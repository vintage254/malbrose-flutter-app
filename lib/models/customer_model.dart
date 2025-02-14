class Customer {
  final int? id;
  final String name;
  final String? email;
  final String? phone;
  final String? address;
  final int totalOrders;
  final double totalAmount;
  final DateTime? lastOrderDate;
  final DateTime createdAt;
  final DateTime? updatedAt;

  Customer({
    this.id,
    required this.name,
    this.email,
    this.phone,
    this.address,
    this.totalOrders = 0,
    this.totalAmount = 0.0,
    this.lastOrderDate,
    required this.createdAt,
    this.updatedAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'email': email,
      'phone': phone,
      'address': address,
      'total_orders': totalOrders,
      'total_amount': totalAmount,
      'last_order_date': lastOrderDate?.toIso8601String(),
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
    };
  }

  factory Customer.fromMap(Map<String, dynamic> map) {
    return Customer(
      id: map['id'] as int?,
      name: map['name'] as String,
      email: map['email'] as String?,
      phone: map['phone'] as String?,
      address: map['address'] as String?,
      totalOrders: (map['total_orders'] as num?)?.toInt() ?? 0,
      totalAmount: (map['total_amount'] as num?)?.toDouble() ?? 0.0,
      lastOrderDate: map['last_order_date'] != null 
          ? DateTime.parse(map['last_order_date'] as String)
          : null,
      createdAt: DateTime.parse(map['created_at'] as String),
      updatedAt: map['updated_at'] != null 
          ? DateTime.parse(map['updated_at'] as String)
          : null,
    );
  }

  Customer copyWith({
    int? id,
    String? name,
    String? email,
    String? phone,
    String? address,
    int? totalOrders,
    double? totalAmount,
    DateTime? lastOrderDate,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Customer(
      id: id ?? this.id,
      name: name ?? this.name,
      email: email ?? this.email,
      phone: phone ?? this.phone,
      address: address ?? this.address,
      totalOrders: totalOrders ?? this.totalOrders,
      totalAmount: totalAmount ?? this.totalAmount,
      lastOrderDate: lastOrderDate ?? this.lastOrderDate,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
} 