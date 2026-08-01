import 'package:cloud_firestore/cloud_firestore.dart';

import '../domain/category.dart';
import '../domain/inventory_repository.dart';
import '../domain/product.dart';
import '../domain/stock_movement.dart';

/// Firestore implementation.
///
/// Catalog (shared):   companies/{cid}/products/{id}, categories/{id}
/// Per branch:         companies/{cid}/branches/{bid}/stock/{productId}   { qty }
///                     companies/{cid}/branches/{bid}/stock_movements/{id}
class FirestoreInventoryRepository implements InventoryRepository {
  FirestoreInventoryRepository(this._db);

  final FirebaseFirestore _db;

  DocumentReference<Map<String, dynamic>> _company(String cid) =>
      _db.collection('companies').doc(cid);
  CollectionReference<Map<String, dynamic>> _products(String cid) =>
      _company(cid).collection('products');
  CollectionReference<Map<String, dynamic>> _categories(String cid) =>
      _company(cid).collection('categories');
  DocumentReference<Map<String, dynamic>> _branch(String cid, String bid) =>
      _company(cid).collection('branches').doc(bid);
  CollectionReference<Map<String, dynamic>> _stock(String cid, String bid) =>
      _branch(cid, bid).collection('stock');
  CollectionReference<Map<String, dynamic>> _movements(String cid, String bid) =>
      _branch(cid, bid).collection('stock_movements');

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
    String branchId = '',
    num openingStock = 0,
    String userId = '',
  }) async {
    final ref = _products(companyId).doc();
    final batch = _db.batch();

    // Catalog doc (no per-branch stock stored here).
    batch.set(ref, {
      ...product.toMap(),
      'createdAt': DateTime.now().toIso8601String(),
    });

    if (branchId.isNotEmpty && openingStock != 0) {
      batch.set(_stock(companyId, branchId).doc(ref.id), {'qty': openingStock});
      final moveRef = _movements(companyId, branchId).doc();
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
    return _products(companyId).doc(product.id).update(product.toMap());
  }

  @override
  Future<void> archiveProduct(String companyId, String productId) {
    return _products(companyId).doc(productId).update({'active': false});
  }

  @override
  Stream<Map<String, num>> watchBranchStock(String companyId, String branchId) {
    if (branchId.isEmpty) return Stream.value(const {});
    return _stock(companyId, branchId).snapshots().map((snap) {
      final map = <String, num>{};
      for (final d in snap.docs) {
        map[d.id] = (d.data()['qty'] ?? 0) as num;
      }
      return map;
    });
  }

  @override
  Future<void> adjustStock({
    required String companyId,
    required String branchId,
    required String productId,
    required num delta,
    required StockMovementType type,
    String note = '',
    String userId = '',
  }) async {
    if (branchId.isEmpty) throw StateError('No branch selected');
    final stockRef = _stock(companyId, branchId).doc(productId);
    final moveRef = _movements(companyId, branchId).doc();

    await _db.runTransaction((tx) async {
      final snap = await tx.get(stockRef);
      final current = (snap.data()?['qty'] ?? 0) as num;
      final next = current + delta;
      if (next < 0) {
        throw StateError('Insufficient stock: have $current, change $delta');
      }
      tx.set(stockRef, {'qty': next}, SetOptions(merge: true));
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
      String companyId, String branchId, String productId) {
    if (branchId.isEmpty) return Stream.value(const []);
    return _movements(companyId, branchId)
        .where('productId', isEqualTo: productId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snap) =>
            snap.docs.map((d) => StockMovement.fromMap(d.id, d.data())).toList());
  }

  @override
  Future<int> importLegacyStock(String companyId, String branchId) async {
    if (branchId.isEmpty) throw StateError('No branch selected');

    final products = await _products(companyId).get();
    final existing = await _stock(companyId, branchId).get();
    final existingIds = existing.docs.map((d) => d.id).toSet();
    final now = DateTime.now();

    var batch = _db.batch();
    var ops = 0;
    var count = 0;
    for (final doc in products.docs) {
      if (existingIds.contains(doc.id)) continue; // already has branch stock
      final legacy = (doc.data()['stock'] ?? 0) as num;
      if (legacy <= 0) continue;

      batch.set(_stock(companyId, branchId).doc(doc.id), {'qty': legacy});
      final moveRef = _movements(companyId, branchId).doc();
      batch.set(
        moveRef,
        StockMovement(
          id: moveRef.id,
          productId: doc.id,
          type: StockMovementType.add,
          delta: legacy,
          resultingStock: legacy,
          createdAt: now,
          note: 'Imported opening stock',
        ).toMap(),
      );
      count++;
      ops += 2;
      if (ops >= 400) {
        await batch.commit();
        batch = _db.batch();
        ops = 0;
      }
    }
    if (ops > 0) await batch.commit();
    return count;
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
