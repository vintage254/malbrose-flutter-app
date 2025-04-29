import 'dart:io';
import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:intl/intl.dart';
import 'package:my_flutter_app/services/printer_service.dart';
import 'package:my_flutter_app/services/config_service.dart';
import 'package:my_flutter_app/services/database.dart';

class ReceiptService {
  static final ReceiptService instance = ReceiptService._init();
  
  ReceiptService._init();
  
  // Print a completed sales receipt
  Future<void> printSalesReceipt({
    required Map<String, dynamic> order,
    required List<Map<String, dynamic>> orderItems,
    required BuildContext context,
    bool isReprint = false,
  }) async {
    try {
      final pdf = pw.Document();
      final config = ConfigService.instance;
      final printerService = PrinterService.instance;
      
      // Get receipt number and order number
      final receiptNumber = order['receipt_number'] ?? order['id']?.toString() ?? 'Unknown';
      final orderNumber = order['order_number'] ?? 'Unknown';
      
      // Get customer information
      final customerName = order['customer_name'] ?? 'customer general';
      final customerId = order['customer_id'] as int?;
      
      // Get payment information
      final paymentMethod = order['payment_method'] ?? 'CASH';
      final totalAmount = (order['total_amount'] as num?)?.toDouble() ?? 0.0;
      final discountAmount = (order['discount_amount'] as num?)?.toDouble() ?? 0.0;
      
      // Calculate pending balance for current order (for credit payments)
      double? pendingOrderBalance;
      if (paymentMethod.toLowerCase().contains('credit')) {
        // For full credit payments
        if (paymentMethod == 'Credit') {
          pendingOrderBalance = totalAmount;
        }
        // For split payments with credit component (e.g., "Mobile: KSH 200.00, Credit: KSH 100.00")
        else if (paymentMethod.contains('Credit:')) {
          try {
            final parts = paymentMethod.split(',');
            for (final part in parts) {
              if (part.toLowerCase().contains('credit')) {
                final creditPart = part.trim();
                final amountStr = creditPart.split('KSH').last.trim();
                pendingOrderBalance = double.parse(amountStr);
                break;
              }
            }
          } catch (e) {
            debugPrint('Error parsing credit amount: $e');
          }
        }
      }
      
      // Get customer's total outstanding balance
      double totalOutstandingBalance = 0.0;
      if (customerId != null) {
        totalOutstandingBalance = await DatabaseService.instance.getCustomerTotalOutstandingBalance(customerId);
      }
      
      // Calculate VAT if enabled
      double vatAmount = 0.0;
      double netAmount = totalAmount;
      
      if (config.enableVat) {
        vatAmount = config.calculateVatFromGross(totalAmount);
        netAmount = config.calculateNetFromGross(totalAmount);
      }

      // Use consistent date format
      final dateFormatter = DateFormat('MM/dd/yyyy hh:mm a');
      final orderDate = DateTime.parse(order['created_at'] as String? ?? DateTime.now().toIso8601String());
      final formattedDate = dateFormatter.format(orderDate);
      
      // Create PDF page
      pdf.addPage(
        pw.Page(
          pageFormat: printerService.getPageFormat(),
          build: (context) {
            return pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.center,
              children: [
                // Date and Receipt Number
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text(
                      formattedDate,
                      style: const pw.TextStyle(fontSize: 8),
                    ),
                    pw.Text(
                      'Sales Receipt #$receiptNumber',
                      style: const pw.TextStyle(fontSize: 8),
                    ),
                    pw.Text(
                      'Workstation: ${order['workstation_id'] ?? '4'}',
                      style: const pw.TextStyle(fontSize: 8),
                    ),
                  ],
                ),
                pw.SizedBox(height: 5),
                pw.Text(
                  'Store: ${order['store_id'] ?? '1'}',
                  style: const pw.TextStyle(fontSize: 8),
                ),
                
                // REPRINTED label if applicable
                if (isReprint)
                  pw.Center(
                    child: pw.Text(
                      'REPRINTED',
                      style: pw.TextStyle(
                        fontSize: 10,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                  ),
                
                // Business Info Section
                pw.Text(
                  config.businessName,
                  style: pw.TextStyle(
                    fontSize: 12,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
                pw.Text(
                  config.businessAddress,
                  style: const pw.TextStyle(fontSize: 8),
                ),
                pw.Text(
                  'Pin No. ${order['pin_number'] ?? 'P051910588M'}',
                  style: const pw.TextStyle(fontSize: 8),
                ),
                pw.Text(
                  'Phone: ${config.businessPhone}',
                  style: const pw.TextStyle(fontSize: 8),
                ),
                
                // Customer Info
                pw.SizedBox(height: 5),
                pw.Row(
                  children: [
                    pw.Text(
                      'Bill To: ',
                      style: const pw.TextStyle(fontSize: 8),
                    ),
                    pw.Text(
                      customerName,
                      style: const pw.TextStyle(fontSize: 8),
                    ),
                  ],
                ),
                
                // Cashier Info (if enabled)
                if (config.showCashierName)
                  pw.Row(
                    children: [
                      pw.Text(
                        'Cashier: ',
                        style: const pw.TextStyle(fontSize: 8),
                      ),
                      pw.Text(
                        order['cashier_name'] ?? 'Unknown',
                        style: const pw.TextStyle(fontSize: 8),
                      ),
                    ],
                  ),
                
                // Order Items Section
                pw.SizedBox(height: 10),
                pw.Row(
                  children: [
                    pw.Expanded(
                      flex: 1,
                      child: pw.Text(
                        'Qty',
                        style: pw.TextStyle(
                          fontSize: 8,
                          fontWeight: pw.FontWeight.bold,
                        ),
                      ),
                    ),
                    pw.Expanded(
                      flex: 3,
                      child: pw.Text(
                        'Item Name',
                        style: pw.TextStyle(
                          fontSize: 8,
                          fontWeight: pw.FontWeight.bold,
                        ),
                      ),
                    ),
                    pw.Expanded(
                      flex: 1,
                      child: pw.Text(
                        'Price',
                        style: pw.TextStyle(
                          fontSize: 8,
                          fontWeight: pw.FontWeight.bold,
                        ),
                        textAlign: pw.TextAlign.right,
                      ),
                    ),
                    pw.Expanded(
                      flex: 1,
                      child: pw.Text(
                        'TOTAL',
                        style: pw.TextStyle(
                          fontSize: 8,
                          fontWeight: pw.FontWeight.bold,
                        ),
                        textAlign: pw.TextAlign.right,
                      ),
                    ),
                  ],
                ),
                pw.Divider(thickness: 1, height: 5),
                
                // Order Items
                pw.Column(
                  children: orderItems.map((item) {
                    final quantity = (item['quantity'] as num?)?.toInt() ?? 0;
                    final productName = item['product_name'] ?? 'Unknown';
                    final price = (item['selling_price'] as num?)?.toDouble() ?? 0.0;
                    final total = (item['total_amount'] as num?)?.toDouble() ?? 0.0;
                    
                    return pw.Row(
                      children: [
                        pw.Expanded(
                          flex: 1,
                          child: pw.Text(
                            quantity.toString(),
                            style: const pw.TextStyle(fontSize: 8),
                          ),
                        ),
                        pw.Expanded(
                          flex: 3,
                          child: pw.Text(
                            productName,
                            style: const pw.TextStyle(fontSize: 8),
                          ),
                        ),
                        pw.Expanded(
                          flex: 1,
                          child: pw.Text(
                            price.toStringAsFixed(2),
                            style: const pw.TextStyle(fontSize: 8),
                            textAlign: pw.TextAlign.right,
                          ),
                        ),
                        pw.Expanded(
                          flex: 1,
                          child: pw.Text(
                            total.toStringAsFixed(2),
                            style: const pw.TextStyle(fontSize: 8),
                            textAlign: pw.TextAlign.right,
                          ),
                        ),
                      ],
                    );
                  }).toList(),
                ),
                
                // Totals Section
                pw.Divider(height: 5),
                pw.SizedBox(height: 5),
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text(
                      'RECEIPT TOTAL:',
                      style: pw.TextStyle(
                        fontSize: 10,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                    pw.Text(
                      totalAmount.toStringAsFixed(2),
                      style: pw.TextStyle(
                        fontSize: 10,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                
                // Payment Info (fixed to avoid duplication)
                pw.SizedBox(height: 5),
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text(
                      '$paymentMethod:',
                      style: const pw.TextStyle(fontSize: 8),
                    ),
                    pw.Text(
                      totalAmount.toStringAsFixed(2),
                      style: const pw.TextStyle(fontSize: 8),
                    ),
                  ],
                ),
                
                // Deposit and Balance
                pw.SizedBox(height: 5),
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text(
                      'Total Deposit Taken:',
                      style: const pw.TextStyle(fontSize: 8),
                    ),
                    pw.Text(
                      '0.00',
                      style: const pw.TextStyle(fontSize: 8),
                    ),
                  ],
                ),
                
                // Current order pending balance (if applicable)
                if (pendingOrderBalance != null && pendingOrderBalance > 0)
                  pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Text(
                        'Current Order Balance:',
                        style: pw.TextStyle(
                          fontSize: 8,
                          fontWeight: pw.FontWeight.bold,
                          color: PdfColors.red,
                        ),
                      ),
                      pw.Text(
                        pendingOrderBalance.toStringAsFixed(2),
                        style: pw.TextStyle(
                          fontSize: 8,
                          fontWeight: pw.FontWeight.bold,
                          color: PdfColors.red,
                        ),
                      ),
                    ],
                  ),
                  
                // Customer's total outstanding balance (if applicable)
                if (customerId != null && totalOutstandingBalance > 0)
                  pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Text(
                        'Total Outstanding Balance:',
                        style: pw.TextStyle(
                          fontSize: 8,
                          fontWeight: pw.FontWeight.bold,
                          color: PdfColors.red,
                        ),
                      ),
                      pw.Text(
                        totalOutstandingBalance.toStringAsFixed(2),
                        style: pw.TextStyle(
                          fontSize: 8,
                          fontWeight: pw.FontWeight.bold,
                          color: PdfColors.red,
                        ),
                      ),
                    ],
                  ),
                
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text(
                      'Balance Outstanding:',
                      style: const pw.TextStyle(fontSize: 8),
                    ),
                    pw.Text(
                      '0.00',
                      style: const pw.TextStyle(fontSize: 8),
                    ),
                  ],
                ),
                
                // Discount
                if (discountAmount > 0)
                  pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Text(
                        'Total Sales Discounts:',
                        style: const pw.TextStyle(fontSize: 8),
                      ),
                      pw.Text(
                        discountAmount.toStringAsFixed(2),
                        style: const pw.TextStyle(fontSize: 8),
                      ),
                    ],
                  ),
                
                // VAT Information
                if (config.enableVat && config.showVatOnReceipt)
                  pw.Column(
                    children: [
                      pw.SizedBox(height: 10),
                      pw.Row(
                        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                        children: [
                          pw.Text(
                            'VAT (${config.vatRate}%):',
                            style: const pw.TextStyle(fontSize: 8),
                          ),
                          pw.Text(
                            vatAmount.toStringAsFixed(2),
                            style: const pw.TextStyle(fontSize: 8),
                          ),
                        ],
                      ),
                      pw.Row(
                        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                        children: [
                          pw.Text(
                            'Net Amount:',
                            style: const pw.TextStyle(fontSize: 8),
                          ),
                          pw.Text(
                            netAmount.toStringAsFixed(2),
                            style: const pw.TextStyle(fontSize: 8),
                          ),
                        ],
                      ),
                    ],
                  )
                else if (config.enableVat && !config.showVatOnReceipt)
                  pw.SizedBox(
                    height: 10,
                    child: pw.Center(
                      child: pw.Text(
                        'VAT prices included',
                        style: pw.TextStyle(
                          fontSize: 8,
                          fontStyle: pw.FontStyle.italic,
                        ),
                      ),
                    ),
                  ),
                
                // Order Reference
                pw.SizedBox(height: 10),
                pw.Text(
                  'From Sales Order #$orderNumber',
                  style: const pw.TextStyle(fontSize: 8),
                ),
                
                // Receipt Footer
                pw.SizedBox(height: 15),
                pw.Text(
                  config.receiptFooter,
                  style: pw.TextStyle(
                    fontSize: 8,
                    fontStyle: pw.FontStyle.italic,
                  ),
                  textAlign: pw.TextAlign.center,
                ),
                
                // Extra space for cutting
                pw.SizedBox(height: 20),
              ],
            );
          },
        ),
      );
      
      // Print the receipt
      await printerService.printPdf(
        pdf: pdf,
        documentName: 'Sales Receipt #$receiptNumber',
        context: context,
      );
    } catch (e) {
      debugPrint('Error printing sales receipt: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error printing sales receipt: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
  
  // Print an order receipt (pending/held/reverted)
  Future<void> printOrderReceipt({
    required Map<String, dynamic> order,
    required List<Map<String, dynamic>> orderItems,
    required String orderType, // "Pending", "Held", or "Reverted"
    required BuildContext context,
  }) async {
    try {
      final pdf = pw.Document();
      final config = ConfigService.instance;
      final printerService = PrinterService.instance;
      
      // Get order information
      final orderNumber = order['order_number'] ?? order['id']?.toString() ?? 'Unknown';
      
      // Use consistent date format
      final dateFormatter = DateFormat('dd-MMM-yy');
      final orderDate = DateTime.parse(order['created_at'] as String? ?? DateTime.now().toIso8601String());
      final formattedDate = dateFormatter.format(orderDate);
      
      // Get customer information
      final customerName = order['customer_name'] ?? 'customer general';
      final customerId = order['customer_id'] as int?;
      
      // Get customer's total outstanding balance
      double totalOutstandingBalance = 0.0;
      if (customerId != null) {
        totalOutstandingBalance = await DatabaseService.instance.getCustomerTotalOutstandingBalance(customerId);
      }
      
      // Order status
      final orderStatus = orderType == "Pending" ? "Open" : orderType;
      
      // Calculate totals
      final subtotal = (order['total_amount'] as num?)?.toDouble() ?? 0.0;
      final depositBalance = (order['deposit_amount'] as num?)?.toDouble() ?? 0.0;
      final balanceDue = subtotal - depositBalance;
      
      // Create PDF page
      pdf.addPage(
        pw.Page(
          pageFormat: printerService.getPageFormat(),
          build: (context) {
            return pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.center,
              children: [
                // Date and Order Number
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text(
                      formattedDate,
                      style: const pw.TextStyle(fontSize: 9),
                    ),
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.end,
                      children: [
                        pw.Text(
                          'Sales Order #$orderNumber',
                          style: const pw.TextStyle(fontSize: 9),
                        ),
                        pw.Text(
                          'Ordered: $formattedDate',
                          style: const pw.TextStyle(fontSize: 9),
                        ),
                        pw.Text(
                          'Associate: ${order['cashier_name'] ?? 'Unknown'}',
                          style: const pw.TextStyle(fontSize: 9),
                        ),
                      ],
                    ),
                  ],
                ),
                pw.SizedBox(height: 2),
                pw.Text(
                  'Store: ${order['store_id'] ?? '1'}',
                  style: const pw.TextStyle(fontSize: 9),
                ),
                
                // Business Info Section
                pw.Text(
                  config.businessName,
                  style: pw.TextStyle(
                    fontSize: 12,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
                pw.Text(
                  config.businessAddress,
                  style: const pw.TextStyle(fontSize: 9),
                ),
                pw.Text(
                  'Tel: ${config.businessPhone}',
                  style: const pw.TextStyle(fontSize: 9),
                ),
                pw.Text(
                  'PIN NO. ${order['pin_number'] ?? 'P051910588M'}',
                  style: const pw.TextStyle(fontSize: 9),
                ),
                
                // Customer Info
                pw.SizedBox(height: 5),
                pw.Row(
                  children: [
                    pw.Text(
                      'Bill To: ',
                      style: const pw.TextStyle(fontSize: 9),
                    ),
                    pw.Text(
                      customerName,
                      style: const pw.TextStyle(fontSize: 9),
                    ),
                  ],
                ),
                pw.Text(
                  'Order Status: $orderStatus',
                  style: const pw.TextStyle(fontSize: 9),
                ),
                
                // Order Items Section
                pw.SizedBox(height: 10),
                pw.Row(
                  children: [
                    pw.Expanded(
                      flex: 4,
                      child: pw.Text(
                        'Item Name',
                        style: pw.TextStyle(
                          fontSize: 9,
                          fontWeight: pw.FontWeight.bold,
                        ),
                      ),
                    ),
                    pw.Expanded(
                      flex: 1,
                      child: pw.Text(
                        'QTY',
                        style: pw.TextStyle(
                          fontSize: 9,
                          fontWeight: pw.FontWeight.bold,
                        ),
                        textAlign: pw.TextAlign.right,
                      ),
                    ),
                    pw.Expanded(
                      flex: 1,
                      child: pw.Text(
                        'Price',
                        style: pw.TextStyle(
                          fontSize: 9,
                          fontWeight: pw.FontWeight.bold,
                        ),
                        textAlign: pw.TextAlign.right,
                      ),
                    ),
                  ],
                ),
                pw.Divider(thickness: 1, height: 2),
                
                // Order Items
                pw.Column(
                  children: orderItems.map((item) {
                    final quantity = (item['quantity'] as num?)?.toInt() ?? 0;
                    final productName = item['product_name'] ?? 'Unknown';
                    final price = (item['selling_price'] as num?)?.toDouble() ?? 0.0;
                    
                    return pw.Row(
                      children: [
                        pw.Expanded(
                          flex: 4,
                          child: pw.Text(
                            productName,
                            style: const pw.TextStyle(fontSize: 9),
                          ),
                        ),
                        pw.Expanded(
                          flex: 1,
                          child: pw.Text(
                            quantity.toString(),
                            style: const pw.TextStyle(fontSize: 9),
                            textAlign: pw.TextAlign.right,
                          ),
                        ),
                        pw.Expanded(
                          flex: 1,
                          child: pw.Text(
                            price.toStringAsFixed(2),
                            style: const pw.TextStyle(fontSize: 9),
                            textAlign: pw.TextAlign.right,
                          ),
                        ),
                      ],
                    );
                  }).toList(),
                ),
                
                // Totals Section
                pw.SizedBox(height: 5),
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text(
                      'Subtotal:',
                      style: const pw.TextStyle(fontSize: 9),
                    ),
                    pw.Text(
                      subtotal.toStringAsFixed(2),
                      style: const pw.TextStyle(fontSize: 9),
                    ),
                  ],
                ),
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text(
                      'TOTAL:',
                      style: pw.TextStyle(
                        fontSize: 10,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                    pw.Text(
                      subtotal.toStringAsFixed(2),
                      style: pw.TextStyle(
                        fontSize: 10,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text(
                      'Deposit Balance:',
                      style: const pw.TextStyle(fontSize: 9),
                    ),
                    pw.Text(
                      depositBalance.toStringAsFixed(2),
                      style: const pw.TextStyle(fontSize: 9),
                    ),
                  ],
                ),
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text(
                      'Balance Due:',
                      style: const pw.TextStyle(fontSize: 9),
                    ),
                    pw.Text(
                      balanceDue.toStringAsFixed(2),
                      style: const pw.TextStyle(fontSize: 9),
                    ),
                  ],
                ),
                
                // Customer's total outstanding balance (if applicable)
                if (customerId != null && totalOutstandingBalance > 0)
                  pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Text(
                        'Total Outstanding Balance:',
                        style: pw.TextStyle(
                          fontSize: 9,
                          fontWeight: pw.FontWeight.bold,
                          color: PdfColors.red,
                        ),
                      ),
                      pw.Text(
                        totalOutstandingBalance.toStringAsFixed(2),
                        style: pw.TextStyle(
                          fontSize: 9,
                          fontWeight: pw.FontWeight.bold,
                          color: PdfColors.red,
                        ),
                      ),
                    ],
                  ),
                
                // Thank you message
                pw.SizedBox(height: 10),
                pw.Text(
                  'Thank you for your order!',
                  style: pw.TextStyle(
                    fontSize: 10,
                    fontStyle: pw.FontStyle.italic,
                  ),
                  textAlign: pw.TextAlign.center,
                ),
                
                // Extra space for cutting
                pw.SizedBox(height: 20),
              ],
            );
          },
        ),
      );
      
      // Print the order receipt
      await printerService.printPdf(
        pdf: pdf,
        documentName: 'Order #$orderNumber',
        context: context,
      );
    } catch (e) {
      debugPrint('Error printing order receipt: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error printing order receipt: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
} 