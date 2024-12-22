class ActivityLog {
  final int? id;
  final int userId;
  final String action;
  final String details;
  final DateTime timestamp;

  ActivityLog({
    this.id,
    required this.userId,
    required this.action,
    required this.details,
    required this.timestamp,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'user_id': userId,
      'action': action,
      'details': details,
      'timestamp': timestamp.toIso8601String(),
    };
  }

  factory ActivityLog.fromMap(Map<String, dynamic> map) {
    return ActivityLog(
      id: map['id'],
      userId: map['user_id'],
      action: map['action'],
      details: map['details'],
      timestamp: DateTime.parse(map['timestamp']),
    );
  }
} 