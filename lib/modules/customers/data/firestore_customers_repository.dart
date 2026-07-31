import 'package:cloud_firestore/cloud_firestore.dart';

import '../domain/customer.dart';
import '../domain/customers_repository.dart';

/// Firestore implementation. Data at `companies/{cid}/customers/{id}`.
class FirestoreCustomersRepository implements CustomersRepository {
  FirestoreCustomersRepository(this._db);

  final FirebaseFirestore _db;

  CollectionReference<Map<String, dynamic>> _col(String cid) =>
      _db.collection('companies').doc(cid).collection('customers');

  @override
  Stream<List<Customer>> watchCustomers(String companyId) {
    return _col(companyId).orderBy('name').snapshots().map(
        (s) => s.docs.map((d) => Customer.fromMap(d.id, d.data())).toList());
  }

  @override
  Future<String> createCustomer(String companyId, Customer customer) async {
    final ref = _col(companyId).doc();
    await ref.set({...customer.toMap(), 'dueAmount': 0, 'loyaltyPoints': 0});
    return ref.id;
  }

  @override
  Future<void> updateCustomer(String companyId, Customer customer) {
    return _col(companyId).doc(customer.id).update(customer.toMap());
  }

  @override
  Future<void> archiveCustomer(String companyId, String customerId) {
    return _col(companyId).doc(customerId).update({'active': false});
  }
}
