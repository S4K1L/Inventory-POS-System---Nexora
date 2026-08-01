import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/company/company_providers.dart';
import '../inventory/inventory_providers.dart';
import '../pos/domain/sale.dart';
import '../pos/pos_providers.dart';

/// Live overview stats for a single branch — used by the owner's branch
/// monitoring view. Kept in its own file to avoid import cycles between the
/// branches, pos and inventory provider modules.

final _companyIdProvider = Provider<String>((ref) {
  return ref.watch(currentProfileProvider).companyId;
});

/// Stock quantities for an arbitrary branch (not just the active one).
final branchStockFamilyProvider =
    StreamProvider.family<Map<String, num>, String>((ref, branchId) {
  final cid = ref.watch(_companyIdProvider);
  if (cid.isEmpty || branchId.isEmpty) return Stream.value(const {});
  return ref
      .watch(inventoryRepositoryProvider)
      .watchBranchStock(cid, branchId);
});

/// Today's sales for an arbitrary branch.
final branchTodaySalesFamilyProvider =
    StreamProvider.family<List<Sale>, String>((ref, branchId) {
  final cid = ref.watch(_companyIdProvider);
  if (cid.isEmpty || branchId.isEmpty) return Stream.value(const []);
  final now = DateTime.now();
  final midnight = DateTime(now.year, now.month, now.day);
  return ref
      .watch(salesRepositoryProvider)
      .watchSalesSince(cid, branchId, midnight);
});

class BranchOverview {
  const BranchOverview({
    required this.revenue,
    required this.orders,
    required this.stockValue,
    required this.lowStock,
    required this.loading,
  });

  final num revenue;
  final int orders;
  final num stockValue;
  final int lowStock;
  final bool loading;
}

/// Composed overview for one branch: today's revenue/orders + current stock
/// value and low-stock count.
final branchOverviewProvider =
    Provider.family<BranchOverview, String>((ref, branchId) {
  final catalog = ref.watch(catalogProductsProvider).value ?? const [];
  final stockAsync = ref.watch(branchStockFamilyProvider(branchId));
  final salesAsync = ref.watch(branchTodaySalesFamilyProvider(branchId));

  final stock = stockAsync.value ?? const <String, num>{};
  final sales = salesAsync.value ?? const <Sale>[];

  num stockValue = 0;
  int lowStock = 0;
  for (final p in catalog) {
    final qty = stock[p.id] ?? 0;
    stockValue += p.purchasePrice * qty;
    if (p.minStock > 0 && qty <= p.minStock) lowStock++;
  }

  return BranchOverview(
    revenue: sales.fold<num>(0, (t, s) => t + s.total),
    orders: sales.length,
    stockValue: stockValue,
    lowStock: lowStock,
    loading: stockAsync.isLoading || salesAsync.isLoading,
  );
});
