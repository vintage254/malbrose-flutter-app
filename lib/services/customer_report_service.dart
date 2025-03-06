import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:my_flutter_app/models/customer_report_model.dart';
import 'package:my_flutter_app/models/customer_model.dart';
import 'package:my_flutter_app/const/constant.dart';
import 'package:intl/intl.dart';
import 'dart:io';
import 'dart:typed_data';
import 'package:my_flutter_app/models/order_model.dart';
import 'package:my_flutter_app/services/database.dart';
import 'package:sqflite/sqflite.dart';

class CustomerReportService {
  static final CustomerReportService instance = CustomerReportService._internal();
  CustomerReportService._internal();

  Future<void> generateAndPrintCustomerReport(CustomerReport report, Customer customer) async {
    try {
      final pdf = await generateCustomerReportPdf(report, customer);
      await Printing.layoutPdf(onLayout: (format) async => pdf);
      
      // Log the print activity
      final currentUser = await DatabaseService.instance.getCurrentUser();
      if (currentUser != null) {
        await DatabaseService.instance.logActivity(
          currentUser['id'] as int,
          currentUser['username'] as String,
          DatabaseService.actionPrintCustomerReport,
          'Print customer report',
          'Printed customer report #${report.reportNumber} for ${customer.name}'
        );
      }
    } catch (e) {
      print('Error generating customer report PDF: $e');
      rethrow;
    }
  }

  static Future<Uint8List> generateCustomerReportPdf(CustomerReport report, Customer customer) async {
    final pdf = pw.Document();
    final logo = await _getLogoImage();
    final font = await PdfGoogleFonts.nunitoRegular();
    final boldFont = await PdfGoogleFonts.nunitoBold();

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        build: (context) {
          final List<pw.Widget> children = [];
          
          children.addAll([
            _buildHeader(report, logo, font, boldFont),
            pw.SizedBox(height: 40),
            _buildCustomerInfo(customer, font, boldFont),
            pw.SizedBox(height: 20),
          ]);

          if (report.hasCompletedItems) {
            children.addAll([
              _buildSectionTitle('Completed Orders', boldFont, PdfColors.blue900),
              pw.SizedBox(height: 10),
              _buildItemsTable(report.completedItems!, font),
              pw.SizedBox(height: 20),
            ]);
          }

          if (report.hasPendingItems) {
            children.addAll([
              _buildSectionTitle('Pending Orders', boldFont, PdfColors.orange),
              pw.SizedBox(height: 10),
              _buildItemsTable(report.pendingItems!, font),
              pw.SizedBox(height: 20),
            ]);
          }

          children.addAll([
            _buildSummaryRow('Subtotal:', report.totalAmount, font, boldFont),
            _buildSummaryRow('VAT (16%):', report.totalAmount * 0.16, font, boldFont),
            _buildSummaryRow(
              'Total Amount:',
              report.totalAmount * 1.16,
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
    CustomerReport report,
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
              'CUSTOMER REPORT',
              style: pw.TextStyle(
                font: boldFont,
                fontSize: 24,
                color: PdfColors.orange,
              ),
            ),
            _buildText('Report #: ${report.reportNumber}', font),
            _buildText(
              'Date: ${DateFormat('MMM dd, yyyy').format(report.createdAt)}',
              font,
            ),
            if (report.dueDate != null)
              _buildText(
                'Due Date: ${DateFormat('MMM dd, yyyy').format(report.dueDate!)}',
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
            'Customer:',
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
            'For any questions about this report, please contact:',
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

  Future<CustomerReport> generateCustomerReport(int customerId, {Transaction? txn}) async {
    if (txn != null) {
      return await _generateCustomerReportWithExecutor(customerId, txn);
    }
    // If no transaction provided, create one
    return await DatabaseService.instance.withTransaction((transaction) async {
      return await _generateCustomerReportWithExecutor(customerId, transaction);
    });
  }

  Future<CustomerReport> _generateCustomerReportWithExecutor(
    int customerId, 
    DatabaseExecutor executor
  ) async {
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
      
      final orders = await executor.rawQuery('''
        SELECT 
          o.id,
          o.status,
          oi.id as item_id,
          COALESCE(oi.product_id, 0) as product_id,
          COALESCE(oi.quantity, 0) as quantity,
          COALESCE(oi.unit_price, 0.0) as unit_price,
          COALESCE(oi.selling_price, 0.0) as selling_price,
          COALESCE(oi.is_sub_unit, 0) as is_sub_unit,
          oi.sub_unit_name,
          COALESCE(p.product_name, 'Unknown Product') as product_name,
          p.sub_unit_price,
          p.sub_unit_quantity
        FROM orders o
        LEFT JOIN order_items oi ON o.id = oi.order_id
        LEFT JOIN products p ON oi.product_id = p.id
        WHERE o.customer_id = ? AND o.status != 'REPORTED'
        ORDER BY o.created_at DESC
      ''', [customerId]);

      if (orders.isEmpty) {
        throw Exception('No unreported orders found for this customer');
      }

      double completedAmount = 0;
      double pendingAmount = 0;
      final completedItems = <OrderItem>[];
      final pendingItems = <OrderItem>[];

      for (final order in orders) {
        try {
          final item = OrderItem.fromMap(order);
          final isSubUnit = order['is_sub_unit'] == 1;
          final subUnitPrice = (order['sub_unit_price'] as num?)?.toDouble();
          
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
        } catch (e) {
          print('Error processing order item: $e');
          print('Order data: $order');
          continue;
        }
      }

      if (completedItems.isEmpty && pendingItems.isEmpty) {
        throw Exception('No valid items found for customer report');
      }

      final reportNumber = await generateReportNumber(executor);
      
      return CustomerReport(
        reportNumber: reportNumber,
        customerId: customerId,
        customerName: customer['name'] as String? ?? 'Unknown Customer',
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
    } catch (e) {
      print('Error generating customer report: $e');
      rethrow;
    }
  }

  Future<String> generateReportNumber(DatabaseExecutor executor) async {
    final now = DateTime.now();
    final prefix = 'REP';
    final date = DateFormat('yyyyMMdd').format(now);
    
    final result = await executor.rawQuery('''
      SELECT report_number 
      FROM customer_reports 
      WHERE date(created_at) = date(?)
      ORDER BY report_number DESC 
      LIMIT 1
    ''', [now.toIso8601String()]);

    int sequence = 1;
    if (result.isNotEmpty) {
      final lastNumber = result.first['report_number'] as String;
      final lastSequence = int.tryParse(lastNumber.split('-').last) ?? 0;
      sequence = lastSequence + 1;
    }

    return '$prefix-$date-${sequence.toString().padLeft(4, '0')}';
  }

  Future<List<CustomerReport>> getCustomerReports(int customerId, {Transaction? txn}) async {
    if (txn != null) {
      return await _getCustomerReportsWithExecutor(customerId, txn);
    }
    // If no transaction provided, create one
    return await DatabaseService.instance.withTransaction((transaction) async {
      return await _getCustomerReportsWithExecutor(customerId, transaction);
    });
  }

  Future<List<CustomerReport>> _getCustomerReportsWithExecutor(
    int customerId, 
    DatabaseExecutor executor
  ) async {
    final reports = await executor.query(
      DatabaseService.tableCustomerReports,
      where: 'customer_id = ?',
      whereArgs: [customerId],
      orderBy: 'created_at DESC',
    );

    return reports.map((map) => CustomerReport.fromMap(map)).toList();
  }

  Future<CustomerReport> createCustomerReportWithItems(CustomerReport report, {Transaction? txn}) async {
    if (txn != null) {
      return await _createCustomerReportWithExecutor(report, txn);
    }
    // If no transaction provided, create one
    return await DatabaseService.instance.withTransaction((transaction) async {
      return await _createCustomerReportWithExecutor(report, transaction);
    });
  }

  Future<CustomerReport> _createCustomerReportWithExecutor(CustomerReport report, DatabaseExecutor executor) async {
    try {
      // Insert report with payment status
      final Map<String, dynamic> reportMap = report.toMap();
      
      // Ensure payment_status is set
      if (!reportMap.containsKey('payment_status')) {
        reportMap['payment_status'] = 'PENDING';
      }

      final reportId = await executor.insert(
        DatabaseService.tableCustomerReports, 
        reportMap
      );
      
      // Process items...
      if (report.hasCompletedItems) {
        await _processReportItems(
          executor,
          reportId,
          report.completedItems!,
          'COMPLETED'
        );
      }

      if (report.hasPendingItems) {
        await _processReportItems(
          executor,
          reportId,
          report.pendingItems!,
          'PENDING'
        );
      }

      // Log the activity
      final currentUser = await DatabaseService.instance.getCurrentUser();
      if (currentUser != null) {
        await DatabaseService.instance.logActivity(
          currentUser['id'] as int,
          currentUser['username'] as String,
          DatabaseService.actionCreateCustomerReport,
          'Create customer report',
          'Created customer report #${report.reportNumber} for ${report.customerName}'
        );
      }

      return report.copyWith(id: reportId);
    } catch (e) {
      print('Error creating customer report: $e');
      rethrow;
    }
  }

  Future<void> _processReportItems(
    DatabaseExecutor executor,
    int reportId,
    List<OrderItem> items,
    String status,
  ) async {
    for (var item in items) {
      await executor.insert(
        DatabaseService.tableReportItems,
        {
          'report_id': reportId,
          'order_id': item.orderId,
          'product_id': item.productId,
          'quantity': item.quantity,
          'unit_price': item.unitPrice,
          'selling_price': item.sellingPrice,
          'total_amount': item.totalAmount,
          'is_sub_unit': item.isSubUnit ? 1 : 0,
          'sub_unit_name': item.subUnitName,
          'status': status,
        },
      );

      if (status == 'COMPLETED') {
        await executor.update(
          DatabaseService.tableOrders,
          {'status': 'REPORTED'},
          where: 'id = ?',
          whereArgs: [item.orderId],
        );
      }
    }
  }

  Future<void> updateReportStatus(int reportId, String status, {Transaction? txn}) async {
    if (txn != null) {
      await _updateReportStatusWithExecutor(reportId, status, txn);
    } else {
      await DatabaseService.instance.withTransaction((transaction) async {
        await _updateReportStatusWithExecutor(reportId, status, transaction);
      });
    }
  }

  Future<void> _updateReportStatusWithExecutor(
    int reportId, 
    String status, 
    DatabaseExecutor executor
  ) async {
    await executor.update(
      DatabaseService.tableCustomerReports,
      {'status': status},
      where: 'id = ?',
      whereArgs: [reportId],
    );

    // Log the activity
    final currentUser = await DatabaseService.instance.getCurrentUser();
    if (currentUser != null) {
      await DatabaseService.instance.logActivity(
        currentUser['id'] as int,
        currentUser['username'] as String,
        DatabaseService.actionUpdateCustomerReport,
        'Update customer report',
        'Updated customer report #$reportId status to $status'
      );
    }
  }

  Future<void> updatePaymentStatus(int reportId, String paymentStatus, {Transaction? txn}) async {
    if (txn != null) {
      await _updatePaymentStatusWithExecutor(reportId, paymentStatus, txn);
    } else {
      await DatabaseService.instance.withTransaction((transaction) async {
        await _updatePaymentStatusWithExecutor(reportId, paymentStatus, transaction);
      });
    }
  }

  Future<void> _updatePaymentStatusWithExecutor(
    int reportId, 
    String paymentStatus, 
    DatabaseExecutor executor
  ) async {
    await executor.update(
      DatabaseService.tableCustomerReports,
      {'payment_status': paymentStatus},
      where: 'id = ?',
      whereArgs: [reportId],
    );

    // Log the activity
    final currentUser = await DatabaseService.instance.getCurrentUser();
    if (currentUser != null) {
      await DatabaseService.instance.logActivity(
        currentUser['id'] as int,
        currentUser['username'] as String,
        DatabaseService.actionUpdateCustomerReport,
        'Update customer report',
        'Updated customer report #$reportId payment status to $paymentStatus'
      );
    }
  }

  Future<void> deleteCustomerReport(int reportId, {Transaction? txn}) async {
    if (txn != null) {
      await _deleteCustomerReportWithExecutor(reportId, txn);
    } else {
      await DatabaseService.instance.withTransaction((transaction) async {
        await _deleteCustomerReportWithExecutor(reportId, transaction);
      });
    }
  }

  Future<void> _deleteCustomerReportWithExecutor(int reportId, DatabaseExecutor executor) async {
    // Delete report items first
    await executor.delete(
      DatabaseService.tableReportItems,
      where: 'report_id = ?',
      whereArgs: [reportId],
    );

    // Then delete the report
    await executor.delete(
      DatabaseService.tableCustomerReports,
      where: 'id = ?',
      whereArgs: [reportId],
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
} 