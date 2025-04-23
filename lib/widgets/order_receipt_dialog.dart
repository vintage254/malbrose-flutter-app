import 'package:flutter/material.dart';
import 'package:my_flutter_app/const/constant.dart';
import 'package:my_flutter_app/models/cart_item_model.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:intl/intl.dart';
import 'package:my_flutter_app/services/printer_service.dart';

class OrderReceiptDialog extends StatefulWidget {
  final List<CartItem> items;
  final String? customerName;
  final String paymentMethod;
  final String? orderNumber;
  final Function(String paymentMethod)? onCompleteSale;

  const OrderReceiptDialog({
    super.key,
    required this.items,
    this.customerName,
    this.paymentMethod = 'Cash',
    this.orderNumber,
    this.onCompleteSale,
  });

  @override
  State<OrderReceiptDialog> createState() => _OrderReceiptDialogState();
}

class _OrderReceiptDialogState extends State<OrderReceiptDialog> {
  late List<CartItem> _orderItems;
  final bool _isLoading = false;
  String _selectedPaymentMethod = 'Cash';
  final TextEditingController _cashAmountController = TextEditingController();
  final TextEditingController _creditAmountController = TextEditingController();
  bool _isSplitPayment = false;

  @override
  void initState() {
    super.initState();
    _orderItems = widget.items;
    _selectedPaymentMethod = widget.paymentMethod;
    print('OrderReceiptDialog - Items count: ${_orderItems.length}');
    if (_orderItems.isNotEmpty) {
      final firstItem = _orderItems.first;
      print('OrderReceiptDialog - First item: ${firstItem.product.productName}, Quantity: ${firstItem.quantity}, Total: ${firstItem.total}');
      print('OrderReceiptDialog - First item selling price: ${firstItem.product.sellingPrice}, Effective price: ${firstItem.effectivePrice}');
    } else {
      print('OrderReceiptDialog - WARNING: No items received for receipt!');
      print('OrderReceiptDialog - Customer name: ${widget.customerName}');
      print('OrderReceiptDialog - Widget items length: ${widget.items.length}');
      print('OrderReceiptDialog - Payment method: ${widget.paymentMethod}');
    }
    
    _calculateInitialAmounts();
  }
  
  void _calculateInitialAmounts() {
    final totalAmount = _orderItems.fold<double>(
      0,
      (sum, item) => sum + item.total,
    );
    
    _cashAmountController.text = totalAmount.toStringAsFixed(2);
    _creditAmountController.text = "0.00";
  }

  @override
  void dispose() {
    _cashAmountController.dispose();
    _creditAmountController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final totalAmount = _orderItems.fold<double>(
      0,
      (sum, item) => sum + item.total,
    );
    
    print('OrderReceiptDialog - Calculated total amount: $totalAmount');
    
    return AlertDialog(
      title: const Text('Order Receipt'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Malbrose Hardware Store',
                style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: defaultPadding),
            Text('Date: ${DateFormat('yyyy-MM-dd HH:mm').format(DateTime.now())}'),
            if (widget.customerName != null && widget.customerName!.isNotEmpty)
              Text('Customer: ${widget.customerName}'),
            if (widget.orderNumber != null)
              Text('Order #: ${widget.orderNumber}'),
            const Divider(),
            // Table header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  flex: 2,
                  child: Text('Item', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
                Expanded(
                  child: Text('Qty', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
                Expanded(
                  child: Text('Price', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
                Expanded(
                  child: Text('Total', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ],
            ),
            const Divider(),
            ..._orderItems.map((item) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    flex: 2,
                    child: Text(item.product.productName),
                  ),
                  Expanded(
                    child: Text('x${item.quantity}${item.isSubUnit ? ' ${item.subUnitName ?? "pieces"}' : ''}'),
                  ),
                  Expanded(
                    child: Text('KSH ${item.effectivePrice.toStringAsFixed(2)}'),
                  ),
                  Expanded(
                    child: Text('KSH ${item.total.toStringAsFixed(2)}'),
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
                  'KSH ${totalAmount.toStringAsFixed(2)}',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 16),
            
            // Payment method section
            if (widget.onCompleteSale != null) ...[
              const Text('Payment Method:', style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              
              // Payment method selection
              Row(
                children: [
                  Expanded(
                    child: RadioListTile<String>(
                      title: const Text('Cash'),
                      value: 'Cash',
                      groupValue: _selectedPaymentMethod,
                      onChanged: (value) {
                        setState(() {
                          _selectedPaymentMethod = value!;
                          _isSplitPayment = false;
                          _calculateInitialAmounts();
                        });
                      },
                    ),
                  ),
                  Expanded(
                    child: RadioListTile<String>(
                      title: const Text('Credit'),
                      value: 'Credit',
                      groupValue: _selectedPaymentMethod,
                      onChanged: (value) {
                        setState(() {
                          _selectedPaymentMethod = value!;
                          _isSplitPayment = false;
                          _cashAmountController.text = "0.00";
                          _creditAmountController.text = totalAmount.toStringAsFixed(2);
                        });
                      },
                    ),
                  ),
                ],
              ),
              
              // Split payment option
              CheckboxListTile(
                title: const Text('Split Payment'),
                value: _isSplitPayment,
                onChanged: (value) {
                  setState(() {
                    _isSplitPayment = value!;
                    if (_isSplitPayment) {
                      _selectedPaymentMethod = 'Split';
                      _cashAmountController.text = (totalAmount / 2).toStringAsFixed(2);
                      _creditAmountController.text = (totalAmount / 2).toStringAsFixed(2);
                    } else {
                      _selectedPaymentMethod = 'Cash';
                      _calculateInitialAmounts();
                    }
                  });
                },
              ),
              
              // Split payment fields
              if (_isSplitPayment) ...[
                const SizedBox(height: 8),
                TextField(
                  controller: _cashAmountController,
                  decoration: const InputDecoration(
                    labelText: 'Cash Amount',
                    prefixText: 'KSH ',
                    border: OutlineInputBorder(),
                  ),
                  keyboardType: TextInputType.number,
                  onChanged: (_) => _updateSplitPayment(totalAmount),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _creditAmountController,
                  decoration: const InputDecoration(
                    labelText: 'Credit Amount',
                    prefixText: 'KSH ',
                    border: OutlineInputBorder(),
                  ),
                  keyboardType: TextInputType.number,
                  onChanged: (_) => _updateSplitPayment(totalAmount),
                ),
              ],
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Close'),
        ),
        if (widget.onCompleteSale != null)
          ElevatedButton(
            onPressed: () {
              String paymentMethodString;
              if (_isSplitPayment) {
                final cashAmount = double.tryParse(_cashAmountController.text) ?? 0;
                final creditAmount = double.tryParse(_creditAmountController.text) ?? 0;
                paymentMethodString = 'Cash: KSH ${cashAmount.toStringAsFixed(2)}, Credit: KSH ${creditAmount.toStringAsFixed(2)}';
              } else {
                paymentMethodString = _selectedPaymentMethod;
              }
              
              widget.onCompleteSale!(paymentMethodString);
              Navigator.pop(context);
            },
            child: const Text('Complete Sale'),
          ),
        ElevatedButton(
          onPressed: () => _printReceipt(),
          child: const Text('Print Receipt'),
        ),
      ],
    );
  }
  
  void _updateSplitPayment(double totalAmount) {
    double cashAmount = double.tryParse(_cashAmountController.text) ?? 0;
    double creditAmount = double.tryParse(_creditAmountController.text) ?? 0;
    
    // Ensure total matches the order total
    if (cashAmount + creditAmount != totalAmount) {
      creditAmount = totalAmount - cashAmount;
      if (creditAmount < 0) {
        cashAmount = totalAmount;
        creditAmount = 0;
      }
      _creditAmountController.text = creditAmount.toStringAsFixed(2);
    }
  }

  Future<void> _printReceipt() async {
    try {
      print('Printing receipt with ${widget.items.length} items');
      
      // Get the printer service
      final printerService = PrinterService.instance;
      
      // Calculate total amount
      final totalAmount = _orderItems.fold<double>(
        0,
        (sum, item) => sum + item.total,
      );
      
      // Generate a unique order number if not available
      final orderNumber = widget.orderNumber ?? 'ORD-${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}';
      
      // Current timestamp
      final now = DateTime.now();
      
      // Create the PDF document
      final pdf = pw.Document();
      
      // Add a page to the PDF
      pdf.addPage(
        pw.Page(
          // Use the printer service to get the appropriate page format
          pageFormat: printerService.getPageFormat(),
          build: (context) {
            return pw.Column(
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
                  'ORDER #: $orderNumber',
                  style: pw.TextStyle(
                    fontWeight: pw.FontWeight.bold,
                    fontSize: 10,
                  ),
                ),
                pw.Text(
                  'Date: ${DateFormat('yyyy-MM-dd HH:mm').format(now)}',
                  style: const pw.TextStyle(fontSize: 10),
                ),
                pw.Text(
                  'Customer: ${widget.customerName ?? "Walk-in"}',
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
                  
                  return pw.Column(
                    children: [
                      pw.Row(
                        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Expanded(
                            flex: 3,
                            child: pw.Text(
                              item.product.productName,
                              style: const pw.TextStyle(fontSize: 9),
                            ),
                          ),
                          pw.Expanded(
                            flex: 1,
                            child: pw.Text(
                              '${item.quantity}${item.isSubUnit ? item.subUnitName != null ? " ${item.subUnitName!}" : "" : ""}',
                              style: const pw.TextStyle(fontSize: 9),
                              textAlign: pw.TextAlign.right,
                            ),
                          ),
                          pw.Expanded(
                            flex: 1,
                            child: pw.Text(
                              item.effectivePrice.toStringAsFixed(2),
                              style: const pw.TextStyle(fontSize: 9),
                              textAlign: pw.TextAlign.right,
                            ),
                          ),
                          pw.Expanded(
                            flex: 1,
                            child: pw.Text(
                              item.total.toStringAsFixed(2),
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
                        'TOTAL:',
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
                      widget.paymentMethod,
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
                      widget.customerName ?? 'Walk-in Customer',
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
            );
          },
        ),
      );

      // Use the printer service to print the PDF
      await printerService.printPdf(
        pdf: pdf,
        documentName: 'Receipt-${DateTime.now().millisecondsSinceEpoch}',
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
} 