import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:my_flutter_app/models/invoice_model.dart';
import 'package:my_flutter_app/models/customer_model.dart';
import 'package:my_flutter_app/const/constant.dart';
import 'package:intl/intl.dart';

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
              ),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    'Bill To:',
                    style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                  ),
                  pw.Text(customer.name),
                  if (customer.email != null) pw.Text(customer.email!),
                  if (customer.phone != null) pw.Text(customer.phone!),
                  if (customer.address != null) pw.Text(customer.address!),
                ],
              ),
            ),
            pw.SizedBox(height: 20),

            // Items Table
            if (invoice.items != null && invoice.items!.isNotEmpty) ...[
              pw.Table.fromTextArray(
                headers: ['Order #', 'Description', 'Amount'],
                data: invoice.items!.map((item) => [
                  item.orderId.toString(),
                  'Order #${item.orderId}',
                  'KSH ${item.totalAmount.toStringAsFixed(2)}',
                ]).toList(),
                border: null,
                headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                headerDecoration: pw.BoxDecoration(color: PdfColors.grey300),
                cellHeight: 30,
                cellAlignments: {
                  0: pw.Alignment.centerLeft,
                  1: pw.Alignment.centerLeft,
                  2: pw.Alignment.centerRight,
                },
              ),
            ],
            pw.SizedBox(height: 20),

            // Total
            pw.Container(
              alignment: pw.Alignment.centerRight,
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.end,
                children: [
                  pw.Text(
                    'Total Amount: KSH ${invoice.totalAmount.toStringAsFixed(2)}',
                    style: pw.TextStyle(
                      fontSize: 16,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),

            // Footer
            pw.Spacer(),
            pw.Divider(),
            pw.Text(
              'Thank you for your business!',
              style: const pw.TextStyle(
                color: PdfColors.grey,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );

    await Printing.layoutPdf(
      onLayout: (format) async => pdf.save(),
    );
  }
} 