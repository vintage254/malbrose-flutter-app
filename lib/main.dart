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
import 'package:my_flutter_app/screens/customer_reports_screen.dart';
import 'package:my_flutter_app/screens/sales_report_screen.dart';
import 'package:my_flutter_app/services/database.dart';

void main() async {
  try {
    // Ensure Flutter bindings are initialized first
    WidgetsFlutterBinding.ensureInitialized();
    debugPrint('Flutter bindings initialized');

    // Initialize FFI
    sqfliteFfiInit();
    debugPrint('SQLite FFI initialized');
    
    // Set the databaseFactory to use FFI
    databaseFactory = databaseFactoryFfi;
    debugPrint('Database factory set');
    
    // Initialize database and check for admin user
    await DatabaseService.instance.checkAndCreateAdminUser();
    debugPrint('Admin user checked');
    
    // Add required columns if they don't exist
    await DatabaseService.instance.addUsernameColumnToActivityLogs();
    await DatabaseService.instance.addUpdatedAtColumnToProducts();
    await DatabaseService.instance.addStatusColumnToOrders();
    debugPrint('Database columns updated');
    
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
  } catch (e, stackTrace) {
    debugPrint('Error during app initialization: $e');
    debugPrint('Stack trace: $stackTrace');
    
    // Show error UI instead of crashing
    runApp(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        home: Scaffold(
          appBar: AppBar(
            title: const Text('Malbrose Hardware Store - Error'),
            backgroundColor: Colors.red.shade700,
          ),
          body: Center(
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline, color: Colors.red, size: 80),
                  const SizedBox(height: 20),
                  Text(
                    'Error initializing app: $e',
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.red, fontSize: 16),
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    'Please restart the application. If the problem persists, contact support.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 14),
                  ),
                  const SizedBox(height: 20),
                  ElevatedButton(
                    onPressed: () {
                      // Attempt to restart the app
                      main();
                    },
                    child: const Text('Try Again'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
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
        '/customer-reports': (context) => const CustomerReportsScreen(),
        '/sales-report': (context) => const SalesReportScreen(),
      },
    );
  }
}
