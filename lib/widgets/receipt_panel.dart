import 'package:flutter/material.dart';
import 'package:my_flutter_app/const/constant.dart';
import 'package:my_flutter_app/models/order_model.dart';
import 'package:my_flutter_app/services/database.dart';
import 'package:printing/printing.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:intl/intl.dart';
import 'package:my_flutter_app/widgets/order_cart_panel.dart';
import 'package:my_flutter_app/models/cart_item_model.dart';

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
      if (widget.order.id != null) {
        final items = await DatabaseService.instance.getOrderItems(widget.order.id!);
        if (mounted) {
          setState(() {
            _orderItems = items;  // Keep as Map<String, dynamic>
            _isLoading = false;
          });
        }
      }
    } catch (e) {
      print('Error loading order items: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading order items: $e')),
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
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Order #${widget.order.orderNumber}',
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              if (widget.order.orderStatus == 'PENDING')
                ElevatedButton.icon(
                  onPressed: () => _navigateToEdit(context),
                  icon: const Icon(Icons.edit),
                  label: const Text('Edit Order'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                  ),
                ),
            ],
          ),
          const SizedBox(height: defaultPadding),
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
          const Spacer(),
          Row(
            children: [
              if (widget.order.orderStatus == 'PENDING')
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => widget.onProcessSale(widget.order),
                    icon: const Icon(Icons.check_circle),
                    label: const Text('Complete Sale'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                    ),
                  ),
                ),
              const SizedBox(width: 8),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () => _printReceipt(context),
                  icon: const Icon(Icons.print),
                  label: const Text('Print Receipt'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.orange,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _navigateToEdit(BuildContext context) {
    final cartItems = widget.order.items.map((item) => CartItem.fromOrderItem(item)).toList();
    
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => OrderCartPanel(
          orderId: widget.order.id!,
          isEditing: true,
          initialItems: cartItems,
          customerName: widget.order.customerName,
        ),
      ),
    ).then((_) {
      if (mounted) {
        _loadOrderItems();
      }
    });
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
