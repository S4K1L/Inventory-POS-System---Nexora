import 'category.dart';
import 'product.dart';
import 'stock_movement.dart';

/// Contract for inventory data. The product *catalog* is company-wide; stock is
/// tracked per branch (`branches/{bid}/stock/{productId}`), so stock methods
/// take a [branchId].
abstract interface class InventoryRepository {
  // Products (catalog — shared across branches)
  Stream<List<Product>> watchProducts(String companyId);
  Future<Product?> getProduct(String companyId, String productId);

  /// Looks up a single active product by its exact barcode (or SKU).
  Future<Product?> findByBarcode(String companyId, String code);

  /// Creates a catalog product and returns its id. Any [openingStock] is
  /// recorded against [branchId].
  Future<String> createProduct(
    String companyId,
    Product product, {
    String branchId = '',
    num openingStock = 0,
    String userId = '',
  });

  Future<void> updateProduct(String companyId, Product product);
  Future<void> archiveProduct(String companyId, String productId);

  /// Per-branch stock levels: productId → quantity on hand at [branchId].
  Stream<Map<String, num>> watchBranchStock(String companyId, String branchId);

  /// Applies a signed [delta] to a product's stock AT [branchId] and writes a
  /// matching [StockMovement] — atomically.
  Future<void> adjustStock({
    required String companyId,
    required String branchId,
    required String productId,
    required num delta,
    required StockMovementType type,
    String note = '',
    String userId = '',
  });

  Stream<List<StockMovement>> watchMovements(
      String companyId, String branchId, String productId);

  /// One-time migration: seeds [branchId] stock from any product's legacy
  /// `stock` field (from before per-branch stock existed), skipping products
  /// that already have a branch stock doc. Returns how many were imported.
  Future<int> importLegacyStock(String companyId, String branchId);

  // Categories (shared)
  Stream<List<Category>> watchCategories(String companyId);
  Future<String> createCategory(String companyId, Category category);
}
