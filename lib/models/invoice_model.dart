import 'package:my_flutter_app/models/order_model.dart';

class Invoice {
  final int? id;
  final String invoiceNumber;
  final int customerId;
  final String? customerName;
  final double totalAmount;
  final String status;
  final DateTime createdAt;
  final DateTime? dueDate;
  final List<OrderItem>? items;

  Invoice({
    this.id,
    required this.invoiceNumber,
    required this.customerId,
    this.customerName,
    required this.totalAmount,
    required this.status,
    required this.createdAt,
    this.dueDate,
    this.items,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'invoice_number': invoiceNumber,
      'customer_id': customerId,
      'customer_name': customerName,
      'total_amount': totalAmount,
      'status': status,
      'created_at': createdAt.toIso8601String(),
      'due_date': dueDate?.toIso8601String(),
    };
  }

  factory Invoice.fromMap(Map<String, dynamic> map) {
    return Invoice(
      id: map['id'] as int?,
      invoiceNumber: map['invoice_number'] as String,
      customerId: map['customer_id'] as int,
      customerName: map['customer_name'] as String?,
      totalAmount: (map['total_amount'] as num).toDouble(),
      status: map['status'] as String,
      createdAt: DateTime.parse(map['created_at'] as String),
      dueDate: map['due_date'] != null 
          ? DateTime.parse(map['due_date'] as String)
          : null,
      items: map['items'] != null 
          ? List<OrderItem>.from(
              (map['items'] as List).map((item) => 
                OrderItem.fromMap(item as Map<String, dynamic>)
              )
            )
          : null,
    );
  }
} 