import 'package:flutter/material.dart';
import 'package:my_flutter_app/models/product_model.dart';

class ColumnMappingDialog extends StatefulWidget {
  final List<String> excelHeaders;
  final Map<String, String> initialMapping;
  final String fileType;

  const ColumnMappingDialog({
    Key? key,
    required this.excelHeaders,
    required this.initialMapping,
    this.fileType = 'Excel',
  }) : super(key: key);

  @override
  State<ColumnMappingDialog> createState() => _ColumnMappingDialogState();
}

class _ColumnMappingDialogState extends State<ColumnMappingDialog> {
  late Map<String, String?> _columnMapping;
  final List<String> _requiredFields = ['product_name', 'buying_price', 'selling_price', 'quantity', 'supplier'];

  @override
  void initState() {
    super.initState();
    _columnMapping = {};
    // Initialize mapping with initial values
    widget.excelHeaders.forEach((header) {
      _columnMapping[header] = widget.initialMapping[header];
    });
  }

  bool get _isValid {
    // Check if all required fields are mapped
    return _requiredFields.every((field) {
      return _columnMapping.values.contains(field);
    });
  }

  @override
  Widget build(BuildContext context) {
    // Get system field names for display
    final dbFields = {
      'product_name': 'Product Name',
      'description': 'Description',
      'buying_price': 'Buying Price',
      'selling_price': 'Selling Price',
      'quantity': 'Quantity',
      'supplier': 'Supplier',
      'sub_unit_name': 'Sub Unit Name',
      'number_of_sub_units': 'Number of Sub Units',
      'department': 'Department',
      'received_date': 'Received Date',
      'sub_unit_price': 'Sub Unit Price',
      'sub_unit_buying_price': 'Sub Unit Buying Price',
      'has_sub_units': 'Has Sub Units',
    };

    return Dialog(
      insetPadding: const EdgeInsets.all(16),
      child: Container(
        width: MediaQuery.of(context).size.width * 0.8,
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Column Mapping',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Map columns from your ${widget.fileType} file to product fields.',
              style: TextStyle(fontSize: 14),
            ),
            const SizedBox(height: 16),
            // Table header
            Container(
              padding: const EdgeInsets.symmetric(vertical: 8),
              decoration: BoxDecoration(
                border: Border(bottom: BorderSide(color: Colors.grey.shade300)),
              ),
              child: Row(
                children: [
                  Expanded(
                    flex: 2,
                    child: Text(
                      '${widget.fileType} Column',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: Colors.grey.shade800,
                      ),
                    ),
                  ),
                  Expanded(
                    flex: 3,
                    child: Text(
                      'Product Field',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: Colors.grey.shade800,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Flexible(
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: widget.excelHeaders.length,
                itemBuilder: (context, index) {
                  final header = widget.excelHeaders[index];
                  final selectedValue = _columnMapping[header];
                  
                  return Container(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    decoration: BoxDecoration(
                      border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          flex: 2,
                          child: Text(
                            header,
                            style: const TextStyle(fontSize: 14),
                          ),
                        ),
                        Expanded(
                          flex: 3,
                          child: DropdownButtonFormField<String?>(
                            value: selectedValue,
                            decoration: InputDecoration(
                              isDense: true,
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 8,
                              ),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(4),
                              ),
                            ),
                            items: [
                              const DropdownMenuItem<String?>(
                                value: null,
                                child: Text('Ignore this column'),
                              ),
                              ...dbFields.entries.map(
                                (entry) => DropdownMenuItem<String?>(
                                  value: entry.key,
                                  child: Text(entry.value),
                                ),
                              ),
                            ],
                            onChanged: (value) {
                              setState(() {
                                _columnMapping[header] = value;
                              });
                            },
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 24),
            if (!_isValid)
              Container(
                padding: const EdgeInsets.all(8),
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  border: Border.all(color: Colors.red.shade300),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Row(
                  children: [
                    Icon(Icons.warning, color: Colors.red.shade700, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Missing required fields: ${_requiredFields.where((field) => !_columnMapping.values.contains(field)).map((field) => dbFields[field]).join(", ")}',
                        style: TextStyle(color: Colors.red.shade700),
                      ),
                    ),
                  ],
                ),
              ),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Cancel'),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: _isValid
                      ? () => Navigator.of(context).pop(_columnMapping)
                      : null,
                  child: const Text('Apply Mapping'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
} 