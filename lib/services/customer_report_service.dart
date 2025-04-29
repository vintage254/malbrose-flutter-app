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
import 'package:my_flutter_app/services/printer_service.dart';
import 'package:flutter/material.dart';
import 'package:my_flutter_app/services/config_service.dart';

class CustomerReportService {
  static final CustomerReportService instance = CustomerReportService._internal();
  CustomerReportService._internal();
  final config = ConfigService.instance;

  Future<void> generateAndPrintCustomerReport(CustomerReport report, Customer customer, [BuildContext? context]) async {
    try {
      // Get the printer service
      final printerService = PrinterService.instance;
      
      final pdf = await generateCustomerReportPdf(report, customer);
      
      // Use the printer service to print the PDF if context is provided
      if (context != null) {
        await printerService.printPdf(
          pdf: pdf,
          documentName: 'Customer Report - ${report.reportNumber}',
          context: context,
        );
      } else {
        // Fallback to the old method if no context is provided
        await Printing.layoutPdf(onLayout: (format) async => pdf);
      }
      
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

    // Get the printer service for page format
    final printerService = PrinterService.instance;
    final pageFormat = printerService.printerType == PrinterType.thermal 
        ? printerService.getPageFormat() 
        : PdfPageFormat.a4;

    pdf.addPage(
      pw.MultiPage(
        pageFormat: pageFormat,
        build: (context) {
          final List<pw.Widget> children = [];
          
          // Add report header with date range
          children.addAll([
            _buildHeader(report, logo, font, boldFont),
            pw.SizedBox(height: 40),
            _buildCustomerInfo(customer, font, boldFont),
            pw.SizedBox(height: 10),
            _buildDateRangeInfo(report.startDate, report.endDate, font, boldFont),
            pw.SizedBox(height: 20),
          ]);

          // Add payment status if available
          if (report.paymentStatus != null) {
            children.add(
              pw.Container(
                padding: const pw.EdgeInsets.all(10),
                decoration: pw.BoxDecoration(
                  color: report.paymentStatus?.toUpperCase() == 'PAID' ? 
                    PdfColors.green100 : PdfColors.orange100,
                  borderRadius: const pw.BorderRadius.all(pw.Radius.circular(5)),
                ),
                child: pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.center,
                  children: [
                    pw.Text(
                      'Payment Status: ',
                      style: pw.TextStyle(font: boldFont, fontSize: 12),
                    ),
                    pw.Text(
                      report.paymentStatus ?? 'Unknown',
                      style: pw.TextStyle(
                        font: boldFont, 
                        fontSize: 12,
                        color: report.paymentStatus?.toUpperCase() == 'PAID' ? 
                          PdfColors.green800 : PdfColors.orange800,
                      ),
                    ),
                  ],
                ),
              )
            );
            children.add(pw.SizedBox(height: 20));
          }

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

          // Add financial summary
          children.addAll([
            _buildSummaryRow('Completed Orders Total:', report.completedAmount, font, boldFont),
            _buildSummaryRow('Pending Orders Total:', report.pendingAmount, font, boldFont),
            _buildSummaryRow(
              'Total Amount:',
              report.totalAmount,
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

  static pw.Widget _buildDateRangeInfo(DateTime? startDate, DateTime? endDate, pw.Font font, pw.Font boldFont) {
    final dateFormat = DateFormat('MMM dd, yyyy');
    final startDateStr = startDate != null ? dateFormat.format(startDate) : 'All time';
    final endDateStr = endDate != null ? dateFormat.format(endDate) : 'Present';
    
    return pw.Container(
      padding: const pw.EdgeInsets.all(10),
      decoration: pw.BoxDecoration(
        color: PdfColors.grey100,
        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(5)),
      ),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.center,
        children: [
          pw.Text(
            'Report Period: ',
            style: pw.TextStyle(font: boldFont, fontSize: 12),
          ),
          pw.Text(
            '$startDateStr to $endDateStr',
            style: pw.TextStyle(font: font, fontSize: 12),
          ),
        ],
      ),
    );
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
              config.businessName,
              style: pw.TextStyle(
                font: boldFont,
                fontSize: 24,
                color: PdfColors.blue900,
              ),
            ),
            _buildText(config.businessAddress, font),
            _buildText(config.businessPhone, font),
            if (config.businessEmail.isNotEmpty) _buildText(config.businessEmail, font),
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
    // Group items by order number
    final Map<String, List<OrderItem>> itemsByOrder = {};
    for (final item in items) {
      final orderNumber = item.orderNumber ?? 'Unknown';
      if (!itemsByOrder.containsKey(orderNumber)) {
        itemsByOrder[orderNumber] = [];
      }
      itemsByOrder[orderNumber]!.add(item);
    }
    
    // Build a list of widgets for each order
    final List<pw.Widget> orderWidgets = [];
    
    itemsByOrder.forEach((orderNumber, orderItems) {
      final orderDate = orderItems.isNotEmpty && orderItems.first.orderDate != null
          ? DateFormat('MMM dd, yyyy').format(orderItems.first.orderDate!)
          : 'Unknown date';
      
      // Calculate order total
      final orderTotal = orderItems.fold<double>(
          0, (sum, item) => sum + item.totalAmount);
      
      // Add order header
      orderWidgets.add(
        pw.Container(
          padding: const pw.EdgeInsets.all(8),
          color: PdfColors.grey200,
          child: pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text(
                'Order #$orderNumber - $orderDate',
                style: pw.TextStyle(font: font, fontWeight: pw.FontWeight.bold),
              ),
              pw.Text(
                'Total: KSH ${orderTotal.toStringAsFixed(2)}',
                style: pw.TextStyle(font: font, fontWeight: pw.FontWeight.bold),
              ),
            ],
          ),
        )
      );
      
      // Add order items table
      orderWidgets.add(
        pw.Table(
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
            ...orderItems.map((item) => _buildTableRow(item, font)),
          ],
        )
      );
      
      // Add spacing between orders
      orderWidgets.add(pw.SizedBox(height: 10));
    });
    
    return pw.Column(children: orderWidgets);
  }

  static pw.TableRow _buildTableHeader(pw.Font font) {
    return pw.TableRow(
      decoration: pw.BoxDecoration(color: PdfColors.blue900),
      children: [
        _buildTableCell('Product', font, isHeader: true),
        _buildTableCell('Quantity', font, isHeader: true),
        _buildTableCell('Unit Price', font, isHeader: true),
        _buildTableCell('Total', font, isHeader: true),
        _buildTableCell('Status', font, isHeader: true),
      ],
    );
  }

  static pw.TableRow _buildTableRow(OrderItem item, pw.Font font) {
    final status = item.orderId > 0 ? 'COMPLETED' : 'PENDING';
    
    return pw.TableRow(
      children: [
        _buildTableCell(item.displayName, font),
        _buildTableCell(
          '${item.quantity}${item.isSubUnit ? " ${item.subUnitName ?? 'pieces'}" : ""}', 
          font
        ),
        _buildTableCell('KSH ${item.effectivePrice.toStringAsFixed(2)}', font),
        _buildTableCell('KSH ${item.totalAmount.toStringAsFixed(2)}', font),
        _buildTableCell(status, font, textColor: status == 'COMPLETED' ? PdfColors.green : PdfColors.orange),
      ],
    );
  }

  static pw.Widget _buildTableCell(
    String text,
    pw.Font font, {
    bool isHeader = false,
    PdfColor? textColor,
  }) {
    return pw.Padding(
      padding: const pw.EdgeInsets.all(8),
      child: pw.Text(
        text,
        style: pw.TextStyle(
          font: font,
          color: isHeader ? PdfColors.white : (textColor ?? PdfColors.black),
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

  Future<CustomerReport> generateCustomerReport(
    int customerId, {
    DateTime? startDate,
    DateTime? endDate,
    Transaction? txn
  }) async {
    int retryCount = 0;
    const maxRetries = 2;
    
    while (true) {
      try {
        // Pre-fetch current user outside of transaction to avoid nested database calls
        final currentUser = await DatabaseService.instance.getCurrentUser();
        
        if (txn != null) {
          return await _generateCustomerReportWithExecutor(
            customerId, 
            txn,
            startDate: startDate,
            endDate: endDate,
            currentUser: currentUser
          );
        }
        
        // If no transaction provided, create one with timeout handling
        return await DatabaseService.instance.withTransaction((transaction) async {
          return await _generateCustomerReportWithExecutor(
            customerId, 
            transaction,
            startDate: startDate,
            endDate: endDate,
            currentUser: currentUser
          );
        });
      } catch (e) {
        print('Error in generateCustomerReport (attempt ${retryCount + 1}): $e');
        
        // Check if we should retry
        if (retryCount >= maxRetries) {
          rethrow; // Don't retry if max retries reached
        }
        
        // Exponential backoff with jitter to prevent thundering herd
        final baseDelay = 500 * (1 << retryCount);
        final jitter = (baseDelay * 0.2 * (DateTime.now().millisecondsSinceEpoch % 10) / 10).toInt();
        final delay = baseDelay + jitter;
        
        print('Retrying report generation in $delay ms...');
        await Future.delayed(Duration(milliseconds: delay));
        retryCount++;
      }
    }
  }

  Future<CustomerReport> _generateCustomerReportWithExecutor(
    int customerId, 
    DatabaseExecutor executor, {
    DateTime? startDate,
    DateTime? endDate,
    Map<String, dynamic>? currentUser
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
      
      // Build query with date range if provided
      String dateRangeClause = '';
      List<dynamic> queryArgs = [customerId];
      
      if (startDate != null) {
        dateRangeClause += ' AND date(o.created_at) >= date(?)';
        queryArgs.add(startDate.toIso8601String());
      }
      
      if (endDate != null) {
        dateRangeClause += ' AND date(o.created_at) <= date(?)';
        queryArgs.add(endDate.toIso8601String());
      }
      
      final orders = await executor.rawQuery('''
        SELECT 
          o.id,
          o.order_number,
          o.created_at,
          o.status,
          oi.id as item_id,
          COALESCE(oi.product_id, 0) as product_id,
          COALESCE(oi.quantity, 0) as quantity,
          COALESCE(oi.unit_price, 0.0) as unit_price,
          COALESCE(oi.selling_price, 0.0) as selling_price,
          COALESCE(oi.total_amount, 0.0) as total_amount,
          COALESCE(oi.is_sub_unit, 0) as is_sub_unit,
          oi.sub_unit_name,
          COALESCE(p.product_name, 'Unknown Product') as product_name,
          p.sub_unit_price,
          p.sub_unit_quantity
        FROM orders o
        LEFT JOIN order_items oi ON o.id = oi.order_id
        LEFT JOIN products p ON oi.product_id = p.id
        WHERE o.customer_id = ? $dateRangeClause
        ORDER BY o.created_at DESC
      ''', queryArgs);

      if (orders.isEmpty) {
        throw Exception('No orders found for this customer in the specified time period');
      }

      double completedAmount = 0;
      double pendingAmount = 0;
      final completedItems = <OrderItem>[];
      final pendingItems = <OrderItem>[];

      for (final order in orders) {
        try {
          final item = OrderItem.fromMap(order);
          
          // Add order number and date to the item for better reporting
          item.orderNumber = order['order_number'] as String? ?? 'Unknown';
          item.orderDate = order['created_at'] != null 
              ? DateTime.parse(order['created_at'] as String)
              : DateTime.now();
          
          final isSubUnit = order['is_sub_unit'] == 1;
          final subUnitPrice = (order['sub_unit_price'] as num?)?.toDouble();
          
          final actualPrice = isSubUnit && subUnitPrice != null ? 
              subUnitPrice : item.sellingPrice;
          
          final totalAmount = actualPrice * item.quantity;

          if (order['status'] == 'COMPLETED') {
            completedItems.add(item);
            completedAmount += totalAmount;
          } else if (order['status'] == 'PENDING') {
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
      final now = DateTime.now();
      
      // Create the report object
      final report = CustomerReport(
        reportNumber: reportNumber,
        customerId: customerId,
        customerName: customer['name'] as String? ?? 'Unknown Customer',
        totalAmount: completedAmount + pendingAmount,
        completedAmount: completedAmount,
        pendingAmount: pendingAmount,
        createdAt: now,
        startDate: startDate,
        endDate: endDate,
        completedItems: completedItems,
        pendingItems: pendingItems,
      );
      
      // Log the report generation if user is available
      if (currentUser != null) {
        await executor.insert(
          DatabaseService.tableActivityLogs,
          {
            'user_id': currentUser['id'] as int,
            'username': currentUser['username'] as String,
            'action': DatabaseService.actionCreateCustomerReport,
            'action_type': 'Generate customer report',
            'details': 'Generated customer report #${report.reportNumber} for ${customer['name']}',
            'timestamp': now.toIso8601String(),
          },
        );
      }
      
      return report;
    } catch (e) {
      print('Error generating customer report: $e');
      rethrow;
    }
  }

  Future<String> generateReportNumber(DatabaseExecutor executor) async {
    try {
      final now = DateTime.now();
      final prefix = 'REP';
      final date = DateFormat('yyyyMMdd').format(now);
      final timeComponent = '${now.hour.toString().padLeft(2, '0')}${now.minute.toString().padLeft(2, '0')}${now.second.toString().padLeft(2, '0')}';
      
      // Add a time component to make the report number more unique
      // This helps prevent collisions when multiple reports are generated in quick succession
      return '$prefix-$date-$timeComponent';
    } catch (e) {
      print('Error generating report number: $e');
      // Fallback to a simpler format if there's an error
      return 'REP-${DateTime.now().millisecondsSinceEpoch}';
    }
  }

  Future<List<CustomerReport>> getCustomerReports(int customerId, {Transaction? txn}) async {
    try {
      if (txn != null) {
        return await _getCustomerReportsWithExecutor(customerId, txn);
      }
      // If no transaction provided, create one with timeout handling
      return await DatabaseService.instance.withTransaction((transaction) async {
        return await _getCustomerReportsWithExecutor(customerId, transaction);
      });
    } catch (e) {
      print('Error in getCustomerReports: $e');
      // If we get a database lock error, try again with a delay
      if (e.toString().contains('locked')) {
        await Future.delayed(const Duration(milliseconds: 500));
        return await DatabaseService.instance.withTransaction((transaction) async {
          return await _getCustomerReportsWithExecutor(customerId, transaction);
        });
      }
      rethrow;
    }
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
    int retryCount = 0;
    const maxRetries = 2;
    
    while (true) {
      try {
        // If transaction is provided, use it directly
        if (txn != null) {
          // Check if report already exists within the provided transaction
          final existingReportCheck = await txn.query(
            DatabaseService.tableCustomerReports,
            where: 'report_number = ?',
            whereArgs: [report.reportNumber],
            limit: 1,
          );
          
          if (existingReportCheck.isNotEmpty) {
            return CustomerReport.fromMap(existingReportCheck.first);
          }
          
          return await _createCustomerReportWithExecutor(report, txn);
        }
        
        // If no transaction provided, do a quick check outside transaction first
        final db = await DatabaseService.instance.database;
        final existingReport = await db.query(
          DatabaseService.tableCustomerReports,
          where: 'report_number = ?',
          whereArgs: [report.reportNumber],
          limit: 1,
        );
        
        if (existingReport.isNotEmpty) {
          print('Report with number ${report.reportNumber} already exists, returning existing report');
          return CustomerReport.fromMap(existingReport.first);
        }
        
        // Pre-fetch current user outside of transaction to avoid nested database calls
        final currentUser = await DatabaseService.instance.getCurrentUser();
        
        // Create a transaction with timeout handling
        return await DatabaseService.instance.withTransaction((transaction) async {
          // Double-check within transaction that report doesn't already exist
          final existingReportCheck = await transaction.query(
            DatabaseService.tableCustomerReports,
            where: 'report_number = ?',
            whereArgs: [report.reportNumber],
            limit: 1,
          );
          
          if (existingReportCheck.isNotEmpty) {
            return CustomerReport.fromMap(existingReportCheck.first);
          }
          
          // Create the report with the transaction and pre-fetched user
          final result = await _createCustomerReportWithExecutor(
            report, 
            transaction,
            currentUser: currentUser
          );
          
          return result;
        });
      } catch (e) {
        print('Error in createCustomerReportWithItems (attempt ${retryCount + 1}): $e');
        
        // Check if we should retry
        if (retryCount >= maxRetries) {
          rethrow; // Don't retry if max retries reached
        }
        
        // Exponential backoff with jitter
        final baseDelay = 500 * (1 << retryCount);
        final jitter = (baseDelay * 0.2 * (DateTime.now().millisecondsSinceEpoch % 10) / 10).toInt();
        final delay = baseDelay + jitter;
        
        print('Retrying report creation in $delay ms...');
        await Future.delayed(Duration(milliseconds: delay));
        retryCount++;
      }
    }
  }

  Future<CustomerReport> _createCustomerReportWithExecutor(
    CustomerReport report, 
    DatabaseExecutor executor, 
    {Map<String, dynamic>? currentUser} // Accept pre-fetched user
  ) async {
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
      
      // Use batch operations for better performance and reduced locking
      final batch = executor.batch();
      
      // Process completed items
      if (report.hasCompletedItems) {
        for (final item in report.completedItems!) {
          // Add report item
          batch.insert(
            DatabaseService.tableReportItems,
            {
              'report_id': reportId,
              'order_id': item.orderId,
              'product_id': item.productId,
              'product_name': item.productName,
              'quantity': item.quantity,
              'unit_price': item.unitPrice,
              'selling_price': item.sellingPrice,
              'total_amount': item.totalAmount,
              'status': 'COMPLETED',
              'is_sub_unit': item.isSubUnit ? 1 : 0,
              'sub_unit_name': item.subUnitName,
              'created_at': DateTime.now().toIso8601String(),
            },
          );
          
          // We don't change the order status when creating a report
          // This ensures the original order status is preserved
        }
      }

      // Process pending items
      if (report.hasPendingItems) {
        for (final item in report.pendingItems!) {
          batch.insert(
            DatabaseService.tableReportItems,
            {
              'report_id': reportId,
              'order_id': item.orderId,
              'product_id': item.productId,
              'product_name': item.productName,
              'quantity': item.quantity,
              'unit_price': item.unitPrice,
              'selling_price': item.sellingPrice,
              'total_amount': item.totalAmount,
              'status': 'PENDING',
              'is_sub_unit': item.isSubUnit ? 1 : 0,
              'sub_unit_name': item.subUnitName,
              'created_at': DateTime.now().toIso8601String(),
            },
          );
        }
      }
      
      // Add activity log to the batch if user is available
      if (currentUser != null) {
        batch.insert(
          DatabaseService.tableActivityLogs,
          {
            'user_id': currentUser['id'] as int,
            'username': currentUser['username'] as String,
            'action': DatabaseService.actionCreateCustomerReport,
            'action_type': 'Create customer report',
            'details': 'Created customer report #${report.reportNumber} for ${report.customerName}',
            'timestamp': DateTime.now().toIso8601String(),
          },
        );
      }
      
      // Execute all operations in a single batch
      await batch.commit(noResult: true);

      return report.copyWith(id: reportId);
    } catch (e) {
      print('Error creating customer report: $e');
      rethrow;
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