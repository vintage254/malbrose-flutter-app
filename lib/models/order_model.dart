import 'package:my_flutter_app/models/product_model.dart';
import 'dart:convert';

class Order {
  final int? id;
  final String orderNumber;
  final String? salesReceiptNumber;
  final String? heldReceiptNumber;
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
    this.salesReceiptNumber,
    this.heldReceiptNumber,
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
      if (salesReceiptNumber != null) 'sales_receipt_number': salesReceiptNumber,
      if (heldReceiptNumber != null) 'held_receipt_number': heldReceiptNumber,
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

  static Order fromMap(Map<String, dynamic> map) {
    // Handle parsing items
    List<OrderItem> orderItems = [];
    
    try {
      if (map.containsKey('items_json')) {
        final itemsJson = map['items_json'];
        if (itemsJson != null && itemsJson.toString().isNotEmpty) {
          // Try to parse different formats of items_json
          try {
            try {
              // Try to parse as a List<dynamic>
              dynamic itemsList = json.decode(itemsJson.toString());
              
              if (itemsList is List) {
                if (itemsList.isNotEmpty && itemsList[0] is List) {
                  // Handle nested JSON arrays [[{...}]]
                  itemsList = itemsList[0];
                }

                for (var item in itemsList) {
                  if (item is Map<String, dynamic>) {
                    final productId = (item['product_id'] as num?)?.toInt() ?? 0;
                    final quantity = (item['quantity'] as num?)?.toInt() ?? 0;
                    final unitPrice = (item['unit_price'] as num?)?.toDouble() ?? 0.0;
                    final sellingPrice = (item['selling_price'] as num?)?.toDouble() ?? 0.0;
                    final totalAmount = (item['total_amount'] as num?)?.toDouble() ?? 0.0;
                    final productName = item['product_name'] as String? ?? 'Unknown Product';
                    
                    orderItems.add(OrderItem(
                      orderId: map['id'] as int? ?? 0,
                      productId: productId,
                      quantity: quantity,
                      unitPrice: unitPrice,
                      sellingPrice: sellingPrice,
                      totalAmount: totalAmount,
                      productName: productName,
                      isSubUnit: item['is_sub_unit'] == 1,
                      subUnitName: item['sub_unit_name'] as String?,
                      subUnitQuantity: (item['sub_unit_quantity'] as num?)?.toDouble(),
                      adjustedPrice: (item['adjusted_price'] as num?)?.toDouble(),
                    ));
                  }
                }
              }
            } catch (e) {
              print('Error parsing items_json as List: $e');
            }
          } catch (e) {
            print('Error parsing items_json: $e');
          }
        }
      }
    } catch (e) {
      print('Error processing items_json: $e');
    }

    // Handle customer name - use non-null default if original is null/empty
    String? customerName = map['customer_name'] as String?;
    if (customerName == null || customerName.isEmpty) {
      customerName = 'Walk-in Customer';
    }

    // Calculate total from items if available or use the provided total
    double totalAmount = 0.0;
    if (orderItems.isNotEmpty) {
      // Sum up individual item totals
      totalAmount = orderItems.fold<double>(
        0, 
        (sum, item) => sum + item.totalAmount
      );
    } else {
      // Fallback to the total in the order if no items
      totalAmount = map['total_amount'] != null ? 
                    (map['total_amount'] as num).toDouble() : 
                    0.0;
    }
    
    // Explicitly prioritize order_status over the deprecated status field
    // Status field is planned to be removed in future updates
    final orderStatus = map['order_status'] as String? ?? 
                       map['status'] as String? ?? // Fallback to status field (deprecated)
                       'PENDING';
    
    return Order(
      id: map['id'] as int?,
      orderNumber: map['order_number'] as String,
      salesReceiptNumber: map['sales_receipt_number'] as String?,
      heldReceiptNumber: map['held_receipt_number'] as String?,
      totalAmount: totalAmount,
      customerName: customerName,
      customerId: (map['customer_id'] as num?)?.toInt(),
      orderStatus: orderStatus,
      paymentStatus: map['payment_status'] as String? ?? 'PENDING',
      paymentMethod: map['payment_method'] as String?,
      createdBy: (map['created_by'] as num?)?.toInt() ?? 1,
      createdAt: DateTime.parse(map['created_at'] as String),
      orderDate: DateTime.parse(map['order_date'] as String),
      items: orderItems,
      adjustedPrice: (map['adjusted_price'] as num?)?.toDouble(),
    );
  }

  double get totalProfit => items.fold(0, (sum, item) => sum + item.profit);

  String get itemsDisplay => items.map((item) {
    final unitText = item.isSubUnit ? 
        ' (${item.quantity} ${item.subUnitName ?? "pieces"})' : 
        ' (${item.quantity} units)';
    return '${item.displayName}$unitText';
  }).join(", ");

  // Method to create a copy of an Order with optional updated fields
  Order copyWith({
    int? id,
    String? orderNumber,
    String? salesReceiptNumber,
    String? heldReceiptNumber,
    double? totalAmount,
    String? customerName,
    int? customerId,
    String? orderStatus,
    String? paymentStatus,
    String? paymentMethod,
    int? createdBy,
    DateTime? createdAt,
    DateTime? orderDate,
    List<OrderItem>? items,
    double? adjustedPrice,
  }) {
    return Order(
      id: id ?? this.id,
      orderNumber: orderNumber ?? this.orderNumber,
      salesReceiptNumber: salesReceiptNumber ?? this.salesReceiptNumber,
      heldReceiptNumber: heldReceiptNumber ?? this.heldReceiptNumber,
      totalAmount: totalAmount ?? this.totalAmount,
      customerName: customerName ?? this.customerName,
      customerId: customerId ?? this.customerId,
      orderStatus: orderStatus ?? this.orderStatus,
      paymentStatus: paymentStatus ?? this.paymentStatus,
      paymentMethod: paymentMethod ?? this.paymentMethod,
      createdBy: createdBy ?? this.createdBy,
      createdAt: createdAt ?? this.createdAt,
      orderDate: orderDate ?? this.orderDate,
      items: items ?? this.items,
      adjustedPrice: adjustedPrice ?? this.adjustedPrice,
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

  double get effectivePrice => adjustedPrice ?? sellingPrice;

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
      if (orderNumber != null) 'order_number': orderNumber,
      if (orderDate != null) 'order_date': orderDate!.toIso8601String(),
      'created_at': DateTime.now().toIso8601String(),
    };
  }

  // Convert OrderItem to Product model for cart items
  Product toProductModel() {
    return Product(
      id: productId,
      productName: productName,
      supplier: '',
      receivedDate: DateTime.now(),
      description: '',
      buyingPrice: unitPrice,
      sellingPrice: adjustedPrice ?? sellingPrice,
      quantity: quantity,
      hasSubUnits: isSubUnit,
      subUnitName: subUnitName,
      subUnitQuantity: subUnitQuantity?.toInt(),
      subUnitPrice: isSubUnit ? sellingPrice : null,
      department: Product.deptLubricants, // Default department
    );
  }

  // Add a copyWith method to the OrderItem class
  OrderItem copyWith({
    int? id,
    int? orderId,
    int? productId,
    int? quantity,
    double? unitPrice,
    double? sellingPrice,
    double? totalAmount,
    String? productName,
    bool? isSubUnit,
    String? subUnitName,
    String? orderNumber,
    DateTime? orderDate,
    double? subUnitQuantity,
    double? adjustedPrice,
  }) {
    return OrderItem(
      id: id ?? this.id,
      orderId: orderId ?? this.orderId,
      productId: productId ?? this.productId,
      quantity: quantity ?? this.quantity,
      unitPrice: unitPrice ?? this.unitPrice,
      sellingPrice: sellingPrice ?? this.sellingPrice,
      totalAmount: totalAmount ?? this.totalAmount,
      productName: productName ?? this.productName,
      isSubUnit: isSubUnit ?? this.isSubUnit,
      subUnitName: subUnitName ?? this.subUnitName,
      orderNumber: orderNumber ?? this.orderNumber,
      orderDate: orderDate ?? this.orderDate,
      subUnitQuantity: subUnitQuantity ?? this.subUnitQuantity,
      adjustedPrice: adjustedPrice ?? this.adjustedPrice,
    );
  }
}