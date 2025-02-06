import 'package:my_flutter_app/models/order_model.dart';
import 'package:my_flutter_app/models/product_model.dart';

class CartItem {
  final Product product;
  final int quantity;
  final double total;
  final bool isSubUnit;
  final String? subUnitName;
  final int? subUnitQuantity;

  CartItem({
    required this.product,
    required this.quantity,
    required this.total,
    this.isSubUnit = false,
    this.subUnitName,
    this.subUnitQuantity,
  });

  double get unitPrice => product.buyingPrice;
  double get sellingPrice => product.sellingPrice;
  int get productId => product.id!;

  factory CartItem.fromOrderItem(OrderItem orderItem) {
    final product = Product(
      id: orderItem.productId,
      productName: orderItem.productName,
      buyingPrice: orderItem.unitPrice,
      sellingPrice: orderItem.sellingPrice,
      quantity: orderItem.quantity,
      supplier: 'Unknown',
      receivedDate: DateTime.now(),
    );

    return CartItem(
      product: product,
      quantity: orderItem.quantity,
      total: orderItem.totalAmount,
      isSubUnit: orderItem.isSubUnit,
      subUnitName: orderItem.subUnitName,
      subUnitQuantity: orderItem.subUnitQuantity?.toInt(),
    );
  }

  double get effectiveQuantity => isSubUnit && subUnitQuantity != null
      ? quantity / subUnitQuantity!
      : quantity.toDouble();

  double get adjustedPrice => isSubUnit ? unitPrice : sellingPrice;
  double get profit => (adjustedPrice - (isSubUnit ? 
      (unitPrice / (subUnitQuantity ?? 1)) : 
      unitPrice)) * effectiveQuantity;

  Map<String, dynamic> toMap() => {
    'product_id': product.id,
    'quantity': quantity,
    'unit_price': product.buyingPrice,
    'selling_price': product.sellingPrice,
    'total_amount': total,
    'is_sub_unit': isSubUnit ? 1 : 0,
    'sub_unit_name': subUnitName,
    'sub_unit_quantity': subUnitQuantity,
  };
} 