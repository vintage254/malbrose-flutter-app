import 'package:flutter/foundation.dart';

class OrderService extends ChangeNotifier {
  static final OrderService instance = OrderService._internal();
  OrderService._internal();

  void notifyOrderUpdate() {
    notifyListeners();
  }
} 