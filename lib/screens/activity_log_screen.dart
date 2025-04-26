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
import 'dart:io';
import 'package:my_flutter_app/services/printer_service.dart';
import 'package:file_picker/file_picker.dart';

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
  String? _selectedEventType;
  DateTime? _selectedDate;
  final _searchController = TextEditingController();
  String _searchQuery = '';

  // Predefined action types using constants from DatabaseService
  final List<String> _actionTypes = [
    DatabaseService.actionCreateProduct,
    DatabaseService.actionUpdateProduct,
    DatabaseService.actionDeleteProduct,
    DatabaseService.actionCreateOrder,
    DatabaseService.actionUpdateOrder,
    DatabaseService.actionCompleteSale,
    DatabaseService.actionRevertReceipt,
    DatabaseService.actionCreateCreditor,
    DatabaseService.actionUpdateCreditor,
    DatabaseService.actionDeleteCreditor,
    DatabaseService.actionCreateDebtor,
    DatabaseService.actionUpdateDebtor,
    DatabaseService.actionLogin,
    DatabaseService.actionLogout,
    DatabaseService.actionCreateCustomerReport,
    DatabaseService.actionUpdateCustomerReport,
    DatabaseService.actionPrintCustomerReport,
    DatabaseService.actionCreateCustomer,
    DatabaseService.actionUpdateCustomer,
    DatabaseService.actionDeleteCustomer,
    'update_inventory',
    'delete_order',
    'payment_received',
    'refund_issued',
    'user_created',
    'user_updated',
    'system_event',
  ];

  // System event types
  final List<String> _eventTypes = [
    DatabaseService.eventLeaderChange,
    DatabaseService.eventSyncCompleted,
    DatabaseService.eventSyncFailed,
    DatabaseService.eventServerStarted,
    DatabaseService.eventServerStopped,
    DatabaseService.eventSystemStartup,
    DatabaseService.eventSystemShutdown,
    DatabaseService.eventDatabaseMigration,
    DatabaseService.eventNetworkChange,
    DatabaseService.eventDeviceConnected,
    DatabaseService.eventDeviceDisconnected,
    DatabaseService.eventBackupCreated,
    DatabaseService.eventBackupRestored,
    DatabaseService.eventErrorOccurred,
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
        eventTypeFilter: _selectedEventType,
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
      // Show loading indicator
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Generating PDF...')),
      );
      
      final pdf = pw.Document();
      
      pdf.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4,
          build: (context) => pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Center(
                child: pw.Text(
                  'Activity Logs',
                  style: pw.TextStyle(
                    fontSize: 24,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
              ),
              pw.SizedBox(height: 20),
              pw.Table.fromTextArray(
                context: context,
                data: <List<String>>[
                  <String>['Date/Time', 'User', 'Event Type', 'Action', 'Details'],
                  ..._filteredLogs.map((log) => [
                    DateFormat('dd/MM/yyyy HH:mm').format(log.timestamp),
                    log.username,
                    log.eventType ?? 'N/A',
                    log.action.replaceAll('_', ' ').toUpperCase(),
                    log.details,
                  ]),
                ],
              ),
            ],
          ),
        ),
      );

      // Generate the PDF bytes
      final pdfBytes = await pdf.save();
      
      // Ask user for save location
      String? outputPath = await FilePicker.platform.saveFile(
        dialogTitle: 'Choose where to save the Activity Logs PDF',
        fileName: 'activity_logs_${DateFormat('yyyy-MM-dd_HH-mm').format(DateTime.now())}.pdf',
        allowedExtensions: ['pdf'],
        type: FileType.custom,
      );
      
      if (outputPath == null) {
        // User cancelled the picker
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Export cancelled'),
            backgroundColor: Colors.orange,
          ),
        );
        return;
      }
      
      // Ensure .pdf extension
      if (!outputPath.toLowerCase().endsWith('.pdf')) {
        outputPath = '$outputPath.pdf';
      }
      
      // Write the PDF to the selected location
      final file = File(outputPath);
      await file.writeAsBytes(pdfBytes);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Exported to $outputPath'),
          backgroundColor: Colors.green,
          duration: const Duration(seconds: 5),
          action: SnackBarAction(
            label: 'Open',
            onPressed: () async {
              // Open the PDF file using printing package
              await Printing.sharePdf(bytes: pdfBytes, filename: outputPath ?? 'activity_log.pdf');
            },
          ),
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

  Future<void> _printActivityLogs() async {
    try {
      // Get the printer service
      final printerService = PrinterService.instance;
      
      // Create the PDF document
      final pdf = pw.Document();
      
      // Add a page to the PDF
      pdf.addPage(
        pw.Page(
          // Use the printer service to get the appropriate page format
          pageFormat: printerService.getPageFormat(),
          build: (context) => pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Center(
                child: pw.Text(
                  'Activity Logs',
                  style: pw.TextStyle(
                    fontSize: 24,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
              ),
              pw.SizedBox(height: 20),
              pw.Table.fromTextArray(
                context: context,
                data: <List<String>>[
                  <String>['Date/Time', 'User', 'Event Type', 'Action', 'Details'],
                  ..._filteredLogs.map((log) => [
                    DateFormat('dd/MM/yyyy HH:mm').format(log.timestamp),
                    log.username,
                    log.eventType ?? 'N/A',
                    log.action.replaceAll('_', ' ').toUpperCase(),
                    log.details,
                  ]),
                ],
                headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                headerDecoration: pw.BoxDecoration(color: PdfColors.grey300),
                cellHeight: 30,
                cellAlignments: {
                  0: pw.Alignment.centerLeft,
                  1: pw.Alignment.centerLeft,
                  2: pw.Alignment.centerLeft,
                  3: pw.Alignment.centerLeft,
                  4: pw.Alignment.centerLeft,
                },
              ),
              pw.SizedBox(height: 20),
              pw.Text(
                'Generated on: ${DateFormat('dd/MM/yyyy HH:mm').format(DateTime.now())}',
                style: pw.TextStyle(
                  fontSize: 10,
                  fontStyle: pw.FontStyle.italic,
                ),
              ),
            ],
          ),
        ),
      );

      // Use the printer service to print the PDF
      await printerService.printPdf(
        pdf: pdf,
        documentName: 'Activity Logs - ${DateFormat('yyyy-MM-dd').format(DateTime.now())}',
        context: context,
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error printing: $e'),
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
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        const Text(
                          'Activity Logs',
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(width: 20),
                        // Date Filter
                        SizedBox(
                          width: 200,
                          child: ElevatedButton.icon(
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
                        ),
                        const SizedBox(width: defaultPadding),
                        // User Filter
                        SizedBox(
                          width: 200,
                          child: FutureBuilder<List<String>>(
                            future: DatabaseService.instance.getAllUsernames(),
                            builder: (context, snapshot) {
                              return DropdownButtonFormField<String>(
                                isExpanded: true,
                                decoration: const InputDecoration(
                                  labelText: 'Filter by User',
                                  filled: true,
                                  fillColor: Colors.white,
                                  contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
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
                        // Event Type Filter
                        SizedBox(
                          width: 200,
                          child: DropdownButtonFormField<String>(
                            isExpanded: true,
                            decoration: const InputDecoration(
                              labelText: 'Filter by Event Type',
                              filled: true,
                              fillColor: Colors.white,
                              contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            ),
                            value: _selectedEventType,
                            items: [
                              const DropdownMenuItem(
                                value: null,
                                child: Text('All Event Types'),
                              ),
                              ..._eventTypes.map((eventType) {
                                return DropdownMenuItem(
                                  value: eventType,
                                  child: Text(eventType.replaceAll('_', ' ')),
                                );
                              }),
                            ],
                            onChanged: (value) {
                              setState(() => _selectedEventType = value);
                              _loadLogs();
                            },
                          ),
                        ),
                        const SizedBox(width: defaultPadding),
                        // Action Filter
                        SizedBox(
                          width: 200,
                          child: DropdownButtonFormField<String>(
                            isExpanded: true,
                            decoration: const InputDecoration(
                              labelText: 'Filter by Action',
                              filled: true,
                              fillColor: Colors.white,
                              contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
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
                        SizedBox(
                          width: 120,
                          child: ElevatedButton.icon(
                            onPressed: _exportToPDF,
                            icon: const Icon(Icons.file_download),
                            label: const Text('Export'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.green,
                              foregroundColor: Colors.white,
                            ),
                          ),
                        ),
                        const SizedBox(width: defaultPadding),
                        // Print Button
                        SizedBox(
                          width: 120,
                          child: ElevatedButton.icon(
                            onPressed: _printActivityLogs,
                            icon: const Icon(Icons.print),
                            label: const Text('Print'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.blue,
                              foregroundColor: Colors.white,
                            ),
                          ),
                        ),
                        const SizedBox(width: defaultPadding),
                        // Clear Filters Button
                        SizedBox(
                          width: 150,
                          child: ElevatedButton.icon(
                            onPressed: () {
                              setState(() {
                                _selectedDate = null;
                                _selectedUser = null;
                                _selectedAction = null;
                                _selectedEventType = null;
                                _searchQuery = '';
                                _searchController.clear();
                              });
                              _loadLogs();
                            },
                            icon: const Icon(Icons.clear),
                            label: const Text('Clear Filters'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.red,
                              foregroundColor: Colors.white,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: defaultPadding),
                  // Add search field
                  TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      hintText: 'Search logs...',
                      prefixIcon: const Icon(Icons.search),
                      filled: true,
                      fillColor: Colors.white,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    ),
                    onChanged: (value) {
                      setState(() {
                        _searchQuery = value;
                      });
                    },
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
                                    label: Text('Event Type'),
                                    size: ColumnSize.M,
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
                                      DataCell(Text(log.eventType ?? 'N/A')),
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
          (log.eventType?.toLowerCase().contains(_searchQuery.toLowerCase()) ?? false) ||
          log.username.toLowerCase().contains(_searchQuery.toLowerCase());

      final matchesUser = _selectedUser == null || log.username == _selectedUser;

      final matchesAction = _selectedAction == null || log.action == _selectedAction;
      
      final matchesEventType = _selectedEventType == null || log.eventType == _selectedEventType;

      final matchesDate = _selectedDate == null ||
          (log.timestamp.year == _selectedDate!.year &&
              log.timestamp.month == _selectedDate!.month &&
              log.timestamp.day == _selectedDate!.day);

      return matchesSearch && matchesUser && matchesAction && matchesEventType && matchesDate;
    }).toList();
  }
}
