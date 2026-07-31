import 'package:cloud_firestore/cloud_firestore.dart';

import '../../inventory/domain/stock_movement.dart';
import '../domain/purchase.dart';
import '../domain/purchases_repository.dart';

/// Firestore implementation. [receive] is a single transaction mirroring the
/// POS checkout, but adding stock instead of removing it: reads products +
/// counter + supplier, then writes the purchase, a `purchase` movement per
/// line, incremented stock (and latest cost), the bumped supplier due, and the
/// bill counter — all or nothing.
class FirestorePurchasesRepository implements PurchasesRepository {
  FirestorePurchasesRepository(this._db);

  final FirebaseFirestore _db;

  DocumentReference<Map<String, dynamic>> _company(String cid) =>
      _db.collection('companies').doc(cid);
  CollectionReference<Map<String, dynamic>> _purchases(String cid) =>
      _company(cid).collection('purchases');
  CollectionReference<Map<String, dynamic>> _products(String cid) =>
      _company(cid).collection('products');
  CollectionReference<Map<String, dynamic>> _movements(String cid) =>
      _company(cid).collection('stock_movements');
  CollectionReference<Map<String, dynamic>> _suppliers(String cid) =>
      _company(cid).collection('suppliers');
  DocumentReference<Map<String, dynamic>> _counters(String cid) =>
      _company(cid).collection('meta').doc('counters');

  @override
  Future<Purchase> receive(String companyId, PurchaseRequest req) async {
    if (req.items.isEmpty) {
      throw StateError('Add at least one product to receive');
    }

    final purchaseRef = _purchases(companyId).doc();
    final counterRef = _counters(companyId);
    final supplierRef =
        req.supplierId.isEmpty ? null : _suppliers(companyId).doc(req.supplierId);
    final now = DateTime.now();

    return _db.runTransaction<Purchase>((tx) async {
      // ---- READS ----
      final productRefs = {
        for (final item in req.items)
          item.productId: _products(companyId).doc(item.productId)
      };
      final snaps = <String, DocumentSnapshot<Map<String, dynamic>>>{};
      for (final e in productRefs.entries) {
        snaps[e.key] = await tx.get(e.value);
      }
      final counterSnap = await tx.get(counterRef);
      DocumentSnapshot<Map<String, dynamic>>? supplierSnap;
      if (supplierRef != null) supplierSnap = await tx.get(supplierRef);

      // ---- COMPUTE ----
      num subtotal = 0;
      final newStock = <String, num>{};
      for (final item in req.items) {
        final snap = snaps[item.productId]!;
        if (!snap.exists) {
          throw StateError('“${item.name}” no longer exists');
        }
        final current = (snap.data()?['stock'] ?? 0) as num;
        newStock[item.productId] = current + item.quantity;
        subtotal += item.quantity * item.unitCost;
      }

      final discount = req.discount.clamp(0, subtotal);
      final total = (subtotal - discount) + req.tax + req.shipping;
      final due = (total - req.paid).clamp(0, double.infinity);

      final nextNo = ((counterSnap.data()?['purchases'] ?? 0) as num).toInt() + 1;
      final billNo = 'PB-${now.year}-${nextNo.toString().padLeft(5, '0')}';

      final purchase = Purchase(
        id: purchaseRef.id,
        billNo: billNo,
        supplierId: req.supplierId,
        supplierName: req.supplierName,
        items: req.items,
        subtotal: subtotal,
        discount: discount,
        tax: req.tax,
        shipping: req.shipping,
        total: total,
        paid: req.paid,
        createdAt: now,
        note: req.note,
        userId: req.userId,
      );

      // ---- WRITES ----
      tx.set(purchaseRef, purchase.toMap());
      tx.set(counterRef, {'purchases': nextNo}, SetOptions(merge: true));

      for (final item in req.items) {
        final update = <String, dynamic>{'stock': newStock[item.productId]};
        if (req.updateCostPrice && item.unitCost > 0) {
          update['purchasePrice'] = item.unitCost;
        }
        tx.update(productRefs[item.productId]!, update);

        final moveRef = _movements(companyId).doc();
        tx.set(
          moveRef,
          StockMovement(
            id: moveRef.id,
            productId: item.productId,
            type: StockMovementType.purchase,
            delta: item.quantity,
            resultingStock: newStock[item.productId]!,
            createdAt: now,
            note: 'Purchase $billNo',
            userId: req.userId,
          ).toMap(),
        );
      }

      // Increase supplier payable by any unpaid balance.
      if (supplierRef != null && supplierSnap != null && due > 0) {
        final currentDue = (supplierSnap.data()?['dueAmount'] ?? 0) as num;
        tx.update(supplierRef, {'dueAmount': currentDue + due});
      }

      return purchase;
    });
  }

  @override
  Stream<List<Purchase>> watchRecentPurchases(String companyId,
      {int limit = 100}) {
    return _purchases(companyId)
        .orderBy('createdAt', descending: true)
        .limit(limit)
        .snapshots()
        .map((s) =>
            s.docs.map((d) => Purchase.fromMap(d.id, d.data())).toList());
  }
}
