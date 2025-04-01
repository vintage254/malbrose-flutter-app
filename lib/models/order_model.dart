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

  factory Order.fromMap(Map<String, dynamic> map) {
    final customerName = map['customer_name'] as String?;
    if (customerName == null || customerName.isEmpty) {
      throw ArgumentError('Customer name is required');
    }

    // Parse items from items_json if present
    List<OrderItem> orderItems = [];
    if (map['items_json'] != null) {
      try {
        print('Raw items_json before parsing: ${map['items_json']}');
        
        // Parse the JSON array string
        final String jsonStr = map['items_json'].toString();
        
        // If it's already a list (from json_group_array), process directly
        if (jsonStr.startsWith('[') && jsonStr.endsWith(']')) {
          // Parse the JSON array
          final List<dynamic> itemsList = json.decode(jsonStr);
          
          print('Processing ${itemsList.length} items from JSON array');
          
          for (var itemData in itemsList) {
            try {
              // Ensure we have valid product data
              if (itemData['product_id'] != null && 
                  itemData['product_id'] is int &&
                  itemData['product_id'] > 0 &&
                  itemData['quantity'] != null &&
                  itemData['quantity'] is int &&
                  itemData['quantity'] > 0 &&
                  itemData['product_name'] != null &&
                  itemData['product_name'].toString().isNotEmpty) {
                
                print('Creating OrderItem: ${itemData['product_name']} (ID: ${itemData['product_id']}, Qty: ${itemData['quantity']})');
                
                orderItems.add(OrderItem(
                  id: itemData['item_id'] as int?,
                  orderId: map['id'] as int,
                  productId: itemData['product_id'] as int,
                  quantity: itemData['quantity'] as int,
                  unitPrice: (itemData['unit_price'] as num).toDouble(),
                  sellingPrice: (itemData['selling_price'] as num).toDouble(),
                  totalAmount: (itemData['total_amount'] as num).toDouble(),
                  productName: itemData['product_name'] as String,
                  isSubUnit: itemData['is_sub_unit'] == 1,
                  subUnitName: itemData['sub_unit_name'] as String?,
                  subUnitQuantity: (itemData['sub_unit_quantity'] as num?)?.toDouble(),
                  adjustedPrice: (itemData['adjusted_price'] as num?)?.toDouble(),
                ));
              } else {
                print('Skipping invalid item data: $itemData');
              }
            } catch (e) {
              print('Error creating OrderItem from data: $e');
              print('Item data: $itemData');
            }
          }
        }
      } catch (e) {
        print('Error parsing items_json: $e');
        print('Raw items_json: ${map['items_json']}');
      }
    }

    // Calculate total amount from items if not provided
    final totalAmount = map['total_amount'] != null ? 
      (map['total_amount'] as num).toDouble() :
      orderItems.fold<double>(0, (sum, item) => sum + item.totalAmount);

    return Order(
      id: map['id'] as int?,
      orderNumber: map['order_number'] as String,
      salesReceiptNumber: map['sales_receipt_number'] as String?,
      heldReceiptNumber: map['held_receipt_number'] as String?,
      totalAmount: totalAmount,
      customerName: customerName,
      customerId: map['customer_id'] as int?,
      orderStatus: map['status'] as String? ?? 'PENDING',
      paymentStatus: map['payment_status'] as String? ?? 'PENDING',
      paymentMethod: map['payment_method'] as String?,
      createdBy: (map['created_by'] as num?)?.toInt() ?? 1,
      createdAt: DateTime.parse(map['created_at'] as String),
      orderDate: DateTime.parse(map['order_date'] as String),
      items: orderItems,
      adjustedPrice: (map['adjusted_price'] as num?)?.toDouble(),
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