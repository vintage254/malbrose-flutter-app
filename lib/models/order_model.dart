class Order {
  final int? id;
  String? orderNumber;
  final int productId;
  final int quantity;
  final double sellingPrice;
  final double buyingPrice;
  final double totalAmount;
  final String? customerName;
  final String? orderStatus;
  final String? paymentStatus;
  final String? paymentMethod;
  final int createdBy;
  final DateTime orderDate;
  final DateTime? createdAt;
  final List<Order>? items;

  Order({
    this.id,
    this.orderNumber,
    required this.productId,
    required this.quantity,
    required this.sellingPrice,
    required this.buyingPrice,
    required this.totalAmount,
    this.customerName,
    this.orderStatus = 'PENDING',
    this.paymentStatus = 'PENDING',
    this.paymentMethod,
    required this.createdBy,
    required this.orderDate,
    this.createdAt,
    this.items,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'order_number': orderNumber,
      'product_id': productId,
      'quantity': quantity,
      'selling_price': sellingPrice,
      'buying_price': buyingPrice,
      'total_amount': totalAmount,
      'customer_name': customerName,
      'payment_status': paymentStatus,
      'payment_method': paymentMethod,
      'order_status': orderStatus,
      'created_by': createdBy,
      'order_date': orderDate.toIso8601String(),
      'created_at': createdAt?.toIso8601String(),
    };
  }

  factory Order.fromMap(Map<String, dynamic> map) {
    return Order(
      id: map['id'],
      orderNumber: map['order_number'],
      productId: map['product_id'],
      quantity: map['quantity'],
      sellingPrice: (map['selling_price'] as num).toDouble(),
      buyingPrice: (map['buying_price'] as num).toDouble(),
      totalAmount: (map['total_amount'] as num).toDouble(),
      customerName: map['customer_name'],
      paymentStatus: map['payment_status'],
      paymentMethod: map['payment_method'],
      orderStatus: map['order_status'],
      createdBy: map['created_by'],
      orderDate: DateTime.parse(map['order_date'] ?? map['created_at']),
      createdAt: map['created_at'] != null ? DateTime.parse(map['created_at']) : null,
    );
  }
} 