import 'package:cloud_firestore/cloud_firestore.dart';

class Product {
  const Product({
    required this.id,
    required this.productName,
    required this.companyName,
    required this.currentWarehouseStock,
    required this.totalReturnedIn,
    required this.totalHandedOver,
  });

  final String id;
  final String productName;
  final String companyName;
  final int currentWarehouseStock;
  final int totalReturnedIn;
  final int totalHandedOver;

  factory Product.fromDocument(DocumentSnapshot<Map<String, dynamic>> document) {
    final data = document.data() ?? <String, dynamic>{};
    return Product(
      id: document.id,
      productName: data['productName'] as String? ?? 'Unnamed product',
      companyName: data['companyName'] as String? ?? 'Unknown brand',
      currentWarehouseStock: (data['currentWarehouseStock'] as num?)?.toInt() ?? 0,
      totalReturnedIn: (data['totalReturnedIn'] as num?)?.toInt() ?? 0,
      totalHandedOver: (data['totalHandedOver'] as num?)?.toInt() ?? 0,
    );
  }
}