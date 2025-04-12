import 'package:flutter/material.dart';
import 'package:your_app/services/database_service.dart';
import 'package:your_app/services/order_service.dart';
import 'package:your_app/screens/sales_screen.dart';

class HeldOrdersScreen extends StatefulWidget {
  // ... (existing code)
  @override
  _HeldOrdersScreenState createState() => _HeldOrdersScreenState();
}

class _HeldOrdersScreenState extends State<HeldOrdersScreen> {
  // ... (existing code)

  Future<void> _restoreHeldOrder(Order order) async {
    try {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const AlertDialog(
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text('Restoring order...'),
            ],
          ),
        ),
      );
      
      // First check if order still exists and has ON_HOLD status
      final orderCheck = await DatabaseService.instance.getOrderById(order.id!);
      if (orderCheck == null || orderCheck['order_status'] != 'ON_HOLD') {
        // Order has already been processed or doesn't exist
        Navigator.of(context, rootNavigator: true).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Order has already been processed or deleted'),
            backgroundColor: Colors.orange,
          ),
        );
        // Refresh the list to show current state
        _loadHeldOrders();
        return;
      }
      
      // Use OrderService to handle the restoration process
      // This will ensure proper status updates and duplicate prevention
      final success = await _orderService.restoreHeldOrder(order);
      
      // Close loading dialog
      Navigator.of(context, rootNavigator: true).pop();
      
      if (!success) {
        throw Exception('Failed to restore order');
      }
      
      // Show success message and refresh
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Order #${order.orderNumber} successfully restored'),
          backgroundColor: Colors.green,
        ),
      );
      
      // Refresh the held orders list
      await _loadHeldOrders();
      
      // Navigate to the sales screen to show the active orders
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => const SalesScreen(),
        ),
      );
    } catch (e) {
      // Make sure dialog is closed in case of error
      if (Navigator.of(context, rootNavigator: true).canPop()) {
        Navigator.of(context, rootNavigator: true).pop();
      }
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error restoring order: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // ... (existing code)
  }
} 