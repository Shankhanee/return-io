import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/product.dart';
import '../models/warehouse_transaction.dart';

class FirestoreService {
  FirestoreService._();
  static final instance = FirestoreService._();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Stream<List<Product>> productsStream() => _firestore.collection('products').snapshots().map(
        (snapshot) => snapshot.docs.map(Product.fromDocument).toList(),
      );

  Stream<List<WarehouseTransaction>> transactionsStream({int limit = 10}) => _firestore
      .collection('transactions')
      .orderBy('timestamp', descending: true)
      .limit(limit)
      .snapshots()
      .map((snapshot) => snapshot.docs.map(WarehouseTransaction.fromDocument).toList());

  Future<void> recordMovement({
    required String productName,
    required String companyName,
    required int quantity,
    required bool isReturn,
    DateTime? movementTime,
  }) async {
    if (quantity <= 0) throw ArgumentError('Quantity must be greater than zero.');
    final products = _firestore.collection('products');
    final productQuery = await products
        .where('productName', isEqualTo: productName)
        .where('companyName', isEqualTo: companyName)
        .limit(1)
        .get();
    final productReference = productQuery.docs.isEmpty ? products.doc() : productQuery.docs.first.reference;

    await _firestore.runTransaction((transaction) async {
      final existing = await transaction.get(productReference);
      final data = existing.data() ?? <String, dynamic>{};
      final currentStock = (data['currentWarehouseStock'] as num?)?.toInt() ?? 0;
      final returnedIn = (data['totalReturnedIn'] as num?)?.toInt() ?? 0;
      final handedOver = (data['totalHandedOver'] as num?)?.toInt() ?? 0;
      if (!isReturn && currentStock < quantity) throw StateError('Not enough stock available for this handover.');
      transaction.set(productReference, {
        'productName': productName,
        'companyName': companyName,
        'currentWarehouseStock': currentStock + (isReturn ? quantity : -quantity),
        'totalReturnedIn': returnedIn + (isReturn ? quantity : 0),
        'totalHandedOver': handedOver + (isReturn ? 0 : quantity),
      });
      transaction.set(_firestore.collection('transactions').doc(), {
        'type': isReturn ? 'RETURN_IN' : 'HANDOVER_OUT',
        'productName': productName,
        'companyName': companyName,
        'quantity': quantity,
        'timestamp': movementTime == null ? FieldValue.serverTimestamp() : Timestamp.fromDate(movementTime),
        'performedBy': FirebaseAuth.instance.currentUser?.email ?? 'Unknown user',
      });
    });
  }

  Future<void> deleteProduct(String productId) => _firestore.collection('products').doc(productId).delete();

  Future<void> clearActivity() async {
    final snapshots = await _firestore.collection('transactions').get();
    for (var start = 0; start < snapshots.docs.length; start += 500) {
      final batch = _firestore.batch();
      final end = (start + 500).clamp(0, snapshots.docs.length);
      for (final document in snapshots.docs.sublist(start, end)) {
        batch.delete(document.reference);
      }
      await batch.commit();
    }
  }
}