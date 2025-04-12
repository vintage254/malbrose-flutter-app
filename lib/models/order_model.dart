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
        final orderNumber = map['order_number'] as String? ?? 'Unknown';
        print('Raw items_json before parsing: ${map['items_json']}');
        
        // Function to convert map to OrderItem safely
        OrderItem? createOrderItemSafely(Map<String, dynamic> itemData, int orderId) {
          try {
            // Extract values with safe fallbacks
            final productId = itemData['product_id'] is int
                ? itemData['product_id'] as int
                : int.tryParse(itemData['product_id']?.toString() ?? '') ?? 0;
                
            final quantity = itemData['quantity'] is int
                ? itemData['quantity'] as int
                : int.tryParse(itemData['quantity']?.toString() ?? '') ?? 1;
                
            final unitPrice = itemData['unit_price'] is num
                ? (itemData['unit_price'] as num).toDouble()
                : double.tryParse(itemData['unit_price']?.toString() ?? '') ?? 0.0;
                
            final sellingPrice = itemData['selling_price'] is num
                ? (itemData['selling_price'] as num).toDouble()
                : (double.tryParse(itemData['selling_price']?.toString() ?? '') ?? unitPrice);
                
            final productName = itemData['product_name']?.toString() ?? 'Unknown Product';
            
            // Calculate total if not available
            final providedTotal = itemData['total_amount'] is num
                ? (itemData['total_amount'] as num).toDouble()
                : double.tryParse(itemData['total_amount']?.toString() ?? '');
            final totalAmount = providedTotal ?? (sellingPrice * quantity);
            
            // Convert is_sub_unit which might come as int, bool, or string
            bool isSubUnit = false;
            if (itemData['is_sub_unit'] != null) {
              if (itemData['is_sub_unit'] is bool) {
                isSubUnit = itemData['is_sub_unit'] as bool;
              } else if (itemData['is_sub_unit'] is int) {
                isSubUnit = (itemData['is_sub_unit'] as int) == 1;
              } else if (itemData['is_sub_unit'] is String) {
                isSubUnit = (itemData['is_sub_unit'] as String).toLowerCase() == 'true' || 
                          (itemData['is_sub_unit'] as String) == '1';
              }
            }
            
            // Skip invalid items
            if (productId <= 0 || productName.isEmpty || quantity <= 0) {
              print('Skipping invalid item: $itemData');
              return null;
            }
            
            print('Successfully created OrderItem: $productName (ID: $productId, Qty: $quantity)');
            
            return OrderItem(
              id: itemData['id'] is int ? itemData['id'] as int : null,
              orderId: orderId,
              productId: productId,
              quantity: quantity,
              unitPrice: unitPrice,
              sellingPrice: sellingPrice,
              totalAmount: totalAmount,
              productName: productName,
              isSubUnit: isSubUnit,
              subUnitName: itemData['sub_unit_name']?.toString(),
              subUnitQuantity: itemData['sub_unit_quantity'] is num
                  ? (itemData['sub_unit_quantity'] as num).toDouble()
                  : double.tryParse(itemData['sub_unit_quantity']?.toString() ?? ''),
              adjustedPrice: itemData['adjusted_price'] is num
                  ? (itemData['adjusted_price'] as num).toDouble()
                  : double.tryParse(itemData['adjusted_price']?.toString() ?? ''),
            );
          } catch (e) {
            print('Error creating individual OrderItem: $e');
            print('Problem item data: $itemData');
            return null;
          }
        }
        
        // MULTIPLE APPROACHES TO PARSE THE DATA
        final orderId = map['id'] is int ? map['id'] as int : 0;
        var itemsList = <Map<String, dynamic>>[];
        var rawJson = map['items_json'];
        
        // APPROACH 1: Direct List
        if (rawJson is List) {
          print('Approach 1: Processing direct List');
          if (rawJson.isNotEmpty) {
            if (rawJson.first is List) {
              // Handle nested list format: [[{item1}, {item2}]]
              try {
                // Use safer method to extract from nested list
                for (var outerItem in rawJson) {
                  if (outerItem is List) {
                    for (var innerItem in outerItem) {
                      if (innerItem is Map<String, dynamic>) {
                        itemsList.add(innerItem);
                      }
                    }
                  } else if (outerItem is Map<String, dynamic>) {
                    // Sometimes the first item might be a List but others are Maps
                    itemsList.add(outerItem);
                  }
                }
              } catch (e) {
                print('Error processing nested list: $e');
                // Fallback: try to work with the raw list
                for (var item in rawJson) {
                  if (item is Map<String, dynamic>) {
                    itemsList.add(item);
                  }
                }
              }
            } else {
              // Standard list format: [{item1}, {item2}]
              for (var item in rawJson) {
                if (item is Map<String, dynamic>) {
                  itemsList.add(item);
                }
              }
            }
          }
        }
        // APPROACH 2: String parsing
        else if (rawJson is String || rawJson.toString().isNotEmpty) {
          print('Approach 2: Processing string representation');
          String jsonStr = rawJson.toString();
          
          try {
            // Attempt to parse as JSON
            var parsed = json.decode(jsonStr);
            
            if (parsed is List) {
              if (parsed.isNotEmpty && parsed.first is List) {
                // Handle nested list in string: "[[{\"item1\"}, {\"item2\"}]]"
                try {
                  // Handle multi-level nesting more safely
                  for (var outerItem in parsed) {
                    if (outerItem is List) {
                      for (var innerItem in outerItem) {
                        if (innerItem is Map<String, dynamic>) {
                          itemsList.add(innerItem);
                        }
                      }
                    } else if (outerItem is Map<String, dynamic>) {
                      // Sometimes mixed format
                      itemsList.add(outerItem);
                    }
                  }
                } catch (e) {
                  print('Error processing nested JSON list: $e');
                  // Fallback for simple first-level nesting
                  try {
                    List<dynamic> innerList = parsed.first as List<dynamic>;
                    for (var item in innerList) {
                      if (item is Map<String, dynamic>) {
                        itemsList.add(item);
                      }
                    }
                  } catch (e) {
                    print('Fallback also failed: $e');
                  }
                }
              } else {
                // Standard list in string: "[{\"item1\"}, {\"item2\"}]"
                for (var item in parsed) {
                  if (item is Map<String, dynamic>) {
                    itemsList.add(item);
                  }
                }
              }
            } else if (parsed is Map<String, dynamic>) {
              // Single item: "{\"item1\"}"
              itemsList.add(parsed);
            }
          } catch (e) {
            print('Error parsing JSON string: $e');
          }
        }
        
        print('Successfully parsed ${itemsList.length} items from JSON for order $orderNumber');
        
        // Now process the list of items
        for (var itemData in itemsList) {
          final orderItem = createOrderItemSafely(itemData, orderId);
          if (orderItem != null) {
            orderItems.add(orderItem);
          }
        }
      } catch (e) {
        print('Error parsing items_json: $e');
        print('Raw items_json: ${map['items_json']}');
      }
    }

    double totalAmount = (map['total_amount'] as num?)?.toDouble() ?? 0.0;

    // Ensure the total amount matches the sum of item totals
    if (orderItems.isNotEmpty) {
      final calculatedTotal = orderItems.fold<double>(0, (sum, item) => sum + item.totalAmount);
      if (calculatedTotal > 0 && (totalAmount == 0 || (calculatedTotal - totalAmount).abs() > 0.01)) {
        print('Warning: Order total amount ($totalAmount) does not match sum of items ($calculatedTotal). Using calculated total.');
        totalAmount = calculatedTotal;
      }
    }

    return Order(
      id: map['id'] as int?,
      orderNumber: map['order_number'] as String,
      salesReceiptNumber: map['sales_receipt_number'] as String?,
      heldReceiptNumber: map['held_receipt_number'] as String?,
      totalAmount: totalAmount,
      customerName: customerName,
      customerId: (map['customer_id'] as num?)?.toInt(),
      orderStatus: map['order_status'] as String? ?? map['status'] as String? ?? 'PENDING',
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