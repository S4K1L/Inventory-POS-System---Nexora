import 'package:cloud_firestore/cloud_firestore.dart';

import '../domain/category.dart';
import '../domain/inventory_repository.dart';
import '../domain/product.dart';
import '../domain/stock_movement.dart';

/// Firestore implementation. Data lives under each company for tenant
/// isolation:
///   companies/{cid}/products/{id}
///   companies/{cid}/categories/{id}
///   companies/{cid}/stock_movements/{id}
class FirestoreInventoryRepository implements InventoryRepository {
  FirestoreInventoryRepository(this._db);

  final FirebaseFirestore _db;

  CollectionReference<Map<String, dynamic>> _products(String cid) =>
      _db.collection('companies').doc(cid).collection('products');
  CollectionReference<Map<String, dynamic>> _categories(String cid) =>
      _db.collection('companies').doc(cid).collection('categories');
  CollectionReference<Map<String, dynamic>> _movements(String cid) =>
      _db.collection('companies').doc(cid).collection('stock_movements');

  @override
  Stream<List<Product>> watchProducts(String companyId) {
    return _products(companyId)
        .orderBy('name')
        .snapshots()
        .map((snap) =>
            snap.docs.map((d) => Product.fromMap(d.id, d.data())).toList());
  }

  @override
  Future<Product?> getProduct(String companyId, String productId) async {
    final doc = await _products(companyId).doc(productId).get();
    final data = doc.data();
    if (!doc.exists || data == null) return null;
    return Product.fromMap(doc.id, data);
  }

  @override
  Future<Product?> findByBarcode(String companyId, String code) async {
    final trimmed = code.trim();
    if (trimmed.isEmpty) return null;

    // Try barcode first, then fall back to SKU — both are common on labels.
    for (final field in ['barcode', 'sku']) {
      final snap = await _products(companyId)
          .where(field, isEqualTo: trimmed)
          .limit(1)
          .get();
      if (snap.docs.isNotEmpty) {
        final doc = snap.docs.first;
        return Product.fromMap(doc.id, doc.data());
      }
    }
    return null;
  }

  @override
  Future<String> createProduct(
    String companyId,
    Product product, {
    num openingStock = 0,
    String userId = '',
  }) async {
    final ref = _products(companyId).doc();
    final batch = _db.batch();

    batch.set(ref, {
      ...product.toMap(),
      'stock': openingStock,
      'createdAt': DateTime.now().toIso8601String(),
    });

    if (openingStock != 0) {
      final moveRef = _movements(companyId).doc();
      batch.set(
        moveRef,
        StockMovement(
          id: moveRef.id,
          productId: ref.id,
          type: StockMovementType.add,
          delta: openingStock,
          resultingStock: openingStock,
          createdAt: DateTime.now(),
          note: 'Opening stock',
          userId: userId,
        ).toMap(),
      );
    }

    await batch.commit();
    return ref.id;
  }

  @override
  Future<void> updateProduct(String companyId, Product product) {
    // Note: stock is excluded — only adjustStock changes quantity.
    return _products(companyId).doc(product.id).update(product.toMap());
  }

  @override
  Future<void> archiveProduct(String companyId, String productId) {
    return _products(companyId).doc(productId).update({'active': false});
  }

  @override
  Future<void> adjustStock({
    required String companyId,
    required String productId,
    required num delta,
    required StockMovementType type,
    String note = '',
    String userId = '',
  }) async {
    final productRef = _products(companyId).doc(productId);
    final moveRef = _movements(companyId).doc();

    await _db.runTransaction((tx) async {
      final snap = await tx.get(productRef);
      if (!snap.exists) {
        throw StateError('Product $productId no longer exists');
      }
      final current = (snap.data()?['stock'] ?? 0) as num;
      final next = current + delta;
      if (next < 0) {
        throw StateError('Insufficient stock: have $current, change $delta');
      }

      tx.update(productRef, {'stock': next});
      tx.set(
        moveRef,
        StockMovement(
          id: moveRef.id,
          productId: productId,
          type: type,
          delta: delta,
          resultingStock: next,
          createdAt: DateTime.now(),
          note: note,
          userId: userId,
        ).toMap(),
      );
    });
  }

  @override
  Stream<List<StockMovement>> watchMovements(
      String companyId, String productId) {
    return _movements(companyId)
        .where('productId', isEqualTo: productId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snap) =>
            snap.docs.map((d) => StockMovement.fromMap(d.id, d.data())).toList());
  }

  @override
  Stream<List<Category>> watchCategories(String companyId) {
    return _categories(companyId)
        .orderBy('name')
        .snapshots()
        .map((snap) =>
            snap.docs.map((d) => Category.fromMap(d.id, d.data())).toList());
  }

  @override
  Future<String> createCategory(String companyId, Category category) async {
    final ref = _categories(companyId).doc();
    await ref.set(category.toMap());
    return ref.id;
  }
}
