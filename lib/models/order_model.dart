class Order {
  final int? id;
  final String? orderNumber;
  final int productId;
  final int quantity;
  final double sellingPrice;
  final double buyingPrice;
  final double totalAmount;
  final String? customerName;
  final String paymentStatus;
  String _orderStatus;
  final int createdBy;
  final DateTime createdAt;
  final DateTime orderDate;
  final List<OrderItem>? items;

  String get orderStatus => _orderStatus;
  set orderStatus(String value) {
    _orderStatus = value;
  }

  Order({
    this.id,
    this.orderNumber,
    required this.productId,
    required this.quantity,
    required this.sellingPrice,
    required this.buyingPrice,
    required this.totalAmount,
    this.customerName,
    this.paymentStatus = 'PENDING',
    String orderStatus = 'PENDING',
    required this.createdBy,
    this.items,
    DateTime? createdAt,
    DateTime? orderDate,
  }) : 
    _orderStatus = orderStatus,
    createdAt = createdAt ?? DateTime.now(),
    orderDate = orderDate ?? DateTime.now();

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
      'order_status': _orderStatus,
      'created_by': createdBy,
      'created_at': createdAt.toIso8601String(),
      'order_date': orderDate.toIso8601String(),
    };
  }

  factory Order.fromMap(Map<String, dynamic> map) {
    return Order(
      id: map['id'],
      orderNumber: map['order_number'],
      productId: map['product_id'],
      quantity: map['quantity'],
      sellingPrice: map['selling_price']?.toDouble() ?? 0.0,
      buyingPrice: map['buying_price']?.toDouble() ?? 0.0,
      totalAmount: map['total_amount']?.toDouble() ?? 0.0,
      customerName: map['customer_name'],
      paymentStatus: map['payment_status'] ?? 'PENDING',
      orderStatus: map['order_status'] ?? 'PENDING',
      createdBy: map['created_by'],
      createdAt: DateTime.parse(map['created_at']),
      orderDate: DateTime.parse(map['order_date']),
      items: (map['items'] as List<dynamic>?)
          ?.map((item) => OrderItem.fromMap(item))
          .toList(),
    );
  }
}

class OrderItem {
  final int productId;
  final int quantity;
  final double price;
  final double sellingPrice;
  final double totalAmount;
  final double total;

  OrderItem({
    required this.productId,
    required this.quantity,
    required this.price,
    required this.sellingPrice,
    required this.totalAmount,
    required this.total,
  });

  Map<String, dynamic> toMap() {
    return {
      'product_id': productId,
      'quantity': quantity,
      'price': price,
      'selling_price': sellingPrice,
      'total_amount': totalAmount,
      'total': total,
    };
  }

  factory OrderItem.fromMap(Map<String, dynamic> map) {
    return OrderItem(
      productId: map['product_id'],
      quantity: map['quantity'],
      price: map['price'],
      sellingPrice: map['selling_price'],
      totalAmount: map['total_amount'],
      total: map['total'],
    );
  }
} 