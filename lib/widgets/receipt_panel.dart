import 'package:flutter/material.dart';
import 'package:my_flutter_app/const/constant.dart';
import 'package:my_flutter_app/models/order_model.dart';
import 'package:my_flutter_app/services/database.dart';
import 'package:printing/printing.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:intl/intl.dart';

class ReceiptPanel extends StatelessWidget {
  final Order order;
  final Function(Order) onProcessSale;

  const ReceiptPanel({
    super.key,
    required this.order,
    required this.onProcessSale,
  });

  Future<void> _printReceipt(BuildContext context, Map<String, dynamic> product) async {
    final pdf = pw.Document();
    
    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.roll80,
        build: (context) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text(
              'Malbrose Hardware Store',
              style: pw.TextStyle(
                fontSize: 18,
                fontWeight: pw.FontWeight.bold,
              ),
            ),
            pw.SizedBox(height: 10),
            pw.Text('Receipt #${order.id}'),
            pw.Text('Date: ${DateFormat('yyyy-MM-dd HH:mm').format(order.orderDate)}'),
            pw.Text('Customer: ${order.customerName ?? "N/A"}'),
            pw.Divider(),
            pw.Text(
              'Order Details',
              style: pw.TextStyle(
                fontSize: 14,
                fontWeight: pw.FontWeight.bold,
              ),
            ),
            pw.SizedBox(height: 10),
            pw.Text('Product: ${product['product_name']}'),
            pw.Text('Quantity: ${order.quantity}'),
            pw.Text('Unit Price: KSH ${order.sellingPrice.toStringAsFixed(2)}'),
            pw.Divider(),
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text(
                  'Total Amount:',
                  style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                ),
                pw.Text(
                  'KSH ${order.totalAmount.toStringAsFixed(2)}',
                  style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                ),
              ],
            ),
            pw.SizedBox(height: 20),
            pw.Text(
              'Thank you for your business!',
              style: pw.TextStyle(
                fontSize: 12,
                fontStyle: pw.FontStyle.italic,
              ),
            ),
          ],
        ),
      ),
    );

    try {
      await Printing.layoutPdf(
        onLayout: (format) async => pdf.save(),
        name: 'Receipt_${order.id}',
      );
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error printing receipt: $e'),
            backgroundColor: Colors.red,
          ),
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
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(defaultPadding),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Sales Receipt',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: defaultPadding),
              Text('Order #${order.id}'),
              Text('Date: ${order.orderDate.toString()}'),
              Text('Customer: ${order.customerName ?? "N/A"}'),
              const Divider(),
              const Text(
                'Order Details',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: defaultPadding),
              Expanded(
                child: FutureBuilder<Map<String, dynamic>?>(
                  future: DatabaseService.instance.getProductById(order.productId),
                  builder: (context, snapshot) {
                    if (!snapshot.hasData) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    final product = snapshot.data!;
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Product: ${product['product_name']}'),
                        Text('Quantity: ${order.quantity}'),
                        Text('Unit Price: KSH ${order.sellingPrice.toStringAsFixed(2)}'),
                      ],
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
                    'KSH ${order.totalAmount.toStringAsFixed(2)}',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: defaultPadding),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () => onProcessSale(order),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        padding: const EdgeInsets.all(defaultPadding),
                      ),
                      icon: const Icon(Icons.check_circle),
                      label: const Text(
                        'Complete Sale',
                        style: TextStyle(fontSize: 16),
                      ),
                    ),
                  ),
                  const SizedBox(width: defaultPadding),
                  ElevatedButton.icon(
                    onPressed: () async {
                      final product = await DatabaseService.instance.getProductById(order.productId);
                      if (context.mounted && product != null) {
                        await _printReceipt(context, product);
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue,
                      padding: const EdgeInsets.all(defaultPadding),
                    ),
                    icon: const Icon(Icons.print),
                    label: const Text('Print Receipt'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
