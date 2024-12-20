import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:my_flutter_app/services/order_service.dart';
import 'package:my_flutter_app/screens/dashboard_screen.dart';
import 'package:my_flutter_app/screens/order_screen.dart';
import 'package:my_flutter_app/screens/sales_screen.dart';
import 'package:my_flutter_app/screens/product_management_screen.dart';
import 'package:my_flutter_app/screens/user_management_screen.dart';
import 'package:my_flutter_app/screens/activity_log_screen.dart';
import 'package:my_flutter_app/screens/home_screen.dart';
import 'package:my_flutter_app/screens/main_screen.dart';
import 'package:my_flutter_app/screens/creditors_screen.dart';
import 'package:my_flutter_app/screens/debtors_screen.dart';
import 'package:my_flutter_app/services/database.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // For development only - reset database if needed
  // await DatabaseService.instance.resetDatabase();
  
  // Initialize database and check for admin user
  await DatabaseService.instance.checkAndCreateAdminUser();
  
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider<OrderService>.value(
          value: OrderService.instance,
        ),
      ],
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Malbrose Hardware Store',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.orange),
        useMaterial3: true,
      ),
      home: const HomeScreen(),
      routes: {
        '/main': (context) => const MainScreen(),
        '/dashboard': (context) => const DashboardScreen(),
        '/orders': (context) => const OrderScreen(),
        '/sales': (context) => const SalesScreen(),
        '/products': (context) => const ProductManagementScreen(),
        '/users': (context) => const UserManagementScreen(),
        '/activity': (context) => const ActivityLogScreen(),
        '/creditors': (context) => const CreditorsScreen(),
        '/debtors': (context) => const DebtorsScreen(),
      },
    );
  }
}
