import 'package:my_flutter_app/models/product_model.dart';

class CartItem {
  final Product product;
  int quantity;
  double get total => product.sellingPrice * quantity;

  CartItem({
    required this.product,
    this.quantity = 1,
  });
} 