import 'package:flutter/foundation.dart';
import 'package:my_flutter_app/models/order_model.dart';
import 'package:my_flutter_app/services/database.dart';
import 'package:my_flutter_app/services/database_extensions.dart';
import 'package:my_flutter_app/services/product_service.dart';
import 'package:my_flutter_app/services/auth_service.dart';
import 'package:intl/intl.dart';
import 'dart:convert';

class OrderService extends ChangeNotifier {
  static final OrderService instance = OrderService._internal();
  OrderService._internal();

  // Add table definitions
  static const String tableOrders = DatabaseService.tableOrders;
  static const String tableOrderItems = DatabaseService.tableOrderItems;
  static const String tableProducts = DatabaseService.tableProducts;
  static const String tableActivityLogs = DatabaseService.tableActivityLogs;

  // Private fields for tracking statistics
  int _todayOrders = 0;
  double _todaySales = 0.0;
  int _totalOrders = 0;
  double _totalSales = 0.0;
  int _pendingOrdersCount = 0;
  List<Map<String, dynamic>> _recentOrders = [];
  final List<Map<String, dynamic>> _pendingOrders = [];

  // Public getters
  int get todayOrders => _todayOrders;
  double get todaySales => _todaySales;
  int get totalOrders => _totalOrders;
  double get totalSales => _totalSales;
  int get pendingOrdersCount => _pendingOrdersCount;
  List<Map<String, dynamic>> get recentOrders => _recentOrders;
  List<Map<String, dynamic>> get pendingOrders => _pendingOrders;

  String get currentDate => DateFormat('EEEE, MMMM d, y').format(DateTime.now());

  Future<void> refreshStats() async {
    try {
      await DatabaseService.instance.withTransaction((txn) async {
        final todayStart = DateTime.now().copyWith(
          hour: 0, 
          minute: 0, 
          second: 0, 
          millisecond: 0
        );
        
        // Get all stats in a single query with proper status filtering
        final stats = await txn.rawQuery('''
          SELECT 
            (SELECT COUNT(*) FROM $tableOrders 
             WHERE DATE(created_at) = DATE(?) 
             AND order_status = 'COMPLETED') as completed_today,
            (SELECT SUM(total_amount) FROM $tableOrders 
             WHERE DATE(created_at) = DATE(?) 
             AND order_status = 'COMPLETED') as today_sales,
            (SELECT COUNT(*) FROM $tableOrders 
             WHERE order_status = 'PENDING') as pending_count,
            (SELECT COUNT(*) FROM $tableOrders) as total_orders,
            (SELECT SUM(total_amount) FROM $tableOrders 
             WHERE order_status = 'COMPLETED') as total_sales
        ''', [
          todayStart.toIso8601String(),
          todayStart.toIso8601String(),
        ]);
        
        final result = stats.first;
        _todayOrders = result['completed_today'] as int? ?? 0;
        _todaySales = result['today_sales'] as double? ?? 0.0;
        _pendingOrdersCount = result['pending_count'] as int? ?? 0;
        _totalOrders = result['total_orders'] as int? ?? 0;
        _totalSales = result['total_sales'] as double? ?? 0.0;

        // Get recent orders with detailed information
        _recentOrders = await txn.rawQuery('''
          SELECT 
            o.*,
            json_group_array(
              json_object(
                'product_id', oi.product_id,
                'quantity', oi.quantity,
                'unit_price', oi.unit_price,
                'selling_price', oi.selling_price,
                'total_amount', oi.total_amount,
                'product_name', p.product_name
              )
            ) as items_json
          FROM $tableOrders o
          LEFT JOIN $tableOrderItems oi ON o.id = oi.order_id
          LEFT JOIN $tableProducts p ON oi.product_id = p.id
          WHERE DATE(o.created_at) = DATE(?)
          GROUP BY o.id
          ORDER BY o.created_at DESC
        ''', [todayStart.toIso8601String()]);
      });
      
      notifyListeners();
    } catch (e) {
      debugPrint('Error refreshing stats: $e');
    }
  }

  void notifyOrderUpdate() {
    refreshStats();
  }

  Future<Map<String, List<Map<String, dynamic>>>> getOrdersByStatus(String status) async {
    final db = await DatabaseService.instance.database;
    
    // Get orders with the given status, excluding REVERTED/CONVERTED orders
    final List<Map<String, dynamic>> orders = await db.rawQuery('''
      SELECT o.*, json_array(json_group_array(json_object(
        'id', oi.id, 
        'product_id', oi.product_id, 
        'product_name', oi.product_name, 
        'quantity', oi.quantity, 
        'unit_price', oi.unit_price, 
        'selling_price', oi.selling_price,
        'total_amount', oi.total_amount,
        'is_sub_unit', oi.is_sub_unit))) as items_json
      FROM ${DatabaseService.tableOrders} o
      LEFT JOIN ${DatabaseService.tableOrderItems} oi ON o.id = oi.order_id
      WHERE o.order_status = ?
        AND o.order_status NOT IN ('REVERTED', 'CONVERTED') -- Exclude reverted/converted orders
      GROUP BY o.id
      ORDER BY o.created_at DESC
    ''', [status]);
    
    // If requesting PENDING orders and we want to include held orders (optional)
    // Modified to only include ON_HOLD orders that don't have PENDING duplicates
    final List<Map<String, dynamic>> heldOrders = (status == 'PENDING') ? 
      await db.rawQuery('''
        SELECT o.*, json_array(json_group_array(json_object(
          'id', oi.id, 
          'product_id', oi.product_id, 
          'product_name', oi.product_name, 
          'quantity', oi.quantity, 
          'unit_price', oi.unit_price, 
          'selling_price', oi.selling_price,
          'total_amount', oi.total_amount,
          'is_sub_unit', oi.is_sub_unit))) as items_json
        FROM ${DatabaseService.tableOrders} o
        LEFT JOIN ${DatabaseService.tableOrderItems} oi ON o.id = oi.order_id
        WHERE o.order_status = 'ON_HOLD'
          -- Skip held orders that have PENDING/COMPLETED duplicates
          AND NOT EXISTS (
            SELECT 1 FROM ${DatabaseService.tableOrders} o2
            WHERE o2.order_number = REPLACE(o.order_number, 'HLD-', 'ORD-')
            AND o2.order_status IN ('PENDING', 'COMPLETED', 'CONVERTED')
          )
        GROUP BY o.id
        ORDER BY o.created_at DESC
      ''') : [];

    // When returning orders, ensure no duplicate order numbers
    // Create a map to track seen order numbers (without prefix)
    final Map<String, bool> seenOrderNumbers = {};
    final List<Map<String, dynamic>> dedupedOrders = [];

    // Process pending orders first (they take priority)
    for (var order in orders) {
      final rawNumber = order['order_number'] as String;
      final baseNumber = rawNumber.replaceFirst(RegExp(r'^(ORD-|HLD-)'), '');
      
      if (!seenOrderNumbers.containsKey(baseNumber)) {
        seenOrderNumbers[baseNumber] = true;
        dedupedOrders.add(order);
      }
    }

    // Then process held orders, skipping any with same base number as pending orders
    final List<Map<String, dynamic>> dedupedHeldOrders = [];
    for (var order in heldOrders) {
      final rawNumber = order['order_number'] as String;
      final baseNumber = rawNumber.replaceFirst(RegExp(r'^(ORD-|HLD-)'), '');
      
      if (!seenOrderNumbers.containsKey(baseNumber)) {
        seenOrderNumbers[baseNumber] = true;
        dedupedHeldOrders.add(order);
      }
    }

    return {
      'pendingOrders': dedupedOrders,
      'heldOrders': dedupedHeldOrders
    };
  }

  Future<List<Order>> getUnreportedOrders() async {
    final db = await DatabaseService.instance.database;
    final List<Map<String, dynamic>> maps = await db.query(
      'orders',
      where: 'order_status != ?',
      whereArgs: ['REPORTED'],
      orderBy: 'created_at DESC',
    );

    return List.generate(maps.length, (i) {
      return Order.fromMap(maps[i]);
    });
  }

  // ADDED ORDER STATUS MANAGEMENT METHODS
  
  // Constants for order status
  static const String STATUS_PENDING = 'PENDING';
  static const String STATUS_COMPLETED = 'COMPLETED';
  static const String STATUS_ON_HOLD = 'ON_HOLD';
  static const String STATUS_REPORTED = 'REPORTED';
  
  // Log order creation activity
  Future<void> logOrderCreation(Order order) async {
    try {
      final currentUser = AuthService.instance.currentUser;
      if (currentUser != null) {
        await DatabaseService.instance.logActivity(
          currentUser.id!,
          currentUser.username,
          'create_order',
          'Order Creation',
          'Created order #${order.orderNumber} with ${order.items.length} items, total: KSH ${order.totalAmount?.toStringAsFixed(2)}',
        );
      }
    } catch (e) {
      debugPrint('Error logging order creation: $e');
    }
  }
  
  // Log order update activity
  Future<void> logOrderUpdate(Order order, {String? updateDetails}) async {
    try {
      final currentUser = AuthService.instance.currentUser;
      if (currentUser != null) {
        await DatabaseService.instance.logActivity(
          currentUser.id!,
          currentUser.username,
          'update_order',
          'Order Update',
          'Updated order #${order.orderNumber}: ${updateDetails ?? "Modified order details"}',
        );
      }
    } catch (e) {
      debugPrint('Error logging order update: $e');
    }
  }
  
  // Log order deletion activity
  Future<void> logOrderDeletion(String orderNumber, {String? reason}) async {
    try {
      final currentUser = AuthService.instance.currentUser;
      if (currentUser != null) {
        await DatabaseService.instance.logActivity(
          currentUser.id!,
          currentUser.username,
          'delete_order',
          'Order Deletion',
          'Deleted order #$orderNumber${reason != null ? ". Reason: $reason" : ""}',
        );
      }
    } catch (e) {
      debugPrint('Error logging order deletion: $e');
    }
  }

  // Create a new order with validation of product IDs
  Future<bool> createOrder(Map<String, dynamic> orderMap, List<Map<String, dynamic>> orderItems) async {
    try {
      final String orderNumber = orderMap['order_number'] as String;
      debugPrint('ORDER WORKFLOW: Processing order #$orderNumber with status ${orderMap['order_status']}');

      // Enhanced detection for edit mode
      final bool isEdit = orderMap.containsKey('id') && orderMap['id'] != null;
      
      // Fix ID handling to ensure consistent type
      final int? orderId = isEdit ? (orderMap['id'] is int 
          ? orderMap['id'] as int 
          : int.tryParse(orderMap['id'].toString())) : null;

      if (isEdit) {
        debugPrint('ORDER WORKFLOW: Edit mode detected with ID: $orderId');
        
        // Ensure ID is correctly set for database update
        if (orderId != null) {
          orderMap['id'] = orderId;
        } else {
          debugPrint('WARNING: Invalid order ID format: ${orderMap['id']}');
          throw Exception('Invalid order ID or data type');
        }
      }
      
      // Validate product IDs in all order items
      for (final item in orderItems) {
        final productId = item['product_id'] as int?;
        if (productId == null || productId <= 0) {
          debugPrint('Warning: Invalid product ID detected: $productId');
          // Try to find a valid product by name
          final productName = item['product_name'] as String?;
          if (productName != null && productName.isNotEmpty) {
            final products = await DatabaseService.instance.getProductByName(productName);
            if (products.isNotEmpty) {
              final validProductId = products.first['id'] as int;
              item['product_id'] = validProductId;
              debugPrint('Fixed product ID for "$productName": now $validProductId');
            } else {
              throw Exception('Invalid product ID and could not find a replacement for "$productName"');
            }
          } else {
            throw Exception('Invalid product ID and no product name provided');
          }
        }
      }
      
      bool success;
      int newOrderId;
      
      // If we're editing, use updateOrder instead of createOrder
      if (isEdit) {
        // When updating, respect the order_status in the update map
        success = await DatabaseService.instance.updateOrder(orderMap, orderItems);
        newOrderId = orderId!;
        
        // Log order update with status info
        if (success) {
          final orderStatus = orderMap['order_status'] as String? ?? 'UNKNOWN';
          final order = Order.fromMap({...orderMap, 'id': newOrderId});
          await logOrderUpdate(
            order, 
            updateDetails: "Updated order details with status: $orderStatus"
          );
        }
      } else {
        final result = await DatabaseService.instance.createOrder(orderMap, orderItems);
        // Check if result is a map and extract the ID, or handle error
        if (result != null && result is Map<String, dynamic> && result.containsKey('id')) {
          newOrderId = result['id'] as int;
          success = newOrderId > 0;
          
          // Log order creation with status info
          if (success) {
            final orderStatus = orderMap['order_status'] as String? ?? 'UNKNOWN';
            final order = Order.fromMap({...orderMap, 'id': newOrderId});
            await logOrderCreation(order);
            debugPrint('Created order #${order.orderNumber} with status: $orderStatus');
          }
        } else {
          // Handle error - result is null or doesn't have ID
          debugPrint('Error: createOrder returned invalid result');
          success = false;
          newOrderId = -1;
        }
      }
      
      refreshStats();
      return success;
    } catch (e) {
      debugPrint('Error in OrderService.createOrder: $e');
      return false;
    }
  }
  
  // Create a held order
  Future<bool> createHeldOrder(Map<String, dynamic> orderMap, List<Map<String, dynamic>> orderItems) async {
    // Ensure order status is set to ON_HOLD
    orderMap['order_status'] = STATUS_ON_HOLD;
    orderMap['status'] = STATUS_ON_HOLD; // Also set status field for backward compatibility
    
    // If order number doesn't start with HLD-, make sure it does
    if (orderMap.containsKey('order_number') && 
        orderMap['order_number'] is String && 
        !orderMap['order_number'].toString().startsWith('HLD-')) {
      
      // If it starts with ORD-, replace the prefix, otherwise just prepend HLD-
      if (orderMap['order_number'].toString().startsWith('ORD-')) {
        orderMap['order_number'] = 'HLD-' + orderMap['order_number'].toString().substring(4);
      } else {
        orderMap['order_number'] = 'HLD-' + orderMap['order_number'].toString();
      }
      
      debugPrint('OrderService: Modified order number to ${orderMap['order_number']}');
    }
    
    // Log additional debug information
    debugPrint('OrderService.createHeldOrder: Processing held order with data:');
    debugPrint('  - Order ID: ${orderMap['id']}');
    debugPrint('  - Order Number: ${orderMap['order_number']}');
    debugPrint('  - Status: ${orderMap['order_status']}');
    
    return await createOrder(orderMap, orderItems);
  }
  
  // Update order status with validation
  Future<bool> updateOrderStatus(int orderId, String status) async {
    try {
      if (status != STATUS_PENDING && 
          status != STATUS_ON_HOLD && 
          status != STATUS_COMPLETED && 
          status != STATUS_REPORTED) {
        throw Exception('Invalid order status: $status');
      }
      
      final success = await DatabaseService.instance.updateOrderStatus(orderId, status);
      if (success) {
        notifyListeners();
      }
      return success;
    } catch (e) {
      debugPrint('Error updating order status in OrderService: $e');
      return false;
    }
  }
  
  // Restore a held order to pending
  Future<bool> restoreHeldOrder(Order order) async {
    try {
      if (order.id == null) {
        throw Exception('Order ID is null for held order restoration');
      }

      final db = await DatabaseService.instance.database;

      // Start a transaction for consistency
      return await db.transaction((txn) async {
        // Fetch currentUser ONCE at the start of the transaction
        final currentUser = AuthService.instance.currentUser;

        // First check if order exists and get its current status
        final orderCheck = await txn.query(
          tableOrders,
          where: 'id = ?',
          whereArgs: [order.id],
          limit: 1,
        );

        if (orderCheck.isEmpty) {
          debugPrint('Held order ID ${order.id} not found during restore attempt.');
          return false; // Indicate failure - order doesn't exist
        }

        final currentStatus = orderCheck.first['order_status'] as String? ??
                            orderCheck.first['status'] as String? ??
                            'UNKNOWN';
        final originalOrderNumber = orderCheck.first['order_number'] as String;

        // If order is not actually ON_HOLD, stop
        if (currentStatus != STATUS_ON_HOLD) {
          debugPrint('Order #$originalOrderNumber (ID: ${order.id}) is not ON_HOLD (Status: $currentStatus). Cannot restore.');
          // If already processed, consider it a success
          return currentStatus == STATUS_PENDING || currentStatus == STATUS_COMPLETED || currentStatus == 'CONVERTED';
        }

        // Generate the target ORD-... number
        String newOrderNumber = originalOrderNumber.startsWith('HLD-')
            ? 'ORD-' + originalOrderNumber.substring(4)
            : originalOrderNumber;

        // Check if the target ORD-... number already exists for a DIFFERENT order
        final existingOrdOrder = await txn.query(
          tableOrders,
          where: 'order_number = ? AND id != ?',
          whereArgs: [newOrderNumber, order.id],
          limit: 1,
        );

        // CASE 1: Duplicate ORD-... order FOUND
        if (existingOrdOrder.isNotEmpty) {
          debugPrint('Order #$newOrderNumber already exists (ID: ${existingOrdOrder.first['id']}). Marking original HLD order ${order.id} as CONVERTED.');

          // Mark the original HLD order as CONVERTED
          await txn.update(
            tableOrders,
            {
              'status': 'CONVERTED',
              'order_status': 'CONVERTED',
              'updated_at': DateTime.now().toIso8601String()
            },
            where: 'id = ?',
            whereArgs: [order.id],
          );

          // Log that the HLD order was linked/superseded
          if (currentUser != null) {
            await txn.insert(
              tableActivityLogs,
              {
                'user_id': currentUser.id ?? 0,
                'username': currentUser.username,
                'action': 'link_held_to_existing',
                'action_type': 'Restore Held Order',
                'details': 'Held order #$originalOrderNumber (ID: ${order.id}) found existing active order #$newOrderNumber (ID: ${existingOrdOrder.first['id']}). Marked held order as CONVERTED.',
                'timestamp': DateTime.now().toIso8601String(),
              },
            );
          }
          // No notify for pending orders, as no new pending order was made
          return true; // Handled successfully (duplicate existed)

        // CASE 2: No Duplicate ORD-... order found
        } else {
          debugPrint('Converting held order #$originalOrderNumber (ID: ${order.id}) to active order #$newOrderNumber');

          // Update the original HLD order record to become the new PENDING order
          await txn.update(
            tableOrders,
            {
              'order_number': newOrderNumber,
              'status': STATUS_PENDING,
              'order_status': STATUS_PENDING,
              'updated_at': DateTime.now().toIso8601String()
            },
            where: 'id = ?',
            whereArgs: [order.id],
          );

          // Log the successful restoration
          if (currentUser != null) {
            await txn.insert(
              tableActivityLogs,
              {
                'user_id': currentUser.id ?? 0,
                'username': currentUser.username,
                'action': 'restore_held_order',
                'action_type': 'Restore Held Order',
                'details': 'Restored held order #$originalOrderNumber to active order #$newOrderNumber (ID: ${order.id})',
                'timestamp': DateTime.now().toIso8601String(),
              },
            );
          }
          
          // Notify listeners because a new PENDING order is now available
          notifyListeners();
          return true; // Indicate successful restoration
        }
      }); // End of transaction
    } catch (e) {
      debugPrint('Error restoring held order ID ${order.id} in OrderService: $e');
      return false; // Indicate failure
    }
  }

  // Complete a sale
  Future<bool> completeSale(Order order, {String paymentMethod = 'Cash'}) async {
    try {
      print("|||||||||| ORDER SERVICE - SALE COMPLETION START ||||||||||");
      print("|||||||||| ORDER #${order.orderNumber}: PAYMENT METHOD = '$paymentMethod'");
      print("|||||||||| ORDER #${order.orderNumber}: PAYMENT STATUS FROM ORDER = '${order.paymentStatus}'");
      print("|||||||||| ORDER #${order.orderNumber}: PAYMENT METHOD FROM ORDER = '${order.paymentMethod}'");
      
      if (order.id == null) {
        print("|||||||||| ORDER #${order.orderNumber}: ERROR - Order ID is null");
        throw Exception('Order ID is null');
      }
      
      // First validate all product IDs
      print("|||||||||| ORDER #${order.orderNumber}: VALID ITEMS = ${order.items.where((item) => item.productId > 0).length} / ${order.items.length}");
      
      // Handle credit payment and split payments with credit component
      if (paymentMethod == 'Credit' || paymentMethod.toLowerCase().contains('credit')) {
        print("|||||||||| ORDER #${order.orderNumber}: CREDIT PAYMENT FLOW DETECTED");
        
        // Make sure customer is valid
        if (order.customerId == null || order.customerId! <= 0) {
          print("|||||||||| ORDER #${order.orderNumber}: ERROR - Invalid customer ID for credit payment");
          throw Exception('Credit payment requires a valid customer account');
        }
        
        if (order.customerName == null || order.customerName!.isEmpty) {
          print("|||||||||| ORDER #${order.orderNumber}: ERROR - Invalid customer name for credit payment");
          throw Exception('Credit payment requires a valid customer name');
        }
        
        // Parse out the credit amount for split payments
        double creditAmount = order.totalAmount ?? 0;
        
        // For split payments, calculate the remaining credit amount
        if (paymentMethod.contains('+') || paymentMethod.contains(':')) {
          print("|||||||||| ORDER #${order.orderNumber}: SPLIT PAYMENT DETECTED: '$paymentMethod'");
          
          // Try to parse the credit amount from the payment method string
          try {
            // Format example: "Cash: KSH 900.00, Credit: KSH 6000.00"
            if (paymentMethod.contains(':')) {
              final parts = paymentMethod.split(',');
              for (final part in parts) {
                if (part.toLowerCase().contains('credit')) {
                  final creditPart = part.trim();
                  final amountStr = creditPart.split('KSH').last.trim();
                  creditAmount = double.parse(amountStr);
                  print("|||||||||| ORDER #${order.orderNumber}: PARSED CREDIT AMOUNT = $creditAmount");
                  break;
                }
              }
            }
          } catch (e) {
            print("|||||||||| ORDER #${order.orderNumber}: ERROR PARSING CREDIT AMOUNT - $e");
            // Keep the default (full amount) if parsing fails
          }
          
          // Split payments with credit have PARTIAL status
          final paymentStatus = 'PARTIAL';
          print("|||||||||| ORDER #${order.orderNumber}: SETTING PAYMENT STATUS TO '$paymentStatus' FOR SPLIT PAYMENT");
        }
        
        // Create a copy of the order with appropriate payment method and status
        final String finalPaymentStatus = paymentMethod.toLowerCase().contains('credit') && 
                                    paymentMethod != 'Credit' ? 'PARTIAL' : 'CREDIT';
                                    
        print("|||||||||| ORDER #${order.orderNumber}: CALCULATED PAYMENT STATUS = '$finalPaymentStatus'");
        
        final creditOrder = order.copyWith(
          paymentMethod: paymentMethod,
          paymentStatus: finalPaymentStatus,
        );
        
        print("|||||||||| ORDER #${order.orderNumber}: CREATED CREDIT ORDER WITH PAYMENT STATUS = '${creditOrder.paymentStatus}'");
        print("|||||||||| ORDER #${order.orderNumber}: CREATED CREDIT ORDER WITH PAYMENT METHOD = '${creditOrder.paymentMethod}'");
        
        // Complete the sale via DatabaseService
        print("|||||||||| ORDER #${order.orderNumber}: CALLING DATABASE SERVICE completeSale");
        await DatabaseService.instance.completeSale(creditOrder, paymentMethod: paymentMethod);
        
        // Create credit record for customer
        print("|||||||||| ORDER #${order.orderNumber}: CREATING CREDITOR RECORD FOR CUSTOMER ID ${creditOrder.customerId}");
        await DatabaseService.instance.addCreditorRecordForOrder(
          creditOrder.customerId!,
          creditOrder.customerName!,
          creditOrder.id!,
          creditOrder.orderNumber,
          creditAmount,
          details: 'Credit sale transaction',
          orderDetailsSummary: 'Full credit purchase for order #${creditOrder.orderNumber}'
        );
        
        // Refresh stats before notifying listeners to ensure UI updates with latest data
        await refreshStats();
        notifyListeners();
        print("|||||||||| ORDER #${order.orderNumber}: CREDIT PAYMENT FLOW COMPLETED SUCCESSFULLY");
        print("|||||||||| ORDER SERVICE - SALE COMPLETION END ||||||||||");
        return true;
      } else {
        // Regular non-credit sale with full payment
        print("|||||||||| ORDER #${order.orderNumber}: STANDARD PAYMENT FLOW DETECTED");
        
        // Create updated order with PAID status
        final updatedOrder = order.copyWith(
          orderStatus: 'COMPLETED',
          paymentStatus: order.paymentStatus ?? 'PAID', // Use existing status if available, otherwise PAID
          paymentMethod: paymentMethod,
        );
        
        print("|||||||||| ORDER #${order.orderNumber}: CREATED UPDATED ORDER WITH PAYMENT STATUS = '${updatedOrder.paymentStatus}'");
        print("|||||||||| ORDER #${order.orderNumber}: CREATED UPDATED ORDER WITH PAYMENT METHOD = '${updatedOrder.paymentMethod}'");
        
        try {
          // Update product quantities safely without using last_updated field
          for (var item in updatedOrder.items) {
            if (item.productId <= 0) continue;
            
            // Get current product quantity
            final productDetails = await DatabaseService.instance.getProductById(item.productId);
            if (productDetails == null) {
              print("|||||||||| ORDER #${order.orderNumber}: WARNING - Product ${item.productId} not found");
              continue;
            }
            
            final currentQuantity = (productDetails['quantity'] as num?)?.toDouble() ?? 0;
            
            // Calculate quantity to deduct
            double quantityToDeduct;
            if (item.isSubUnit) {
              final subUnitQuantity = (productDetails['sub_unit_quantity'] as num?)?.toDouble() ?? 1.0;
              if (subUnitQuantity <= 0) {
                quantityToDeduct = item.quantity.toDouble();
              } else {
                quantityToDeduct = (item.quantity / subUnitQuantity);
              }
            } else {
              quantityToDeduct = item.quantity.toDouble();
            }
            
            // Calculate new quantity
            final newQuantity = currentQuantity - quantityToDeduct;
            
            // Update product quantity directly in database without using last_updated field
            final db = await DatabaseService.instance.database;
            await db.update(
              tableProducts,
              {
                'quantity': newQuantity,
                'updated_at': DateTime.now().toIso8601String(),
              },
              where: 'id = ?',
              whereArgs: [item.productId],
            );
          }
          
          // Complete the order - updating status
          print("|||||||||| ORDER #${order.orderNumber}: CALLING DATABASE SERVICE completeSale (standard flow)");
          await DatabaseService.instance.completeSale(updatedOrder, paymentMethod: paymentMethod);
          
          // Refresh stats before notifying listeners to ensure UI updates with latest data
          await refreshStats();
          notifyListeners();
          print("|||||||||| ORDER #${order.orderNumber}: STANDARD PAYMENT FLOW COMPLETED SUCCESSFULLY");
          print("|||||||||| ORDER SERVICE - SALE COMPLETION END ||||||||||");
          return true;
        } catch (e) {
          print("|||||||||| ORDER #${order.orderNumber}: ERROR UPDATING QUANTITIES - $e");
          
          // Try again with a more basic approach
          try {
            final db = await DatabaseService.instance.database;
            for (var item in updatedOrder.items) {
              if (item.productId <= 0) continue;
              
              await db.rawUpdate(
                'UPDATE ${tableProducts} SET quantity = quantity - ? WHERE id = ?',
                [item.quantity, item.productId]
              );
            }
            
            // Add detailed logging right before second retry call to DatabaseService
            print("|||||||||| ORDER #${order.orderNumber}: CALLING DATABASE SERVICE completeSale (retry)");
            await DatabaseService.instance.completeSale(updatedOrder, paymentMethod: paymentMethod);
            
            // Refresh stats before notifying listeners to ensure UI updates with latest data
            await refreshStats();
            notifyListeners();
            print("|||||||||| ORDER #${order.orderNumber}: STANDARD PAYMENT FLOW COMPLETED SUCCESSFULLY (RETRY)");
            print("|||||||||| ORDER SERVICE - SALE COMPLETION END ||||||||||");
            return true;
          } catch (e2) {
            print("|||||||||| ORDER #${order.orderNumber}: ERROR WITH BASIC QUANTITY UPDATE - $e2");
            
            // Still attempt to complete the sale without inventory changes
            print("|||||||||| ORDER #${order.orderNumber}: CALLING DATABASE SERVICE completeSale (fallback)");
            await DatabaseService.instance.completeSale(updatedOrder, paymentMethod: paymentMethod);
            
            // Refresh stats before notifying listeners to ensure UI updates with latest data
            await refreshStats();
            notifyListeners();
            print("|||||||||| ORDER #${order.orderNumber}: STANDARD PAYMENT FLOW COMPLETED WITH ERRORS");
            print("|||||||||| ORDER SERVICE - SALE COMPLETION END ||||||||||");
            return true;
          }
        }
      }
    } catch (e) {
      print("|||||||||| ORDER SERVICE - ERROR COMPLETING SALE: $e ||||||||||");
      return false;
    }
  }
  
  // Apply payment to customer credit
  Future<bool> applyPaymentToCredits(
    String customerName,
    double paymentAmount,
    String paymentMethod,
    String? details
  ) async {
    try {
      // Validate inputs
      if (customerName.isEmpty) {
        throw Exception('Customer name is required');
      }
      
      if (paymentAmount <= 0) {
        throw Exception('Payment amount must be greater than zero');
      }
      
      // Apply payment via DatabaseService
      await DatabaseService.instance.applyPaymentToCredits(
        customerName,
        paymentAmount,
        paymentMethod,
        details ?? '' // Provide empty string if details is null
      );
      
      // Refresh stats
      notifyListeners();
      
      return true;
    } catch (e) {
      debugPrint('Error applying payment to credits: $e');
      return false;
    }
  }

  // Revert a completed sale (cancel receipt)
  Future<bool> revertSale(Order order, {required String reason}) async {
    try {
      debugPrint('ORDER SERVICE: Reverting sale for order ${order.orderNumber}');
      
      if (order.id == null) {
        debugPrint('ORDER SERVICE: Error - Cannot revert order with null ID');
        return false;
      }
      
      // First, ensure the sale is in a state that can be reverted
      if (order.orderStatus != 'COMPLETED') {
        debugPrint('ORDER SERVICE: Error - Can only revert COMPLETED sales');
        return false;
      }
      
      final db = await DatabaseService.instance.database;
      
      // Use a transaction to ensure all operations succeed or fail together
      return await db.transaction((txn) async {
        // 1. Check if the order exists and is COMPLETED
        final orderResult = await txn.query(
          tableOrders,
          where: 'id = ? AND order_status = ?',
          whereArgs: [order.id, 'COMPLETED'],
        );
        
        if (orderResult.isEmpty) {
          debugPrint('ORDER SERVICE: Error - Order not found or not in COMPLETED state');
          return false;
        }
        
        // 2. Update order status to CANCELLED
        await txn.update(
          tableOrders,
          {
            'order_status': 'CANCELLED',
            'status': 'CANCELLED',
            'payment_status': 'REVERTED',
            'updated_at': DateTime.now().toIso8601String(),
          },
          where: 'id = ?',
          whereArgs: [order.id],
        );
        
        // 3. Restore product quantities
        for (final item in order.items) {
          if (item.productId <= 0) continue;
          
          final productDetails = await txn.query(
            tableProducts,
            where: 'id = ?',
            whereArgs: [item.productId],
          );
          
          if (productDetails.isEmpty) {
            debugPrint('ORDER SERVICE: Warning - Product ${item.productId} not found for reverting');
            continue;
          }
          
          final currentQuantity = (productDetails.first['quantity'] as num).toDouble();
          
          // Calculate quantity to add back
          double quantityToAdd;
          if (item.isSubUnit) {
            final subUnitQuantity = (productDetails.first['sub_unit_quantity'] as num?)?.toDouble() ?? 1.0;
            if (subUnitQuantity <= 0) {
              quantityToAdd = item.quantity.toDouble();
            } else {
              quantityToAdd = (item.quantity / subUnitQuantity);
            }
          } else {
            quantityToAdd = item.quantity.toDouble();
          }
          
          // Update product quantity
          await txn.update(
            tableProducts,
            {
              'quantity': currentQuantity + quantityToAdd,
              'updated_at': DateTime.now().toIso8601String(),
            },
            where: 'id = ?',
            whereArgs: [item.productId],
          );
        }
        
        // 4. Check if this order has an associated credit record
          final creditorRecords = await txn.query(
            DatabaseService.tableCreditors,
          where: 'order_number = ? OR order_id = ?',
          whereArgs: [order.orderNumber, order.id],
          );
          
          if (creditorRecords.isNotEmpty) {
          for (final creditor in creditorRecords) {
            // Update the credit record status to CANCELED and set balance to zero
            await txn.update(
              DatabaseService.tableCreditors,
              {
                'status': 'CANCELED',
                'details': 'Credit canceled - Order reverted: $reason',
                'balance': 0.0, // Set balance to zero since order is cancelled
                'updated_at': DateTime.now().toIso8601String(),
              },
              where: 'id = ?',
              whereArgs: [creditor['id']],
            );
            
            // Log the credit cancellation
            final currentUser = AuthService.instance.currentUser;
            if (currentUser != null) {
              await txn.insert(
                tableActivityLogs,
                {
                  'user_id': currentUser.id,
                  'username': currentUser.username,
                  'action': 'cancel_credit',
                  'action_type': 'Cancel Credit',
                  'details': 'Canceled credit for order #${order.orderNumber} due to order reversion. Reason: $reason',
                  'timestamp': DateTime.now().toIso8601String(),
                },
              );
            }
          }
        }
        
        // 5. Log the reversion
        final currentUser = AuthService.instance.currentUser;
        if (currentUser != null) {
          await txn.insert(
            tableActivityLogs,
            {
              'user_id': currentUser.id,
              'username': currentUser.username,
              'action': 'revert_order',
              'action_type': 'Revert Sale',
              'details': 'Cancelled sale for order #${order.orderNumber}. Reason: $reason',
              'timestamp': DateTime.now().toIso8601String(),
            },
          );
        }
        
        refreshStats();
        notifyListeners();
        
        return true;
      });
    } catch (e) {
      debugPrint('ORDER SERVICE: Error reverting sale: $e');
      return false;
    }
  }
} 