import 'sale.dart';

/// A validated checkout request. Totals are recomputed server-side (in the
/// transaction) from the items + discount + tax to avoid trusting the client.
class CheckoutRequest {
  const CheckoutRequest({
    required this.items,
    required this.discount,
    required this.taxRate,
    required this.paid,
    required this.paymentMethod,
    this.customerId = '',
    this.customerName = '',
    this.userId = '',
  });

  final List<SaleItem> items;
  final num discount;
  final num taxRate;
  final num paid;
  final PaymentMethod paymentMethod;
  final String customerId;
  final String customerName;
  final String userId;
}

/// Contract for sales. All operations are scoped to a branch (stock and sales
/// are per-branch); customers are company-wide.
abstract interface class SalesRepository {
  /// Records a sale AND decrements branch stock for every line, atomically.
  /// Throws if any line has insufficient stock. Returns the persisted [Sale].
  Future<Sale> checkout(
      String companyId, String branchId, CheckoutRequest request);

  /// Sales on or after [from] at a branch (used for "today's sales").
  Stream<List<Sale>> watchSalesSince(
      String companyId, String branchId, DateTime from);

  /// Most recent sales at a branch, newest first.
  Stream<List<Sale>> watchRecentSales(String companyId, String branchId,
      {int limit = 50});
}
