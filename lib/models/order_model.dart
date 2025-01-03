class Order {
  final int? id;
  final String? orderNumber;
  final int productId;
  final int quantity;
  final double sellingPrice;
  final double buyingPrice;
  final double totalAmount;
  final String? customerName;
  String orderStatus;
  final String paymentStatus;
  final int createdBy;
  final DateTime createdAt;
  final DateTime orderDate;
  final List<OrderItem>? items;

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
    required this.createdBy,
    required this.createdAt,
    required this.orderDate,
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
      'status': orderStatus,
      'payment_status': paymentStatus,
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
      sellingPrice: (map['selling_price'] as num).toDouble(),
      buyingPrice: (map['buying_price'] as num).toDouble(),
      totalAmount: (map['total_amount'] as num).toDouble(),
      customerName: map['customer_name'],
      orderStatus: map['status'] ?? 'PENDING',
      paymentStatus: map['payment_status'] ?? 'PENDING',
      createdBy: map['created_by'],
      createdAt: DateTime.parse(map['created_at']),
      orderDate: DateTime.parse(map['order_date']),
    );
  }
}

class OrderItem {
  final int productId;
  final int quantity;
  final double price;
  final double total;
  final double sellingPrice;
  final double totalAmount;

  OrderItem({
    required this.productId,
    required this.quantity,
    required this.price,
    required this.total,
    required this.sellingPrice,
    required this.totalAmount,
  });
} 