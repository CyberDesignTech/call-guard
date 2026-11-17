class CallLogEntry {
  const CallLogEntry({
    required this.id,
    required this.phone,
    this.contactName = '',
    required this.reason,
    required this.timestamp,
  });

  final int id;
  final String phone;
  final String contactName;
  final String reason;
  final int timestamp;

  factory CallLogEntry.fromRow(Map<String, Object?> row) => CallLogEntry(
    id: row['id'] as int,
    phone: row['phone'] as String,
    contactName: row['contact_name'] as String? ?? '',
    reason: row['reason'] as String,
    timestamp: row['timestamp'] as int,
  );
}
