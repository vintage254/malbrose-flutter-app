class ActivityLog {
  final int? id;
  final int userId;
  final String username;
  final String actionType;
  final String details;
  final DateTime timestamp;

  ActivityLog({
    this.id,
    required this.userId,
    required this.username,
    required this.actionType,
    required this.details,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'user_id': userId,
      'username': username,
      'action_type': actionType,
      'details': details,
      'timestamp': timestamp.toIso8601String(),
    };
  }

  factory ActivityLog.fromMap(Map<String, dynamic> map) {
    return ActivityLog(
      id: map['id'],
      userId: map['user_id'],
      username: map['username'],
      actionType: map['action_type'],
      details: map['details'],
      timestamp: DateTime.parse(map['timestamp']),
    );
  }
} 