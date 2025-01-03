import 'package:flutter/material.dart';
import 'package:my_flutter_app/widgets/side_menu_widget.dart';
import 'package:my_flutter_app/const/constant.dart';
import 'package:my_flutter_app/services/database.dart';
import 'package:my_flutter_app/models/activity_log_model.dart';
import 'package:intl/intl.dart';
import 'package:data_table_2/data_table_2.dart';
import 'package:printing/printing.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'dart:async';
import 'package:path_provider/path_provider.dart';
import 'dart:io';

class ActivityLogScreen extends StatefulWidget {
  const ActivityLogScreen({super.key});

  @override
  State<ActivityLogScreen> createState() => _ActivityLogScreenState();
}

class _ActivityLogScreenState extends State<ActivityLogScreen> {
  List<ActivityLog> _logs = [];
  bool _isLoading = true;
  Timer? _refreshTimer;
  String? _selectedUser;
  String? _selectedAction;
  DateTime? _selectedDate;
  final _searchController = TextEditingController();
  String _searchQuery = '';

  // Predefined action types
  final List<String> _actionTypes = [
    'create_product',
    'update_product',
    'create_order',
    'update_order',
    'complete_sale',
    'create_creditor',
    'update_creditor',
    'create_debtor',
    'update_debtor',
    'login',
    'logout',
  ];

  @override
  void initState() {
    super.initState();
    _loadLogs();
    _refreshTimer = Timer.periodic(const Duration(seconds: 30), (_) => _loadLogs());
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadLogs() async {
    if (!mounted) return;

    setState(() => _isLoading = true);

    try {
      final logs = await DatabaseService.instance.getActivityLogs(
        userFilter: _selectedUser,
        actionFilter: _selectedAction,
        dateFilter: _selectedDate?.toIso8601String(),
      );
      if (mounted) {
        setState(() {
          _logs = logs.map((log) => ActivityLog.fromMap(log)).toList();
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading activity logs: $e')),
        );
      }
    }
  }

  Future<void> _exportToPDF() async {
    try {
      final pdf = pw.Document();
      
      pdf.addPage(
        pw.Page(
          build: (context) => pw.Column(
            children: [
              pw.Text(
                'Activity Logs',
                style: pw.TextStyle(
                  fontSize: 24,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              pw.SizedBox(height: 20),
              pw.Table.fromTextArray(
                context: context,
                data: <List<String>>[
                  <String>['Date/Time', 'User', 'Action', 'Details'],
                  ..._filteredLogs.map((log) => [
                    DateFormat('dd/MM/yyyy HH:mm').format(log.timestamp),
                    log.username,
                    log.action.replaceAll('_', ' ').toUpperCase(),
                    log.details,
                  ]),
                ],
              ),
            ],
          ),
        ),
      );

      final directory = await getApplicationDocumentsDirectory();
      final fileName = 'activity_logs_${DateTime.now().toIso8601String()}.pdf';
      final filePath = '${directory.path}/$fileName';
      final file = File(filePath);
      await file.writeAsBytes(await pdf.save());

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Exported to $filePath'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error exporting: $e'),
          backgroundColor: Colors.red,
        ),
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
              padding: const EdgeInsets.all(defaultPadding),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Text(
                        'Activity Logs',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      const Spacer(),
                      // Date Filter
                      ElevatedButton.icon(
                        onPressed: () async {
                          final picked = await showDatePicker(
                            context: context,
                            initialDate: _selectedDate ?? DateTime.now(),
                            firstDate: DateTime(2000),
                            lastDate: DateTime(2101),
                          );
                          if (picked != null) {
                            setState(() => _selectedDate = picked);
                            _loadLogs();
                          }
                        },
                        icon: const Icon(Icons.calendar_today),
                        label: Text(
                          _selectedDate == null
                              ? 'Select Date'
                              : DateFormat('dd/MM/yyyy').format(_selectedDate!),
                        ),
                      ),
                      const SizedBox(width: defaultPadding),
                      // User Filter
                      SizedBox(
                        width: 200,
                        child: FutureBuilder<List<String>>(
                          future: DatabaseService.instance.getAllUsernames(),
                          builder: (context, snapshot) {
                            return DropdownButtonFormField<String>(
                              decoration: const InputDecoration(
                                labelText: 'Filter by User',
                                filled: true,
                                fillColor: Colors.white,
                              ),
                              value: _selectedUser,
                              items: [
                                const DropdownMenuItem(
                                  value: null,
                                  child: Text('All Users'),
                                ),
                                if (snapshot.hasData)
                                  ...snapshot.data!.map((username) {
                                    return DropdownMenuItem(
                                      value: username,
                                      child: Text(username),
                                    );
                                  }),
                              ],
                              onChanged: (value) {
                                setState(() => _selectedUser = value);
                                _loadLogs();
                              },
                            );
                          },
                        ),
                      ),
                      const SizedBox(width: defaultPadding),
                      // Action Filter
                      SizedBox(
                        width: 200,
                        child: DropdownButtonFormField<String>(
                          decoration: const InputDecoration(
                            labelText: 'Filter by Action',
                            filled: true,
                            fillColor: Colors.white,
                          ),
                          value: _selectedAction,
                          items: [
                            const DropdownMenuItem(
                              value: null,
                              child: Text('All Actions'),
                            ),
                            ..._actionTypes.map((action) {
                              return DropdownMenuItem(
                                value: action,
                                child: Text(action.replaceAll('_', ' ')),
                              );
                            }),
                          ],
                          onChanged: (value) {
                            setState(() => _selectedAction = value);
                            _loadLogs();
                          },
                        ),
                      ),
                      const SizedBox(width: defaultPadding),
                      // Export Button
                      ElevatedButton.icon(
                        onPressed: _exportToPDF,
                        icon: const Icon(Icons.file_download),
                        label: const Text('Export to PDF'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                          foregroundColor: Colors.white,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: defaultPadding),
                  Expanded(
                    child: Card(
                      elevation: 4,
                      child: Padding(
                        padding: const EdgeInsets.all(defaultPadding),
                        child: _isLoading
                            ? const Center(child: CircularProgressIndicator())
                            : DataTable2(
                                columns: const [
                                  DataColumn2(
                                    label: Text('Date/Time'),
                                    size: ColumnSize.M,
                                  ),
                                  DataColumn2(
                                    label: Text('User'),
                                    size: ColumnSize.S,
                                  ),
                                  DataColumn2(
                                    label: Text('Action'),
                                    size: ColumnSize.M,
                                  ),
                                  DataColumn2(
                                    label: Text('Details'),
                                    size: ColumnSize.L,
                                  ),
                                ],
                                rows: _filteredLogs.map((log) {
                                  return DataRow2(
                                    cells: [
                                      DataCell(Text(
                                        DateFormat('dd/MM/yyyy HH:mm')
                                            .format(log.timestamp),
                                      )),
                                      DataCell(Text(log.username)),
                                      DataCell(Text(
                                        log.action.replaceAll('_', ' ').toUpperCase(),
                                      )),
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

  List<ActivityLog> get _filteredLogs {
    return _logs.where((log) {
      final matchesSearch = _searchQuery.isEmpty ||
          log.details.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          log.action.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          log.username.toLowerCase().contains(_searchQuery.toLowerCase());

      final matchesUser = _selectedUser == null || log.username == _selectedUser;

      final matchesAction = _selectedAction == null || log.action == _selectedAction;

      final matchesDate = _selectedDate == null ||
          (log.timestamp.year == _selectedDate!.year &&
              log.timestamp.month == _selectedDate!.month &&
              log.timestamp.day == _selectedDate!.day);

      return matchesSearch && matchesUser && matchesAction && matchesDate;
    }).toList();
  }
}
