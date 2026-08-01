import '../../inventory/domain/product.dart';
import 'sale.dart';

/// A single cart line: a product plus the quantity being sold.
class CartLine {
  const CartLine({required this.product, required this.quantity});

  final Product product;
  final num quantity;

  num get lineTotal => product.sellingPrice * quantity;

  CartLine copyWith({num? quantity}) =>
      CartLine(product: product, quantity: quantity ?? this.quantity);

  SaleItem toSaleItem() => SaleItem(
        productId: product.id,
        name: product.name,
        unitPrice: product.sellingPrice,
        quantity: quantity,
        unitCost: product.purchasePrice,
      );
}

/// The current sale in progress. Immutable value object; the cart notifier
/// swaps in a new one on each change.
class Cart {
  const Cart({
    this.lines = const [],
    this.discount = 0,
    this.taxRate = 0,
    this.customerId = '',
    this.customerName = '',
  });

  final List<CartLine> lines;
  final num discount;

  /// Sale-level tax percentage (0–100).
  final num taxRate;

  /// Optional customer this sale is attached to.
  final String customerId;
  final String customerName;

  bool get isEmpty => lines.isEmpty;
  bool get isNotEmpty => lines.isNotEmpty;
  int get count => lines.fold(0, (n, l) => n + l.quantity.toInt());

  num get subtotal => lines.fold<num>(0, (s, l) => s + l.lineTotal);
  num get taxable => (subtotal - discount).clamp(0, double.infinity);
  num get tax => taxable * taxRate / 100;
  num get total => taxable + tax;

  Cart copyWith({
    List<CartLine>? lines,
    num? discount,
    num? taxRate,
    String? customerId,
    String? customerName,
  }) =>
      Cart(
        lines: lines ?? this.lines,
        discount: discount ?? this.discount,
        taxRate: taxRate ?? this.taxRate,
        customerId: customerId ?? this.customerId,
        customerName: customerName ?? this.customerName,
      );
}
