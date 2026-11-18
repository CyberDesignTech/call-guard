import 'dart:io';

import '../data/database_helper.dart';
import '../platform/call_screening_channel.dart';

/// Local mirror of the native call-rule engine used by Test call.
///
/// Keep rule ordering and persisted setting keys in sync with
/// `CallRuleEngine.kt`; call screening itself always runs natively.
class CallRuleSimulator {
  const CallRuleSimulator(this.database);

  final DatabaseHelper database;

  Future<CallSimulationVerdict> evaluate(
    String phoneNumber, {
    DateTime? now,
    bool? isInContacts,
  }) async {
    final rawPhone = phoneNumber.trim();
    final settings = await database.getSettings();
    final canonical = _canonical(rawPhone);
    CallSimulationVerdict verdict(bool allowed, String reason) =>
        CallSimulationVerdict(
          allowed: allowed,
          reason: reason,
          phoneNumber: canonical.isEmpty ? rawPhone : '+$canonical',
        );

    if (!_bool(settings, 'protection_enabled', true)) {
      return verdict(true, 'protection_disabled');
    }

    // Driving mode intentionally precedes every allow rule, including
    // permanent and temporary allowlist entries.
    if (_bool(settings, 'driving_mode', false)) {
      return verdict(false, 'driving_mode');
    }

    final hidden = _isHidden(rawPhone);
    final whiteRules = await database.getPhoneRules('white');
    final isWhitelisted =
        !hidden &&
        whiteRules.any(
          (row) =>
              _samePhone(rawPhone, canonical, row['phone'] as String? ?? ''),
        );
    if (isWhitelisted) return verdict(true, 'allowlist');

    final currentTime = now ?? DateTime.now();
    final scheduleActive =
        _bool(settings, 'automatic_silence', false) &&
        _isWithinSchedule(settings, currentTime);
    final manualSilence =
        _bool(settings, 'manual_silence_enabled', false) ||
        _bool(settings, 'manual_silence', false) ||
        _bool(settings, 'silence_manual', false);
    if (manualSilence || scheduleActive) {
      return verdict(false, 'silent_schedule');
    }

    if (hidden && _bool(settings, 'block_hidden', true)) {
      return verdict(false, 'hidden_number');
    }
    if (_bool(settings, 'block_non_contacts', false) && isInContacts == false) {
      return verdict(false, 'not_in_contacts');
    }

    final countries = await database.getCountries();
    final digits = canonical;
    final country = countries
        .where((row) {
          final dialCode = _digits(row['dial_code'] as String? ?? '');
          return dialCode.isNotEmpty && digits.startsWith(dialCode);
        })
        .fold<Map<String, Object?>?>(null, (best, candidate) {
          if (best == null ||
              _digits(candidate['dial_code'] as String? ?? '').length >
                  _digits(best['dial_code'] as String? ?? '').length) {
            return candidate;
          }
          return best;
        });

    if (country != null) {
      final isoCode = country['iso_code'] as String? ?? '';
      final dialCode = _digits(country['dial_code'] as String? ?? '');
      final nationalDigits = digits.substring(dialCode.length);
      final operators = await database.getOperators(isoCode);
      final matchingOperator = <(String, String)>[
        for (final operator in operators)
          for (final prefix in (operator['prefixes'] as String? ?? '').split(
            ',',
          ))
            if (_digits(prefix).isNotEmpty &&
                nationalDigits.startsWith(_digits(prefix)))
              (_digits(prefix), operator['action'] as String? ?? 'neutral'),
      ]..sort((a, b) => b.$1.length.compareTo(a.$1.length));
      if (matchingOperator.isNotEmpty) {
        if (matchingOperator.first.$2 == 'block') {
          return verdict(false, 'operator_block');
        }
        if (matchingOperator.first.$2 == 'allow') {
          return verdict(true, 'operator_allow');
        }
      }
      final countryAction = country['action'] as String? ?? 'neutral';
      if (countryAction == 'block') return verdict(false, 'country_block');
      if (countryAction == 'allow') return verdict(true, 'country_allow');

      if (_bool(settings, 'block_international', false) &&
          _isInternational(rawPhone, country, countries)) {
        return verdict(false, 'international_block');
      }
    }

    final blackRules = await database.getPhoneRules('black');
    if (!hidden &&
        blackRules.any(
          (row) =>
              _samePhone(rawPhone, canonical, row['phone'] as String? ?? ''),
        )) {
      return verdict(false, 'blacklist');
    }

    // The schedule whitelist setting is not a permanent, global allowlist
    // policy. Its effect is limited to an enabled schedule in its time window.
    if (scheduleActive && _bool(settings, 'allow_only_whitelist', false)) {
      return verdict(false, 'allowlist_only');
    }
    return verdict(true, 'default_allow');
  }

  bool _isWithinSchedule(Map<String, String> settings, DateTime now) {
    final weekdays = (settings['silence_weekdays'] ?? '1,2,3,4,5,6,7')
        .split(',')
        .map(int.tryParse)
        .whereType<int>()
        .where((day) => day >= 1 && day <= 7)
        .toSet();
    if (weekdays.isEmpty) return false;
    final start = _int(settings, 'silence_start_minute', 1320).clamp(0, 1439);
    final end = _int(settings, 'silence_end_minute', 420).clamp(0, 1439);
    final minute = now.hour * 60 + now.minute;
    final weekday = now.weekday;
    if (start == end) return weekdays.contains(weekday);
    if (start < end) {
      return weekdays.contains(weekday) && minute >= start && minute < end;
    }
    if (minute >= start) return weekdays.contains(weekday);
    if (minute < end) {
      return weekdays.contains(weekday == 1 ? 7 : weekday - 1);
    }
    return false;
  }

  bool _isInternational(
    String rawPhone,
    Map<String, Object?> country,
    List<Map<String, Object?>> countries,
  ) {
    final rawDigits = _digits(rawPhone);
    final explicitInternational =
        rawPhone.startsWith('+') || rawDigits.startsWith('00');
    if (!explicitInternational) return false;
    final locale = Platform.localeName;
    final homeIso = locale.contains('_') ? locale.split('_').last : '';
    final homeDialCode = countries
        .where(
          (row) =>
              (row['iso_code'] as String? ?? '').toUpperCase() ==
              homeIso.toUpperCase(),
        )
        .map((row) => _digits(row['dial_code'] as String? ?? ''))
        .firstOrNull;
    final matchedDial = _digits(country['dial_code'] as String? ?? '');
    return homeDialCode == null || matchedDial != homeDialCode;
  }

  bool _samePhone(String raw, String canonical, String stored) {
    final incoming = canonical.isNotEmpty ? canonical : _digits(raw);
    final saved = _digits(stored);
    return incoming.isNotEmpty && incoming == saved;
  }

  bool _isHidden(String number) =>
      number.trim().isEmpty ||
      const {
        'unknown',
        'private',
        'hidden',
        'restricted',
        'anonymous',
      }.contains(number.trim().toLowerCase());

  String _canonical(String phone) {
    final normalized = _digits(phone);
    if (normalized.startsWith('00')) return normalized.substring(2);
    return normalized;
  }

  String _digits(String value) => value.replaceAll(RegExp(r'\D'), '');

  bool _bool(Map<String, String> settings, String key, bool fallback) =>
      settings[key] == null ? fallback : settings[key] == 'true';

  int _int(Map<String, String> settings, String key, int fallback) =>
      int.tryParse(settings[key] ?? '') ?? fallback;
}
