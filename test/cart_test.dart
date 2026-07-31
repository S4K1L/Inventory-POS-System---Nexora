import 'package:flutter_test/flutter_test.dart';

import 'package:nexora/modules/inventory/domain/product.dart';
import 'package:nexora/modules/pos/domain/cart.dart';

Product _p(String id, num price) =>
    Product(id: id, name: 'P$id', sellingPrice: price);

void main() {
  group('Cart totals', () {
    test('subtotal sums line totals', () {
      const cart = Cart(lines: [
        CartLine(product: Product(id: 'a', name: 'A', sellingPrice: 100), quantity: 2),
        CartLine(product: Product(id: 'b', name: 'B', sellingPrice: 50), quantity: 1),
      ]);
      expect(cart.subtotal, 250);
      expect(cart.count, 3);
    });

    test('discount then tax applied in the right order', () {
      final cart = Cart(
        lines: [CartLine(product: _p('a', 1000), quantity: 1)],
        discount: 100,
        taxRate: 10, // 10% of taxable (900)
      );
      expect(cart.taxable, 900);
      expect(cart.tax, 90);
      expect(cart.total, 990);
    });

    test('discount cannot push total negative via taxable clamp', () {
      final cart = Cart(
        lines: [CartLine(product: _p('a', 100), quantity: 1)],
        discount: 500,
      );
      expect(cart.taxable, 0);
      expect(cart.total, 0);
    });
  });
}
