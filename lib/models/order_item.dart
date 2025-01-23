class OrderItem {
  final int? id;
  final int? orderId;
  final int productId;
  final int quantity;
  final double price;
  final double sellingPrice;
  final double totalAmount;
  final String? productName;

  // Add total getter
  double get total => totalAmount;

  OrderItem({
    this.id,
    this.orderId,
    required this.productId,
    required this.quantity,
    required this.price,
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
      'price': price,
      'selling_price': sellingPrice,
      'total_amount': totalAmount,
      'product_name': productName,
    };
  }

  factory OrderItem.fromMap(Map<String, dynamic> map) {
    return OrderItem(
      id: map['id'] as int?,
      orderId: map['order_id'] as int?,
      productId: (map['product_id'] as num).toInt(),
      quantity: (map['quantity'] as num).toInt(),
      price: (map['price'] as num).toDouble(),
      sellingPrice: (map['selling_price'] as num).toDouble(),
      totalAmount: (map['total_amount'] as num).toDouble(),
      productName: map['product_name'] as String?,
    );
  }
} 