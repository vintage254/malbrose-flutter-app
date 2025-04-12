import 'package:flutter/material.dart';
import 'package:my_flutter_app/const/constant.dart';
import 'package:my_flutter_app/models/product_model.dart';
import 'package:my_flutter_app/models/order_model.dart';
import 'package:my_flutter_app/models/cart_item_model.dart';
import 'package:my_flutter_app/models/customer_model.dart';
import 'package:my_flutter_app/services/database.dart';
import 'package:my_flutter_app/services/auth_service.dart';
import 'package:my_flutter_app/widgets/order_receipt_dialog.dart';
import 'package:my_flutter_app/widgets/order_cart_panel.dart';
import 'package:my_flutter_app/widgets/side_menu_widget.dart';
import 'package:my_flutter_app/services/order_service.dart';
import 'package:my_flutter_app/screens/held_orders_screen.dart';
import 'dart:io';

class OrderScreen extends StatefulWidget {
  final Order? editingOrder;
  final bool isEditing;
  final VoidCallback? onHoldOrderPressed;
  final bool preserveOrderNumber;
  final bool viewOnly;
  final bool preventDuplicateCreation;

  const OrderScreen({
    super.key, 
    this.editingOrder,
    this.isEditing = false,
    this.onHoldOrderPressed,
    this.preserveOrderNumber = false,
    this.viewOnly = false,
    this.preventDuplicateCreation = false,
  });

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
  String? _selectedDepartment;
  int customerId = 0; // Already set to 0 as default

  @override
  void initState() {
    super.initState();
    _loadProducts();
    
    // If editing an existing order, load its items
    // Handle editing of existing orders or when using the preventDuplicateCreation flag
    if ((widget.isEditing || widget.preventDuplicateCreation) && widget.editingOrder != null) {
      _customerNameController.text = widget.editingOrder!.customerName ?? '';
      
      print('OrderScreen - Editing order #${widget.editingOrder!.orderNumber}');
      
      if (widget.editingOrder!.items.isNotEmpty) {
        // Convert order items to cart items
        _cartItems = widget.editingOrder!.items.map((item) => CartItem.fromOrderItem(item)).toList();
        print('OrderScreen - Loaded ${_cartItems.length} items from order items list');
      } else {
        print('OrderScreen - No items in order.items, trying to load from database');
        // Attempt to load the order items from the database
        _loadOrderItems(widget.editingOrder!.id!);
      }
    }
  }

  @override
  void didUpdateWidget(OrderScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    
    // Check if the editing order has changed
    if (widget.editingOrder != null && 
        (oldWidget.editingOrder?.id != widget.editingOrder?.id ||
         oldWidget.editingOrder?.orderNumber != widget.editingOrder?.orderNumber)) {
      
      print('OrderScreen - Order changed, refreshing data');
      
      // Update customer name
      _customerNameController.text = widget.editingOrder!.customerName ?? '';
      
      // Clear existing cart items and load new ones
      setState(() {
        _cartItems = [];
      });
      
      // Load items for the new order
      if (widget.editingOrder!.items.isNotEmpty) {
        setState(() {
          _cartItems = widget.editingOrder!.items.map((item) => CartItem.fromOrderItem(item)).toList();
        });
        print('OrderScreen - Loaded ${_cartItems.length} items from new order');
      } else if (widget.editingOrder!.id != null) {
        _loadOrderItems(widget.editingOrder!.id!);
      }
    }
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

  Future<void> _loadOrderItems(int orderId) async {
    try {
      final orderItemsData = await DatabaseService.instance.getOrderItems(orderId);
      
      if (orderItemsData.isEmpty) {
        print('No order items found in database for order ID: $orderId');
        return;
      }
      
      // Convert the map data to OrderItem objects
      final orderItems = orderItemsData.map((map) => OrderItem.fromMap(map)).toList();
      
      // Convert OrderItems to CartItems
      final cartItems = orderItems.map((item) => CartItem.fromOrderItem(item)).toList();
      
      if (mounted) {
        setState(() {
          _cartItems = cartItems;
        });
        print('OrderScreen - Loaded ${_cartItems.length} items from database');
      }
    } catch (e) {
      print('Error loading order items: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading order items: $e')),
        );
      }
    }
  }

  List<Product> get _filteredProducts {
    if (_searchQuery.isEmpty && _selectedDepartment == null) return _products;
    return _products.where((product) {
      // Handle search query filter
      final matchesSearch = _searchQuery.isEmpty || 
          product.productName.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          (product.description?.toLowerCase() ?? '').contains(_searchQuery.toLowerCase()) ||
          product.supplier.toLowerCase().contains(_searchQuery.toLowerCase());
      
      // Handle department filter
      final matchesDepartment = _selectedDepartment == null || 
          product.department == _selectedDepartment;
      
      return matchesSearch && matchesDepartment;
    }).toList();
  }

  void _showOrderReceipt(String orderNumber) {
    // Add debug information
    print('_showOrderReceipt - Cart items count: ${_cartItems.length}');
    
    if (_cartItems.isEmpty) {
      print('_showOrderReceipt - WARNING: No items to show in receipt!');
      return;
    }
    
    // Create a copy of the cart items to prevent issues when the cart is cleared
    final List<CartItem> receiptItems = List.from(_cartItems);
    
    // Print the first item for debugging
    if (receiptItems.isNotEmpty) {
      final firstItem = receiptItems.first;
      print('_showOrderReceipt - First item: ${firstItem.product.productName}, Quantity: ${firstItem.quantity}, Total: ${firstItem.total}');
    }
    
    showDialog(
      context: context,
      builder: (context) => OrderReceiptDialog(
        items: receiptItems,
        customerName: _customerNameController.text.trim(),
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
                        Text(
                          widget.isEditing ? 'Edit Order #${widget.editingOrder?.orderNumber}' : 'Place Order',
                          style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Flexible(
                          child: SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                ElevatedButton.icon(
                                  onPressed: () => Navigator.push(
                                    context,
                                    MaterialPageRoute(builder: (context) => const HeldOrdersScreen()),
                                  ),
                                  icon: const Icon(Icons.pause_circle_filled),
                                  label: const Text('Held Orders'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.orange,
                                    foregroundColor: Colors.white,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                ElevatedButton.icon(
                                  onPressed: _exportQuotation,
                                  icon: const Icon(Icons.file_download),
                                  label: const Text('Export'),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  
                  // Search bar
                  Padding(
                    padding: const EdgeInsets.all(defaultPadding),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: _searchController,
                                decoration: InputDecoration(
                                  hintText: 'Search products by name, description or supplier...',
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
                          ],
                        ),
                        const SizedBox(height: 10),
                        // Department filter as a separate row to avoid flex issues
                        Container(
                          width: 200,
                          child: DropdownButton<String?>(
                            value: _selectedDepartment,
                            hint: const Text('All Departments'),
                            isExpanded: true,
                            underline: Container(
                              height: 1,
                              color: Colors.grey,
                            ),
                            items: [
                              const DropdownMenuItem<String?>(
                                value: null,
                                child: Text('All Departments'),
                              ),
                              ...Product.getDepartments().map((dept) => 
                                DropdownMenuItem<String?>(
                                  value: dept,
                                  child: Text(dept),
                                )
                              ),
                            ],
                            onChanged: (value) {
                              setState(() {
                                _selectedDepartment = value;
                              });
                            },
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Products grid
                  Expanded(
                    child: _isLoading
                      ? const Center(child: CircularProgressIndicator())
                      : GridView.builder(
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
              initialItems: _cartItems,
              customerName: _customerNameController.text,
              onRemoveItem: _removeFromCart,
              onPlaceOrder: _handlePlaceOrder,
              onClearCart: _clearCart,
              onCustomerNameChanged: (name) {
                setState(() {
                  _customerNameController.text = name;
                });
              },
              isEditing: widget.isEditing,
              orderButtonText: widget.isEditing ? 'Update Order' : 'Place Order',
              onHoldOrderPressed: widget.isEditing ? null : _holdOrder,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProductCard(Product product) {
    return Card(
      child: InkWell(
        onTap: () => _showOrderDialog(product),
        child: Padding(
          padding: const EdgeInsets.all(8.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Expanded(
                child: product.image != null && product.image!.isNotEmpty
                  ? Image.file(
                      File(product.image!),
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) {
                        print('Error loading image: $error');
                        return const Icon(Icons.shopping_bag, size: 40);
                      },
                    )
                  : const Icon(Icons.shopping_bag, size: 40),
              ),
              const SizedBox(height: 8),
              Text(
                product.productName,
                textAlign: TextAlign.center,
                style: const TextStyle(fontWeight: FontWeight.bold),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              Text(
                'KSH ${product.sellingPrice.toStringAsFixed(2)}',
                style: const TextStyle(color: Colors.green),
              ),
              if (product.hasSubUnits)
                Text(
                  '(${product.subUnitName ?? 'pieces'} available)',
                  style: const TextStyle(fontSize: 10, fontStyle: FontStyle.italic),
                  textAlign: TextAlign.center,
                ),
            ],
          ),
        ),
      ),
    );
  }

  void _showOrderDialog(Product product) {
    if (product.hasSubUnits) {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: Text('Select Unit Type'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                title: Text('Full ${product.productName}'),
                subtitle: Text('KSH ${product.sellingPrice}'),
                onTap: () {
                  Navigator.pop(context);
                  _showQuantityDialog(product, false, product.sellingPrice);
                },
              ),
              if (product.subUnitPrice != null)
                ListTile(
                  title: Text('Per ${product.subUnitName ?? "piece"}'),
                  subtitle: Text('KSH ${product.subUnitPrice}'),
                  onTap: () {
                    Navigator.pop(context);
                    _showQuantityDialog(product, true, product.subUnitPrice!);
                  },
                ),
            ],
          ),
        ),
      );
    } else {
      _showQuantityDialog(product, false, product.sellingPrice);
    }
  }

  void _showQuantityDialog(Product product, bool isSubUnit, double defaultPrice) {
    final quantityController = TextEditingController();
    final priceController = TextEditingController(text: defaultPrice.toString());
    final maxQuantity = isSubUnit ? 
        (product.quantity * (product.subUnitQuantity ?? 1)) : 
        product.quantity;
    bool showWarning = false;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: Text('Add ${product.productName}'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: quantityController,
                decoration: InputDecoration(
                  labelText: 'Quantity (Available: $maxQuantity)',
                  suffix: Text(isSubUnit ? product.subUnitName ?? 'pieces' : 'units'),
                ),
                keyboardType: TextInputType.number,
                onChanged: (value) {
                  final enteredQuantity = int.tryParse(value);
                  if (enteredQuantity != null) {
                    setState(() {
                      showWarning = enteredQuantity > maxQuantity;
                    });
                  }
                },
              ),
              TextField(
                controller: priceController,
                decoration: const InputDecoration(
                  labelText: 'Price per unit',
                  prefixText: 'KSH ',
                ),
                keyboardType: TextInputType.number,
              ),
              if (showWarning)
                Padding(
                  padding: const EdgeInsets.only(top: 8.0),
                  child: Text(
                    'Warning: This quantity exceeds available stock and will result in negative inventory.',
                    style: TextStyle(color: Colors.red, fontSize: 12),
                  ),
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
                final price = double.tryParse(priceController.text);
                
                if (quantity != null && quantity > 0 &&
                    price != null && price > 0) {
                  setState(() {
                    _addToCart(product, quantity, isSubUnit, isSubUnit ? product.subUnitName : null, price);
                  });
                  Navigator.pop(context);
                }
              },
              child: const Text('Add to Cart'),
            ),
          ],
        ),
      ),
    );
  }

  void _removeFromCart(int index) {
    setState(() {
      _cartItems.removeAt(index);
    });
  }

  void _clearCart() {
    setState(() {
      _cartItems.clear();
      _customerNameController.clear();
    });
  }

  // Method to handle holding an order
  Future<void> _holdOrder() async {
    if (_cartItems.isEmpty || _customerNameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please add items and enter a customer name before holding an order'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // If a callback is provided, use it instead of the default implementation
    if (widget.onHoldOrderPressed != null) {
      widget.onHoldOrderPressed!();
      return;
    }
    
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
              Text('Saving order on hold...'),
            ],
          ),
        ),
      );
      
      final customerName = _customerNameController.text.trim();
      final now = DateTime.now();
      final datePrefix = '${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}';
      final timeComponent = '${now.hour.toString().padLeft(2, '0')}${now.minute.toString().padLeft(2, '0')}${now.second.toString().padLeft(2, '0')}${(now.millisecond ~/ 10).toString().padLeft(2, '0')}';
      final orderNumber = 'HLD-$datePrefix-$timeComponent';
      
      final currentUser = AuthService.instance.currentUser;
      if (currentUser == null) throw Exception('User not logged in');
      
      // Create order map with customer information
      final orderMap = {
        'order_number': orderNumber,
        'customer_id': customerId > 0 ? customerId : null,
        'customer_name': customerName,
        'total_amount': _cartItems.fold<double>(0, (sum, item) => sum + item.total),
        'order_status': 'ON_HOLD',
        'payment_status': 'PENDING',
        'created_by': currentUser.id is String 
            ? int.tryParse(currentUser.id as String) ?? 0 
            : (currentUser.id as int? ?? 0),
        'created_at': now.toIso8601String(),
        'order_date': now.toIso8601String(),
      };
      
      // Convert cart items to order items
      final orderItems = _cartItems.map((item) => {
        'product_id': item.product.id ?? 0,
        'quantity': item.quantity,
        'unit_price': item.product.buyingPrice,
        'selling_price': item.product.sellingPrice,
        'total_amount': item.total,
        'product_name': item.product.productName,
        'is_sub_unit': item.isSubUnit ? 1 : 0,
        'sub_unit_name': item.subUnitName,
        'sub_unit_quantity': item.subUnitQuantity != null ? item.subUnitQuantity!.toDouble() : null,
        'adjusted_price': item.adjustedPrice,
      }).toList();

      // Create the order
      await DatabaseService.instance.createOrder(orderMap, orderItems);
      
      // Close loading dialog
      if (mounted) {
        Navigator.of(context, rootNavigator: true).pop();
      }
      
      // Show success message
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Order #$orderNumber placed on hold successfully'),
            backgroundColor: Colors.green,
          ),
        );
      }
      
      // Clear the cart
      _clearCart();
      
    } catch (e) {
      // Close loading dialog
      if (mounted) {
        Navigator.of(context, rootNavigator: true).pop();
      }
      
      // Show error message
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error holding order: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _addToCart(Product product, int quantity, bool isSubUnit, String? selectedSubUnit, [double? adjustedPrice]) {
    final defaultPrice = isSubUnit ? product.subUnitPrice ?? product.sellingPrice : product.sellingPrice;
    final price = adjustedPrice ?? defaultPrice;
    
    setState(() {
      _cartItems.add(CartItem(
        product: product,
        quantity: quantity,
        total: quantity * price,
        isSubUnit: isSubUnit,
        subUnitName: selectedSubUnit,
        subUnitQuantity: isSubUnit ? product.subUnitQuantity : null,
        adjustedPrice: adjustedPrice != defaultPrice ? adjustedPrice : null,
      ));
    });
  }

  Future<void> _handlePlaceOrder() async {
    if (_cartItems.isEmpty) return;

    try {
      setState(() => _isLoading = true);
      
      final currentUser = AuthService.instance.currentUser;
      if (currentUser == null) throw Exception('User not logged in');

      final customerName = _customerNameController.text.trim();
      
      if (customerName.isEmpty) {
        throw Exception('Customer name is required');
      }
      
      final now = DateTime.now();
      
      // Handle editing of existing orders or when using the preventDuplicateCreation flag
      if ((widget.isEditing || widget.preventDuplicateCreation) && widget.editingOrder != null) {
        // Update existing order
        final updatedOrder = Order(
          id: widget.editingOrder!.id,
          orderNumber: widget.editingOrder!.orderNumber,
          customerId: null, // Let createOrder handle it
          customerName: customerName,
          totalAmount: _cartItems.fold<double>(0, (sum, item) => sum + item.total),
          orderStatus: widget.editingOrder!.orderStatus,
          paymentStatus: widget.editingOrder!.paymentStatus,
          paymentMethod: widget.editingOrder!.paymentMethod,
          createdBy: widget.editingOrder!.createdBy,
          createdAt: widget.editingOrder!.createdAt,
          orderDate: widget.editingOrder!.orderDate,
          items: _cartItems.map((item) => OrderItem(
            orderId: widget.editingOrder!.id ?? 0,
            productId: item.product.id ?? 0,
            quantity: item.quantity,
            unitPrice: item.product.buyingPrice,
            sellingPrice: item.product.sellingPrice,
            totalAmount: item.total,
            productName: item.product.productName,
            isSubUnit: item.isSubUnit,
            subUnitName: item.subUnitName,
            subUnitQuantity: item.subUnitQuantity?.toDouble(),
            adjustedPrice: item.adjustedPrice,
          )).toList(),
        );
        
        // Convert to map for database update
        final orderMap = updatedOrder.toMap();
        final orderItems = updatedOrder.items?.map((item) => item.toMap()).toList() ?? [];
        
        // Update the order in the database
        await DatabaseService.instance.updateOrder(updatedOrder.id!, orderMap, orderItems);
        
        // Log the update
        await DatabaseService.instance.logActivity(
          1, // Default admin user ID
          'admin',
          DatabaseService.actionUpdateOrder,
          'Order Updated',
          'Order #${updatedOrder.orderNumber} was updated',
        );
        
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Order updated successfully'),
            backgroundColor: Colors.green,
          ),
        );
        
        // Navigate back to the previous screen
        Navigator.pop(context);
      } else if (widget.preventDuplicateCreation && widget.editingOrder != null) {
        // If we're preventing duplicate creation but not in edit mode,
        // treat this as an update to the existing order anyway
        print('Using preventDuplicateCreation flag to update existing order instead of creating a new one');
        
        // Create an updated order with the same ID but new items
        final updatedOrder = Order(
          id: widget.editingOrder!.id,
          orderNumber: widget.editingOrder!.orderNumber,
          customerId: null,
          customerName: customerName,
          totalAmount: _cartItems.fold<double>(0, (sum, item) => sum + item.total),
          orderStatus: 'PENDING',
          paymentStatus: 'PENDING',
          paymentMethod: widget.editingOrder!.paymentMethod,
          createdBy: widget.editingOrder!.createdBy,
          createdAt: widget.editingOrder!.createdAt,
          orderDate: widget.editingOrder!.orderDate,
          items: _cartItems.map((item) => OrderItem(
            orderId: widget.editingOrder!.id ?? 0,
            productId: item.product.id ?? 0,
            quantity: item.quantity,
            unitPrice: item.product.buyingPrice,
            sellingPrice: item.product.sellingPrice,
            totalAmount: item.total,
            productName: item.product.productName,
            isSubUnit: item.isSubUnit,
            subUnitName: item.subUnitName,
            subUnitQuantity: item.subUnitQuantity?.toDouble(),
            adjustedPrice: item.adjustedPrice,
          )).toList(),
        );
        
        // Convert to map for database update
        final orderMap = updatedOrder.toMap();
        final orderItems = updatedOrder.items?.map((item) => item.toMap()).toList() ?? [];
        
        // Update the order in the database
        await DatabaseService.instance.updateOrder(updatedOrder.id!, orderMap, orderItems);
        
        // Log the update
        await DatabaseService.instance.logActivity(
          1, // Default admin user ID
          'admin',
          DatabaseService.actionUpdateOrder,
          'Order Updated from Held Order',
          'Order #${updatedOrder.orderNumber} was updated from held order',
        );
        
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Order updated successfully'),
            backgroundColor: Colors.green,
          ),
        );
        
        // Navigate back to the previous screen
        Navigator.pop(context);
      } else {
        // Create completely new order
        // Generate a more consistent order number with date prefix for better tracking
        String orderNumber;
        
        // If this is a held order being restored and we want to preserve the order number
        if (widget.preserveOrderNumber && widget.editingOrder != null) {
          orderNumber = widget.editingOrder!.orderNumber;
          print('Using existing order number for restored held order: $orderNumber');
        } else {
          // Generate a new order number
          final datePrefix = '${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}';
          final timeComponent = '${now.hour.toString().padLeft(2, '0')}${now.minute.toString().padLeft(2, '0')}${now.second.toString().padLeft(2, '0')}${(now.millisecond ~/ 10).toString().padLeft(2, '0')}';
          orderNumber = 'ORD-$datePrefix-$timeComponent';
        }
        
        // Create order with proper customer information
        final orderMap = {
          'order_number': orderNumber,
          'customer_id': customerId > 0 ? customerId : null,
          'customer_name': customerName,
          'total_amount': _cartItems.fold<double>(0, (sum, item) => sum + item.total),
          'order_status': 'PENDING',
          'payment_status': 'PENDING',
          'created_by': currentUser.id is String 
              ? int.tryParse(currentUser.id as String) ?? 0 
              : (currentUser.id as int? ?? 0),
          'created_at': now.toIso8601String(),
          'order_date': now.toIso8601String(),
        };
        
        // Convert cart items to order items
        final orderItems = _cartItems.map((item) => {
          'product_id': item.product.id ?? 0,
          'quantity': item.quantity,
          'unit_price': item.product.buyingPrice,
          'selling_price': item.product.sellingPrice,
          'total_amount': item.total,
          'product_name': item.product.productName,
          'is_sub_unit': item.isSubUnit ? 1 : 0,
          'sub_unit_name': item.subUnitName,
          'sub_unit_quantity': item.subUnitQuantity != null ? item.subUnitQuantity!.toDouble() : null,
          'adjusted_price': item.adjustedPrice,
        }).toList();

        // Use the DatabaseService to handle the transaction
        await DatabaseService.instance.createOrder(orderMap, orderItems);

        if (!mounted) return;
        
        // Show the receipt before clearing the cart
        _showOrderReceipt(orderNumber);
        
        // Wait a moment before clearing the cart to ensure the receipt dialog has time to capture the items
        Future.delayed(Duration(milliseconds: 500), () {
          if (mounted) {
            setState(() {
              _cartItems.clear();
              _customerNameController.clear();
            });
          }
        });
        
        OrderService.instance.notifyOrderUpdate();
      }

    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error ${widget.isEditing ? "updating" : "placing"} order: $e')),
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