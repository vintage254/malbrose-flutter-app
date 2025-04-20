class Creditor {
  final int? id;
  final String name;
  final double balance;
  final String? details;
  final String status;
  final DateTime? createdAt;
  final DateTime? lastUpdated;
  final String? orderNumber;
  final String? orderDetails;
  final double? originalAmount;
  final int? customerId;
  final String? customerName;
  final int? orderId;
  final double? amount;
  final DateTime? paymentDate;
  final double? paymentAmount;
  final String? paymentMethod;
  final String? paymentDetails;
  final DateTime? updatedAt;

  Creditor({
    this.id,
    required this.name,
    required this.balance,
    this.details,
    this.status = 'PENDING',
    this.createdAt,
    this.lastUpdated,
    this.orderNumber,
    this.orderDetails,
    this.originalAmount,
    this.customerId,
    this.customerName,
    this.orderId,
    this.amount,
    this.paymentDate,
    this.paymentAmount,
    this.paymentMethod,
    this.paymentDetails,
    this.updatedAt,
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
      'order_number': orderNumber,
      'order_details': orderDetails,
      'original_amount': originalAmount,
      'customer_id': customerId,
      'customer_name': customerName,
      'order_id': orderId,
      'amount': amount,
      'payment_date': paymentDate?.toIso8601String(),
      'payment_amount': paymentAmount,
      'payment_method': paymentMethod,
      'payment_details': paymentDetails,
      'updated_at': updatedAt?.toIso8601String(),
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
      orderNumber: map['order_number'] as String?,
      orderDetails: map['order_details'] as String?,
      originalAmount: map['original_amount'] as double?,
      customerId: map['customer_id'] as int?,
      customerName: map['customer_name'] as String?,
      orderId: map['order_id'] as int?,
      amount: map['amount'] as double?,
      paymentDate: map['payment_date'] != null 
          ? DateTime.parse(map['payment_date'] as String)
          : null,
      paymentAmount: map['payment_amount'] as double?,
      paymentMethod: map['payment_method'] as String?,
      paymentDetails: map['payment_details'] as String?,
      updatedAt: map['updated_at'] != null 
          ? DateTime.parse(map['updated_at'] as String)
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
    String? orderNumber,
    String? orderDetails,
    double? originalAmount,
    int? customerId,
    String? customerName,
    int? orderId,
    double? amount,
    DateTime? paymentDate,
    double? paymentAmount,
    String? paymentMethod,
    String? paymentDetails,
    DateTime? updatedAt,
  }) {
    return Creditor(
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
      customerId: customerId ?? this.customerId,
      customerName: customerName ?? this.customerName,
      orderId: orderId ?? this.orderId,
      amount: amount ?? this.amount,
      paymentDate: paymentDate ?? this.paymentDate,
      paymentAmount: paymentAmount ?? this.paymentAmount,
      paymentMethod: paymentMethod ?? this.paymentMethod,
      paymentDetails: paymentDetails ?? this.paymentDetails,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
} 