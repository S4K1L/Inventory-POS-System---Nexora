import 'customer.dart';

/// Contract for customer data. App depends on this, not on Firestore.
abstract interface class CustomersRepository {
  Stream<List<Customer>> watchCustomers(String companyId);
  Future<String> createCustomer(String companyId, Customer customer);
  Future<void> updateCustomer(String companyId, Customer customer);
  Future<void> archiveCustomer(String companyId, String customerId);
}
