import 'package:flutter/material.dart';
import 'package:my_flutter_app/services/database.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  try {
    print('Starting database reset...');
    await DatabaseService.instance.resetDatabase();
    print('Database reset completed successfully!');
    print('A new database has been created with default tables and an admin user.');
    print('Username: admin');
    print('Password: admin123');
  } catch (e) {
    print('Error resetting database: $e');
  }
}
