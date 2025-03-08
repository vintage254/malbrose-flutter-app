import 'package:flutter/material.dart';
import 'package:my_flutter_app/services/printer_service.dart';
import 'package:my_flutter_app/widgets/side_menu_widget.dart';
import 'package:my_flutter_app/const/constant.dart';
import 'package:printing/printing.dart';

class PrinterSettingsScreen extends StatefulWidget {
  const PrinterSettingsScreen({super.key});

  @override
  State<PrinterSettingsScreen> createState() => _PrinterSettingsScreenState();
}

class _PrinterSettingsScreenState extends State<PrinterSettingsScreen> {
  final _printerService = PrinterService.instance;
  List<Printer> _availablePrinters = [];
  bool _isLoading = true;
  final _paperWidthController = TextEditingController();
  
  @override
  void initState() {
    super.initState();
    _loadPrinterSettings();
  }
  
  @override
  void dispose() {
    _paperWidthController.dispose();
    super.dispose();
  }
  
  Future<void> _loadPrinterSettings() async {
    setState(() => _isLoading = true);
    
    try {
      // Initialize printer service
      await _printerService.initialize();
      
      // Load available printers
      _availablePrinters = await _printerService.getAvailablePrinters();
      
      // Set paper width controller
      _paperWidthController.text = _printerService.thermalPaperWidth.toString();
      
      if (mounted) {
        setState(() => _isLoading = false);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading printer settings: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
  
  Future<void> _testPrinter() async {
    try {
      await _printerService.printTestPage(context);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error testing printer: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
  
  void _savePaperWidth() {
    try {
      final width = double.parse(_paperWidthController.text);
      if (width > 0) {
        _printerService.thermalPaperWidth = width;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Paper width saved'),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Paper width must be greater than 0'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Invalid paper width'),
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
          const Expanded(
            flex: 1,
            child: SideMenuWidget(),
          ),
          Expanded(
            flex: 5,
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.blue.shade300,
                    Colors.blue.shade700,
                  ],
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.all(defaultPadding),
                child: _isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Printer Settings',
                            style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: defaultPadding),
                          Expanded(
                            child: Card(
                              elevation: 4,
                              child: Padding(
                                padding: const EdgeInsets.all(defaultPadding),
                                child: SingleChildScrollView(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      // Printer Type Selection
                                      const Text(
                                        'Printer Type',
                                        style: TextStyle(
                                          fontSize: 18,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                      DropdownButtonFormField<PrinterType>(
                                        value: _printerService.printerType,
                                        decoration: const InputDecoration(
                                          border: OutlineInputBorder(),
                                          contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                        ),
                                        items: PrinterType.values.map((type) {
                                          return DropdownMenuItem<PrinterType>(
                                            value: type,
                                            child: Text(type.toString().split('.').last),
                                          );
                                        }).toList(),
                                        onChanged: (value) {
                                          if (value != null) {
                                            setState(() {
                                              _printerService.printerType = value;
                                            });
                                          }
                                        },
                                      ),
                                      const SizedBox(height: 20),
                                      
                                      // Default Printer Selection
                                      const Text(
                                        'Default Printer',
                                        style: TextStyle(
                                          fontSize: 18,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                      DropdownButtonFormField<String?>(
                                        value: _printerService.defaultPrinterName,
                                        decoration: const InputDecoration(
                                          border: OutlineInputBorder(),
                                          contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                        ),
                                        items: [
                                          const DropdownMenuItem<String?>(
                                            value: null,
                                            child: Text('System Default'),
                                          ),
                                          ..._availablePrinters.map((printer) {
                                            return DropdownMenuItem<String?>(
                                              value: printer.name,
                                              child: Text(printer.name),
                                            );
                                          }),
                                        ],
                                        onChanged: (value) {
                                          setState(() {
                                            _printerService.defaultPrinterName = value;
                                          });
                                        },
                                      ),
                                      const SizedBox(height: 20),
                                      
                                      // Thermal Paper Width
                                      if (_printerService.printerType == PrinterType.thermal ||
                                          _printerService.printerType == PrinterType.auto)
                                        Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            const Text(
                                              'Thermal Paper Width (mm)',
                                              style: TextStyle(
                                                fontSize: 18,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                            const SizedBox(height: 8),
                                            Row(
                                              children: [
                                                Expanded(
                                                  child: TextFormField(
                                                    controller: _paperWidthController,
                                                    decoration: const InputDecoration(
                                                      border: OutlineInputBorder(),
                                                      hintText: 'Enter paper width in mm',
                                                      contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                                    ),
                                                    keyboardType: TextInputType.number,
                                                  ),
                                                ),
                                                const SizedBox(width: 8),
                                                ElevatedButton(
                                                  onPressed: _savePaperWidth,
                                                  child: const Text('Save'),
                                                ),
                                              ],
                                            ),
                                            const SizedBox(height: 8),
                                            const Text(
                                              'Common sizes: 58mm, 80mm, 112mm',
                                              style: TextStyle(
                                                fontSize: 12,
                                                fontStyle: FontStyle.italic,
                                              ),
                                            ),
                                            const SizedBox(height: 20),
                                          ],
                                        ),
                                      
                                      // Available Printers
                                      const Text(
                                        'Available Printers',
                                        style: TextStyle(
                                          fontSize: 18,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                      _availablePrinters.isEmpty
                                          ? const Text('No printers found')
                                          : ListView.builder(
                                              shrinkWrap: true,
                                              physics: const NeverScrollableScrollPhysics(),
                                              itemCount: _availablePrinters.length,
                                              itemBuilder: (context, index) {
                                                final printer = _availablePrinters[index];
                                                return ListTile(
                                                  title: Text(printer.name),
                                                  subtitle: Text(printer.url ?? 'Local printer'),
                                                  trailing: ElevatedButton(
                                                    onPressed: () {
                                                      setState(() {
                                                        _printerService.defaultPrinterName = printer.name;
                                                      });
                                                    },
                                                    child: const Text('Set as Default'),
                                                  ),
                                                );
                                              },
                                            ),
                                      const SizedBox(height: 20),
                                      
                                      // Test Print Button
                                      Center(
                                        child: ElevatedButton.icon(
                                          onPressed: _testPrinter,
                                          icon: const Icon(Icons.print),
                                          label: const Text('Test Print'),
                                          style: ElevatedButton.styleFrom(
                                            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(height: 20),
                                      
                                      // Refresh Printers Button
                                      Center(
                                        child: TextButton.icon(
                                          onPressed: _loadPrinterSettings,
                                          icon: const Icon(Icons.refresh),
                                          label: const Text('Refresh Printer List'),
                                        ),
                                      ),
                                    ],
                                  ),
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
} 