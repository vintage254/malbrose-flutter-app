import 'package:my_flutter_app/models/menu_model.dart';
import 'package:my_flutter_app/assets/icons.dart';

class SideMenuData {
  final menu = const <MenuModel>[
    MenuModel(icon: AppIcons.home, title: 'Dashboard'),
    MenuModel(icon: AppIcons.user, title: 'user management'),
    MenuModel(icon: AppIcons.product, title: 'product management'),
    MenuModel(icon: AppIcons.orders, title: 'orders'),
    MenuModel(icon: AppIcons.auth, title: 'authentication'),
  ];
}
