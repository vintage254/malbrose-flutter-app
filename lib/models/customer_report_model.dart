import 'package:my_flutter_app/models/order_model.dart';

class CustomerReport {
  final int? id;
  final String reportNumber;
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

  CustomerReport({
    this.id,
    required this.reportNumber,
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
      'report_number': reportNumber,
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

  factory CustomerReport.fromMap(Map<String, dynamic> map) {
    return CustomerReport(
      id: map['id'] as int?,
      reportNumber: map['report_number'] as String,
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

  CustomerReport copyWith({
    int? id,
    String? reportNumber,
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
    return CustomerReport(
      id: id ?? this.id,
      reportNumber: reportNumber ?? this.reportNumber,
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
