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
    this.customerName = '',
    this.userId = '',
  });

  final List<SaleItem> items;
  final num discount;
  final num taxRate;
  final num paid;
  final PaymentMethod paymentMethod;
  final String customerName;
  final String userId;
}

/// Contract for sales. As with inventory, the app depends on this interface.
abstract interface class SalesRepository {
  /// Records a sale AND decrements stock for every line, atomically. Throws if
  /// any line has insufficient stock. Returns the persisted [Sale].
  Future<Sale> checkout(String companyId, CheckoutRequest request);

  /// Sales on or after [from] (used for "today's sales").
  Stream<List<Sale>> watchSalesSince(String companyId, DateTime from);

  /// Most recent sales, newest first.
  Stream<List<Sale>> watchRecentSales(String companyId, {int limit = 50});
}
