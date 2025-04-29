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
import 'package:my_flutter_app/screens/sales_screen.dart';
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
  final Set<String> _processingOrders = {};

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
    if (_processingOrders.contains(order.orderNumber)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Order restoration already in progress...'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() {
      _processingOrders.add(order.orderNumber);
    });

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => WillPopScope(
        onWillPop: () async => false,
        child: const AlertDialog(
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text('Restoring order...'),
            ],
          ),
        ),
      ),
    );

    try {
      print('HELD RESTORE: Starting to restore order #${order.orderNumber} with status ${order.orderStatus}');
      
      // Use atomic backend logic
      final bool restored = await _orderService.restoreHeldOrder(order);
      Navigator.of(context, rootNavigator: true).pop();

      print('HELD RESTORE: OrderService.restoreHeldOrder result: $restored');

      if (!restored) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Order could not be restored (already processed or duplicate found).'),
            backgroundColor: Colors.orange,
          ),
        );
        await _loadHeldOrders();
        return;
      }

      // Re-check the order's new status
      final updatedOrder = await DatabaseService.instance.getOrderById(order.id!);
      print('HELD RESTORE: First check of updated order after restore: $updatedOrder');
      
      if (updatedOrder == null || updatedOrder['order_status'] != 'PENDING') {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Order restored, but a duplicate or converted order exists. No edit possible.'),
            backgroundColor: Colors.orange,
          ),
        );
        await _loadHeldOrders();
        return;
      }

      // Re-fetch the updated order data after the successful transaction
      final updatedOrderData = await DatabaseService.instance.getOrderById(order.id!);
      
      debugPrint('============= HELD ORDERS SCREEN DEBUG =============');
      debugPrint('Original order: ${order.id} | ${order.orderNumber} | ${order.orderStatus}');
      debugPrint('Raw database data: $updatedOrderData');

      if (updatedOrderData == null) {
        // Handle error - the order should exist after successful update
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error fetching updated order data after restore.'), 
              backgroundColor: Colors.red
            ),
          );
        }
        // Refresh the held orders list
        _loadHeldOrders();
        return; // Stop the navigation
      }

      // CRITICAL FIX: Make sure our order data map has ALL required fields
      // This ensures Order.fromMap works properly and has non-null values
      final Map<String, dynamic> sanitizedOrderData = {
        ...updatedOrderData,
        'id': updatedOrderData['id'] ?? order.id,
        'order_number': updatedOrderData['order_number'] ?? order.orderNumber,
        'order_status': updatedOrderData['order_status'] ?? updatedOrderData['status'] ?? 'PENDING',
        'customer_name': updatedOrderData['customer_name'] ?? order.customerName ?? 'Walk-in Customer',
        'total_amount': updatedOrderData['total_amount'] ?? order.totalAmount,
        'created_by': updatedOrderData['created_by'] ?? order.createdBy,
        'created_at': updatedOrderData['created_at'] ?? order.createdAt.toIso8601String(),
        'order_date': updatedOrderData['order_date'] ?? order.orderDate.toIso8601String(),
      };
      
      debugPrint('Sanitized order data: $sanitizedOrderData');
      
      // Convert the fresh map data to an Order object using the sanitized data
      final Order restoredOrderForEditing = Order.fromMap(sanitizedOrderData);
      
      debugPrint('Converted order: ${restoredOrderForEditing.id} | ${restoredOrderForEditing.orderNumber} | ${restoredOrderForEditing.orderStatus}');
      debugPrint('===================================');
      
      // Success: navigate to OrderScreen with the FRESH data
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Order #${restoredOrderForEditing.orderNumber} restored successfully. Loading for editing...'),
            backgroundColor: Colors.green,
          ),
        );
        
        debugPrint("Navigating to OrderScreen with UPDATED order: ID ${restoredOrderForEditing.id}, "
                  "Number ${restoredOrderForEditing.orderNumber}, Status ${restoredOrderForEditing.orderStatus}");
        
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => OrderScreen(
              editingOrder: restoredOrderForEditing, // Pass the FRESHLY FETCHED order
              isEditing: true,                       // Tell OrderScreen this is an edit
              preserveOrderNumber: true,              // Keep the order number
              preventDuplicateCreation: true,         // Critical flag to prevent duplicates
            ),
          ),
        );
      }
      await _loadHeldOrders(); // Still refresh list to ensure UI consistency
    } catch (e) {
      if (Navigator.of(context, rootNavigator: true).canPop()) {
        Navigator.of(context, rootNavigator: true).pop();
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error restoring order: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _processingOrders.remove(order.orderNumber);
        });
      }
    }
  }
  
  // Helper method to convert order items to cart items
  Future<List<CartItem>> _convertOrderItemsToCartItems(List<Map<String, dynamic>> orderItems) async {
    final List<CartItem> result = [];
    
    for (final item in orderItems) {
      final productId = item['product_id'] as int;
      final productData = await DatabaseService.instance.getProductById(productId);
      
      if (productData != null) {
        final product = Product.fromMap(productData);
        final isSubUnit = item['is_sub_unit'] == 1;
        
        result.add(
          CartItem(
            product: product,
            quantity: (item['quantity'] as num).toInt(),
            isSubUnit: isSubUnit,
            subUnitName: item['sub_unit_name'] as String?,
            subUnitQuantity: isSubUnit ? (item['sub_unit_quantity'] as num?)?.toInt() : null,
            adjustedPrice: (item['adjusted_price'] as num?)?.toDouble(),
            total: (item['total_amount'] as num?)?.toDouble() ?? 
                  ((item['adjusted_price'] as num?)?.toDouble() ?? product.sellingPrice) * (item['quantity'] as num).toDouble(),
          ),
        );
      }
    }
    
    return result;
  }

  Widget _buildOrderListItem(Order order) {
    final isProcessing = _processingOrders.contains(order.orderNumber);
    
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4.0, horizontal: 8.0),
      child: ListTile(
        leading: const Icon(Icons.receipt_long, size: 36, color: Colors.orange),
        title: Text(
          'Order #${order.orderNumber}',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Customer: ${order.customerName ?? "Unknown"}'),
            Text('Total: KSH ${order.totalAmount.toStringAsFixed(2)}'),
            Text('Date: ${DateFormat('MMM dd, yyyy HH:mm').format(order.createdAt)}'),
          ],
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (!isProcessing)
              IconButton(
                icon: const Icon(Icons.restore, color: Colors.green),
                tooltip: 'Restore Order',
                onPressed: () => _restoreHeldOrder(order),
              )
            else
              const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            IconButton(
              icon: const Icon(Icons.delete, color: Colors.red),
              tooltip: 'Delete Order',
              onPressed: isProcessing ? null : () => _deleteHeldOrder(order),
            ),
          ],
        ),
        isThreeLine: true,
        onTap: isProcessing ? null : () => _restoreHeldOrder(order),
      ),
    );
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
                                  return _buildOrderListItem(order);
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