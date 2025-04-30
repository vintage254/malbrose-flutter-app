import 'package:flutter/material.dart';
import 'dart:async';
import 'package:my_flutter_app/models/cart_item_model.dart';
import 'package:my_flutter_app/const/constant.dart';
import 'package:my_flutter_app/services/auth_service.dart';
import 'package:my_flutter_app/services/database.dart';
import 'package:my_flutter_app/models/customer_model.dart';
import 'package:my_flutter_app/models/order_model.dart';
import 'package:my_flutter_app/utils/receipt_number_generator.dart';
import 'package:my_flutter_app/widgets/order_receipt_dialog.dart';
import 'package:my_flutter_app/widgets/credit_orders_dialog.dart';
import 'package:my_flutter_app/screens/sales_screen.dart';
import 'package:my_flutter_app/screens/held_orders_screen.dart';
import 'package:my_flutter_app/services/order_service.dart';

class OrderCartPanel extends StatefulWidget {
  final List<CartItem> initialItems;
  final String? customerName;
  final int? orderId;
  final bool isEditing;
  final Function(int)? onRemoveItem;
  final VoidCallback? onPlaceOrder;
  final VoidCallback? onClearCart;
  final Function(String)? onCustomerNameChanged;
  final String orderButtonText;
  final Function()? onHoldOrderPressed;
  final Order? order;
  final bool preserveOrderNumber;
  final bool preventDuplicateCreation;

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
    this.orderButtonText = 'Place Order',
    this.onHoldOrderPressed,
    this.order,
    this.preserveOrderNumber = false,
    this.preventDuplicateCreation = false,
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
  int customerId = 0; // Default to 0
  final OrderService _orderService = OrderService.instance;

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
            // Set customerId from the loaded customer, ensuring proper type conversion
            if (customer['id'] is int) {
              customerId = customer['id'] as int;
            } else if (customer['id'] != null) {
              // Handle any other potential types
              customerId = int.tryParse(customer['id'].toString()) ?? 0;
            }
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
      
      final customerMap = {
        'name': name,
        'created_at': DateTime.now().toIso8601String(),
      };
      
      final customerResult = await DatabaseService.instance.createCustomer(customerMap);
      setState(() {
        _selectedCustomer = customer.copyWith(id: customerResult != null ? customerResult['id'] as int : null);
        _customerNameController.text = name;
        // Set customerId from the newly created customer
        if (customerResult != null) {
          customerId = customerResult['id'] is String ? int.parse(customerResult['id'] as String) : customerResult['id'] as int;
        }
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

  Future<void> _placeOrder(BuildContext context) async {
    // Detailed diagnostic logging for debugging order flow issues
    debugPrint('--- _placeOrder START ---');
    debugPrint('widget.isEditing = ${widget.isEditing}');
    debugPrint('widget.preventDuplicateCreation = ${widget.preventDuplicateCreation}');
    debugPrint('widget.preserveOrderNumber = ${widget.preserveOrderNumber}');
    debugPrint('widget.order ID = ${widget.order?.id}'); 
    debugPrint('widget.order Number = ${widget.order?.orderNumber}');
    debugPrint('widget.order Status = ${widget.order?.orderStatus}');
    debugPrint('widget.orderId prop = ${widget.orderId}'); 
    
    if (widget.initialItems.isEmpty || _customerNameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please add items and enter a customer name before placing an order'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    try {
      final customerName = _customerNameController.text.trim();
      final now = DateTime.now();
      final datePrefix = '${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}';
      final timeComponent = '${now.hour.toString().padLeft(2, '0')}${now.minute.toString().padLeft(2, '0')}${now.second.toString().padLeft(2, '0')}${(now.millisecond ~/ 10).toString().padLeft(2, '0')}';
      
      // Determine if this is a held order we're editing
      final bool isEditingHeldOrder = widget.isEditing && 
                                     widget.order != null && 
                                     (widget.order!.orderStatus == 'ON_HOLD' || 
                                      widget.order!.orderNumber.startsWith('HLD-'));
                                      
      debugPrint('OrderCartPanel: isEditingHeldOrder = $isEditingHeldOrder');
      
      // Determine order number with enhanced logic to prevent duplicates
      String orderNumber;
      
      // Case 1: Editing an existing order OR explicitly preserving number
      if ((widget.isEditing && widget.order != null) || 
          (widget.preserveOrderNumber && widget.order != null)) {
        // Always use the existing order number when editing or preserving
        orderNumber = widget.order!.orderNumber;
        debugPrint('OrderCartPanel: Using existing order number: $orderNumber');
      } 
      // Case 2: Creating a new order
      else {
        // If not editing, new orders go to pending status with ORD- prefix
        orderNumber = 'ORD-$datePrefix-$timeComponent';
        debugPrint('OrderCartPanel: Generated new order number: $orderNumber');
      }
      
      // Get current user with null safety
      final currentUser = AuthService.instance.currentUser;
      if (currentUser == null) throw Exception('User not logged in');
      
      // Extract user ID with proper null safety
      final int createdBy = currentUser.id != null 
          ? (currentUser.id is String 
              ? int.tryParse(currentUser.id as String) ?? 0 
              : (currentUser.id as int? ?? 0))
          : 0;
      
      // Create order map with customer information
      final orderMap = {
        'order_number': orderNumber,
        'customer_id': customerId > 0 ? customerId : null,
        'customer_name': customerName,
        'total_amount': widget.initialItems.fold<double>(0, (sum, item) => sum + item.total),
        // Define the order status based on the operation:
        // - When editing a held order, maintain ON_HOLD status
        // - When creating a new order, use PENDING status
        'order_status': isEditingHeldOrder ? 'ON_HOLD' : 'PENDING',
        'status': isEditingHeldOrder ? 'ON_HOLD' : 'PENDING', // Also set status field for compatibility
        'payment_status': 'PENDING',
        'created_by': createdBy,
        'created_at': now.toIso8601String(),
        'order_date': now.toIso8601String(),
        'updated_at': now.toIso8601String(),
      };
      
      // Enhanced ID handling with multiple safeguards
      
      // Case 1: Directly provided ID via orderId property
      if (widget.orderId != null) {
        orderMap['id'] = widget.orderId;
        debugPrint('OrderCartPanel: Using orderId: ${widget.orderId}');
      }
      // Case 2: ID available from the order object
      else if (widget.order?.id != null) {
        orderMap['id'] = widget.order!.id;
        debugPrint('OrderCartPanel: Using order.id: ${widget.order!.id}');
      }

      // Critical: Flag the order for update instead of insert if any of our conditions are met
      final bool shouldForceUpdate = (widget.isEditing || widget.preventDuplicateCreation) && 
                                    (widget.orderId != null || widget.order?.id != null);
      
      if (shouldForceUpdate) {
        debugPrint('OrderCartPanel: Flagged order for UPDATE instead of INSERT');
      }
      
      // Generate orderItems list from cartItems
      final orderItems = widget.initialItems.map(_createOrderItem).toList();
      
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
                Text('Processing order...'),
              ],
            ),
          ),
        );

        // Use the appropriate service method based on whether this is a held order
        final success = isEditingHeldOrder 
            ? await _orderService.createHeldOrder(orderMap, orderItems)
            : await _orderService.createOrder(orderMap, orderItems);
        
        // Close loading dialog
        Navigator.of(context, rootNavigator: true).pop();
        
        if (success) {
          // Clear the cart after placing the order
          if (widget.onClearCart != null) {
            widget.onClearCart!();
          }
          
          // Show success message
          final String statusMsg = isEditingHeldOrder ? 'held' : 'pending';
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(widget.isEditing 
                  ? 'Order #$orderNumber updated successfully' 
                  : 'Order #$orderNumber created as $statusMsg'),
              backgroundColor: Colors.green,
            ),
          );
          
          // Navigate to the appropriate screen based on order status
          if (isEditingHeldOrder) {
            debugPrint('OrderCartPanel: Navigating back to held orders screen');
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                builder: (context) => const HeldOrdersScreen(),
              ),
            );
          }
        } else {
          throw Exception('Failed to ${widget.isEditing ? 'update' : 'create'} order');
        }
      } catch (e) {
        // Close loading dialog if it's open
        Navigator.of(context, rootNavigator: true).pop();
        
        // Show error message
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error ${widget.isEditing ? 'updating' : 'creating'} order: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      print('Error generating order number: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error generating order number: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
  
  Map<String, dynamic> _createOrderItem(CartItem item) {
    return {
      'product_id': item.product.id ?? 0,
      'product_name': item.product.productName,
      'quantity': item.quantity,
      'unit_price': item.product.buyingPrice,
      'selling_price': item.product.sellingPrice,
      'total_amount': item.total,
      'is_sub_unit': item.isSubUnit ? 1 : 0,
      'sub_unit_name': item.subUnitName,
      'sub_unit_quantity': item.subUnitQuantity != null ? item.subUnitQuantity!.toDouble() : null,
      'adjusted_price': item.adjustedPrice,
    };
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
    
    // Debug logging for held order detection
    if (widget.isEditing && widget.order != null) {
      print('DEBUG ORDER PANEL: Editing order #${widget.order!.orderNumber} | Status: ${widget.order!.orderStatus}');
      print('DEBUG ORDER PANEL: isHeld by status: ${widget.order!.orderStatus == 'ON_HOLD'}');
      print('DEBUG ORDER PANEL: isHeld by number prefix: ${widget.order!.orderNumber.startsWith('HLD-')}');
      print('DEBUG ORDER PANEL: preserveOrderNumber: ${widget.preserveOrderNumber}, preventDuplicateCreation: ${widget.preventDuplicateCreation}');
      
      // IMPORTANT: We consider it a held order being edited if:
      // 1. It's currently in ON_HOLD status, OR
      // 2. Its order number starts with HLD-, OR
      // 3. Both preserveOrderNumber AND preventDuplicateCreation flags are true (indicates restored held order)
      // 4. If the order number was previously a held order (check for ORD- with the same number pattern as HLD-)
      final bool wasHeldOrder = widget.order!.orderNumber.startsWith('ORD-') && 
                              widget.preserveOrderNumber && 
                              widget.preventDuplicateCreation;
      
      final isHeldOrder = ((widget.order!.orderStatus == 'ON_HOLD' || 
                         widget.order!.orderNumber.startsWith('HLD-')) || 
                         wasHeldOrder);
      
      print('DEBUG ORDER PANEL: wasHeldOrder: $wasHeldOrder');
      print('DEBUG ORDER PANEL: Final isHeldOrder evaluation: $isHeldOrder');
    }
    
    // NEW: Determine if this is a restored held order being edited
    final bool isRestoredHeldOrder = widget.isEditing && 
                                 widget.order != null &&
                                 widget.order!.orderStatus == 'PENDING' &&
                                 widget.order!.orderNumber.startsWith('ORD-') &&
                                 widget.preserveOrderNumber && 
                                 widget.preventDuplicateCreation;
    
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
                  // Update customerId when customer is selected
                  if (customer.id != null) {
                    customerId = customer.id!;
                  }
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
                
                return Row(
                  children: [
                    Expanded(
                      child: TextField(
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
                      ),
                    ),
                    if (_customerNameController.text.isNotEmpty) ...[
                      const SizedBox(width: 8),
                      ElevatedButton.icon(
                        onPressed: () {
                          showDialog(
                            context: context,
                            builder: (context) => CreditOrdersDialog(
                              customerName: _customerNameController.text,
                            ),
                          );
                        },
                        icon: const Icon(Icons.credit_card),
                        label: const Text("View & Pay Credits"),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green.shade700,
                          foregroundColor: Colors.white,
                        ),
                      ),
                    ],
                  ],
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
                            subtitle: null,
                            onTap: () {
                              onSelected(customer);
                            },
                          );
                        },
                      ),
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: defaultPadding),
            // Convert orderId to string for display purposes
            Text(
              'Order #${widget.orderId != null ? widget.orderId.toString() : DateTime.now().millisecondsSinceEpoch.toString()}',
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
                      onTap: () => _showEditItemDialog(item, index),
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
                    // FIXED: Modified row of buttons for held orders to always include all three buttons
                    Row(
                      children: [
                        // HELD ORDER WORKFLOW: Show these buttons when editing a held order
                        if (widget.isEditing && widget.order != null && 
                            ((widget.order!.orderStatus == 'ON_HOLD' || 
                              widget.order!.orderNumber.startsWith('HLD-')) || 
                             (widget.preserveOrderNumber && widget.preventDuplicateCreation))) ...[
                          // Save button - preserves held status
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: widget.initialItems.isEmpty ? null : () => _saveHeldOrder(context),
                              icon: const Icon(Icons.save),
                              label: const Text('Save Changes'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.blue,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          // Place Order button - converts to pending
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: widget.initialItems.isEmpty ? null : () => _convertHeldToPendingOrder(context),
                              icon: const Icon(Icons.receipt_long),
                              label: const Text('Place Order'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.green,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          // Print button - always available
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: widget.initialItems.isEmpty ? null : () => _printCurrentOrder(context),
                              icon: const Icon(Icons.print),
                              label: const Text('Print'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.orange,
                              ),
                            ),
                          ),
                        ] else if (widget.isEditing) ...[
                          // Regular editing (not held orders) - show just Save Changes
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: () => _placeOrder(context),
                              icon: const Icon(Icons.save),
                              label: const Text('Save Changes'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.blue,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          // Print button
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: widget.initialItems.isEmpty ? null : () => _printCurrentOrder(context),
                              icon: const Icon(Icons.print),
                              label: const Text('Print'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.orange,
                              ),
                            ),
                          ),
                        ] else ...[
                          // Normal mode - show Place Order button
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: widget.initialItems.isEmpty ? null : () => _placeOrder(context),
                              icon: const Icon(Icons.receipt_long),
                              label: Text(widget.orderButtonText),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.green,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          if (widget.onHoldOrderPressed != null)
                            Expanded(
                              child: ElevatedButton.icon(
                                onPressed: widget.initialItems.isEmpty ? null : () => _holdOrder(context),
                                icon: const Icon(Icons.pause_circle_outline),
                                label: const Text('Hold'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.orange,
                                ),
                              ),
                            ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: ElevatedButton.icon(
                              onPressed: widget.initialItems.isNotEmpty ? () => _printCurrentOrder(context) : null,
                            icon: const Icon(Icons.print),
                              label: const Text('Print'),
                            style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.amber,
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

  void _showEditItemDialog(CartItem item, int index) {
    final quantityController = TextEditingController(text: item.quantity.toString());
    final priceController = TextEditingController(
      text: (item.adjustedPrice ?? (item.isSubUnit ? item.product.subUnitPrice : item.product.sellingPrice)).toString()
    );
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Edit ${item.product.productName}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: quantityController,
              decoration: InputDecoration(
                labelText: 'Quantity',
                suffix: Text(item.isSubUnit ? item.subUnitName ?? 'pieces' : 'units'),
              ),
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 8),
            TextField(
              controller: priceController,
              decoration: const InputDecoration(
                labelText: 'Price per unit',
                prefixText: 'KSH ',
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
              final price = double.tryParse(priceController.text);
              
              if (quantity != null && quantity > 0 && price != null && price > 0) {
                setState(() {
                  // Update the item
                  final updatedItem = CartItem(
                    product: item.product,
                    quantity: quantity,
                    isSubUnit: item.isSubUnit,
                    subUnitName: item.subUnitName,
                    subUnitQuantity: item.subUnitQuantity,
                    adjustedPrice: price,
                    total: quantity * price,
                  );
                  
                  // Replace the item in the list
                  widget.initialItems[index] = updatedItem;
                });
                Navigator.pop(context);
              }
            },
            child: const Text('Update'),
          ),
        ],
      ),
    );
  }
  
  Future<void> _holdOrder(BuildContext context) async {
    if (widget.initialItems.isEmpty || _customerNameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please add items and enter a customer name before holding an order'),
          backgroundColor: Colors.red,
        ),
      );
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
      
      // Check if we're editing an existing order
      final bool isEditingExistingOrder = widget.isEditing && 
                                        (widget.orderId != null || widget.order?.id != null);
                                        
      debugPrint('OrderCartPanel: isEditingExistingOrder in _holdOrder = $isEditingExistingOrder');
      
      String orderNumber;
      
      // If editing an existing order, preserve its number or convert to HLD- prefix
      if (isEditingExistingOrder && widget.order != null) {
        if (widget.order!.orderNumber.startsWith('HLD-')) {
          // Already a held order number, keep it
          orderNumber = widget.order!.orderNumber;
          debugPrint('OrderCartPanel: Using existing held order number: $orderNumber');
        } else {
          // Convert existing order number to held format
          orderNumber = 'HLD-' + widget.order!.orderNumber.replaceFirst('ORD-', '');
          debugPrint('OrderCartPanel: Converting to held order number: $orderNumber');
        }
      } else {
        // Generate new held order number
        final datePrefix = '${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}';
        final timeComponent = '${now.hour.toString().padLeft(2, '0')}${now.minute.toString().padLeft(2, '0')}${now.second.toString().padLeft(2, '0')}${(now.millisecond ~/ 10).toString().padLeft(2, '0')}';
        orderNumber = 'HLD-$datePrefix-$timeComponent';
        debugPrint('OrderCartPanel: Generated new held order number: $orderNumber');
      }
      
      // Get current user with null safety
      final currentUser = AuthService.instance.currentUser;
      if (currentUser == null) throw Exception('User not logged in');
      
      // Extract user ID with proper null safety
      final int createdBy = currentUser.id != null 
          ? (currentUser.id is String 
              ? int.tryParse(currentUser.id as String) ?? 0 
              : (currentUser.id as int? ?? 0))
          : 0;
      
      // Create order map with customer information
      final orderMap = {
        'order_number': orderNumber,
        'customer_id': customerId > 0 ? customerId : null,
        'customer_name': customerName,
        'total_amount': widget.initialItems.fold<double>(0, (sum, item) => sum + item.total),
        'order_status': 'ON_HOLD',
        'payment_status': 'PENDING',
        'created_by': createdBy,
        'created_at': now.toIso8601String(),
        'order_date': now.toIso8601String(),
      };
      
      // If editing an existing order, include its ID to update instead of create
      if (isEditingExistingOrder) {
        if (widget.orderId != null) {
          orderMap['id'] = widget.orderId;
          debugPrint('OrderCartPanel: Using orderId for held order: ${widget.orderId}');
        } else if (widget.order?.id != null) {
          orderMap['id'] = widget.order!.id;
          debugPrint('OrderCartPanel: Using order.id for held order: ${widget.order!.id}');
        }
      }
      
      // Convert cart items to order items
      final orderItems = widget.initialItems.map((item) => {
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

      // Create the order using OrderService
      final success = await _orderService.createHeldOrder(orderMap, orderItems);
      
      // Close loading dialog
      Navigator.of(context, rootNavigator: true).pop();
      
      if (!success) {
        throw Exception('Failed to place order on hold');
      }
      
      // Show success message
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(isEditingExistingOrder 
              ? 'Order #$orderNumber updated and placed on hold' 
              : 'Order #$orderNumber placed on hold successfully'),
          backgroundColor: Colors.green,
        ),
      );
      
      // Clear the cart
      if (widget.onClearCart != null) {
        widget.onClearCart!();
      }
      
      // Navigate to held orders screen
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => const HeldOrdersScreen(),
        ),
      );
      
    } catch (e) {
      // Close loading dialog
      Navigator.of(context, rootNavigator: true).pop();
      
      // Show error message
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error holding order: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _printCurrentOrder(BuildContext context) {
    if (widget.initialItems.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Cannot print receipt for an empty order'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }
    
    print('OrderCartPanel - Printing receipt for ${widget.initialItems.length} items');
    for (var item in widget.initialItems) {
      print('  * ${item.product.productName}: ${item.quantity} x ${item.effectivePrice} = ${item.total}');
    }
    
    // Show receipt dialog
    showDialog(
      context: context,
      builder: (context) => OrderReceiptDialog(
        items: widget.initialItems,
        customerName: _customerNameController.text.trim(),
        paymentMethod: 'Preview', // This is just a preview
      ),
    );
  }

  // Fixed _saveHeldOrder implementation to ensure it correctly preserves status
  Future<void> _saveHeldOrder(BuildContext context) async {
    if (widget.initialItems.isEmpty || _customerNameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please add items and enter a customer name before saving the order'),
          backgroundColor: Colors.red,
        ),
      );
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
              Text('Saving held order...'),
            ],
          ),
        ),
      );

      final customerName = _customerNameController.text.trim();
      final now = DateTime.now();

      // Get the order ID - this is crucial for updating
      final int orderId = widget.orderId ?? widget.order?.id ?? 0;
      
      if (orderId <= 0) {
        throw Exception('Cannot update order: Missing valid order ID');
      }

      // Get the existing order number
      String orderNumber = widget.order?.orderNumber ?? '';
      if (orderNumber.isEmpty) {
        throw Exception('Cannot update order: Missing order number');
      }
      
      // If the order number starts with ORD-, change it to HLD-
      // This ensures that when saving changes, it always becomes a held order
      if (orderNumber.startsWith('ORD-')) {
        orderNumber = 'HLD-' + orderNumber.substring(4);
        debugPrint('OrderCartPanel: Converting order number to held format: $orderNumber');
      }
      
      debugPrint('OrderCartPanel: Saving order #$orderNumber with ID $orderId');

      // Get current user with null safety
      final currentUser = AuthService.instance.currentUser;
      if (currentUser == null) throw Exception('User not logged in');
      
      // Extract user ID with proper null safety
      final int createdBy = currentUser.id != null 
          ? (currentUser.id is String 
              ? int.tryParse(currentUser.id as String) ?? 0 
              : (currentUser.id as int? ?? 0))
          : 0;

      // Create order map with customer information
      // ALWAYS set status to ON_HOLD when saving changes
      final orderMap = {
        'id': orderId,
        'order_number': orderNumber,
        'customer_id': customerId > 0 ? customerId : null,
        'customer_name': customerName,
        'total_amount': widget.initialItems.fold<double>(0, (sum, item) => sum + item.total),
        'order_status': 'ON_HOLD',  // Always ON_HOLD when using Save Changes
        'status': 'ON_HOLD',        // Also set status field
        'payment_status': 'PENDING',
        'updated_at': now.toIso8601String(),
        'created_by': createdBy, // Make sure created_by is included
      };

      // Convert cart items to order items
      final orderItems = widget.initialItems.map(_createOrderItem).toList();

      // Update the order using DatabaseService
      final success = await DatabaseService.instance.updateOrder(orderId, orderMap, orderItems);

      // Close loading dialog
      Navigator.of(context, rootNavigator: true).pop();

      if (success) {
        // Show success message
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Order saved as held order #$orderNumber'),
            backgroundColor: Colors.green,
          ),
        );

        // Always navigate to held orders screen since we're making it a held order
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => const HeldOrdersScreen(),
          ),
        );
      } else {
        throw Exception('Failed to update order');
      }
    } catch (e) {
      // Close loading dialog
        Navigator.of(context, rootNavigator: true).pop();

      // Show error message
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error saving held order: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // Fixed convert method implementation to ensure it reliably changes status to PENDING
  Future<void> _convertHeldToPendingOrder(BuildContext context) async {
    if (widget.initialItems.isEmpty || _customerNameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please add items and enter a customer name before processing this order'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    try {
      // Show confirmation dialog
      final bool shouldProceed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Convert to Pending Order?'),
          content: const Text(
            'This will convert the held order to a pending order and move it to the regular order queue. Proceed?'
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
              child: const Text('Proceed'),
            ),
          ],
        ),
      ) ?? false;

      if (!shouldProceed) return;

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
              Text('Converting order...'),
            ],
          ),
        ),
      );
      
      final customerName = _customerNameController.text.trim();
      final now = DateTime.now();
      
      // Get the order ID - this is crucial for updating
      final int orderId = widget.orderId ?? widget.order?.id ?? 0;
      
      if (orderId <= 0) {
        throw Exception('Cannot convert order: Missing valid order ID');
      }
      
      // Generate a new order number by replacing HLD- with ORD-
      String orderNumber = widget.order?.orderNumber ?? '';
      if (orderNumber.isEmpty) {
        throw Exception('Cannot convert order: Missing order number');
      }
      
      if (orderNumber.startsWith('HLD-')) {
        orderNumber = 'ORD-' + orderNumber.substring(4);
      }
      
      // Get current user with null safety
      final currentUser = AuthService.instance.currentUser;
      if (currentUser == null) throw Exception('User not logged in');
      
      // Extract user ID with proper null safety
      final int createdBy = currentUser.id != null 
          ? (currentUser.id is String 
              ? int.tryParse(currentUser.id as String) ?? 0 
              : (currentUser.id as int? ?? 0))
          : 0;
      
      // Create order map with customer information
      final orderMap = {
        'id': orderId,
        'order_number': orderNumber,
        'customer_id': customerId > 0 ? customerId : null,
        'customer_name': customerName,
        'total_amount': widget.initialItems.fold<double>(0, (sum, item) => sum + item.total),
        'order_status': 'PENDING', // CRITICAL: Change status to PENDING
        'status': 'PENDING',       // Also set status field for backward compatibility
        'payment_status': 'PENDING',
        'created_by': createdBy,
        'created_at': widget.order?.createdAt?.toIso8601String() ?? now.toIso8601String(),
        'order_date': now.toIso8601String(),
        'updated_at': now.toIso8601String(),
      };
      
      // Generate orderItems list from cartItems
      final orderItems = widget.initialItems.map(_createOrderItem).toList();

      // Update the order by converting it to a pending order
      final success = await DatabaseService.instance.updateOrder(orderId, orderMap, orderItems);
      
      // Close loading dialog
      Navigator.of(context, rootNavigator: true).pop();
      
      if (success) {
        // Show success message
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Order #$orderNumber converted to pending status'),
            backgroundColor: Colors.green,
          ),
        );
        
        // Navigate to sales screen (where pending orders are shown)
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => const SalesScreen(),
          ),
        );
      } else {
        throw Exception('Failed to convert order');
      }
    } catch (e) {
      // Close loading dialog if it's open
      if (Navigator.of(context, rootNavigator: true).canPop()) {
      Navigator.of(context, rootNavigator: true).pop();
      }
      
      // Show error message
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error converting order: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
}