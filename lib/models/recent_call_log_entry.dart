String normalizePhoneNumber(String value) {
  final trimmed = value.trim();
  final digits = trimmed.replaceAll(RegExp(r'\D'), '');
  if (digits.isEmpty) return '';
  return trimmed.startsWith('+') ? '+$digits' : digits;
}

class RecentCallLogEntry {
  const RecentCallLogEntry({
    required this.number,
    required this.name,
    required this.type,
    required this.timestamp,
  });

  final String number;
  final String name;
  final String type;
  final int timestamp;

  factory RecentCallLogEntry.fromMap(Map<String, Object?> values) =>
      RecentCallLogEntry(
        number: normalizePhoneNumber(values['number'] as String? ?? ''),
        name: values['name'] as String? ?? '',
        type: values['type'] as String? ?? 'incoming',
        timestamp: (values['timestamp'] as num?)?.toInt() ?? 0,
      );
}

class RecentCallLogResult {
  const RecentCallLogResult({
    required this.permissionGranted,
    required this.permanentlyDenied,
    required this.calls,
  });

  final bool permissionGranted;
  final bool permanentlyDenied;
  final List<RecentCallLogEntry> calls;

  factory RecentCallLogResult.fromMap(Map<String, Object?> values) {
    final rawCalls = values['calls'];
    final calls = <RecentCallLogEntry>[];
    if (rawCalls is List) {
      for (final rawCall in rawCalls) {
        if (rawCall is! Map) continue;
        final call = <String, Object?>{
          for (final entry in rawCall.entries)
            entry.key.toString(): entry.value,
        };
        final parsed = RecentCallLogEntry.fromMap(call);
        if (parsed.number.isNotEmpty) calls.add(parsed);
      }
    }
    return RecentCallLogResult(
      permissionGranted: values['permissionGranted'] == true,
      permanentlyDenied: values['permanentlyDenied'] == true,
      calls: calls,
    );
  }
}
