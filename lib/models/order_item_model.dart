class OrderItem {
  final int? id;
  final int orderId;
  final int productId;
  final int quantity;
  final double unitPrice;
  final double sellingPrice;
  final double adjustedPrice;
  final double totalAmount;
  final String productName;
  final bool isSubUnit;
  final String? subUnitName;

  OrderItem({
    this.id,
    required this.orderId,
    required this.productId,
    required this.quantity,
    required this.unitPrice,
    required this.sellingPrice,
    required this.adjustedPrice,
    required this.totalAmount,
    required this.productName,
    this.isSubUnit = false,
    this.subUnitName,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'order_id': orderId,
      'product_id': productId,
      'quantity': quantity,
      'unit_price': unitPrice,
      'selling_price': sellingPrice,
      'adjusted_price': adjustedPrice,
      'total_amount': totalAmount,
      'product_name': productName,
      'is_sub_unit': isSubUnit ? 1 : 0,
      'sub_unit_name': subUnitName,
    };
  }

  factory OrderItem.fromMap(Map<String, dynamic> map) {
    return OrderItem(
      id: map['id'] as int?,
      orderId: map['order_id'],
      productId: map['product_id'],
      quantity: map['quantity'],
      unitPrice: (map['unit_price'] as num).toDouble(),
      sellingPrice: (map['selling_price'] as num).toDouble(),
      adjustedPrice: (map['adjusted_price'] as num?)?.toDouble() ?? 
                    (map['selling_price'] as num).toDouble(),
      totalAmount: (map['total_amount'] as num).toDouble(),
      productName: map['product_name'] as String,
      isSubUnit: (map['is_sub_unit'] as num?)?.toInt() == 1,
      subUnitName: map['sub_unit_name'],
    );
  }

  double get profit => (adjustedPrice - unitPrice) * quantity;
} 