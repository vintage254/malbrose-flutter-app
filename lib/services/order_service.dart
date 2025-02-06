import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:my_flutter_app/models/order_model.dart';
import 'package:my_flutter_app/services/database.dart';
import 'package:intl/intl.dart';

class OrderService extends ChangeNotifier {
  static final OrderService instance = OrderService._internal();
  OrderService._internal();

  // Add table definitions
  static const String tableOrders = DatabaseService.tableOrders;
  static const String tableOrderItems = DatabaseService.tableOrderItems;
  static const String tableProducts = DatabaseService.tableProducts;

  // Private fields for tracking statistics
  int _todayOrders = 0;
  double _todaySales = 0.0;
  int _totalOrders = 0;
  double _totalSales = 0.0;
  int _pendingOrdersCount = 0;
  List<Map<String, dynamic>> _recentOrders = [];
  List<Map<String, dynamic>> _pendingOrders = [];

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
             AND status = 'COMPLETED') as completed_today,
            (SELECT SUM(total_amount) FROM $tableOrders 
             WHERE DATE(created_at) = DATE(?) 
             AND status = 'COMPLETED') as today_sales,
            (SELECT COUNT(*) FROM $tableOrders 
             WHERE status = 'PENDING') as pending_count,
            (SELECT COUNT(*) FROM $tableOrders) as total_orders,
            (SELECT SUM(total_amount) FROM $tableOrders 
             WHERE status = 'COMPLETED') as total_sales
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
            GROUP_CONCAT(json_object(
              'product_id', oi.product_id,
              'quantity', oi.quantity,
              'unit_price', oi.unit_price,
              'selling_price', oi.selling_price,
              'total_amount', oi.total_amount,
              'product_name', p.product_name
            )) as items_json
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
} 