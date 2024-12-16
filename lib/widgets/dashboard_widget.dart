import 'package:flutter/material.dart';
import 'package:my_flutter_app/const/constant.dart';
import 'package:my_flutter_app/models/product_model.dart';
import 'package:my_flutter_app/services/database.dart';
import 'package:my_flutter_app/screens/product_form_screen.dart';
import 'dart:io';

class DashboardWidget extends StatefulWidget {
  const DashboardWidget({
    super.key,
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

  // Add search controller
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _loadProducts();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _horizontalController.dispose();
    _verticalController.dispose();
    super.dispose();
  }

  Future<void> _loadProducts() async {
    if (!mounted) return;
    
    setState(() {
      _isLoading = true;
    });

    try {
      final productsData = await DatabaseService.instance.getAllProducts(
        sortColumn: _sortColumn,
        sortAscending: _sortAscending,
      );
      
      if (!mounted) return;
      
      setState(() {
        _products = productsData.map((map) => Product.fromMap(map)).toList();
        if (_sortColumn.isNotEmpty) {
          _sort(_sortColumn, _sortAscending);
        }
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error loading products: $e')),
      );
    }
  }

  // Filter products based on search
  List<Product> get _filteredProducts {
    if (_searchQuery.isEmpty) return _products;
    return _products.where((product) {
      final search = _searchQuery.toLowerCase();
      return product.productName.toLowerCase().contains(search) ||
             product.supplier.toLowerCase().contains(search);
    }).toList();
  }

  // Update pagination to use filtered products
  List<Product> get _paginatedProducts {
    final startIndex = _currentPage * _itemsPerPage;
    final endIndex = (startIndex + _itemsPerPage) > _filteredProducts.length 
        ? _filteredProducts.length 
        : startIndex + _itemsPerPage;
    return _filteredProducts.sublist(startIndex, endIndex);
  }

  void _sort(String column, bool ascending) {
    setState(() {
      _sortColumn = column;
      _sortAscending = ascending;
      _products.sort((a, b) {
        final aValue = _getSortValue(a, column);
        final bValue = _getSortValue(b, column);
        return ascending 
            ? Comparable.compare(aValue, bValue)
            : Comparable.compare(bValue, aValue);
      });
    });
  }

  dynamic _getSortValue(Product product, String column) {
    switch (column) {
      case 'product_name':
        return product.productName.toLowerCase();
      case 'supplier':
        return product.supplier.toLowerCase();
      case 'quantity':
        return product.quantity;
      default:
        return '';
    }
  }

  // Add this method to handle product updates
  Future<void> _handleProductAction(BuildContext context, {Product? product}) async {
    final result = await showDialog(
      context: context,
      builder: (context) => ProductFormScreen(product: product),
    );
    
    if (result == true) {
      await _loadProducts(); // Reload products after successful update/add
    }
  }

  @override
  Widget build(BuildContext context) {
    final totalPages = (_filteredProducts.length / _itemsPerPage).ceil();

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
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      hintText: 'Search products...',
                      prefixIcon: const Icon(Icons.search),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    onChanged: (value) {
                      setState(() {
                        _searchQuery = value;
                      });
                    },
                  ),
                ),
                const SizedBox(width: defaultPadding),
                IconButton(
                  icon: const Icon(Icons.refresh),
                  onPressed: _loadProducts,
                  tooltip: 'Refresh Products',
                ),
                IconButton(
                  icon: const Icon(Icons.add),
                  onPressed: () => _handleProductAction(context),
                  tooltip: 'Add Product',
                ),
              ],
            ),
            const SizedBox(height: defaultPadding),
            if (_isLoading)
              const Center(child: CircularProgressIndicator())
            else
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(defaultPadding),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Column(
                    children: [
                      // Product list with proper scrolling
                      Expanded(
                        child: Scrollbar(
                          controller: _verticalController,
                          thumbVisibility: true,
                          child: Scrollbar(
                            controller: _horizontalController,
                            thumbVisibility: true,
                            notificationPredicate: (notification) => notification.depth == 1,
                            child: SingleChildScrollView(
                              controller: _verticalController,
                              child: SingleChildScrollView(
                                controller: _horizontalController,
                                scrollDirection: Axis.horizontal,
                                child: DataTable(
                                  columnSpacing: 20,
                                  columns: [
                                    const DataColumn(
                                      label: SizedBox(
                                        width: 60,
                                        child: Text('Image'),
                                      ),
                                    ),
                                    DataColumn(
                                      label: const Text('Product Name'),
                                      onSort: (_, __) => _sort('product_name', !_sortAscending),
                                    ),
                                    DataColumn(
                                      label: const Text('Supplier'),
                                      onSort: (_, __) => _sort('supplier', !_sortAscending),
                                    ),
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
                                                icon: const Icon(Icons.edit, size: 20),
                                                onPressed: () => _handleProductAction(context, product: product),
                                              ),
                                              IconButton(
                                                icon: const Icon(Icons.delete, size: 20),
                                                onPressed: () => _deleteProduct(product.id!),
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
                      // Pagination controls
                      Padding(
                        padding: const EdgeInsets.only(top: defaultPadding),
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
          ],
        ),
      ),
    );
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
    _loadProducts();
  }
}
