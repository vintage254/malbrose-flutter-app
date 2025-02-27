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
import 'package:my_flutter_app/screens/invoices_screen.dart';
import 'package:my_flutter_app/screens/sales_report_screen.dart';
import 'package:my_flutter_app/services/database.dart';

void main() async {
  try {
    // Ensure Flutter bindings are initialized first
    WidgetsFlutterBinding.ensureInitialized();
    print('Flutter bindings initialized');

    // Initialize FFI
    sqfliteFfiInit();
    print('SQLite FFI initialized');
    
    // Set the databaseFactory to use FFI
    databaseFactory = databaseFactoryFfi;
    print('Database factory set');
    
    // Initialize database and check for admin user
    await DatabaseService.instance.checkAndCreateAdminUser();
    print('Admin user checked');
    
    // Add required columns if they don't exist
    await DatabaseService.instance.addUsernameColumnToActivityLogs();
    await DatabaseService.instance.addUpdatedAtColumnToProducts();
    await DatabaseService.instance.addStatusColumnToOrders();
    print('Database columns updated');
    
    runApp(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<OrderService>.value(
            value: OrderService.instance,
          ),
        ],
        child: MaterialApp(
          title: 'Malbrose Hardware Store',
          debugShowCheckedModeBanner: false,
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
            '/invoices': (context) => const InvoicesScreen(),
            '/sales-report': (context) => const SalesReportScreen(),
          },
        ),
      ),
    );
  } catch (e, stackTrace) {
    print('Error during app initialization: $e');
    print('Stack trace: $stackTrace');
    
    // Show error UI instead of crashing
    runApp(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: Text(
              'Error initializing app: $e\nPlease restart the application.',
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.red),
            ),
          ),
        ),
      ),
    );
  }
}
