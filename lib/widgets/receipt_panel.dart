import 'package:flutter/material.dart';
import 'package:my_flutter_app/const/constant.dart';
import 'package:my_flutter_app/models/order_model.dart';
import 'package:my_flutter_app/services/database.dart';
import 'package:printing/printing.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:intl/intl.dart';

class ReceiptPanel extends StatefulWidget {
  final Order order;
  final Function(Order) onProcessSale;

  const ReceiptPanel({
    super.key,
    required this.order,
    required this.onProcessSale,
  });

  @override
  State<ReceiptPanel> createState() => _ReceiptPanelState();
}

class _ReceiptPanelState extends State<ReceiptPanel> {
  List<Map<String, dynamic>> _orderItems = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadOrderItems();
  }

  Future<void> _loadOrderItems() async {
    try {
      if (widget.order.id == null) {
        setState(() {
          _orderItems = [];
          _isLoading = false;
        });
        return;
      }

      final items = await DatabaseService.instance.getOrderItems(widget.order.id!);
      
      if (mounted) {
        setState(() {
          _orderItems = items;
          _isLoading = false;
        });
      }
    } catch (e) {
      print('Error loading order items: $e');
      if (mounted) {
        setState(() {
          _orderItems = [];
          _isLoading = false;
        });
      }
    }
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
            Text('Order #${widget.order.orderNumber}'),
            Text('Customer: ${widget.order.customerName ?? "N/A"}'),
            Text('Date: ${DateFormat('yyyy-MM-dd HH:mm').format(widget.order.orderDate)}'),
            const Divider(),
            Expanded(
              child: _isLoading 
                ? const Center(child: CircularProgressIndicator())
                : _orderItems.isEmpty
                  ? const Center(child: Text('No items in this order'))
                  : ListView.builder(
                      itemCount: _orderItems.length,
                      itemBuilder: (context, index) {
                        final item = _orderItems[index];
                        return Card(
                          margin: const EdgeInsets.symmetric(vertical: 4.0),
                          child: Padding(
                            padding: const EdgeInsets.all(8.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  item['product_name'] ?? 'Product not found',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text('Quantity: ${item['quantity']}'),
                                    Text('Unit Price: KSH ${(item['unit_price'] as num).toStringAsFixed(2)}'),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.end,
                                  children: [
                                    Text(
                                      'Subtotal: KSH ${(item['total_amount'] as num).toStringAsFixed(2)}',
                                      style: const TextStyle(fontWeight: FontWeight.bold),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
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
                  'KSH ${widget.order.totalAmount.toStringAsFixed(2)}',
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
                    onPressed: () => widget.onProcessSale(widget.order),
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
                  onPressed: () => _printReceipt(context),
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

  Future<void> _printReceipt(BuildContext context) async {
    if (_orderItems.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No products to print'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }
    
    try {
      final pdf = pw.Document();
      
      pdf.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.roll80,
          build: (context) => pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              // ... keep existing PDF generation code ...
            ],
          ),
        ),
      );

      await Printing.layoutPdf(
        onLayout: (format) async => pdf.save(),
        name: '${salePrefix}-${widget.order.orderNumber}',
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
