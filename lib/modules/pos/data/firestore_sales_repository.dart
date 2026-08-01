import 'package:cloud_firestore/cloud_firestore.dart';

import '../../inventory/domain/stock_movement.dart';
import '../domain/sale.dart';
import '../domain/sales_repository.dart';

/// Firestore implementation of POS sales — scoped per branch.
///
/// Per branch:  companies/{cid}/branches/{bid}/sales,  /stock/{pid} { qty },
///              /stock_movements,  /meta/counters
/// Company-wide: customers (credit due is tracked on the shared customer).
class FirestoreSalesRepository implements SalesRepository {
  FirestoreSalesRepository(this._db);

  final FirebaseFirestore _db;

  DocumentReference<Map<String, dynamic>> _company(String cid) =>
      _db.collection('companies').doc(cid);
  DocumentReference<Map<String, dynamic>> _branch(String cid, String bid) =>
      _company(cid).collection('branches').doc(bid);
  CollectionReference<Map<String, dynamic>> _sales(String cid, String bid) =>
      _branch(cid, bid).collection('sales');
  CollectionReference<Map<String, dynamic>> _stock(String cid, String bid) =>
      _branch(cid, bid).collection('stock');
  CollectionReference<Map<String, dynamic>> _movements(String cid, String bid) =>
      _branch(cid, bid).collection('stock_movements');
  DocumentReference<Map<String, dynamic>> _counters(String cid, String bid) =>
      _branch(cid, bid).collection('meta').doc('counters');
  CollectionReference<Map<String, dynamic>> _customers(String cid) =>
      _company(cid).collection('customers');

  @override
  Future<Sale> checkout(
      String companyId, String branchId, CheckoutRequest req) async {
    if (branchId.isEmpty) throw StateError('No branch selected');
    if (req.items.isEmpty) throw StateError('Cannot check out an empty cart');

    final saleRef = _sales(companyId, branchId).doc();
    final counterRef = _counters(companyId, branchId);
    final customerRef = req.customerId.isEmpty
        ? null
        : _customers(companyId).doc(req.customerId);
    final now = DateTime.now();

    return _db.runTransaction<Sale>((tx) async {
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
      DocumentSnapshot<Map<String, dynamic>>? customerSnap;
      if (customerRef != null) customerSnap = await tx.get(customerRef);

      // ---- VALIDATE + COMPUTE ----
      num subtotal = 0;
      final newStock = <String, num>{};
      for (final item in req.items) {
        final current = (snaps[item.productId]?.data()?['qty'] ?? 0) as num;
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
        customerId: req.customerId,
        customerName: req.customerName,
        userId: req.userId,
      );

      // ---- WRITES ----
      tx.set(saleRef, sale.toMap());
      tx.set(counterRef, {'sales': nextNo}, SetOptions(merge: true));
      for (final item in req.items) {
        tx.set(stockRefs[item.productId]!, {'qty': newStock[item.productId]},
            SetOptions(merge: true));
        final moveRef = _movements(companyId, branchId).doc();
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

      // Credit sale: add any unpaid balance to the (company-wide) customer.
      final due = total - req.paid;
      if (customerRef != null &&
          customerSnap != null &&
          customerSnap.exists &&
          due > 0) {
        final currentDue = (customerSnap.data()?['dueAmount'] ?? 0) as num;
        tx.update(customerRef, {'dueAmount': currentDue + due});
      }

      return sale;
    });
  }

  @override
  Stream<List<Sale>> watchSalesSince(
      String companyId, String branchId, DateTime from) {
    if (branchId.isEmpty) return Stream.value(const []);
    return _sales(companyId, branchId)
        .where('createdAt', isGreaterThanOrEqualTo: from.toIso8601String())
        .snapshots()
        .map((s) => s.docs.map((d) => Sale.fromMap(d.id, d.data())).toList());
  }

  @override
  Stream<List<Sale>> watchRecentSales(String companyId, String branchId,
      {int limit = 50}) {
    if (branchId.isEmpty) return Stream.value(const []);
    return _sales(companyId, branchId)
        .orderBy('createdAt', descending: true)
        .limit(limit)
        .snapshots()
        .map((s) => s.docs.map((d) => Sale.fromMap(d.id, d.data())).toList());
  }
}
