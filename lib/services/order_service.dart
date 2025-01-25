import 'package:flutter/foundation.dart';
import 'package:my_flutter_app/models/order_model.dart';
import 'package:my_flutter_app/services/database.dart';
import 'package:intl/intl.dart';

class OrderService extends ChangeNotifier {
  static final OrderService instance = OrderService._internal();
  OrderService._internal();

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
      final stats = await DatabaseService.instance.getDashboardStats();
      
      // Update statistics
      _todayOrders = stats['today_orders'] as int;
      _todaySales = (stats['today_sales'] as num).toDouble();
      _totalOrders = stats['total_orders'] as int;
      _totalSales = (stats['total_sales'] as num).toDouble();
      _pendingOrdersCount = stats['pending_orders'] as int;
      
      // Use new method to get all recent orders
      _recentOrders = await DatabaseService.instance.getRecentOrders();
      
      notifyListeners();
    } catch (e) {
      print('Error refreshing stats: $e');
      // Keep existing data on error
    }
  }

  void notifyOrderUpdate() {
    refreshStats();
  }
} 