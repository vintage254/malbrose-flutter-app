import 'package:flutter/material.dart';
import 'package:my_flutter_app/const/constant.dart';
import 'package:my_flutter_app/models/order_model.dart';
import 'package:my_flutter_app/services/database.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:intl/intl.dart';
import 'package:my_flutter_app/screens/order_screen.dart';
import 'package:my_flutter_app/services/printer_service.dart';
import 'package:my_flutter_app/models/customer_model.dart';
import 'dart:async';
import 'package:my_flutter_app/utils/ui_helpers.dart';
import 'package:my_flutter_app/services/auth_service.dart';
import 'package:my_flutter_app/utils/receipt_number_generator.dart';
import 'package:my_flutter_app/services/config_service.dart';
import 'dart:io';
import 'package:pdf/pdf.dart';

class ReceiptPanel extends StatefulWidget {
  final Order order;
  final Function(Order) onProcessSale;

  const ReceiptPanel({
    super.key,
    required this.order,
    required this.onProcessSale,
  });

  @override
  State<ReceiptPanel> createState() => _ReceiptPanelState();
}

class _ReceiptPanelState extends State<ReceiptPanel> {
  List<Map<String, dynamic>> _orderItems = [];
  bool _isLoading = true;
  String _selectedPaymentMethod = 'Cash';
  final _creditDetailsController = TextEditingController();
  final _creditCustomerNameController = TextEditingController();
  Customer? _selectedCustomer;
  // Add these controllers and variables for split payment support
  final _cashAmountController = TextEditingController();
  final _mobileAmountController = TextEditingController();
  final _bankAmountController = TextEditingController();
  bool _showSplitPayment = false;
  // Add sales receipt number variable
  String? _salesReceiptNumber;
  double _totalPaid = 0.0;

  @override
  void initState() {
    super.initState();
    _loadOrderItems();
  }

  @override
  void didUpdateWidget(ReceiptPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    
    // Check if the order has changed
    if (widget.order.id != oldWidget.order.id || 
        widget.order.orderNumber != oldWidget.order.orderNumber) {
      print('ReceiptPanel: Order changed, reloading order items');
      
      // Clear existing items first
      setState(() {
        _isLoading = true;
        _orderItems = [];
      });
      
      // Load new order items
      _loadOrderItems();
    }
  }

  @override
  void dispose() {
    _creditDetailsController.dispose();
    _creditCustomerNameController.dispose();
    _cashAmountController.dispose();
    _mobileAmountController.dispose();
    _bankAmountController.dispose();
    super.dispose();
  }

  Future<void> _loadOrderItems() async {
    try {
      if (widget.order.id != null) {
        final items = await DatabaseService.instance.getOrderItems(widget.order.id!);
        if (mounted) {
          setState(() {
            _orderItems = items;  // Keep as Map<String, dynamic>
            _isLoading = false;
          });
        }
      }
    } catch (e) {
      print('Error loading order items: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        UIHelpers.showSnackBarWithContext(
          context, 
          'Error loading order items: $e',
          isError: true,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
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
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Order #${widget.order.orderNumber}',
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                if (widget.order.orderStatus == 'PENDING')
                  ElevatedButton.icon(
                    onPressed: () => _navigateToEdit(context),
                    icon: const Icon(Icons.edit),
                    label: const Text('Edit Order'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue,
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: defaultPadding),
          Text('Customer: ${widget.order.customerName ?? "N/A"}',
               style: const TextStyle(color: Colors.white)),
          Text('Date: ${DateFormat('yyyy-MM-dd HH:mm').format(widget.order.orderDate)}',
               style: const TextStyle(color: Colors.white)),
          const SizedBox(height: 8),
          
          Expanded(
            flex: 3,
            child: Card(
              color: Colors.white.withOpacity(0.9),
              elevation: 4,
              child: _isLoading 
                ? const Center(child: CircularProgressIndicator())
                : _orderItems.isEmpty
                  ? const Center(child: Text('No items in this order'))
                  : ListView.builder(
                      itemCount: _orderItems.length,
                      itemBuilder: (context, index) {
                        final item = _orderItems[index];
                        return Card(
                          margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          elevation: 2,
                          child: Padding(
                            padding: const EdgeInsets.all(8.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  item['product_name'] ?? 'Product not found',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text('Quantity: ${item['quantity']}'),
                                    Text('Unit Price: KSH ${(item['unit_price'] as num).toStringAsFixed(2)}'),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.end,
                                  children: [
                                    Text(
                                      'Subtotal: KSH ${(item['total_amount'] as num).toStringAsFixed(2)}',
                                      style: const TextStyle(fontWeight: FontWeight.bold),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ),
          const Divider(),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Total Amount:',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                'KSH ${widget.order.totalAmount.toStringAsFixed(2)}',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const Spacer(),
          if (widget.order.orderStatus == 'PENDING')
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Payment Method:',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  decoration: const InputDecoration(
                    filled: true,
                    fillColor: Colors.white,
                    border: OutlineInputBorder(),
                  ),
                  value: _selectedPaymentMethod,
                  items: const [
                    DropdownMenuItem(value: 'Cash', child: Text('Cash')),
                    DropdownMenuItem(value: 'Mobile Payment', child: Text('Mobile Payment')),
                    DropdownMenuItem(value: 'Bank Transfer', child: Text('Bank Transfer')),
                    DropdownMenuItem(value: 'Credit', child: Text('Credit')),
                  ],
                  onChanged: (value) {
                    setState(() {
                      _selectedPaymentMethod = value!;
                      _showSplitPayment = true;
                    });
                  },
                ),
                const SizedBox(height: 16),
                if (_showSplitPayment) ...[
                  const Text(
                    'Split Payment Details:',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _cashAmountController,
                          decoration: const InputDecoration(
                            labelText: 'Cash Amount',
                            border: OutlineInputBorder(),
                            prefixText: 'KSH ',
                            filled: true,
                            fillColor: Colors.white,
                          ),
                          keyboardType: TextInputType.number,
                          onChanged: (value) {
                            setState(() {
                              _updateTotalPaid();
                            });
                          },
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextFormField(
                          controller: _mobileAmountController,
                          decoration: const InputDecoration(
                            labelText: 'Mobile Payment',
                            border: OutlineInputBorder(),
                            prefixText: 'KSH ',
                            filled: true,
                            fillColor: Colors.white,
                          ),
                          keyboardType: TextInputType.number,
                          onChanged: (value) {
                            setState(() {
                              _updateTotalPaid();
                            });
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _bankAmountController,
                          decoration: const InputDecoration(
                            labelText: 'Bank Transfer',
                            border: OutlineInputBorder(),
                            prefixText: 'KSH ',
                            filled: true,
                            fillColor: Colors.white,
                          ),
                          keyboardType: TextInputType.number,
                          onChanged: (value) {
                            setState(() {
                              _updateTotalPaid();
                            });
                          },
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.white),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Total Paid:',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Text(
                                'KSH ${_totalPaid.toStringAsFixed(2)}',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          Row(
            children: [
              if (widget.order.orderStatus == 'PENDING')
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () {
                      if (_selectedPaymentMethod == 'Credit') {
                        _showCreditDetailsDialog();
                      } else {
                        _completeSale();
                      }
                    },
                    icon: const Icon(Icons.check_circle),
                    label: const Text('Complete Sale'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                    ),
                  ),
                ),
            ],
          ),
          if (widget.order.orderStatus == 'PENDING')
            Padding(
              padding: const EdgeInsets.only(top: 8.0),
              child: ElevatedButton.icon(
                onPressed: () => _confirmDeleteOrder(context),
                icon: const Icon(Icons.delete),
                label: const Text('Delete Order'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                ),
              ),
            ),
        ],
      ),
    );
  }

  void _navigateToEdit(BuildContext context) {
    print('ReceiptPanel - Navigating to edit order #${widget.order.orderNumber}');
    print('ReceiptPanel - Order items count: ${widget.order.items.length}');
    
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (context) => OrderScreen(
          editingOrder: widget.order,
          isEditing: true,
          preserveOrderNumber: true,              // Keep the order number
          preventDuplicateCreation: true,         // Critical flag to prevent duplicates
        ),
      ),
    );
  }

  void _updateTotalPaid() {
    double cashAmount = double.tryParse(_cashAmountController.text) ?? 0;
    double mobileAmount = double.tryParse(_mobileAmountController.text) ?? 0;
    double bankAmount = double.tryParse(_bankAmountController.text) ?? 0;
    
    double totalPaid = cashAmount + mobileAmount + bankAmount;
    
    // Validate that total paid doesn't exceed total amount
    if (totalPaid > widget.order.totalAmount) {
      UIHelpers.showSnackBarWithContext(
        context,
        'Total paid amount cannot exceed total order amount',
        isError: true,
      );
      // Reset the last changed amount
      if (_cashAmountController.text.isNotEmpty) {
        _cashAmountController.text = (widget.order.totalAmount - (mobileAmount + bankAmount)).toStringAsFixed(2);
      } else if (_mobileAmountController.text.isNotEmpty) {
        _mobileAmountController.text = (widget.order.totalAmount - (cashAmount + bankAmount)).toStringAsFixed(2);
      } else if (_bankAmountController.text.isNotEmpty) {
        _bankAmountController.text = (widget.order.totalAmount - (cashAmount + mobileAmount)).toStringAsFixed(2);
      }
      totalPaid = widget.order.totalAmount;
    }
    
    setState(() {
      _totalPaid = totalPaid;
    });
  }

  // New method to directly complete sales from the credit dialog without creating loops
  Future<void> _directlyCompleteSale(String paymentMethod, double remainingCredit) async {
    // Similar to _completeSale but bypasses the credit dialog check
    final validItems = widget.order.items.where((item) => item.productId > 0).toList();
    
    print('ReceiptPanel - Directly completing sale for order ${widget.order.orderNumber}');
    print('ReceiptPanel - Payment method: $paymentMethod, Remaining credit: $remainingCredit');
    print('ReceiptPanel - Valid items: ${validItems.length} of ${widget.order.items.length}');
    
    if (widget.order.items.any((item) => item.productId <= 0)) {
      print('ReceiptPanel - Warning: Order contains invalid products:');
      for (var item in widget.order.items.where((item) => item.productId <= 0)) {
        print('  - ${item.productName} (ID: ${item.productId})');
      }
    }
    
    // Same logic as _completeSale for handling valid items
    if (validItems.isEmpty && widget.order.totalAmount > 0) {
      print('ReceiptPanel - No valid items but order has total amount: ${widget.order.totalAmount}');
      print('ReceiptPanel - Creating a placeholder item for receipt generation');
      
      validItems.add(OrderItem(
        id: 0,
        orderId: widget.order.id ?? 0,
        productId: 1, // Use a valid ID to pass the check
        quantity: 1,
        unitPrice: widget.order.totalAmount / 3, // Use a reasonable unit price
        sellingPrice: widget.order.totalAmount, // Make sure selling price matches total
        totalAmount: widget.order.totalAmount,
        productName: "Order Total",
        isSubUnit: false,
      ));
    }
    
    // Make sure all items have the correct relationship between selling price and total amount
    final correctedItems = validItems.map((item) {
      // Calculate effective price (adjusted or selling price)
      final effectivePrice = item.adjustedPrice ?? item.sellingPrice;
      
      // Check if totalAmount doesn't match quantity * effectivePrice
      if ((item.quantity * effectivePrice - item.totalAmount).abs() > 0.01) {
        print('ReceiptPanel - Correcting item pricing for ${item.productName}: ' +
              'Qty: ${item.quantity}, Original Total: ${item.totalAmount}, ' +
              'Calculated Total: ${item.quantity * effectivePrice}');
              
        // Return a corrected item
        return item.copyWith(
          totalAmount: item.quantity * effectivePrice,
        );
      }
      return item;
    }).toList();
    
    if (correctedItems.isEmpty) {
      UIHelpers.showSnackBarWithContext(
        context, 
        'Cannot complete sale - no valid product items in order',
        isError: true,
      );
      return;
    }
    
    // Generate a distinct sales receipt number if not already generated
    _salesReceiptNumber ??= ReceiptNumberGenerator.generateSalesReceiptNumber();
    
    print('ReceiptPanel - Generated sales receipt number: $_salesReceiptNumber');
    
    // Calculate total paid from split payments
    double cashAmount = double.tryParse(_cashAmountController.text) ?? 0;
    double mobileAmount = double.tryParse(_mobileAmountController.text) ?? 0;
    double bankAmount = double.tryParse(_bankAmountController.text) ?? 0;
    double totalPaid = cashAmount + mobileAmount + bankAmount;
    
    // Calculate the correct total based on the selling prices
    final correctTotal = correctedItems.fold<double>(0, (sum, item) => sum + item.totalAmount);
    
    // Create a copy of the order with the selected payment method and only valid items
    final updatedOrder = Order(
      id: widget.order.id,
      orderNumber: widget.order.orderNumber,
      salesReceiptNumber: _salesReceiptNumber,
      heldReceiptNumber: widget.order.heldReceiptNumber,
      customerId: widget.order.customerId,
      customerName: widget.order.customerName,
      totalAmount: correctTotal, // Use the corrected total amount
      orderStatus: widget.order.orderStatus,
      // Improved payment status logic for credit orders
      paymentStatus: (remainingCredit > 0 || paymentMethod.toLowerCase().contains('credit'))
          ? (paymentMethod == 'Credit' ? 'CREDIT' : 'PARTIAL') // For credit payments: full credit vs. split+credit
          : 'PAID', // For fully paid orders with no credit component
      paymentMethod: paymentMethod,
      createdBy: widget.order.createdBy,
      createdAt: widget.order.createdAt,
      orderDate: widget.order.orderDate,
      items: correctedItems, // Use the corrected items
    );
    
    print('ReceiptPanel - Completing sale with payment method: $paymentMethod');
    print('ReceiptPanel - Order items count: ${correctedItems.length}');
    print('ReceiptPanel - Corrected total amount: $correctTotal');
    
    // For split payments with remaining credit, ensure a credit record is created
    if (remainingCredit > 0 && updatedOrder.customerId != null && updatedOrder.customerName != null) {
      print('ReceiptPanel - Creating credit record for partial payment, remaining credit: $remainingCredit');
      
      // Create credit record for the remaining balance
      try {
        DatabaseService.instance.addCreditorRecordForOrder(
          updatedOrder.customerId!,
          updatedOrder.customerName!,
          updatedOrder.id!,
          updatedOrder.orderNumber,
          remainingCredit,  // Use the remaining credit amount calculated from split payment
          details: 'Credit from split payment transaction',
          orderDetailsSummary: 'Split payment for order #${updatedOrder.orderNumber}'
        );
        print('ReceiptPanel - Credit record created successfully for order ${updatedOrder.orderNumber}');
        
        // Log credit creation in activity log
        final currentUser = AuthService.instance.currentUser;
        if (currentUser != null) {
          await DatabaseService.instance.logActivity(
            currentUser.id!,
            currentUser.username,
            'create_credit',
            'Credit Creation',
            'Created credit of KSH ${remainingCredit.toStringAsFixed(2)} for customer ${updatedOrder.customerName} (Order #${updatedOrder.orderNumber})',
          );
        }
      } catch (e) {
        print('ReceiptPanel - Error creating credit record: $e');
      }
    }
    
    // Call the onProcessSale callback with the updated order
    widget.onProcessSale(updatedOrder);
    
    // Log the sales receipt in the activity log
    _logSalesReceipt(updatedOrder);
  }

  Future<void> _completeSale() async {
    // Check for invalid product IDs first
    final validItems = widget.order.items.where((item) => item.productId > 0).toList();
    
    print('ReceiptPanel - Attempting to complete sale for order ${widget.order.orderNumber}');
    print('ReceiptPanel - Valid items: ${validItems.length} of ${widget.order.items.length}');
    
    if (widget.order.items.any((item) => item.productId <= 0)) {
      print('ReceiptPanel - Warning: Order contains invalid products:');
      for (var item in widget.order.items.where((item) => item.productId <= 0)) {
        print('  - ${item.productName} (ID: ${item.productId})');
      }
    }
    
    // If no valid items but order has a total amount, create a placeholder item
    // This ensures the sale can be completed and a receipt can be generated
    if (validItems.isEmpty && widget.order.totalAmount > 0) {
      print('ReceiptPanel - No valid items but order has total amount: ${widget.order.totalAmount}');
      print('ReceiptPanel - Creating a placeholder item for receipt generation');
      
      validItems.add(OrderItem(
        id: 0,
        orderId: widget.order.id ?? 0,
        productId: 1, // Use a valid ID to pass the check
        quantity: 1,
        unitPrice: widget.order.totalAmount / 3, // Use a reasonable unit price
        sellingPrice: widget.order.totalAmount, // Make sure selling price matches total
        totalAmount: widget.order.totalAmount,
        productName: "Order Total",
        isSubUnit: false,
      ));
    }
    
    // Make sure all items have the correct relationship between selling price and total amount
    final correctedItems = validItems.map((item) {
      // Calculate effective price (adjusted or selling price)
      final effectivePrice = item.adjustedPrice ?? item.sellingPrice;
      
      // Check if totalAmount doesn't match quantity * effectivePrice
      if ((item.quantity * effectivePrice - item.totalAmount).abs() > 0.01) {
        print('ReceiptPanel - Correcting item pricing for ${item.productName}: ' +
              'Qty: ${item.quantity}, Original Total: ${item.totalAmount}, ' +
              'Calculated Total: ${item.quantity * effectivePrice}');
              
        // Return a corrected item
        return item.copyWith(
          totalAmount: item.quantity * effectivePrice,
        );
      }
      return item;
    }).toList();
    
    if (correctedItems.isEmpty) {
      UIHelpers.showSnackBarWithContext(
        context, 
        'Cannot complete sale - no valid product items in order',
        isError: true,
      );
      return;
    }
    
    // Generate a distinct sales receipt number if not already generated
    _salesReceiptNumber ??= ReceiptNumberGenerator.generateSalesReceiptNumber();
    
    print('ReceiptPanel - Generated sales receipt number: $_salesReceiptNumber');
    
    // Calculate total paid from split payments
    double cashAmount = double.tryParse(_cashAmountController.text) ?? 0;
    double mobileAmount = double.tryParse(_mobileAmountController.text) ?? 0;
    double bankAmount = double.tryParse(_bankAmountController.text) ?? 0;
    double totalPaid = cashAmount + mobileAmount + bankAmount;
    
    // Determine effective payment method based on split payments
    String effectivePaymentMethod = _selectedPaymentMethod;
    if (totalPaid > 0 && totalPaid < widget.order.totalAmount) {
      List<String> paymentMethods = [];
      if (cashAmount > 0) paymentMethods.add('Cash');
      if (mobileAmount > 0) paymentMethods.add('Mobile');
      if (bankAmount > 0) paymentMethods.add('Bank');
      if (totalPaid < widget.order.totalAmount) paymentMethods.add(_selectedPaymentMethod);
      
      effectivePaymentMethod = paymentMethods.join(' + ');
    }
    
    // Calculate the correct total based on the selling prices
    final correctTotal = correctedItems.fold<double>(0, (sum, item) => sum + item.totalAmount);
    
    // Create a copy of the order with the selected payment method and only valid items
    final updatedOrder = Order(
      id: widget.order.id,
      orderNumber: widget.order.orderNumber,
      salesReceiptNumber: _salesReceiptNumber,
      heldReceiptNumber: widget.order.heldReceiptNumber,
      customerId: widget.order.customerId,
      customerName: widget.order.customerName,
      totalAmount: correctTotal, // Use the corrected total amount
      orderStatus: widget.order.orderStatus,
      // Improved payment status logic:
      // 1. For full direct payments (cash, mobile, bank) -> 'PAID'
      // 2. For credit sales -> 'CREDIT'
      // 3. For partial payments -> 'PARTIAL'
      paymentStatus: (effectivePaymentMethod.toLowerCase().contains('credit')) 
                     ? (effectivePaymentMethod == 'Credit' ? 'CREDIT' : 'PARTIAL')
                     : (totalPaid >= correctTotal ? 'PAID' : 'PARTIAL'),
      paymentMethod: effectivePaymentMethod,
      createdBy: widget.order.createdBy,
      createdAt: widget.order.createdAt,
      orderDate: widget.order.orderDate,
      items: correctedItems, // Use the corrected items
    );
    
    print('ReceiptPanel - Completing sale with payment method: $effectivePaymentMethod');
    print('ReceiptPanel - Order items count: ${correctedItems.length}');
    print('ReceiptPanel - Corrected total amount: $correctTotal');
    
    // Call the onProcessSale callback with the updated order
    widget.onProcessSale(updatedOrder);
    
    // Log the sales receipt in the activity log
    _logSalesReceipt(updatedOrder);
  }

  // Method to log sales receipt information
  Future<void> _logSalesReceipt(Order order) async {
    try {
      final currentUser = AuthService.instance.currentUser;
      if (currentUser != null) {
        await DatabaseService.instance.logActivity(
          currentUser.id!,
          currentUser.username,
          'SALES_RECEIPT',
          'Sales Receipt Generated',
          'Order #${order.orderNumber} completed with Sales Receipt #$_salesReceiptNumber. '
          'Total: KSH ${order.totalAmount.toStringAsFixed(2)}, '
          'Payment Method: ${order.paymentMethod}',
        );
      }
    } catch (e) {
      print('Error logging sales receipt: $e');
    }
  }

  Future<void> _printReceipt() async {
    try {
      print('ReceiptPanel - Printing receipt with ${_orderItems.length} items');
      
      // Generate a distinct sales receipt number if not already generated
      _salesReceiptNumber ??= ReceiptNumberGenerator.generateSalesReceiptNumber();
      
      print('ReceiptPanel - Using sales receipt number: $_salesReceiptNumber');
      
      // Get the printer service
      final printerService = PrinterService.instance;
      
      // Get config service for company details
      final configService = ConfigService.instance;
      
      // Get tax settings from ConfigService
      final config = ConfigService.instance;
      final enableVat = config.enableVat;
      final vatRate = config.vatRate;
      final showVatOnReceipt = config.showVatOnReceipt;

      // Calculate total amount
      final totalAmount = widget.order.totalAmount ?? 0.0;
      
      // Calculate VAT if enabled
      double vatAmount = 0.0;
      double netAmount = totalAmount;
      
      if (enableVat) {
        // Use the same VAT formula as in settings screen
        vatAmount = totalAmount * (vatRate / (100 + vatRate));
        netAmount = totalAmount - vatAmount;
      }
      
      // Calculate pending balance for credit payments
      double pendingBalance = 0.0;
      final paymentMethod = widget.order.paymentMethod ?? 'Cash';
      
      // Get customer's total outstanding balance if customer ID exists
      double totalOutstandingBalance = 0.0;
      if (widget.order.customerId != null) {
        totalOutstandingBalance = await DatabaseService.instance.getCustomerTotalOutstandingBalance(widget.order.customerId!);
      }
      
      if (paymentMethod.contains('Credit')) {
        if (paymentMethod.contains(',')) {
          // Parse split payment format: "Cash: KSH 900.00, Credit: KSH 6000.00"
          try {
            final creditPart = paymentMethod.split(',')
                .where((part) => part.contains('Credit:'))
                .first
                .trim();
            final amountStr = creditPart.split('KSH').last.trim();
            pendingBalance = double.parse(amountStr);
          } catch (e) {
            print('Error parsing credit amount: $e');
            pendingBalance = widget.order.paymentStatus == 'CREDIT' ? totalAmount : 0.0;
          }
        } else {
          // Full credit payment
          pendingBalance = totalAmount;
        }
      }

      // Create the document with the receipt content
      final doc = pw.Document();
      doc.addPage(
        pw.Page(
          pageFormat: printerService.getPageFormat(),
          build: (context) {
            return pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.center,
            children: [
                // Company logo
                if (configService.showBusinessLogo && configService.businessLogo != null && configService.businessLogo!.isNotEmpty)
                  pw.Container(
                    height: 80,
                    width: 200,
                    alignment: pw.Alignment.center,
                    margin: const pw.EdgeInsets.only(bottom: 10),
                    child: pw.Image(
                      pw.MemoryImage(File(configService.businessLogo!).readAsBytesSync()),
                      fit: pw.BoxFit.contain,
                ),
              ),
                
                // Company name
                pw.Text(
                  configService.businessName,
                  style: pw.TextStyle(
                    fontSize: 16,
                    fontWeight: pw.FontWeight.bold,
                ),
              ),
                
                // Company address and contact info
                if (configService.businessAddress.isNotEmpty)
                  pw.Text(configService.businessAddress),
                
                if (configService.businessPhone.isNotEmpty)
                  pw.Text('Tel: ${configService.businessPhone}'),
                
                // Company tax information - only show if enabled in settings
                if (configService.businessEmail.isNotEmpty)
                  pw.Text('Email: ${configService.businessEmail}'),
                
              pw.SizedBox(height: 10),
              
                // Receipt header text if configured
                if (configService.receiptHeader.isNotEmpty)
                        pw.Text(
                    configService.receiptHeader,
                    style: const pw.TextStyle(fontSize: 12),
                        ),
                
                pw.SizedBox(height: 8),
                
                // Receipt details
                        pw.Text(
                  'SALES RECEIPT',
                          style: pw.TextStyle(
                            fontWeight: pw.FontWeight.bold,
                          ),
                        ),
                
                pw.Text('No: $_salesReceiptNumber'),
                
                        pw.Text(
                  'Date: ${DateFormat(configService.dateTimeFormat.isNotEmpty ? configService.dateTimeFormat : 'yyyy-MM-dd HH:mm').format(DateTime.now())}',
                ),
                
                // Show cashier name if enabled in settings
                if (configService.showCashierName)
                  pw.Text('Cashier: ${AuthService.instance.currentUser?.username ?? "Admin"}'),
                
                // Customer info if available
                if (widget.order.customerName != null && widget.order.customerName!.isNotEmpty)
                  pw.Text('Customer: ${widget.order.customerName}'),
                
                pw.SizedBox(height: 10),
              
              // Items Table Header
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Expanded(
                    flex: 3,
                    child: pw.Text(
                      'Item Name',
                      style: pw.TextStyle(
                        fontWeight: pw.FontWeight.bold,
                        fontSize: 9,
                      ),
                    ),
                  ),
                  pw.Expanded(
                    flex: 1,
                    child: pw.Text(
                      'Qty',
                      style: pw.TextStyle(
                        fontWeight: pw.FontWeight.bold,
                        fontSize: 9,
                      ),
                      textAlign: pw.TextAlign.right,
                    ),
                  ),
                  pw.Expanded(
                    flex: 1,
                    child: pw.Text(
                      'Price',
                      style: pw.TextStyle(
                        fontWeight: pw.FontWeight.bold,
                        fontSize: 9,
                      ),
                      textAlign: pw.TextAlign.right,
                    ),
                  ),
                  pw.Expanded(
                    flex: 1,
                    child: pw.Text(
                      'Total',
                      style: pw.TextStyle(
                        fontWeight: pw.FontWeight.bold,
                        fontSize: 9,
                      ),
                      textAlign: pw.TextAlign.right,
                    ),
                  ),
                ],
              ),
              pw.Divider(thickness: 0.5),
              
              // Order items
              ...List.generate(_orderItems.length, (index) {
                final item = _orderItems[index];
                final isSubUnit = item['is_sub_unit'] == 1;
                final subUnitName = item['sub_unit_name'] as String? ?? 'piece';
                final sellingPrice = (item['selling_price'] as num).toDouble();
                final adjustedPrice = item['adjusted_price'] != null ? (item['adjusted_price'] as num).toDouble() : null;
                final effectivePrice = adjustedPrice ?? sellingPrice;
                
                return pw.Column(
                  children: [
                    pw.Row(
                      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Expanded(
                          flex: 3,
                          child: pw.Text(
                            item['product_name'] ?? 'Unknown Product',
                            style: const pw.TextStyle(fontSize: 9),
                          ),
                        ),
                        pw.Expanded(
                          flex: 1,
                          child: pw.Text(
                            '${item['quantity']}${isSubUnit ? " $subUnitName" : ""}',
                            style: const pw.TextStyle(fontSize: 9),
                            textAlign: pw.TextAlign.right,
                          ),
                        ),
                        pw.Expanded(
                          flex: 1,
                          child: pw.Text(
                            effectivePrice.toStringAsFixed(2),
                            style: const pw.TextStyle(fontSize: 9),
                            textAlign: pw.TextAlign.right,
                          ),
                        ),
                        pw.Expanded(
                          flex: 1,
                          child: pw.Text(
                            (item['total_amount'] as num).toStringAsFixed(2),
                            style: const pw.TextStyle(fontSize: 9),
                            textAlign: pw.TextAlign.right,
                          ),
                        ),
                      ],
                    ),
                    pw.SizedBox(height: 2),
                  ],
                );
              }),
              
              // Total Calculation with VAT
              pw.Divider(),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Expanded(
                    flex: 3,
                    child: pw.Text(
                      'SUBTOTAL:',
                      style: pw.TextStyle(
                        fontWeight: pw.FontWeight.bold,
                        fontSize: 10,
                      ),
                    ),
                  ),
                  pw.Expanded(
                    flex: 1,
                    child: pw.Text(
                      'KSH ${totalAmount.toStringAsFixed(2)}',
                      style: pw.TextStyle(
                        fontWeight: pw.FontWeight.bold,
                        fontSize: 10,
                      ),
                      textAlign: pw.TextAlign.right,
                    ),
                  ),
                ],
              ),
              
              // Show VAT breakdown if enabled and configured to show on receipt
              if (enableVat && showVatOnReceipt) ...[
                pw.SizedBox(height: 5),
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Expanded(
                      flex: 3,
                      child: pw.Text(
                        'VAT (${vatRate.toStringAsFixed(1)}%):',
                        style: const pw.TextStyle(fontSize: 9),
                      ),
                    ),
                    pw.Expanded(
                      flex: 1,
                      child: pw.Text(
                        'KSH ${vatAmount.toStringAsFixed(2)}',
                        style: const pw.TextStyle(fontSize: 9),
                        textAlign: pw.TextAlign.right,
                      ),
                    ),
                  ],
                ),
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Expanded(
                      flex: 3,
                      child: pw.Text(
                        'Net Amount:',
                        style: const pw.TextStyle(fontSize: 9),
                      ),
                    ),
                    pw.Expanded(
                      flex: 1,
                      child: pw.Text(
                        'KSH ${netAmount.toStringAsFixed(2)}',
                        style: const pw.TextStyle(fontSize: 9),
                        textAlign: pw.TextAlign.right,
                      ),
                    ),
                  ],
                ),
              ],
              
              pw.SizedBox(height: 5),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Expanded(
                    flex: 3,
                    child: pw.Text(
                      'TOTAL AMOUNT DUE:',
                      style: pw.TextStyle(
                        fontWeight: pw.FontWeight.bold,
                        fontSize: 10,
                      ),
                    ),
                  ),
                  pw.Expanded(
                    flex: 1,
                    child: pw.Text(
                      'KSH ${totalAmount.toStringAsFixed(2)}',
                      style: pw.TextStyle(
                        fontWeight: pw.FontWeight.bold,
                        fontSize: 10,
                      ),
                      textAlign: pw.TextAlign.right,
                    ),
                  ),
                ],
              ),
              
              // Payment Details
              pw.SizedBox(height: 10),
              pw.Text(
                'PAYMENT DETAILS:',
                style: pw.TextStyle(
                  fontWeight: pw.FontWeight.bold,
                  fontSize: 10,
                ),
              ),
              pw.SizedBox(height: 5),
              pw.Row(
                children: [
                  pw.Text(
                    'Payment Mode:',
                    style: const pw.TextStyle(fontSize: 9),
                  ),
                  pw.SizedBox(width: 5),
                  pw.Text(
                    widget.order.paymentMethod ?? 'Cash',
                    style: const pw.TextStyle(fontSize: 9),
                  ),
                ],
              ),
              pw.Row(
                children: [
                  pw.Text(
                    'Paid By:',
                    style: const pw.TextStyle(fontSize: 9),
                  ),
                  pw.SizedBox(width: 5),
                  pw.Text(
                    widget.order.customerName ?? 'Walk-in Customer',
                    style: const pw.TextStyle(fontSize: 9),
                  ),
                ],
              ),
              
              // Add who serviced the transaction
              pw.Row(
                children: [
                  pw.Text(
                    'Serviced by:',
                    style: const pw.TextStyle(fontSize: 9),
                  ),
                  pw.SizedBox(width: 5),
                  pw.Text(
                    AuthService.instance.currentUser?.username ?? 'Admin',
                    style: const pw.TextStyle(fontSize: 9),
                  ),
                ],
              ),
              
              // Show pending balance for credit orders
              if (widget.order.paymentMethod != null && widget.order.paymentMethod!.contains('Credit')) ...[
                pw.SizedBox(height: 5),
                pw.Row(
                  children: [
                    pw.Text(
                      'Current Order Balance:',
                      style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9),
                    ),
                    pw.SizedBox(width: 5),
                    pw.Text(
                      'KSH ${pendingBalance.toStringAsFixed(2)}',
                      style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9),
                    ),
                  ],
                ),
                
                // Show total outstanding balance if applicable
                if (widget.order.customerId != null && (totalOutstandingBalance > 0 || pendingBalance > 0)) ...[
                  pw.SizedBox(height: 5),
                  // First show previous outstanding balance if exists
                  if (totalOutstandingBalance > 0) ...[
                    pw.Row(
                      children: [
                        pw.Text(
                          'Previous Outstanding Balance:',
                          style: pw.TextStyle(fontSize: 9),
                        ),
                        pw.SizedBox(width: 5),
                        pw.Text(
                          'KSH ${totalOutstandingBalance.toStringAsFixed(2)}',
                          style: pw.TextStyle(fontSize: 9),
                        ),
                      ],
                    ),
                  ],
                  // Then show combined total 
                  pw.Row(
                    children: [
                      pw.Text(
                        'Total Outstanding Balance:',
                        style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9, color: const PdfColor.fromInt(0xffff0000)),
                      ),
                      pw.SizedBox(width: 5),
                      pw.Text(
                        'KSH ${(totalOutstandingBalance + pendingBalance).toStringAsFixed(2)}',
                        style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9, color: const PdfColor.fromInt(0xffff0000)),
                      ),
                    ],
                  ),
                ],
              ],
              
              // Footer Section
              pw.SizedBox(height: 10),
              pw.Center(
                child: pw.Text(
                  'Thank you for your business!',
                  style: pw.TextStyle(
                    fontSize: 10,
                    fontStyle: pw.FontStyle.italic,
                  ),
                ),
              ),
              pw.Center(
                child: pw.Text(
                  'Please keep this receipt for your records',
                  style: pw.TextStyle(
                    fontSize: 8,
                  ),
                ),
              ),
              pw.SizedBox(height: 5),
                
                // Add "Goods once sold are not returnable" disclaimer when enabled
                if (configService.showNoReturnsPolicy)
                  pw.Center(
                    child: pw.Text(
                      'Goods once sold are not returnable.',
                      style: const pw.TextStyle(fontSize: 10),
                    ),
                  ),
                
              pw.Center(
                child: pw.Text(
                  'Powered by Malbrose POS',
                  style: pw.TextStyle(
                    fontSize: 8,
                  ),
                ),
              ),
              
              // Extra space for thermal printer cutting
              pw.SizedBox(height: 20),
            ],
            );
          }
        ),
      );

      // Use the printer service to print the PDF
      await printerService.printPdf(
        pdf: doc,
        documentName: 'Receipt-${widget.order.orderNumber}',
        context: context,
      );
    } catch (e) {
      print('Error printing receipt: $e');
      if (!mounted) return;
      
      UIHelpers.showSnackBarWithContext(
        context, 
        'Error printing receipt: $e',
        isError: true,
      );
    }
  }

  Future<void> _confirmDeleteOrder(BuildContext context) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Order'),
        content: const Text(
          'Are you sure you want to delete this order? This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (result == true && widget.order.id != null) {
      try {
        // Log the deletion
        await DatabaseService.instance.logActivity(
          1, // Default admin user ID
          'admin',
          'ORDER_DELETION',
          'Order Deleted',
          'Order with ID ${widget.order.id} and total amount KSH ${widget.order.totalAmount} was deleted',
        );
        
        // Delete the order
        await DatabaseService.instance.deleteOrder(widget.order.id!);
        
        if (!mounted) return;
        
        UIHelpers.showSnackBarWithContext(
          context, 
          'Order deleted successfully',
          isError: false,
        );
        
        // Navigate back
        Navigator.pop(context);
      } catch (e) {
        if (!mounted) return;
        
        UIHelpers.showSnackBarWithContext(
          context, 
          'Error deleting order: $e',
          isError: true,
        );
      }
    }
  }

  Future<void> _showCreditDetailsDialog() async {
    // Get existing split payment values from the main interface
    // We'll store these values separately since we need to preserve the controllers as-is
    final String cashText = _cashAmountController.text;
    final String mobileText = _mobileAmountController.text;
    final String bankText = _bankAmountController.text;
    
    double existingCashAmount = double.tryParse(cashText) ?? 0;
    double existingMobileAmount = double.tryParse(mobileText) ?? 0;
    double existingBankAmount = double.tryParse(bankText) ?? 0;
    
    // Calculate total paid amount
    double existingTotalPaid = existingCashAmount + existingMobileAmount + existingBankAmount;
    
    // Setup the controllers for the dialog
    // We'll create temporary controllers just for the dialog to avoid controller conflicts
    final dialogCashController = TextEditingController(text: existingCashAmount > 0 ? existingCashAmount.toStringAsFixed(2) : '');
    final dialogMobileController = TextEditingController(text: existingMobileAmount > 0 ? existingMobileAmount.toStringAsFixed(2) : '');
    final dialogBankController = TextEditingController(text: existingBankAmount > 0 ? existingBankAmount.toStringAsFixed(2) : '');
    final dialogNotesController = TextEditingController();
    
    _creditCustomerNameController.text = widget.order.customerName ?? '';
    _selectedCustomer = null;
    
    // Calculate remaining credit amount based on existing payments
    double totalAmount = widget.order.totalAmount;
    double remainingCredit = totalAmount - existingTotalPaid;
    
    // Generate a credit receipt number if needed
    final creditReceiptNumber = ReceiptNumberGenerator.generateCreditReceiptNumber();
    
    print('ReceiptPanel - Using existing payment: Cash: ${existingCashAmount}, Mobile: ${existingMobileAmount}, Bank: ${existingBankAmount}');
    print('ReceiptPanel - Total paid amount: ${existingTotalPaid}, Remaining credit: ${remainingCredit}');
    
    print('ReceiptPanel - Generated credit receipt number: $creditReceiptNumber');
    
    // If there's a customer ID in the order, try to get customer details
    if (widget.order.customerId != null) {
      try {
        final customer = await DatabaseService.instance.getCustomerById(widget.order.customerId!);
        if (customer != null) {
          _selectedCustomer = customer;
          _creditCustomerNameController.text = _selectedCustomer!.name;
        }
      } catch (e) {
        print('Error fetching customer: $e');
      }
    }
    
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) {
          // Calculate the remaining credit amount based on entered values
          void updateRemainingCredit() {
            double cashAmount = double.tryParse(dialogCashController.text) ?? 0;
            double mobileAmount = double.tryParse(dialogMobileController.text) ?? 0;
            double bankAmount = double.tryParse(dialogBankController.text) ?? 0;
            
            double totalPaid = cashAmount + mobileAmount + bankAmount;
            
            // Validate that total paid doesn't exceed total amount
            if (totalPaid > totalAmount) {
              UIHelpers.showSnackBarWithContext(
                context,
                'Total paid amount cannot exceed total order amount',
                isError: true,
              );
              // Reset the last changed amount
              if (_cashAmountController.text.isNotEmpty) {
                _cashAmountController.text = (totalAmount - (mobileAmount + bankAmount)).toStringAsFixed(2);
              } else if (_mobileAmountController.text.isNotEmpty) {
                _mobileAmountController.text = (totalAmount - (cashAmount + bankAmount)).toStringAsFixed(2);
              } else if (_bankAmountController.text.isNotEmpty) {
                _bankAmountController.text = (totalAmount - (cashAmount + mobileAmount)).toStringAsFixed(2);
              }
              totalPaid = totalAmount;
            }
            
            remainingCredit = totalAmount - totalPaid;
            
            // Ensure we don't have negative credit
            if (remainingCredit < 0) remainingCredit = 0;
            
            // Update total paid for the main UI as well
            _totalPaid = totalPaid;
          }
          
          // Update initial remaining credit
          updateRemainingCredit();
          
          return AlertDialog(
            title: const Text('Payment Details'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Customer Information:'),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _creditCustomerNameController,
                    decoration: const InputDecoration(
                      labelText: 'Customer Name',
                      border: OutlineInputBorder(),
                    ),
                    readOnly: _selectedCustomer != null, // Read-only if customer is selected
                  ),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.blue),
                      borderRadius: BorderRadius.circular(4),
                      color: Colors.blue.shade50,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'Total Order Amount:',
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                            Text(
                              'KSH ${totalAmount.toStringAsFixed(2)}',
                              style: const TextStyle(fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'Total Paid:',
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                            Text(
                              'KSH ${(totalAmount - remainingCredit).toStringAsFixed(2)}',
                              style: const TextStyle(fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'Remaining Credit:',
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                            Text(
                              'KSH ${remainingCredit.toStringAsFixed(2)}',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.red,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Split Payment Details:',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: dialogCashController,
                          decoration: const InputDecoration(
                            labelText: 'Cash Amount',
                            border: OutlineInputBorder(),
                            prefixText: 'KSH ',
                          ),
                          keyboardType: TextInputType.number,
                          onChanged: (value) {
                            setState(() {
                              updateRemainingCredit();
                            });
                          },
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextFormField(
                          controller: dialogMobileController,
                          decoration: const InputDecoration(
                            labelText: 'Mobile Payment',
                            border: OutlineInputBorder(),
                            prefixText: 'KSH ',
                          ),
                          keyboardType: TextInputType.number,
                          onChanged: (value) {
                            setState(() {
                              updateRemainingCredit();
                            });
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: dialogBankController,
                          decoration: const InputDecoration(
                            labelText: 'Bank Transfer',
                            border: OutlineInputBorder(),
                            prefixText: 'KSH ',
                          ),
                          keyboardType: TextInputType.number,
                          onChanged: (value) {
                            setState(() {
                              updateRemainingCredit();
                            });
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: dialogNotesController,
                    decoration: const InputDecoration(
                      labelText: 'Payment Notes',
                      border: OutlineInputBorder(),
                      hintText: 'Enter any additional payment details',
                    ),
                    maxLines: 3,
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () async {
                  // Validate customer name
                  if (_creditCustomerNameController.text.trim().isEmpty) {
                    UIHelpers.showSnackBarWithContext(
                      context, 
                      'Please enter customer name',
                      isError: true,
                    );
                    return;
                  }
                  
                  // Get values from dialog-specific controllers
                  double cashAmount = double.tryParse(dialogCashController.text) ?? 0;
                  double mobileAmount = double.tryParse(dialogMobileController.text) ?? 0;
                  double bankAmount = double.tryParse(dialogBankController.text) ?? 0;
                  double totalPaid = cashAmount + mobileAmount + bankAmount;
                  
                  // Update main screen controllers with these values for persistence
                  if (cashAmount > 0) _cashAmountController.text = cashAmount.toStringAsFixed(2);
                  if (mobileAmount > 0) _mobileAmountController.text = mobileAmount.toStringAsFixed(2);
                  if (bankAmount > 0) _bankAmountController.text = bankAmount.toStringAsFixed(2);
                  
                  // Update notes if any were entered
                  if (dialogNotesController.text.isNotEmpty) {
                    _creditDetailsController.text = dialogNotesController.text;
                  }
                  
                  if (totalPaid > totalAmount) {
                    UIHelpers.showSnackBarWithContext(
                      context,
                      'Total paid amount cannot exceed total order amount',
                      isError: true,
                    );
                    return;
                  }
                  
                  Navigator.of(context).pop();
                  
                  // Create payment details string
                  List<String> paymentDetails = [];
                  if (cashAmount > 0) paymentDetails.add('Cash: KSH ${cashAmount.toStringAsFixed(2)}');
                  if (mobileAmount > 0) paymentDetails.add('Mobile: KSH ${mobileAmount.toStringAsFixed(2)}');
                  if (bankAmount > 0) paymentDetails.add('Bank: KSH ${bankAmount.toStringAsFixed(2)}');
                  if (remainingCredit > 0) paymentDetails.add('Credit: KSH ${remainingCredit.toStringAsFixed(2)}');
                  
                  // Determine effective payment method based on split payments
                  String paymentMethodsUsed = paymentDetails.join(', ');
                  
                  String effectivePaymentMethod;
                  if (paymentDetails.length > 1) {
                    // It's a split payment
                    effectivePaymentMethod = paymentMethodsUsed;
                  } else if (remainingCredit > 0 && totalPaid == 0) {
                    // Full credit payment
                    effectivePaymentMethod = 'Credit';
                  } else {
                    // Single payment method
                    effectivePaymentMethod = remainingCredit > 0 ? 'Credit' : _selectedPaymentMethod;
                  }
                  
                  print('ReceiptPanel - Effective payment method: $effectivePaymentMethod');
                  
                  // Bypass the normal _completeSale() flow to avoid the loop
                  // Instead, directly complete the sale with the effective payment method
                  await _directlyCompleteSale(effectivePaymentMethod, remainingCredit);
                  
                  // Skip the credit record creation since we'll handle it in _directlyCompleteSale
                  // But we still want to log the split payment if applicable
                  // Log the split payment if applicable
                  if (cashAmount > 0 || mobileAmount > 0 || bankAmount > 0) {
                    try {
                      final currentUser = AuthService.instance.currentUser;
                      if (currentUser != null) {
                        await DatabaseService.instance.logActivity(
                          currentUser.id!,
                          currentUser.username,
                          'split_payment',
                          'Split Payment',
                          'Order #${widget.order.orderNumber}: $paymentMethodsUsed',
                        );
                      }
                    } catch (e) {
                      print('Error logging split payment: $e');
                    }
                  }
                  
                  // Just return from here, we don't need the remaining code since _directlyCompleteSale handles everything
                  return;
                  
                  // Keep this condition for backward compatibility, but it should never run now
                  if (false && remainingCredit > 0) {
                    try {
                      // Make sure customer ID is set
                      int? customerId = widget.order.customerId;
                      
                      // If no customer ID and we have a customer name, try to find or create the customer
                      if (customerId == null && _creditCustomerNameController.text.trim().isNotEmpty) {
                        try {
                          // Use a single transaction for customer operations
                          await DatabaseService.instance.withTransaction((txn) async {
                            // Try to find existing customer by name
                            final customer = await txn.query(
                              DatabaseService.tableCustomers,
                              where: 'name = ?',
                              whereArgs: [_creditCustomerNameController.text.trim()],
                              limit: 1,
                            );
                            
                            if (customer.isNotEmpty) {
                              customerId = customer.first['id'] as int;
                              print('Found existing customer: ${customer.first['name']} (ID: $customerId)');
                            } else {
                              // Create new customer if not found
                              final newCustomer = {
                                'name': _creditCustomerNameController.text.trim(),
                                'created_at': DateTime.now().toIso8601String(),
                              };
                              
                              final id = await txn.insert(
                                DatabaseService.tableCustomers,
                                newCustomer,
                              );
                              
                              if (id != null) {
                                customerId = id as int;
                                print('Created new customer: ${newCustomer['name']} (ID: $customerId)');
                              }
                            }
                          });
                        } catch (e) {
                          print('Error finding/creating customer: $e');
                          if (!mounted) return;
                          UIHelpers.showSnackBarWithContext(
                            context,
                            'Error processing customer: $e',
                            isError: true,
                          );
                          return;
                        }
                      }
                      
                      // Create the creditor record with all required fields
                      final creditor = {
                        'name': _creditCustomerNameController.text.trim(),
                        'balance': remainingCredit,
                        'details': 'Credit for Order #${widget.order.orderNumber}. '
                            '${_creditDetailsController.text.isNotEmpty ? _creditDetailsController.text : ''}'
                            ' (Split payment: $paymentMethodsUsed)',
                        'status': 'PENDING',
                        'created_at': DateTime.now().toIso8601String(),
                        'order_number': widget.order.orderNumber,
                        'receipt_number': creditReceiptNumber,
                        'order_details': widget.order.items.map((i) => i.productName).join(', '),
                        'original_amount': widget.order.totalAmount,
                        'customer_id': customerId,
                      };
                      
                      print('Adding creditor record: ${creditor.toString()}');
                      
                      // Use a single transaction for creditor record creation
                      await DatabaseService.instance.withTransaction((txn) async {
                        // Check for existing creditor with same order number
                        final existingCreditors = await txn.query(
                          DatabaseService.tableCreditors,
                          where: 'order_number = ?',
                          whereArgs: [widget.order.orderNumber],
                          limit: 1,
                        );
                        
                        if (existingCreditors.isEmpty) {
                          await txn.insert(
                            DatabaseService.tableCreditors,
                            creditor,
                          );
                          
                          // Also update the order to reflect the credit payment
                          await txn.update(
                            DatabaseService.tableOrders,
                            {
                              'payment_status': remainingCredit > 0 ? 'PARTIAL' : 'PAID',
                              'payment_method': totalPaid > 0 && remainingCredit > 0 ? 'Split Payment' : 'Credit',
                              'updated_at': DateTime.now().toIso8601String()
                            },
                            where: 'order_number = ?',
                            whereArgs: [widget.order.orderNumber],
                          );
                          
                          // Log the activity within the same transaction
                          final currentUser = AuthService.instance.currentUser;
                          if (currentUser != null) {
                            await txn.insert(
                              DatabaseService.tableActivityLogs,
                              {
                                'user_id': currentUser.id,
                                'username': currentUser.username,
                                'action': 'create_credit',
                                'action_type': 'Create credit',
                                'details': 'Created credit record for Order #${widget.order.orderNumber}',
                                'timestamp': DateTime.now().toIso8601String(),
                              },
                            );
                          }
                        } else {
                          print('Warning: Creditor record already exists for order #${widget.order.orderNumber}');
                        }
                      });
                    } catch (e) {
                      print('Error adding credit record: $e');
                      
                      // Try to get more detailed error information
                      if (e.toString().contains('no such column')) {
                        print('Missing column error. This typically happens when the database schema is out of date.');
                        print('Attempted to create credit record for customer: ${_creditCustomerNameController.text.trim()}');
                      } else if (e.toString().contains('database is locked') || e.toString().contains('busy')) {
                        print('Database lock detected. The database is busy with another transaction.');
                      }
                      
                      if (!mounted) return;
                      UIHelpers.showSnackBarWithContext(
                        context, 
                        'Error adding credit record: $e',
                        isError: true,
                      );
                    }
                  }
                },
                child: const Text('Confirm Payment'),
              ),
            ],
          );
        }
      ),
    );
  }
}
