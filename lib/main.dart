import 'package:flutter/material.dart';
import 'package:my_flutter_app/screens/home_screen.dart';
import 'package:my_flutter_app/screens/login_screen.dart';
import 'package:my_flutter_app/screens/dashboard_screen.dart';
import 'package:my_flutter_app/screens/order_screen.dart';
import 'package:my_flutter_app/screens/sales_screen.dart';
import 'package:my_flutter_app/screens/product_screen.dart';
import 'package:my_flutter_app/screens/user_management_screen.dart';
import 'package:my_flutter_app/screens/activity_log_screen.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Malbrose POS',
      theme: ThemeData(
        primarySwatch: Colors.amber,
      ),
      initialRoute: '/',
      routes: {
        '/': (context) => const HomeScreen(),
        '/login': (context) => const LoginScreen(),
        '/dashboard': (context) => const DashboardScreen(),
        '/orders': (context) => const OrderScreen(),
        '/sales': (context) => const SalesScreen(),
        '/products': (context) => const ProductScreen(),
        '/users': (context) => const UserManagementScreen(),
        '/activity-log': (context) => const ActivityLogScreen(),
      },
    );
  }
}
