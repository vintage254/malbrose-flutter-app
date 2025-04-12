import 'package:flutter/foundation.dart';
import 'package:my_flutter_app/models/order_model.dart';
import 'package:my_flutter_app/services/database.dart';
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
    
    // Get orders with the given status
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
      GROUP BY o.id
      ORDER BY o.created_at DESC
    ''', [status]);
    
    // Get any held orders that have been restored
    final List<Map<String, dynamic>> heldOrders = status == 'PENDING' ? 
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
        GROUP BY o.id
        ORDER BY o.created_at DESC
      ''') : [];
    
    return {
      'pendingOrders': orders,
      'heldOrders': heldOrders
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
  static const String STATUS_ON_HOLD = 'ON_HOLD';
  static const String STATUS_COMPLETED = 'COMPLETED';
  static const String STATUS_REPORTED = 'REPORTED';
  
  // Create a new order with validation of product IDs
  Future<bool> createOrder(Map<String, dynamic> orderMap, List<Map<String, dynamic>> orderItems) async {
    try {
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
      
      // Create the order through DatabaseService
      final result = await DatabaseService.instance.createOrder(orderMap, orderItems);
      if (result != null) {
        // Refresh stats after creating an order
        notifyOrderUpdate();
        return true;
      }
      return false;
    } catch (e) {
      debugPrint('Error creating order in OrderService: $e');
      return false;
    }
  }
  
  // Create a held order
  Future<bool> createHeldOrder(Map<String, dynamic> orderMap, List<Map<String, dynamic>> orderItems) async {
    // Ensure order status is set to ON_HOLD
    orderMap['order_status'] = STATUS_ON_HOLD;
    
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
        notifyOrderUpdate();
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
        throw Exception('Order ID is null');
      }
      
      final db = await DatabaseService.instance.database;
      
      // Start a transaction for consistency
      return await db.transaction((txn) async {
        // First check if order exists and get its current status
        final orderCheck = await txn.rawQuery('''
          SELECT id, order_status, status, order_number, customer_name, total_amount 
          FROM ${tableOrders} 
          WHERE id = ?
        ''', [order.id]);
        
        if (orderCheck.isEmpty) {
          throw Exception('Order not found');
        }
        
        final currentStatus = orderCheck.first['order_status'] as String? ?? 
                            orderCheck.first['status'] as String? ?? 
                            'UNKNOWN';
        final originalOrderNumber = orderCheck.first['order_number'] as String;
        
        // If order is already converted or completed, don't process again
        if (currentStatus == 'CONVERTED' || currentStatus == 'COMPLETED') {
          debugPrint('Order #$originalOrderNumber already processed (status: $currentStatus)');
          
          // Try to find the converted order
          final convertedOrderQuery = await txn.rawQuery(
            '''
            SELECT * FROM ${tableOrders} 
            WHERE order_number LIKE ? AND order_status = 'PENDING'
            ''',
            ['ORD-${originalOrderNumber.substring(4)}']
          );
          
          if (convertedOrderQuery.isNotEmpty) {
            debugPrint('Found converted order: ${convertedOrderQuery.first['order_number']}');
          }
          
          return true; // Already processed, no error
        }
        
        // Only proceed if this is actually a held order
        if (currentStatus != 'ON_HOLD') {
          debugPrint('Order #$originalOrderNumber is not on hold (status: $currentStatus)');
          return false;
        }
        
        // First mark the order as being converted to prevent concurrent conversions
        await txn.update(
          tableOrders,
          {
            'status': 'CONVERTING',
            'order_status': 'CONVERTING',
            'updated_at': DateTime.now().toIso8601String()
          },
          where: 'id = ?',
          whereArgs: [order.id],
        );
        
        // Generate the new order number
        String newOrderNumber = originalOrderNumber.startsWith('HLD-') ? 
                              'ORD-' + originalOrderNumber.substring(4) : 
                              originalOrderNumber;
        
        // Check if an order with this number already exists
        final existingOrders = await txn.query(
          tableOrders,
          where: 'order_number = ? AND id != ?',
          whereArgs: [newOrderNumber, order.id],
          limit: 1
        );
        
        if (existingOrders.isNotEmpty) {
          debugPrint('Order #$newOrderNumber already exists with a different ID');
          
          // Mark the original order as converted but don't create duplicate
          await txn.update(
            tableOrders,
            {
              'status': 'CONVERTED',
              'order_status': 'CONVERTED',
              'updated_at': DateTime.now().toIso8601String()
            },
            where: 'id = ?',
            whereArgs: [order.id]
          );
          
          // Log this conversion link
          final currentUser = AuthService.instance.currentUser;
          if (currentUser != null) {
            await txn.insert(
              tableActivityLogs,
              {
                'user_id': currentUser.id,
                'username': currentUser.username,
                'action': 'link_to_existing',
                'details': 'Linked held order #$originalOrderNumber to existing order #$newOrderNumber',
                'timestamp': DateTime.now().toIso8601String(),
              },
            );
          }
          
          notifyOrderUpdate();
          return true;
        }
        
        // Check for similar orders with same customer and total to avoid duplicates
        final similarOrders = await txn.query(
          tableOrders,
          where: "customer_name = ? AND total_amount = ? AND order_status = 'PENDING' AND id != ?",
          whereArgs: [
            orderCheck.first['customer_name'],
            orderCheck.first['total_amount'],
            order.id
          ],
          orderBy: 'created_at DESC',
          limit: 1
        );
        
        if (similarOrders.isNotEmpty) {
          final similarOrderNumber = similarOrders.first['order_number'] as String;
          debugPrint('Found similar pending order: $similarOrderNumber');
          
          // Mark as converted and link to the similar order
          await txn.update(
            tableOrders,
            {
              'status': 'CONVERTED',
              'order_status': 'CONVERTED', 
              'updated_at': DateTime.now().toIso8601String()
            },
            where: 'id = ?',
            whereArgs: [order.id]
          );
          
          // Log this duplicate detection
          final currentUser = AuthService.instance.currentUser;
          if (currentUser != null) {
            await txn.insert(
              tableActivityLogs,
              {
                'user_id': currentUser.id,
                'username': currentUser.username,
                'action': 'mark_duplicate',
                'details': 'Marked held order #$originalOrderNumber as duplicate of $similarOrderNumber',
                'timestamp': DateTime.now().toIso8601String(),
              },
            );
          }
          
          notifyOrderUpdate();
          return true;
        }
        
        // Now we can safely convert the order
        debugPrint('Converting held order #$originalOrderNumber to #$newOrderNumber');
        
        // Update the order status and number
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
        
        // Log this action
        final currentUser = AuthService.instance.currentUser;
        if (currentUser != null) {
          await txn.insert(
            tableActivityLogs,
            {
              'user_id': currentUser.id,
              'username': currentUser.username,
              'action': 'restore_held_order',
              'details': 'Converted held order #$originalOrderNumber to active order #$newOrderNumber',
              'timestamp': DateTime.now().toIso8601String(),
            },
          );
        }
        
        notifyOrderUpdate();
        return true;
      });
    } catch (e) {
      debugPrint('Error restoring held order in OrderService: $e');
      return false;
    }
  }
  
  // Complete a sale
  Future<bool> completeSale(Order order, {String paymentMethod = 'Cash'}) async {
    try {
      if (order.id == null) {
        throw Exception('Order ID is null');
      }
      
      // First validate all product IDs
      debugPrint('OrderService - Valid items: ${order.items.where((item) => item.productId > 0).length} of ${order.items.length}');
      
      // Even if there are no items, still allow the sale to complete
      // This handles the case where order items might be malformed or missing
      
      // Handle credit payment separately
      if (paymentMethod == 'Credit') {
        // Make sure customer is valid
        if (order.customerId == null || order.customerId! <= 0) {
          throw Exception('Credit payment requires a valid customer account');
        }
        
        if (order.customerName == null || order.customerName!.isEmpty) {
          throw Exception('Credit payment requires a valid customer name');
        }
        
        // Create a copy of the order with credit payment method
        final creditOrder = order.copyWith(
          paymentMethod: 'Credit',
          paymentStatus: 'PENDING', // Credit orders have pending payment status
        );
        
        // Complete the sale via DatabaseService
        await DatabaseService.instance.completeSale(creditOrder, paymentMethod: 'Credit');
        
        // Create credit record for customer
        await DatabaseService.instance.createCredit(
          creditOrder.customerId!,
          creditOrder.customerName!,
          creditOrder.id!,
          creditOrder.orderNumber,
          creditOrder.totalAmount ?? 0,
        );
        
        notifyOrderUpdate();
        return true;
      } else {
        // For cash or other payment methods
        final updatedOrder = order.copyWith(
          paymentMethod: paymentMethod,
          paymentStatus: 'PAID',
          orderStatus: STATUS_COMPLETED,
        );
        
        try {
          // Update product quantities safely without using last_updated field
          for (var item in updatedOrder.items) {
            if (item.productId <= 0) continue;
            
            // Get current product quantity
            final productDetails = await DatabaseService.instance.getProductById(item.productId);
            if (productDetails == null) {
              debugPrint('Warning: Product ${item.productId} not found for quantity update');
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
            
            debugPrint('Updated product ${item.productId} quantity from $currentQuantity to $newQuantity');
          }
          
          // Complete the order - updating status
          await DatabaseService.instance.completeSale(updatedOrder, paymentMethod: paymentMethod);
          
          notifyOrderUpdate();
          return true;
        } catch (e) {
          debugPrint('Error updating product quantities: $e');
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
            
            await DatabaseService.instance.completeSale(updatedOrder, paymentMethod: paymentMethod);
            notifyOrderUpdate();
            return true;
          } catch (e2) {
            debugPrint('Error with basic quantity update: $e2');
            // Still attempt to complete the sale without inventory changes
            await DatabaseService.instance.completeSale(updatedOrder, paymentMethod: paymentMethod);
            notifyOrderUpdate();
            return true;
          }
        }
      }
    } catch (e) {
      debugPrint('Error completing sale in OrderService: $e');
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
      notifyOrderUpdate();
      
      return true;
    } catch (e) {
      debugPrint('Error applying payment to credits: $e');
      return false;
    }
  }
} 