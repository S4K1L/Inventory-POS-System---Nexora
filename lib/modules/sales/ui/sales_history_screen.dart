import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/company/company_providers.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/ui/app_card.dart';
import '../../../core/ui/status_pill.dart';
import '../../../core/utils/format.dart';
import '../../pos/domain/sale.dart';
import '../../pos/pos_providers.dart';
import '../../pos/ui/receipt_dialog.dart';

/// Sales History — past receipts grouped by day, with a per-day total. Tap any
/// row to reopen its receipt.
class SalesHistoryScreen extends ConsumerWidget {
  const SalesHistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final salesAsync = ref.watch(recentSalesProvider);
    final today = ref.watch(todayStatsProvider);
    final currency = ref.watch(currentCompanyProvider).currency;

    return salesAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Failed to load sales: $e')),
      data: (sales) {
        return ListView(
          padding: const EdgeInsets.all(AppSpace.xl),
          children: [
            Row(
              children: [
                Expanded(
                  child: _MiniStat(
                    label: "Today's Revenue",
                    value: Fmt.money(today.revenue, currency: currency),
                    icon: Icons.trending_up_rounded,
                    color: AppColors.brand,
                  ),
                ),
                const SizedBox(width: AppSpace.lg),
                Expanded(
                  child: _MiniStat(
                    label: 'Orders Today',
                    value: today.count.toString(),
                    icon: Icons.receipt_long_outlined,
                    color: AppColors.accent,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpace.xl),
            if (sales.isEmpty)
              const _Empty()
            else
              ..._buildGrouped(context, currency, sales),
          ],
        );
      },
    );
  }

  List<Widget> _buildGrouped(
      BuildContext context, String currency, List<Sale> sales) {
    final widgets = <Widget>[];
    String? currentKey;

    for (var i = 0; i < sales.length; i++) {
      final sale = sales[i];
      final key = DateFormat('yyyy-MM-dd').format(sale.createdAt);
      if (key != currentKey) {
        currentKey = key;
        // Sum this day's sales.
        final dayTotal = sales
            .where((s) =>
                DateFormat('yyyy-MM-dd').format(s.createdAt) == key)
            .fold<num>(0, (t, s) => t + s.total);
        widgets.add(Padding(
          padding: EdgeInsets.only(
              top: widgets.isEmpty ? 0 : AppSpace.lg, bottom: AppSpace.sm),
          child: Row(
            children: [
              Text(_dayLabel(sale.createdAt),
                  style: Theme.of(context).textTheme.titleSmall),
              const Spacer(),
              Text(Fmt.money(dayTotal, currency: currency),
                  style: Theme.of(context)
                      .textTheme
                      .titleSmall
                      ?.copyWith(color: AppColors.success)),
            ],
          ),
        ));
      }
      widgets.add(Padding(
        padding: const EdgeInsets.only(bottom: AppSpace.md),
        child: _SaleRow(sale: sale, currency: currency),
      ));
    }
    return widgets;
  }

  String _dayLabel(DateTime dt) {
    final now = DateTime.now();
    final d = DateTime(dt.year, dt.month, dt.day);
    final today = DateTime(now.year, now.month, now.day);
    final diff = today.difference(d).inDays;
    if (diff == 0) return 'Today';
    if (diff == 1) return 'Yesterday';
    return DateFormat('EEEE, d MMM').format(dt);
  }
}

class _SaleRow extends StatelessWidget {
  const _SaleRow({required this.sale, required this.currency});
  final Sale sale;
  final String currency;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return AppCard(
      padding: const EdgeInsets.all(AppSpace.md),
      onTap: () => showReceiptDialog(context, sale,
          currency: currency, primaryLabel: 'Close'),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: sale.paymentMethod.color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(AppRadius.md),
            ),
            child: Icon(sale.paymentMethod.icon,
                color: sale.paymentMethod.color, size: 20),
          ),
          const SizedBox(width: AppSpace.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(sale.invoiceNo, style: text.titleSmall),
                const SizedBox(height: 2),
                Text(
                  '${DateFormat('h:mm a').format(sale.createdAt)}  ·  '
                  '${sale.itemCount} item${sale.itemCount == 1 ? '' : 's'}',
                  style: text.bodySmall,
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(Fmt.money(sale.total, currency: currency),
                  style: text.titleSmall),
              const SizedBox(height: 4),
              StatusPill(
                  label: sale.paymentMethod.label,
                  color: sale.paymentMethod.color),
            ],
          ),
        ],
      ),
    );
  }
}

class _MiniStat extends StatelessWidget {
  const _MiniStat({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return AppCard(
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(AppRadius.md),
            ),
            child: Icon(icon, color: color, size: 22),
          ),
          const SizedBox(width: AppSpace.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(value,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: text.titleLarge),
                Text(label, style: text.bodySmall),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Empty extends StatelessWidget {
  const _Empty();

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(top: 80),
      child: Center(
        child: Column(
          children: [
            Container(
              width: 84,
              height: 84,
              decoration: BoxDecoration(
                color: scheme.primary.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(AppRadius.xl),
              ),
              child: Icon(Icons.receipt_long_outlined,
                  size: 40, color: scheme.primary),
            ),
            const SizedBox(height: AppSpace.lg),
            Text('No sales yet', style: text.titleLarge),
            const SizedBox(height: 4),
            Text('Completed sales from the POS will appear here.',
                style: text.bodyMedium),
          ],
        ),
      ),
    );
  }
}
