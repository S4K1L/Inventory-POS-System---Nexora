import 'supplier.dart';

/// Contract for supplier data. App depends on this, not on Firestore.
abstract interface class SuppliersRepository {
  Stream<List<Supplier>> watchSuppliers(String companyId);
  Future<String> createSupplier(String companyId, Supplier supplier);
  Future<void> updateSupplier(String companyId, Supplier supplier);
  Future<void> archiveSupplier(String companyId, String supplierId);
}
