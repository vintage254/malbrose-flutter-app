import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:my_flutter_app/models/invoice_model.dart';
import 'package:my_flutter_app/models/customer_model.dart';
import 'package:my_flutter_app/const/constant.dart';
import 'package:intl/intl.dart';
import 'dart:io';
import 'dart:typed_data';

class InvoiceService {
  static final InvoiceService instance = InvoiceService._internal();
  InvoiceService._internal();

  Future<void> generateAndPrintInvoice(Invoice invoice, Customer customer) async {
    final pdf = pw.Document();
    
    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        build: (context) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            // Header
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

            // Items Table
            if (invoice.items != null && invoice.items!.isNotEmpty) ...[
              pw.Table.fromTextArray(
                headers: ['Order #', 'Product', 'Quantity', 'Unit Price', 'Total'],
                data: invoice.items!.map((item) => [
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
            ],
            pw.SizedBox(height: 20),

            // Summary
            pw.Container(
              alignment: pw.Alignment.centerRight,
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.end,
                children: [
                  pw.Divider(color: PdfColors.grey),
                  pw.SizedBox(height: 10),
                  pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.end,
                    children: [
                      pw.Text(
                        'Total Amount:',
                        style: pw.TextStyle(
                          fontWeight: pw.FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                      pw.SizedBox(width: 20),
                  pw.Text(
                        'KSH ${invoice.totalAmount.toStringAsFixed(2)}',
                    style: pw.TextStyle(
                      fontWeight: pw.FontWeight.bold,
                          fontSize: 14,
                          color: PdfColors.orange,
                        ),
                    ),
                    ],
                  ),
                ],
              ),
            ),

            // Footer
            pw.Spacer(),
            pw.Divider(color: PdfColors.grey),
            pw.SizedBox(height: 10),
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
            pw.Text(
              'Thank you for your business!',
              style: const pw.TextStyle(
                    color: PdfColors.grey700,
                fontSize: 12,
              ),
                ),
                pw.Text(
                  'Generated on ${DateFormat('MMM dd, yyyy HH:mm').format(DateTime.now())}',
                  style: const pw.TextStyle(
                    color: PdfColors.grey700,
                    fontSize: 10,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );

    await Printing.layoutPdf(
      onLayout: (format) async => pdf.save(),
      name: 'Invoice_${invoice.invoiceNumber}.pdf',
    );
  }

  static Future<Uint8List> generateInvoice(Invoice invoice, Customer customer) async {
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
                    if (invoice.items != null)
                      ...invoice.items!.map((item) => pw.TableRow(
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
} 