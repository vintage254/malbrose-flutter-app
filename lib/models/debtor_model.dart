class Debtor {
  final int? id;
  final String name;
  final double balance;
  final String details;
  final String status;
  final DateTime createdAt;
  final DateTime? lastUpdated;

  Debtor({
    this.id,
    required this.name,
    required this.balance,
    required this.details,
    required this.status,
    required this.createdAt,
    this.lastUpdated,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'balance': balance,
      'details': details,
      'status': status,
      'created_at': createdAt.toIso8601String(),
      'last_updated': lastUpdated?.toIso8601String(),
    };
  }

  factory Debtor.fromMap(Map<String, dynamic> map) {
    return Debtor(
      id: map['id'],
      name: map['name'],
      balance: map['balance'],
      details: map['details'] ?? '',
      status: map['status'],
      createdAt: DateTime.parse(map['created_at']),
      lastUpdated: map['last_updated'] != null 
          ? DateTime.parse(map['last_updated'])
          : null,
    );
  }
} 