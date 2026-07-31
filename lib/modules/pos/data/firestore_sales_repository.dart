import 'package:cloud_firestore/cloud_firestore.dart';

import '../../inventory/domain/stock_movement.dart';
import '../domain/sale.dart';
import '../domain/sales_repository.dart';

/// Firestore implementation of POS sales.
///
/// [checkout] runs a single transaction that: reads every product + the
/// invoice counter, validates stock, then writes the sale, a `sale` stock
/// movement per line, decremented product stock, and the bumped counter — all
/// or nothing. Firestore requires all reads before any writes, which this
/// respects.
class FirestoreSalesRepository implements SalesRepository {
  FirestoreSalesRepository(this._db);

  final FirebaseFirestore _db;

  DocumentReference<Map<String, dynamic>> _company(String cid) =>
      _db.collection('companies').doc(cid);
  CollectionReference<Map<String, dynamic>> _sales(String cid) =>
      _company(cid).collection('sales');
  CollectionReference<Map<String, dynamic>> _products(String cid) =>
      _company(cid).collection('products');
  CollectionReference<Map<String, dynamic>> _movements(String cid) =>
      _company(cid).collection('stock_movements');
  DocumentReference<Map<String, dynamic>> _counters(String cid) =>
      _company(cid).collection('meta').doc('counters');

  @override
  Future<Sale> checkout(String companyId, CheckoutRequest req) async {
    if (req.items.isEmpty) {
      throw StateError('Cannot check out an empty cart');
    }

    final saleRef = _sales(companyId).doc();
    final counterRef = _counters(companyId);
    final now = DateTime.now();

    return _db.runTransaction<Sale>((tx) async {
      // ---- READS (must all precede writes) ----
      final productRefs = {
        for (final item in req.items)
          item.productId: _products(companyId).doc(item.productId)
      };
      final snaps = <String, DocumentSnapshot<Map<String, dynamic>>>{};
      for (final entry in productRefs.entries) {
        snaps[entry.key] = await tx.get(entry.value);
      }
      final counterSnap = await tx.get(counterRef);

      // ---- VALIDATE + COMPUTE ----
      num subtotal = 0;
      final newStock = <String, num>{};
      for (final item in req.items) {
        final snap = snaps[item.productId]!;
        if (!snap.exists) {
          throw StateError('“${item.name}” no longer exists');
        }
        final current = (snap.data()?['stock'] ?? 0) as num;
        final remaining = current - item.quantity;
        if (remaining < 0) {
          throw StateError(
              'Not enough stock for “${item.name}” (have $current)');
        }
        newStock[item.productId] = remaining;
        subtotal += item.unitPrice * item.quantity;
      }

      final discount = req.discount.clamp(0, subtotal);
      final taxable = subtotal - discount;
      final tax = taxable * req.taxRate / 100;
      final total = taxable + tax;

      final nextNo = ((counterSnap.data()?['sales'] ?? 0) as num).toInt() + 1;
      final invoiceNo = 'INV-${now.year}-${nextNo.toString().padLeft(5, '0')}';

      final sale = Sale(
        id: saleRef.id,
        invoiceNo: invoiceNo,
        items: req.items,
        subtotal: subtotal,
        discount: discount,
        tax: tax,
        total: total,
        paid: req.paid,
        paymentMethod: req.paymentMethod,
        createdAt: now,
        customerName: req.customerName,
        userId: req.userId,
      );

      // ---- WRITES ----
      tx.set(saleRef, sale.toMap());
      tx.set(counterRef, {'sales': nextNo}, SetOptions(merge: true));
      for (final item in req.items) {
        tx.update(productRefs[item.productId]!,
            {'stock': newStock[item.productId]});
        final moveRef = _movements(companyId).doc();
        tx.set(
          moveRef,
          StockMovement(
            id: moveRef.id,
            productId: item.productId,
            type: StockMovementType.sale,
            delta: -item.quantity,
            resultingStock: newStock[item.productId]!,
            createdAt: now,
            note: 'Sale $invoiceNo',
            userId: req.userId,
          ).toMap(),
        );
      }

      return sale;
    });
  }

  @override
  Stream<List<Sale>> watchSalesSince(String companyId, DateTime from) {
    return _sales(companyId)
        .where('createdAt', isGreaterThanOrEqualTo: from.toIso8601String())
        .snapshots()
        .map((s) => s.docs.map((d) => Sale.fromMap(d.id, d.data())).toList());
  }

  @override
  Stream<List<Sale>> watchRecentSales(String companyId, {int limit = 50}) {
    return _sales(companyId)
        .orderBy('createdAt', descending: true)
        .limit(limit)
        .snapshots()
        .map((s) => s.docs.map((d) => Sale.fromMap(d.id, d.data())).toList());
  }
}
