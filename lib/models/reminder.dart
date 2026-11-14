class Reminder {
  const Reminder({
    this.id,
    required this.phone,
    required this.contactName,
    required this.remindAt,
    required this.note,
    this.isDone = false,
    this.repeatType = 'none',
    this.repeatInterval = 1,
  });

  final int? id;
  final String phone;
  final String contactName;
  final int remindAt;
  final String note;
  final bool isDone;
  final String repeatType;
  final int repeatInterval;
}

class RepeatRule {
  const RepeatRule({required this.type, required this.interval});

  final String type;
  final int interval;
}
