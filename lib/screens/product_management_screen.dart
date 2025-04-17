import 'package:flutter/material.dart';
import 'package:my_flutter_app/const/constant.dart';
import 'package:my_flutter_app/models/product_model.dart';
import 'package:my_flutter_app/services/database.dart';
import 'package:my_flutter_app/widgets/side_menu_widget.dart';
import 'package:my_flutter_app/screens/product_form_screen.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:io';
import 'package:permission_handler/permission_handler.dart';
import 'package:share_plus/share_plus.dart';
import 'package:my_flutter_app/widgets/column_mapping_dialog.dart';

class ProductManagementScreen extends StatefulWidget {
  const ProductManagementScreen({super.key});

  @override
  State<ProductManagementScreen> createState() => _ProductManagementScreenState();
}

class _ProductManagementScreenState extends State<ProductManagementScreen> {
  List<Product> _products = [];
  bool _isLoading = true;
  bool _isExporting = false;
  bool _isImporting = false;

  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  String? _selectedDepartment;
  Map<String, dynamic> _importProgress = {
    'message': 'Starting import...',
    'current': 0,
    'total': 0,
    'percentage': 0.0,
    'completed': false,
  };

  @override
  void initState() {
    super.initState();
    _loadProducts();
  }

  Future<void> _loadProducts() async {
    try {
      setState(() {
        _isLoading = true;
      });
      
      // Force database to refresh cached data by adding a timestamp parameter
      final productsData = await DatabaseService.instance.getAllProducts(
        forceRefresh: true,
        timestamp: DateTime.now().millisecondsSinceEpoch,
      );
      
      if (mounted) {
        setState(() {
          try {
            _products = [];
            for (var map in productsData) {
              try {
                final product = Product.fromMap(map);
                _products.add(product);
              } catch (e) {
                print('Error mapping product: $map\nError: $e');
                // Continue with other products instead of failing completely
              }
            }
            _isLoading = false;
          } catch (e) {
            print('Error in product list mapping: $e');
            _isLoading = false;
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Error processing products: $e')),
            );
          }
        });
        
        print('Loaded ${_products.length} products');
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

  void _showProductForm([Product? product]) {
    showDialog(
      context: context,
      builder: (context) => ProductFormScreen(
        product: product,
      ),
    ).then((value) {
      if (value == true) {
        _loadProducts();
      }
    });
  }
  
  Future<void> _exportProducts() async {
    try {
      // Check storage permission
      final status = await Permission.storage.request();
      if (!status.isGranted) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Storage permission is required to export products')),
          );
        }
        return;
      }
      
      setState(() {
        _isExporting = true;
      });
      
      // Show progress dialog
      if (mounted) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => const AlertDialog(
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(),
                SizedBox(height: 16),
                Text('Generating Excel file...'),
              ],
            ),
          ),
        );
      }
      
      // Generate Excel data in memory first
      final tempFilePath = await DatabaseService.instance.exportProductsToExcel();
      
      // Close progress dialog
      if (mounted) {
        Navigator.of(context, rootNavigator: true).pop();
      }
      
      // Ask user for save location
      final dateStr = DateTime.now().toString().split(' ')[0];
      final defaultFileName = 'products_export_$dateStr.xlsx';
      
      String? outputPath = await FilePicker.platform.saveFile(
        dialogTitle: 'Save Excel File',
        fileName: defaultFileName,
        allowedExtensions: ['xlsx'],
        type: FileType.custom,
      );
      
      if (outputPath == null) {
        // User canceled the picker
        setState(() {
          _isExporting = false;
        });
        return;
      }
      
      // Ensure proper extension
      if (!outputPath.toLowerCase().endsWith('.xlsx')) {
        outputPath += '.xlsx';
      }
      
      // Copy the temp file to the chosen location
      final tempFile = File(tempFilePath);
      final finalFile = await tempFile.copy(outputPath);
      
      // Clean up temp file
      try {
        await tempFile.delete();
      } catch (e) {
        print('Error deleting temp file: $e');
        // Continue even if cleanup fails
      }
      
      if (mounted) {
        setState(() {
          _isExporting = false;
        });
        
        // Show success message with option to share the file
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Products exported to ${finalFile.path}'),
            action: SnackBarAction(
              label: 'Share',
              onPressed: () {
                final file = XFile(finalFile.path);
                Share.shareXFiles(
                  [file],
                  subject: 'Product Export',
                  text: 'Exported products from Malbrose POS',
                );
              },
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        // Close progress dialog if open
        Navigator.of(context, rootNavigator: true).popUntil((route) => route.isFirst);
        
        setState(() {
          _isExporting = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error exporting products: $e')),
        );
      }
    }
  }
  
  Future<void> _importProducts() async {
    try {
      // Check storage permission
      final status = await Permission.storage.request();
      if (!status.isGranted) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Storage permission is required to import products')),
          );
        }
        return;
      }
      
      // Pick Excel file
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['xlsx', 'xls'],
      );
      
      if (result == null || result.files.isEmpty) {
        return; // User canceled
      }
      
      final file = result.files.first;
      final filePath = file.path;
      
      if (filePath == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Could not access the selected file')),
          );
        }
        return;
      }
      
      setState(() {
        _isImporting = true;
      });
      
      // Show loading dialog
      if (mounted) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => const AlertDialog(
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(),
                SizedBox(height: 16),
                Text('Reading file headers...'),
              ],
            ),
          ),
        );
      }
      
      // First, read the headers to show in the mapping dialog
      final headersResult = await DatabaseService.instance.readExcelHeaders(filePath);
      
      // Close the loading dialog
      if (mounted) {
        Navigator.of(context).pop();
      }
      
      if (!headersResult['success']) {
        setState(() {
          _isImporting = false;
        });
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(headersResult['message'])),
          );
        }
        return;
      }
      
      final List<String> headers = List<String>.from(headersResult['headers']);
      final Map<String, String> initialMapping = Map<String, String>.from(headersResult['initialMapping'] ?? {});
      
      if (headers.isEmpty) {
        setState(() {
          _isImporting = false;
        });
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('No headers found in the Excel file')),
          );
        }
        return;
      }
      
      // Show the column mapping dialog
      final Map<String, String?>? columnMapping = await showDialog<Map<String, String?>>(
        context: context,
        barrierDismissible: false,
        builder: (context) => ColumnMappingDialog(
          excelHeaders: headers,
          initialMapping: initialMapping,
        ),
      );
      
      if (columnMapping == null) {
        // User canceled the mapping dialog
        setState(() {
          _isImporting = false;
        });
        return;
      }
      
      // Show progress dialog and trigger import outside the dialog
      if (mounted) {
        await _startImportAndShowProgress(filePath, columnMapping);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isImporting = false;
        });
        
        // Close progress dialog if open
        Navigator.of(context, rootNavigator: true).popUntil((route) => route.isFirst);
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error importing products: $e')),
        );
      }
    }
  }

  Future<void> _startImportAndShowProgress(String filePath, Map<String, String?> columnMapping) async {
    // Initialize progress tracking
    setState(() {
      _importProgress = {
        'message': 'Starting import...',
        'current': 0,
        'total': 100, // Initial estimate
        'percentage': 0.0,
        'completed': false,
      };
    });
    
    try {
      // Get real-time progress updates by passing a callback
      await showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => StatefulBuilder(
          builder: (context, setDialogState) {
            // Start the import on first build
            if (_importProgress['current'] == 0 && !_importProgress['completed']) {
              DatabaseService.instance.importProductsFromExcelWithMapping(
                filePath,
                columnMapping,
                (progressData) {
                  if (mounted) {
                    setDialogState(() {
                      _importProgress = progressData;
                    });
                  }
                },
              ).then((finalResult) {
                if (mounted) {
                  setDialogState(() {
                    _importProgress = finalResult;
                  });
                }
              });
            }
            return AlertDialog(
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const SizedBox(height: 20),
                  const CircularProgressIndicator(),
                  const SizedBox(height: 20),
                  Text(_importProgress['message'] ?? 'Starting import...'),
                  const SizedBox(height: 10),
                  LinearProgressIndicator(
                    value: (_importProgress['percentage'] ?? 0.0) / 100,
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'Processed: ${_importProgress['current'] ?? 0} / ${_importProgress['total'] ?? 0}',
                    style: const TextStyle(fontSize: 12),
                  ),
                ],
              ),
              actions: _importProgress['completed'] == true
                  ? [
                      TextButton(
                        onPressed: () {
                          Navigator.of(context).pop();
                          _refreshProductList();
                        },
                        child: const Text('Close'),
                      ),
                    ]
                  : null,
            );
          },
        ),
      );
      // Reset spinner after dialog closes
      if (mounted) {
        setState(() {
          _isImporting = false;
        });
      }
    } catch (e) {
      // Handle any errors
      setState(() {
        _importProgress = {
          'success': false,
          'message': 'Error during import: $e',
          'current': 0,
          'total': 100,
          'percentage': 0.0,
          'completed': true,
        };
      });
      
      // Show error message
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Import error: $e')),
      );
    }

  }

  void _refreshProductList() {
    _loadProducts();
  }

  // Method to clear all products
  Future<void> _clearAllProducts() async {
    // Show confirmation dialog first
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear All Products'),
        content: const Text(
          'Are you sure you want to delete ALL products? This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete All'),
          ),
        ],
      ),
    );
    
    if (confirmed != true) return;
    
    try {
      // Show progress dialog
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const AlertDialog(
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text('Deleting all products...'),
            ],
          ),
        ),
      );
      
      // Delete all products
      final count = await DatabaseService.instance.deleteAllProducts();
      
      // Close progress dialog
      if (mounted) {
        Navigator.of(context).pop();
      }
      
      // Reload products
      await _loadProducts();
      
      // Show success message
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Successfully deleted $count products')),
        );
      }
      
    } catch (e) {
      // Close progress dialog if open
      if (mounted) {
        Navigator.of(context, rootNavigator: true).popUntil((route) => route.isFirst);
      }
      
      // Show error message
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error deleting products: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _showImportDialog() {
    _importProducts();
  }

  @override
  Widget build(BuildContext context) {
    // Filter products by search query and selected department
    final filteredProducts = _products.where((product) {
      final searchLower = _searchQuery.toLowerCase();
      final matchesSearch = product.productName.toLowerCase().contains(searchLower) ||
          product.supplier.toLowerCase().contains(searchLower);
      
      // If department filter is active, check if product matches selected department
      final matchesDepartment = _selectedDepartment == null || product.department == _selectedDepartment;
      
      return matchesSearch && matchesDepartment;
    }).toList();

    return Scaffold(
      floatingActionButton: FloatingActionButton(
        onPressed: _isImporting ? null : _importProducts,
        backgroundColor: _isImporting ? Colors.grey : Theme.of(context).primaryColor,
        child: _isImporting
            ? const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  strokeWidth: 3,
                ),
              )
            : const Icon(Icons.file_upload),
        tooltip: 'Import from Excel',
      ),
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
              child: Padding(
                padding: const EdgeInsets.all(defaultPadding),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // First row with title and action buttons
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Flexible(
                          child: Text(
                            'Product Management',
                            style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 8),
                        // Action buttons in a horizontal scroll view
                        SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              FloatingActionButton(
                                onPressed: () => _showProductForm(),
                                heroTag: 'add_product',
                                tooltip: 'Add Product',
                                child: const Icon(Icons.add),
                              ),
                              const SizedBox(width: 8),
                              FloatingActionButton(
                                onPressed: _isExporting ? null : _exportProducts,
                                heroTag: 'export_products',
                                tooltip: 'Export to Excel',
                                backgroundColor: Colors.green,
                                child: _isExporting
                                    ? const SizedBox(
                                        width: 24,
                                        height: 24,
                                        child: CircularProgressIndicator(
                                          color: Colors.white,
                                          strokeWidth: 2,
                                        ),
                                      )
                                    : const Icon(Icons.file_download),
                              ),
                              const SizedBox(width: 8),
                              FloatingActionButton(
                                onPressed: _isImporting ? null : _showImportDialog,
                                heroTag: 'import_products',
                                tooltip: 'Import from Excel',
                                backgroundColor: Colors.blue,
                                child: _isImporting
                                    ? const SizedBox(
                                        width: 24,
                                        height: 24,
                                        child: CircularProgressIndicator(
                                          color: Colors.white,
                                          strokeWidth: 2,
                                        ),
                                      )
                                    : const Icon(Icons.file_upload),
                              ),
                              const SizedBox(width: 8),
                              FloatingActionButton(
                                onPressed: _clearAllProducts,
                                heroTag: 'clear_all_products',
                                tooltip: 'Clear All Products',
                                backgroundColor: Colors.red,
                                child: const Icon(Icons.delete_forever),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: defaultPadding),
                    // Second row with search bar and department filter
                    Row(
                      children: [
                        // Search field
                        Expanded(
                          flex: 3,
                          child: TextField(
                            controller: _searchController,
                            decoration: InputDecoration(
                              hintText: 'Search products...',
                              prefixIcon: const Icon(Icons.search),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                              filled: true,
                              fillColor: Colors.white,
                            ),
                            onChanged: (value) {
                              setState(() {
                                _searchQuery = value;
                              });
                            },
                          ),
                        ),
                        const SizedBox(width: defaultPadding),
                        // Department filter dropdown
                        Expanded(
                          flex: 2,
                          child: DropdownButtonFormField<String?>(
                            value: _selectedDepartment,
                            decoration: InputDecoration(
                              hintText: 'Filter by department',
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                              filled: true,
                              fillColor: Colors.white,
                            ),
                            items: [
                              const DropdownMenuItem<String?>(
                                value: null,
                                child: Text('All Departments'),
                              ),
                              ...Product.getDepartments().map((dept) => 
                                DropdownMenuItem<String?>(
                                  value: dept,
                                  child: Text(dept),
                                )
                              ),
                            ],
                            onChanged: (value) {
                              setState(() {
                                _selectedDepartment = value;
                              });
                            },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: defaultPadding),
                    Expanded(
                      child: _isLoading
                          ? const Center(child: CircularProgressIndicator())
                          : Card(
                              child: ListView.builder(
                                itemCount: filteredProducts.length,
                                itemBuilder: (context, index) {
                                  final product = filteredProducts[index];
                                  return ListTile(
                                    leading: product.image != null && product.image!.isNotEmpty 
                                      ? ClipRRect(
                                          borderRadius: BorderRadius.circular(8),
                                          child: Image.file(
                                            File(product.image!),
                                            width: 50,
                                            height: 50,
                                            fit: BoxFit.cover,
                                            errorBuilder: (context, error, stackTrace) {
                                              print('Error loading product image: $error');
                                              return const Icon(Icons.inventory, size: 40);
                                            },
                                          ),
                                        )
                                      : const Icon(Icons.inventory),
                                    title: Text(product.productName),
                                    subtitle: Text(
                                      'Supplier: ${product.supplier}\n'
                                      'Quantity: ${product.quantity < 0 ? "OVERSOLD (${product.quantity})" : product.quantity}',
                                      style: TextStyle(
                                        color: product.quantity < 0 ? Colors.red : null,
                                        fontWeight: product.quantity < 0 ? FontWeight.bold : null,
                                      ),
                                    ),
                                    trailing: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Column(
                                          mainAxisSize: MainAxisSize.min,
                                          crossAxisAlignment: CrossAxisAlignment.end,
                                          children: [
                                            Text(
                                              'KSH ${product.sellingPrice.toStringAsFixed(2)}',
                                              style: const TextStyle(
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                            Text(
                                              product.department,
                                              style: TextStyle(
                                                fontSize: 12,
                                                color: Colors.grey.shade700,
                                              ),
                                            ),
                                          ],
                                        ),
                                        IconButton(
                                          icon: const Icon(Icons.edit),
                                          onPressed: () => _showProductForm(product),
                                        ),
                                      ],
                                    ),
                                    isThreeLine: true,
                                  );
                                },
                              ),
                            ),
                    ),
                  ],
                ),
              ),
            ),
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