import 'package:flutter/material.dart';
import 'package:my_flutter_app/const/constant.dart';
import 'package:my_flutter_app/models/order_model.dart';
import 'package:my_flutter_app/models/cart_item_model.dart';
import 'package:my_flutter_app/services/database.dart';
import 'package:my_flutter_app/widgets/side_menu_widget.dart';
import 'package:intl/intl.dart';
import 'package:my_flutter_app/screens/order_screen.dart';
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
      // Show loading dialog
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
      
      // Get order items
      final orderItemsData = await DatabaseService.instance.getOrderItems(order.id!);
      
      // Convert the map data to OrderItem objects
      final orderItems = orderItemsData.map((map) => OrderItem.fromMap(map)).toList();
      
      print('Restoring held order: ${order.orderNumber} with ${orderItems.length} items');
      
      // Fix order items with invalid product IDs (productId = 0)
      final fixedOrderItems = await Future.wait(orderItems.map((item) async {
        // Skip items that already have valid product IDs
        if (item.productId > 0) return item;
        
        print('Fixing invalid product ID for item: ${item.productName} (ID: ${item.productId})');
        
        // Try multiple approaches to find the correct product
        // 1. First try by exact name
        final products = await DatabaseService.instance.getProductByName(item.productName);
        if (products.isNotEmpty) {
          final productId = products.first['id'] as int;
          print('  Found product by name: ${products.first['product_name']} (ID: $productId)');
          return item.copyWith(productId: productId);
        }
        
        // 2. Try querying all products and doing a manual comparison
        final allProducts = await DatabaseService.instance.getAllProducts();
        
        // Try to find a product with similar name (case insensitive)
        final productName = item.productName.toLowerCase();
        for (final product in allProducts) {
          final dbProductName = (product['product_name'] as String? ?? '').toLowerCase();
          if (dbProductName.contains(productName) || productName.contains(dbProductName)) {
            final productId = product['id'] as int;
            print('  Found product by fuzzy match: ${product['product_name']} (ID: $productId)');
            return item.copyWith(productId: productId);
          }
        }
        
        print('  Could not find a matching product for: ${item.productName}');
        return item;
      }));

      // Filter out items with invalid product IDs for the final list
      final validItems = fixedOrderItems.where((item) => item.productId > 0).toList();
      
      print('Valid items after fixing: ${validItems.length} of ${orderItems.length}');
      
      if (validItems.isEmpty) {
        throw Exception('No valid items found to restore. Please create a new order.');
      }
      
      // Update the order with the fixed items
      final updatedOrder = order.copyWith(
        items: validItems,
        orderStatus: 'PENDING'
      );
      
      // Close loading dialog
      Navigator.of(context, rootNavigator: true).pop();
      
      // Navigate to the order screen with the restored order
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => OrderScreen(
            editingOrder: updatedOrder,
            isEditing: true,
          ),
        ),
      );
    } catch (e) {
      // Close loading dialog if open
      Navigator.of(context, rootNavigator: true).pop();
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error restoring order: $e'),
          backgroundColor: Colors.red,
        ),
      );
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