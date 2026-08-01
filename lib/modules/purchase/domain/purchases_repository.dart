import 'purchase.dart';

/// A request to receive goods. Totals are computed server-side in the
/// transaction from items + discount + tax + shipping.
class PurchaseRequest {
  const PurchaseRequest({
    required this.supplierId,
    required this.supplierName,
    required this.items,
    this.discount = 0,
    this.tax = 0,
    this.shipping = 0,
    this.paid = 0,
    this.note = '',
    this.userId = '',
    this.updateCostPrice = true,
  });

  final String supplierId;
  final String supplierName;
  final List<PurchaseItem> items;
  final num discount;
  final num tax;
  final num shipping;
  final num paid;
  final String note;
  final String userId;

  /// When true, each product's purchasePrice is updated to the latest unit cost.
  final bool updateCostPrice;
}

/// Contract for purchases (stock in). Stock and purchases are per-branch;
/// suppliers are company-wide.
abstract interface class PurchasesRepository {
  /// Records the purchase AND increments branch stock for every line,
  /// atomically: stock += qty, a `purchase` movement per line, the supplier's
  /// due rises by any unpaid balance, and a bill number is assigned.
  Future<Purchase> receive(
      String companyId, String branchId, PurchaseRequest request);

  Stream<List<Purchase>> watchRecentPurchases(String companyId, String branchId,
      {int limit = 100});
}
