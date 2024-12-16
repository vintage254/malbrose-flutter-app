import 'package:flutter/material.dart';
import 'package:my_flutter_app/const/constant.dart';
import 'package:my_flutter_app/models/product_model.dart';
import 'package:my_flutter_app/services/database.dart';
import 'package:my_flutter_app/screens/product_form_screen.dart';
import 'dart:io';

class DashboardWidget extends StatefulWidget {
  final GlobalKey<DashboardWidgetState> dashboardKey;
  
  const DashboardWidget({
    super.key,
    required this.dashboardKey,
  });

  @override
  State<DashboardWidget> createState() => DashboardWidgetState();
}

class DashboardWidgetState extends State<DashboardWidget> {
  List<Product> _products = [];
  bool _isLoading = true;
  int _currentPage = 0;
  final int _itemsPerPage = 10;
  String _sortColumn = 'product_name';
  bool _sortAscending = true;
  
  // Add ScrollControllers
  final ScrollController _verticalController = ScrollController();
  final ScrollController _horizontalController = ScrollController();

  @override
  void initState() {
    super.initState();
    _loadProducts();
  }

  @override
  void dispose() {
    _verticalController.dispose();
    _horizontalController.dispose();
    super.dispose();
  }

  Future<void> _loadProducts() async {
    if (!mounted) return;

    try {
      setState(() => _isLoading = true);
      final productsData = await DatabaseService.instance.getAllProducts(
        sortColumn: _sortColumn,
        sortAscending: _sortAscending,
      );
      
      if (!mounted) return;
      setState(() {
        _products = productsData.map((map) => Product.fromMap(map)).toList();
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Error loading products: $e');
      if (!mounted) return;
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error loading products: $e')),
      );
    }
  }

  List<Product> get _paginatedProducts {
    final startIndex = _currentPage * _itemsPerPage;
    final endIndex = (startIndex + _itemsPerPage) > _products.length 
        ? _products.length 
        : startIndex + _itemsPerPage;
    return _products.sublist(startIndex, endIndex);
  }

  void _sort<T>(String column, bool ascending) {
    setState(() {
      _sortColumn = column;
      _sortAscending = ascending;
      _loadProducts();
    });
  }

  @override
  Widget build(BuildContext context) {
    final totalPages = (_products.length / _itemsPerPage).ceil();

    return Material(
      child: Container(
        padding: const EdgeInsets.all(defaultPadding),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              const Color.fromARGB(207, 162, 216, 176).withAlpha(179),
              const Color.fromARGB(207, 89, 226, 123),
            ],
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Flexible(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Flexible(
                    child: Text(
                      'Welcome to malbrose hardware and stores pos',
                      style: Theme.of(context).textTheme.titleMedium,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Icon(Icons.notifications),
                ],
              ),
            ),
            const SizedBox(height: defaultPadding),
            if (_isLoading)
              const Center(child: CircularProgressIndicator())
            else
              Expanded(
                child: Material(
                  color: Colors.transparent,
                  child: Container(
                    padding: const EdgeInsets.all(defaultPadding),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            DropdownButton<String>(
                              value: _sortColumn,
                              items: const [
                                DropdownMenuItem(
                                  value: 'product_name',
                                  child: Text('Product Name'),
                                ),
                                DropdownMenuItem(
                                  value: 'supplier',
                                  child: Text('Supplier'),
                                ),
                                DropdownMenuItem(
                                  value: 'buying_price',
                                  child: Text('Buying Price'),
                                ),
                                DropdownMenuItem(
                                  value: 'selling_price',
                                  child: Text('Selling Price'),
                                ),
                              ],
                              onChanged: (value) {
                                if (value != null) {
                                  _sort(value, _sortAscending);
                                }
                              },
                            ),
                            IconButton(
                              icon: Icon(_sortAscending 
                                ? Icons.arrow_upward 
                                : Icons.arrow_downward
                              ),
                              onPressed: () => _sort(_sortColumn, !_sortAscending),
                            ),
                          ],
                        ),
                        const SizedBox(height: defaultPadding / 2),
                        Expanded(
                          child: Scrollbar(
                            controller: _verticalController,
                            thumbVisibility: true,
                            trackVisibility: true,
                            child: SingleChildScrollView(
                              controller: _verticalController,
                              scrollDirection: Axis.vertical,
                              child: Scrollbar(
                                controller: _horizontalController,
                                thumbVisibility: true,
                                trackVisibility: true,
                                notificationPredicate: (notification) => notification.depth == 1,
                                child: SingleChildScrollView(
                                  controller: _horizontalController,
                                  scrollDirection: Axis.horizontal,
                                  child: ConstrainedBox(
                                    constraints: BoxConstraints(
                                      minWidth: MediaQuery.of(context).size.width - (defaultPadding * 4),
                                    ),
                                    child: DataTable(
                                      horizontalMargin: 20,
                                      columnSpacing: 20,
                                      columns: [
                                        DataColumn(
                                          label: Container(
                                            width: 60,
                                            child: const Text('Image'),
                                          ),
                                        ),
                                        const DataColumn(label: Text('Product Name')),
                                        const DataColumn(label: Text('Supplier')),
                                        const DataColumn(label: Text('Buying Price')),
                                        const DataColumn(label: Text('Selling Price')),
                                        const DataColumn(label: Text('Quantity')),
                                        const DataColumn(label: Text('Actions')),
                                      ],
                                      rows: _paginatedProducts.map((product) {
                                        return DataRow(
                                          cells: [
                                            DataCell(
                                              Container(
                                                width: 60,
                                                height: 50,
                                                child: product.image != null
                                                    ? Image.file(
                                                        File(product.image!),
                                                        fit: BoxFit.cover,
                                                      )
                                                    : const Icon(Icons.image_not_supported),
                                              ),
                                            ),
                                            DataCell(Text(product.productName)),
                                            DataCell(Text(product.supplier)),
                                            DataCell(
                                                Text('\$${product.buyingPrice}')),
                                            DataCell(
                                                Text('\$${product.sellingPrice}')),
                                            DataCell(Text('${product.quantity}')),
                                            DataCell(
                                              Row(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  IconButton(
                                                    icon: const Icon(Icons.edit),
                                                    onPressed: () =>
                                                        _editProduct(product),
                                                  ),
                                                  IconButton(
                                                    icon: const Icon(Icons.delete),
                                                    onPressed: () =>
                                                        _deleteProduct(product.id!),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ],
                                        );
                                      }).toList(),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.all(8.0),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              IconButton(
                                icon: const Icon(Icons.arrow_back),
                                onPressed: _currentPage > 0
                                    ? () => setState(() => _currentPage--)
                                    : null,
                              ),
                              Text('${_currentPage + 1} / $totalPages'),
                              IconButton(
                                icon: const Icon(Icons.arrow_forward),
                                onPressed: _currentPage < totalPages - 1
                                    ? () => setState(() => _currentPage++)
                                    : null,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  void _editProduct(Product product) async {
    final result = await showDialog(
      context: context,
      builder: (context) => ProductFormScreen(product: product),
    );
    
    if (result == true && mounted) {
      _loadProducts();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Product updated successfully!'),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  Future<void> _deleteProduct(int id) async {
    if (!mounted) return;

    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirm Delete'),
        content: const Text('Are you sure you want to delete this product?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm != true || !mounted) return;

    try {
      final success = await DatabaseService.instance.deleteProduct(id);
      if (!mounted) return;

      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Product deleted successfully!'),
            backgroundColor: Colors.green,
          ),
        );
        _loadProducts();
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error deleting product: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void refreshProducts() {
    if (mounted) {
      setState(() {
        _isLoading = true;
      });
      _loadProducts().then((_) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Products updated successfully!'),
              backgroundColor: Colors.green,
            ),
          );
        }
      });
    }
  }
}
