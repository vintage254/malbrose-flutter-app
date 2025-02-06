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
  final double? adjustedPrice;

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
    this.adjustedPrice,
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

  factory Order.fromMap(Map<String, dynamic> map, [List<OrderItem>? items]) {
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
      items: items ?? [],
      adjustedPrice: map['adjusted_price'] as double?,
    );
  }

  // Calculate total profit for the order
  double get totalProfit => items.fold(0, (sum, item) => sum + item.profit);

  // Get formatted display of items with unit information
  String get itemsDisplay => items.map((item) {
    final unitText = item.isSubUnit ? 
        ' (${item.quantity} ${item.subUnitName ?? "pieces"})' : 
        ' (${item.quantity} units)';
    return '${item.displayName}$unitText';
  }).join(", ");
}

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
  final double? subUnitQuantity;

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
    required this.isSubUnit,
    this.subUnitName,
    this.subUnitQuantity,
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
      'sub_unit_quantity': subUnitQuantity,
    };
  }

  factory OrderItem.fromMap(Map<String, dynamic> map) {
    return OrderItem(
      id: map['id'] as int?,
      orderId: map['order_id'] as int,
      productId: map['product_id'] as int,
      quantity: map['quantity'] as int,
      unitPrice: (map['unit_price'] as num).toDouble(),
      sellingPrice: (map['selling_price'] as num).toDouble(),
      adjustedPrice: (map['adjusted_price'] as num?)?.toDouble() ?? 
                    (map['selling_price'] as num).toDouble(),
      totalAmount: (map['total_amount'] as num).toDouble(),
      productName: map['product_name'] as String,
      isSubUnit: (map['is_sub_unit'] as int?) == 1,
      subUnitName: map['sub_unit_name'] as String?,
      subUnitQuantity: (map['sub_unit_quantity'] as num?)?.toDouble(),
    );
  }

  String get displayName => isSubUnit && subUnitName != null ? 
      '$productName ($subUnitName)' : productName ?? 'Unknown Product';

  double get profit => (sellingPrice - unitPrice) * quantity;

  double get total => totalAmount;
} 