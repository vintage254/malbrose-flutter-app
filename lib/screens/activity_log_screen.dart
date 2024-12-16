import 'package:flutter/material.dart';
import 'package:my_flutter_app/const/constant.dart';
import 'package:my_flutter_app/models/activity_log_model.dart';
import 'package:my_flutter_app/services/database.dart';
import 'package:my_flutter_app/widgets/side_menu_widget.dart';
import 'package:intl/intl.dart';

class ActivityLogScreen extends StatefulWidget {
  const ActivityLogScreen({super.key});

  @override
  State<ActivityLogScreen> createState() => _ActivityLogScreenState();
}

class _ActivityLogScreenState extends State<ActivityLogScreen> {
  List<ActivityLog> _logs = [];
  bool _isLoading = true;
  final _dateFormat = DateFormat('yyyy-MM-dd HH:mm:ss');
  String _filterUser = '';
  String _filterAction = '';

  @override
  void initState() {
    super.initState();
    _loadLogs();
  }

  Future<void> _loadLogs() async {
    try {
      final logs = await DatabaseService.instance.getActivityLogs(
        userFilter: _filterUser,
        actionFilter: _filterAction,
      );
      if (mounted) {
        setState(() {
          _logs = logs;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading logs: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Row(
        children: [
          const Expanded(
            flex: 1,
            child: SideMenuWidget(),
          ),
          Expanded(
            flex: 5,
            child: Padding(
              padding: const EdgeInsets.all(defaultPadding),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'User Activity Log',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: defaultPadding),
                  // Filters
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          decoration: const InputDecoration(
                            labelText: 'Filter by Username',
                            prefixIcon: Icon(Icons.person),
                          ),
                          onChanged: (value) {
                            _filterUser = value;
                            _loadLogs();
                          },
                        ),
                      ),
                      const SizedBox(width: defaultPadding),
                      Expanded(
                        child: TextField(
                          decoration: const InputDecoration(
                            labelText: 'Filter by Action',
                            prefixIcon: Icon(Icons.category),
                          ),
                          onChanged: (value) {
                            _filterAction = value;
                            _loadLogs();
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: defaultPadding),
                  Expanded(
                    child: _isLoading
                        ? const Center(child: CircularProgressIndicator())
                        : Card(
                            child: SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              child: DataTable(
                                columns: const [
                                  DataColumn(label: Text('Timestamp')),
                                  DataColumn(label: Text('User')),
                                  DataColumn(label: Text('Action')),
                                  DataColumn(label: Text('Details')),
                                ],
                                rows: _logs.map((log) {
                                  return DataRow(
                                    cells: [
                                      DataCell(Text(_dateFormat.format(log.timestamp))),
                                      DataCell(Text(log.username ?? 'Unknown')),
                                      DataCell(Text(log.actionType)),
                                      DataCell(Text(log.details)),
                                    ],
                                  );
                                }).toList(),
                              ),
                            ),
                          ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
} 