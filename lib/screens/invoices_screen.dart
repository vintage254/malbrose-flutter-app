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
    if (!mounted) return;
    setState(() => _isLoading = true);
    
    try {
      final List<Invoice> loadedInvoices = [];
      final invoicesData = await DatabaseService.instance.getInvoices(
        startDate: _startDate,
        endDate: _endDate,
        searchQuery: _searchQuery,
      );

      for (var invoiceData in invoicesData) {
        // Load order items for this invoice
        final completedItems = await DatabaseService.instance.getOrderItems(
          invoiceData['id'] as int,
          status: 'COMPLETED',
        );
        
        final pendingItems = await DatabaseService.instance.getOrderItems(
          invoiceData['id'] as int,
          status: 'PENDING',
        );

        // Create Invoice object
        final invoice = Invoice(
          id: invoiceData['id'] as int?,
          invoiceNumber: invoiceData['invoice_number'] as String,
          customerId: invoiceData['customer_id'] as int,
          customerName: invoiceData['customer_name'] as String?,
          totalAmount: (invoiceData['total_amount'] as num).toDouble(),
          completedAmount: (invoiceData['completed_amount'] as num?)?.toDouble() ?? 0.0,
          pendingAmount: (invoiceData['pending_amount'] as num?)?.toDouble() ?? 0.0,
          status: invoiceData['status'] as String,
          paymentStatus: invoiceData['payment_status'] as String,
          createdAt: DateTime.parse(invoiceData['created_at'] as String),
          dueDate: invoiceData['due_date'] != null 
              ? DateTime.parse(invoiceData['due_date'] as String)
              : null,
          completedItems: _mapOrderItems(completedItems),
          pendingItems: _mapOrderItems(pendingItems),
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
          SnackBar(
            content: Text('Failed to load invoices: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  List<OrderItem> _mapOrderItems(List<Map<String, dynamic>> items) {
    return items.map((item) => OrderItem(
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
      final invoice = await DatabaseService.instance.withTransaction((txn) async {
        // Get orders within the same transaction
        final completedOrders = await DatabaseService.instance.getOrdersByCustomerId(
          _selectedCustomer!.id!,
          status: 'COMPLETED',
          txn: txn,
        );
        
        final pendingOrders = await DatabaseService.instance.getOrdersByCustomerId(
          _selectedCustomer!.id!,
          status: 'PENDING',
          txn: txn,
        );

        if (completedOrders.isEmpty && pendingOrders.isEmpty) {
          throw Exception('No orders found for this customer');
        }

        // Calculate totals
        final completedAmount = completedOrders.fold<double>(
          0.0,
          (sum, order) => sum + (order['total_amount'] as num).toDouble(),
        );
        
        final pendingAmount = pendingOrders.fold<double>(
          0.0,
          (sum, order) => sum + (order['total_amount'] as num).toDouble(),
        );

        final newInvoice = Invoice(
          id: null,
          invoiceNumber: await InvoiceService.instance.generateInvoiceNumber(),
          customerId: _selectedCustomer!.id!,
          customerName: _selectedCustomer!.name,
          totalAmount: completedAmount + pendingAmount,
          status: 'PENDING',
          paymentStatus: 'PENDING',
          createdAt: DateTime.now(),
          dueDate: DateTime.now().add(const Duration(days: 30)),
          orderIds: [...completedOrders.map((o) => o['id'] as int), 
                    ...pendingOrders.map((o) => o['id'] as int)],
          completedAmount: completedAmount,
          pendingAmount: pendingAmount,
        );

        // Create invoice within the same transaction
        return await DatabaseService.instance.createInvoiceWithItems(newInvoice);
      });

      // Reload invoices after successful creation
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
      print('Error generating invoice: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error generating invoice: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
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
            child: Padding(
              padding: const EdgeInsets.all(defaultPadding),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: DropdownButtonFormField<Customer>(
                          value: _selectedCustomer,
                          decoration: InputDecoration(
                            labelText: 'Select Customer',
                            prefixIcon: const Icon(Icons.person),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          items: _customers.map((customer) {
                            return DropdownMenuItem(
                              value: customer,
                              child: Text(customer.name),
                            );
                          }).toList(),
                          onChanged: (Customer? customer) {
                            setState(() => _selectedCustomer = customer);
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
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.add),
                        label: const Text('New Invoice'),
                      ),
                    ],
                  ),
                  const SizedBox(height: defaultPadding),
                  if (_isLoading)
                    const Center(child: CircularProgressIndicator())
                  else if (_invoices.isEmpty)
                    Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(
                            Icons.receipt_long_outlined,
                            size: 64,
                            color: Colors.grey,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            _selectedCustomer != null
                              ? 'No invoices found for ${_selectedCustomer!.name}'
                              : 'Select a customer to view invoices',
                            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              color: Colors.grey,
                            ),
                          ),
                        ],
                      ),
                    )
                  else
                    Expanded(
                      child: ListView.builder(
                        itemCount: _invoices.length,
                        itemBuilder: (context, index) {
                          final invoice = _invoices[index];
                          return InvoicePreviewWidget(
                            invoice: invoice,
                            customer: _customers.firstWhere(
                              (c) => c.id == invoice.customerId,
                            ),
                          );
                        },
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