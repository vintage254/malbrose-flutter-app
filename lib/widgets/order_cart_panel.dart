import 'package:flutter/material.dart';
import 'dart:async';
import 'package:my_flutter_app/models/cart_item_model.dart';
import 'package:my_flutter_app/const/constant.dart';
import 'package:my_flutter_app/services/auth_service.dart';
import 'package:my_flutter_app/services/database.dart';
import 'package:my_flutter_app/services/order_service.dart';
import 'package:my_flutter_app/models/customer_model.dart';
import 'package:my_flutter_app/models/order_model.dart';

class OrderCartPanel extends StatefulWidget {
  final List<CartItem> initialItems;
  final String? customerName;
  final int? orderId;
  final bool isEditing;
  final Function(int)? onRemoveItem;
  final VoidCallback? onPlaceOrder;
  final VoidCallback? onClearCart;
  final Function(String)? onCustomerNameChanged;

  const OrderCartPanel({
    super.key,
    required this.initialItems,
    this.customerName,
    this.orderId,
    this.isEditing = false,
    this.onRemoveItem,
    this.onPlaceOrder,
    this.onClearCart,
    this.onCustomerNameChanged,
  });

  @override
  State<OrderCartPanel> createState() => _OrderCartPanelState();
}

class _OrderCartPanelState extends State<OrderCartPanel> {
  late final TextEditingController _customerNameController;
  List<Customer> _customers = [];
  Customer? _selectedCustomer;
  bool _isLoadingCustomers = false;
  Timer? _debounceTimer;

  @override
  void initState() {
    super.initState();
    _customerNameController = TextEditingController(text: widget.customerName ?? '');
    _loadInitialCustomer();
    _loadCustomers();
  }

  @override
  void didUpdateWidget(OrderCartPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Update the controller text if the widget's customerName changes
    if (widget.customerName != oldWidget.customerName && 
        widget.customerName != null && 
        widget.customerName != _customerNameController.text) {
      _customerNameController.text = widget.customerName!;
    }
  }

  Future<void> _loadInitialCustomer() async {
    if (widget.customerName != null) {
      try {
        final customer = await DatabaseService.instance.getCustomerByName(widget.customerName!);
        if (customer != null) {
          setState(() {
            _selectedCustomer = Customer.fromMap(customer);
          });
        }
      } catch (e) {
        print('Error loading initial customer: $e');
      }
    }
  }

  Future<void> _loadCustomers() async {
    setState(() => _isLoadingCustomers = true);
    try {
      final customersData = await DatabaseService.instance.getAllCustomers();
      if (mounted) {
        setState(() {
          _customers = customersData.map((c) => Customer.fromMap(c)).toList();
          _isLoadingCustomers = false;
        });
      }
    } catch (e) {
      print('Error loading customers: $e');
      if (mounted) {
        setState(() => _isLoadingCustomers = false);
      }
    }
  }

  void _onCustomerSearchChanged(String value) {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 500), () async {
      if (value.isEmpty) {
        await _loadCustomers();
      } else {
        setState(() => _isLoadingCustomers = true);
        try {
          final customersData = await DatabaseService.instance.getAllCustomers();
          if (mounted) {
            setState(() {
              _customers = customersData
                  .map((c) => Customer.fromMap(c))
                  .where((c) => c.name.toLowerCase().contains(value.toLowerCase()))
                  .toList();
            });
          }
        } finally {
          if (mounted) {
            setState(() => _isLoadingCustomers = false);
          }
        }
      }
    });
  }

  Future<void> _createNewCustomer(String name) async {
    try {
      final customer = Customer(
        name: name,
        createdAt: DateTime.now(),
      );
      
      final customerId = await DatabaseService.instance.createCustomer(customer);
      setState(() {
        _selectedCustomer = customer.copyWith(id: customerId);
        _customerNameController.text = name;
      });
      if (widget.onCustomerNameChanged != null) {
        widget.onCustomerNameChanged!(name);
      }
    } catch (e) {
      if (mounted) {
        if (e.toString().contains('UNIQUE constraint failed')) {
          showDialog(
            context: context,
            builder: (context) => AlertDialog(
              title: const Text('Customer Already Exists'),
              content: Text('A customer with the name "$name" already exists. Please select from the existing customers or use a different name.'),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('OK'),
                ),
              ],
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error creating customer: $e')),
          );
        }
      }
    }
  }

  Future<void> _placeOrder() async {
    int retryCount = 0;
    const maxRetries = 3;
    
    while (retryCount <= maxRetries) {
      try {
        // Get the customer name from the controller
        final customerName = _customerNameController.text.trim();
        print('Customer name from controller: "$customerName"');
        
        if (customerName.isEmpty) {
          throw Exception('Customer name is required');
        }
        
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
                Text('Processing order...'),
              ],
            ),
          ),
        );
        
        // If onPlaceOrder callback is provided, let the parent handle order creation
        if (widget.onPlaceOrder != null) {
          // Close loading dialog
          if (mounted) {
            Navigator.of(context, rootNavigator: true).pop();
          }
          
          // Call the onPlaceOrder callback
          widget.onPlaceOrder!();
          
          // Success - break out of retry loop
          break;
        }
        
        // Otherwise, create the order here
        // First check if customer exists and get their ID
        int? customerId;
        final customerData = await DatabaseService.instance.getCustomerByName(customerName);
        if (customerData != null) {
          customerId = customerData['id'] as int;
        } else {
          // Create a new customer if they don't exist
          final customer = Customer(
            name: customerName,
            createdAt: DateTime.now(),
          );
          customerId = await DatabaseService.instance.createCustomer(customer);
        }

        // Generate a more consistent order number with date prefix for better tracking
        // Add milliseconds for even more uniqueness
        final now = DateTime.now();
        final datePrefix = '${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}';
        final timeComponent = '${now.hour.toString().padLeft(2, '0')}${now.minute.toString().padLeft(2, '0')}${now.second.toString().padLeft(2, '0')}${(now.millisecond ~/ 10).toString().padLeft(2, '0')}';
        final orderNumber = 'ORD-$datePrefix-$timeComponent';
        final currentUser = AuthService.instance.currentUser;
        if (currentUser == null) {
          throw Exception('User not logged in');
        }
        
        // Create order with customer information
        final order = Order(
          orderNumber: orderNumber,
          customerId: customerId,
          customerName: customerName,
          totalAmount: _total,
          orderStatus: 'PENDING',
          paymentStatus: 'PENDING',
          createdBy: currentUser.id!,
          createdAt: now, // Use the same timestamp throughout
          orderDate: now,
          items: widget.initialItems.map((item) => _createOrderItem(item)).toList(),
        );

        // Let DatabaseService handle the transaction
        await DatabaseService.instance.createOrder(order);
        
        // Close loading dialog
        if (mounted) {
          Navigator.of(context, rootNavigator: true).pop();
        }
        
        // Success - break out of retry loop
        break;
      } catch (e) {
        print('Error placing order (attempt ${retryCount + 1}): $e');
        
        // If we've reached max retries, show error and break
        if (retryCount >= maxRetries) {
          // Close loading dialog
          if (mounted) {
            Navigator.of(context, rootNavigator: true).pop();
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Error placing order: ${e.toString()}'),
                backgroundColor: Colors.red,
              ),
            );
          }
          break;
        }
        
        // If it's a database lock error, retry with exponential backoff
        if (e.toString().contains('locked') || e.toString().contains('busy')) {
          // Exponential backoff for retries
          final delay = 500 * (1 << retryCount);
          print('Retrying order placement in $delay ms...');
          await Future.delayed(Duration(milliseconds: delay));
          retryCount++;
        } else {
          // For other errors, show message and break
          if (mounted) {
            Navigator.of(context, rootNavigator: true).pop();
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Error placing order: ${e.toString()}'),
                backgroundColor: Colors.red,
              ),
            );
          }
          break;
        }
      }
    }
  }

  OrderItem _createOrderItem(CartItem item) {
    return OrderItem(
      orderId: 0,  // Will be set when order is created
      productId: item.productId,
      quantity: item.quantity,
      unitPrice: item.unitPrice,
      sellingPrice: item.sellingPrice,
      totalAmount: item.total,
      productName: item.product.productName,
      isSubUnit: item.isSubUnit,
      subUnitName: item.subUnitName,
      subUnitQuantity: item.subUnitQuantity?.toDouble(),
    );
  }

  double get _total => widget.initialItems.fold(
    0, (sum, item) => sum + item.total
  );

  void _removeItem(int index) {
    if (widget.onRemoveItem != null) {
      widget.onRemoveItem!(index);
      setState(() {
        // Remove the item from the list
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    // Ensure customer name is synchronized with parent widget
    if (widget.customerName != null && widget.customerName!.isNotEmpty && 
        widget.customerName != _customerNameController.text) {
      _customerNameController.text = widget.customerName!;
    }
    
    return Material(
      type: MaterialType.transparency,
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
        padding: const EdgeInsets.all(defaultPadding),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.isEditing ? 'Edit Order' : 'Current Order',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                color: Colors.white,
              ),
            ),
            const SizedBox(height: defaultPadding),
            // Customer Autocomplete
            Autocomplete<Customer>(
              initialValue: TextEditingValue(text: _customerNameController.text),
              optionsBuilder: (TextEditingValue textEditingValue) {
                if (textEditingValue.text.isEmpty) {
                  return _customers;
                }
                return _customers.where((customer) =>
                    customer.name.toLowerCase().contains(textEditingValue.text.toLowerCase()));
              },
              onSelected: (Customer customer) {
                setState(() {
                  _selectedCustomer = customer;
                  _customerNameController.text = customer.name;
                });
                if (widget.onCustomerNameChanged != null) {
                  widget.onCustomerNameChanged!(customer.name);
                }
              },
              displayStringForOption: (Customer customer) => customer.name,
              fieldViewBuilder: (context, controller, focusNode, onFieldSubmitted) {
                // Sync the controller with our _customerNameController
                if (controller.text != _customerNameController.text) {
                  controller.text = _customerNameController.text;
                }
                
                return TextField(
                  controller: controller,
                  focusNode: focusNode,
                  decoration: InputDecoration(
                    labelText: 'Customer Name',
                    border: const OutlineInputBorder(),
                    filled: true,
                    fillColor: Colors.white,
                    suffixIcon: _isLoadingCustomers
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : IconButton(
                            icon: const Icon(Icons.add),
                            onPressed: () {
                              if (controller.text.isNotEmpty) {
                                _createNewCustomer(controller.text);
                              }
                            },
                          ),
                  ),
                  onChanged: (value) {
                    _customerNameController.text = value;
                    _onCustomerSearchChanged(value);
                    if (widget.onCustomerNameChanged != null) {
                      widget.onCustomerNameChanged!(value);
                    }
                  },
                );
              },
              optionsViewBuilder: (context, onSelected, options) {
                return Align(
                  alignment: Alignment.topLeft,
                  child: Material(
                    elevation: 4,
                    child: SizedBox(
                      width: 300,
                      child: ListView.builder(
                        padding: EdgeInsets.zero,
                        shrinkWrap: true,
                        itemCount: options.length,
                        itemBuilder: (context, index) {
                          final customer = options.elementAt(index);
                          return ListTile(
                            title: Text(customer.name),
                            subtitle: customer.phone != null ? Text(customer.phone!) : null,
                            onTap: () => onSelected(customer),
                          );
                        },
                      ),
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: defaultPadding),
            Text(
              'Order #${widget.orderId ?? DateTime.now().millisecondsSinceEpoch}',
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            Text(
              'Created by: ${AuthService.instance.currentUser?.username ?? "Unknown"}',
              style: const TextStyle(color: Colors.white70),
            ),
            const SizedBox(height: defaultPadding),
            Expanded(
              child: Card(
                child: ListView.builder(
                  itemCount: widget.initialItems.length,
                  itemBuilder: (context, index) {
                    final item = widget.initialItems[index];
                    return ListTile(
                      title: Text(item.product.productName),
                      subtitle: Text(
                        'Quantity: ${item.quantity}${item.isSubUnit ? ' ${item.subUnitName ?? 'pieces'}' : ''}',
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'KSH ${item.total.toStringAsFixed(2)}',
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          if (widget.onRemoveItem != null)
                            IconButton(
                              icon: const Icon(Icons.delete),
                              onPressed: () => widget.onRemoveItem!(index),
                            ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(defaultPadding),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Total:',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          'KSH ${_total.toStringAsFixed(2)}',
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: defaultPadding),
                    Row(
                      children: [
                        if (widget.isEditing)
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: _placeOrder,
                              icon: const Icon(Icons.save),
                              label: const Text('Save Changes'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.blue,
                              ),
                            ),
                          )
                        else ...[
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: widget.initialItems.isEmpty ? null : _placeOrder,
                              icon: const Icon(Icons.receipt_long),
                              label: const Text('Place Order'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.green,
                              ),
                            ),
                          ),
                          const SizedBox(width: defaultPadding),
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: widget.initialItems.isEmpty ? null : widget.onClearCart,
                              icon: const Icon(Icons.clear_all),
                              label: const Text('Clear'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.red,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _customerNameController.dispose();
    _debounceTimer?.cancel();
    super.dispose();
  }
} 