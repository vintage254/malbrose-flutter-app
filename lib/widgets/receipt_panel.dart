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

  Future<void> _printReceipt(BuildContext context, List<Map<String, dynamic>> products) async {
    final pdf = pw.Document();
    
    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.roll80,
        build: (context) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.center,
          children: [
            // Header
            pw.Text(
              companyName,
              style: pw.TextStyle(
                fontSize: 18,
                fontWeight: pw.FontWeight.bold,
              ),
              textAlign: pw.TextAlign.center,
            ),
            pw.SizedBox(height: 5),
            pw.Text(companyAddress),
            pw.Text(companyPhone),
            pw.Text(companyEmail),
            pw.SizedBox(height: 5),
            pw.Text(
              companyTagline,
              style: pw.TextStyle(fontStyle: pw.FontStyle.italic),
            ),
            pw.Divider(thickness: 2),
            
            // Receipt Details
            pw.SizedBox(height: 10),
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text('Receipt No:'),
                pw.Text('${salePrefix}-${order.orderNumber}'),
              ],
            ),
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text('Date:'),
                pw.Text(DateFormat('yyyy-MM-dd HH:mm').format(order.orderDate)),
              ],
            ),
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text('Customer:'),
                pw.Text(order.customerName ?? 'Walk-in Customer'),
              ],
            ),
            
            // Items Header
            pw.Divider(),
            pw.Row(
              children: [
                pw.Expanded(flex: 3, child: pw.Text('Item')),
                pw.Expanded(child: pw.Text('Qty')),
                pw.Expanded(flex: 2, child: pw.Text('Price')),
                pw.Expanded(flex: 2, child: pw.Text('Total')),
              ],
            ),
            pw.Divider(),
            
            // Items
            ...order.items!.asMap().entries.map((entry) {
              final orderItem = entry.value;
              final product = products[entry.key];
              return pw.Row(
                children: [
                  pw.Expanded(
                    flex: 3,
                    child: pw.Text(product['product_name']),
                  ),
                  pw.Expanded(
                    child: pw.Text('${orderItem.quantity}'),
                  ),
                  pw.Expanded(
                    flex: 2,
                    child: pw.Text('${orderItem.price.toStringAsFixed(2)}'),
                  ),
                  pw.Expanded(
                    flex: 2,
                    child: pw.Text('${orderItem.total.toStringAsFixed(2)}'),
                  ),
                ],
              );
            }).toList(),
            
            // Footer
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
              style: pw.TextStyle(fontStyle: pw.FontStyle.italic),
            ),
            pw.SizedBox(height: 10),
            pw.Text(
              'Powered by Malbrose POS',
              style: pw.TextStyle(fontSize: 8),
            ),
          ],
        ),
      ),
    );

    // Print the document
    await Printing.layoutPdf(
      onLayout: (format) async => pdf.save(),
      name: '${salePrefix}-${order.orderNumber}',
    );
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(defaultPadding),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Order Details',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: defaultPadding),
            Text('Order #${order.orderNumber}'),
            Text('Customer: ${order.customerName ?? "N/A"}'),
            Text('Date: ${DateFormat('yyyy-MM-dd HH:mm').format(order.orderDate)}'),
            const Divider(),
            Expanded(
              child: ListView.builder(
                itemCount: order.items?.length ?? 0,
                itemBuilder: (context, index) {
                  final item = order.items![index];
                  return FutureBuilder<Map<String, dynamic>?>(
                    future: DatabaseService.instance.getProductById(item.productId),
                    builder: (context, snapshot) {
                      if (!snapshot.hasData) {
                        return const Center(child: CircularProgressIndicator());
                      }
                      final product = snapshot.data!;
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Product: ${product['product_name']}'),
                          Text('Quantity: ${item.quantity}'),
                          Text('Unit Price: KSH ${item.price.toStringAsFixed(2)}'),
                          Text('Subtotal: KSH ${item.total.toStringAsFixed(2)}'),
                          const Divider(),
                        ],
                      );
                    },
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
                    final products = await Future.wait(
                      order.items!.map((item) => 
                        DatabaseService.instance.getProductById(item.productId)
                      )
                    );
                    if (context.mounted && products.every((p) => p != null)) {
                      await _printReceipt(context, products.cast<Map<String, dynamic>>());
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
    );
  }
}
