import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/company/company_providers.dart';
import 'data/firestore_suppliers_repository.dart';
import 'domain/supplier.dart';
import 'domain/suppliers_repository.dart';

final suppliersRepositoryProvider = Provider<SuppliersRepository>((ref) {
  return FirestoreSuppliersRepository(FirebaseFirestore.instance);
});

final _companyIdProvider = Provider<String>((ref) {
  return ref.watch(currentProfileProvider).companyId;
});

final suppliersProvider = StreamProvider<List<Supplier>>((ref) {
  final cid = ref.watch(_companyIdProvider);
  if (cid.isEmpty) return Stream.value(const []);
  return ref.watch(suppliersRepositoryProvider).watchSuppliers(cid);
});

/// Thin write helper bound to the current company.
final supplierActionsProvider = Provider<SupplierActions>((ref) {
  return SupplierActions(
    ref.watch(suppliersRepositoryProvider),
    ref.watch(currentProfileProvider).companyId,
  );
});

class SupplierActions {
  SupplierActions(this._repo, this._companyId);
  final SuppliersRepository _repo;
  final String _companyId;

  Future<String> create(Supplier s) => _repo.createSupplier(_companyId, s);
  Future<void> update(Supplier s) => _repo.updateSupplier(_companyId, s);
  Future<void> archive(String id) => _repo.archiveSupplier(_companyId, id);
}
