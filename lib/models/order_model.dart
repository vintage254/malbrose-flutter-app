class Order {
  final int? id;
  final String orderNumber;
  final double totalAmount;
  final String? customerName;
  final int? customerId;
  final String orderStatus;
  final String paymentStatus;
  final String? paymentMethod;
  final int createdBy;
  final DateTime createdAt;
  final DateTime orderDate;
  final List<OrderItem> items;
  final double? adjustedPrice;

  Order({
    this.id,
    required this.orderNumber,
    required this.totalAmount,
    required this.customerName,
    this.customerId,
    this.orderStatus = 'PENDING',
    this.paymentStatus = 'PENDING',
    this.paymentMethod,
    required this.createdBy,
    required this.createdAt,
    required this.orderDate,
    required this.items,
    this.adjustedPrice,
  }) {
    if (customerName == null || customerName!.isEmpty) {
      throw ArgumentError('Customer name is required');
    }
  }

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'order_number': orderNumber,
      'customer_id': customerId,
      'customer_name': customerName ?? '',
      'total_amount': totalAmount,
      'status': orderStatus,
      'payment_status': paymentStatus,
      if (paymentMethod != null) 'payment_method': paymentMethod,
      'created_by': createdBy,
      'created_at': createdAt.toIso8601String(),
      'order_date': orderDate.toIso8601String(),
    };
  }

  factory Order.fromMap(Map<String, dynamic> map, [List<OrderItem>? items]) {
    final customerName = map['customer_name'] as String?;
    if (customerName == null || customerName.isEmpty) {
      throw ArgumentError('Customer name is required');
    }

    return Order(
      id: map['id'],
      orderNumber: map['order_number'],
      totalAmount: (map['total_amount'] as num).toDouble(),
      customerName: customerName,
      customerId: map['customer_id'] as int?,
      orderStatus: map['status'] ?? 'PENDING',
      paymentStatus: map['payment_status'] ?? 'PENDING',
      paymentMethod: map['payment_method'] as String?,
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
  final double totalAmount;
  final String productName;
  final bool isSubUnit;
  final String? subUnitName;
  String? orderNumber;
  DateTime? orderDate;
  final double? subUnitQuantity;
  final double? adjustedPrice;

  OrderItem({
    this.id,
    required this.orderId,
    required this.productId,
    required this.quantity,
    required this.unitPrice,
    required this.sellingPrice,
    required this.totalAmount,
    required this.productName,
    this.isSubUnit = false,
    this.subUnitName,
    this.orderNumber,
    this.orderDate,
    this.subUnitQuantity,
    this.adjustedPrice,
  });

  double get effectivePrice => adjustedPrice ?? 
    (isSubUnit && subUnitQuantity != null ? 
      sellingPrice / subUnitQuantity! : 
      sellingPrice);

  double get effectiveQuantity => isSubUnit && subUnitQuantity != null ?
      quantity / subUnitQuantity! :
      quantity.toDouble();

  double get profit => (effectivePrice - unitPrice) * effectiveQuantity;

  String get displayName => isSubUnit && subUnitName != null ? 
      '$productName ($subUnitName)' : 
      productName;

  factory OrderItem.fromMap(Map<String, dynamic> map) {
    return OrderItem(
      id: map['item_id'] != null ? (map['item_id'] as num).toInt() : null,
      orderId: (map['id'] as num?)?.toInt() ?? 0,
      productId: (map['product_id'] as num?)?.toInt() ?? 0,
      quantity: (map['quantity'] as num?)?.toInt() ?? 0,
      unitPrice: (map['unit_price'] as num?)?.toDouble() ?? 0.0,
      sellingPrice: (map['selling_price'] as num?)?.toDouble() ?? 0.0,
      totalAmount: (map['total_amount'] as num?)?.toDouble() ?? 0.0,
      productName: (map['product_name'] as String?) ?? 'Unknown Product',
      isSubUnit: map['is_sub_unit'] == 1,
      subUnitName: map['sub_unit_name'] as String?,
      orderNumber: map['order_number'] as String?,
      orderDate: map['order_date'] != null ? DateTime.parse(map['order_date'] as String) : null,
      subUnitQuantity: (map['sub_unit_quantity'] as num?)?.toDouble(),
      adjustedPrice: (map['adjusted_price'] as num?)?.toDouble(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'order_id': orderId,
      'product_id': productId,
      'quantity': quantity,
      'unit_price': unitPrice,
      'selling_price': sellingPrice,
      'total_amount': totalAmount,
      'product_name': productName,
      'is_sub_unit': isSubUnit ? 1 : 0,
      if (subUnitName != null) 'sub_unit_name': subUnitName,
      if (subUnitQuantity != null) 'sub_unit_quantity': subUnitQuantity,
      if (adjustedPrice != null) 'adjusted_price': adjustedPrice,
    };
  }
} 