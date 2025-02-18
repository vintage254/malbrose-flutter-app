import 'package:flutter/material.dart';
import 'package:my_flutter_app/const/constant.dart';
import 'package:my_flutter_app/models/order_model.dart';
import 'package:my_flutter_app/models/product_model.dart';
import 'package:my_flutter_app/models/cart_item_model.dart';
import 'package:my_flutter_app/services/database.dart';
import 'package:my_flutter_app/widgets/side_menu_widget.dart';
import 'package:my_flutter_app/widgets/receipt_panel.dart';
import 'package:my_flutter_app/services/order_service.dart';
import 'package:my_flutter_app/services/auth_service.dart';
import 'package:my_flutter_app/widgets/order_cart_panel.dart';

class SalesScreen extends StatefulWidget {
  const SalesScreen({super.key});

  @override
  State<SalesScreen> createState() => _SalesScreenState();
}

class _SalesScreenState extends State<SalesScreen> {
  List<Order> _pendingOrders = [];
  Order? _selectedOrder;
  bool _isLoading = true;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _loadPendingOrders();
  }

  Future<void> _loadPendingOrders() async {
    try {
      setState(() => _isLoading = true);
      final orders = await DatabaseService.instance.getOrdersByStatus('PENDING');
      
      if (mounted) {
        // Group orders by order number
        final Map<String, List<Map<String, dynamic>>> groupedOrders = {};
        for (var order in orders) {
          final orderNumber = order['order_number'] as String?;
          if (orderNumber != null) {
            if (!groupedOrders.containsKey(orderNumber)) {
              groupedOrders[orderNumber] = [];
            }
            groupedOrders[orderNumber]!.add(order);
          }
        }

        // Convert grouped orders to Order objects
        final List<Order> combinedOrders = [];
        for (var entry in groupedOrders.entries) {
          final firstOrder = entry.value.first;
          
          // Create order items
          final orderItems = entry.value.map((o) => OrderItem(
            id: o['item_id'],
            orderId: o['id'],
            productId: o['product_id'],
            quantity: o['quantity'],
            unitPrice: (o['unit_price'] as num).toDouble(),
            sellingPrice: (o['selling_price'] as num).toDouble(),
            adjustedPrice: (o['adjusted_price'] as num?)?.toDouble() ?? 
                         (o['selling_price'] as num).toDouble(),
            totalAmount: (o['item_total'] as num).toDouble(),
            productName: o['product_name'] ?? 'Unknown Product',
            isSubUnit: o['is_sub_unit'] == 1,
            subUnitName: o['sub_unit_name'],
          )).toList();

          try {
            // Calculate total amount from items
            final totalAmount = orderItems.fold<double>(
              0, 
              (sum, item) => sum + item.totalAmount
            );

            // Create order with customer information
            final order = Order(
              id: firstOrder['id'],
              orderNumber: firstOrder['order_number'],
              totalAmount: totalAmount,
              customerName: firstOrder['customer_name'] ?? 'Unknown Customer',
              customerId: firstOrder['customer_id'],
              orderStatus: firstOrder['status'] ?? 'PENDING',
              paymentStatus: firstOrder['payment_status'] ?? 'PENDING',
              createdBy: firstOrder['created_by'],
              createdAt: DateTime.parse(firstOrder['created_at']),
              orderDate: DateTime.parse(firstOrder['order_date']),
              items: orderItems,
            );
            combinedOrders.add(order);
          } catch (e) {
            print('Error creating order object: $e');
            print('Order data: ${firstOrder.toString()}');
            continue;
          }
        }

        setState(() {
          _pendingOrders = combinedOrders;
          _isLoading = false;
        });
      }
    } catch (e) {
      print('Error loading pending orders: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading orders: $e')),
        );
      }
    }
  }

  List<Order> get _filteredOrders {
    if (_searchQuery.isEmpty) return _pendingOrders;
    return _pendingOrders.where((order) {
      final search = _searchQuery.toLowerCase();
      return 
        (order.customerName?.toLowerCase().contains(search) ?? false) ||
        order.id.toString().contains(search);
    }).toList();
  }

  Future<void> _processSale(Order order) async {
    try {
      await DatabaseService.instance.withTransaction((txn) async {
        // First verify all items have sufficient stock
        for (var item in order.items) {
          final product = await txn.query(
            DatabaseService.tableProducts,
            where: 'id = ?',
            whereArgs: [item.productId],
            limit: 1,
          );
          
          if (product.isEmpty) {
            throw Exception('Product not found: ${item.productId}');
          }

          final currentQuantity = (product.first['quantity'] as num).toDouble();
          final subUnitQuantity = (product.first['sub_unit_quantity'] as num?)?.toDouble() ?? 1.0;
          
          final availableQuantity = item.isSubUnit 
              ? currentQuantity * subUnitQuantity 
              : currentQuantity;

          if (item.quantity > availableQuantity) {
            throw Exception(
              'Insufficient stock for ${product.first['product_name']}. '
              'Available: ${availableQuantity.toStringAsFixed(2)} '
              '${item.isSubUnit ? (product.first['sub_unit_name'] ?? 'pieces') : 'units'}'
            );
          }
        }

        // Update order status using simple map
        await txn.update(
          DatabaseService.tableOrders,
          {
            'status': 'COMPLETED',
            'payment_status': 'PAID',
            'updated_at': DateTime.now().toIso8601String(),
          },
          where: 'order_number = ?',
          whereArgs: [order.orderNumber],
        );

        // Update product quantities using simple values
        for (var item in order.items) {
          final product = await txn.query(
            DatabaseService.tableProducts,
            where: 'id = ?',
            whereArgs: [item.productId],
            limit: 1,
          );

          if (product.isNotEmpty) {
            final currentQuantity = (product.first['quantity'] as num).toDouble();
            final quantityToDeduct = item.isSubUnit
                ? item.quantity / (product.first['sub_unit_quantity'] as num).toDouble()
                : item.quantity;

            await txn.update(
              DatabaseService.tableProducts,
              {'quantity': currentQuantity - quantityToDeduct},
              where: 'id = ?',
              whereArgs: [item.productId],
            );
          }
        }

        // Update customer statistics if customer_id exists
        if (order.customerId != null) {
          // Get current customer stats
          final customerStats = await txn.query(
            DatabaseService.tableCustomers,
            columns: ['total_orders', 'total_amount'],
            where: 'id = ?',
            whereArgs: [order.customerId],
            limit: 1,
          );

          if (customerStats.isNotEmpty) {
            final currentTotalOrders = (customerStats.first['total_orders'] as int?) ?? 0;
            final currentTotalAmount = (customerStats.first['total_amount'] as num?)?.toDouble() ?? 0.0;

            await txn.update(
              DatabaseService.tableCustomers,
              {
                'total_orders': currentTotalOrders + 1,
                'total_amount': currentTotalAmount + order.totalAmount,
                'last_order_date': DateTime.now().toIso8601String(),
                'updated_at': DateTime.now().toIso8601String(),
              },
              where: 'id = ?',
              whereArgs: [order.customerId],
            );
          }
        }

        // Log the activity using simple map
        final currentUser = AuthService.instance.currentUser;
        if (currentUser != null) {
          await txn.insert(
            DatabaseService.tableActivityLogs,
            {
              'user_id': currentUser.id,
              'username': currentUser.username,
              'action': 'complete_sale',
              'details': 'Completed sale #${order.orderNumber}, amount: ${order.totalAmount}',
              'timestamp': DateTime.now().toIso8601String(),
            },
          );
        }
      });

      // Notify order service to refresh stats
      await OrderService.instance.refreshStats();
      
      if (mounted) {
        setState(() {
          _selectedOrder = null;
        });
        await _loadPendingOrders();
      }
    } catch (e) {
      print('Error completing sale: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error completing sale: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _completeSale(Order order) async {
    try {
      // Create new order instance with updated status
      final updatedOrder = Order(
        id: order.id,
        orderNumber: order.orderNumber,
        totalAmount: order.totalAmount,
        customerName: order.customerName,
        orderStatus: 'COMPLETED',
        paymentStatus: order.paymentStatus,
        createdBy: order.createdBy,
        createdAt: order.createdAt,
        orderDate: order.orderDate,
        items: order.items,
      );

      await DatabaseService.instance.updateOrder(updatedOrder);
      
      // Log sale completion
      await DatabaseService.instance.logActivity({
        'user_id': AuthService.instance.currentUser!.id!,
        'action': 'complete_sale',
        'details': 'Completed sale #${updatedOrder.orderNumber}, amount: ${updatedOrder.totalAmount}',
        'timestamp': DateTime.now().toIso8601String(),
      });
      
      // Refresh orders list
      await _loadPendingOrders();
      
    } catch (e) {
      print('Error completing sale: $e');
    }
  }

  Future<void> _editOrder(Order order) async {
    try {
      // Load order items
      final orderItems = await DatabaseService.instance.getOrderItems(order.id!);
      
      // Convert order items to CartItems
      final cartItems = await Future.wait(orderItems.map((item) async {
        final productData = await DatabaseService.instance.getProductById(item['product_id'] as int);
        if (productData == null) return null;
        
        final product = Product.fromMap(productData);
        
        return CartItem(
          product: product,
          quantity: item['quantity'] as int,
          total: item['total_amount'] as double,
          isSubUnit: item['is_sub_unit'] == 1,
          subUnitName: item['sub_unit_name'] as String?,
          subUnitQuantity: product.subUnitQuantity,
        );
      }));

      // Filter out any null items
      List<CartItem> editableCartItems = cartItems.whereType<CartItem>().toList();
      
      if (mounted) {
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => StatefulBuilder(
              builder: (context, setState) => Scaffold(
                appBar: AppBar(
                  title: Text('Edit Order #${order.orderNumber}'),
                  backgroundColor: Colors.amber,
                  actions: [
                    IconButton(
                      icon: const Icon(Icons.add),
                      onPressed: () async {
                        // Show product selection dialog
                        await _showProductSelectionDialog(context, (product, quantity, isSubUnit, subUnitName) {
                          setState(() {
                            final price = isSubUnit ? product.subUnitPrice ?? product.sellingPrice : product.sellingPrice;
                            editableCartItems.add(CartItem(
                              product: product,
                              quantity: quantity,
                              total: quantity * price,
                              isSubUnit: isSubUnit,
                              subUnitName: subUnitName,
                              subUnitQuantity: isSubUnit ? product.subUnitQuantity : null,
                            ));
                          });
                        });
                      },
                    ),
                  ],
                ),
                body: OrderCartPanel(
                  orderId: order.id!,
                  isEditing: true,
                  initialItems: editableCartItems,
                  customerName: order.customerName,
                  onRemoveItem: (index) {
                    setState(() {
                      editableCartItems.removeAt(index);
                    });
                  },
                ),
              ),
            ),
          ),
        ).then((_) {
          // Refresh the orders list when returning from edit screen
          _loadPendingOrders();
        });
      }
    } catch (e) {
      print('Error loading order for edit: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading order: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _showProductSelectionDialog(
    BuildContext context,
    Function(Product, int, bool, String?) onProductSelected
  ) async {
    try {
      final products = await DatabaseService.instance.getAllProducts();
      if (!mounted) return;

      await showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Add Product'),
          content: SizedBox(
            width: double.maxFinite,
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: products.length,
              itemBuilder: (context, index) {
                final product = Product.fromMap(products[index]);
                return ListTile(
                  title: Text(product.productName),
                  subtitle: Text('KSH ${product.sellingPrice.toStringAsFixed(2)}'),
                  onTap: () {
                    Navigator.pop(context);
                    _showQuantityDialog(context, product, onProductSelected);
                  },
                );
              },
            ),
          ),
        ),
      );
    } catch (e) {
      print('Error loading products: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading products: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _showQuantityDialog(
    BuildContext context,
    Product product,
    Function(Product, int, bool, String?) onProductSelected
  ) async {
    final quantityController = TextEditingController();
    bool isSubUnit = false;

    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: Text('Add ${product.productName}'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (product.hasSubUnits) ...[
                SwitchListTile(
                  title: Text('Sell by ${product.subUnitName ?? "pieces"}'),
                  value: isSubUnit,
                  onChanged: (value) => setState(() => isSubUnit = value),
                ),
              ],
              TextField(
                controller: quantityController,
                decoration: InputDecoration(
                  labelText: 'Quantity',
                  suffix: Text(isSubUnit ? product.subUnitName ?? 'pieces' : 'units'),
                ),
                keyboardType: TextInputType.number,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                final quantity = int.tryParse(quantityController.text);
                if (quantity != null && quantity > 0) {
                  onProductSelected(
                    product,
                    quantity,
                    isSubUnit,
                    isSubUnit ? product.subUnitName : null,
                  );
                  Navigator.pop(context);
                }
              },
              child: const Text('Add'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOrderListItem(Order order) {
    return Card(
      margin: const EdgeInsets.symmetric(
        horizontal: defaultPadding,
        vertical: defaultPadding / 2,
      ),
      child: ListTile(
        leading: const Icon(Icons.receipt),
        title: Text('Order #${order.orderNumber}'),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Customer: ${order.customerName ?? "N/A"}'),
            Text('Items: ${order.items.map((item) {
              final unitText = item.isSubUnit ? 
                  ' (${item.quantity} ${item.subUnitName ?? "pieces"})' : 
                  ' (${item.quantity} units)';
              return '${item.productName}$unitText';
            }).join(", ")}'),
          ],
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'KSH ${order.totalAmount.toStringAsFixed(2)}',
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
            IconButton(
              icon: const Icon(Icons.edit),
              onPressed: () => _editOrder(order),
            ),
          ],
        ),
        onTap: () => setState(() => _selectedOrder = order),
        selected: _selectedOrder?.orderNumber == order.orderNumber,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Row(
        children: [
          const Expanded(flex: 1, child: SideMenuWidget()),
          Expanded(
            flex: 2,
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
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.all(defaultPadding),
                    child: Row(
                      children: [
                        const Text(
                          'Pending Orders', 
                          style: TextStyle(
                            fontSize: 24, 
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        const Spacer(),
                        SizedBox(
                          width: 200,
                          child: TextField(
                            controller: _searchController,
                            decoration: InputDecoration(
                              hintText: 'Search orders...',
                              prefixIcon: const Icon(Icons.search),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                              filled: true,
                              fillColor: Colors.white,
                            ),
                            onChanged: (value) {
                              setState(() {
                                _searchQuery = value;
                              });
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: _isLoading
                        ? const Center(child: CircularProgressIndicator())
                        : _filteredOrders.isEmpty
                            ? const Center(
                                child: Text(
                                  'No pending orders found',
                                  style: TextStyle(
                                    fontSize: 18,
                                    color: Colors.white,
                                  ),
                                ),
                              )
                            : ListView.builder(
                                itemCount: _filteredOrders.length,
                                itemBuilder: (context, index) {
                                  final order = _filteredOrders[index];
                                  return _buildOrderListItem(order);
                                },
                              ),
                  ),
                ],
              ),
            ),
          ),
          if (_selectedOrder != null)
            Expanded(
              flex: 2,
              child: ReceiptPanel(
                order: _selectedOrder!,
                onProcessSale: _processSale,
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