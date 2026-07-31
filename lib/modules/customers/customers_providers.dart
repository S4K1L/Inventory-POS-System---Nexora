import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/company/company_providers.dart';
import 'data/firestore_customers_repository.dart';
import 'domain/customer.dart';
import 'domain/customers_repository.dart';

final customersRepositoryProvider = Provider<CustomersRepository>((ref) {
  return FirestoreCustomersRepository(FirebaseFirestore.instance);
});

final _companyIdProvider = Provider<String>((ref) {
  return ref.watch(currentProfileProvider).companyId;
});

final customersProvider = StreamProvider<List<Customer>>((ref) {
  final cid = ref.watch(_companyIdProvider);
  if (cid.isEmpty) return Stream.value(const []);
  return ref.watch(customersRepositoryProvider).watchCustomers(cid);
});

final customerActionsProvider = Provider<CustomerActions>((ref) {
  return CustomerActions(
    ref.watch(customersRepositoryProvider),
    ref.watch(currentProfileProvider).companyId,
  );
});

class CustomerActions {
  CustomerActions(this._repo, this._companyId);
  final CustomersRepository _repo;
  final String _companyId;

  Future<String> create(Customer c) => _repo.createCustomer(_companyId, c);
  Future<void> update(Customer c) => _repo.updateCustomer(_companyId, c);
  Future<void> archive(String id) => _repo.archiveCustomer(_companyId, id);
}
