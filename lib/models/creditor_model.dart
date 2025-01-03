class Creditor {
  final int? id;
  final String name;
  final double balance;
  final String? details;
  final String status;
  final DateTime? createdAt;
  final DateTime? lastUpdated;

  Creditor({
    this.id,
    required this.name,
    required this.balance,
    this.details,
    this.status = 'PENDING',
    this.createdAt,
    this.lastUpdated,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'balance': balance,
      'details': details,
      'status': status,
      'created_at': createdAt?.toIso8601String(),
      'last_updated': lastUpdated?.toIso8601String(),
    };
  }

  factory Creditor.fromMap(Map<String, dynamic> map) {
    return Creditor(
      id: map['id'] as int?,
      name: map['name'] as String,
      balance: map['balance'] as double,
      details: map['details'] as String?,
      status: map['status'] as String? ?? 'PENDING',
      createdAt: map['created_at'] != null 
          ? DateTime.parse(map['created_at'] as String)
          : null,
      lastUpdated: map['last_updated'] != null 
          ? DateTime.parse(map['last_updated'] as String)
          : null,
    );
  }

  Creditor copyWith({
    int? id,
    String? name,
    double? balance,
    String? details,
    String? status,
    DateTime? createdAt,
    DateTime? lastUpdated,
  }) {
    return Creditor(
      id: id ?? this.id,
      name: name ?? this.name,
      balance: balance ?? this.balance,
      details: details ?? this.details,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      lastUpdated: lastUpdated ?? this.lastUpdated,
    );
  }
} 