import 'package:flutter/material.dart';
import 'package:my_flutter_app/const/constant.dart';
import 'package:my_flutter_app/models/product_model.dart';
import 'package:my_flutter_app/models/order_model.dart';
import 'package:my_flutter_app/services/database.dart';
import 'package:my_flutter_app/widgets/order_receipt_dialog.dart';

class OrderScreen extends StatefulWidget {
  const OrderScreen({super.key});

  @override
  State<OrderScreen> createState() => _OrderScreenState();
}

class _OrderScreenState extends State<OrderScreen> {
  List<Product> _products = [];
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadProducts();
  }

  Future<void> _loadProducts() async {
    try {
      final productsData = await DatabaseService.instance.getAllProducts();
      if (mounted) {
        setState(() {
          _products = productsData.map((map) => Product.fromMap(map)).toList();
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading products: $e')),
        );
      }
    }
  }

  List<Product> get _filteredProducts {
    if (_searchQuery.isEmpty) return _products;
    return _products.where((product) {
      final search = _searchQuery.toLowerCase();
      return product.productName.toLowerCase().contains(search);
    }).toList();
  }

  void _showOrderReceipt(Product product, int quantity) {
    showDialog(
      context: context,
      builder: (context) => OrderReceiptDialog(
        product: product,
        quantity: quantity,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Place Order'),
        backgroundColor: primaryColor,
      ),
      body: Padding(
        padding: const EdgeInsets.all(defaultPadding),
        child: Column(
          children: [
            TextField(
              controller: _searchController,
              decoration: const InputDecoration(
                labelText: 'Search Products',
                prefixIcon: Icon(Icons.search),
              ),
              onChanged: (value) {
                setState(() {
                  _searchQuery = value;
                });
              },
            ),
            const SizedBox(height: defaultPadding),
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : SingleChildScrollView(
                      scrollDirection: Axis.vertical,
                      child: DataTable(
                        columns: const [
                          DataColumn(label: Text('Product Name')),
                          DataColumn(label: Text('Available Qty')),
                          DataColumn(label: Text('Selling Price')),
                          DataColumn(label: Text('Actions')),
                        ],
                        rows: _filteredProducts.map((product) {
                          return DataRow(
                            cells: [
                              DataCell(Text(product.productName)),
                              DataCell(Text(product.quantity.toString())),
                              DataCell(Text(product.sellingPrice.toString())),
                              DataCell(
                                ElevatedButton(
                                  onPressed: () => _showOrderDialog(product),
                                  child: const Text('Make Order'),
                                ),
                              ),
                            ],
                          );
                        }).toList(),
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  void _showOrderDialog(Product product) {
    final quantityController = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Place Order'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Product: ${product.productName}'),
            const SizedBox(height: defaultPadding),
            TextField(
              controller: quantityController,
              decoration: const InputDecoration(labelText: 'Quantity'),
              keyboardType: TextInputType.number,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              final quantity = int.tryParse(quantityController.text);
              if (quantity != null && quantity > 0) {
                try {
                  final order = Order(
                    productId: product.id!,
                    quantity: quantity,
                    sellingPrice: product.sellingPrice,
                    buyingPrice: product.buyingPrice,
                    totalAmount: product.sellingPrice * quantity,
                    createdBy: 1,
                    orderDate: DateTime.now(),
                  );
                  
                  await DatabaseService.instance.createOrder(order);
                  if (!mounted) return;
                  
                  Navigator.pop(context); // Close the dialog
                  _showOrderReceipt(product, quantity);
                  
                } catch (e) {
                  if (!mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Error creating order: $e'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              }
            },
            child: const Text('Confirm'),
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