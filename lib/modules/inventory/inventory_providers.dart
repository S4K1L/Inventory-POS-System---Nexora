import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/company/company_providers.dart';
import '../branches/branches_providers.dart';
import 'data/firestore_inventory_repository.dart';
import 'domain/category.dart';
import 'domain/inventory_repository.dart';
import 'domain/product.dart';
import 'domain/stock_movement.dart';

/// Swap seam for the inventory backend.
final inventoryRepositoryProvider = Provider<InventoryRepository>((ref) {
  return FirestoreInventoryRepository(FirebaseFirestore.instance);
});

final _companyIdProvider = Provider<String>((ref) {
  return ref.watch(currentProfileProvider).companyId;
});

/// The shared product catalog. Each product's `stock` field here is its LEGACY
/// value (pre-multi-branch); branch quantities live in [branchStockProvider].
final catalogProductsProvider = StreamProvider<List<Product>>((ref) {
  final cid = ref.watch(_companyIdProvider);
  if (cid.isEmpty) return Stream.value(const []);
  return ref.watch(inventoryRepositoryProvider).watchProducts(cid);
});

/// Stock levels for the currently-selected branch (productId → qty).
final branchStockProvider = StreamProvider<Map<String, num>>((ref) {
  final cid = ref.watch(_companyIdProvider);
  final bid = ref.watch(currentBranchIdProvider);
  if (cid.isEmpty || bid.isEmpty) return Stream.value(const {});
  return ref.watch(inventoryRepositoryProvider).watchBranchStock(cid, bid);
});

/// Products with their `stock` field set to the CURRENT branch's quantity, so
/// all downstream UI is automatically branch-scoped.
final productsProvider = Provider<AsyncValue<List<Product>>>((ref) {
  final catalog = ref.watch(catalogProductsProvider);
  final stock = ref.watch(branchStockProvider);
  return catalog.whenData((products) {
    final map = stock.value ?? const <String, num>{};
    return products
        .map((p) => p.copyWith(stock: map[p.id] ?? 0))
        .toList();
  });
});

/// Categories for the current company.
final categoriesProvider = StreamProvider<List<Category>>((ref) {
  final cid = ref.watch(_companyIdProvider);
  if (cid.isEmpty) return Stream.value(const []);
  return ref.watch(inventoryRepositoryProvider).watchCategories(cid);
});

/// Stock movement history for one product at the current branch.
final movementsProvider =
    StreamProvider.family<List<StockMovement>, String>((ref, productId) {
  final cid = ref.watch(_companyIdProvider);
  final bid = ref.watch(currentBranchIdProvider);
  if (cid.isEmpty || bid.isEmpty) return Stream.value(const []);
  return ref
      .watch(inventoryRepositoryProvider)
      .watchMovements(cid, bid, productId);
});

/// Derived: quick inventory KPIs for the current branch.
final inventoryStatsProvider = Provider<InventoryStats>((ref) {
  final products = ref.watch(productsProvider).value ?? const [];
  return InventoryStats(
    totalProducts: products.length,
    lowStock: products.where((p) => p.isLowStock).length,
    outOfStock: products.where((p) => p.isOutOfStock).length,
    stockValue:
        products.fold<num>(0, (acc, p) => acc + p.purchasePrice * p.stock),
  );
});

/// Count of catalog products that carry legacy stock (>0) but have no entry in
/// the current branch's stock — i.e. what a one-time import would seed.
final legacyStockToImportProvider = Provider<int>((ref) {
  final catalog = ref.watch(catalogProductsProvider).value ?? const [];
  final branchStock = ref.watch(branchStockProvider).value ?? const {};
  return catalog
      .where((p) => p.stock > 0 && !branchStock.containsKey(p.id))
      .length;
});

class InventoryStats {
  const InventoryStats({
    required this.totalProducts,
    required this.lowStock,
    required this.outOfStock,
    required this.stockValue,
  });
  final int totalProducts;
  final int lowStock;
  final int outOfStock;
  final num stockValue;
}
