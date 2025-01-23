import 'package:flutter/material.dart';
import 'package:my_flutter_app/const/constant.dart';
import 'package:my_flutter_app/models/customer_model.dart';
import 'package:my_flutter_app/models/invoice_model.dart';
import 'package:my_flutter_app/services/database.dart';
import 'package:my_flutter_app/widgets/side_menu_widget.dart';
import 'package:my_flutter_app/services/invoice_service.dart';
import 'package:intl/intl.dart';
import 'package:my_flutter_app/models/order_model.dart';
import 'package:my_flutter_app/widgets/invoice_preview_widget.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

class InvoicesScreen extends StatefulWidget {
  const InvoicesScreen({super.key});

  @override
  State<InvoicesScreen> createState() => _InvoicesScreenState();
}

class _InvoicesScreenState extends State<InvoicesScreen> {
  Customer? _selectedCustomer;
  List<Customer> _customers = [];
  List<Invoice> _invoices = [];
  bool _isLoading = true;
  final _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadCustomers();
    _loadInvoices();
  }

  Future<void> _loadCustomers() async {
    try {
      final customersData = await DatabaseService.instance.getAllCustomers();
      if (mounted) {
        setState(() {
          _customers = customersData.map((map) => Customer.fromMap(map)).toList();
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading customers: $e')),
        );
      }
    }
  }

  Future<void> _loadInvoices() async {
    try {
      final invoicesData = await DatabaseService.instance.getAllInvoices();
      if (mounted) {
        setState(() {
          _invoices = invoicesData.map((map) => Invoice.fromMap(map)).toList();
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading invoices: $e')),
        );
      }
    }
  }

  Future<void> _generateInvoice() async {
    if (_selectedCustomer == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a customer')),
      );
      return;
    }

    try {
      final orders = await DatabaseService.instance.getOrdersByCustomerId(_selectedCustomer!.id!);
      final totalAmount = await DatabaseService.instance.calculateCustomerTotal(_selectedCustomer!.id!);

      final invoice = Invoice(
        invoiceNumber: 'INV-${DateTime.now().millisecondsSinceEpoch}',
        customerId: _selectedCustomer!.id!,
        totalAmount: totalAmount,
        status: 'PENDING',
        createdAt: DateTime.now(),
        dueDate: DateTime.now().add(const Duration(days: 30)),
        items: orders.map((order) => OrderItem(
          orderId: order['id'] as int,
          productId: order['product_id'] as int,
          quantity: order['quantity'] as int,
          sellingPrice: (order['selling_price'] as num).toDouble(),
          totalAmount: (order['total_amount'] as num).toDouble(),
          productName: order['product_name'] as String,
        )).toList(),
      );

      await DatabaseService.instance.createInvoice(invoice);
      await _loadInvoices();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Invoice generated successfully')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error generating invoice: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Row(
        children: [
          const Expanded(
            flex: 1,
            child: SideMenuWidget(),
          ),
          Expanded(
            flex: 4,
            child: Container(
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
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Customer Selection and Invoice Generation
                  Card(
                    margin: const EdgeInsets.all(defaultPadding),
                    child: Padding(
                      padding: const EdgeInsets.all(defaultPadding),
                      child: Row(
                        children: [
                          Expanded(
                            child: DropdownButtonFormField<Customer>(
                              value: _selectedCustomer,
                              hint: const Text('Select Customer'),
                              items: _customers.map((customer) {
                                return DropdownMenuItem(
                                  value: customer,
                                  child: Text(customer.name),
                                );
                              }).toList(),
                              onChanged: (customer) {
                                setState(() {
                                  _selectedCustomer = customer;
                                });
                              },
                            ),
                          ),
                          const SizedBox(width: defaultPadding),
                          ElevatedButton.icon(
                            onPressed: _generateInvoice,
                            icon: const Icon(Icons.add),
                            label: const Text('New Invoice'),
                          ),
                        ],
                      ),
                    ),
                  ),
                  
                  // Invoices List
                  Expanded(
                    child: Card(
                      margin: const EdgeInsets.all(defaultPadding),
                      child: _isLoading
                          ? const Center(child: CircularProgressIndicator())
                          : ListView.builder(
                              itemCount: _invoices.length,
                              itemBuilder: (context, index) {
                                final invoice = _invoices[index];
                                final customer = _customers.firstWhere(
                                  (c) => c.id == invoice.customerId,
                                  orElse: () => Customer(
                                    name: 'Unknown Customer',
                                    createdAt: DateTime.now(),
                                  ),
                                );
                                
                                return ListTile(
                                  leading: Icon(
                                    Icons.receipt_long,
                                    color: _getStatusColor(invoice.status),
                                  ),
                                  title: Text('Invoice #${invoice.invoiceNumber}'),
                                  subtitle: Text(
                                    'Customer: ${customer.name}\n'
                                    'Date: ${DateFormat('MMM dd, yyyy').format(invoice.createdAt)}',
                                  ),
                                  trailing: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        'KSH ${invoice.totalAmount.toStringAsFixed(2)}',
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      const SizedBox(width: defaultPadding),
                                      IconButton(
                                        icon: const Icon(Icons.print),
                                        onPressed: () => _printInvoice(invoice, customer),
                                      ),
                                    ],
                                  ),
                                  onTap: () => _showInvoiceDetails(invoice, customer),
                                );
                              },
                            ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status.toUpperCase()) {
      case 'PAID':
        return Colors.green;
      case 'PENDING':
        return Colors.orange;
      case 'OVERDUE':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  Future<void> _printInvoice(Invoice invoice, Customer customer) async {
    try {
      await InvoiceService.instance.generateAndPrintInvoice(invoice, customer);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error printing invoice: $e')),
        );
      }
    }
  }

  void _showInvoiceDetails(Invoice invoice, Customer customer) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Invoice #${invoice.invoiceNumber}'),
        content: SizedBox(
          width: 600,
          child: InvoicePreviewWidget(
            invoice: invoice,
            customer: customer,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
          ElevatedButton.icon(
            onPressed: () => _printInvoice(invoice, customer),
            icon: const Icon(Icons.print),
            label: const Text('Print'),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }
} 