class CallLogEntry {
  const CallLogEntry({
    required this.id,
    required this.phone,
    required this.reason,
    required this.timestamp,
  });

  final int id;
  final String phone;
  final String reason;
  final int timestamp;
}
