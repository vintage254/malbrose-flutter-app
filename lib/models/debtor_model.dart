class Debtor {
  final int? id;
  final String name;
  final double balance;
  final String details;
  final String status;
  final DateTime createdAt;
  final DateTime? lastUpdated;
  final String? orderNumber;
  final String? orderDetails;
  final double? originalAmount;

  Debtor({
    this.id,
    required this.name,
    required this.balance,
    required this.details,
    required this.status,
    required this.createdAt,
    this.lastUpdated,
    this.orderNumber,
    this.orderDetails,
    this.originalAmount,
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
      'order_number': orderNumber,
      'order_details': orderDetails,
      'original_amount': originalAmount,
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
      orderNumber: map['order_number'] as String?,
      orderDetails: map['order_details'] as String?,
      originalAmount: map['original_amount'] as double?,
    );
  }

  Debtor copyWith({
    int? id,
    String? name,
    double? balance,
    String? details,
    String? status,
    DateTime? createdAt,
    DateTime? lastUpdated,
    String? orderNumber,
    String? orderDetails,
    double? originalAmount,
  }) {
    return Debtor(
      id: id ?? this.id,
      name: name ?? this.name,
      balance: balance ?? this.balance,
      details: details ?? this.details,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      lastUpdated: lastUpdated ?? this.lastUpdated,
      orderNumber: orderNumber ?? this.orderNumber,
      orderDetails: orderDetails ?? this.orderDetails,
      originalAmount: originalAmount ?? this.originalAmount,
    );
  }
} 