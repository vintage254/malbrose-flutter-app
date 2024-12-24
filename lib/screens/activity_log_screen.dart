import 'package:flutter/material.dart';
import 'package:my_flutter_app/const/constant.dart';
import 'package:my_flutter_app/models/activity_log_model.dart';
import 'package:my_flutter_app/services/database.dart';
import 'package:my_flutter_app/widgets/side_menu_widget.dart';
import 'package:intl/intl.dart';
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
  final _searchController = TextEditingController();
  String _searchQuery = '';
  DateTime? _selectedDate;

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
      final logs = await DatabaseService.instance.getActivityLogs();
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
              pw.Text('Activity Logs', style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold)),
              pw.SizedBox(height: 20),
              pw.Table.fromTextArray(
                context: context,
                data: <List<String>>[
                  <String>['User ID', 'Action', 'Timestamp', 'Details'],
                  ..._logs.map((log) => [
                    log.userId.toString(),
                    log.action,
                    DateFormat('yyyy-MM-dd HH:mm').format(log.timestamp),
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

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate ?? DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2101),
    );
    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
      });
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
              child: Padding(
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
                        ElevatedButton(
                          onPressed: () => _selectDate(context),
                          child: Text(
                            _selectedDate == null
                                ? 'Select Date'
                                : DateFormat('yyyy-MM-dd').format(_selectedDate!),
                          ),
                        ),
                        const SizedBox(width: defaultPadding),
                        SizedBox(
                          width: 300,
                          child: TextField(
                            controller: _searchController,
                            decoration: InputDecoration(
                              hintText: 'Search logs...',
                              prefixIcon: const Icon(Icons.search),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                              filled: true,
                              fillColor: Colors.white,
                            ),
                            onChanged: (value) {
                              setState(() => _searchQuery = value);
                            },
                          ),
                        ),
                        const SizedBox(width: defaultPadding),
                        ElevatedButton.icon(
                          onPressed: _exportToPDF,
                          icon: const Icon(Icons.file_download),
                          label: const Text('Export to PDF'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green,
                            padding: const EdgeInsets.all(defaultPadding),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: defaultPadding),
                    Expanded(
                      child: RefreshIndicator(
                        onRefresh: _loadLogs,
                        child: Card(
                          child: _isLoading
                              ? const Center(child: CircularProgressIndicator())
                              : ListView.builder(
                                  itemCount: _filteredLogs.length,
                                  itemBuilder: (context, index) {
                                    final log = _filteredLogs[index];
                                    return ListTile(
                                      title: Text(log.details),
                                      subtitle: Text(
                                        '${log.userId} - ${DateFormat('MMM d, y HH:mm').format(log.timestamp)}',
                                      ),
                                    );
                                  },
                                ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  List<ActivityLog> get _filteredLogs {
    if (_searchQuery.isEmpty && _selectedDate == null) return _logs;

    return _logs.where((log) {
      final search = _searchQuery.toLowerCase();
      final matchesSearch = log.details.toLowerCase().contains(search) ||
          log.action.toLowerCase().contains(search) ||
          log.userId.toString().contains(search);

      final matchesDate = _selectedDate == null ||
          log.timestamp.year == _selectedDate!.year &&
          log.timestamp.month == _selectedDate!.month &&
          log.timestamp.day == _selectedDate!.day;

      return matchesSearch && matchesDate;
    }).toList();
  }
} 