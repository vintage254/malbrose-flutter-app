class ActivityLog {
  final int? id;
  final int userId;
  final String actionType;
  final String details;
  final DateTime timestamp;
  final String? username; // For joining with user data

  ActivityLog({
    this.id,
    required this.userId,
    required this.actionType,
    required this.details,
    DateTime? timestamp,
    this.username,
  }) : timestamp = timestamp ?? DateTime.now();

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'user_id': userId,
      'action_type': actionType,
      'details': details,
      'timestamp': timestamp.toIso8601String(),
    };
  }

  factory ActivityLog.fromMap(Map<String, dynamic> map) {
    return ActivityLog(
      id: map['id'],
      userId: map['user_id'],
      actionType: map['action_type'],
      details: map['details'],
      timestamp: DateTime.parse(map['timestamp']),
      username: map['username'],
    );
  }
} 