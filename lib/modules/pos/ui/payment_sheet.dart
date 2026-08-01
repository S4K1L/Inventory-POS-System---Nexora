import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/company/company_providers.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/ui/form_widgets.dart';
import '../../../core/utils/format.dart';
import '../domain/cart.dart';
import '../domain/sale.dart';
import '../pos_providers.dart';
import 'receipt_dialog.dart';

/// Payment step: pick a tender, enter the amount received, see change, and
/// complete the sale. On success it clears the cart and shows the receipt.
class PaymentSheet extends ConsumerStatefulWidget {
  const PaymentSheet({super.key, required this.cart});
  final Cart cart;

  static Future<void> show(BuildContext context, Cart cart) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => Padding(
        padding:
            EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
        child: PaymentSheet(cart: cart),
      ),
    );
  }

  @override
  ConsumerState<PaymentSheet> createState() => _PaymentSheetState();
}

class _PaymentSheetState extends ConsumerState<PaymentSheet> {
  late final TextEditingController _paid =
      TextEditingController(text: _fmtInput(widget.cart.total));
  PaymentMethod _method = PaymentMethod.cash;
  bool _busy = false;
  String? _error;

  static String _fmtInput(num v) =>
      v == v.roundToDouble() ? v.toInt().toString() : v.toStringAsFixed(2);

  @override
  void dispose() {
    _paid.dispose();
    super.dispose();
  }

  num get _paidAmount => num.tryParse(_paid.text.trim()) ?? 0;
  num get _change => (_paidAmount - widget.cart.total).clamp(0, double.infinity);
  num get _due => (widget.cart.total - _paidAmount).clamp(0, double.infinity);
  bool get _hasCustomer => widget.cart.customerId.isNotEmpty;

  Future<void> _confirm() async {
    if (_paidAmount < widget.cart.total && !_hasCustomer) {
      setState(() => _error =
          'Attach a customer to leave a balance due, or collect the full amount');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final sale = await ref.read(checkoutServiceProvider).checkout(
            cart: widget.cart,
            paid: _paidAmount,
            method: _method,
            customerId: widget.cart.customerId,
            customerName: widget.cart.customerName,
          );
      ref.read(cartProvider.notifier).clear();
      if (!mounted) return;
      final currency = ref.read(currentCompanyProvider).currency;
      Navigator.of(context).pop(); // close sheet
      await showReceiptDialog(context, sale, currency: currency);
    } catch (e) {
      if (mounted) {
        setState(() =>
            _error = e.toString().replaceFirst('Bad state: ', ''));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final currency = ref.watch(currentCompanyProvider).currency;
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.fromLTRB(
          AppSpace.xl, AppSpace.lg, AppSpace.xl, AppSpace.xl),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: scheme.outline,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: AppSpace.lg),
          Row(
            children: [
              Text('Payment', style: text.titleLarge),
              const Spacer(),
              Text(Fmt.money(widget.cart.total, currency: currency),
                  style: text.headlineSmall),
            ],
          ),
          const SizedBox(height: AppSpace.lg),
          Text('Payment method', style: text.bodySmall),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final m in PaymentMethod.values)
                ChoiceChip(
                  avatar: Icon(m.icon,
                      size: 16,
                      color: _method == m ? m.color : scheme.onSurfaceVariant),
                  label: Text(m.label),
                  selected: _method == m,
                  onSelected: (_) => setState(() => _method = m),
                ),
            ],
          ),
          const SizedBox(height: AppSpace.lg),
          TextField(
            controller: _paid,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            onChanged: (_) => setState(() {}),
            decoration: const InputDecoration(
              labelText: 'Amount received',
              prefixIcon: Icon(Icons.payments_outlined),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              for (final q in {
                widget.cart.total,
                _round(widget.cart.total, 50),
                _round(widget.cart.total, 100),
              })
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ActionChip(
                    label: Text(_fmtInput(q)),
                    onPressed: () => setState(() => _paid.text = _fmtInput(q)),
                  ),
                ),
            ],
          ),
          const SizedBox(height: AppSpace.md),
          Container(
            padding: const EdgeInsets.all(AppSpace.md),
            decoration: BoxDecoration(
              color: scheme.surfaceContainerHighest,
              borderRadius: AppRadius.field,
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(_due > 0 ? 'Balance due' : 'Change',
                    style: text.bodyMedium),
                Text(
                  Fmt.money(_due > 0 ? _due : _change, currency: currency),
                  style: text.titleMedium?.copyWith(
                      color: _due > 0 ? AppColors.warning : null),
                ),
              ],
            ),
          ),
          if (_error != null) ...[
            const SizedBox(height: AppSpace.md),
            FormErrorBox(_error!),
          ],
          const SizedBox(height: AppSpace.lg),
          FilledButton(
            onPressed: _busy ? null : _confirm,
            child: _busy
                ? const ButtonSpinner()
                : Text('Charge ${Fmt.money(widget.cart.total, currency: currency)}'),
          ),
        ],
      ),
    );
  }

  /// Rounds up to the next multiple of [step] for quick-cash chips.
  num _round(num value, num step) => (value / step).ceil() * step;
}
