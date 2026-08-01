import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/company/company_providers.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/ui/app_card.dart';
import '../../../core/ui/pill_chips.dart';
import '../../../core/ui/stat_card.dart';
import '../../../core/utils/format.dart';
import '../../expense/expense_providers.dart';
import '../../inventory/domain/product.dart';
import '../../inventory/inventory_providers.dart';
import '../../pos/domain/sale.dart';
import '../../pos/pos_providers.dart';

enum _Period {
  today('Today'),
  week('7 Days'),
  month('30 Days'),
  thisMonth('This Month');

  const _Period(this.label);
  final String label;

  DateTime get from {
    final now = DateTime.now();
    switch (this) {
      case _Period.today:
        return DateTime(now.year, now.month, now.day);
      case _Period.week:
        return now.subtract(const Duration(days: 7));
      case _Period.month:
        return now.subtract(const Duration(days: 30));
      case _Period.thisMonth:
        return DateTime(now.year, now.month);
    }
  }
}

/// Reports — profit & loss, top products, payment mix and stock valuation,
/// computed from existing sales, purchases and expenses. COGS is estimated from
/// each product's current cost price.
class ReportsScreen extends ConsumerStatefulWidget {
  const ReportsScreen({super.key});

  @override
  ConsumerState<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends ConsumerState<ReportsScreen> {
  _Period _period = _Period.month;

  @override
  Widget build(BuildContext context) {
    final currency = ref.watch(currentCompanyProvider).currency;
    final sales = ref.watch(recentSalesProvider).value ?? const [];
    final expenses = ref.watch(recentExpensesProvider).value ?? const [];
    final products = ref.watch(productsProvider).value ?? const [];

    final from = _period.from;
    final periodSales = sales.where((s) => s.createdAt.isAfter(from)).toList();
    final periodExpenses =
        expenses.where((e) => e.date.isAfter(from)).toList();

    final costById = {for (final p in products) p.id: p.purchasePrice};

    final revenue = periodSales.fold<num>(0, (t, s) => t + s.total);
    num cogs = 0;
    for (final s in periodSales) {
      for (final item in s.items) {
        // Prefer the cost captured on the sale; fall back to current cost for
        // older sales recorded before cost snapshotting.
        final unit =
            item.unitCost > 0 ? item.unitCost : (costById[item.productId] ?? 0);
        cogs += unit * item.quantity;
      }
    }
    final expenseTotal = periodExpenses.fold<num>(0, (t, e) => t + e.amount);
    final grossProfit = revenue - cogs;
    final netProfit = grossProfit - expenseTotal;

    return LayoutBuilder(builder: (context, c) {
      final cols = c.maxWidth >= 1100 ? 4 : (c.maxWidth >= 680 ? 2 : 1);
      final twoCol = c.maxWidth >= 900;
      final pl = _PLCard(
        currency: currency,
        revenue: revenue,
        cogs: cogs,
        gross: grossProfit,
        expenses: expenseTotal,
        net: netProfit,
      );
      final top = _TopProductsCard(sales: periodSales, currency: currency);
      final pay = _PaymentMixCard(sales: periodSales, currency: currency);
      final stock = _StockValuationCard(products: products, currency: currency);

      return ListView(
        padding: const EdgeInsets.all(AppSpace.xl),
        children: [
          PillChips(
            labels: [for (final p in _Period.values) p.label],
            selectedIndex: _Period.values.indexOf(_period),
            onSelected: (i) => setState(() => _period = _Period.values[i]),
          ),
          const SizedBox(height: AppSpace.xl),
          GridView.count(
            crossAxisCount: cols,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: AppSpace.lg,
            crossAxisSpacing: AppSpace.lg,
            childAspectRatio: 1.75,
            children: [
              StatCard(
                label: 'Revenue',
                value: Fmt.money(revenue, currency: currency),
                icon: Icons.trending_up_rounded,
                color: AppColors.brand,
              ),
              StatCard(
                label: 'Net Profit',
                value: Fmt.money(netProfit, currency: currency),
                icon: Icons.savings_outlined,
                color: netProfit >= 0 ? AppColors.success : AppColors.danger,
              ),
              StatCard(
                label: 'Expenses',
                value: Fmt.money(expenseTotal, currency: currency),
                icon: Icons.account_balance_wallet_outlined,
                color: AppColors.warning,
              ),
              StatCard(
                label: 'Orders',
                value: periodSales.length.toString(),
                icon: Icons.receipt_long_outlined,
                color: AppColors.accent,
              ),
            ],
          ),
          const SizedBox(height: AppSpace.xl),
          if (twoCol)
            IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(child: pl),
                  const SizedBox(width: AppSpace.lg),
                  Expanded(child: top),
                ],
              ),
            )
          else ...[
            pl,
            const SizedBox(height: AppSpace.lg),
            top,
          ],
          const SizedBox(height: AppSpace.lg),
          if (twoCol)
            IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(child: pay),
                  const SizedBox(width: AppSpace.lg),
                  Expanded(child: stock),
                ],
              ),
            )
          else ...[
            pay,
            const SizedBox(height: AppSpace.lg),
            stock,
          ],
        ],
      );
    });
  }
}

class _PLCard extends StatelessWidget {
  const _PLCard({
    required this.currency,
    required this.revenue,
    required this.cogs,
    required this.gross,
    required this.expenses,
    required this.net,
  });

  final String currency;
  final num revenue, cogs, gross, expenses, net;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Profit & Loss', style: text.titleMedium),
          const SizedBox(height: 2),
          Text('Cost of goods captured at each sale',
              style: text.bodySmall),
          const SizedBox(height: AppSpace.lg),
          _row(context, 'Revenue', revenue),
          _row(context, 'Cost of goods sold', -cogs),
          const Divider(height: 20),
          _row(context, 'Gross profit', gross, strong: true),
          _row(context, 'Expenses', -expenses),
          const Divider(height: 20),
          _row(context, 'Net profit', net, strong: true, highlight: true),
        ],
      ),
    );
  }

  Widget _row(BuildContext context, String label, num value,
      {bool strong = false, bool highlight = false}) {
    final negative = value < 0;
    final color = highlight
        ? (value >= 0 ? AppColors.success : AppColors.danger)
        : Theme.of(context).colorScheme.onSurface;
    final valueStr =
        '${negative ? '- ' : ''}${Fmt.money(value.abs(), currency: currency)}';
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style: TextStyle(
                  fontSize: strong ? 15 : 14,
                  fontWeight: strong ? FontWeight.w700 : FontWeight.w500)),
          Text(valueStr,
              style: TextStyle(
                  fontSize: strong ? 16 : 14,
                  fontWeight: strong ? FontWeight.w800 : FontWeight.w600,
                  color: color)),
        ],
      ),
    );
  }
}

class _TopProductsCard extends StatelessWidget {
  const _TopProductsCard({required this.sales, required this.currency});
  final List<Sale> sales;
  final String currency;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    // Aggregate revenue + qty per product.
    final revenue = <String, num>{};
    final qty = <String, num>{};
    for (final s in sales) {
      for (final item in s.items) {
        revenue[item.name] = (revenue[item.name] ?? 0) + item.lineTotal;
        qty[item.name] = (qty[item.name] ?? 0) + item.quantity;
      }
    }
    final top = revenue.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final items = top.take(5).toList();
    final max = items.isEmpty ? 1 : items.first.value;

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Top Products', style: text.titleMedium),
          const SizedBox(height: AppSpace.lg),
          if (items.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 20),
              child: Center(
                  child: Text('No sales in this period', style: text.bodySmall)),
            )
          else
            for (final e in items)
              _BarRow(
                label: e.key,
                sub: '${Fmt.qty(qty[e.key] ?? 0)} sold',
                value: e.value,
                max: max,
                currency: currency,
                color: AppColors.brand,
              ),
        ],
      ),
    );
  }
}

class _PaymentMixCard extends StatelessWidget {
  const _PaymentMixCard({required this.sales, required this.currency});
  final List<Sale> sales;
  final String currency;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final byMethod = <PaymentMethod, num>{};
    for (final s in sales) {
      byMethod[s.paymentMethod] = (byMethod[s.paymentMethod] ?? 0) + s.total;
    }
    final entries = byMethod.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final max = entries.isEmpty ? 1 : entries.first.value;

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Payment Methods', style: text.titleMedium),
          const SizedBox(height: AppSpace.lg),
          if (entries.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 20),
              child: Center(
                  child: Text('No sales in this period', style: text.bodySmall)),
            )
          else
            for (final e in entries)
              _BarRow(
                label: e.key.label,
                value: e.value,
                max: max,
                currency: currency,
                color: e.key.color,
              ),
        ],
      ),
    );
  }
}

class _StockValuationCard extends StatelessWidget {
  const _StockValuationCard({required this.products, required this.currency});
  final List<Product> products;
  final String currency;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    num cost = 0, retail = 0;
    for (final p in products) {
      cost += p.purchasePrice * p.stock;
      retail += p.sellingPrice * p.stock;
    }
    final margin = retail - cost;

    Widget row(String label, num value, {Color? color}) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 5),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(label, style: text.bodyMedium),
              Text(Fmt.money(value, currency: currency),
                  style: TextStyle(fontWeight: FontWeight.w700, color: color)),
            ],
          ),
        );

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Stock Valuation', style: text.titleMedium),
          const SizedBox(height: 2),
          Text('Current on-hand inventory', style: text.bodySmall),
          const SizedBox(height: AppSpace.lg),
          row('Cost value', cost),
          row('Retail value', retail),
          const Divider(height: 20),
          row('Potential margin', margin, color: AppColors.success),
        ],
      ),
    );
  }
}

class _BarRow extends StatelessWidget {
  const _BarRow({
    required this.label,
    required this.value,
    required this.max,
    required this.currency,
    required this.color,
    this.sub,
  });

  final String label;
  final String? sub;
  final num value;
  final num max;
  final String currency;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final frac = max <= 0 ? 0.0 : (value / max).clamp(0.0, 1.0).toDouble();
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w600)),
              ),
              Text(Fmt.money(value, currency: currency),
                  style: const TextStyle(fontWeight: FontWeight.w700)),
            ],
          ),
          if (sub != null)
            Text(sub!, style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: frac,
              minHeight: 8,
              backgroundColor: scheme.surfaceContainerHighest,
              valueColor: AlwaysStoppedAnimation(color),
            ),
          ),
        ],
      ),
    );
  }
}
