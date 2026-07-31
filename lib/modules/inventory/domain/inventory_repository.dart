import 'category.dart';
import 'product.dart';
import 'stock_movement.dart';

/// Contract for inventory data. All methods are scoped by [companyId] to keep
/// tenants isolated. Backed by Firestore today; swap the impl for the custom
/// backend later without touching the UI.
abstract interface class InventoryRepository {
  // Products
  Stream<List<Product>> watchProducts(String companyId);
  Future<Product?> getProduct(String companyId, String productId);

  /// Looks up a single active product by its exact barcode (or SKU). Returns
  /// null if nothing matches. Used by scanners at the POS and product form.
  Future<Product?> findByBarcode(String companyId, String code);

  /// Creates a product and returns its id. Optionally seeds opening stock,
  /// which is recorded as an `add` movement.
  Future<String> createProduct(
    String companyId,
    Product product, {
    num openingStock = 0,
    String userId = '',
  });

  Future<void> updateProduct(String companyId, Product product);
  Future<void> archiveProduct(String companyId, String productId);

  /// Applies a signed [delta] to a product's stock and writes a matching
  /// [StockMovement] — atomically, in a transaction.
  Future<void> adjustStock({
    required String companyId,
    required String productId,
    required num delta,
    required StockMovementType type,
    String note = '',
    String userId = '',
  });

  Stream<List<StockMovement>> watchMovements(String companyId, String productId);

  // Categories
  Stream<List<Category>> watchCategories(String companyId);
  Future<String> createCategory(String companyId, Category category);
}
