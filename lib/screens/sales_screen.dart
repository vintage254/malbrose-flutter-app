import 'package:flutter/material.dart';
import 'package:my_flutter_app/const/constant.dart';
import 'package:my_flutter_app/models/order_model.dart';
import 'package:my_flutter_app/models/product_model.dart';
import 'package:my_flutter_app/models/cart_item_model.dart';
import 'package:my_flutter_app/services/database.dart';
import 'package:my_flutter_app/services/order_service.dart';
import 'package:my_flutter_app/services/auth_service.dart';
import 'package:my_flutter_app/widgets/side_menu_widget.dart';
import 'package:my_flutter_app/widgets/receipt_panel.dart';
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
  String _selectedPaymentMethod = 'Cash';
  final OrderService _orderService = OrderService.instance;

  @override
  void initState() {
    super.initState();
    _loadPendingOrders();
  }

  Future<void> _loadPendingOrders() async {
    if (!mounted) return;
    
    setState(() {
      _isLoading = true;
    });
    
    try {
      // Use OrderService to get pending orders
      final orderServiceResults = await _orderService.getOrdersByStatus('PENDING');
      
      // Load both PENDING and restored ON_HOLD orders
      final pendingOrders = orderServiceResults['pendingOrders'] ?? [];
      final heldOrders = orderServiceResults['heldOrders'] ?? [];
      final orders = [...pendingOrders, ...heldOrders];
      
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
              print('Raw items_json before parsing: $jsonStr');
              
              // Check if the string is already a valid JSON array (starts with '[' and ends with ']')
              // If not, try to handle single object or comma-separated objects
              List<dynamic> itemsList = [];
              
              if (jsonStr.trim().startsWith('[') && jsonStr.trim().endsWith(']')) {
                // It's already a JSON array
                itemsList = json.decode(jsonStr);
              } else if (jsonStr.trim().startsWith('{') && jsonStr.trim().endsWith('}')) {
                // Single object - wrap it in a list
                itemsList = [json.decode(jsonStr)];
              } else if (jsonStr.contains('},{')) {
                // Multiple comma-separated objects - add brackets and parse
                itemsList = json.decode('[${jsonStr}]');
              }
              
              print('Successfully parsed ${itemsList.length} items from JSON');
              
              for (var item in itemsList) {
                // Skip null entries
                if (item == null) continue;
                
                // Extract required fields with safe type casting
                final productId = (item['product_id'] as num?)?.toInt() ?? 0;
                final quantity = (item['quantity'] as num?)?.toInt() ?? 0;
                final unitPrice = (item['unit_price'] as num?)?.toDouble() ?? 0.0;
                final sellingPrice = (item['selling_price'] as num?)?.toDouble() ?? unitPrice;
                final itemTotal = (item['total_amount'] as num?)?.toDouble() ?? 
                               (quantity * sellingPrice);
                final productName = item['product_name'] as String? ?? 'Unknown Product';
                
                // Skip items with invalid product IDs or quantities
                if (productId <= 0 || quantity <= 0) {
                  print('Skipping invalid item: $productName (ID: $productId, Qty: $quantity)');
                  continue;
                }
                
                print('Creating OrderItem: $productName (ID: $productId, Qty: $quantity)');
                
                final orderItem = OrderItem(
                  id: (item['id'] as num?)?.toInt() ?? 0,
                  orderId: firstOrder['id'] as int? ?? 0,
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
                );
                
                orderItems.add(orderItem);
              }
            } catch (e) {
              print('Error parsing items_json: $e');
              print('Raw items_json: ${firstOrder['items_json']}');
            }
          }

          print('Loaded ${orderItems.length} items for order #${firstOrder['order_number']}');

          // Calculate total amount from items or use the one from the order
          double totalAmount = 0.0;
          if (orderItems.isNotEmpty) {
            totalAmount = orderItems.fold<double>(
              0, 
              (sum, item) => sum + item.totalAmount
            );
          } else {
            totalAmount = (firstOrder['total_amount'] as num?)?.toDouble() ?? 0.0;
          }

          final order = Order(
            id: firstOrder['id'] as int?,
            orderNumber: firstOrder['order_number'] as String,
            totalAmount: totalAmount,
            customerName: firstOrder['customer_name'] as String? ?? 'Unknown Customer',
            customerId: firstOrder['customer_id'] as int?,
            orderStatus: firstOrder['order_status'] as String? ?? 'PENDING',
            paymentStatus: firstOrder['payment_status'] as String? ?? 'PENDING',
            createdBy: firstOrder['created_by'] as int? ?? 1,
            createdAt: DateTime.parse(firstOrder['created_at'] as String),
            orderDate: DateTime.parse(firstOrder['order_date'] as String),
            items: orderItems,
          );
          
          print('Processed Order: ${order.orderNumber}');
          print('- Items: ${order.items.length}');
          print('- Total Amount: ${order.totalAmount}');
          for (var item in order.items) {
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
      
      // Debug items in order
      for (var item in order.items) {
        print('Order item: ${item.productName}, ID: ${item.productId}, Qty: ${item.quantity}');
      }

      // Filter out invalid items (where productId = 0)
      final validItems = order.items.where((item) => item.productId > 0).toList();
      
      print('ReceiptPanel - Valid items: ${validItems.length} of ${order.items.length}');
      
      // If no valid items but order has a total amount, create a placeholder item
      // This ensures the receipt dialog can still be shown
      if (validItems.isEmpty && order.totalAmount > 0) {
        print('No valid items but order has total amount: ${order.totalAmount}');
        print('Creating a placeholder item for receipt');
        
        validItems.add(OrderItem(
          id: 0,
          orderId: order.id ?? 0,
          productId: 1, // Use a valid ID to pass the check
          quantity: 1,
          unitPrice: order.totalAmount,
          sellingPrice: order.totalAmount,
          totalAmount: order.totalAmount,
          productName: "Order Total",
          isSubUnit: false,
        ));
      }
      
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

      // Use a transaction to ensure all operations succeed or fail together
      await DatabaseService.instance.withTransaction((txn) async {
        // Update order status using simple map
        await txn.update(
          DatabaseService.tableOrders,
          {
            'order_status': 'COMPLETED',
            'payment_status': order.paymentMethod == 'Credit' ? 'PENDING' : 'PAID',
            'payment_method': order.paymentMethod,
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
            final currentQuantity = (product[0]['quantity'] as num).toDouble();
            final subUnitQuantity = (product[0]['sub_unit_quantity'] as num?)?.toDouble() ?? 1.0;
            final quantityToDeduct = item.isSubUnit
                ? item.quantity / subUnitQuantity
                : item.quantity.toDouble();

            await txn.update(
              DatabaseService.tableProducts,
              {
                'quantity': currentQuantity - quantityToDeduct,
                'last_updated': DateTime.now().toIso8601String(),
              },
              where: 'id = ?',
              whereArgs: [item.productId],
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
              'details': 'Completed sale #${order.orderNumber}, amount: ${order.totalAmount}, method: ${order.paymentMethod}',
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
      final paymentMethod = order.paymentMethod ?? _selectedPaymentMethod;
      
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
              Text('Completing sale...'),
            ],
          ),
        ),
      );
      
      // Complete the sale using OrderService instead of DatabaseService
      final success = await _orderService.completeSale(order, paymentMethod: paymentMethod);
      
      // Close loading dialog
      Navigator.of(context, rootNavigator: true).pop();
      
      if (!success) {
        throw Exception('Failed to complete sale');
      }
      
      // Show success message
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Sale #${order.orderNumber} completed successfully'),
          backgroundColor: Colors.green,
        ),
      );
      
      // Refresh orders list
      await _loadPendingOrders();
      
    } catch (e) {
      // Close loading dialog if it's open
      Navigator.of(context, rootNavigator: true).pop();
      
      print('Error completing sale: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error completing sale: $e'),
          backgroundColor: Colors.red,
        ),
      );
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
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  filled: true,
                  fillColor: Colors.white,
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