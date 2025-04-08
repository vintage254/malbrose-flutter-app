import 'package:flutter/material.dart';
import 'package:my_flutter_app/const/constant.dart';
import 'package:my_flutter_app/models/order_model.dart';
import 'package:my_flutter_app/models/cart_item_model.dart';
import 'package:my_flutter_app/services/database.dart';
import 'package:my_flutter_app/services/order_service.dart';
import 'package:my_flutter_app/widgets/side_menu_widget.dart';
import 'package:intl/intl.dart';
import 'package:my_flutter_app/screens/order_screen.dart';
import 'package:my_flutter_app/models/product_model.dart';
import 'package:my_flutter_app/widgets/order_receipt_dialog.dart';
import 'dart:convert';

class HeldOrdersScreen extends StatefulWidget {
  const HeldOrdersScreen({super.key});

  @override
  State<HeldOrdersScreen> createState() => _HeldOrdersScreenState();
}

class _HeldOrdersScreenState extends State<HeldOrdersScreen> {
  List<Order> _heldOrders = [];
  bool _isLoading = true;
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();
  final OrderService _orderService = OrderService.instance;

  @override
  void initState() {
    super.initState();
    _loadHeldOrders();
  }

  Future<void> _loadHeldOrders() async {
    setState(() => _isLoading = true);
    try {
      final ordersData = await DatabaseService.instance.getOrdersByStatus('ON_HOLD');
      if (mounted) {
        setState(() {
          _heldOrders = ordersData.map((map) => Order.fromMap(map)).toList();
          _isLoading = false;
        });
      }
    } catch (e) {
      print('Error loading held orders: $e');
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading held orders: $e')),
        );
      }
    }
  }

  List<Order> get _filteredOrders {
    if (_searchQuery.isEmpty) return _heldOrders;
    return _heldOrders.where((order) {
      final search = _searchQuery.toLowerCase();
      return order.orderNumber.toLowerCase().contains(search) || 
             (order.customerName?.toLowerCase() ?? '').contains(search);
    }).toList();
  }

  Future<void> _deleteHeldOrder(Order order) async {
    try {
      await showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Delete Held Order'),
          content: Text('Are you sure you want to delete order #${order.orderNumber}?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                Navigator.pop(context);
                await DatabaseService.instance.deleteOrder(order.id!);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Order deleted successfully')),
                );
                _loadHeldOrders();
              },
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              child: const Text('Delete'),
            ),
          ],
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error deleting order: $e')),
      );
    }
  }

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
      
      // Use OrderService to update the status to PENDING
      final success = await _orderService.restoreHeldOrder(order);
      
      if (!success) {
        // Close loading dialog before throwing exception
        Navigator.of(context, rootNavigator: true).pop();
        throw Exception('Failed to restore order');
      }
      
      // Load the order items from the database
      final orderItems = await DatabaseService.instance.getOrderItems(order.id!);
      print('Loaded ${orderItems.length} items for order #${order.orderNumber}');
      
      // Convert database orderItems to OrderItem models
      final items = orderItems.map((item) => OrderItem(
        id: item['id'] as int?,
        orderId: order.id!,
        productId: item['product_id'] as int,
        quantity: item['quantity'] as int,
        unitPrice: (item['unit_price'] as num).toDouble(),
        sellingPrice: (item['selling_price'] as num).toDouble(),
        totalAmount: (item['total_amount'] as num).toDouble(),
        productName: item['product_name'] as String,
        isSubUnit: item['is_sub_unit'] == 1,
        subUnitName: item['sub_unit_name'] as String?,
        subUnitQuantity: (item['sub_unit_quantity'] as num?)?.toDouble(),
        adjustedPrice: (item['adjusted_price'] as num?)?.toDouble(),
      )).toList();
      
      // Close loading dialog
      Navigator.of(context, rootNavigator: true).pop();
      
      // Create an updated order with the items and PENDING status
      final updatedOrder = order.copyWith(
        orderStatus: 'PENDING',
        items: items,
      );
      
      // Navigate to OrderScreen with the fully loaded order
      Navigator.pushReplacement(
        context, 
        MaterialPageRoute(
          builder: (context) => OrderScreen(
            editingOrder: updatedOrder,
            isEditing: true,
          ),
        ),
      );
      
      // Refresh the held orders list - must be done here because we're using pushReplacement
      _loadHeldOrders();
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
    return Scaffold(
      appBar: AppBar(
        title: const Text('Held Orders'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadHeldOrders,
          ),
        ],
      ),
      body: Row(
        children: [
          const Expanded(
            flex: 1,
            child: SideMenuWidget(),
          ),
          Expanded(
            flex: 5,
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.amber.withOpacity(0.7),
                    Colors.orange.shade900,
                  ],
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.all(defaultPadding),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Held Orders',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: defaultPadding),
                    // Search bar
                    TextField(
                      controller: _searchController,
                      decoration: InputDecoration(
                        hintText: 'Search by order number or customer name...',
                        prefixIcon: const Icon(Icons.search),
                        filled: true,
                        fillColor: Colors.white,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      onChanged: (value) {
                        setState(() {
                          _searchQuery = value;
                        });
                      },
                    ),
                    const SizedBox(height: defaultPadding),
                    Expanded(
                      child: _isLoading
                        ? const Center(child: CircularProgressIndicator())
                        : _filteredOrders.isEmpty
                          ? const Center(
                              child: Text(
                                'No held orders found',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                            )
                          : Card(
                              elevation: 4,
                              child: ListView.separated(
                                itemCount: _filteredOrders.length,
                                separatorBuilder: (context, index) => const Divider(),
                                itemBuilder: (context, index) {
                                  final order = _filteredOrders[index];
                                  return ListTile(
                                    leading: const Icon(Icons.receipt_long, size: 36, color: Colors.orange),
                                    title: Text(
                                      'Order #${order.orderNumber}',
                                      style: const TextStyle(fontWeight: FontWeight.bold),
                                    ),
                                    subtitle: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text('Customer: ${order.customerName ?? 'Unknown'}'),
                                        Text('Total: KSH ${order.totalAmount.toStringAsFixed(2)}'),
                                        Text('Date: ${DateFormat('MMM dd, yyyy HH:mm').format(order.createdAt)}'),
                                      ],
                                    ),
                                    trailing: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        IconButton(
                                          icon: const Icon(Icons.restore, color: Colors.green),
                                          tooltip: 'Restore Order',
                                          onPressed: () => _restoreHeldOrder(order),
                                        ),
                                        IconButton(
                                          icon: const Icon(Icons.delete, color: Colors.red),
                                          tooltip: 'Delete Order',
                                          onPressed: () => _deleteHeldOrder(order),
                                        ),
                                      ],
                                    ),
                                    isThreeLine: true,
                                    onTap: () => _restoreHeldOrder(order),
                                  );
                                },
                              ),
                            ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }
} 