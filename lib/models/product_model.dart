class Product {
  final int? id;
  final String? image;
  final String supplier;
  final DateTime receivedDate;
  final String productName;
  final double buyingPrice;
  final double sellingPrice;
  final int quantity;
  final String? description;
  final bool hasSubUnits;
  final int? subUnitQuantity;
  final double? subUnitPrice;
  final String? subUnitName;
  final int? createdBy;
  final int? updatedBy;

  Product({
    this.id,
    this.image,
    required this.supplier,
    required this.receivedDate,
    required this.productName,
    required this.buyingPrice,
    required this.sellingPrice,
    required this.quantity,
    this.description,
    this.hasSubUnits = false,
    this.subUnitQuantity,
    this.subUnitPrice,
    this.subUnitName,
    this.createdBy,
    this.updatedBy,
  });

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'image': image,
      'supplier': supplier,
      'received_date': receivedDate.toIso8601String(),
      'product_name': productName,
      'buying_price': buyingPrice,
      'selling_price': sellingPrice,
      'quantity': quantity,
      'description': description,
      'has_sub_units': hasSubUnits ? 1 : 0,
      'sub_unit_quantity': subUnitQuantity,
      'sub_unit_price': subUnitPrice,
      'sub_unit_name': subUnitName,
      'created_by': createdBy,
      'updated_by': updatedBy,
    };
  }

  factory Product.fromMap(Map<String, dynamic> map) {
    return Product(
      id: map['id'],
      image: map['image'],
      supplier: map['supplier'],
      receivedDate: DateTime.parse(map['received_date']),
      productName: map['product_name'],
      buyingPrice: map['buying_price'],
      sellingPrice: map['selling_price'],
      quantity: map['quantity'],
      description: map['description'],
      hasSubUnits: map['has_sub_units'] == 1,
      subUnitQuantity: map['sub_unit_quantity'],
      subUnitPrice: map['sub_unit_price'],
      subUnitName: map['sub_unit_name'],
      createdBy: map['created_by'],
      updatedBy: map['updated_by'],
    );
  }
}
