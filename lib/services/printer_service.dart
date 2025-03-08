import 'package:flutter/material.dart';
import 'package:printing/printing.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'dart:typed_data';
import 'package:shared_preferences/shared_preferences.dart';

enum PrinterType {
  thermal,
  inkjet,
  laser,
  auto
}

class PrinterService {
  static final PrinterService instance = PrinterService._init();
  
  PrinterService._init();
  
  PrinterType _printerType = PrinterType.auto;
  String? _defaultPrinterName;
  double _thermalPaperWidth = 80.0; // mm
  
  // Initialize printer settings from shared preferences
  Future<void> initialize() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      // Load printer type
      final printerTypeString = prefs.getString('printer_type') ?? 'auto';
      _printerType = _stringToPrinterType(printerTypeString);
      
      // Load default printer name
      _defaultPrinterName = prefs.getString('default_printer_name');
      
      // Load thermal paper width
      _thermalPaperWidth = prefs.getDouble('thermal_paper_width') ?? 80.0;
    } catch (e) {
      debugPrint('Error initializing printer settings: $e');
    }
  }
  
  // Save printer settings to shared preferences
  Future<void> saveSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      // Save printer type
      await prefs.setString('printer_type', _printerType.toString().split('.').last);
      
      // Save default printer name if set
      if (_defaultPrinterName != null) {
        await prefs.setString('default_printer_name', _defaultPrinterName!);
      }
      
      // Save thermal paper width
      await prefs.setDouble('thermal_paper_width', _thermalPaperWidth);
    } catch (e) {
      debugPrint('Error saving printer settings: $e');
    }
  }
  
  // Convert string to PrinterType enum
  PrinterType _stringToPrinterType(String typeString) {
    switch (typeString.toLowerCase()) {
      case 'thermal':
        return PrinterType.thermal;
      case 'inkjet':
        return PrinterType.inkjet;
      case 'laser':
        return PrinterType.laser;
      case 'auto':
      default:
        return PrinterType.auto;
    }
  }
  
  // Getters and setters for printer settings
  PrinterType get printerType => _printerType;
  set printerType(PrinterType type) {
    _printerType = type;
    saveSettings();
  }
  
  String? get defaultPrinterName => _defaultPrinterName;
  set defaultPrinterName(String? name) {
    _defaultPrinterName = name;
    saveSettings();
  }
  
  double get thermalPaperWidth => _thermalPaperWidth;
  set thermalPaperWidth(double width) {
    _thermalPaperWidth = width;
    saveSettings();
  }
  
  // Get the appropriate page format based on printer type
  PdfPageFormat getPageFormat() {
    switch (_printerType) {
      case PrinterType.thermal:
        // Convert mm to points (1 inch = 25.4 mm, 1 inch = 72 points)
        final widthPoints = _thermalPaperWidth * 72.0 / 25.4;
        return PdfPageFormat(
          widthPoints,
          double.infinity, // Use infinity for roll paper
          marginAll: 5 * PdfPageFormat.mm,
        );
      case PrinterType.inkjet:
      case PrinterType.laser:
        return PdfPageFormat.a4;
      case PrinterType.auto:
      default:
        // Auto-detect will be handled at print time
        return PdfPageFormat.a4;
    }
  }
  
  // Print a PDF document
  Future<void> printPdf({
    required pw.Document pdf,
    required String documentName,
    required BuildContext context,
    bool showPrinterDialog = true,
  }) async {
    try {
      // If auto-detect, try to determine the printer type
      if (_printerType == PrinterType.auto) {
        await _autoDetectPrinterType();
      }
      
      // Apply printer-specific formatting
      final formattedPdf = await _formatForPrinterType(pdf);
      
      // Print the document
      await Printing.layoutPdf(
        onLayout: (format) async => formattedPdf.save(),
        name: documentName,
        usePrinterSettings: true,
      );
    } catch (e) {
      debugPrint('Error printing document: $e');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error printing document: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
  
  // Auto-detect printer type based on available printers
  Future<void> _autoDetectPrinterType() async {
    try {
      final printers = await Printing.listPrinters();
      
      // Look for common thermal printer keywords in printer names
      final thermalKeywords = [
        'thermal', 'receipt', 'pos', 'epson tm', 'star', 'tsp', 
        'bixolon', 'citizen', 'rongta', 'zjiang'
      ];
      
      for (final printer in printers) {
        final printerName = printer.name.toLowerCase();
        
        // Check if any thermal keywords match
        if (thermalKeywords.any((keyword) => printerName.contains(keyword))) {
          _printerType = PrinterType.thermal;
          _defaultPrinterName = printer.name;
          return;
        }
      }
      
      // If no thermal printer found, default to inkjet/laser
      _printerType = PrinterType.inkjet;
    } catch (e) {
      debugPrint('Error auto-detecting printer type: $e');
      // Default to inkjet if auto-detection fails
      _printerType = PrinterType.inkjet;
    }
  }
  
  // Format PDF for specific printer type
  Future<pw.Document> _formatForPrinterType(pw.Document originalPdf) async {
    // For thermal printers, we need to adjust the page format
    if (_printerType == PrinterType.thermal) {
      // For thermal printers, just use the original document with adjusted page format
      // We can't easily extract content from the original PDF, so we'll return it as is
      // The page format will be applied during printing
      return originalPdf;
    }
    
    // For other printer types, return the original document
    return originalPdf;
  }
  
  // Get a list of available printers
  Future<List<Printer>> getAvailablePrinters() async {
    try {
      return await Printing.listPrinters();
    } catch (e) {
      debugPrint('Error getting available printers: $e');
      return [];
    }
  }
  
  // Test print a sample receipt
  Future<void> printTestPage(BuildContext context) async {
    final pdf = pw.Document();
    
    pdf.addPage(
      pw.Page(
        pageFormat: getPageFormat(),
        build: (context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.center,
            children: [
              pw.Text(
                'Printer Test Page',
                style: pw.TextStyle(
                  fontSize: 18,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              pw.SizedBox(height: 10),
              pw.Text('Printer Type: ${_printerType.toString().split('.').last}'),
              pw.SizedBox(height: 5),
              pw.Text('Paper Width: $_thermalPaperWidth mm'),
              pw.SizedBox(height: 20),
              pw.Text('If you can read this, your printer is working correctly!'),
              pw.SizedBox(height: 10),
              pw.Divider(),
              pw.SizedBox(height: 10),
              pw.Text(
                'Malbrose POS System',
                style: pw.TextStyle(
                  fontSize: 10,
                  fontStyle: pw.FontStyle.italic,
                ),
              ),
              // Extra space for thermal printer cutting
              pw.SizedBox(height: 20),
            ],
          );
        },
      ),
    );
    
    await printPdf(
      pdf: pdf,
      documentName: 'Printer Test Page',
      context: context,
    );
  }
} 