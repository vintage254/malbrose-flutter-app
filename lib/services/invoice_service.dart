import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:my_flutter_app/models/invoice_model.dart';
import 'package:my_flutter_app/models/customer_model.dart';
import 'package:my_flutter_app/const/constant.dart';
import 'package:intl/intl.dart';
import 'dart:io';
import 'dart:typed_data';
import 'package:my_flutter_app/models/order_model.dart';
import 'package:my_flutter_app/services/database.dart';

class InvoiceService {
  static final InvoiceService instance = InvoiceService._internal();
  InvoiceService._internal();

  Future<void> generateAndPrintInvoice(Invoice invoice, Customer customer) async {
    try {
      if (invoice.completedItems == null && invoice.pendingItems == null) {
        throw Exception('No items found in invoice');
      }

      final pdf = pw.Document();
      final List<pw.Widget> children = [];
      
      // Add header and customer info
      children.addAll([
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  companyName,
                  style: pw.TextStyle(
                    fontSize: 24,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
                pw.Text('Phone: $companyPhone'),
                pw.Text('Email: $companyEmail'),
                pw.Text('Address: $companyAddress'),
              ],
            ),
            pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.end,
              children: [
                pw.Text(
                  'INVOICE',
                  style: pw.TextStyle(
                    fontSize: 24,
                    fontWeight: pw.FontWeight.bold,
                    color: PdfColors.orange,
                  ),
                ),
                pw.Text('Invoice #: ${invoice.invoiceNumber}'),
                pw.Text('Date: ${DateFormat('MMM dd, yyyy').format(invoice.createdAt)}'),
                if (invoice.dueDate != null)
                  pw.Text('Due Date: ${DateFormat('MMM dd, yyyy').format(invoice.dueDate!)}'),
              ],
            ),
          ],
        ),
        pw.SizedBox(height: 40),

        // Customer Information
        pw.Container(
          padding: const pw.EdgeInsets.all(10),
          decoration: pw.BoxDecoration(
            border: pw.Border.all(color: PdfColors.grey),
            borderRadius: const pw.BorderRadius.all(pw.Radius.circular(5)),
          ),
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(
                'Bill To:',
                style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
              ),
              pw.SizedBox(height: 5),
              pw.Text(customer.name, style: const pw.TextStyle(fontSize: 12)),
              if (customer.email != null) 
                pw.Text(customer.email!, style: const pw.TextStyle(fontSize: 12)),
              if (customer.phone != null) 
                pw.Text(customer.phone!, style: const pw.TextStyle(fontSize: 12)),
              if (customer.address != null) 
                pw.Text(customer.address!, style: const pw.TextStyle(fontSize: 12)),
            ],
          ),
        ),
        pw.SizedBox(height: 20),
      ]);

      // Add items tables
      if ((invoice.completedItems != null && invoice.completedItems!.isNotEmpty) ||
          (invoice.pendingItems != null && invoice.pendingItems!.isNotEmpty)) {
        
        // Add completed items table if exists
        if (invoice.completedItems != null && invoice.completedItems!.isNotEmpty) {
          children.addAll([
            pw.Text(
              'Completed Orders',
              style: pw.TextStyle(
                fontWeight: pw.FontWeight.bold,
                fontSize: 14,
                color: PdfColors.blue900,
              ),
            ),
            pw.SizedBox(height: 10),
            pw.Table.fromTextArray(
              headers: ['Order #', 'Product', 'Quantity', 'Unit Price', 'Total'],
              data: invoice.completedItems!.map((item) => [
                item.orderId.toString(),
                item.productName,
                '${item.quantity} ${item.isSubUnit ? (item.subUnitName ?? "pieces") : "units"}',
                'KSH ${item.sellingPrice.toStringAsFixed(2)}',
                'KSH ${item.totalAmount.toStringAsFixed(2)}',
              ]).toList(),
              border: pw.TableBorder.all(color: PdfColors.grey300),
              headerStyle: pw.TextStyle(
                fontWeight: pw.FontWeight.bold,
                color: PdfColors.white,
              ),
              headerDecoration: const pw.BoxDecoration(
                color: PdfColors.orange,
              ),
              cellHeight: 30,
              cellAlignments: {
                0: pw.Alignment.centerLeft,
                1: pw.Alignment.centerLeft,
                2: pw.Alignment.center,
                3: pw.Alignment.centerRight,
                4: pw.Alignment.centerRight,
              },
              cellStyle: const pw.TextStyle(
                fontSize: 10,
              ),
            ),
            pw.SizedBox(height: 20),
          ]);
        }

        // Add pending items table if exists
        if (invoice.pendingItems != null && invoice.pendingItems!.isNotEmpty) {
          children.addAll([
            pw.Text(
              'Pending Orders',
              style: pw.TextStyle(
                fontWeight: pw.FontWeight.bold,
                fontSize: 14,
                color: PdfColors.orange,
              ),
            ),
            pw.SizedBox(height: 10),
            pw.Table.fromTextArray(
              headers: ['Order #', 'Product', 'Quantity', 'Unit Price', 'Total'],
              data: invoice.pendingItems!.map((item) => [
                item.orderId.toString(),
                item.productName,
                '${item.quantity} ${item.isSubUnit ? (item.subUnitName ?? "pieces") : "units"}',
                'KSH ${item.sellingPrice.toStringAsFixed(2)}',
                'KSH ${item.totalAmount.toStringAsFixed(2)}',
              ]).toList(),
              border: pw.TableBorder.all(color: PdfColors.grey300),
              headerStyle: pw.TextStyle(
                fontWeight: pw.FontWeight.bold,
                color: PdfColors.white,
              ),
              headerDecoration: const pw.BoxDecoration(
                color: PdfColors.orange,
              ),
              cellHeight: 30,
              cellAlignments: {
                0: pw.Alignment.centerLeft,
                1: pw.Alignment.centerLeft,
                2: pw.Alignment.center,
                3: pw.Alignment.centerRight,
                4: pw.Alignment.centerRight,
              },
              cellStyle: const pw.TextStyle(
                fontSize: 10,
              ),
            ),
          ]);
        }
      }

      // Add the page with all children
      pdf.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4,
          build: (context) => pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: children,
          ),
        ),
      );

      // Print the document
      await Printing.layoutPdf(
        onLayout: (format) async => pdf.save(),
      );
    } catch (e) {
      print('Error generating PDF: $e');
      rethrow;
    }
  }

  static Future<Uint8List> generateInvoicePdf(Invoice invoice, Customer customer) async {
    final pdf = pw.Document();
    final logo = await _getLogoImage();
    final font = await PdfGoogleFonts.nunitoRegular();
    final boldFont = await PdfGoogleFonts.nunitoBold();

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        build: (pw.Context context) {
          return pw.Container(
            padding: const pw.EdgeInsets.all(40),
            decoration: pw.BoxDecoration(
              borderRadius: pw.BorderRadius.circular(15),
              border: pw.Border.all(
                color: PdfColors.grey300,
                width: 2,
              ),
            ),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                // Header
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        if (logo != null)
                          pw.Image(logo, width: 120),
                        pw.SizedBox(height: 10),
                        pw.Text(
                          'MALBROSE ENTERPRISES',
                          style: pw.TextStyle(
                            font: boldFont,
                            fontSize: 24,
                            color: PdfColors.blue900,
                          ),
                        ),
                        pw.Text(
                          'P.O. Box 123-00100\nNairobi, Kenya',
                          style: pw.TextStyle(
                            font: font,
                            fontSize: 12,
                            color: PdfColors.grey700,
                          ),
                        ),
                      ],
                    ),
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.end,
                      children: [
                        pw.Text(
                          'INVOICE',
                          style: pw.TextStyle(
                            font: boldFont,
                            fontSize: 32,
                            color: PdfColors.blue900,
                          ),
                        ),
                        pw.Text(
                          '#${invoice.invoiceNumber}',
                          style: pw.TextStyle(
                            font: boldFont,
                            fontSize: 16,
                            color: PdfColors.grey700,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),

                pw.SizedBox(height: 40),

                // Customer Information
                pw.Container(
                  padding: const pw.EdgeInsets.all(15),
                  decoration: pw.BoxDecoration(
                    color: PdfColors.grey100,
                    borderRadius: pw.BorderRadius.circular(8),
                  ),
                  child: pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Text(
                            'BILL TO',
                            style: pw.TextStyle(
                              font: boldFont,
                              fontSize: 12,
                              color: PdfColors.grey700,
                            ),
                          ),
                          pw.SizedBox(height: 8),
                          pw.Text(
                            customer.name,
                            style: pw.TextStyle(
                              font: boldFont,
                              fontSize: 16,
                              color: PdfColors.blue900,
                            ),
                          ),
                          if (customer.address != null)
                            pw.Text(
                              customer.address!,
                              style: pw.TextStyle(
                                font: font,
                                fontSize: 12,
                                color: PdfColors.grey700,
                              ),
                            ),
                        ],
                      ),
                      pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.end,
                        children: [
                          pw.Row(
                            children: [
                              pw.Text(
                                'Invoice Date: ',
                                style: pw.TextStyle(
                                  font: font,
                                  fontSize: 12,
                                  color: PdfColors.grey700,
                                ),
                              ),
                              pw.Text(
                                DateFormat('MMM dd, yyyy').format(invoice.createdAt),
                                style: pw.TextStyle(
                                  font: boldFont,
                                  fontSize: 12,
                                  color: PdfColors.blue900,
                                ),
                              ),
                            ],
                          ),
                          pw.SizedBox(height: 8),
                          pw.Row(
                            children: [
                              pw.Text(
                                'Due Date: ',
                                style: pw.TextStyle(
                                  font: font,
                                  fontSize: 12,
                                  color: PdfColors.grey700,
                                ),
                              ),
                              pw.Text(
                                DateFormat('MMM dd, yyyy').format(invoice.dueDate!),
                                style: pw.TextStyle(
                                  font: boldFont,
                                  fontSize: 12,
                                  color: PdfColors.blue900,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                pw.SizedBox(height: 30),

                // Items Table
                pw.Table(
                  border: pw.TableBorder.all(
                    color: PdfColors.grey300,
                    width: 1,
                  ),
                  columnWidths: {
                    0: const pw.FlexColumnWidth(4),
                    1: const pw.FlexColumnWidth(2),
                    2: const pw.FlexColumnWidth(2),
                    3: const pw.FlexColumnWidth(2),
                  },
                  children: [
                    // Table Header
                    pw.TableRow(
                      decoration: pw.BoxDecoration(
                        color: PdfColors.blue900,
                      ),
                      children: [
                        _buildTableCell('Product', font, isHeader: true),
                        _buildTableCell('Quantity', font, isHeader: true),
                        _buildTableCell('Unit Price', font, isHeader: true),
                        _buildTableCell('Total', font, isHeader: true),
                      ],
                    ),
                    // Table Items
                    if (invoice.completedItems != null)
                      ...invoice.completedItems!.map((item) => pw.TableRow(
                        children: [
                          _buildTableCell(item.productName, font),
                          _buildTableCell(
                            item.quantity.toString() + 
                            (item.isSubUnit && item.subUnitName != null 
                                ? ' ${item.subUnitName}'
                                : ''),
                            font,
                          ),
                          _buildTableCell(
                            'KSH ${item.adjustedPrice.toStringAsFixed(2)}',
                            font,
                          ),
                          _buildTableCell(
                            'KSH ${item.totalAmount.toStringAsFixed(2)}',
                            font,
                          ),
                        ],
                      )),
                    if (invoice.pendingItems != null)
                      ...invoice.pendingItems!.map((item) => pw.TableRow(
                        children: [
                          _buildTableCell(item.productName, font),
                          _buildTableCell(
                            item.quantity.toString() + 
                            (item.isSubUnit && item.subUnitName != null 
                                ? ' ${item.subUnitName}'
                                : ''),
                            font,
                          ),
                          _buildTableCell(
                            'KSH ${item.adjustedPrice.toStringAsFixed(2)}',
                            font,
                          ),
                          _buildTableCell(
                            'KSH ${item.totalAmount.toStringAsFixed(2)}',
                            font,
                          ),
                        ],
                      )),
                  ],
                ),

                pw.SizedBox(height: 30),

                // Summary
                pw.Container(
                  alignment: pw.Alignment.centerRight,
                  child: pw.Container(
                    width: 200,
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.stretch,
                      children: [
                        _buildSummaryRow('Subtotal:', invoice.totalAmount, font, boldFont),
                        pw.SizedBox(height: 5),
                        _buildSummaryRow('VAT (16%):', invoice.totalAmount * 0.16, font, boldFont),
                        pw.SizedBox(height: 5),
                        pw.Divider(color: PdfColors.grey300),
                        _buildSummaryRow(
                          'Total:',
                          invoice.totalAmount * 1.16,
                          font,
                          boldFont,
                          isTotal: true,
                        ),
                      ],
                    ),
                  ),
                ),

                pw.Spacer(),

                // Footer
                pw.Container(
                  padding: const pw.EdgeInsets.symmetric(vertical: 30),
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.center,
                    children: [
                      pw.Text(
                        'Thank you for your business!',
                        style: pw.TextStyle(
                          font: boldFont,
                          fontSize: 14,
                          color: PdfColors.blue900,
                        ),
                      ),
                      pw.SizedBox(height: 10),
                      pw.Text(
                        'For any questions about this invoice, please contact:',
                        style: pw.TextStyle(
                          font: font,
                          fontSize: 12,
                          color: PdfColors.grey700,
                        ),
                      ),
                      pw.Text(
                        'info@malbrose.com | +254 700 000 000',
                        style: pw.TextStyle(
                          font: boldFont,
                          fontSize: 12,
                          color: PdfColors.blue900,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );

    return pdf.save();
  }

  static pw.Widget _buildTableCell(
    String text,
    pw.Font font, {
    bool isHeader = false,
  }) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(10),
      alignment: text.contains('KSH') 
          ? pw.Alignment.centerRight 
          : pw.Alignment.centerLeft,
      child: pw.Text(
        text,
        style: pw.TextStyle(
          font: font,
          color: isHeader ? PdfColors.white : PdfColors.black,
          fontSize: 12,
        ),
      ),
    );
  }

  static pw.Widget _buildSummaryRow(
    String label,
    double amount,
    pw.Font font,
    pw.Font boldFont, {
    bool isTotal = false,
  }) {
    return pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      children: [
        pw.Text(
          label,
          style: pw.TextStyle(
            font: isTotal ? boldFont : font,
            fontSize: isTotal ? 14 : 12,
            color: isTotal ? PdfColors.blue900 : PdfColors.grey700,
          ),
        ),
        pw.Text(
          'KSH ${amount.toStringAsFixed(2)}',
          style: pw.TextStyle(
            font: isTotal ? boldFont : font,
            fontSize: isTotal ? 14 : 12,
            color: isTotal ? PdfColors.blue900 : PdfColors.grey700,
          ),
        ),
      ],
    );
  }

  static Future<pw.ImageProvider?> _getLogoImage() async {
    try {
      final logoFile = File('assets/images/logo.png');
      if (await logoFile.exists()) {
        final bytes = await logoFile.readAsBytes();
        return pw.MemoryImage(bytes);
      }
      return null;
    } catch (e) {
      print('Error loading logo: $e');
      return null;
    }
  }

  Future<Invoice> generateInvoice(int customerId) async {
    final db = await DatabaseService.instance.database;
    
    return await db.transaction((txn) async {
      // Get customer details
      final customerResult = await txn.query(
        'customers',
        where: 'id = ?',
        whereArgs: [customerId],
        limit: 1,
      );
      
      if (customerResult.isEmpty) {
        throw Exception('Customer not found');
      }
      
      final customer = customerResult.first;
      
      // Get all orders for the customer
      final orders = await txn.rawQuery('''
        SELECT 
          o.*,
          oi.id as item_id,
          oi.product_id,
          oi.quantity,
          oi.unit_price,
          oi.selling_price,
          oi.adjusted_price,
          oi.total_amount as item_total,
          oi.is_sub_unit,
          oi.sub_unit_name,
          p.product_name
        FROM orders o
        LEFT JOIN order_items oi ON o.id = oi.order_id
        LEFT JOIN products p ON oi.product_id = p.id
        WHERE o.customer_id = ?
        ORDER BY o.created_at DESC
      ''', [customerId]);

      // Separate completed and pending orders
      final completedItems = <OrderItem>[];
      final pendingItems = <OrderItem>[];
      double completedAmount = 0;
      double pendingAmount = 0;

      for (final order in orders) {
        final item = OrderItem.fromMap(order);
        if (order['status'] == 'COMPLETED') {
          completedItems.add(item);
          completedAmount += item.totalAmount;
        } else {
          pendingItems.add(item);
          pendingAmount += item.totalAmount;
        }
      }

      final invoice = Invoice(
        invoiceNumber: 'INV-${DateTime.now().millisecondsSinceEpoch}',
        customerId: customerId,
        customerName: customer['name'] as String,
        totalAmount: completedAmount + pendingAmount,
        completedAmount: completedAmount,
        pendingAmount: pendingAmount,
        status: 'PENDING',
        paymentStatus: 'PENDING',
        createdAt: DateTime.now(),
        dueDate: DateTime.now().add(const Duration(days: 30)),
        completedItems: completedItems,
        pendingItems: pendingItems,
      );

      // Save the invoice
      final invoiceId = await txn.insert('invoices', invoice.toMap());
      return invoice.copyWith(id: invoiceId);
    });
  }

  Future<List<Invoice>> getCustomerInvoices(int customerId) async {
    final db = await DatabaseService.instance.database;
    final invoices = await db.query(
      'invoices',
      where: 'customer_id = ?',
      whereArgs: [customerId],
      orderBy: 'created_at DESC',
    );

    return invoices.map((map) => Invoice.fromMap(map)).toList();
  }

  Future<String> generateInvoiceNumber() async {
    final now = DateTime.now();
    final prefix = 'INV';
    final date = DateFormat('yyyyMMdd').format(now);
    
    // Get the last invoice number for today
    final db = await DatabaseService.instance.database;
    final result = await db.rawQuery('''
      SELECT invoice_number 
      FROM invoices 
      WHERE date(created_at) = date(?)
      ORDER BY invoice_number DESC 
      LIMIT 1
    ''', [now.toIso8601String()]);

    int sequence = 1;
    if (result.isNotEmpty) {
      final lastNumber = result.first['invoice_number'] as String;
      final lastSequence = int.tryParse(lastNumber.split('-').last) ?? 0;
      sequence = lastSequence + 1;
    }

    return '$prefix-$date-${sequence.toString().padLeft(4, '0')}';
  }
} 