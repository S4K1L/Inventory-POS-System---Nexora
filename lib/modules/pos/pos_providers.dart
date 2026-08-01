import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/company/company_providers.dart';
import '../branches/branches_providers.dart';
import '../inventory/domain/product.dart';
import 'data/firestore_sales_repository.dart';
import 'domain/cart.dart';
import 'domain/sale.dart';
import 'domain/sales_repository.dart';

/// Swap seam for the sales backend.
final salesRepositoryProvider = Provider<SalesRepository>((ref) {
  return FirestoreSalesRepository(FirebaseFirestore.instance);
});

final _companyIdProvider = Provider<String>((ref) {
  return ref.watch(currentProfileProvider).companyId;
});

/// The in-progress sale. Mutated through [CartNotifier].
final cartProvider = NotifierProvider<CartNotifier, Cart>(CartNotifier.new);

class CartNotifier extends Notifier<Cart> {
  @override
  Cart build() => const Cart();

  /// Adds one unit of [product], or increments if already present.
  void add(Product product) {
    final lines = [...state.lines];
    final i = lines.indexWhere((l) => l.product.id == product.id);
    if (i >= 0) {
      lines[i] = lines[i].copyWith(quantity: lines[i].quantity + 1);
    } else {
      lines.add(CartLine(product: product, quantity: 1));
    }
    state = state.copyWith(lines: lines);
  }

  void setQuantity(String productId, num qty) {
    if (qty <= 0) {
      removeLine(productId);
      return;
    }
    final lines = [
      for (final l in state.lines)
        if (l.product.id == productId) l.copyWith(quantity: qty) else l
    ];
    state = state.copyWith(lines: lines);
  }

  void increment(String productId) {
    final l = state.lines.firstWhere((l) => l.product.id == productId);
    setQuantity(productId, l.quantity + 1);
  }

  void decrement(String productId) {
    final l = state.lines.firstWhere((l) => l.product.id == productId);
    setQuantity(productId, l.quantity - 1);
  }

  void removeLine(String productId) {
    state = state.copyWith(
      lines: state.lines.where((l) => l.product.id != productId).toList(),
    );
  }

  void setDiscount(num value) =>
      state = state.copyWith(discount: value.clamp(0, double.infinity));

  void setTaxRate(num value) =>
      state = state.copyWith(taxRate: value.clamp(0, 100));

  void setCustomer(String id, String name) =>
      state = state.copyWith(customerId: id, customerName: name);

  void clear() => state = const Cart();
}

/// Most recent sales (newest first) at the current branch — Sales History.
final recentSalesProvider = StreamProvider<List<Sale>>((ref) {
  final cid = ref.watch(_companyIdProvider);
  final bid = ref.watch(currentBranchIdProvider);
  if (cid.isEmpty || bid.isEmpty) return Stream.value(const []);
  return ref
      .watch(salesRepositoryProvider)
      .watchRecentSales(cid, bid, limit: 100);
});

/// Sales since local midnight at the current branch — "Today's Sales".
final todaySalesProvider = StreamProvider<List<Sale>>((ref) {
  final cid = ref.watch(_companyIdProvider);
  final bid = ref.watch(currentBranchIdProvider);
  if (cid.isEmpty || bid.isEmpty) return Stream.value(const []);
  final now = DateTime.now();
  final midnight = DateTime(now.year, now.month, now.day);
  return ref.watch(salesRepositoryProvider).watchSalesSince(cid, bid, midnight);
});

/// Aggregated totals for today.
final todayStatsProvider = Provider<TodayStats>((ref) {
  final sales = ref.watch(todaySalesProvider).value ?? const [];
  return TodayStats(
    count: sales.length,
    revenue: sales.fold<num>(0, (s, x) => s + x.total),
  );
});

class TodayStats {
  const TodayStats({required this.count, required this.revenue});
  final int count;
  final num revenue;
}

/// Runs checkout using the current company + branch + user.
final checkoutServiceProvider = Provider<CheckoutService>((ref) {
  final repo = ref.watch(salesRepositoryProvider);
  final profile = ref.watch(currentProfileProvider);
  final branchId = ref.watch(currentBranchIdProvider);
  return CheckoutService(repo, profile.companyId, branchId, profile.uid);
});

class CheckoutService {
  CheckoutService(this._repo, this._companyId, this._branchId, this._userId);
  final SalesRepository _repo;
  final String _companyId;
  final String _branchId;
  final String _userId;

  Future<Sale> checkout({
    required Cart cart,
    required num paid,
    required PaymentMethod method,
    String customerId = '',
    String customerName = '',
  }) {
    return _repo.checkout(
      _companyId,
      _branchId,
      CheckoutRequest(
        items: cart.lines.map((l) => l.toSaleItem()).toList(),
        discount: cart.discount,
        taxRate: cart.taxRate,
        paid: paid,
        paymentMethod: method,
        customerId: customerId,
        customerName: customerName,
        userId: _userId,
      ),
    );
  }
}
