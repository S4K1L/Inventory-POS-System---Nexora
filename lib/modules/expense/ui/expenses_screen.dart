import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/access/access.dart';
import '../../../core/company/company_providers.dart';
import '../../../core/permissions/permissions.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/ui/app_card.dart';
import '../../../core/utils/format.dart';
import '../domain/expense.dart';
import '../expense_providers.dart';
import 'expense_form_sheet.dart';

/// Expenses — monthly/today totals plus a day-grouped list. Add via the sheet.
class ExpensesScreen extends ConsumerWidget {
  const ExpensesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final expensesAsync = ref.watch(recentExpensesProvider);
    final stats = ref.watch(expenseStatsProvider);
    final currency = ref.watch(currentCompanyProvider).currency;
    final canManage = ref.watch(accessProvider).can(Perm.expenseManage);

    return Padding(
      padding: const EdgeInsets.all(AppSpace.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: _MiniStat(
                  label: "Today's Expenses",
                  value: Fmt.money(stats.today, currency: currency),
                  icon: Icons.today_outlined,
                  color: AppColors.warning,
                ),
              ),
              const SizedBox(width: AppSpace.lg),
              Expanded(
                child: _MiniStat(
                  label: 'This Month',
                  value: Fmt.money(stats.month, currency: currency),
                  icon: Icons.calendar_month_outlined,
                  color: AppColors.danger,
                ),
              ),
              if (canManage) ...[
                const SizedBox(width: AppSpace.lg),
                FilledButton.icon(
                  onPressed: () => ExpenseFormSheet.show(context),
                  style: FilledButton.styleFrom(minimumSize: const Size(0, 56)),
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('Add Expense'),
                ),
              ],
            ],
          ),
          const SizedBox(height: AppSpace.xl),
          Expanded(
            child: expensesAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('Failed to load: $e')),
              data: (expenses) {
                if (expenses.isEmpty) {
                  return _EmptyState(
                    canManage: canManage,
                    onAdd: () => ExpenseFormSheet.show(context),
                  );
                }
                return ListView(
                  children: _buildGrouped(context, ref, currency, expenses,
                      canManage: canManage),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildGrouped(BuildContext context, WidgetRef ref,
      String currency, List<Expense> expenses,
      {required bool canManage}) {
    final widgets = <Widget>[];
    String? currentKey;
    for (final e in expenses) {
      final key = DateFormat('yyyy-MM-dd').format(e.date);
      if (key != currentKey) {
        currentKey = key;
        final dayTotal = expenses
            .where((x) => DateFormat('yyyy-MM-dd').format(x.date) == key)
            .fold<num>(0, (t, x) => t + x.amount);
        widgets.add(Padding(
          padding: EdgeInsets.only(
              top: widgets.isEmpty ? 0 : AppSpace.lg, bottom: AppSpace.sm),
          child: Row(
            children: [
              Text(_dayLabel(e.date),
                  style: Theme.of(context).textTheme.titleSmall),
              const Spacer(),
              Text(Fmt.money(dayTotal, currency: currency),
                  style: Theme.of(context)
                      .textTheme
                      .titleSmall
                      ?.copyWith(color: AppColors.danger)),
            ],
          ),
        ));
      }
      widgets.add(Padding(
        padding: const EdgeInsets.only(bottom: AppSpace.md),
        child: _ExpenseRow(
          expense: e,
          currency: currency,
          onDelete: canManage
              ? () => _confirmDelete(context, ref, e)
              : null,
        ),
      ));
    }
    return widgets;
  }

  Future<void> _confirmDelete(
      BuildContext context, WidgetRef ref, Expense e) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete expense?'),
        content: Text('${e.category} · ${Fmt.money(e.amount)} will be removed.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.danger),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (ok == true) {
      await ref.read(expenseActionsProvider).delete(e.id);
    }
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

IconData _iconFor(String category) {
  switch (category) {
    case 'Rent':
      return Icons.home_outlined;
    case 'Salary':
      return Icons.badge_outlined;
    case 'Electricity':
      return Icons.bolt_outlined;
    case 'Internet':
      return Icons.wifi;
    case 'Fuel':
      return Icons.local_gas_station_outlined;
    case 'Transport':
      return Icons.local_shipping_outlined;
    case 'Marketing':
      return Icons.campaign_outlined;
    case 'Supplies':
      return Icons.inventory_2_outlined;
    case 'Maintenance':
      return Icons.build_outlined;
    default:
      return Icons.receipt_long_outlined;
  }
}

class _ExpenseRow extends StatelessWidget {
  const _ExpenseRow({
    required this.expense,
    required this.currency,
    this.onDelete,
  });

  final Expense expense;
  final String currency;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    return AppCard(
      padding: const EdgeInsets.all(AppSpace.md),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: AppColors.warning.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(AppRadius.md),
            ),
            child: Icon(_iconFor(expense.category),
                color: AppColors.warning, size: 20),
          ),
          const SizedBox(width: AppSpace.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(expense.category, style: text.titleSmall),
                const SizedBox(height: 2),
                Text(
                  expense.note.isEmpty
                      ? DateFormat('h:mm a').format(expense.date)
                      : expense.note,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: text.bodySmall,
                ),
              ],
            ),
          ),
          Text(Fmt.money(expense.amount, currency: currency),
              style: text.titleSmall?.copyWith(color: AppColors.danger)),
          if (onDelete != null)
            IconButton(
              icon: Icon(Icons.delete_outline,
                  size: 18, color: scheme.onSurfaceVariant),
              onPressed: onDelete,
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

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.canManage, required this.onAdd});
  final bool canManage;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 84,
            height: 84,
            decoration: BoxDecoration(
              color: AppColors.warning.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(AppRadius.xl),
            ),
            child: const Icon(Icons.account_balance_wallet_outlined,
                size: 40, color: AppColors.warning),
          ),
          const SizedBox(height: AppSpace.lg),
          Text('No expenses yet', style: text.titleLarge),
          const SizedBox(height: 4),
          Text('Record rent, salaries, utilities and more.',
              style: text.bodyMedium),
          if (canManage) ...[
            const SizedBox(height: AppSpace.xl),
            FilledButton.icon(
              onPressed: onAdd,
              icon: const Icon(Icons.add, size: 18),
              label: const Text('Add Expense'),
            ),
          ],
        ],
      ),
    );
  }
}
