import 'package:flutter/material.dart';
import 'package:my_flutter_app/models/menu_model.dart';

class SideMenuData {
  final List<MenuModel> menu = [
    const MenuModel(icon: Icons.dashboard, title: 'Dashboard'),
    const MenuModel(icon: Icons.shopping_cart, title: 'Orders'),
    const MenuModel(icon: Icons.point_of_sale, title: 'Sales'),
    const MenuModel(icon: Icons.inventory, title: 'Product Management'),
    const MenuModel(icon: Icons.people, title: 'User Management'),
    const MenuModel(icon: Icons.history, title: 'Activity Logs'),
  ];
}
