/// A product in the catalog. Stored at
/// `companies/{companyId}/products/{id}`.
///
/// [stock] is kept on the document and mutated transactionally alongside a
/// [StockMovement] log entry — so the current quantity is a cheap single read
/// while full history is preserved. (Firestore can't sum a movements
/// collection cheaply, so we don't try.)
class Product {
  const Product({
    required this.id,
    required this.name,
    this.sku = '',
    this.barcode = '',
    this.categoryId,
    this.categoryName = '',
    this.brand = '',
    this.unit = 'pcs',
    this.purchasePrice = 0,
    this.sellingPrice = 0,
    this.wholesalePrice = 0,
    this.stock = 0,
    this.minStock = 0,
    this.taxRate = 0,
    this.imageUrl,
    this.active = true,
  });

  final String id;
  final String name;
  final String sku;
  final String barcode;

  /// Reference to a [Category]; [categoryName] is denormalized for cheap list
  /// rendering without a join.
  final String? categoryId;
  final String categoryName;

  final String brand;
  final String unit;

  final num purchasePrice;
  final num sellingPrice;
  final num wholesalePrice;

  final num stock;
  final num minStock;

  final num taxRate;
  final String? imageUrl;
  final bool active;

  bool get isLowStock => minStock > 0 && stock <= minStock;
  bool get isOutOfStock => stock <= 0;

  /// Estimated margin per unit (selling − purchase).
  num get unitMargin => sellingPrice - purchasePrice;

  Product copyWith({
    String? name,
    String? sku,
    String? barcode,
    String? categoryId,
    String? categoryName,
    String? brand,
    String? unit,
    num? purchasePrice,
    num? sellingPrice,
    num? wholesalePrice,
    num? stock,
    num? minStock,
    num? taxRate,
    String? imageUrl,
    bool? active,
  }) {
    return Product(
      id: id,
      name: name ?? this.name,
      sku: sku ?? this.sku,
      barcode: barcode ?? this.barcode,
      categoryId: categoryId ?? this.categoryId,
      categoryName: categoryName ?? this.categoryName,
      brand: brand ?? this.brand,
      unit: unit ?? this.unit,
      purchasePrice: purchasePrice ?? this.purchasePrice,
      sellingPrice: sellingPrice ?? this.sellingPrice,
      wholesalePrice: wholesalePrice ?? this.wholesalePrice,
      stock: stock ?? this.stock,
      minStock: minStock ?? this.minStock,
      taxRate: taxRate ?? this.taxRate,
      imageUrl: imageUrl ?? this.imageUrl,
      active: active ?? this.active,
    );
  }

  factory Product.fromMap(String id, Map<String, dynamic> data) {
    num n(String k) => (data[k] ?? 0) as num;
    return Product(
      id: id,
      name: (data['name'] ?? '') as String,
      sku: (data['sku'] ?? '') as String,
      barcode: (data['barcode'] ?? '') as String,
      categoryId: data['categoryId'] as String?,
      categoryName: (data['categoryName'] ?? '') as String,
      brand: (data['brand'] ?? '') as String,
      unit: (data['unit'] ?? 'pcs') as String,
      purchasePrice: n('purchasePrice'),
      sellingPrice: n('sellingPrice'),
      wholesalePrice: n('wholesalePrice'),
      stock: n('stock'),
      minStock: n('minStock'),
      taxRate: n('taxRate'),
      imageUrl: data['imageUrl'] as String?,
      active: data['active'] != false,
    );
  }

  /// For writes. [stock] is intentionally excluded — quantity only ever changes
  /// through [InventoryRepository.adjustStock] so history stays consistent.
  Map<String, dynamic> toMap({bool includeStock = false}) {
    final map = <String, dynamic>{
      'name': name,
      'sku': sku,
      'barcode': barcode,
      'categoryId': categoryId,
      'categoryName': categoryName,
      'brand': brand,
      'unit': unit,
      'purchasePrice': purchasePrice,
      'sellingPrice': sellingPrice,
      'wholesalePrice': wholesalePrice,
      'minStock': minStock,
      'taxRate': taxRate,
      'imageUrl': imageUrl,
      'active': active,
    };
    if (includeStock) map['stock'] = stock;
    return map;
  }
}
