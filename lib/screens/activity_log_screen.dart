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
  DateTime _selectedDate = DateTime.now();
  String _selectedMonth = DateTime.now().month.toString();
  String _selectedYear = DateTime.now().year.toString();
  String _groupBy = 'day'; // 'day', 'month', 'year'

  @override
  void initState() {
    super.initState();
    _loadLogs();
  }

  Future<void> _loadLogs() async {
    try {
      final logs = await DatabaseService.instance.getActivityLogs(
        groupBy: _groupBy,
        dateFilter: _selectedDate.toString().split(' ')[0],
        userFilter: null,
        actionFilter: null,
      );
      
      setState(() {
        _logs = logs;
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error loading logs: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Row(
        children: [
          const Expanded(flex: 1, child: SideMenuWidget()),
          Expanded(
            flex: 4,
            child: Padding(
              padding: const EdgeInsets.all(defaultPadding),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Activity Logs',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Row(
                        children: [
                          DropdownButton<String>(
                            value: _groupBy,
                            items: const [
                              DropdownMenuItem(value: 'day', child: Text('Daily')),
                              DropdownMenuItem(value: 'month', child: Text('Monthly')),
                              DropdownMenuItem(value: 'year', child: Text('Yearly')),
                            ],
                            onChanged: (value) {
                              setState(() {
                                _groupBy = value!;
                                _loadLogs();
                              });
                            },
                          ),
                          // Add date/month/year pickers based on _groupBy
                        ],
                      ),
                    ],
                  ),
                  Expanded(
                    child: ListView.builder(
                      itemCount: _logs.length,
                      itemBuilder: (context, index) {
                        final log = _logs[index];
                        return Card(
                          child: ListTile(
                            title: Text(log.actionType),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('By: ${log.username}'),
                                Text('Details: ${log.details}'),
                                Text(
                                  'Time: ${DateFormat('yyyy-MM-dd HH:mm:ss').format(log.timestamp)}',
                                ),
                              ],
                            ),
                          ),
                        );
                      },
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