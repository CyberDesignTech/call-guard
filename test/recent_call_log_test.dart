import 'package:flutter_test/flutter_test.dart';
import 'package:call_guard/models/recent_call_log_entry.dart';

void main() {
  test('normalizes visible numbers and rejects hidden numbers', () {
    expect(normalizePhoneNumber(' +1 (202) 555-0198 '), '+12025550198');
    expect(normalizePhoneNumber('020 7123 4567'), '02071234567');
    expect(normalizePhoneNumber('Private number'), isEmpty);
  });

  test('parses recent call entries and access status from the channel', () {
    final result = RecentCallLogResult.fromMap({
      'permissionGranted': true,
      'permanentlyDenied': false,
      'calls': [
        {
          'number': '+44 (0)20 7123 4567',
          'name': 'Sam Example',
          'type': 'missed',
          'timestamp': 1763337600000,
        },
        {'number': 'Private number', 'type': 'incoming', 'timestamp': 1},
      ],
    });

    expect(result.permissionGranted, isTrue);
    expect(result.permanentlyDenied, isFalse);
    expect(result.calls, hasLength(1));
    expect(result.calls.single.number, '+4402071234567');
    expect(result.calls.single.name, 'Sam Example');
    expect(result.calls.single.type, 'missed');
    expect(result.calls.single.timestamp, 1763337600000);

    final denied = RecentCallLogResult.fromMap({
      'permissionGranted': false,
      'permanentlyDenied': true,
      'calls': const [],
    });
    expect(denied.permissionGranted, isFalse);
    expect(denied.permanentlyDenied, isTrue);
    expect(denied.calls, isEmpty);
  });
}
