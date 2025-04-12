import 'package:my_flutter_app/models/order_model.dart';
import 'package:my_flutter_app/models/product_model.dart';

class CartItem {
  final Product product;
  final int quantity;
  final double total;
  final bool isSubUnit;
  final String? subUnitName;
  final int? subUnitQuantity;
  final double? adjustedPrice;

  CartItem({
    required this.product,
    required this.quantity,
    required this.total,
    this.isSubUnit = false,
    this.subUnitName,
    this.subUnitQuantity,
    this.adjustedPrice,
  });

  int get productId => product.id!;
  double get unitPrice => product.buyingPrice;
  double get sellingPrice => adjustedPrice ?? product.sellingPrice;

  double get effectivePrice => adjustedPrice ?? 
    (isSubUnit && product.subUnitPrice != null ? 
      product.subUnitPrice! : 
      sellingPrice);

  double get effectiveQuantity => isSubUnit && subUnitQuantity != null ?
      quantity / subUnitQuantity! :
      quantity.toDouble();

  double get profit => (effectivePrice - unitPrice) * effectiveQuantity;

  // Create CartItem from OrderItem
  static CartItem fromOrderItem(OrderItem item) {
    final product = item.toProductModel();
    
    // Calculate total based on selling price, not unit price
    double effectivePrice = item.adjustedPrice ?? item.sellingPrice;
    double calculatedTotal = item.quantity * effectivePrice;
    
    print('CartItem.fromOrderItem - Recalculating total for ${item.productName}:');
    print('  * Original totalAmount: ${item.totalAmount}');
    print('  * Unit Price: ${item.unitPrice}, Selling Price: ${item.sellingPrice}');
    print('  * Using price: $effectivePrice, Quantity: ${item.quantity}');
    print('  * Recalculated total: $calculatedTotal');
    
    return CartItem(
      product: product,
      quantity: item.quantity,
      total: calculatedTotal, // Use recalculated total based on selling price
      isSubUnit: item.isSubUnit,
      subUnitName: item.subUnitName,
      subUnitQuantity: item.subUnitQuantity?.toInt(),
      adjustedPrice: item.adjustedPrice,
    );
  }

  Map<String, dynamic> toMap() => {
    'product_id': product.id,
    'quantity': quantity,
    'unit_price': product.buyingPrice,
    'selling_price': product.sellingPrice,
    'total_amount': total,
    'is_sub_unit': isSubUnit ? 1 : 0,
    'sub_unit_name': subUnitName,
    'sub_unit_quantity': subUnitQuantity,
    if (adjustedPrice != null) 'adjusted_price': adjustedPrice,
  };
} 