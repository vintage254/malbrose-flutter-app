class Product {
  final int? id;
  final String? image;
  final String supplier;
  final DateTime receivedDate;
  final String productName;
  final double buyingPrice;
  final double sellingPrice;
  /// Quantity of the product in stock
  /// Note: Negative values are allowed and represent oversold items.
  /// A negative quantity indicates that more units have been sold
  /// than were available in inventory.
  final int quantity;
  final String? description;
  final bool hasSubUnits;
  final int? subUnitQuantity;
  final double? subUnitPrice;
  final double? subUnitBuyingPrice;
  final String? subUnitName;
  final int? createdBy;
  final int? updatedBy;
  final int? numberOfSubUnits;
  final double? pricePerSubUnit;
  /// Department categorization for the product
  /// Uses one of the predefined department options
  final String department;

  // Predefined department options
  static const String deptPlumbing = 'Plumbing materials';
  static const String deptConstruction = 'Construction material';
  static const String deptElectrical = 'Electrical appliance';
  static const String deptMetals = 'Metal bars & Tubes';
  static const String deptNewArrivals = 'New arrivals';
  static const String deptPaints = 'Paints & Painting items';
  static const String deptLubricants = 'Lubricants & others';

  // List of all available departments
  static List<String> getDepartments() {
    return [
      deptPlumbing,
      deptConstruction,
      deptElectrical,
      deptMetals,
      deptNewArrivals,
      deptPaints,
      deptLubricants,
    ];
  }

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
    this.subUnitBuyingPrice,
    this.subUnitName,
    this.createdBy,
    this.updatedBy,
    this.numberOfSubUnits,
    this.pricePerSubUnit,
    this.department = deptLubricants, // Default to Lubricants & others
  });

  Product copyWith({
    int? id,
    String? image,
    String? supplier,
    DateTime? receivedDate,
    String? productName,
    double? buyingPrice,
    double? sellingPrice,
    int? quantity,
    String? description,
    bool? hasSubUnits,
    int? subUnitQuantity,
    double? subUnitPrice,
    double? subUnitBuyingPrice,
    String? subUnitName,
    int? createdBy,
    int? updatedBy,
    int? numberOfSubUnits,
    double? pricePerSubUnit,
    String? department,
  }) {
    return Product(
      id: id ?? this.id,
      image: image ?? this.image,
      supplier: supplier ?? this.supplier,
      receivedDate: receivedDate ?? this.receivedDate,
      productName: productName ?? this.productName,
      buyingPrice: buyingPrice ?? this.buyingPrice,
      sellingPrice: sellingPrice ?? this.sellingPrice,
      quantity: quantity ?? this.quantity,
      description: description ?? this.description,
      hasSubUnits: hasSubUnits ?? this.hasSubUnits,
      subUnitQuantity: subUnitQuantity ?? this.subUnitQuantity,
      subUnitPrice: subUnitPrice ?? this.subUnitPrice,
      subUnitBuyingPrice: subUnitBuyingPrice ?? this.subUnitBuyingPrice,
      subUnitName: subUnitName ?? this.subUnitName,
      createdBy: createdBy ?? this.createdBy,
      updatedBy: updatedBy ?? this.updatedBy,
      numberOfSubUnits: numberOfSubUnits ?? this.numberOfSubUnits,
      pricePerSubUnit: pricePerSubUnit ?? this.pricePerSubUnit,
      department: department ?? this.department,
    );
  }

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
      'sub_unit_buying_price': subUnitBuyingPrice,
      'sub_unit_name': subUnitName,
      'created_by': createdBy,
      'updated_by': updatedBy,
      'number_of_sub_units': numberOfSubUnits,
      'price_per_sub_unit': pricePerSubUnit,
      'department': department,
    };
  }

  // Method specifically for Excel export
  Map<String, dynamic> toExcelMap() {
    return {
      'product name': productName,
      'Description': description ?? '',
      'buying_price': buyingPrice,
      'selling_price': sellingPrice,
      'supplier': supplier,
      'quantity': quantity,
      'sub unit name': subUnitName ?? '',
      'no of sub units': numberOfSubUnits ?? '',
      'Department': department,
    };
  }

  // List of standard field names used for Excel export/import
  static List<String> getExcelHeaders() {
    return [
      'product name',
      'Description',
      'buying_price',
      'selling_price',
      'supplier',
      'quantity',
      'sub unit name',
      'no of sub units',
      'Department',
    ];
  }

  // Maps Excel column headers to database field names
  static Map<String, String> getHeaderMappings() {
    return {
      'product name': 'product_name',
      'product_name': 'product_name',
      'Product Name': 'product_name',
      'Description': 'description',
      'buying_price': 'buying_price',
      'Buying Price': 'buying_price',
      'selling_price': 'selling_price',
      'Selling Price': 'selling_price',
      'quantity': 'quantity',
      'Quantity': 'quantity',
      'supplier': 'supplier',
      'Supplier': 'supplier',
      'sub unit name': 'sub_unit_name',
      'Sub Unit Name': 'sub_unit_name',
      'no of sub units': 'number_of_sub_units',
      'Number of Sub Units': 'number_of_sub_units',
      'Department': 'department',
      'department': 'department',
    };
  }

  // Alternate header mappings (for flexible import)
  static Map<String, String> getAlternateHeaderMappings() {
    return {
      'name': 'product_name',
      'product': 'product_name',
      'item name': 'product_name',
      'item': 'product_name',
      'desc': 'description',
      'details': 'description',
      'cost': 'buying_price',
      'cost price': 'buying_price',
      'buy price': 'buying_price',
      'purchase price': 'buying_price',
      'price': 'selling_price',
      'retail price': 'selling_price',
      'sale price': 'selling_price',
      'qty': 'quantity',
      'stock': 'quantity',
      'inventory': 'quantity',
      'vendor': 'supplier',
      'manufacturer': 'supplier',
      'distributor': 'supplier',
      'unit name': 'sub_unit_name',
      'sub unit': 'sub_unit_name',
      'unit': 'sub_unit_name',
      'sub units': 'number_of_sub_units',
      'units per item': 'number_of_sub_units',
      'unit count': 'number_of_sub_units',
      'units': 'number_of_sub_units',
      'sub unit price': 'price_per_sub_unit',
      'unit price': 'price_per_sub_unit',
      'dept': 'department',
      'category': 'department',
      'classification': 'department',
      'type': 'department',
    };
  }

  // Helper method to normalize department value to predefined options
  static String normalizeDepartment(String? value) {
    if (value == null || value.isEmpty) {
      return deptLubricants;
    }
    
    // Clean and lowercase for comparison
    final cleanValue = value.trim().toLowerCase();
    
    // Check if the value contains any of our department keywords
    if (cleanValue.contains('plumb')) return deptPlumbing;
    if (cleanValue.contains('construct')) return deptConstruction;
    if (cleanValue.contains('electric')) return deptElectrical;
    if (cleanValue.contains('metal') || cleanValue.contains('tube')) return deptMetals;
    if (cleanValue.contains('new') || cleanValue.contains('arrival')) return deptNewArrivals;
    if (cleanValue.contains('paint')) return deptPaints;
    if (cleanValue.contains('lubric')) return deptLubricants;
    
    // Default
    return deptLubricants;
  }

  factory Product.fromMap(Map<String, dynamic> map) {
    return Product(
      id: map['id'] as int?,
      image: map['image'] as String?,
      supplier: map['supplier'] as String,
      receivedDate: DateTime.parse(map['received_date'] as String),
      productName: map['product_name'] as String,
      buyingPrice: (map['buying_price'] is int)
          ? (map['buying_price'] as int).toDouble()
          : (map['buying_price'] as num?)?.toDouble() ?? 0.0,
      sellingPrice: (map['selling_price'] is int)
          ? (map['selling_price'] as int).toDouble()
          : (map['selling_price'] as num?)?.toDouble() ?? 0.0,
      quantity: map['quantity'] == null 
          ? 0 
          : (map['quantity'] is double) 
              ? (map['quantity'] as double).toInt() 
              : (map['quantity'] as num).toInt(),
      description: map['description'] as String?,
      hasSubUnits: map['has_sub_units'] == 1,
      subUnitQuantity: (map['sub_unit_quantity'] as num?)?.toInt(),
      subUnitPrice: map['sub_unit_price'] as double?,
      subUnitBuyingPrice: (map['sub_unit_buying_price'] as num?)?.toDouble(),
      subUnitName: map['sub_unit_name'] as String?,
      createdBy: map['created_by'] as int?,
      updatedBy: map['updated_by'] as int?,
      numberOfSubUnits: map['number_of_sub_units'],
      pricePerSubUnit: (map['price_per_sub_unit'] is int)
          ? (map['price_per_sub_unit'] as int).toDouble()
          : (map['price_per_sub_unit'] as num?)?.toDouble(),
      department: map['department'] as String? ?? deptLubricants,
    );
  }

  double getSellingPrice({bool isSubUnit = false}) {
    if (isSubUnit && hasSubUnits && subUnitPrice != null) {
      return subUnitPrice!;
    }
    return sellingPrice;
  }

  double getBuyingPrice({bool isSubUnit = false}) {
    if (isSubUnit && hasSubUnits) {
      // Use custom sub-unit buying price if available
      if (subUnitBuyingPrice != null) {
        return subUnitBuyingPrice!;
      }
      // Fall back to calculated price if custom price not set
      else if (subUnitQuantity != null && subUnitQuantity! > 0) {
        return buyingPrice / subUnitQuantity!;
      }
    }
    return buyingPrice;
  }
}
