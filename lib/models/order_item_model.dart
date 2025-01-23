class OrderItem {
  final int? id;
  final int productId;
  final int quantity;
  final double sellingPrice;
  final double totalAmount;
  final String? productName;

  OrderItem({
    this.id,
    required this.productId,
    required this.quantity,
    required this.sellingPrice,
    required this.totalAmount,
    this.productName,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'product_id': productId,
      'quantity': quantity,
      'selling_price': sellingPrice,
      'total_amount': totalAmount,
    };
  }

  factory OrderItem.fromMap(Map<String, dynamic> map) {
    return OrderItem(
      id: map['id'] as int?,
      productId: (map['product_id'] as num).toInt(),
      quantity: (map['quantity'] as num).toInt(),
      sellingPrice: (map['selling_price'] as num).toDouble(),
      totalAmount: (map['total_amount'] as num).toDouble(),
      productName: map['product_name'] as String?,
    );
  }
} 