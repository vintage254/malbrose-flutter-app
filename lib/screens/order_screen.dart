import 'package:flutter/material.dart';
import 'package:my_flutter_app/const/constant.dart';
import 'package:my_flutter_app/models/product_model.dart';
import 'package:my_flutter_app/models/order_model.dart';
import 'package:my_flutter_app/models/cart_item_model.dart';
import 'package:my_flutter_app/services/database.dart';
import 'package:my_flutter_app/services/auth_service.dart';
import 'package:my_flutter_app/widgets/order_receipt_dialog.dart';
import 'package:my_flutter_app/widgets/order_cart_panel.dart';
import 'package:my_flutter_app/widgets/side_menu_widget.dart';
import 'package:my_flutter_app/services/order_service.dart';

class OrderScreen extends StatefulWidget {
  const OrderScreen({super.key});

  @override
  State<OrderScreen> createState() => _OrderScreenState();
}

class _OrderScreenState extends State<OrderScreen> {
  List<Product> _products = [];
  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _customerNameController = TextEditingController();
  String _searchQuery = '';
  bool _isLoading = true;
  List<CartItem> _cartItems = [];

  @override
  void initState() {
    super.initState();
    _loadProducts();
  }

  Future<void> _loadProducts() async {
    try {
      final productsData = await DatabaseService.instance.getAllProducts();
      if (mounted) {
        setState(() {
          _products = productsData.map((map) => Product.fromMap(map)).toList();
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading products: $e')),
        );
      }
    }
  }

  List<Product> get _filteredProducts {
    if (_searchQuery.isEmpty) return _products;
    return _products.where((product) {
      final search = _searchQuery.toLowerCase();
      return product.productName.toLowerCase().contains(search);
    }).toList();
  }

  void _showOrderReceipt(String orderNumber) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Order Receipt'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Malbrose Hardware Store',
                  style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: defaultPadding),
              Text('Date: ${DateTime.now().toString()}'),
              Text('Customer: ${_customerNameController.text.trim()}'),
              const Divider(),
              ..._cartItems.map((item) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      flex: 2,
                      child: Text(item.product.productName),
                    ),
                    Expanded(
                      child: Text('x${item.quantity}'),
                    ),
                    Expanded(
                      child: Text('\$${item.total.toStringAsFixed(2)}'),
                    ),
                  ],
                ),
              )),
              const Divider(),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Total:',
                      style: TextStyle(fontWeight: FontWeight.bold)),
                  Text(
                    '\$${_cartItems.fold<double>(0, (sum, item) => sum + item.total).toStringAsFixed(2)}',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
          ElevatedButton(
            onPressed: () {
              // TODO: Implement printing functionality
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Printing will be implemented soon')),
              );
            },
            child: const Text('Print Receipt'),
          ),
        ],
      ),
    );
  }

  Future<void> _exportQuotation() async {
    try {
      // TODO: Implement PDF generation and export
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Export functionality coming soon!'),
          backgroundColor: Colors.orange,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error exporting: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Row(
        children: [
          const Expanded(
            flex: 1,
            child: SideMenuWidget(),
          ),
          Expanded(
            flex: 3,
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
                  // Header with export button
                  Padding(
                    padding: const EdgeInsets.all(defaultPadding),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Place Order',
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        ElevatedButton.icon(
                          onPressed: _exportQuotation,
                          icon: const Icon(Icons.file_download),
                          label: const Text('Export'),
                        ),
                      ],
                    ),
                  ),
                  
                  // Search bar
                  Padding(
                    padding: const EdgeInsets.all(defaultPadding),
                    child: TextField(
                      controller: _searchController,
                      decoration: InputDecoration(
                        hintText: 'Search products...',
                        prefixIcon: const Icon(Icons.search),
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
                  ),

                  // Products grid
                  Expanded(
                    child: GridView.builder(
                      padding: const EdgeInsets.all(defaultPadding),
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 4,
                        childAspectRatio: 1,
                        crossAxisSpacing: defaultPadding,
                        mainAxisSpacing: defaultPadding,
                      ),
                      itemCount: _filteredProducts.length,
                      itemBuilder: (context, index) {
                        final product = _filteredProducts[index];
                        return _buildProductCard(product);
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
          Expanded(
            flex: 2,
            child: OrderCartPanel(
              items: _cartItems,
              onRemoveItem: _removeFromCart,
              onPlaceOrder: _handlePlaceOrder,
              onClearCart: _clearCart,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProductCard(Product product) {
    return Card(
      child: InkWell(
        onTap: () => _addToOrder(product),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.shopping_bag, size: 40),
            const SizedBox(height: 8),
            Text(
              product.productName,
              textAlign: TextAlign.center,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            Text(
              '\$${product.sellingPrice.toStringAsFixed(2)}',
              style: const TextStyle(color: Colors.green),
            ),
          ],
        ),
      ),
    );
  }

  void _addToOrder(Product product) {
    final quantityController = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Place Order'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Product: ${product.productName}'),
            const SizedBox(height: defaultPadding),
            TextField(
              controller: quantityController,
              decoration: const InputDecoration(labelText: 'Quantity'),
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
                _addToCart(product, quantity);
                Navigator.pop(context);
              }
            },
            child: const Text('Add to Cart'),
          ),
        ],
      ),
    );
  }

  void _addToCart(Product product, int quantity) {
    setState(() {
      _cartItems.add(CartItem(product: product, quantity: quantity));
    });
  }

  void _removeFromCart(int index) {
    setState(() {
      _cartItems.removeAt(index);
    });
  }

  void _clearCart() {
    setState(() {
      _cartItems.clear();
    });
  }

  Future<void> _handlePlaceOrder() async {
    if (_cartItems.isEmpty) return;

    try {
      setState(() => _isLoading = true);
      
      // Generate a unique order number
      final orderNumber = 'ORD${DateTime.now().millisecondsSinceEpoch}';
      
      // Create one order for all items
      for (final item in _cartItems) {
        final order = Order(
          orderNumber: orderNumber,  // Same order number for all items
          productId: item.product.id!,
          quantity: item.quantity,
          sellingPrice: item.product.sellingPrice,
          buyingPrice: item.product.buyingPrice,
          totalAmount: item.total,
          createdBy: AuthService.instance.currentUser?.id ?? 1,
          orderDate: DateTime.now(),
          customerName: _customerNameController.text.trim(),
        );
        
        await DatabaseService.instance.createOrder(order);
      }

      // Clear the cart
      setState(() {
        _cartItems.clear();
        _customerNameController.clear();
      });

      // Show receipt
      if (!mounted) return;
      _showOrderReceipt(orderNumber);  // Pass the order number

      OrderService.instance.notifyOrderUpdate();  // Notify listeners about the update

    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error placing order: $e')),
      );
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _createOrder() async {
    if (_cartItems.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Cart is empty')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final orderNumber = DateTime.now().millisecondsSinceEpoch.toString();
      
      // Create orders for each cart item
      for (final item in _cartItems) {
        final order = Order(
          orderNumber: orderNumber,
          productId: item.product.id!,
          quantity: item.quantity,
          sellingPrice: item.product.sellingPrice,
          buyingPrice: item.product.buyingPrice,
          totalAmount: item.total,
          createdBy: AuthService.instance.currentUser?.id ?? 1,
          orderDate: DateTime.now(),
          customerName: _customerNameController.text.trim(),
        );
        
        await DatabaseService.instance.createOrder(order);
      }

      // Notify OrderService about the new order
      OrderService.instance.notifyOrderUpdate();

      // Clear the cart
      setState(() {
        _cartItems = [];
        _customerNameController.clear();
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Order created successfully'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error creating order: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    _customerNameController.dispose();
    super.dispose();
  }
} 