import 'package:flutter/material.dart';
import 'package:my_flutter_app/const/constant.dart';
import 'package:my_flutter_app/models/activity_log_model.dart';
import 'package:my_flutter_app/services/database.dart';
import 'package:my_flutter_app/widgets/side_menu_widget.dart';
import 'package:intl/intl.dart';
import 'package:printing/printing.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

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
  String _groupBy = 'day';
  String? _actionFilter;
  int _currentPage = 1;
  final int _rowsPerPage = 10;
  final TextEditingController _searchController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Row(
        children: [
          // Add the side menu
          const Expanded(
            flex: 1,
            child: SideMenuWidget(),
          ),
          // Main content
          Expanded(
            flex: 4,
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.amber.withOpacity(0.7),
                    Colors.orange.shade900,
                  ],
                ),
              ),
        child: Column(
          children: [
            // Controls Row
            Row(
              children: [
                // Date Picker
                Expanded(
                  child: Card(
                    child: ListTile(
                      leading: const Icon(Icons.calendar_today),
                      title: Text(DateFormat('yyyy-MM-dd').format(_selectedDate)),
                      onTap: () async {
                        final date = await showDatePicker(
                          context: context,
                          initialDate: _selectedDate,
                          firstDate: DateTime(2020),
                          lastDate: DateTime.now(),
                        );
                        if (date != null) {
                          setState(() {
                            _selectedDate = date;
                            _loadLogs();
                          });
                        }
                      },
                    ),
                  ),
                ),
                const SizedBox(width: defaultPadding),
                // Action Filter
                Expanded(
                  child: Card(
                    child: DropdownButtonFormField<String>(
                      decoration: const InputDecoration(
                        contentPadding: EdgeInsets.symmetric(horizontal: 12),
                        border: InputBorder.none,
                      ),
                      value: _actionFilter,
                      hint: const Text('Filter by Action'),
                      items: const [
                        DropdownMenuItem(value: null, child: Text('All Actions')),
                        DropdownMenuItem(value: 'login', child: Text('Login')),
                        DropdownMenuItem(value: 'create_order', child: Text('Create Order')),
                        DropdownMenuItem(value: 'update_order', child: Text('Update Order')),
                        DropdownMenuItem(value: 'complete_sale', child: Text('Complete Sale')),
                      ],
                      onChanged: (value) {
                        setState(() {
                          _actionFilter = value;
                          _loadLogs();
                        });
                      },
                    ),
                  ),
                ),
                const SizedBox(width: defaultPadding),
                // Print Button
                ElevatedButton.icon(
                  onPressed: _printLogs,
                  icon: const Icon(Icons.print),
                  label: const Text('Export to Excel'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                  ),
                ),
              ],
            ),
            const SizedBox(height: defaultPadding),
            // Data Table
            Expanded(
              child: Card(
                child: SingleChildScrollView(
                  child: PaginatedDataTable(
                    header: const Text('Activity Logs'),
                    rowsPerPage: _rowsPerPage,
                    columns: const [
                      DataColumn(label: Text('Time')),
                      DataColumn(label: Text('User ID')),
                      DataColumn(label: Text('Action')),
                      DataColumn(label: Text('Details')),
                    ],
                    source: _ActivityLogDataSource(_logs),
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

  Future<void> _printLogs() async {
    // Implementation for Excel export
    // ... (Excel export code will be added later)
  }

  Future<void> _loadLogs() async {
    try {
      final logsData = await DatabaseService.instance.getActivityLogs(
        groupBy: _groupBy,
        dateFilter: _selectedDate.toString().split(' ')[0],
        userFilter: null,
        actionFilter: _actionFilter,
      );
      
      setState(() {
        _logs = logsData.map((log) => ActivityLog.fromMap(log)).toList();
      });
    } catch (e) {
      print('Error loading activity logs: $e');
    }
  }
}

class _ActivityLogDataSource extends DataTableSource {
  final List<ActivityLog> _logs;

  _ActivityLogDataSource(this._logs);

  @override
  DataRow? getRow(int index) {
    if (index >= _logs.length) return null;
    final log = _logs[index];
    return DataRow(cells: [
      DataCell(Text(DateFormat('yyyy-MM-dd HH:mm').format(log.timestamp))),
      DataCell(Text(log.userId.toString())),
      DataCell(Text(log.action)),
      DataCell(Text(log.details)),
    ]);
  }

  @override
  bool get isRowCountApproximate => false;

  @override
  int get rowCount => _logs.length;

  @override
  int get selectedRowCount => 0;
} 