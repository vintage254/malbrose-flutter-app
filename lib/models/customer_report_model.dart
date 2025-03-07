import 'package:my_flutter_app/models/order_model.dart';

class CustomerReport {
  final int? id;
  String reportNumber; // Changed from final to allow setting from outside
  final int customerId;
  final String customerName;
  final double totalAmount;
  final double completedAmount;
  final double pendingAmount;
  final DateTime createdAt;
  final DateTime? startDate;  // Start of report period
  final DateTime? endDate;    // End of report period
  final List<OrderItem>? completedItems;
  final List<OrderItem>? pendingItems;
  final String? paymentStatus; // Payment status of the report

  CustomerReport({
    this.id,
    required this.reportNumber,
    required this.customerId,
    required this.customerName,
    required this.totalAmount,
    this.completedAmount = 0.0,
    this.pendingAmount = 0.0,
    required this.createdAt,
    this.startDate,
    this.endDate,
    this.completedItems,
    this.pendingItems,
    this.paymentStatus,
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
      'created_at': createdAt.toIso8601String(),
      if (startDate != null) 'start_date': startDate!.toIso8601String(),
      if (endDate != null) 'end_date': endDate!.toIso8601String(),
      if (paymentStatus != null) 'payment_status': paymentStatus,
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
      createdAt: map['created_at'] != null 
          ? DateTime.parse(map['created_at'] as String)
          : DateTime.now(),
      startDate: map['start_date'] != null 
          ? DateTime.parse(map['start_date'] as String)
          : null,
      endDate: map['end_date'] != null 
          ? DateTime.parse(map['end_date'] as String)
          : null,
      paymentStatus: map['payment_status'] as String?,
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
    DateTime? createdAt,
    DateTime? startDate,
    DateTime? endDate,
    List<OrderItem>? completedItems,
    List<OrderItem>? pendingItems,
    String? paymentStatus,
  }) {
    return CustomerReport(
      id: id ?? this.id,
      reportNumber: reportNumber ?? this.reportNumber,
      customerId: customerId ?? this.customerId,
      customerName: customerName ?? this.customerName,
      totalAmount: totalAmount ?? this.totalAmount,
      completedAmount: completedAmount ?? this.completedAmount,
      pendingAmount: pendingAmount ?? this.pendingAmount,
      createdAt: createdAt ?? this.createdAt,
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
      completedItems: completedItems ?? this.completedItems,
      pendingItems: pendingItems ?? this.pendingItems,
      paymentStatus: paymentStatus ?? this.paymentStatus,
    );
  }
}
