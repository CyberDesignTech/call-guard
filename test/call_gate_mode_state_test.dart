import 'package:flutter_test/flutter_test.dart';
import 'package:call_guard/platform/call_gate_mode_state.dart';

void main() {
  final now = DateTime.fromMillisecondsSinceEpoch(1_800_000_000_000);

  test(
    'native widget quick-silence timestamp is reflected in Flutter state',
    () {
      final state = CallGateModeState.fromSettings({
        'protection_enabled': 'true',
        'quick_silence_until': '${now.millisecondsSinceEpoch + 3_600_000}',
      }, now: now);

      expect(state.protectionEnabled, isTrue);
      expect(state.drivingMode, isFalse);
      expect(state.whitelistOnly, isTrue);
      expect(state.automaticSilence, isFalse);
      expect(state.quickSilenceActive, isTrue);
      expect(state.silenceControlEnabled, isTrue);
      expect(
        state.quickSilenceUntilMillis,
        now.millisecondsSinceEpoch + 3_600_000,
      );
    },
  );

  test(
    'expired native silence is removed while manual aliases stay synchronized',
    () {
      final expired = CallGateModeState.fromSettings({
        'quick_silence_until': '${now.millisecondsSinceEpoch}',
      }, now: now);
      expect(expired.quickSilenceActive, isFalse);
      expect(expired.silenceControlEnabled, isFalse);
      expect(expired.quickSilenceUntilMillis, isNull);

      final manual = CallGateModeState.fromSettings({
        'manual_silence': 'true',
        'driving_mode': 'true',
        'allow_only_whitelist': 'false',
        'automatic_silence': 'true',
        'protection_enabled': 'false',
      }, now: now);
      expect(manual.manualSilence, isTrue);
      expect(manual.silenceControlEnabled, isTrue);
      expect(manual.drivingMode, isTrue);
      expect(manual.whitelistOnly, isFalse);
      expect(manual.automaticSilence, isTrue);
      expect(manual.protectionEnabled, isFalse);
    },
  );

  test(
    'missing settings use the same whitelist preference default as Flutter',
    () {
      final state = CallGateModeState.fromSettings({});
      expect(state.whitelistOnly, isTrue);
      expect(state.automaticSilence, isFalse);
      expect(state.drivingMode, isFalse);
    },
  );
}
