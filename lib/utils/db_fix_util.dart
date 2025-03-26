import 'package:flutter/material.dart';
import 'package:my_flutter_app/services/database.dart';

/// Utility class to fix database issues
class DbFixUtil {
  static Future<void> fixDatabaseIssues() async {
    runApp(const DbFixApp());
  }
}

class DbFixApp extends StatelessWidget {
  const DbFixApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(
          title: const Text('Database Fix Utility'),
        ),
        body: const DbFixScreen(),
      ),
    );
  }
}

class DbFixScreen extends StatefulWidget {
  const DbFixScreen({super.key});

  @override
  State<DbFixScreen> createState() => _DbFixScreenState();
}

class _DbFixScreenState extends State<DbFixScreen> {
  bool _isFixing = false;
  String _status = 'Ready to fix database issues.';
  List<String> _logs = [];

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _status,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: _isFixing ? null : _fixDatabase,
            child: _isFixing
                ? const CircularProgressIndicator()
                : const Text('Fix Database Issues'),
          ),
          const SizedBox(height: 16),
          const Text('Logs:', style: TextStyle(fontWeight: FontWeight.bold)),
          Expanded(
            child: ListView.builder(
              itemCount: _logs.length,
              itemBuilder: (context, index) {
                return Text(_logs[index]);
              },
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _fixDatabase() async {
    setState(() {
      _isFixing = true;
      _status = 'Fixing database issues...';
      _logs.add('Starting database fix...');
    });

    try {
      // Create a listener for log messages
      void logMessage(String message) {
        setState(() {
          _logs.add(message);
        });
      }

      // Fix the creditors table schema
      _logs.add('Initializing database...');
      await DatabaseService.instance.initialize();
      
      _logs.add('Fixing UNIQUE constraint on creditors table...');
      await DatabaseService.instance.fixUniqueConstraint();
      
      setState(() {
        _status = 'Database fixes completed successfully!';
        _logs.add('All fixes applied successfully.');
      });
    } catch (e) {
      setState(() {
        _status = 'Error fixing database: $e';
        _logs.add('ERROR: $e');
      });
    } finally {
      setState(() {
        _isFixing = false;
      });
    }
  }
}

// Run this from the command line to fix database issues
void main() {
  WidgetsFlutterBinding.ensureInitialized();
  DbFixUtil.fixDatabaseIssues();
} 