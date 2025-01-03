class ActivityLog {
  final int? id;
  final int userId;
  final String username;
  final String action;
  final String details;
  final DateTime timestamp;

  ActivityLog({
    this.id,
    required this.userId,
    required this.username,
    required this.action,
    required this.details,
    required this.timestamp,
  });

  factory ActivityLog.fromMap(Map<String, dynamic> map) {
    return ActivityLog(
      id: map['id'] as int?,
      userId: map['user_id'] as int,
      username: map['username'] as String,
      action: map['action'] as String,
      details: map['details'] as String,
      timestamp: DateTime.parse(map['timestamp'] as String),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'user_id': userId,
      'username': username,
      'action': action,
      'details': details,
      'timestamp': timestamp.toIso8601String(),
    };
  }
}


