import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:provider/provider.dart';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;


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
import 'package:my_flutter_app/screens/order_history_screen.dart';
import 'package:my_flutter_app/services/database.dart';
import 'package:my_flutter_app/services/order_service.dart';
import 'package:my_flutter_app/screens/held_orders_screen.dart';

import 'package:my_flutter_app/services/auth_service.dart';
import 'package:my_flutter_app/screens/login_screen.dart';
import 'package:my_flutter_app/screens/setup_wizard_screen.dart';
import 'package:my_flutter_app/utils/ui_helpers.dart';

import 'package:my_flutter_app/services/printer_service.dart';
import 'package:my_flutter_app/screens/printer_settings_screen.dart';
import 'package:my_flutter_app/services/config_service.dart';
import 'package:my_flutter_app/screens/backup_screen.dart';
import 'package:my_flutter_app/services/backup_service.dart';

void main() async {

  // Ensure Flutter is initialized
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize sqflite_ffi for desktop
  if (Platform.isWindows || Platform.isLinux) {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  }

  // Set preferred window size for desktop
  if (Platform.isWindows || Platform.isMacOS || Platform.isLinux) {
    try {
      // Set preferred window size
      await SystemChrome.setPreferredOrientations([
        DeviceOrientation.portraitUp,
        DeviceOrientation.landscapeLeft,
        DeviceOrientation.landscapeRight,
      ]);
    } catch (e) {
      print('Error setting window properties: $e');
    }
  }

  // Check if setup is completed
  bool setupCompleted = await checkSetupCompleted();

  // Start the app with providers
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider<OrderService>.value(
          value: OrderService.instance,
        ),
      ],
      child: MyApp(setupCompleted: setupCompleted),
    ),
  );
}

// Check if setup is completed
Future<bool> checkSetupCompleted() async {
  try {
    // Check if database is initialized
    await DatabaseService.instance.initialize();
    // Simple check to see if the app is set up by checking for admin user
    final adminExists = await DatabaseService.instance.checkAdminUserExists();
    return adminExists;
  } catch (e) {
    print('Error checking setup completion: $e');
    return false;
  }
}

class MyApp extends StatelessWidget {
  final bool setupCompleted;
  
  const MyApp({super.key, required this.setupCompleted});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Malbrose App',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
      ),
      scaffoldMessengerKey: UIHelpers.scaffoldMessengerKey,
      // Show setup wizard if setup is not completed, otherwise show home screen
      home: setupCompleted ? const HomeScreen() : const SetupWizardScreen(),
      routes: {
        '/login': (context) => const LoginScreen(),
        '/home': (context) => const HomeScreen(),
        '/main': (context) => const MainScreen(),
        '/orders': (context) => const OrderScreen(),
        '/held-orders':(context) => const HeldOrdersScreen(),
        '/sales': (context) => const SalesScreen(),
        '/products': (context) => const ProductManagementScreen(),
        '/users': (context) => const UserManagementScreen(),
        '/activity': (context) => const ActivityLogScreen(),
        '/creditors': (context) => const CreditorsScreen(),
        '/debtors': (context) => const DebtorsScreen(),
        '/customer-reports': (context) => const CustomerReportsScreen(),
        '/sales-report': (context) => const SalesReportScreen(),
        '/printer-settings': (context) => const PrinterSettingsScreen(),
        '/setup': (context) => const SetupWizardScreen(),
        '/backup': (context) => const BackupScreen(),
        '/order-history': (context) => const OrderHistoryScreen(),
      },
    );
  }
}
