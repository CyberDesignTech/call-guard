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
    Map<String, String>? settingsOverrides,
  }) async {
    final rawPhone = phoneNumber.trim();
    if (_isEmergencyServiceNumber(rawPhone)) {
      final canonical = _canonical(rawPhone);
      return CallSimulationVerdict(
        allowed: true,
        reason: 'emergency_service',
        phoneNumber: canonical.isEmpty ? rawPhone : '+$canonical',
      );
    }

    final hidden = _isHidden(rawPhone);
    final shortNumber = !hidden && _isShortNumber(rawPhone);
    final canonical = hidden
        ? ''
        : shortNumber
        ? _digits(rawPhone)
        : _canonical(rawPhone);
    CallSimulationVerdict verdict(bool allowed, String reason) =>
        CallSimulationVerdict(
          allowed: allowed,
          reason: reason,
          phoneNumber: canonical.isEmpty ? rawPhone : '+$canonical',
        );

    final settings = {...await database.getSettings(), ...?settingsOverrides};
    if (!_bool(settings, 'protection_enabled', true)) {
      return verdict(true, 'protection_disabled');
    }

    // Driving mode intentionally precedes every allow rule, including
    // permanent and temporary allowlist entries.
    if (_bool(settings, 'driving_mode', false)) {
      return verdict(false, 'driving_mode');
    }

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
    final scheduleWhitelistOnly =
        scheduleActive && _bool(settings, 'allow_only_whitelist', false);
    final manualSilence =
        _bool(settings, 'manual_silence_enabled', false) ||
        _bool(settings, 'manual_silence', false) ||
        _bool(settings, 'silence_manual', false);
    if (manualSilence || scheduleWhitelistOnly) {
      final emergencyRepeatEnabled =
          _bool(settings, 'answering_emergency_repeat', false) &&
          _bool(settings, 'answering_enabled', false);
      if (emergencyRepeatEnabled &&
          !hidden &&
          canonical.isNotEmpty &&
          !await _isExplicitlyBlocked(rawPhone, canonical, settings) &&
          await _hasRecentRejectedSilenceCalls(canonical, currentTime)) {
        return verdict(true, 'emergency_repeat');
      }
      return verdict(false, 'silent_schedule');
    }

    final blackRules = await database.getPhoneRules('black');
    if (!hidden &&
        blackRules.any(
          (row) =>
              _samePhone(rawPhone, canonical, row['phone'] as String? ?? ''),
        )) {
      return verdict(false, 'blacklist');
    }

    if (hidden && _bool(settings, 'block_hidden', true)) {
      return verdict(false, 'hidden_number');
    }

    if (shortNumber) {
      if (!_bool(settings, DatabaseHelper.settingBlockShortNumbers, false) ||
          isInContacts != false) {
        return verdict(true, 'default_allow');
      }
      return verdict(false, 'short_number_block');
    }

    if (_bool(settings, 'block_non_contacts', false) && isInContacts == false) {
      return verdict(false, 'not_in_contacts');
    }

    final countries = await database.getCountries();
    final digits = canonical;
    final country = _matchCountry(countries, digits);

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

    return verdict(true, 'default_allow');
  }

  Future<bool> _isExplicitlyBlocked(
    String rawPhone,
    String canonical,
    Map<String, String> settings,
  ) async {
    final blackRules = await database.getPhoneRules('black');
    if (blackRules.any(
      (row) => _samePhone(rawPhone, canonical, row['phone'] as String? ?? ''),
    )) {
      return true;
    }
    if (_isShortNumber(rawPhone)) return false;

    final countries = await database.getCountries();
    final country = _matchCountry(countries, canonical);
    if (country != null) {
      final isoCode = country['iso_code'] as String? ?? '';
      final dialCode = _digits(country['dial_code'] as String? ?? '');
      final nationalDigits = canonical.substring(dialCode.length);
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
      if (matchingOperator.isNotEmpty && matchingOperator.first.$2 == 'block') {
        return true;
      }
      if ((country['action'] as String? ?? 'neutral') == 'block') return true;
      if (_bool(settings, 'block_international', false) &&
          _isInternational(rawPhone, country, countries)) {
        return true;
      }
    }
    return false;
  }

  Future<bool> _hasRecentRejectedSilenceCalls(
    String canonical,
    DateTime now,
  ) async {
    final targetDigits = _digits(canonical);
    if (targetDigits.isEmpty) return false;
    final cutoff =
        now.millisecondsSinceEpoch - const Duration(minutes: 5).inMilliseconds;
    var rejectedMatches = 0;
    for (final row in await database.getCallLogs()) {
      if ((row['reason'] as String? ?? '') != 'silent_schedule' ||
          (row['timestamp'] as int? ?? 0) < cutoff) {
        continue;
      }
      final recentPhone = row['phone'] as String? ?? '';
      if (_isHidden(recentPhone) ||
          _digits(_canonical(recentPhone)) != targetDigits) {
        continue;
      }
      rejectedMatches++;
      if (rejectedMatches >= 2) return true;
    }
    return false;
  }

  /// Picks the most specific country for a dialed number.
  ///
  /// Longest calling code wins. Shared codes (+1, +7, +39) are separated by
  /// the national area-code list; when no area code matches, the country
  /// without area codes is the primary one (Russia for +7, Italy for +39),
  /// and +1 defaults to the United States.
  Map<String, Object?>? _matchCountry(
    List<Map<String, Object?>> countries,
    String phoneDigits,
  ) {
    Map<String, Object?>? best;
    var bestDial = '';
    for (final row in countries) {
      final dialCode = _digits(row['dial_code'] as String? ?? '');
      if (dialCode.isEmpty || !phoneDigits.startsWith(dialCode)) continue;
      if (best == null || dialCode.length > bestDial.length) {
        best = row;
        bestDial = dialCode;
        continue;
      }
      if (dialCode.length != bestDial.length) continue;
      final candidateArea = _areaCodeMatches(row, phoneDigits, dialCode);
      final bestArea = _areaCodeMatches(best, phoneDigits, bestDial);
      if (candidateArea && !bestArea) {
        best = row;
      } else if (!candidateArea && bestArea) {
        continue;
      } else if (!candidateArea && !bestArea) {
        final candidateHasAreas = _areaCodes(row).isNotEmpty;
        final bestHasAreas = _areaCodes(best).isNotEmpty;
        if (bestHasAreas && !candidateHasAreas) {
          best = row;
        } else if (candidateHasAreas == bestHasAreas &&
            (row['iso_code'] as String? ?? '') == 'US' &&
            (best['iso_code'] as String? ?? '') != 'US') {
          best = row;
        }
      }
    }
    return best;
  }

  List<String> _areaCodes(Map<String, Object?> row) =>
      (row['area_codes'] as String? ?? '')
          .split(',')
          .map(_digits)
          .where((code) => code.isNotEmpty)
          .toList();

  bool _areaCodeMatches(
    Map<String, Object?> row,
    String phoneDigits,
    String dialCode,
  ) {
    if (phoneDigits.length <= dialCode.length) return false;
    final nationalDigits = phoneDigits.substring(dialCode.length);
    return _areaCodes(row)
        .any((areaCode) => nationalDigits.startsWith(areaCode));
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

  bool _isEmergencyServiceNumber(String phone) {
    var cleaned = _removeShortNumberSeparators(phone);
    if (cleaned.startsWith('+')) cleaned = cleaned.substring(1);
    if (cleaned.startsWith('00')) cleaned = cleaned.substring(2);
    return RegExp(r'^\d+$').hasMatch(cleaned) &&
        _emergencyServiceNumbers.contains(cleaned);
  }

  bool _isShortNumber(String phone) {
    final digitsOnly = _digits(phone);
    return digitsOnly.length >= 2 &&
        digitsOnly.length <= 6 &&
        !_emergencyServiceNumbers.contains(digitsOnly);
  }

  String _removeShortNumberSeparators(String phone) =>
      phone.trim().replaceAll(RegExp(r'[\s()./-]'), '');

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

  static const _emergencyServiceNumbers = {
    '101',
    '102',
    '103',
    '104',
    '112',
    '911',
    '999',
  };
}
