import '../../inventory/domain/product.dart';
import 'sale.dart';

/// A single cart line: a product plus the quantity being sold.
class CartLine {
  const CartLine({required this.product, required this.quantity, this.notes = ''});

  final Product product;
  final num quantity;
  final String notes;

  num get lineTotal => product.sellingPrice * quantity;

  CartLine copyWith({num? quantity, String? notes}) => CartLine(
        product: product,
        quantity: quantity ?? this.quantity,
        notes: notes ?? this.notes,
      );

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
    this.couponDiscount = 0,
    this.taxRate = 0,
    this.customerId = '',
    this.customerName = '',
    this.diningOption = 'Dine In',
    this.tableLabel = '',
  });

  final List<CartLine> lines;

  /// Manual "extra" discount applied by the cashier.
  final num discount;

  /// Discount from an applied coupon code.
  final num couponDiscount;

  /// Sale-level tax percentage (0–100).
  final num taxRate;

  /// Optional customer this sale is attached to.
  final String customerId;
  final String customerName;

  /// Dine In / Takeaway / Delivery.
  final String diningOption;

  /// Table this order is seated at (dine-in only).
  final String tableLabel;

  bool get isEmpty => lines.isEmpty;
  bool get isNotEmpty => lines.isNotEmpty;
  int get count => lines.fold(0, (n, l) => n + l.quantity.toInt());

  num get subtotal => lines.fold<num>(0, (s, l) => s + l.lineTotal);
  num get totalDiscount => discount + couponDiscount;
  num get taxable => (subtotal - totalDiscount).clamp(0, double.infinity);
  num get tax => taxable * taxRate / 100;
  num get total => taxable + tax;

  Cart copyWith({
    List<CartLine>? lines,
    num? discount,
    num? couponDiscount,
    num? taxRate,
    String? customerId,
    String? customerName,
    String? diningOption,
    String? tableLabel,
  }) =>
      Cart(
        lines: lines ?? this.lines,
        discount: discount ?? this.discount,
        couponDiscount: couponDiscount ?? this.couponDiscount,
        taxRate: taxRate ?? this.taxRate,
        customerId: customerId ?? this.customerId,
        customerName: customerName ?? this.customerName,
        diningOption: diningOption ?? this.diningOption,
        tableLabel: tableLabel ?? this.tableLabel,
      );
}
