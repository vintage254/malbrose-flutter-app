import 'package:flutter/material.dart';
import 'package:my_flutter_app/const/constant.dart';
import 'package:my_flutter_app/models/cart_item_model.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:pdf/pdf.dart';
import 'package:intl/intl.dart';
import 'package:my_flutter_app/services/printer_service.dart';
import 'package:my_flutter_app/services/config_service.dart';
import 'package:provider/provider.dart';
import 'dart:io';

class OrderReceiptDialog extends StatefulWidget {
  final List<CartItem> items;
  final String customerName;
  final String? paymentMethod;
  final bool showPrintButton;
  final double? outstandingBalance;
  final double? creditAmount;

  const OrderReceiptDialog({
    Key? key,
    required this.items,
    required this.customerName,
    this.paymentMethod,
    this.showPrintButton = true,
    this.outstandingBalance,
    this.creditAmount,
  }) : super(key: key);

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
  final config = ConfigService.instance;

  @override
  void initState() {
    super.initState();
    _orderItems = widget.items;
    _selectedPaymentMethod = widget.paymentMethod ?? 'Cash';
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
            Text(config.businessName,
                style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: defaultPadding),
            Text('Date: ${DateFormat('yyyy-MM-dd HH:mm').format(DateTime.now())}'),
            if (widget.customerName != null && widget.customerName!.isNotEmpty)
              Text('Customer: ${widget.customerName}'),
            if (widget.outstandingBalance != null)
              Text('Outstanding Balance: ${widget.outstandingBalance?.toStringAsFixed(2) ?? "0.00"}'),
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
            if (widget.creditAmount != null && widget.creditAmount! > 0) ...[
              const Text('Current Order Balance:', style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Text('KSH ${widget.creditAmount!.toStringAsFixed(2)}'),
            ],
            
            // Outstanding balance
            if (widget.outstandingBalance != null && widget.outstandingBalance! > 0) ...[
              const SizedBox(height: 8),
              Text('KSH ${widget.outstandingBalance!.toStringAsFixed(2)}'),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Close'),
        ),
        if (widget.showPrintButton)
          ElevatedButton(
            onPressed: () => _printReceipt(),
            child: const Text('Print Receipt'),
          ),
      ],
    );
  }
  
  Future<void> _printReceipt() async {
    try {
      // Use ConfigService singleton instance directly instead of Provider
      final config = ConfigService.instance;
      final printerService = PrinterService.instance;
      
      // Calculate totals
      final totalAmount = _orderItems.fold<double>(
        0,
        (sum, item) => sum + item.total,
      );
      final vatAmount = 0.0; // Assuming vatAmount is not provided in the original code
      final subTotal = totalAmount - vatAmount;
      final netAmount = subTotal;
      
      // Create PDF document
      final pdf = pw.Document();
      
      // Add page
      pdf.addPage(
        pw.Page(
          pageFormat: printerService.getPageFormat(),
          margin: const pw.EdgeInsets.all(10),
          build: (context) {
            return pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.center,
              children: [
                // Company logo
                if (config.showBusinessLogo && config.businessLogo != null && config.businessLogo!.isNotEmpty)
                  pw.Container(
                    height: 60,
                    width: 200,
                    alignment: pw.Alignment.center,
                    margin: const pw.EdgeInsets.only(bottom: 10),
                    child: pw.Image(
                      pw.MemoryImage(File(config.businessLogo!).readAsBytesSync()),
                      fit: pw.BoxFit.contain,
                    ),
                  ),
                
                // Business name
                pw.Text(
                  config.businessName,
                    style: pw.TextStyle(
                    fontSize: 16,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
                
                // Business address
                pw.Text(
                  config.businessAddress,
                  style: const pw.TextStyle(fontSize: 12),
                ),
                
                // Phone and Email
                pw.Text(
                  'Tel: ${config.businessPhone}',
                  style: const pw.TextStyle(fontSize: 12),
                ),
                pw.Text(
                  'Email: ${config.businessEmail}',
                  style: const pw.TextStyle(fontSize: 12),
                ),
                
                // Receipt header
                pw.SizedBox(height: 8),
                pw.Text(
                  config.receiptHeader,
                  style: const pw.TextStyle(fontSize: 12),
                ),
                
                // SALES RECEIPT
                pw.SizedBox(height: 8),
                pw.Text(
                  'SALES RECEIPT',
                  style: pw.TextStyle(
                    fontWeight: pw.FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
                
                // Receipt details
                pw.Text('No: ${DateTime.now().millisecondsSinceEpoch}'),
                pw.Text(
                  'Date: ${DateFormat(config.dateTimeFormat.isNotEmpty ? config.dateTimeFormat : 'dd/MM/yyyy HH:mm').format(DateTime.now())}',
                ),
                
                // Show cashier name if enabled in settings
                if (config.showCashierName)
                  pw.Text('Cashier: admin'),
                
                // Customer info if available
                pw.Text('Customer: ${widget.customerName}'),
                
                // Items Table Header
                pw.SizedBox(height: 8),
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
                if (config.enableVat && config.showVatOnReceipt) ...[
                  pw.SizedBox(height: 5),
                  pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Expanded(
                        flex: 3,
                        child: pw.Text(
                          'VAT (${config.vatRate.toStringAsFixed(1)}%):',
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
                          '',
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
                
                // Payment information
                pw.SizedBox(height: 8),
                pw.Text('PAYMENT DETAILS:', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10)),
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text('Payment Mode:', style: const pw.TextStyle(fontSize: 9)),
                    pw.Text(widget.paymentMethod ?? _selectedPaymentMethod, style: const pw.TextStyle(fontSize: 9)),
                  ],
                ),
                pw.SizedBox(height: 4),
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text('Paid By:', style: const pw.TextStyle(fontSize: 9)),
                    pw.Text(widget.customerName, style: const pw.TextStyle(fontSize: 9)),
                  ],
                ),
                
                // Add credit amount if available
                if (widget.creditAmount != null && widget.creditAmount! > 0) ...[
                  pw.SizedBox(height: 4),
                  pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Text('Current Order Balance:', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9)),
                      pw.Text('KSH ${widget.creditAmount!.toStringAsFixed(2)}', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9)),
                    ],
                  ),
                ],
                
                // Add outstanding balance if available
                if (widget.outstandingBalance != null && widget.outstandingBalance! > 0) ...[
                  pw.SizedBox(height: 4),
                  pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Text('Total Outstanding Balance:', 
                        style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9, color: PdfColors.red),
                      ),
                      pw.Text('KSH ${widget.outstandingBalance!.toStringAsFixed(2)}', 
                        style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9, color: PdfColors.red),
                      ),
                    ],
                  ),
                ],
                
                // Footer Section
                pw.SizedBox(height: 10),
                pw.Center(
                  child: pw.Text(
                    config.receiptHeader,
                    style: pw.TextStyle(
                      fontSize: 10,
                      fontStyle: pw.FontStyle.italic,
                    ),
                  ),
                ),
                pw.Center(
                  child: pw.Text(
                    config.receiptFooter,
                    style: pw.TextStyle(
                      fontSize: 8,
                    ),
                  ),
                ),
                pw.SizedBox(height: 5),
                
                // Add "Goods once sold are not returnable" disclaimer when enabled
                if (config.showNoReturnsPolicy)
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