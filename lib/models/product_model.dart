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
      id: map['id'] as int?,
      image: map['image'] as String?,
      supplier: map['supplier'] as String,
      receivedDate: DateTime.parse(map['received_date'] as String),
      productName: map['product_name'] as String,
      buyingPrice: (map['buying_price'] as num).toDouble(),
      sellingPrice: (map['selling_price'] as num).toDouble(),
      quantity: (map['quantity'] as num).toInt(),
      description: map['description'] as String?,
      hasSubUnits: map['has_sub_units'] == 1,
      subUnitQuantity: (map['sub_unit_quantity'] as num?)?.toInt(),
      subUnitPrice: map['sub_unit_price'] as double?,
      subUnitName: map['sub_unit_name'] as String?,
      createdBy: map['created_by'] as int?,
      updatedBy: map['updated_by'] as int?,
    );
  }

  double getSellingPrice({bool isSubUnit = false}) {
    if (isSubUnit && hasSubUnits && subUnitPrice != null) {
      return subUnitPrice!;
    }
    return sellingPrice;
  }

  double getBuyingPrice({bool isSubUnit = false}) {
    if (isSubUnit && hasSubUnits && subUnitQuantity != null && subUnitQuantity! > 0) {
      return buyingPrice / subUnitQuantity!;
    }
    return buyingPrice;
  }
}
