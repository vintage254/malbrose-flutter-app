import 'package:flutter/material.dart';
import 'package:my_flutter_app/const/constant.dart';
import 'package:my_flutter_app/models/order_model.dart';
import 'package:my_flutter_app/models/product_model.dart';
import 'package:my_flutter_app/services/database.dart';
import 'package:printing/printing.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:intl/intl.dart';
import 'package:my_flutter_app/widgets/order_cart_panel.dart';
import 'package:my_flutter_app/models/cart_item_model.dart';
import 'package:my_flutter_app/widgets/order_receipt_dialog.dart';
import 'package:my_flutter_app/screens/order_screen.dart';
import 'package:my_flutter_app/services/printer_service.dart';
import 'package:my_flutter_app/models/customer_model.dart';
import 'dart:async';
import 'dart:math';

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

  @override
  void initState() {
    super.initState();
    _loadOrderItems();
  }

  @override
  void dispose() {
    _creditDetailsController.dispose();
    _creditCustomerNameController.dispose();
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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading order items: $e')),
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
          Text('Customer: ${widget.order.customerName ?? "N/A"}'),
          Text('Date: ${DateFormat('yyyy-MM-dd HH:mm').format(widget.order.orderDate)}'),
          const Divider(),
          Expanded(
            child: _isLoading 
              ? const Center(child: CircularProgressIndicator())
              : _orderItems.isEmpty
                ? const Center(child: Text('No items in this order'))
                : ListView.builder(
                    itemCount: _orderItems.length,
                    itemBuilder: (context, index) {
                      final item = _orderItems[index];
                      return Card(
                        margin: const EdgeInsets.symmetric(vertical: 4.0),
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
                    DropdownMenuItem(value: 'Credit Card', child: Text('Credit Card')),
                    DropdownMenuItem(value: 'Bank Transfer', child: Text('Bank Transfer')),
                    DropdownMenuItem(value: 'Credit', child: Text('Credit')),
                  ],
                  onChanged: (value) {
                    setState(() {
                      _selectedPaymentMethod = value!;
                    });
                  },
                ),
                const SizedBox(height: 16),
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
              const SizedBox(width: 8),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () => _printReceipt(),
                  icon: const Icon(Icons.print),
                  label: const Text('Print Receipt'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.orange,
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
        ),
      ),
    );
  }

  void _completeSale() {
    // Create a copy of the order with the selected payment method
    final updatedOrder = Order(
      id: widget.order.id,
      orderNumber: widget.order.orderNumber,
      customerId: widget.order.customerId,
      customerName: widget.order.customerName,
      totalAmount: widget.order.totalAmount,
      orderStatus: widget.order.orderStatus,
      paymentStatus: widget.order.paymentStatus,
      paymentMethod: _selectedPaymentMethod,
      createdBy: widget.order.createdBy,
      createdAt: widget.order.createdAt,
      orderDate: widget.order.orderDate,
      items: widget.order.items,
    );
    
    print('ReceiptPanel - Completing sale with payment method: ${_selectedPaymentMethod}');
    print('ReceiptPanel - Order items count: ${widget.order.items.length}');
    
    // Call the onProcessSale callback with the updated order
    widget.onProcessSale(updatedOrder);
  }

  Future<void> _printReceipt() async {
    try {
      print('ReceiptPanel - Printing receipt with ${_orderItems.length} items');
      
      // Get the printer service
      final printerService = PrinterService.instance;
      
      // Create the PDF document
      final pdf = pw.Document();
      
      // Determine if this is a sale or a quotation
      final salePrefix = widget.order.orderStatus == 'COMPLETED' ? 'Receipt' : 'Quotation';
      
      // Add a page to the PDF
      pdf.addPage(
        pw.Page(
          // Use the printer service to get the appropriate page format
          pageFormat: printerService.getPageFormat(),
          build: (context) => pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              // Header Section
              pw.Center(
                child: pw.Text(
                  'MALBROSE HARDWARE AND STORE',
                  style: pw.TextStyle(
                    fontSize: 12,
                    fontWeight: pw.FontWeight.bold,
                  ),
                  textAlign: pw.TextAlign.center,
                ),
              ),
              pw.Center(
                child: pw.Text(
                  'Eldoret',
                  style: pw.TextStyle(
                    fontSize: 10,
                  ),
                ),
              ),
              pw.Center(
                child: pw.Text(
                  '0720319340, 0721705613',
                  style: pw.TextStyle(
                    fontSize: 10,
                  ),
                ),
              ),
              pw.SizedBox(height: 10),
              
              // Transaction Details
              pw.Divider(),
              pw.Text(
                'SALE #: ${widget.order.orderNumber}',
                style: pw.TextStyle(
                  fontWeight: pw.FontWeight.bold,
                  fontSize: 10,
                ),
              ),
              pw.Text(
                'Date: ${DateFormat('yyyy-MM-dd HH:mm').format(widget.order.orderDate)}',
                style: const pw.TextStyle(fontSize: 10),
              ),
              pw.Text(
                'Customer: ${widget.order.customerName ?? "Walk-in"}',
                style: const pw.TextStyle(fontSize: 10),
              ),
              pw.Divider(),
              
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
                            '${effectivePrice.toStringAsFixed(2)}',
                            style: const pw.TextStyle(fontSize: 9),
                            textAlign: pw.TextAlign.right,
                          ),
                        ),
                        pw.Expanded(
                          flex: 1,
                          child: pw.Text(
                            '${(item['total_amount'] as num).toStringAsFixed(2)}',
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
              
              // Total Calculation
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
                      '',
                      style: const pw.TextStyle(fontSize: 9),
                    ),
                  ),
                  pw.Expanded(
                    flex: 1,
                    child: pw.Text(
                      '',
                      style: const pw.TextStyle(fontSize: 9),
                    ),
                  ),
                  pw.Expanded(
                    flex: 1,
                    child: pw.Text(
                      'KSH ${widget.order.totalAmount.toStringAsFixed(2)}',
                      style: pw.TextStyle(
                        fontWeight: pw.FontWeight.bold,
                        fontSize: 10,
                      ),
                      textAlign: pw.TextAlign.right,
                    ),
                  ),
                ],
              ),
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
                      '',
                      style: const pw.TextStyle(fontSize: 9),
                    ),
                  ),
                  pw.Expanded(
                    flex: 1,
                    child: pw.Text(
                      '',
                      style: const pw.TextStyle(fontSize: 9),
                    ),
                  ),
                  pw.Expanded(
                    flex: 1,
                    child: pw.Text(
                      'KSH ${widget.order.totalAmount.toStringAsFixed(2)}',
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
                    widget.order.paymentMethod ?? _selectedPaymentMethod,
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
          ),
        ),
      );

      // Use the printer service to print the PDF
      await printerService.printPdf(
        pdf: pdf,
        documentName: '${salePrefix}-${widget.order.orderNumber}',
        context: context,
      );
    } catch (e) {
      print('Error printing receipt: $e');
      if (!mounted) return;
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error printing receipt: $e'),
          backgroundColor: Colors.red,
        ),
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
        
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Order deleted successfully'),
            backgroundColor: Colors.green,
          ),
        );
        
        // Navigate back
        Navigator.pop(context);
      } catch (e) {
        if (!mounted) return;
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error deleting order: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _showCreditDetailsDialog() async {
    // Reset the controllers
    _creditDetailsController.clear();
    _creditCustomerNameController.text = widget.order.customerName ?? '';
    _selectedCustomer = null;
    
    // If there's a customer ID in the order, try to get customer details
    if (widget.order.customerId != null) {
      try {
        final customerData = await DatabaseService.instance.getCustomerById(widget.order.customerId!);
        if (customerData != null) {
          _selectedCustomer = Customer.fromMap(customerData);
          _creditCustomerNameController.text = _selectedCustomer!.name;
        }
      } catch (e) {
        print('Error fetching customer: $e');
      }
    }
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Credit Sale Details'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Order will be added as credit to:'),
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
              TextFormField(
                controller: _creditDetailsController,
                decoration: const InputDecoration(
                  labelText: 'Credit Details',
                  border: OutlineInputBorder(),
                  hintText: 'Enter any additional details about this credit',
                ),
                maxLines: 3,
              ),
              const SizedBox(height: 16),
              Text(
                'Total Amount: KSH ${widget.order.totalAmount.toStringAsFixed(2)}',
                style: const TextStyle(fontWeight: FontWeight.bold),
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
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Please enter customer name')),
                );
                return;
              }
              
              Navigator.of(context).pop();
              
              // First complete the sale normally
              _completeSale();
              
              // Then add the credit record
              try {
                final creditor = {
                  'name': _creditCustomerNameController.text.trim(),
                  'balance': widget.order.totalAmount,
                  'details': 'Credit for Order #${widget.order.orderNumber}. '
                      '${_creditDetailsController.text.isNotEmpty ? _creditDetailsController.text : ''}',
                  'status': 'PENDING',
                  'created_at': DateTime.now().toIso8601String(),
                };
                
                await DatabaseService.instance.addCreditor(creditor);
                
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Credit record added successfully'),
                    backgroundColor: Colors.green,
                  ),
                );
              } catch (e) {
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Error adding credit record: $e'),
                    backgroundColor: Colors.red,
                  ),
                );
              }
            },
            child: const Text('Confirm Credit Sale'),
          ),
        ],
      ),
    );
  }
}
