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
import 'dart:async';

class InvoicesScreen extends StatefulWidget {
  const InvoicesScreen({super.key});

  @override
  State<InvoicesScreen> createState() => _InvoicesScreenState();
}

class _InvoicesScreenState extends State<InvoicesScreen> {
  final TextEditingController _searchController = TextEditingController();
  DateTime? _startDate;
  DateTime? _endDate;
  Customer? _selectedCustomer;
  List<Map<String, dynamic>> _invoiceData = [];
  bool _isLoading = false;
  List<Customer> _customers = [];
  List<Invoice> _invoices = [];
  Timer? _debounceTimer;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _loadInitialData();
  }

  Future<void> _loadInitialData() async {
    setState(() => _isLoading = true);
    try {
      await Future.wait([
        _loadCustomers(),
        _loadInvoices(),
      ]);
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _loadCustomers() async {
    try {
      final customersData = await DatabaseService.instance.getAllCustomers();
      if (mounted) {
        setState(() {
          _customers = customersData
              .map((map) => Customer.fromMap(map))
              .where((customer) => customer.name
                  .toLowerCase()
                  .contains(_searchQuery.toLowerCase()))
              .toList();
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
    setState(() => _isLoading = true);
    try {
      final invoicesData = await DatabaseService.instance.getAllInvoices();
      final List<Invoice> loadedInvoices = [];

      for (var invoiceData in invoicesData) {
        // Filter by customer if selected
        if (_selectedCustomer != null && 
            invoiceData['customer_id'] != _selectedCustomer!.id) {
          continue;
        }
        
        // Filter by date range if selected
        final createdAt = DateTime.parse(invoiceData['created_at'] as String);
        if (_startDate != null && createdAt.isBefore(_startDate!)) {
          continue;
        }
        if (_endDate != null && createdAt.isAfter(_endDate!)) {
          continue;
        }

        // Load order items for this invoice
        final orderItems = await DatabaseService.instance.getOrderItems(invoiceData['id'] as int);
        final items = orderItems.map((item) => OrderItem(
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
        )).toList();

        // Create Invoice object with items
        final invoice = Invoice(
          id: invoiceData['id'] as int?,
          invoiceNumber: invoiceData['invoice_number'] as String,
          customerId: invoiceData['customer_id'] as int,
          customerName: invoiceData['customer_name'] as String?,
          totalAmount: (invoiceData['total_amount'] as num).toDouble(),
          status: invoiceData['status'] as String,
          createdAt: DateTime.parse(invoiceData['created_at'] as String),
          dueDate: invoiceData['due_date'] != null 
              ? DateTime.parse(invoiceData['due_date'] as String)
              : null,
          items: items,
        );

        loadedInvoices.add(invoice);
      }

      if (mounted) {
        setState(() {
          _invoices = loadedInvoices;
          _isLoading = false;
        });
      }
    } catch (e) {
      print('Error loading invoices: $e');
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading invoices: $e')),
        );
      }
    }
  }

  void _onSearchChanged(String query) {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 500), () {
      setState(() {
        _searchQuery = query;
        _loadCustomers();
      });
    });
  }

  Future<void> _selectDateRange() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      initialDateRange: _startDate != null && _endDate != null
          ? DateTimeRange(start: _startDate!, end: _endDate!)
          : null,
    );
    
    if (picked != null && mounted) {
      setState(() {
        _startDate = picked.start;
        _endDate = picked.end;
      });
      _loadInvoices();
    }
  }

  Future<void> _generateInvoice() async {
    if (_selectedCustomer == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a customer')),
      );
      return;
    }

    setState(() => _isLoading = true);
    try {
      final orders = await DatabaseService.instance.getOrdersByCustomerId(_selectedCustomer!.id!);
      final totalAmount = await DatabaseService.instance.calculateCustomerTotal(_selectedCustomer!.id!);

      if (orders.isEmpty) {
        throw Exception('No completed orders found for this customer');
      }

      final invoice = Invoice(
        invoiceNumber: 'INV-${DateTime.now().millisecondsSinceEpoch}',
        customerId: _selectedCustomer!.id!,
        customerName: _selectedCustomer!.name,
        totalAmount: totalAmount,
        status: 'PENDING',
        createdAt: DateTime.now(),
        dueDate: DateTime.now().add(const Duration(days: 30)),
        items: orders.map((order) => OrderItem(
          orderId: order['id'] as int,
          productId: order['product_id'] as int,
          quantity: order['quantity'] as int,
          unitPrice: (order['unit_price'] as num).toDouble(),
          sellingPrice: (order['selling_price'] as num).toDouble(),
          adjustedPrice: (order['adjusted_price'] as num?)?.toDouble() ?? 
                         (order['selling_price'] as num).toDouble(),
          totalAmount: (order['total_amount'] as num).toDouble(),
          productName: order['product_name'] as String,
          isSubUnit: (order['is_sub_unit'] as int?) == 1,
          subUnitName: order['sub_unit_name'] as String?,
        )).toList(),
      );

      await DatabaseService.instance.createInvoice(invoice);
      await _loadInvoices();
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Invoice generated successfully'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error generating invoice: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      setState(() => _isLoading = false);
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
                  // Header with controls
                  Card(
                    margin: const EdgeInsets.all(defaultPadding),
                    child: Padding(
                      padding: const EdgeInsets.all(defaultPadding),
                      child: Column(
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: TextField(
                                  controller: _searchController,
                                  decoration: const InputDecoration(
                                    labelText: 'Search Customers',
                                    prefixIcon: Icon(Icons.search),
                                  ),
                                  onChanged: _onSearchChanged,
                                ),
                              ),
                              const SizedBox(width: defaultPadding),
                              ElevatedButton.icon(
                                onPressed: _selectDateRange,
                                icon: const Icon(Icons.date_range),
                                label: Text(
                                  _startDate != null && _endDate != null
                                      ? '${DateFormat('MMM d').format(_startDate!)} - ${DateFormat('MMM d').format(_endDate!)}'
                                      : 'Select Date Range',
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: defaultPadding),
                          Row(
                            children: [
                              Expanded(
                                child: DropdownButtonFormField<Customer>(
                                  value: _selectedCustomer,
                                  hint: const Text('Select Customer'),
                                  decoration: const InputDecoration(
                                    prefixIcon: Icon(Icons.person),
                                  ),
                                  items: _customers.map((customer) {
                                    return DropdownMenuItem<Customer>(
                                      value: customer,
                                      child: Text(customer.name),
                                    );
                                  }).toSet().toList(),
                                  onChanged: (customer) {
                                    setState(() {
                                      _selectedCustomer = customer;
                                    });
                                    _loadInvoices();
                                  },
                                  isExpanded: true,
                                  selectedItemBuilder: (BuildContext context) {
                                    return _customers.map<Widget>((Customer customer) {
                                      return Text(customer.name);
                                    }).toList();
                                  },
                                ),
                              ),
                              const SizedBox(width: defaultPadding),
                              ElevatedButton.icon(
                                onPressed: _isLoading ? null : _generateInvoice,
                                icon: _isLoading 
                                    ? const SizedBox(
                                        width: 20,
                                        height: 20,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                        ),
                                      )
                                    : const Icon(Icons.add),
                                label: const Text('New Invoice'),
                              ),
                            ],
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
                          : _invoices.isEmpty
                              ? Center(
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      const Icon(
                                        Icons.receipt_long,
                                        size: 64,
                                        color: Colors.grey,
                                      ),
                                      const SizedBox(height: defaultPadding),
                                      Text(
                                        _selectedCustomer != null
                                            ? 'No invoices found for ${_selectedCustomer!.name}'
                                            : 'No invoices found',
                                        style: Theme.of(context).textTheme.titleMedium,
                                      ),
                                    ],
                                  ),
                                )
                              : ListView.builder(
                                  itemCount: _invoices.length,
                                  itemBuilder: (context, index) {
                                    final invoice = _invoices[index];
                                    final customer = _customers.firstWhere(
                                      (c) => c.id == invoice.customerId,
                                      orElse: () => Customer(
                                        name: invoice.customerName ?? 'Unknown Customer',
                                        createdAt: DateTime.now(),
                                      ),
                                    );
                                    
                                    return Card(
                                      margin: const EdgeInsets.symmetric(
                                        horizontal: defaultPadding,
                                        vertical: defaultPadding / 2,
                                      ),
                                      child: ListTile(
                                        leading: CircleAvatar(
                                          backgroundColor: _getStatusColor(invoice.status),
                                          child: const Icon(
                                            Icons.receipt_long,
                                            color: Colors.white,
                                          ),
                                        ),
                                        title: Text(
                                          'Invoice #${invoice.invoiceNumber}',
                                          style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                        subtitle: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text('Customer: ${customer.name}'),
                                            Text(
                                              'Date: ${DateFormat('MMM dd, yyyy').format(invoice.createdAt)}',
                                            ),
                                            if (invoice.dueDate != null)
                                              Text(
                                                'Due: ${DateFormat('MMM dd, yyyy').format(invoice.dueDate!)}',
                                              ),
                                          ],
                                        ),
                                        trailing: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Column(
                                              mainAxisAlignment: MainAxisAlignment.center,
                                              crossAxisAlignment: CrossAxisAlignment.end,
                                              children: [
                                                Text(
                                                  'KSH ${invoice.totalAmount.toStringAsFixed(2)}',
                                                  style: const TextStyle(
                                                    fontWeight: FontWeight.bold,
                                                    fontSize: 16,
                                                  ),
                                                ),
                                                Text(
                                                  invoice.status,
                                                  style: TextStyle(
                                                    color: _getStatusColor(invoice.status),
                                                    fontWeight: FontWeight.bold,
                                                  ),
                                                ),
                                              ],
                                            ),
                                            const SizedBox(width: defaultPadding),
                                            IconButton(
                                              icon: const Icon(Icons.print),
                                              onPressed: () => _printInvoice(invoice, customer),
                                            ),
                                            IconButton(
                                              icon: const Icon(Icons.visibility),
                                              onPressed: () => _showInvoiceDetails(invoice, customer),
                                            ),
                                          ],
                                        ),
                                        isThreeLine: true,
                                        onTap: () => _showInvoiceDetails(invoice, customer),
                                      ),
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
    _debounceTimer?.cancel();
    super.dispose();
  }
} 