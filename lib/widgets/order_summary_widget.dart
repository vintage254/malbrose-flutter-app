import 'package:flutter/material.dart';
import 'package:my_flutter_app/services/order_service.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:my_flutter_app/widgets/order_cart_panel.dart';
import 'package:my_flutter_app/models/cart_item_model.dart';
import 'package:my_flutter_app/services/database.dart';
import 'package:my_flutter_app/models/product_model.dart';

class OrderSummaryWidget extends StatefulWidget {
  const OrderSummaryWidget({super.key});

  @override
  State<OrderSummaryWidget> createState() => _OrderSummaryWidgetState();
}

class _OrderSummaryWidgetState extends State<OrderSummaryWidget> {
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  void _onScroll() {
    if (_scrollController.position.pixels == _scrollController.position.maxScrollExtent) {
      // Load more orders if needed
      // Currently showing all for the day, so no need to load more
    }
  }

  Future<void> _handleOrderTap(BuildContext context, Map<String, dynamic> order) async {
    final status = order['status'] as String? ?? 'UNKNOWN';
    
    // Handle both PENDING and ON_HOLD orders similarly
    if (status == 'PENDING' || status == 'ON_HOLD') {
      try {
        // Safely extract the order ID
        final orderId = order['id'];
        if (orderId == null) {
          print('Error: Order ID is null');
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Invalid order data: missing ID'), backgroundColor: Colors.red),
          );
          return;
        }
        
        // Load order items
        final orderItems = await DatabaseService.instance.getOrderItems(orderId as int);
        
        // Convert order items to CartItems
        final cartItems = await Future.wait(orderItems.map((item) async {
          // Safely get the product ID
          final productId = item['product_id'];
          if (productId == null) return null;
          
          try {
            // Get the product details
            final productData = await DatabaseService.instance.getProductById(productId as int);
            if (productData == null) return null;
            
            final product = Product.fromMap(productData);
            
            // Safely extract other fields with defaults
            final quantity = (item['quantity'] as int?) ?? 1;
            final totalAmount = (item['total_amount'] as double?) ?? 0.0;
            final isSubUnit = item['is_sub_unit'] == 1;
            final subUnitName = item['sub_unit_name'] as String?;
            
            return CartItem(
              product: product,
              quantity: quantity,
              total: totalAmount,
              isSubUnit: isSubUnit,
              subUnitName: subUnitName,
              subUnitQuantity: product.subUnitQuantity,
            );
          } catch (productError) {
            print('Error processing product: $productError');
            return null;
          }
        }));

        // Filter out any null items
        List<CartItem> editableCartItems = cartItems.whereType<CartItem>().toList();
        
        if (mounted) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => StatefulBuilder(
                builder: (context, setState) => Scaffold(
                  appBar: AppBar(
                    title: Text('Edit Order #${order['order_number'] ?? 'Unknown'}'),
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
                    orderId: orderId as int,
                    isEditing: true,
                    initialItems: editableCartItems,
                    customerName: order['customer_name'] as String?,
                    onRemoveItem: (index) {
                      if (index >= 0 && index < editableCartItems.length) {
                        setState(() {
                          editableCartItems.removeAt(index);
                        });
                      }
                    },
                  ),
                ),
              ),
            ),
          );
        }
      } catch (e) {
        print('Error loading order: $e');
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

  @override
  Widget build(BuildContext context) {
    return Consumer<OrderService>(
      builder: (context, orderService, child) {
        final recentOrders = orderService.recentOrders;
        
        return Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Colors.orange,
                Colors.deepOrange,
              ],
            ),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Today\'s Orders',
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    IconButton(
                      icon: Icon(Icons.refresh, color: Colors.white),
                      onPressed: () {
                        orderService.refreshStats();
                      },
                      tooltip: 'Refresh Orders',
                    ),
                  ],
                ),
              ),
              Expanded(
                child: recentOrders.isEmpty 
                  ? Center(child: Text('No orders found', style: TextStyle(color: Colors.white)))
                  : ListView.builder(
                      controller: _scrollController,
                      itemCount: recentOrders.length,
                      itemBuilder: (context, index) {
                        final order = recentOrders[index];
                        
                        // Check for both 'status' and 'order_status' fields since both might be used
                        final status = order['order_status'] as String? ?? 
                                      order['status'] as String? ?? 
                                      'PENDING';
                                      
                        // Check if this order is a converted held order that should be hidden
                        if (status == 'CONVERTED') {
                          return SizedBox.shrink(); // Hide converted orders
                        }
                        
                        final paymentStatus = order['payment_status'] as String? ?? 'PENDING';
                        final createdAt = DateTime.parse(order['created_at'] as String);
                        
                        return Card(
                          margin: const EdgeInsets.symmetric(
                            horizontal: 16.0,
                            vertical: 8.0,
                          ),
                          color: _getStatusColor(status),
                          child: InkWell(
                            onTap: () => _handleOrderTap(context, order),
                            child: Padding(
                              padding: const EdgeInsets.all(16.0),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Flexible(
                                        child: Text(
                                          'Order #${order['order_number']}',
                                          style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                            color: Colors.white,
                                          ),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        DateFormat('HH:mm').format(createdAt),
                                        style: const TextStyle(color: Colors.white70),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    'Customer: ${order['customer_name'] ?? 'Walk-in'}',
                                    style: const TextStyle(color: Colors.white),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  Text(
                                    'Total: KSH ${NumberFormat('#,##0.00').format(order['total_amount'])}',
                                    style: const TextStyle(color: Colors.white),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        'Status: $status',
                                        style: const TextStyle(color: Colors.white70),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      if (paymentStatus != 'PENDING')
                                        Chip(
                                          label: Text(
                                            paymentStatus,
                                            style: TextStyle(fontSize: 10, color: Colors.white),
                                          ),
                                          backgroundColor: paymentStatus == 'PAID' 
                                            ? Colors.green 
                                            : Colors.orange,
                                          padding: EdgeInsets.zero,
                                          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                        ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
              ),
            ],
          ),
        );
      },
    );
  }

  Color _getStatusColor(String status) {
    switch (status.toUpperCase()) {
      case 'COMPLETED':
        return Colors.green.withOpacity(0.7);
      case 'PENDING':
        return Colors.orange.withOpacity(0.7);
      default:
        return Colors.grey.withOpacity(0.7);
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }
} 