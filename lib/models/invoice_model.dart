import 'package:my_flutter_app/models/order_model.dart';

class Invoice {
  final int? id;
  final String invoiceNumber;
  final int customerId;
  final String? customerName;
  final double totalAmount;
  final String status;
  final String paymentStatus;
  final DateTime createdAt;
  final DateTime? dueDate;
  final List<int>? orderIds;
  final List<OrderItem>? completedItems;
  final List<OrderItem>? pendingItems;
  final double completedAmount;
  final double pendingAmount;

  Invoice({
    this.id,
    required this.invoiceNumber,
    required this.customerId,
    this.customerName,
    required this.totalAmount,
    required this.status,
    required this.paymentStatus,
    required this.createdAt,
    this.dueDate,
    this.orderIds,
    this.completedItems,
    this.pendingItems,
    this.completedAmount = 0.0,
    this.pendingAmount = 0.0,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'invoice_number': invoiceNumber,
      'customer_id': customerId,
      'customer_name': customerName,
      'total_amount': totalAmount,
      'status': status,
      'payment_status': paymentStatus,
      'created_at': createdAt.toIso8601String(),
      'due_date': dueDate?.toIso8601String(),
      'completed_amount': completedAmount,
      'pending_amount': pendingAmount,
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
      paymentStatus: map['payment_status'] as String,
      createdAt: DateTime.parse(map['created_at'] as String),
      dueDate: map['due_date'] != null 
          ? DateTime.parse(map['due_date'] as String)
          : null,
      orderIds: map['order_ids'] != null 
          ? List<int>.from((map['order_ids'] as List)
              .map((item) => item as int))
          : null,
      completedItems: map['completed_items'] != null 
          ? List<OrderItem>.from((map['completed_items'] as List)
              .map((item) => OrderItem.fromMap(item as Map<String, dynamic>)))
          : null,
      pendingItems: map['pending_items'] != null 
          ? List<OrderItem>.from((map['pending_items'] as List)
              .map((item) => OrderItem.fromMap(item as Map<String, dynamic>)))
          : null,
      completedAmount: (map['completed_amount'] as num?)?.toDouble() ?? 0.0,
      pendingAmount: (map['pending_amount'] as num?)?.toDouble() ?? 0.0,
    );
  }

  Invoice copyWith({
    int? id,
    String? invoiceNumber,
    int? customerId,
    String? customerName,
    double? totalAmount,
    String? status,
    String? paymentStatus,
    DateTime? createdAt,
    DateTime? dueDate,
    List<int>? orderIds,
    List<OrderItem>? completedItems,
    List<OrderItem>? pendingItems,
    double? completedAmount,
    double? pendingAmount,
  }) {
    return Invoice(
      id: id ?? this.id,
      invoiceNumber: invoiceNumber ?? this.invoiceNumber,
      customerId: customerId ?? this.customerId,
      customerName: customerName ?? this.customerName,
      totalAmount: totalAmount ?? this.totalAmount,
      status: status ?? this.status,
      paymentStatus: paymentStatus ?? this.paymentStatus,
      createdAt: createdAt ?? this.createdAt,
      dueDate: dueDate ?? this.dueDate,
      orderIds: orderIds ?? this.orderIds,
      completedItems: completedItems ?? this.completedItems,
      pendingItems: pendingItems ?? this.pendingItems,
      completedAmount: completedAmount ?? this.completedAmount,
      pendingAmount: pendingAmount ?? this.pendingAmount,
    );
  }
} 