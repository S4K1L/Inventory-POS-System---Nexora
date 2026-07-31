import 'package:cloud_firestore/cloud_firestore.dart';

import '../domain/supplier.dart';
import '../domain/suppliers_repository.dart';

/// Firestore implementation. Data at `companies/{cid}/suppliers/{id}`.
class FirestoreSuppliersRepository implements SuppliersRepository {
  FirestoreSuppliersRepository(this._db);

  final FirebaseFirestore _db;

  CollectionReference<Map<String, dynamic>> _col(String cid) =>
      _db.collection('companies').doc(cid).collection('suppliers');

  @override
  Stream<List<Supplier>> watchSuppliers(String companyId) {
    return _col(companyId).orderBy('name').snapshots().map(
        (s) => s.docs.map((d) => Supplier.fromMap(d.id, d.data())).toList());
  }

  @override
  Future<String> createSupplier(String companyId, Supplier supplier) async {
    final ref = _col(companyId).doc();
    await ref.set({...supplier.toMap(), 'dueAmount': 0});
    return ref.id;
  }

  @override
  Future<void> updateSupplier(String companyId, Supplier supplier) {
    return _col(companyId).doc(supplier.id).update(supplier.toMap());
  }

  @override
  Future<void> archiveSupplier(String companyId, String supplierId) {
    return _col(companyId).doc(supplierId).update({'active': false});
  }
}
