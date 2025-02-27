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
import 'package:sqflite/sqflite.dart';

class InvoiceService {
  static final InvoiceService instance = InvoiceService._internal();
  InvoiceService._internal();

  Future<void> generateAndPrintInvoice(Invoice invoice, Customer customer) async {
    try {
      final pdf = await generateInvoicePdf(invoice, customer);
      await Printing.layoutPdf(onLayout: (format) async => pdf);
    } catch (e) {
      print('Error generating invoice PDF: $e');
      rethrow;
    }
  }

  static Future<Uint8List> generateInvoicePdf(Invoice invoice, Customer customer) async {
    final pdf = pw.Document();
    final logo = await _getLogoImage();
    
    // Use Roboto font which has better Unicode support
    final font = await PdfGoogleFonts.robotoRegular();
    final boldFont = await PdfGoogleFonts.robotoBold();

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        theme: pw.ThemeData.withFont(
          base: font,
          bold: boldFont,
        ),
        build: (context) {
          final List<pw.Widget> children = [];
          
          children.addAll([
            _buildHeader(invoice, logo, font, boldFont),
            pw.SizedBox(height: 40),
            _buildCustomerInfo(customer, font, boldFont),
            pw.SizedBox(height: 20),
          ]);

          if (invoice.hasCompletedItems) {
            children.addAll([
              _buildSectionTitle('Completed Orders', boldFont, PdfColors.green700),
              pw.SizedBox(height: 10),
              _buildItemsTable(invoice.completedItems!, font),
              pw.SizedBox(height: 20),
            ]);
          }

          if (invoice.hasPendingItems) {
            children.addAll([
              _buildSectionTitle('Pending Orders', boldFont, PdfColors.orange700),
              pw.SizedBox(height: 10),
              _buildItemsTable(invoice.pendingItems!, font),
              pw.SizedBox(height: 20),
            ]);
          }

          children.addAll([
            _buildSummaryRow('Subtotal:', invoice.totalAmount, font, boldFont),
            _buildSummaryRow('VAT (16%):', invoice.totalAmount * 0.16, font, boldFont),
            _buildSummaryRow(
              'Total Amount:',
              invoice.totalAmount * 1.16,
              font,
              boldFont,
              isTotal: true,
            ),
            _buildFooter(font, boldFont),
          ]);

          return children;
        },
      ),
    );

    return pdf.save();
  }

  static pw.Widget _buildHeader(
    Invoice invoice,
    pw.ImageProvider? logo,
    pw.Font font,
    pw.Font boldFont,
  ) {
    return pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      children: [
        pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            if (logo != null) pw.Image(logo, width: 120),
            pw.SizedBox(height: 10),
            pw.Text(
              companyName,
              style: pw.TextStyle(
                font: boldFont,
                fontSize: 24,
                color: PdfColors.blue900,
              ),
            ),
            _buildText('Phone: $companyPhone', font),
            _buildText('Email: $companyEmail', font),
            _buildText('Address: $companyAddress', font),
          ],
        ),
        pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.end,
          children: [
            pw.Text(
              'INVOICE',
              style: pw.TextStyle(
                font: boldFont,
                fontSize: 24,
                color: PdfColors.orange,
              ),
            ),
            _buildText('Invoice #: ${invoice.invoiceNumber}', font),
            _buildText(
              'Date: ${DateFormat('MMM dd, yyyy').format(invoice.createdAt)}',
              font,
            ),
            if (invoice.dueDate != null)
              _buildText(
                'Due Date: ${DateFormat('MMM dd, yyyy').format(invoice.dueDate!)}',
                font,
              ),
          ],
        ),
      ],
    );
  }

  static pw.Widget _buildText(String text, pw.Font font) {
    return pw.Text(text, style: pw.TextStyle(font: font));
  }

  static pw.Widget _buildCustomerInfo(Customer customer, pw.Font font, pw.Font boldFont) {
    return pw.Container(
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
    );
  }

  static pw.Widget _buildSectionTitle(String title, pw.Font boldFont, PdfColor color) {
    return pw.Text(
      title,
      style: pw.TextStyle(
        font: boldFont,
        fontSize: 14,
        color: color,
        fontWeight: pw.FontWeight.bold,
      ),
    );
  }

  static pw.Widget _buildItemsTable(List<OrderItem> items, pw.Font font) {
    return pw.Table(
      border: pw.TableBorder.all(color: PdfColors.grey300),
      columnWidths: {
        0: const pw.FlexColumnWidth(4),
        1: const pw.FlexColumnWidth(2),
        2: const pw.FlexColumnWidth(2),
        3: const pw.FlexColumnWidth(2),
      },
      children: [
        // Table Header
        _buildTableHeader(font),
        // Table Items
        ...items.map((item) => _buildTableRow(item, font)),
      ],
    );
  }

  static pw.TableRow _buildTableHeader(pw.Font font) {
    return pw.TableRow(
      decoration: pw.BoxDecoration(color: PdfColors.blue900),
      children: [
        _buildTableCell('Product', font, isHeader: true),
        _buildTableCell('Quantity', font, isHeader: true),
        _buildTableCell('Unit Price', font, isHeader: true),
        _buildTableCell('Total', font, isHeader: true),
      ],
    );
  }

  static pw.TableRow _buildTableRow(OrderItem item, pw.Font font) {
    return pw.TableRow(
      children: [
        _buildTableCell(item.displayName, font),
        _buildTableCell(
          '${item.quantity}${item.isSubUnit ? " ${item.subUnitName ?? 'pieces'}" : ""}', 
          font
        ),
        _buildTableCell('KSH ${item.effectivePrice.toStringAsFixed(2)}', font),
        _buildTableCell('KSH ${item.totalAmount.toStringAsFixed(2)}', font),
      ],
    );
  }

  static pw.Widget _buildTableCell(
    String text,
    pw.Font font, {
    bool isHeader = false,
  }) {
    return pw.Padding(
      padding: const pw.EdgeInsets.all(8),
      child: pw.Text(
        text,
        style: pw.TextStyle(
          font: font,
          color: isHeader ? PdfColors.white : PdfColors.black,
          fontWeight: isHeader ? pw.FontWeight.bold : pw.FontWeight.normal,
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
          ),
        ),
        pw.Text(
          'KSH ${amount.toStringAsFixed(2)}',
          style: pw.TextStyle(
            font: isTotal ? boldFont : font,
            fontSize: isTotal ? 14 : 12,
          ),
        ),
      ],
    );
  }

  static pw.Widget _buildFooter(pw.Font font, pw.Font boldFont) {
    return pw.Container(
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
    );
  }

  Future<Invoice> generateInvoice(
    int customerId, {
    DateTime? startDate,
    DateTime? endDate,
    Transaction? txn
  }) async {
    if (txn != null) {
      return await _generateInvoiceWithExecutor(
        customerId, 
        txn,
        startDate: startDate,
        endDate: endDate,
      );
    }
    // If no transaction provided, create one
    return await DatabaseService.instance.withTransaction((transaction) async {
      return await _generateInvoiceWithExecutor(
        customerId, 
        transaction,
        startDate: startDate,
        endDate: endDate,
      );
    });
  }

  Future<Invoice> _generateInvoiceWithExecutor(
    int customerId, 
    DatabaseExecutor executor, {
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    try {
      final customerResult = await executor.query(
        'customers',
        where: 'id = ?',
        whereArgs: [customerId],
        limit: 1,
      );
      
      if (customerResult.isEmpty) {
        throw Exception('Customer not found');
      }
      
      final customer = customerResult.first;
      
      final orders = await DatabaseService.instance.getOrdersByCustomerId(
        customerId,
        startDate: startDate,
        endDate: endDate,
        executor: executor,
      );

      if (orders.isEmpty) {
        throw Exception('No orders found for this customer in the selected date range');
      }

      double completedAmount = 0;
      double pendingAmount = 0;
      final completedItems = <OrderItem>[];
      final pendingItems = <OrderItem>[];

      for (final order in orders) {
        try {
          final orderItems = await DatabaseService.instance.getOrderItems(
            order['order_id'] as int,
            executor: executor,
          );

          for (final itemData in orderItems) {
            final item = OrderItem.fromMap(itemData);
            final isSubUnit = itemData['is_sub_unit'] == 1;
            final subUnitPrice = (itemData['sub_unit_price'] as num?)?.toDouble();
            
            final actualPrice = isSubUnit && subUnitPrice != null ? 
                subUnitPrice : item.sellingPrice;
            
            final totalAmount = actualPrice * item.quantity;

            if (order['status'] == 'COMPLETED') {
              completedItems.add(item);
              completedAmount += totalAmount;
            } else {
              pendingItems.add(item);
              pendingAmount += totalAmount;
            }
          }
        } catch (e) {
          print('Error processing order item: $e');
          print('Order data: $order');
          continue;
        }
      }

      if (completedItems.isEmpty && pendingItems.isEmpty) {
        throw Exception('No valid items found for invoice');
      }

      // Calculate invoice status based on items
      String invoiceStatus;
      if (completedItems.isEmpty) {
        invoiceStatus = 'PENDING';
      } else if (pendingItems.isEmpty) {
        invoiceStatus = 'COMPLETED';
      } else {
        invoiceStatus = 'PARTIAL';
      }

      final invoiceNumber = await _generateInvoiceNumber(executor);
      
      return Invoice(
        invoiceNumber: invoiceNumber,
        customerId: customerId,
        customerName: customer['name'] as String? ?? 'Unknown Customer',
        totalAmount: completedAmount + pendingAmount,
        completedAmount: completedAmount,
        pendingAmount: pendingAmount,
        status: invoiceStatus,
        paymentStatus: 'PENDING',
        createdAt: DateTime.now(),
        dueDate: DateTime.now().add(const Duration(days: 30)),
        completedItems: completedItems,
        pendingItems: pendingItems,
      );
    } catch (e) {
      print('Error generating invoice: $e');
      rethrow;
    }
  }

  Future<String> _generateInvoiceNumber(DatabaseExecutor executor) async {
    final now = DateTime.now();
    final prefix = 'INV';
    final date = DateFormat('yyyyMMdd').format(now);
    
    final result = await executor.rawQuery('''
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

  Future<List<Invoice>> getCustomerInvoices(int customerId, {Transaction? txn}) async {
    if (txn != null) {
      return await _getCustomerInvoicesWithExecutor(customerId, txn);
    }
    // If no transaction provided, create one
    return await DatabaseService.instance.withTransaction((transaction) async {
      return await _getCustomerInvoicesWithExecutor(customerId, transaction);
    });
  }

  Future<List<Invoice>> _getCustomerInvoicesWithExecutor(
    int customerId, 
    DatabaseExecutor executor
  ) async {
    final invoices = await executor.query(
      'invoices',
      where: 'customer_id = ?',
      whereArgs: [customerId],
      orderBy: 'created_at DESC',
    );

    final List<Invoice> result = [];
    
    for (final invoiceMap in invoices) {
      final invoice = Invoice.fromMap(invoiceMap);
      
      // Load invoice items
      final items = await executor.rawQuery('''
        SELECT 
          ii.*,
          p.product_name,
          p.buying_price,
          p.sub_unit_quantity,
          p.sub_unit_price
        FROM invoice_items ii
        JOIN products p ON ii.product_id = p.id
        WHERE ii.invoice_id = ?
        ORDER BY ii.id
      ''', [invoice.id]);

      final completedItems = <OrderItem>[];
      final pendingItems = <OrderItem>[];

      for (final item in items) {
        final orderItem = OrderItem(
          id: item['id'] as int?,
          orderId: item['order_id'] as int,
          productId: item['product_id'] as int,
          quantity: item['quantity'] as int,
          unitPrice: (item['unit_price'] as num).toDouble(),
          sellingPrice: (item['selling_price'] as num).toDouble(),
          adjustedPrice: (item['adjusted_price'] as num?)?.toDouble() ?? 
                        (item['selling_price'] as num).toDouble(),
          totalAmount: (item['total_amount'] as num).toDouble(),
          productName: item['product_name'] as String,
          isSubUnit: (item['is_sub_unit'] as int?) == 1,
          subUnitName: item['sub_unit_name'] as String?,
        );

        if (item['status'] == 'COMPLETED') {
          completedItems.add(orderItem);
        } else {
          pendingItems.add(orderItem);
        }
      }

      result.add(invoice.copyWith(
        completedItems: completedItems,
        pendingItems: pendingItems,
      ));
    }

    return result;
  }

  Future<Invoice> createInvoiceWithItems(Invoice invoice, {Transaction? txn}) async {
    if (txn != null) {
      return await _createInvoiceWithExecutor(invoice, txn);
    }
    // If no transaction provided, create one
    return await DatabaseService.instance.withTransaction((transaction) async {
      return await _createInvoiceWithExecutor(invoice, transaction);
    });
  }

  Future<Invoice> _createInvoiceWithExecutor(Invoice invoice, DatabaseExecutor executor) async {
    try {
      // Insert invoice with payment status
      final Map<String, dynamic> invoiceMap = invoice.toMap();
      
      // Ensure payment_status is set
      if (!invoiceMap.containsKey('payment_status')) {
        invoiceMap['payment_status'] = 'PENDING';
      }

      final invoiceId = await executor.insert(
        DatabaseService.tableInvoices, 
        invoiceMap
      );
      
      // Process items...
      if (invoice.hasCompletedItems) {
        await _processInvoiceItems(
          executor,
          invoiceId,
          invoice.completedItems!,
          'COMPLETED'
        );
      }

      if (invoice.hasPendingItems) {
        await _processInvoiceItems(
          executor,
          invoiceId,
          invoice.pendingItems!,
          'PENDING'
        );
      }

      return invoice.copyWith(id: invoiceId);
    } catch (e) {
      print('Error creating invoice: $e');
      rethrow;
    }
  }

  Future<void> _processInvoiceItems(
    DatabaseExecutor executor,
    int invoiceId,
    List<OrderItem> items,
    String status,
  ) async {
    for (var item in items) {
      await executor.insert(
        DatabaseService.tableInvoiceItems,
        {
          'invoice_id': invoiceId,
          'order_id': item.orderId,
          'product_id': item.productId,
          'quantity': item.quantity,
          'unit_price': item.unitPrice,
          'selling_price': item.sellingPrice,
          'total_amount': item.totalAmount,
          'is_sub_unit': item.isSubUnit ? 1 : 0,
          'sub_unit_name': item.subUnitName,
          'sub_unit_quantity': item.subUnitQuantity,
          'status': status,
        },
      );
    }
  }

  Future<void> updateInvoiceStatus(int invoiceId, String status, {Transaction? txn}) async {
    if (txn != null) {
      await _updateInvoiceStatusWithExecutor(invoiceId, status, txn);
    } else {
      await DatabaseService.instance.withTransaction((transaction) async {
        await _updateInvoiceStatusWithExecutor(invoiceId, status, transaction);
      });
    }
  }

  Future<void> _updateInvoiceStatusWithExecutor(
    int invoiceId, 
    String status, 
    DatabaseExecutor executor
  ) async {
    await executor.update(
      'invoices',
      {'status': status},
      where: 'id = ?',
      whereArgs: [invoiceId],
    );
  }

  Future<void> updatePaymentStatus(int invoiceId, String paymentStatus, {Transaction? txn}) async {
    if (txn != null) {
      await _updatePaymentStatusWithExecutor(invoiceId, paymentStatus, txn);
    } else {
      await DatabaseService.instance.withTransaction((transaction) async {
        await _updatePaymentStatusWithExecutor(invoiceId, paymentStatus, transaction);
      });
    }
  }

  Future<void> _updatePaymentStatusWithExecutor(
    int invoiceId, 
    String paymentStatus, 
    DatabaseExecutor executor
  ) async {
    await executor.update(
      'invoices',
      {'payment_status': paymentStatus},
      where: 'id = ?',
      whereArgs: [invoiceId],
    );
  }

  Future<void> deleteInvoice(int invoiceId, {Transaction? txn}) async {
    if (txn != null) {
      await _deleteInvoiceWithExecutor(invoiceId, txn);
    } else {
      await DatabaseService.instance.withTransaction((transaction) async {
        await _deleteInvoiceWithExecutor(invoiceId, transaction);
      });
    }
  }

  Future<void> _deleteInvoiceWithExecutor(int invoiceId, DatabaseExecutor executor) async {
    // Delete invoice items first
    await executor.delete(
      DatabaseService.tableInvoiceItems,
      where: 'invoice_id = ?',
      whereArgs: [invoiceId],
    );

    // Then delete the invoice
    await executor.delete(
      DatabaseService.tableInvoices,
      where: 'id = ?',
      whereArgs: [invoiceId],
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

  Future<List<Map<String, dynamic>>> getInvoiceItems(int invoiceId, {Transaction? txn}) async {
    final executor = txn ?? await DatabaseService.instance.database;
    
    return await executor.rawQuery('''
      SELECT 
        ii.*,
        p.product_name,
        p.buying_price,
        p.sub_unit_quantity,
        p.sub_unit_price,
        p.sub_unit_name
      FROM invoice_items ii
      JOIN products p ON ii.product_id = p.id
      WHERE ii.invoice_id = ?
      ORDER BY ii.id
    ''', [invoiceId]);
  }
} 