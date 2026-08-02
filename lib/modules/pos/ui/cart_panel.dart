import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/company/company_providers.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/utils/format.dart';
import '../../customers/customers_providers.dart';
import '../domain/cart.dart';
import '../pos_providers.dart';
import 'payment_sheet.dart';

const _kotDark = Color(0xFF14171F);
const _billPrintGreen = Color(0xFF16A34A);

/// The current-sale panel: order header, dining/table selectors, line items
/// with quantity steppers and notes, live totals, and the checkout actions.
/// Reused as a side panel (wide) and inside a bottom sheet (narrow).
class CartPanel extends ConsumerStatefulWidget {
  const CartPanel({super.key, this.showHeader = true});
  final bool showHeader;

  @override
  ConsumerState<CartPanel> createState() => _CartPanelState();
}

class _CartPanelState extends ConsumerState<CartPanel> {
  String _lineQuery = '';

  @override
  Widget build(BuildContext context) {
    final cart = ref.watch(cartProvider);
    final notifier = ref.read(cartProvider.notifier);
    final currency = ref.watch(currentCompanyProvider).currency;
    final todayCount = ref.watch(todaySalesProvider).value?.length ?? 0;
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    String m(num v) => Fmt.money(v, currency: currency);

    final lines = cart.lines
        .where((l) => _lineQuery.isEmpty ||
            l.product.name.toLowerCase().contains(_lineQuery))
        .toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (widget.showHeader)
          Padding(
            padding: const EdgeInsets.fromLTRB(
                AppSpace.lg, AppSpace.lg, AppSpace.lg, AppSpace.sm),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: scheme.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(AppRadius.sm),
                  ),
                  child: Icon(Icons.shopping_bag_outlined,
                      size: 16, color: scheme.primary),
                ),
                const SizedBox(width: 10),
                Text('Order #${todayCount + 1}', style: text.titleMedium),
                if (cart.isNotEmpty) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: scheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(AppRadius.pill),
                    ),
                    child: Text('${cart.count} items',
                        style: TextStyle(fontSize: 11.5, color: scheme.onSurfaceVariant)),
                  ),
                ],
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
          padding: const EdgeInsets.fromLTRB(AppSpace.lg, 0, AppSpace.lg, AppSpace.sm),
          child: _CustomerBar(customerName: cart.customerName),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(AppSpace.lg, 0, AppSpace.lg, AppSpace.sm),
          child: TextField(
            onChanged: (v) => setState(() => _lineQuery = v.trim().toLowerCase()),
            decoration: const InputDecoration(
              isDense: true,
              hintText: 'Search in Existing',
              prefixIcon: Icon(Icons.search, size: 20),
              contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(AppSpace.lg, 0, AppSpace.lg, AppSpace.sm),
          child: Row(
            children: [
              Expanded(
                child: _MiniDropdown(
                  label: 'Select Dining',
                  value: cart.diningOption,
                  options: kDiningOptions,
                  onChanged: (v) => notifier.setDiningOption(v ?? kDiningOptions.first),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _MiniDropdown(
                  label: 'Select Table',
                  value: cart.tableLabel.isEmpty ? null : cart.tableLabel,
                  options: kTables,
                  onChanged: (v) => notifier.setTable(v ?? ''),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: cart.isEmpty
              ? _empty(context)
              : lines.isEmpty
                  ? Center(
                      child: Text('No items match “$_lineQuery”.',
                          style: TextStyle(color: scheme.onSurfaceVariant)))
                  : ListView.separated(
                      padding: const EdgeInsets.symmetric(horizontal: AppSpace.lg),
                      itemCount: lines.length,
                      separatorBuilder: (context, i) => const Divider(height: 16),
                      itemBuilder: (_, i) {
                        final line = lines[i];
                        return _CartLineTile(
                          line: line,
                          money: m,
                          onDelete: () => notifier.removeLine(line.product.id),
                          onMinus: () => notifier.decrement(line.product.id),
                          onPlus: () => notifier.increment(line.product.id),
                          onNotes: () => _editNotes(context, notifier, line),
                        );
                      },
                    ),
        ),
        if (cart.isNotEmpty)
          _Totals(
            cart: cart,
            currency: currency,
            onDiscount: notifier.setDiscount,
            onCoupon: notifier.setCouponDiscount,
          ),
        _ActionButtons(cart: cart),
      ],
    );
  }

  Future<void> _editNotes(
      BuildContext context, CartNotifier notifier, CartLine line) async {
    final controller = TextEditingController(text: line.notes);
    final result = await showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('Notes · ${line.product.name}'),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLines: 3,
          decoration: const InputDecoration(hintText: 'e.g. No onions, extra spicy…'),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel')),
          FilledButton(
              onPressed: () => Navigator.of(context).pop(controller.text.trim()),
              child: const Text('Save')),
        ],
      ),
    );
    if (result != null) notifier.setLineNotes(line.product.id, result);
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

class _CartLineTile extends StatelessWidget {
  const _CartLineTile({
    required this.line,
    required this.money,
    required this.onDelete,
    required this.onMinus,
    required this.onPlus,
    required this.onNotes,
  });

  final CartLine line;
  final String Function(num) money;
  final VoidCallback onDelete;
  final VoidCallback onMinus;
  final VoidCallback onPlus;
  final VoidCallback onNotes;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        InkWell(
          borderRadius: BorderRadius.circular(AppRadius.sm),
          onTap: onDelete,
          child: Padding(
            padding: const EdgeInsets.all(4),
            child: Icon(Icons.delete_outline, size: 18, color: scheme.error),
          ),
        ),
        const SizedBox(width: 4),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(line.product.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: text.titleSmall),
              Text('${money(line.product.sellingPrice)} × ${Fmt.qty(line.quantity)}',
                  style: text.bodySmall),
              const SizedBox(height: 4),
              InkWell(
                onTap: onNotes,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.edit_note,
                        size: 14,
                        color: line.notes.isEmpty
                            ? scheme.onSurfaceVariant
                            : scheme.primary),
                    const SizedBox(width: 3),
                    Flexible(
                      child: Text(
                        line.notes.isEmpty ? 'Add Notes' : line.notes,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 11.5,
                          color: line.notes.isEmpty
                              ? scheme.onSurfaceVariant
                              : scheme.primary,
                          fontWeight:
                              line.notes.isEmpty ? FontWeight.w500 : FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.only(top: 2),
          child: _QtyStepper(
            quantity: line.quantity,
            onMinus: onMinus,
            onPlus: onPlus,
          ),
        ),
        SizedBox(
          width: 74,
          child: Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(money(line.lineTotal),
                textAlign: TextAlign.right,
                style: text.titleSmall),
          ),
        ),
      ],
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

/// A small outlined dropdown used for the dining/table selectors.
class _MiniDropdown extends StatelessWidget {
  const _MiniDropdown({
    required this.label,
    required this.value,
    required this.options,
    required this.onChanged,
  });

  final String label;
  final String? value;
  final List<String> options;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return PopupMenuButton<String?>(
      tooltip: label,
      onSelected: onChanged,
      itemBuilder: (_) => [
        for (final o in options) PopupMenuItem<String?>(value: o, child: Text(o)),
      ],
      child: Container(
        height: 40,
        padding: const EdgeInsets.symmetric(horizontal: 10),
        decoration: BoxDecoration(
          color: scheme.surfaceContainerHighest,
          borderRadius: AppRadius.field,
          border: Border.all(color: scheme.outline),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                value ?? label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                  color: value == null ? scheme.onSurfaceVariant : scheme.onSurface,
                ),
              ),
            ),
            Icon(Icons.keyboard_arrow_down_rounded, size: 16, color: scheme.onSurfaceVariant),
          ],
        ),
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
    required this.onCoupon,
  });

  final Cart cart;
  final String currency;
  final ValueChanged<num> onDiscount;
  final ValueChanged<num> onCoupon;

  @override
  Widget build(BuildContext context) {
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
          _editableLine(context, 'Extra Discount', cart.discount, m,
              onSave: onDiscount),
          const SizedBox(height: 8),
          _editableLine(context, 'Coupon discount', cart.couponDiscount, m,
              onSave: onCoupon),
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

  Widget _editableLine(
    BuildContext context,
    String label,
    num value,
    String Function(num) m, {
    required ValueChanged<num> onSave,
  }) {
    final scheme = Theme.of(context).colorScheme;
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
        InkWell(
          borderRadius: BorderRadius.circular(AppRadius.sm),
          onTap: () => _editAmount(context, label, value, onSave),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 2, horizontal: 4),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(value > 0 ? '- ${m(value)}' : m(0),
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
                const SizedBox(width: 4),
                Icon(Icons.edit, size: 13, color: scheme.onSurfaceVariant),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _editAmount(BuildContext context, String label, num current,
      ValueChanged<num> onSave) async {
    final controller = TextEditingController(
        text: current == 0 ? '' : Fmt.qty(current));
    final result = await showDialog<num>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(label),
        content: TextField(
          controller: controller,
          autofocus: true,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: const InputDecoration(prefixText: '- '),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel')),
          FilledButton(
              onPressed: () =>
                  Navigator.of(context).pop(num.tryParse(controller.text.trim()) ?? 0),
              child: const Text('Apply')),
        ],
      ),
    );
    if (result != null) onSave(result);
  }
}

/// Checkout footer: send-to-kitchen, park as draft, and the two bill actions.
class _ActionButtons extends ConsumerWidget {
  const _ActionButtons({required this.cart});

  final Cart cart;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final empty = cart.isEmpty;
    return Padding(
      padding: const EdgeInsets.fromLTRB(AppSpace.lg, AppSpace.sm, AppSpace.lg, AppSpace.lg),
      child: Column(
        children: [
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: _kotDark,
                disabledBackgroundColor: _kotDark.withValues(alpha: 0.4),
              ),
              onPressed: empty ? null : () => _showKotPreview(context, cart),
              icon: const Icon(Icons.receipt_outlined, size: 18),
              label: const Text('KOT & Print'),
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: empty ? null : () => _saveDraft(context, ref),
                  icon: const Icon(Icons.bookmark_outline, size: 18),
                  label: const Text('Draft'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                flex: 2,
                child: FilledButton.icon(
                  onPressed: empty ? null : () => PaymentSheet.show(context, cart),
                  icon: const Icon(Icons.payments_outlined, size: 18),
                  label: const Text('Bill & Payment'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: _billPrintGreen,
                disabledBackgroundColor: _billPrintGreen.withValues(alpha: 0.4),
              ),
              onPressed: empty ? null : () => PaymentSheet.show(context, cart),
              icon: const Icon(Icons.print_outlined, size: 18),
              label: const Text('Bill & Print'),
            ),
          ),
        ],
      ),
    );
  }

  void _saveDraft(BuildContext context, WidgetRef ref) {
    ref.read(draftOrdersProvider.notifier).save(cart);
    ref.read(cartProvider.notifier).clear();
    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text('Order parked as draft')));
  }

  Future<void> _showKotPreview(BuildContext context, Cart cart) async {
    await showDialog<void>(
      context: context,
      builder: (_) => AlertDialog(
        title: Row(
          children: const [
            Icon(Icons.soup_kitchen_outlined, size: 20),
            SizedBox(width: 8),
            Text('Kitchen Order Ticket'),
          ],
        ),
        content: SizedBox(
          width: 320,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (cart.tableLabel.isNotEmpty || cart.diningOption.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text(
                    cart.tableLabel.isEmpty
                        ? cart.diningOption
                        : '${cart.diningOption} · ${cart.tableLabel}',
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
              const Divider(),
              for (final l in cart.lines)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('${Fmt.qty(l.quantity)}×',
                          style: const TextStyle(fontWeight: FontWeight.w700)),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(l.product.name),
                            if (l.notes.isNotEmpty)
                              Text(l.notes,
                                  style: const TextStyle(
                                      fontSize: 12, fontStyle: FontStyle.italic)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Close')),
          FilledButton(
            onPressed: () {
              Navigator.of(context).pop();
              ScaffoldMessenger.of(context)
                  .showSnackBar(const SnackBar(content: Text('Sent to kitchen printer')));
            },
            child: const Text('Send to Kitchen'),
          ),
        ],
      ),
    );
  }
}
