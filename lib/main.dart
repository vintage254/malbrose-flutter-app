import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:my_flutter_app/services/order_service.dart';
import 'package:my_flutter_app/screens/order_screen.dart';
import 'package:my_flutter_app/screens/sales_screen.dart';
import 'package:my_flutter_app/screens/product_management_screen.dart';
import 'package:my_flutter_app/screens/user_management_screen.dart';
import 'package:my_flutter_app/screens/activity_log_screen.dart';
import 'package:my_flutter_app/screens/home_screen.dart';
import 'package:my_flutter_app/screens/main_screen.dart';
import 'package:my_flutter_app/screens/creditors_screen.dart';
import 'package:my_flutter_app/screens/debtors_screen.dart';
import 'package:my_flutter_app/screens/customer_reports_screen.dart';
import 'package:my_flutter_app/screens/sales_report_screen.dart';
import 'package:my_flutter_app/services/database.dart';
import 'package:path/path.dart';
import 'dart:io';

void main() async {
  // Initialize FFI
  sqfliteFfiInit();
  // Set the databaseFactory to use FFI
  databaseFactory = databaseFactoryFfi;

  WidgetsFlutterBinding.ensureInitialized();
  
  try {
    // Ensure database directory exists with proper permissions
    final dbPath = await getDatabasesPath();
    final dbDir = Directory(dbPath);
    if (!await dbDir.exists()) {
      await dbDir.create(recursive: true);
    }
    
    // Set permissions for Linux platform
    if (Platform.isLinux) {
      try {
        final result = await Process.run('chmod', ['-R', '777', dbPath]);
        if (result.exitCode != 0) {
          print('Warning: Could not set directory permissions: ${result.stderr}');
        }
      } catch (e) {
        print('Warning: Error setting directory permissions: $e');
      }
    }
    
    // Initialize the database
    await DatabaseService.instance.initialize();
    
    // Create admin user if it doesn't exist
    await DatabaseService.instance.checkAndCreateAdminUser();
    
    // Add required columns if they don't exist
    await DatabaseService.instance.addUsernameColumnToActivityLogs();
    await DatabaseService.instance.addUpdatedAtColumnToProducts();
    await DatabaseService.instance.addStatusColumnToOrders();
  } catch (e) {
    print('Error initializing database: $e');
    // Continue with app startup even if database initialization fails
    // The app will show appropriate error messages when database operations fail
  }
  
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
        '/orders': (context) => const OrderScreen(),
        '/sales': (context) => const SalesScreen(),
        '/products': (context) => const ProductManagementScreen(),
        '/users': (context) => const UserManagementScreen(),
        '/activity': (context) => const ActivityLogScreen(),
        '/creditors': (context) => const CreditorsScreen(),
        '/debtors': (context) => const DebtorsScreen(),
        '/customer-reports': (context) => const CustomerReportsScreen(),
        '/sales-report': (context) => const SalesReportScreen(),
      },
    );
  }
}
