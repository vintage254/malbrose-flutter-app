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
import 'dart:convert';

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
          
          // Parse items_json to get the actual order items
          List<OrderItem> orderItems = [];
          if (firstOrder['items_json'] != null) {
            try {
              final String jsonStr = firstOrder['items_json'].toString();
              if (jsonStr.startsWith('[') && jsonStr.endsWith(']') && jsonStr != '[null]') {
                final List<dynamic> itemsList = json.decode(jsonStr);
                print('Parsed ${itemsList.length} items from items_json');
                
                for (var item in itemsList) {
                  // Skip null entries
                  if (item == null) continue;
                  
                  // Extract required fields with safe type casting
                  final productId = (item['product_id'] as num?)?.toInt() ?? 0;
                  final quantity = (item['quantity'] as num?)?.toInt() ?? 0;
                  final unitPrice = (item['unit_price'] as num?)?.toDouble() ?? 0.0;
                  final sellingPrice = (item['selling_price'] as num?)?.toDouble() ?? 0.0;
                  final itemTotal = (item['total_amount'] as num?)?.toDouble() ?? 
                                   (quantity * sellingPrice);
                  final productName = item['product_name'] as String? ?? 'Unknown Product';
                  
                  // Skip items with invalid product IDs or quantities
                  if (productId <= 0 || quantity <= 0) {
                    print('Skipping invalid item: $productName (ID: $productId, Qty: $quantity)');
                    continue;
                  }
                  
                  orderItems.add(OrderItem(
                    id: (item['item_id'] as num?)?.toInt(),
                    orderId: firstOrder['id'] as int,
                    productId: productId,
                    quantity: quantity,
                    unitPrice: unitPrice,
                    sellingPrice: sellingPrice,
                    totalAmount: itemTotal,
                    productName: productName,
                    isSubUnit: item['is_sub_unit'] == 1,
                    subUnitName: item['sub_unit_name'] as String?,
                    subUnitQuantity: (item['sub_unit_quantity'] as num?)?.toDouble(),
                    adjustedPrice: (item['adjusted_price'] as num?)?.toDouble(),
                  ));
                }
              }
            } catch (e) {
              print('Error parsing items_json: $e');
              print('Raw items_json: ${firstOrder['items_json']}');
            }
          }

          // Calculate total amount from items
          final totalAmount = orderItems.fold<double>(
            0, 
            (sum, item) => sum + item.totalAmount
          );

          final order = Order(
            id: firstOrder['id'] as int?,
            orderNumber: firstOrder['order_number'] as String,
            totalAmount: totalAmount > 0 ? totalAmount : (firstOrder['total_amount'] as num?)?.toDouble() ?? 0.0,
            customerName: firstOrder['customer_name'] as String? ?? 'Unknown Customer',
            customerId: firstOrder['customer_id'] as int?,
            orderStatus: firstOrder['status'] as String? ?? 'PENDING',
            paymentStatus: firstOrder['payment_status'] as String? ?? 'PENDING',
            createdBy: firstOrder['created_by'] as int? ?? 1,
            createdAt: DateTime.parse(firstOrder['created_at'] as String),
            orderDate: DateTime.parse(firstOrder['order_date'] as String),
            items: orderItems,
          );
          
          print('Processed Order: ${order.orderNumber}');
          print('- Items: ${orderItems.length}');
          print('- Total Amount: ${order.totalAmount}');
          for (var item in orderItems) {
            print('  * ${item.productName}: ${item.quantity} x ${item.sellingPrice} = ${item.totalAmount}');
          }
          
          combinedOrders.add(order);
        }

        setState(() {
          _pendingOrders = combinedOrders;
          _isLoading = false;
        });
      }
    } catch (e, stackTrace) {
      print('Error loading pending orders: $e');
      print('Stack trace: $stackTrace');
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

  void _processSale(Order order) async {
    setState(() {
      _isLoading = true;
    });

    try {
      print('Processing sale with payment method: ${order.paymentMethod}');
      print('Order items count: ${order.items.length}');

      // Filter out invalid items (where productId = 0)
      final validItems = order.items.where((item) => item.productId > 0).toList();
      
      if (validItems.isEmpty) {
        throw Exception('No valid product items in order');
      }
      
      // Create a new order with only the valid items
      final validOrder = order.copyWith(items: validItems);
      
      // Verify stock for each product
      for (final item in validOrder.items) {
        final productId = item.productId;
        
        if (productId <= 0) {
          print('Warning: Invalid product ID found: $productId');
          continue;
        }
        
        // Get the product from the database
        final productData = await DatabaseService.instance.getProductById(productId);
        if (productData == null) {
          throw Exception('Product not found: ID $productId');
        }
        
        // Allow negative inventory, but log a warning
        final currentQuantity = (productData['quantity'] as num).toDouble();
        final requestedQuantity = item.isSubUnit
            ? item.quantity / ((productData['sub_unit_quantity'] as num?)?.toDouble() ?? 1.0)
            : item.quantity.toDouble();
            
        if (currentQuantity < requestedQuantity) {
          print('Warning: Insufficient stock for ${productData['product_name']}. Available: $currentQuantity, Requested: $requestedQuantity');
        }
      }

      await DatabaseService.instance.withTransaction((txn) async {
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

        // Update product quantities using simple values - only for valid items
        for (var item in validItems) {
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
              'action': DatabaseService.actionCompleteSale,
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
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _completeSale(Order order) async {
    try {
      // Use the payment method from the order or default to Cash
      final paymentMethod = order.paymentMethod ?? 'Cash';
      
      // Complete the sale using the DatabaseService
      await DatabaseService.instance.completeSale(order, paymentMethod: paymentMethod);
      
      // Refresh orders list
      await _loadPendingOrders();
      
    } catch (e) {
      print('Error completing sale: $e');
    }
  }

  Future<void> _editOrder(Order order) async {
    try {
      // Load order items
      final orderItemsData = await DatabaseService.instance.getOrderItems(order.id!);
      
      print('Editing order: ${order.orderNumber} with ${orderItemsData.length} items');
      
      // Fix order items with invalid product IDs
      final fixedOrderItems = await Future.wait(orderItemsData.map((item) async {
        final productId = (item['product_id'] as int?) ?? 0;
        if (productId > 0) return item;
        
        final productName = item['product_name'] as String? ?? '';
        print('Fixing invalid product ID for item: $productName (ID: $productId)');
        
        if (productName.isEmpty) {
          print('  Product name is empty, cannot fix');
          return item;
        }
        
        // Try to find the product by name
        final products = await DatabaseService.instance.getProductByName(productName);
        if (products.isNotEmpty) {
          final newProductId = products.first['id'] as int;
          print('  Found product by name: ${products.first['product_name']} (ID: $newProductId)');
          // Return a copy of the item with updated product ID
          final updatedItem = Map<String, dynamic>.from(item);
          updatedItem['product_id'] = newProductId;
          return updatedItem;
        }
        
        // Try fuzzy matching with all products as a fallback
        final allProducts = await DatabaseService.instance.getAllProducts();
        final lowerProductName = productName.toLowerCase();
        
        for (final product in allProducts) {
          final dbProductName = (product['product_name'] as String? ?? '').toLowerCase();
          if (dbProductName.contains(lowerProductName) || lowerProductName.contains(dbProductName)) {
            final newProductId = product['id'] as int;
            print('  Found product by fuzzy match: ${product['product_name']} (ID: $newProductId)');
            final updatedItem = Map<String, dynamic>.from(item);
            updatedItem['product_id'] = newProductId;
            return updatedItem;
          }
        }
        
        print('  Could not find any matching product for: $productName');
        return item;
      }));
      
      // Convert order items to CartItems
      final cartItems = await Future.wait(fixedOrderItems.map((item) async {
        final productId = (item['product_id'] as int?) ?? 0;
        if (productId <= 0) {
          print('Skipping item with invalid product ID: ${item['product_name']}');
          return null;
        }

        try {
          final productData = await DatabaseService.instance.getProductById(productId);
          if (productData == null) {
            print('Product not found in database for ID: $productId');
            return null;
          }
        
        final product = Product.fromMap(productData);
        
        return CartItem(
          product: product,
            quantity: (item['quantity'] as int?) ?? 0,
            total: (item['total_amount'] as num?)?.toDouble() ?? 0.0,
          isSubUnit: item['is_sub_unit'] == 1,
          subUnitName: item['sub_unit_name'] as String?,
          subUnitQuantity: product.subUnitQuantity,
            adjustedPrice: (item['adjusted_price'] as num?)?.toDouble(),
        );
        } catch (e) {
          print('Error creating CartItem for product ID $productId: $e');
          return null;
        }
      }));

      // Filter out any null items
      List<CartItem> editableCartItems = cartItems.whereType<CartItem>().toList();
      
      print('Valid items after fixing: ${editableCartItems.length} of ${orderItemsData.length}');
      
      if (editableCartItems.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No valid products found in this order. Please create a new order.'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }
      
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
    final isSelected = _selectedOrder?.id == order.id;
    
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4.0, horizontal: 8.0),
      color: isSelected ? Colors.amber.shade100 : null,
      child: InkWell(
        onTap: () {
          setState(() {
            _selectedOrder = order;
          });
        },
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    Text('Order #${order.orderNumber}', style: const TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(width: 16),
                    Text('Customer: ${order.customerName ?? "N/A"}'),
                    const SizedBox(width: 16),
                    Text(
                      'KSH ${order.totalAmount.toStringAsFixed(2)}',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(width: 16),
                    IconButton(
                      icon: const Icon(Icons.edit),
                      onPressed: () => _editOrder(order),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Items: ${order.items.map((item) {
                  final unitText = item.isSubUnit ? 
                      ' (${item.quantity} ${item.subUnitName ?? "pieces"})' : 
                      ' (${item.quantity} units)';
                  return '${item.productName}$unitText';
                }).join(", ")}',
                style: const TextStyle(
                  fontSize: 14,
                  color: Colors.grey,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
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
                        const SizedBox(width: 20),
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
                            : SingleChildScrollView(
                                child: Column(
                                  children: _filteredOrders.map((order) => _buildOrderListItem(order)).toList(),
                                ),
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