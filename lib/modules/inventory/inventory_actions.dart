import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/company/company_providers.dart';
import '../branches/branches_providers.dart';
import 'domain/category.dart';
import 'domain/inventory_repository.dart';
import 'domain/product.dart';
import 'domain/stock_movement.dart';
import 'inventory_providers.dart';

/// Convenience wrapper that binds inventory writes to the current company,
/// branch and user, so screens call e.g. `actions.saveProduct(p)` without
/// threading ids.
class InventoryActions {
  InventoryActions(this._repo, this._companyId, this._branchId, this._userId);

  final InventoryRepository _repo;
  final String _companyId;
  final String _branchId;
  final String _userId;

  Future<String> createProduct(Product product, {num openingStock = 0}) {
    return _repo.createProduct(_companyId, product,
        branchId: _branchId, openingStock: openingStock, userId: _userId);
  }

  Future<void> updateProduct(Product product) =>
      _repo.updateProduct(_companyId, product);

  Future<Product?> findByBarcode(String code) =>
      _repo.findByBarcode(_companyId, code);

  Future<void> archiveProduct(String productId) =>
      _repo.archiveProduct(_companyId, productId);

  Future<void> adjustStock({
    required String productId,
    required num delta,
    required StockMovementType type,
    String note = '',
  }) {
    return _repo.adjustStock(
      companyId: _companyId,
      branchId: _branchId,
      productId: productId,
      delta: delta,
      type: type,
      note: note,
      userId: _userId,
    );
  }

  Future<String> createCategory(String name, {String? parentId}) {
    return _repo.createCategory(
        _companyId, Category(id: '', name: name.trim(), parentId: parentId));
  }

  Future<int> importLegacyStock() =>
      _repo.importLegacyStock(_companyId, _branchId);
}

final inventoryActionsProvider = Provider<InventoryActions>((ref) {
  final repo = ref.watch(inventoryRepositoryProvider);
  final profile = ref.watch(currentProfileProvider);
  final branchId = ref.watch(currentBranchIdProvider);
  return InventoryActions(repo, profile.companyId, branchId, profile.uid);
});
