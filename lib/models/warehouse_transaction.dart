import 'package:cloud_firestore/cloud_firestore.dart';

class WarehouseTransaction {
  const WarehouseTransaction({
    required this.id,
    required this.type,
    required this.productName,
    required this.companyName,
    required this.quantity,
    required this.timestamp,
    required this.performedBy,
  });

  final String id;
  final String type;
  final String productName;
  final String companyName;
  final int quantity;
  final DateTime? timestamp;
  final String performedBy;

  factory WarehouseTransaction.fromDocument(DocumentSnapshot<Map<String, dynamic>> document) {
    final data = document.data() ?? <String, dynamic>{};
    return WarehouseTransaction(
      id: document.id,
      type: data['type'] as String? ?? 'UNKNOWN',
      productName: data['productName'] as String? ?? 'Unknown product',
      companyName: data['companyName'] as String? ?? 'Unknown brand',
      quantity: (data['quantity'] as num?)?.toInt() ?? 0,
      timestamp: (data['timestamp'] as Timestamp?)?.toDate(),
      performedBy: data['performedBy'] as String? ?? 'Unknown user',
    );
  }
}