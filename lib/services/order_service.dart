import 'package:flutter/foundation.dart';
import 'package:my_flutter_app/models/order_model.dart';
import 'package:my_flutter_app/services/database.dart';
import 'package:intl/intl.dart';

class OrderService extends ChangeNotifier {
  static final OrderService instance = OrderService._internal();
  OrderService._internal() {
    _loadDailyStats();
    _startDailyReset();
  }

  int _totalOrders = 0;
  double _totalSales = 0;
  int _pendingOrders = 0;
  List<Order> _recentOrders = [];
  DateTime _currentDate = DateTime.now();

  int get totalOrders => _totalOrders;
  double get totalSales => _totalSales;
  int get pendingOrders => _pendingOrders;
  List<Order> get recentOrders => _recentOrders;
  String get currentDate => DateFormat('EEEE, MMMM d, y').format(_currentDate);

  void _startDailyReset() {
    // Calculate time until next midnight
    final now = DateTime.now();
    final tomorrow = DateTime(now.year, now.month, now.day + 1);
    final timeUntilMidnight = tomorrow.difference(now);

    // Schedule reset at midnight
    Future.delayed(timeUntilMidnight, () {
      _resetDailyStats();
      _startDailyReset(); // Schedule next day's reset
    });
  }

  void _resetDailyStats() {
    _totalOrders = 0;
    _totalSales = 0;
    _pendingOrders = 0;
    _recentOrders = [];
    _currentDate = DateTime.now();
    _loadDailyStats();
  }

  Future<void> _loadDailyStats() async {
    final now = DateTime.now();
    final startOfDay = DateTime(now.year, now.month, now.day);
    final endOfDay = startOfDay.add(const Duration(days: 1));

    try {
      final orders = await DatabaseService.instance.getOrdersByDateRange(
        startOfDay,
        endOfDay,
      );

      final List<Order> ordersList = orders.map((o) => Order.fromMap(o)).toList();
      
      // Group orders by order number to avoid counting multiple items as separate orders
      final groupedOrders = <String, List<Order>>{};
      for (final order in ordersList) {
        final orderNumber = order.orderNumber ?? '';
        if (!groupedOrders.containsKey(orderNumber)) {
          groupedOrders[orderNumber] = [];
        }
        groupedOrders[orderNumber]!.add(order);
      }
      
      // Calculate statistics based on grouped orders
      _totalOrders = groupedOrders.length;
      _totalSales = groupedOrders.values
          .where((orders) => orders.first.orderStatus == 'COMPLETED')
          .fold(0.0, (sum, orders) => sum + orders.fold(0.0, (sum, order) => sum + order.totalAmount));
      _pendingOrders = groupedOrders.values
          .where((orders) => orders.first.orderStatus == 'PENDING')
          .length;

      // Get recent orders (last 5 unique orders)
      _recentOrders = groupedOrders.values
          .map((orders) => orders.first)
          .take(5)
          .toList();

      _currentDate = now;
      notifyListeners();
    } catch (e) {
      print('Error loading daily stats: $e');
    }
  }

  Future<void> notifyOrderUpdate() async {
    try {
      final stats = await DatabaseService.instance.getDailyStats();
      
      _totalOrders = stats['total_orders'] as int? ?? 0;
      _totalSales = (stats['total_sales'] as num?)?.toDouble() ?? 0.0;
      _pendingOrders = stats['pending_orders'] as int? ?? 0;
      
      final recentOrdersData = await DatabaseService.instance.getRecentOrders();
      _recentOrders = recentOrdersData
          .map((order) => Order.fromMap(order as Map<String, dynamic>))
          .toList();
      
      notifyListeners();
    } catch (e) {
      print('Error updating order stats: $e');
    }
  }

  Future<void> createOrder(Order order) async {
    try {
      await DatabaseService.instance.addOrder(order);
      
      // Log order creation
      await DatabaseService.instance.logActivity({
        'user_id': order.createdBy,
        'action': 'create_order',
        'details': 'Created order #${order.orderNumber}, total: ${order.totalAmount}',
        'timestamp': DateTime.now().toIso8601String(),
      });
      
      notifyOrderUpdate();
    } catch (e) {
      print('Error creating order: $e');
    }
  }

  Future<void> updateOrder(Order order) async {
    try {
      await DatabaseService.instance.updateOrder(order);
      
      // Log order update
      await DatabaseService.instance.logActivity({
        'user_id': order.createdBy,
        'action': 'update_order',
        'details': 'Updated order #${order.orderNumber}, status: ${order.orderStatus}',
        'timestamp': DateTime.now().toIso8601String(),
      });
      
      notifyOrderUpdate();
    } catch (e) {
      print('Error updating order: $e');
    }
  }
} 