import 'package:flutter/material.dart';
import 'package:my_flutter_app/const/constant.dart';
import 'package:my_flutter_app/models/product_model.dart';
import 'package:my_flutter_app/services/database.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import 'package:my_flutter_app/services/auth_service.dart';

class ProductFormScreen extends StatefulWidget {
  final Product? product;

  const ProductFormScreen({super.key, this.product});

  @override
  State<ProductFormScreen> createState() => _ProductFormScreenState();
}

class _ProductFormScreenState extends State<ProductFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _supplierController = TextEditingController();
  final _productNameController = TextEditingController();
  final _buyingPriceController = TextEditingController();
  final _sellingPriceController = TextEditingController();
  final _quantityController = TextEditingController();
  final _descriptionController = TextEditingController();
  final DateTime _receivedDate = DateTime.now();
  XFile? _imageFile;
  final ImagePicker _picker = ImagePicker();
  final _subUnitNameController = TextEditingController();
  final _subUnitQuantityController = TextEditingController();
  final _subUnitPriceController = TextEditingController();
  bool _hasSubUnits = false;

  @override
  void initState() {
    super.initState();
    if (widget.product != null) {
      _supplierController.text = widget.product!.supplier;
      _productNameController.text = widget.product!.productName;
      _buyingPriceController.text = widget.product!.buyingPrice.toString();
      _sellingPriceController.text = widget.product!.sellingPrice.toString();
      _quantityController.text = widget.product!.quantity.toString();
      _descriptionController.text = widget.product!.description ?? '';
      _hasSubUnits = widget.product!.hasSubUnits;
      if (_hasSubUnits) {
        _subUnitNameController.text = widget.product!.subUnitName ?? '';
        _subUnitQuantityController.text = widget.product!.subUnitQuantity?.toString() ?? '';
        _subUnitPriceController.text = widget.product!.subUnitPrice?.toString() ?? '';
      }
      if (widget.product!.image != null) {
        _imageFile = XFile(widget.product!.image!);
      }
    }
  }

  Future<void> _pickImage() async {
    if (!mounted) return;

    try {
      final XFile? pickedFile = await _picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 80, // Compress image
      );

      if (!mounted) return;

      if (pickedFile != null) {
        // Get application documents directory
        final appDir = await getApplicationDocumentsDirectory();
        final fileName = '${DateTime.now().millisecondsSinceEpoch}.jpg';
        final savedImage = File('${appDir.path}/products/$fileName');

        // Create the products directory if it doesn't exist
        await Directory('${appDir.path}/products').create(recursive: true);

        // Copy the picked image to app's directory
        await File(pickedFile.path).copy(savedImage.path);

        setState(() {
          _imageFile = XFile(savedImage.path);
        });
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error picking image: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: Container(
        padding: const EdgeInsets.all(defaultPadding),
        width: 500,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  widget.product == null ? 'Add New Product' : 'Edit Product',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: defaultPadding),
                GestureDetector(
                  onTap: _pickImage,
                  child: Container(
                    width: 150,
                    height: 150,
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: _imageFile != null
                        ? ClipRRect(
                            borderRadius: BorderRadius.circular(10),
                            child: Image.file(
                              File(_imageFile!.path),
                              fit: BoxFit.cover,
                            ),
                          )
                        : Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: const [
                              Icon(Icons.add_photo_alternate_outlined),
                              SizedBox(height: 8),
                              Text('Add Product Image'),
                            ],
                          ),
                  ),
                ),
                const SizedBox(height: defaultPadding),
                TextFormField(
                  controller: _productNameController,
                  decoration: const InputDecoration(labelText: 'Product Name'),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter product name';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: defaultPadding),
                TextFormField(
                  controller: _supplierController,
                  decoration: const InputDecoration(labelText: 'Supplier'),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter supplier name';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: defaultPadding),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _buyingPriceController,
                        decoration:
                            const InputDecoration(labelText: 'Buying Price'),
                        keyboardType: TextInputType.number,
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Please enter buying price';
                          }
                          if (double.tryParse(value) == null) {
                            return 'Please enter a valid number';
                          }
                          return null;
                        },
                      ),
                    ),
                    const SizedBox(width: defaultPadding),
                    Expanded(
                      child: TextFormField(
                        controller: _sellingPriceController,
                        decoration:
                            const InputDecoration(labelText: 'Selling Price'),
                        keyboardType: TextInputType.number,
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Please enter selling price';
                          }
                          if (double.tryParse(value) == null) {
                            return 'Please enter a valid number';
                          }
                          return null;
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: defaultPadding),
                TextFormField(
                  controller: _quantityController,
                  decoration: const InputDecoration(labelText: 'Quantity'),
                  keyboardType: TextInputType.number,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter quantity';
                    }
                    if (int.tryParse(value) == null) {
                      return 'Please enter a valid number';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: defaultPadding),
                TextFormField(
                  controller: _descriptionController,
                  decoration: const InputDecoration(labelText: 'Description'),
                  maxLines: 3,
                ),
                const SizedBox(height: defaultPadding),
                SwitchListTile(
                  title: const Text('Has Sub Units'),
                  subtitle: const Text('e.g., Box of nails sold individually'),
                  value: _hasSubUnits,
                  onChanged: (bool value) {
                    setState(() {
                      _hasSubUnits = value;
                    });
                  },
                ),
                if (_hasSubUnits) ...[
                  TextFormField(
                    controller: _subUnitNameController,
                    decoration: const InputDecoration(
                      labelText: 'Sub Unit Name',
                      hintText: 'e.g., piece, nail, packet',
                    ),
                    validator: _hasSubUnits ? (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter sub unit name';
                      }
                      return null;
                    } : null,
                  ),
                  TextFormField(
                    controller: _subUnitQuantityController,
                    decoration: const InputDecoration(
                      labelText: 'Number of Sub Units',
                      hintText: 'e.g., 300 nails in a box',
                    ),
                    keyboardType: TextInputType.number,
                    validator: _hasSubUnits ? (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter number of sub units';
                      }
                      if (int.tryParse(value) == null || int.parse(value) <= 0) {
                        return 'Please enter a valid number';
                      }
                      return null;
                    } : null,
                  ),
                  TextFormField(
                    controller: _subUnitPriceController,
                    decoration: const InputDecoration(
                      labelText: 'Price per Sub Unit',
                      hintText: 'e.g., 2 KSH per nail',
                    ),
                    keyboardType: TextInputType.number,
                    validator: _hasSubUnits ? (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter price per sub unit';
                      }
                      if (double.tryParse(value) == null || double.parse(value) <= 0) {
                        return 'Please enter a valid price';
                      }
                      return null;
                    } : null,
                  ),
                ],
                const SizedBox(height: defaultPadding),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Cancel'),
                    ),
                    const SizedBox(width: defaultPadding),
                    ElevatedButton(
                      onPressed: _saveProduct,
                      child: const Text('Save'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _saveProduct() async {
    if (!_formKey.currentState!.validate()) return;

      String? imagePath;
      if (_imageFile != null) {
        final appDir = await getApplicationDocumentsDirectory();
      final fileName = '${DateTime.now().millisecondsSinceEpoch}.jpg';
      final savedImage = File('${appDir.path}/products/$fileName');
      
      // Create products directory if it doesn't exist
      await Directory('${appDir.path}/products').create(recursive: true);
      
        await File(_imageFile!.path).copy(savedImage.path);
        imagePath = savedImage.path;
      }

    final currentUser = AuthService.instance.currentUser;
    if (currentUser == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('User not logged in')),
      );
      return;
    }

    try {
      if (widget.product != null) {
        // Update existing product
        final updatedProduct = Product(
          id: widget.product!.id,
          image: imagePath ?? widget.product!.image,
        supplier: _supplierController.text,
        receivedDate: _receivedDate,
        productName: _productNameController.text,
        buyingPrice: double.parse(_buyingPriceController.text),
        sellingPrice: double.parse(_sellingPriceController.text),
        quantity: int.parse(_quantityController.text),
        description: _descriptionController.text,
        hasSubUnits: _hasSubUnits,
        subUnitName: _subUnitNameController.text,
        subUnitQuantity: _subUnitQuantityController.text.isEmpty ? null : int.parse(_subUnitQuantityController.text),
        subUnitPrice: _subUnitPriceController.text.isEmpty ? null : double.parse(_subUnitPriceController.text),
          createdBy: widget.product!.createdBy,
          updatedBy: currentUser.id,
        );

        await DatabaseService.instance.updateProduct(updatedProduct.toMap());
        } else {
        // Create new product
        final newProduct = Product(
          image: imagePath,
          supplier: _supplierController.text,
          receivedDate: _receivedDate,
          productName: _productNameController.text,
          buyingPrice: double.parse(_buyingPriceController.text),
          sellingPrice: double.parse(_sellingPriceController.text),
          quantity: int.parse(_quantityController.text),
          description: _descriptionController.text,
          hasSubUnits: _hasSubUnits,
          subUnitName: _subUnitNameController.text,
          subUnitQuantity: _subUnitQuantityController.text.isEmpty ? null : int.parse(_subUnitQuantityController.text),
          subUnitPrice: _subUnitPriceController.text.isEmpty ? null : double.parse(_subUnitPriceController.text),
          createdBy: currentUser.id,
        );

        await DatabaseService.instance.insertProduct(newProduct.toMap());
      }

      // Log the activity
          await DatabaseService.instance.logActivity({
        'user_id': currentUser.id,
        'action': widget.product != null ? 'update_product' : 'create_product',
        'details': '${widget.product != null ? 'Updated' : 'Created'} product: ${_productNameController.text}',
            'timestamp': DateTime.now().toIso8601String(),
          });

        if (!mounted) return;
        Navigator.pop(context, true);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Product saved successfully!'),
            backgroundColor: Colors.green,
          ),
        );
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error saving product: $e')),
        );
    }
  }

  @override
  void dispose() {
    _supplierController.dispose();
    _productNameController.dispose();
    _buyingPriceController.dispose();
    _sellingPriceController.dispose();
    _quantityController.dispose();
    _descriptionController.dispose();
    _subUnitNameController.dispose();
    _subUnitQuantityController.dispose();
    _subUnitPriceController.dispose();
    super.dispose();
  }
}
