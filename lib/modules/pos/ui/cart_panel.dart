import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/company/company_providers.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/utils/format.dart';
import '../../customers/customers_providers.dart';
import '../domain/cart.dart';
import '../pos_providers.dart';
import 'payment_sheet.dart';

/// The current-sale panel: line items with quantity steppers, a discount field,
/// live totals, and the charge button. Reused as a side panel (wide) and inside
/// a bottom sheet (narrow).
class CartPanel extends ConsumerWidget {
  const CartPanel({super.key, this.showHeader = true});
  final bool showHeader;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cart = ref.watch(cartProvider);
    final notifier = ref.read(cartProvider.notifier);
    final currency = ref.watch(currentCompanyProvider).currency;
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    String m(num v) => Fmt.money(v, currency: currency);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (showHeader)
          Padding(
            padding: const EdgeInsets.fromLTRB(
                AppSpace.lg, AppSpace.lg, AppSpace.sm, AppSpace.sm),
            child: Row(
              children: [
                Icon(Icons.shopping_cart_outlined,
                    size: 18, color: scheme.primary),
                const SizedBox(width: 8),
                Text('Current Sale', style: text.titleMedium),
                const Spacer(),
                if (cart.isNotEmpty)
                  TextButton(
                    onPressed: notifier.clear,
                    child: const Text('Clear'),
                  ),
              ],
            ),
          ),
        Padding(
          padding: const EdgeInsets.fromLTRB(
              AppSpace.lg, 0, AppSpace.lg, AppSpace.sm),
          child: _CustomerBar(customerName: cart.customerName),
        ),
        Expanded(
          child: cart.isEmpty
              ? _empty(context)
              : ListView.separated(
                  padding: const EdgeInsets.symmetric(horizontal: AppSpace.lg),
                  itemCount: cart.lines.length,
                  separatorBuilder: (context, i) => const Divider(height: 16),
                  itemBuilder: (_, i) {
                    final line = cart.lines[i];
                    return Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(line.product.name,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: text.titleSmall),
                              Text(m(line.product.sellingPrice),
                                  style: text.bodySmall),
                            ],
                          ),
                        ),
                        _QtyStepper(
                          quantity: line.quantity,
                          onMinus: () => notifier.decrement(line.product.id),
                          onPlus: () => notifier.increment(line.product.id),
                        ),
                        SizedBox(
                          width: 78,
                          child: Text(m(line.lineTotal),
                              textAlign: TextAlign.right,
                              style: text.titleSmall),
                        ),
                      ],
                    );
                  },
                ),
        ),
        if (cart.isNotEmpty)
          _Totals(cart: cart, currency: currency, onDiscount: notifier.setDiscount),
        Padding(
          padding: const EdgeInsets.all(AppSpace.lg),
          child: FilledButton.icon(
            onPressed: cart.isEmpty ? null : () => PaymentSheet.show(context, cart),
            icon: const Icon(Icons.point_of_sale),
            label: Text(cart.isEmpty ? 'Cart is empty' : 'Charge ${m(cart.total)}'),
          ),
        ),
      ],
    );
  }

  Widget _empty(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.add_shopping_cart_outlined,
              size: 40, color: scheme.onSurfaceVariant),
          const SizedBox(height: 10),
          Text('Tap products to add them', style: text.bodySmall),
        ],
      ),
    );
  }
}

/// Compact row to attach/clear a customer on the current sale.
class _CustomerBar extends ConsumerWidget {
  const _CustomerBar({required this.customerName});
  final String customerName;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final notifier = ref.read(cartProvider.notifier);
    final hasCustomer = customerName.isNotEmpty;

    return Material(
      color: hasCustomer
          ? scheme.primary.withValues(alpha: 0.08)
          : scheme.surfaceContainerHighest,
      borderRadius: AppRadius.field,
      child: InkWell(
        onTap: () => _pick(context, ref),
        borderRadius: AppRadius.field,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            borderRadius: AppRadius.field,
            border: Border.all(color: scheme.outline),
          ),
          child: Row(
            children: [
              Icon(hasCustomer ? Icons.person : Icons.person_add_alt,
                  size: 18,
                  color: hasCustomer ? scheme.primary : scheme.onSurfaceVariant),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  hasCustomer ? customerName : 'Add customer (walk-in)',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: hasCustomer ? FontWeight.w600 : FontWeight.w500,
                    color:
                        hasCustomer ? scheme.onSurface : scheme.onSurfaceVariant,
                  ),
                ),
              ),
              if (hasCustomer)
                InkWell(
                  onTap: () => notifier.setCustomer('', ''),
                  child: Icon(Icons.close, size: 16, color: scheme.onSurfaceVariant),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _pick(BuildContext context, WidgetRef ref) async {
    final picked = await showModalBottomSheet<(String, String)>(
      context: context,
      isScrollControlled: true,
      builder: (_) => const _CustomerPickerSheet(),
    );
    if (picked != null) {
      ref.read(cartProvider.notifier).setCustomer(picked.$1, picked.$2);
    }
  }
}

class _CustomerPickerSheet extends ConsumerStatefulWidget {
  const _CustomerPickerSheet();

  @override
  ConsumerState<_CustomerPickerSheet> createState() =>
      _CustomerPickerSheetState();
}

class _CustomerPickerSheetState extends ConsumerState<_CustomerPickerSheet> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final customers = (ref.watch(customersProvider).value ?? const [])
        .where((c) => c.active)
        .where((c) =>
            _query.isEmpty ||
            c.name.toLowerCase().contains(_query) ||
            c.phone.contains(_query))
        .toList();

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.7,
      maxChildSize: 0.92,
      builder: (context, controller) => Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(AppSpace.lg),
            child: TextField(
              autofocus: true,
              onChanged: (v) => setState(() => _query = v.trim().toLowerCase()),
              decoration: const InputDecoration(
                hintText: 'Search customer…',
                prefixIcon: Icon(Icons.search),
              ),
            ),
          ),
          Expanded(
            child: ListView(
              controller: controller,
              children: [
                for (final c in customers)
                  ListTile(
                    leading: const Icon(Icons.person_outline),
                    title: Text(c.name),
                    subtitle: c.phone.isEmpty ? null : Text(c.phone),
                    onTap: () => Navigator.of(context).pop((c.id, c.name)),
                  ),
                if (customers.isEmpty)
                  const Padding(
                    padding: EdgeInsets.all(24),
                    child: Center(child: Text('No customers found.')),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _QtyStepper extends StatelessWidget {
  const _QtyStepper({
    required this.quantity,
    required this.onMinus,
    required this.onPlus,
  });

  final num quantity;
  final VoidCallback onMinus;
  final VoidCallback onPlus;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(AppRadius.pill),
        border: Border.all(color: scheme.outline),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _btn(context, Icons.remove, onMinus),
          SizedBox(
            width: 28,
            child: Text(Fmt.qty(quantity),
                textAlign: TextAlign.center,
                style: const TextStyle(fontWeight: FontWeight.w700)),
          ),
          _btn(context, Icons.add, onPlus),
        ],
      ),
    );
  }

  Widget _btn(BuildContext context, IconData icon, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      customBorder: const CircleBorder(),
      child: Padding(
        padding: const EdgeInsets.all(6),
        child: Icon(icon, size: 16, color: Theme.of(context).colorScheme.primary),
      ),
    );
  }
}

class _Totals extends StatelessWidget {
  const _Totals({
    required this.cart,
    required this.currency,
    required this.onDiscount,
  });

  final Cart cart;
  final String currency;
  final ValueChanged<num> onDiscount;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    String m(num v) => Fmt.money(v, currency: currency);

    return Container(
      padding: const EdgeInsets.all(AppSpace.lg),
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: scheme.outline)),
      ),
      child: Column(
        children: [
          _line(context, 'Subtotal', m(cart.subtotal)),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(child: Text('Discount', style: text.bodyMedium)),
              SizedBox(
                width: 110,
                height: 38,
                child: TextField(
                  textAlign: TextAlign.right,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(
                    isDense: true,
                    prefixText: '- ',
                    contentPadding:
                        EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  ),
                  onChanged: (v) => onDiscount(num.tryParse(v.trim()) ?? 0),
                ),
              ),
            ],
          ),
          if (cart.tax > 0) ...[
            const SizedBox(height: 8),
            _line(context, 'Tax', m(cart.tax)),
          ],
          const Divider(height: 20),
          _line(context, 'Total', m(cart.total), bold: true),
        ],
      ),
    );
  }

  Widget _line(BuildContext context, String label, String value,
      {bool bold = false}) {
    final style = TextStyle(
      fontSize: bold ? 18 : 14,
      fontWeight: bold ? FontWeight.w800 : FontWeight.w500,
    );
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [Text(label, style: style), Text(value, style: style)],
    );
  }
}
