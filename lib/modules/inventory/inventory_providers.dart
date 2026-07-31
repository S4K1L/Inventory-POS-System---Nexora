import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/company/company_providers.dart';
import 'data/firestore_inventory_repository.dart';
import 'domain/category.dart';
import 'domain/inventory_repository.dart';
import 'domain/product.dart';
import 'domain/stock_movement.dart';

/// Swap seam for the inventory backend.
final inventoryRepositoryProvider = Provider<InventoryRepository>((ref) {
  return FirestoreInventoryRepository(FirebaseFirestore.instance);
});

/// The current company id (empty if not loaded / no company).
final _companyIdProvider = Provider<String>((ref) {
  return ref.watch(currentProfileProvider).companyId;
});

/// All products for the current company.
final productsProvider = StreamProvider<List<Product>>((ref) {
  final cid = ref.watch(_companyIdProvider);
  if (cid.isEmpty) return Stream.value(const []);
  return ref.watch(inventoryRepositoryProvider).watchProducts(cid);
});

/// Categories for the current company.
final categoriesProvider = StreamProvider<List<Category>>((ref) {
  final cid = ref.watch(_companyIdProvider);
  if (cid.isEmpty) return Stream.value(const []);
  return ref.watch(inventoryRepositoryProvider).watchCategories(cid);
});

/// Stock movement history for one product.
final movementsProvider =
    StreamProvider.family<List<StockMovement>, String>((ref, productId) {
  final cid = ref.watch(_companyIdProvider);
  if (cid.isEmpty) return Stream.value(const []);
  return ref.watch(inventoryRepositoryProvider).watchMovements(cid, productId);
});

/// Derived: quick inventory KPIs for the dashboard.
final inventoryStatsProvider = Provider<InventoryStats>((ref) {
  final products = ref.watch(productsProvider).value ?? const [];
  return InventoryStats(
    totalProducts: products.length,
    lowStock: products.where((p) => p.isLowStock).length,
    outOfStock: products.where((p) => p.isOutOfStock).length,
    stockValue: products.fold<num>(0, (acc, p) => acc + p.purchasePrice * p.stock),
  );
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
