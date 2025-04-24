import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:provider/provider.dart';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' show join;

import 'package:my_flutter_app/screens/order_screen.dart';
import 'package:my_flutter_app/screens/sales_screen.dart';
import 'package:my_flutter_app/screens/product_management_screen.dart';
import 'package:my_flutter_app/screens/settings_screen.dart';
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
import 'package:my_flutter_app/screens/license_check_screen.dart';

void main() async {

  // Ensure Flutter is initialized
  WidgetsFlutterBinding.ensureInitialized();
  print('Flutter initialized');

  // Initialize sqflite_ffi for desktop
  if (Platform.isWindows || Platform.isLinux) {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    print('SQLite FFI initialized for desktop');
  }

  // Set preferred window size for desktop
  if (Platform.isWindows || Platform.isMacOS || Platform.isLinux) {
    try {
      // Set preferred window orientations
      await SystemChrome.setPreferredOrientations([
        DeviceOrientation.portraitUp,
        DeviceOrientation.landscapeLeft,
        DeviceOrientation.landscapeRight,
      ]);
      
      // Ensure window is positioned correctly and of a reasonable size
      print('Window orientation set');
      print('Make sure your app window is not off-screen or minimized');
      print('Check the taskbar or system tray for the app icon');
    } catch (e) {
      print('Error setting window properties: $e');
    }
  }

  // REMOVED: Don't reset database on startup
  // This was only needed for initial setup/testing
  // await cleanStartApp();

  // Initialize ConfigService
  print('Initializing ConfigService...');
  await ConfigService.instance.initialize();
  print('ConfigService initialized');

  // Check if setup is completed
  print('Checking if setup is completed...');
  bool setupCompleted = await checkSetupCompleted();
  print('Setup completed: $setupCompleted');

  // Start the app with providers
  print('Starting app with providers');
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
  print('App started');
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
    
    // If there's a database error, try to reset and recreate it
    if (e.toString().contains('database') || 
        e.toString().contains('file') || 
        e.toString().contains('SQL')) {
      print('Attempting database recovery due to initialization error');
      try {
        // Try to reset and recreate the database
        await DatabaseService.instance.resetAndRecreateDatabase();
        // Check again if admin exists
        return await DatabaseService.instance.checkAdminUserExists();
      } catch (resetError) {
        print('Critical error during database recovery: $resetError');
        return false;
      }
    }
    
    return false;
  }
}

// More concise cleanStartApp function that uses DatabaseService properly
Future<void> cleanStartApp() async {
  try {
    print('Cleaning up for fresh app start');
    
    // Just call the improved resetAndRecreateDatabase function
    // which handles everything we need - closing connections, deleting files, and recreating the database
    await DatabaseService.instance.resetAndRecreateDatabase();
    print('Database initialized successfully');
    
  } catch (e) {
    print('Error during clean start: $e');
  }
}

class MyApp extends StatelessWidget {
  final bool setupCompleted;
  
  const MyApp({super.key, required this.setupCompleted});

  @override
  Widget build(BuildContext context) {
    print('Building MyApp widget, setupCompleted: $setupCompleted');
    
    final home = setupCompleted 
        ? LicenseCheckScreen(child: const HomeScreen()) 
        : const SetupWizardScreen();
    print('Home widget selected: ${home.runtimeType}');
    
    return MaterialApp(
      title: 'Malbrose App',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
      ),
      scaffoldMessengerKey: UIHelpers.scaffoldMessengerKey,
      // Show setup wizard if setup is not completed, otherwise show home screen
      home: home,
      routes: {
        '/login': (context) => const LoginScreen(),
        '/home': (context) => const LicenseCheckScreen(child: HomeScreen()),
        '/main': (context) => const LicenseCheckScreen(child: MainScreen()),
        '/orders': (context) => const LicenseCheckScreen(child: OrderScreen()),
        '/held-orders':(context) => const LicenseCheckScreen(child: HeldOrdersScreen()),
        '/sales': (context) => const LicenseCheckScreen(child: SalesScreen()),
        '/products': (context) => const LicenseCheckScreen(child: ProductManagementScreen()),
        '/settings': (context) => const LicenseCheckScreen(child: SettingsScreen()),
        '/activity': (context) => const LicenseCheckScreen(child: ActivityLogScreen()),
        '/creditors': (context) => const LicenseCheckScreen(child: CreditorsScreen()),
        '/debtors': (context) => const LicenseCheckScreen(child: DebtorsScreen()),
        '/customer-reports': (context) => const LicenseCheckScreen(child: CustomerReportsScreen()),
        '/sales-report': (context) => const LicenseCheckScreen(child: SalesReportScreen()),
        '/printer-settings': (context) => const LicenseCheckScreen(child: PrinterSettingsScreen()),
        '/setup': (context) => const SetupWizardScreen(),
        '/backup': (context) => const LicenseCheckScreen(child: BackupScreen()),
        '/order-history': (context) => const LicenseCheckScreen(child: OrderHistoryScreen()),
      },
    );
  }
}
