import 'package:flutter/material.dart';

import '../../../core/theme/app_tokens.dart';
import '../../../core/utils/format.dart';
import '../domain/sale.dart';

/// Shows a clean receipt after checkout.
Future<void> showReceiptDialog(
  BuildContext context,
  Sale sale, {
  required String currency,
  String primaryLabel = 'New Sale',
}) {
  return showDialog(
    context: context,
    builder: (_) => Dialog(
      insetPadding: const EdgeInsets.all(AppSpace.lg),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 380),
        child: _Receipt(
            sale: sale, currency: currency, primaryLabel: primaryLabel),
      ),
    ),
  );
}

class _Receipt extends StatelessWidget {
  const _Receipt({
    required this.sale,
    required this.currency,
    required this.primaryLabel,
  });
  final Sale sale;
  final String currency;
  final String primaryLabel;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    String m(num v) => Fmt.money(v, currency: currency);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpace.xl),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                color: AppColors.success.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.check_rounded,
                  color: AppColors.success, size: 34),
            ),
          ),
          const SizedBox(height: 12),
          Center(child: Text('Payment complete', style: text.titleLarge)),
          const SizedBox(height: 2),
          Center(child: Text(sale.invoiceNo, style: text.bodySmall)),
          if (sale.customerName.isNotEmpty)
            Center(
                child: Text('Customer: ${sale.customerName}',
                    style: text.bodySmall)),
          const SizedBox(height: AppSpace.lg),
          const Divider(),
          const SizedBox(height: 8),
          for (final item in sale.items)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                children: [
                  Text('${Fmt.qty(item.quantity)}×',
                      style: TextStyle(color: scheme.onSurfaceVariant)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(item.name,
                        maxLines: 1, overflow: TextOverflow.ellipsis),
                  ),
                  Text(m(item.lineTotal)),
                ],
              ),
            ),
          const SizedBox(height: 8),
          const Divider(),
          _row(context, 'Subtotal', m(sale.subtotal)),
          if (sale.discount > 0) _row(context, 'Discount', '- ${m(sale.discount)}'),
          if (sale.tax > 0) _row(context, 'Tax', m(sale.tax)),
          const SizedBox(height: 4),
          _row(context, 'Total', m(sale.total), bold: true),
          const SizedBox(height: 8),
          _row(context, 'Paid (${sale.paymentMethod.label})', m(sale.paid)),
          if (sale.change > 0) _row(context, 'Change', m(sale.change)),
          const SizedBox(height: AppSpace.xl),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.print_outlined, size: 18),
                  label: const Text('Print'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: Text(primaryLabel),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _row(BuildContext context, String label, String value,
      {bool bold = false}) {
    final style = TextStyle(
      fontSize: bold ? 17 : 14,
      fontWeight: bold ? FontWeight.w800 : FontWeight.w500,
      color: Theme.of(context).colorScheme.onSurface,
    );
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [Text(label, style: style), Text(value, style: style)],
      ),
    );
  }
}
