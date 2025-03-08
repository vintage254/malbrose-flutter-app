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

  double get unitPrice => product.buyingPrice;
  double get sellingPrice => product.sellingPrice;
  int get productId => product.id!;

  double get effectivePrice => adjustedPrice ?? 
    (isSubUnit && product.subUnitPrice != null ? 
      product.subUnitPrice! : 
      sellingPrice);

  double get effectiveQuantity => isSubUnit && subUnitQuantity != null ?
      quantity / subUnitQuantity! :
      quantity.toDouble();

  double get profit => (effectivePrice - unitPrice) * effectiveQuantity;

  factory CartItem.fromOrderItem(OrderItem orderItem) {
    final product = Product(
      id: orderItem.productId,
      productName: orderItem.productName,
      buyingPrice: orderItem.unitPrice,
      sellingPrice: orderItem.sellingPrice,
      quantity: orderItem.quantity,
      supplier: 'Unknown',
      receivedDate: DateTime.now(),
      subUnitQuantity: orderItem.subUnitQuantity?.toInt(),
      subUnitName: orderItem.subUnitName,
    );

    return CartItem(
      product: product,
      quantity: orderItem.quantity,
      total: orderItem.totalAmount,
      isSubUnit: orderItem.isSubUnit,
      subUnitName: orderItem.subUnitName,
      subUnitQuantity: orderItem.subUnitQuantity?.toInt(),
      adjustedPrice: orderItem.adjustedPrice,
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