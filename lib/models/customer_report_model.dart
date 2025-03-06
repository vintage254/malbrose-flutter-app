import 'package:my_flutter_app/models/order_model.dart';

class CustomerReport {
  final int? id;
  final String reportNumber;
  final int customerId;
  final String customerName;
  final double totalAmount;
  final double completedAmount;
  final double pendingAmount;
  final String status;
  final String paymentStatus;
  final DateTime createdAt;
  final DateTime? dueDate;
  final List<OrderItem>? completedItems;
  final List<OrderItem>? pendingItems;

  CustomerReport({
    this.id,
    required this.reportNumber,
    required this.customerId,
    required this.customerName,
    required this.totalAmount,
    this.completedAmount = 0.0,
    this.pendingAmount = 0.0,
    required this.status,
    this.paymentStatus = 'PENDING',
    required this.createdAt,
    this.dueDate,
    this.completedItems,
    this.pendingItems,
  });

  // Add helper methods for calculations
  double get effectiveTotal => completedAmount + pendingAmount;
  
  bool get hasCompletedItems => completedItems?.isNotEmpty ?? false;
  
  bool get hasPendingItems => pendingItems?.isNotEmpty ?? false;

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'report_number': reportNumber,
      'customer_id': customerId,
      'customer_name': customerName,
      'total_amount': totalAmount,
      'completed_amount': completedAmount,
      'pending_amount': pendingAmount,
      'status': status,
      'payment_status': paymentStatus,
      'created_at': createdAt.toIso8601String(),
      if (dueDate != null) 'due_date': dueDate!.toIso8601String(),
    };
  }

  factory CustomerReport.fromMap(Map<String, dynamic> map) {
    return CustomerReport(
      id: map['id'] != null ? (map['id'] as num).toInt() : null,
      reportNumber: map['report_number'] as String,
      customerId: (map['customer_id'] as num).toInt(),
      customerName: (map['customer_name'] as String?) ?? 'Unknown Customer',
      totalAmount: (map['total_amount'] as num?)?.toDouble() ?? 0.0,
      completedAmount: (map['completed_amount'] as num?)?.toDouble() ?? 0.0,
      pendingAmount: (map['pending_amount'] as num?)?.toDouble() ?? 0.0,
      status: (map['status'] as String?) ?? 'PENDING',
      paymentStatus: (map['payment_status'] as String?) ?? 'PENDING',
      createdAt: map['created_at'] != null 
          ? DateTime.parse(map['created_at'] as String)
          : DateTime.now(),
      dueDate: map['due_date'] != null 
          ? DateTime.parse(map['due_date'] as String)
          : null,
      // Items will be loaded separately
    );
  }

  CustomerReport copyWith({
    int? id,
    String? reportNumber,
    int? customerId,
    String? customerName,
    double? totalAmount,
    double? completedAmount,
    double? pendingAmount,
    String? status,
    String? paymentStatus,
    DateTime? createdAt,
    DateTime? dueDate,
    List<OrderItem>? completedItems,
    List<OrderItem>? pendingItems,
  }) {
    return CustomerReport(
      id: id ?? this.id,
      reportNumber: reportNumber ?? this.reportNumber,
      customerId: customerId ?? this.customerId,
      customerName: customerName ?? this.customerName,
      totalAmount: totalAmount ?? this.totalAmount,
      completedAmount: completedAmount ?? this.completedAmount,
      pendingAmount: pendingAmount ?? this.pendingAmount,
      status: status ?? this.status,
      paymentStatus: paymentStatus ?? this.paymentStatus,
      createdAt: createdAt ?? this.createdAt,
      dueDate: dueDate ?? this.dueDate,
      completedItems: completedItems ?? this.completedItems,
      pendingItems: pendingItems ?? this.pendingItems,
    );
  }
}
