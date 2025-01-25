class Order {
  final int? id;
  final String orderNumber;
  final double totalAmount;
  final String? customerName;
  final String orderStatus;
  final String paymentStatus;
  final int createdBy;
  final DateTime createdAt;
  final DateTime orderDate;
  final List<OrderItem> items;

  Order({
    this.id,
    required this.orderNumber,
    required this.totalAmount,
    this.customerName,
    this.orderStatus = 'PENDING',
    this.paymentStatus = 'PENDING',
    required this.createdBy,
    required this.createdAt,
    required this.orderDate,
    required this.items,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'order_number': orderNumber,
      'total_amount': totalAmount,
      'customer_name': customerName,
      'status': orderStatus,
      'payment_status': paymentStatus,
      'created_by': createdBy,
      'created_at': createdAt.toIso8601String(),
      'order_date': orderDate.toIso8601String(),
    };
  }

  factory Order.fromMap(Map<String, dynamic> map, List<OrderItem> items) {
    return Order(
      id: map['id'],
      orderNumber: map['order_number'],
      totalAmount: (map['total_amount'] as num).toDouble(),
      customerName: map['customer_name'],
      orderStatus: map['status'] ?? 'PENDING',
      paymentStatus: map['payment_status'] ?? 'PENDING',
      createdBy: map['created_by'],
      createdAt: DateTime.parse(map['created_at']),
      orderDate: DateTime.parse(map['order_date']),
      items: items,
    );
  }
}

class OrderItem {
  final int? id;
  final int orderId;
  final int productId;
  final int quantity;
  final double unitPrice;
  final double sellingPrice;
  final double totalAmount;
  final String? productName;

  OrderItem({
    this.id,
    required this.orderId,
    required this.productId,
    required this.quantity,
    required this.unitPrice,
    required this.sellingPrice,
    required this.totalAmount,
    this.productName,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'order_id': orderId,
      'product_id': productId,
      'quantity': quantity,
      'unit_price': unitPrice,
      'selling_price': sellingPrice,
      'total_amount': totalAmount,
    };
  }

  factory OrderItem.fromMap(Map<String, dynamic> map) {
    return OrderItem(
      id: map['id'],
      orderId: map['order_id'],
      productId: map['product_id'],
      quantity: map['quantity'],
      unitPrice: (map['unit_price'] as num).toDouble(),
      sellingPrice: (map['selling_price'] as num).toDouble(),
      totalAmount: (map['total_amount'] as num).toDouble(),
      productName: map['product_name'],
    );
  }
} 