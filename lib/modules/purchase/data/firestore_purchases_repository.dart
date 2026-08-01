import 'package:cloud_firestore/cloud_firestore.dart';

import '../../inventory/domain/stock_movement.dart';
import '../domain/purchase.dart';
import '../domain/purchases_repository.dart';

/// Firestore implementation of purchases — scoped per branch (stock in goes to
/// a specific branch). Suppliers/products are company-wide.
///
/// Per branch:  companies/{cid}/branches/{bid}/purchases,  /stock/{pid} { qty },
///              /stock_movements,  /meta/counters
class FirestorePurchasesRepository implements PurchasesRepository {
  FirestorePurchasesRepository(this._db);

  final FirebaseFirestore _db;

  DocumentReference<Map<String, dynamic>> _company(String cid) =>
      _db.collection('companies').doc(cid);
  DocumentReference<Map<String, dynamic>> _branch(String cid, String bid) =>
      _company(cid).collection('branches').doc(bid);
  CollectionReference<Map<String, dynamic>> _purchases(String cid, String bid) =>
      _branch(cid, bid).collection('purchases');
  CollectionReference<Map<String, dynamic>> _stock(String cid, String bid) =>
      _branch(cid, bid).collection('stock');
  CollectionReference<Map<String, dynamic>> _movements(String cid, String bid) =>
      _branch(cid, bid).collection('stock_movements');
  DocumentReference<Map<String, dynamic>> _counters(String cid, String bid) =>
      _branch(cid, bid).collection('meta').doc('counters');
  CollectionReference<Map<String, dynamic>> _products(String cid) =>
      _company(cid).collection('products');
  CollectionReference<Map<String, dynamic>> _suppliers(String cid) =>
      _company(cid).collection('suppliers');

  @override
  Future<Purchase> receive(
      String companyId, String branchId, PurchaseRequest req) async {
    if (branchId.isEmpty) throw StateError('No branch selected');
    if (req.items.isEmpty) {
      throw StateError('Add at least one product to receive');
    }

    final purchaseRef = _purchases(companyId, branchId).doc();
    final counterRef = _counters(companyId, branchId);
    final supplierRef =
        req.supplierId.isEmpty ? null : _suppliers(companyId).doc(req.supplierId);
    final now = DateTime.now();

    return _db.runTransaction<Purchase>((tx) async {
      // ---- READS ----
      final stockRefs = {
        for (final item in req.items)
          item.productId: _stock(companyId, branchId).doc(item.productId)
      };
      final snaps = <String, DocumentSnapshot<Map<String, dynamic>>>{};
      for (final e in stockRefs.entries) {
        snaps[e.key] = await tx.get(e.value);
      }
      final counterSnap = await tx.get(counterRef);
      DocumentSnapshot<Map<String, dynamic>>? supplierSnap;
      if (supplierRef != null) supplierSnap = await tx.get(supplierRef);

      // ---- COMPUTE ----
      num subtotal = 0;
      final newStock = <String, num>{};
      for (final item in req.items) {
        final current = (snaps[item.productId]?.data()?['qty'] ?? 0) as num;
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
        tx.set(stockRefs[item.productId]!, {'qty': newStock[item.productId]},
            SetOptions(merge: true));

        // Keep the catalog's latest cost price up to date (company-wide).
        if (req.updateCostPrice && item.unitCost > 0) {
          tx.set(_products(companyId).doc(item.productId),
              {'purchasePrice': item.unitCost}, SetOptions(merge: true));
        }

        final moveRef = _movements(companyId, branchId).doc();
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

      if (supplierRef != null && supplierSnap != null && due > 0) {
        final currentDue = (supplierSnap.data()?['dueAmount'] ?? 0) as num;
        tx.update(supplierRef, {'dueAmount': currentDue + due});
      }

      return purchase;
    });
  }

  @override
  Stream<List<Purchase>> watchRecentPurchases(String companyId, String branchId,
      {int limit = 100}) {
    if (branchId.isEmpty) return Stream.value(const []);
    return _purchases(companyId, branchId)
        .orderBy('createdAt', descending: true)
        .limit(limit)
        .snapshots()
        .map((s) =>
            s.docs.map((d) => Purchase.fromMap(d.id, d.data())).toList());
  }
}
