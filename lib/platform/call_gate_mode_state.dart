/// Shared interpretation of mode settings written by Flutter and native Android.
class CallGateModeState {
  const CallGateModeState({
    required this.protectionEnabled,
    required this.drivingMode,
    required this.whitelistOnly,
    required this.automaticSilence,
    required this.manualSilence,
    required this.quickSilenceUntilMillis,
    required this.quickSilenceActive,
  });

  final bool protectionEnabled;
  final bool drivingMode;
  final bool whitelistOnly;
  final bool automaticSilence;
  final bool manualSilence;
  final int? quickSilenceUntilMillis;
  final bool quickSilenceActive;

  /// Flutter's existing manual-silence control also reflects a timed silence
  /// requested from the native widget, so the UI updates without a Flutter engine
  /// being involved in the original click.
  bool get silenceControlEnabled => manualSilence || quickSilenceActive;

  factory CallGateModeState.fromSettings(
    Map<String, String> settings, {
    DateTime? now,
  }) {
    bool setting(String key, [bool fallback = false]) =>
        settings[key] == null ? fallback : settings[key] == 'true';
    final until = int.tryParse(settings['quick_silence_until'] ?? '');
    final quickActive =
        until != null && until > (now ?? DateTime.now()).millisecondsSinceEpoch;
    return CallGateModeState(
      protectionEnabled: setting('protection_enabled', true),
      drivingMode: setting('driving_mode'),
      whitelistOnly: setting('allow_only_whitelist', true),
      automaticSilence: setting('automatic_silence'),
      manualSilence:
          setting('manual_silence_enabled') ||
          setting('manual_silence') ||
          setting('silence_manual'),
      quickSilenceUntilMillis: quickActive ? until : null,
      quickSilenceActive: quickActive,
    );
  }
}
