import 'package:flutter/material.dart';
import 'package:my_flutter_app/widgets/side_menu_widget.dart';
import 'package:my_flutter_app/const/constant.dart';
import 'package:my_flutter_app/services/database.dart';
import 'package:my_flutter_app/models/order_model.dart';
import 'package:intl/intl.dart';
import 'package:data_table_2/data_table_2.dart';
import 'package:my_flutter_app/services/printer_service.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

class OrderHistoryScreen extends StatefulWidget {
  const OrderHistoryScreen({super.key});

  @override
  State<OrderHistoryScreen> createState() => _OrderHistoryScreenState();
}

class _OrderHistoryScreenState extends State<OrderHistoryScreen> {
  DateTime _endDate = DateTime.now();
  late DateTime _startDate;
  List<Map<String, dynamic>> _orders = [];
  bool _isLoading = false;
  String _searchQuery = '';
  final _searchController = TextEditingController();
  Order? _selectedOrder;

  @override
  void initState() {
    super.initState();
    // Default to last 30 days
    _startDate = _endDate.subtract(const Duration(days: 30));
    _loadOrders();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadOrders() async {
    if (!mounted) return;

    setState(() => _isLoading = true);

    try {
      final orders = await DatabaseService.instance.getOrdersByDateRange(
        _startDate,
        _endDate.add(const Duration(days: 1)), // Include the end date
      );
      
      if (mounted) {
        setState(() {
          _orders = orders;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading orders: $e')),
        );
      }
    }
  }

  Future<void> _revertReceipt(Order order) async {
    if (!mounted) return;

    setState(() => _isLoading = true);

    try {
      await DatabaseService.instance.revertCompletedOrder(order);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Order successfully reverted'),
            backgroundColor: Colors.green,
          ),
        );
        
        // Reload orders
        _loadOrders();
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error reverting order: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _showOrderDetails(Order order) {
    setState(() {
      _selectedOrder = order;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Row(
        children: [
          const Expanded(flex: 1, child: SideMenuWidget()),
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
              padding: const EdgeInsets.all(defaultPadding),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header with filters
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        const Text(
                          'Order History',
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(width: 20),
                        // Start Date Filter
                        SizedBox(
                          width: 160,
                          child: ElevatedButton.icon(
                            onPressed: () async {
                              final picked = await showDatePicker(
                                context: context,
                                initialDate: _startDate,
                                firstDate: DateTime(2000),
                                lastDate: _endDate,
                              );
                              if (picked != null) {
                                setState(() => _startDate = picked);
                                _loadOrders();
                              }
                            },
                            icon: const Icon(Icons.calendar_today),
                            label: Text(
                              'From: ${DateFormat('dd/MM/yyyy').format(_startDate)}',
                              style: const TextStyle(fontSize: 12),
                            ),
                          ),
                        ),
                        const SizedBox(width: defaultPadding / 2),
                        // End Date Filter
                        SizedBox(
                          width: 160,
                          child: ElevatedButton.icon(
                            onPressed: () async {
                              final picked = await showDatePicker(
                                context: context,
                                initialDate: _endDate,
                                firstDate: _startDate,
                                lastDate: DateTime.now(),
                              );
                              if (picked != null) {
                                setState(() => _endDate = picked);
                                _loadOrders();
                              }
                            },
                            icon: const Icon(Icons.calendar_today),
                            label: Text(
                              'To: ${DateFormat('dd/MM/yyyy').format(_endDate)}',
                              style: const TextStyle(fontSize: 12),
                            ),
                          ),
                        ),
                        const SizedBox(width: defaultPadding),
                        // Refresh Button
                        ElevatedButton.icon(
                          onPressed: _loadOrders,
                          icon: const Icon(Icons.refresh),
                          label: const Text('Refresh'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blue,
                            foregroundColor: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: defaultPadding),
                  // Search field
                  TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      hintText: 'Search orders by number, customer, or status...',
                      prefixIcon: const Icon(Icons.search),
                      filled: true,
                      fillColor: Colors.white,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    ),
                    onChanged: (value) {
                      setState(() {
                        _searchQuery = value;
                      });
                    },
                  ),
                  const SizedBox(height: defaultPadding),
                  // Orders table and details panel
                  Expanded(
                    child: _selectedOrder == null ? _buildOrdersTable() : _buildOrderDetailsPanel(),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOrdersTable() {
    return Card(
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(defaultPadding),
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _filteredOrders.isEmpty
                ? const Center(child: Text('No orders found for the selected date range'))
                : DataTable2(
                    columns: const [
                      DataColumn2(
                        label: Text('Order #'),
                        size: ColumnSize.S,
                      ),
                      DataColumn2(
                        label: Text('Date'),
                        size: ColumnSize.S,
                      ),
                      DataColumn2(
                        label: Text('Customer'),
                        size: ColumnSize.M,
                      ),
                      DataColumn2(
                        label: Text('Total'),
                        size: ColumnSize.S,
                      ),
                      DataColumn2(
                        label: Text('Status'),
                        size: ColumnSize.S,
                      ),
                      DataColumn2(
                        label: Text('Actions'),
                        size: ColumnSize.M,
                      ),
                    ],
                    rows: _filteredOrders.map((orderData) {
                      final isCompleted = orderData['status'] == 'COMPLETED';
                      final isPending = orderData['status'] == 'PENDING';
                      final isReverted = orderData['status'] == 'REVERTED';
                      
                      return DataRow2(
                        onTap: () {
                          // Convert to Order object for details view
                          final order = Order.fromMap(orderData);
                          _showOrderDetails(order);
                        },
                        cells: [
                          DataCell(Text(orderData['order_number'])),
                          DataCell(Text(
                            DateFormat('dd/MM/yyyy').format(
                              DateTime.parse(orderData['created_at']),
                            ),
                          )),
                          DataCell(Text(orderData['customer_name'])),
                          DataCell(Text(
                            'KSH ${NumberFormat('#,##0.00').format(orderData['total_amount'])}',
                          )),
                          DataCell(_buildStatusChip(orderData['status'])),
                          DataCell(
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                // Print button for all orders
                                IconButton(
                                  icon: const Icon(Icons.print, color: Colors.blue),
                                  tooltip: 'Print Receipt',
                                  onPressed: () {
                                    final order = Order.fromMap(orderData);
                                    if (isCompleted) {
                                      _printCompletedReceipt(order);
                                    } else if (isPending) {
                                      _printPendingReceipt(order);
                                    } else if (isReverted) {
                                      _printRevertedReceipt(order);
                                    }
                                  },
                                ),
                                // Revert button for completed orders
                                if (isCompleted)
                                  IconButton(
                                    icon: const Icon(Icons.history, color: Colors.red),
                                    tooltip: 'Revert Receipt',
                                    onPressed: () {
                                      // Show confirmation dialog
                                      showDialog(
                                        context: context,
                                        builder: (context) => AlertDialog(
                                          title: const Text('Confirm Reversion'),
                                          content: const Text(
                                            'Are you sure you want to revert this receipt? This will return the products to inventory and update the sales records. This action cannot be undone.',
                                          ),
                                          actions: [
                                            TextButton(
                                              onPressed: () => Navigator.pop(context),
                                              child: const Text('Cancel'),
                                            ),
                                            TextButton(
                                              onPressed: () {
                                                Navigator.pop(context);
                                                // Convert to Order object and revert
                                                final order = Order.fromMap(orderData);
                                                _revertReceipt(order);
                                              },
                                              style: TextButton.styleFrom(
                                                foregroundColor: Colors.red,
                                              ),
                                              child: const Text('Revert'),
                                            ),
                                          ],
                                        ),
                                      );
                                    },
                                  ),
                              ],
                            ),
                          ),
                        ],
                      );
                    }).toList(),
                  ),
      ),
    );
  }

  Widget _buildOrderDetailsPanel() {
    return Card(
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(defaultPadding),
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Order Details: ${_selectedOrder!.orderNumber}',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () {
                          setState(() {
                            _selectedOrder = null;
                          });
                        },
                      ),
                    ],
                  ),
                  const Divider(),
                  // Order Info
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildInfoRow('Customer', _selectedOrder!.customerName ?? 'Unknown'),
                        _buildInfoRow('Date', DateFormat('dd/MM/yyyy').format(_selectedOrder!.createdAt)),
                        _buildInfoRow('Status', _selectedOrder!.orderStatus),
                        _buildInfoRow('Payment Status', _selectedOrder!.paymentStatus),
                        if (_selectedOrder!.paymentMethod != null)
                          _buildInfoRow('Payment Method', _selectedOrder!.paymentMethod!),
                        _buildInfoRow('Total Amount', 'KSH ${NumberFormat('#,##0.00').format(_selectedOrder!.totalAmount)}'),
                      ],
                    ),
                  ),
                  const Divider(),
                  // Load and display order items
                  FutureBuilder<List<Map<String, dynamic>>>(
                    future: DatabaseService.instance.getOrderItems(_selectedOrder!.id!),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Center(child: CircularProgressIndicator());
                      } else if (snapshot.hasError) {
                        return Center(child: Text('Error: ${snapshot.error}'));
                      } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
                        return const Center(child: Text('No items found for this order'));
                      }
                      
                      final items = snapshot.data!;
                      
                      return Expanded(
                        child: SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: DataTable(
                            columns: const [
                              DataColumn(label: Text('Product')),
                              DataColumn(label: Text('Quantity')),
                              DataColumn(label: Text('Unit Price')),
                              DataColumn(label: Text('Total')),
                            ],
                            rows: items.map((item) {
                              final bool isSubUnit = item['is_sub_unit'] == 1;
                              final String? subUnitName = item['sub_unit_name'] as String?;
                              
                              return DataRow(
                                cells: [
                                  DataCell(Text(item['product_name'] as String)),
                                  DataCell(Text(
                                    '${item['quantity']}${isSubUnit ? " ${subUnitName ?? 'pieces'}" : ""}',
                                  )),
                                  DataCell(Text(
                                    'KSH ${NumberFormat('#,##0.00').format(item['selling_price'])}',
                                  )),
                                  DataCell(Text(
                                    'KSH ${NumberFormat('#,##0.00').format(item['total_amount'])}',
                                  )),
                                ],
                              );
                            }).toList(),
                          ),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: defaultPadding),
                  // Action buttons
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      // Print button based on order status
                      ElevatedButton.icon(
                        icon: const Icon(Icons.print),
                        label: const Text('Print Receipt'),
                        style: ElevatedButton.styleFrom(
                          foregroundColor: Colors.white,
                          backgroundColor: Colors.blue,
                        ),
                        onPressed: () {
                          if (_selectedOrder!.orderStatus == 'COMPLETED') {
                            _printCompletedReceipt(_selectedOrder!);
                          } else if (_selectedOrder!.orderStatus == 'PENDING') {
                            _printPendingReceipt(_selectedOrder!);
                          } else if (_selectedOrder!.orderStatus == 'REVERTED') {
                            _printRevertedReceipt(_selectedOrder!);
                          }
                        },
                      ),
                      const SizedBox(width: 10),
                      // Revert button for completed orders
                      if (_selectedOrder!.orderStatus == 'COMPLETED')
                        ElevatedButton.icon(
                          icon: const Icon(Icons.history),
                          label: const Text('Revert Receipt'),
                          style: ElevatedButton.styleFrom(
                            foregroundColor: Colors.white,
                            backgroundColor: Colors.red,
                          ),
                          onPressed: () {
                            // Show confirmation dialog
                            showDialog(
                              context: context,
                              builder: (context) => AlertDialog(
                                title: const Text('Confirm Reversion'),
                                content: const Text(
                                  'Are you sure you want to revert this receipt? This will return the products to inventory and update the sales records. This action cannot be undone.',
                                ),
                                actions: [
                                  TextButton(
                                    onPressed: () => Navigator.pop(context),
                                    child: const Text('Cancel'),
                                  ),
                                  TextButton(
                                    onPressed: () {
                                      Navigator.pop(context);
                                      _revertReceipt(_selectedOrder!);
                                    },
                                    style: TextButton.styleFrom(
                                      foregroundColor: Colors.red,
                                    ),
                                    child: const Text('Revert'),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                    ],
                  ),
                ],
              ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          Expanded(
            child: Text(value),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusChip(String status) {
    Color color;
    switch (status.toUpperCase()) {
      case 'COMPLETED':
        color = Colors.green;
        break;
      case 'PENDING':
        color = Colors.orange;
        break;
      case 'CANCELLED':
        color = Colors.red;
        break;
      default:
        color = Colors.grey;
    }

    return Chip(
      label: Text(status),
      backgroundColor: color.withOpacity(0.2),
      labelStyle: TextStyle(color: color),
      padding: const EdgeInsets.all(4),
    );
  }

  List<Map<String, dynamic>> get _filteredOrders {
    if (_searchQuery.isEmpty) {
      return _orders;
    }
    
    final query = _searchQuery.toLowerCase();
    return _orders.where((order) {
      final orderNumber = order['order_number'].toString().toLowerCase();
      final customerName = (order['customer_name'] as String).toLowerCase();
      final status = (order['status'] as String).toLowerCase();
      
      return orderNumber.contains(query) || 
             customerName.contains(query) || 
             status.contains(query);
    }).toList();
  }

  // Print receipt for completed order
  Future<void> _printCompletedReceipt(Order order) async {
    if (!mounted) return;
    
    setState(() => _isLoading = true);
    
    try {
      // Fetch order items
      final items = await DatabaseService.instance.getOrderItems(order.id!);
      
      // Create PDF document
      final pdf = pw.Document();
      
      // Get printer service
      final printerService = PrinterService.instance;
      
      // Add receipt page
      pdf.addPage(
        pw.Page(
          pageFormat: printerService.getPageFormat(),
          build: (context) => pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              // Header
              pw.Center(
                child: pw.Text(
                  'RECEIPT',
                  style: pw.TextStyle(
                    fontSize: 18,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
              ),
              pw.SizedBox(height: 10),
              
              // Store info
              pw.Center(
                child: pw.Text(
                  'Malbrose Hardware Store',
                  style: pw.TextStyle(
                    fontSize: 14,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
              ),
              pw.SizedBox(height: 5),
              
              // Order information
              pw.Divider(),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('Receipt No:'),
                  pw.Text(order.orderNumber),
                ],
              ),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('Date:'),
                  pw.Text(DateFormat('dd/MM/yyyy').format(order.createdAt)),
                ],
              ),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('Time:'),
                  pw.Text(DateFormat('HH:mm:ss').format(order.createdAt)),
                ],
              ),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('Customer:'),
                  pw.Text(order.customerName ?? 'Walk-in Customer'),
                ],
              ),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('Status:'),
                  pw.Text(order.orderStatus.toUpperCase()),
                ],
              ),
              pw.Divider(),
              
              // Items table
              pw.Text(
                'Items:',
                style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
              ),
              pw.SizedBox(height: 5),
              
              // Items table header
              pw.Row(
                children: [
                  pw.Expanded(
                    flex: 4,
                    child: pw.Text(
                      'Product',
                      style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                    ),
                  ),
                  pw.Expanded(
                    flex: 2,
                    child: pw.Text(
                      'Qty',
                      style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                      textAlign: pw.TextAlign.center,
                    ),
                  ),
                  pw.Expanded(
                    flex: 2,
                    child: pw.Text(
                      'Price',
                      style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                      textAlign: pw.TextAlign.right,
                    ),
                  ),
                  pw.Expanded(
                    flex: 3,
                    child: pw.Text(
                      'Total',
                      style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                      textAlign: pw.TextAlign.right,
                    ),
                  ),
                ],
              ),
              pw.Divider(thickness: 0.5),
              
              // Items
              pw.Column(
                children: items.map((item) {
                  final bool isSubUnit = item['is_sub_unit'] == 1;
                  final String? subUnitName = item['sub_unit_name'] as String?;
                  
                  return pw.Row(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Expanded(
                        flex: 4,
                        child: pw.Text(item['product_name'] as String),
                      ),
                      pw.Expanded(
                        flex: 2,
                        child: pw.Text(
                          '${item['quantity']}${isSubUnit ? " ${subUnitName ?? 'pc'}" : ""}',
                          textAlign: pw.TextAlign.center,
                        ),
                      ),
                      pw.Expanded(
                        flex: 2,
                        child: pw.Text(
                          NumberFormat('#,##0.00').format(item['selling_price']),
                          textAlign: pw.TextAlign.right,
                        ),
                      ),
                      pw.Expanded(
                        flex: 3,
                        child: pw.Text(
                          NumberFormat('#,##0.00').format(item['total_amount']),
                          textAlign: pw.TextAlign.right,
                        ),
                      ),
                    ],
                  );
                }).toList(),
              ),
              pw.Divider(),
              
              // Totals
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text(
                    'Total Amount:',
                    style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                  ),
                  pw.Text(
                    'KSH ${NumberFormat('#,##0.00').format(order.totalAmount)}',
                    style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                  ),
                ],
              ),
              
              // Payment info
              pw.SizedBox(height: 10),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('Payment Method:'),
                  pw.Text(order.paymentMethod ?? 'Cash'),
                ],
              ),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('Payment Status:'),
                  pw.Text(order.paymentStatus),
                ],
              ),
              
              // Footer
              pw.SizedBox(height: 20),
              pw.Center(
                child: pw.Text(
                  'Thank you for your business!',
                  style: pw.TextStyle(fontStyle: pw.FontStyle.italic),
                ),
              ),
              pw.SizedBox(height: 5),
              pw.Center(
                child: pw.Text(
                  'Powered by Malbrose POS System',
                  style: pw.TextStyle(
                    fontSize: 8,
                    fontStyle: pw.FontStyle.italic,
                  ),
                ),
              ),
              pw.SizedBox(height: 10),
            ],
          ),
        ),
      );
      
      // Print the document
      await printerService.printPdf(
        pdf: pdf,
        documentName: 'Receipt - ${order.orderNumber}',
        context: context,
      );
      
      if (mounted) {
        setState(() => _isLoading = false);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error printing receipt: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
  
  // Print receipt for reverted order
  Future<void> _printRevertedReceipt(Order order) async {
    if (!mounted) return;
    
    setState(() => _isLoading = true);
    
    try {
      // Fetch order items
      final items = await DatabaseService.instance.getOrderItems(order.id!);
      
      // Create PDF document
      final pdf = pw.Document();
      
      // Get printer service
      final printerService = PrinterService.instance;
      
      // Add receipt page
      pdf.addPage(
        pw.Page(
          pageFormat: printerService.getPageFormat(),
          build: (context) => pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              // Header
              pw.Center(
                child: pw.Text(
                  'REVERTED RECEIPT',
                  style: pw.TextStyle(
                    fontSize: 18,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
              ),
              pw.SizedBox(height: 10),
              
              // Store info
              pw.Center(
                child: pw.Text(
                  'Malbrose Hardware Store',
                  style: pw.TextStyle(
                    fontSize: 14,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
              ),
              pw.SizedBox(height: 5),
              
              // Order information
              pw.Divider(),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('Receipt No:'),
                  pw.Text(order.orderNumber),
                ],
              ),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('Original Date:'),
                  pw.Text(DateFormat('dd/MM/yyyy').format(order.createdAt)),
                ],
              ),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('Original Time:'),
                  pw.Text(DateFormat('HH:mm:ss').format(order.createdAt)),
                ],
              ),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('Customer:'),
                  pw.Text(order.customerName ?? 'Walk-in Customer'),
                ],
              ),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('Status:'),
                  pw.Text('REVERTED', style: pw.TextStyle(color: PdfColors.red)),
                ],
              ),
              pw.Divider(),
              
              // Items table
              pw.Text(
                'Items:',
                style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
              ),
              pw.SizedBox(height: 5),
              
              // Items table header
              pw.Row(
                children: [
                  pw.Expanded(
                    flex: 4,
                    child: pw.Text(
                      'Product',
                      style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                    ),
                  ),
                  pw.Expanded(
                    flex: 2,
                    child: pw.Text(
                      'Qty',
                      style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                      textAlign: pw.TextAlign.center,
                    ),
                  ),
                  pw.Expanded(
                    flex: 2,
                    child: pw.Text(
                      'Price',
                      style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                      textAlign: pw.TextAlign.right,
                    ),
                  ),
                  pw.Expanded(
                    flex: 3,
                    child: pw.Text(
                      'Total',
                      style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                      textAlign: pw.TextAlign.right,
                    ),
                  ),
                ],
              ),
              pw.Divider(thickness: 0.5),
              
              // Items
              pw.Column(
                children: items.map((item) {
                  final bool isSubUnit = item['is_sub_unit'] == 1;
                  final String? subUnitName = item['sub_unit_name'] as String?;
                  
                  return pw.Row(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Expanded(
                        flex: 4,
                        child: pw.Text(item['product_name'] as String),
                      ),
                      pw.Expanded(
                        flex: 2,
                        child: pw.Text(
                          '${item['quantity']}${isSubUnit ? " ${subUnitName ?? 'pc'}" : ""}',
                          textAlign: pw.TextAlign.center,
                        ),
                      ),
                      pw.Expanded(
                        flex: 2,
                        child: pw.Text(
                          NumberFormat('#,##0.00').format(item['selling_price']),
                          textAlign: pw.TextAlign.right,
                        ),
                      ),
                      pw.Expanded(
                        flex: 3,
                        child: pw.Text(
                          NumberFormat('#,##0.00').format(item['total_amount']),
                          textAlign: pw.TextAlign.right,
                        ),
                      ),
                    ],
                  );
                }).toList(),
              ),
              pw.Divider(),
              
              // Totals
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text(
                    'Total Amount:',
                    style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                  ),
                  pw.Text(
                    'KSH ${NumberFormat('#,##0.00').format(order.totalAmount)}',
                    style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                  ),
                ],
              ),
              
              // Notice
              pw.SizedBox(height: 15),
              pw.Container(
                padding: const pw.EdgeInsets.all(10),
                decoration: pw.BoxDecoration(
                  border: pw.Border.all(color: PdfColors.red),
                  color: PdfColors.red50,
                ),
                child: pw.Text(
                  'This receipt has been reverted. The products have been returned to inventory and the sales records have been updated.',
                  style: pw.TextStyle(
                    color: PdfColors.red,
                    fontStyle: pw.FontStyle.italic,
                  ),
                ),
              ),
              
              // Footer
              pw.SizedBox(height: 20),
              pw.Center(
                child: pw.Text(
                  'Powered by Malbrose POS System',
                  style: pw.TextStyle(
                    fontSize: 8,
                    fontStyle: pw.FontStyle.italic,
                  ),
                ),
              ),
              pw.SizedBox(height: 10),
            ],
          ),
        ),
      );
      
      // Print the document
      await printerService.printPdf(
        pdf: pdf,
        documentName: 'Reverted Receipt - ${order.orderNumber}',
        context: context,
      );
      
      if (mounted) {
        setState(() => _isLoading = false);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error printing receipt: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
  
  // Print receipt for pending order
  Future<void> _printPendingReceipt(Order order) async {
    if (!mounted) return;
    
    setState(() => _isLoading = true);
    
    try {
      // Fetch order items
      final items = await DatabaseService.instance.getOrderItems(order.id!);
      
      // Create PDF document
      final pdf = pw.Document();
      
      // Get printer service
      final printerService = PrinterService.instance;
      
      // Add receipt page
      pdf.addPage(
        pw.Page(
          pageFormat: printerService.getPageFormat(),
          build: (context) => pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              // Header
              pw.Center(
                child: pw.Text(
                  'ORDER RECEIPT',
                  style: pw.TextStyle(
                    fontSize: 18,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
              ),
              pw.SizedBox(height: 10),
              
              // Store info
              pw.Center(
                child: pw.Text(
                  'Malbrose Hardware Store',
                  style: pw.TextStyle(
                    fontSize: 14,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
              ),
              pw.SizedBox(height: 5),
              
              // Order information
              pw.Divider(),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('Order No:'),
                  pw.Text(order.orderNumber),
                ],
              ),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('Date:'),
                  pw.Text(DateFormat('dd/MM/yyyy').format(order.createdAt)),
                ],
              ),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('Time:'),
                  pw.Text(DateFormat('HH:mm:ss').format(order.createdAt)),
                ],
              ),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('Customer:'),
                  pw.Text(order.customerName ?? 'Walk-in Customer'),
                ],
              ),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('Status:'),
                  pw.Text('PENDING', style: pw.TextStyle(color: PdfColors.orange)),
                ],
              ),
              pw.Divider(),
              
              // Items table
              pw.Text(
                'Items:',
                style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
              ),
              pw.SizedBox(height: 5),
              
              // Items table header
              pw.Row(
                children: [
                  pw.Expanded(
                    flex: 4,
                    child: pw.Text(
                      'Product',
                      style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                    ),
                  ),
                  pw.Expanded(
                    flex: 2,
                    child: pw.Text(
                      'Qty',
                      style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                      textAlign: pw.TextAlign.center,
                    ),
                  ),
                  pw.Expanded(
                    flex: 2,
                    child: pw.Text(
                      'Price',
                      style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                      textAlign: pw.TextAlign.right,
                    ),
                  ),
                  pw.Expanded(
                    flex: 3,
                    child: pw.Text(
                      'Total',
                      style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                      textAlign: pw.TextAlign.right,
                    ),
                  ),
                ],
              ),
              pw.Divider(thickness: 0.5),
              
              // Items
              pw.Column(
                children: items.map((item) {
                  final bool isSubUnit = item['is_sub_unit'] == 1;
                  final String? subUnitName = item['sub_unit_name'] as String?;
                  
                  return pw.Row(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Expanded(
                        flex: 4,
                        child: pw.Text(item['product_name'] as String),
                      ),
                      pw.Expanded(
                        flex: 2,
                        child: pw.Text(
                          '${item['quantity']}${isSubUnit ? " ${subUnitName ?? 'pc'}" : ""}',
                          textAlign: pw.TextAlign.center,
                        ),
                      ),
                      pw.Expanded(
                        flex: 2,
                        child: pw.Text(
                          NumberFormat('#,##0.00').format(item['selling_price']),
                          textAlign: pw.TextAlign.right,
                        ),
                      ),
                      pw.Expanded(
                        flex: 3,
                        child: pw.Text(
                          NumberFormat('#,##0.00').format(item['total_amount']),
                          textAlign: pw.TextAlign.right,
                        ),
                      ),
                    ],
                  );
                }).toList(),
              ),
              pw.Divider(),
              
              // Totals
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text(
                    'Total Amount:',
                    style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                  ),
                  pw.Text(
                    'KSH ${NumberFormat('#,##0.00').format(order.totalAmount)}',
                    style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                  ),
                ],
              ),
              
              // Notice
              pw.SizedBox(height: 15),
              pw.Container(
                padding: const pw.EdgeInsets.all(10),
                decoration: pw.BoxDecoration(
                  border: pw.Border.all(color: PdfColors.orange),
                  color: PdfColors.amber50,
                ),
                child: pw.Text(
                  'This is a pending order. This is not a payment receipt.',
                  style: pw.TextStyle(
                    fontStyle: pw.FontStyle.italic,
                  ),
                ),
              ),
              
              // Footer
              pw.SizedBox(height: 20),
              pw.Center(
                child: pw.Text(
                  'Thank you for your business!',
                  style: pw.TextStyle(fontStyle: pw.FontStyle.italic),
                ),
              ),
              pw.SizedBox(height: 5),
              pw.Center(
                child: pw.Text(
                  'Powered by Malbrose POS System',
                  style: pw.TextStyle(
                    fontSize: 8,
                    fontStyle: pw.FontStyle.italic,
                  ),
                ),
              ),
              pw.SizedBox(height: 10),
            ],
          ),
        ),
      );
      
      // Print the document
      await printerService.printPdf(
        pdf: pdf,
        documentName: 'Pending Order - ${order.orderNumber}',
        context: context,
      );
      
      if (mounted) {
        setState(() => _isLoading = false);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error printing receipt: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
} 