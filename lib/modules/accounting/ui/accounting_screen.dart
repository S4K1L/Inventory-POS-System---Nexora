import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/company/company_providers.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/ui/app_card.dart';
import '../../../core/ui/form_widgets.dart';
import '../../../core/utils/format.dart';
import '../accounting_providers.dart';
import '../domain/ledger_entry.dart';

/// Accounting — a cash book plus live receivables/payables from dues.
class AccountingScreen extends ConsumerWidget {
  const AccountingScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ledgerAsync = ref.watch(ledgerProvider);
    final summary = ref.watch(accountingSummaryProvider);
    final currency = ref.watch(currentCompanyProvider).currency;

    return Padding(
      padding: const EdgeInsets.all(AppSpace.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Text('Accounts', style: Theme.of(context).textTheme.titleMedium),
              const Spacer(),
              FilledButton.icon(
                onPressed: () => _openForm(context),
                style: FilledButton.styleFrom(minimumSize: const Size(0, 48)),
                icon: const Icon(Icons.add, size: 18),
                label: const Text('Add Entry'),
              ),
            ],
          ),
          const SizedBox(height: AppSpace.lg),
          LayoutBuilder(builder: (context, c) {
            final wide = c.maxWidth >= 680;
            final cards = [
              _AccountCard(
                label: 'Cash on hand',
                value: Fmt.money(summary.cash, currency: currency),
                icon: Icons.account_balance_wallet_outlined,
                color: summary.cash >= 0 ? AppColors.success : AppColors.danger,
              ),
              _AccountCard(
                label: 'Receivables (customer dues)',
                value: Fmt.money(summary.receivables, currency: currency),
                icon: Icons.call_received,
                color: AppColors.brand,
              ),
              _AccountCard(
                label: 'Payables (supplier dues)',
                value: Fmt.money(summary.payables, currency: currency),
                icon: Icons.call_made,
                color: AppColors.warning,
              ),
            ];
            return wide
                ? Row(
                    children: [
                      for (var i = 0; i < cards.length; i++) ...[
                        if (i > 0) const SizedBox(width: AppSpace.lg),
                        Expanded(child: cards[i]),
                      ]
                    ],
                  )
                : Column(
                    children: [
                      for (final card in cards) ...[
                        card,
                        const SizedBox(height: AppSpace.md),
                      ]
                    ],
                  );
          }),
          const SizedBox(height: AppSpace.xl),
          Text('Cash book', style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: AppSpace.sm),
          Expanded(
            child: ledgerAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('Failed to load: $e')),
              data: (entries) {
                if (entries.isEmpty) {
                  return const Center(
                      child: Text('No entries yet. Add income or expenses.'));
                }
                return ListView.separated(
                  itemCount: entries.length,
                  separatorBuilder: (context, i) =>
                      const SizedBox(height: AppSpace.md),
                  itemBuilder: (context, i) => _EntryRow(
                    entry: entries[i],
                    currency: currency,
                    onDelete: () =>
                        ref.read(accountingActionsProvider).delete(entries[i].id),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  void _openForm(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => Padding(
        padding:
            EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
        child: const _EntryForm(),
      ),
    );
  }
}

class _AccountCard extends StatelessWidget {
  const _AccountCard(
      {required this.label,
      required this.value,
      required this.icon,
      required this.color});
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(AppRadius.md)),
            child: Icon(icon, color: color, size: 22),
          ),
          const SizedBox(height: AppSpace.md),
          Text(value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: text.headlineSmall),
          const SizedBox(height: 2),
          Text(label, style: text.bodySmall),
        ],
      ),
    );
  }
}

class _EntryRow extends StatelessWidget {
  const _EntryRow(
      {required this.entry, required this.currency, required this.onDelete});
  final LedgerEntry entry;
  final String currency;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    final income = entry.type == LedgerType.income;
    final color = income ? AppColors.success : AppColors.danger;
    return AppCard(
      padding: const EdgeInsets.all(AppSpace.md),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(AppRadius.md)),
            child: Icon(
                income ? Icons.south_west : Icons.north_east,
                color: color,
                size: 20),
          ),
          const SizedBox(width: AppSpace.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(entry.account.isEmpty ? entry.type.label : entry.account,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: text.titleSmall),
                const SizedBox(height: 2),
                Text(
                  entry.note.isEmpty
                      ? DateFormat('d MMM yyyy').format(entry.date)
                      : '${DateFormat('d MMM').format(entry.date)} · ${entry.note}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: text.bodySmall,
                ),
              ],
            ),
          ),
          Text(
            '${income ? '+' : '-'} ${Fmt.money(entry.amount, currency: currency)}',
            style: text.titleSmall?.copyWith(color: color),
          ),
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

class _EntryForm extends ConsumerStatefulWidget {
  const _EntryForm();

  @override
  ConsumerState<_EntryForm> createState() => _EntryFormState();
}

class _EntryFormState extends ConsumerState<_EntryForm> {
  final _account = TextEditingController();
  final _amount = TextEditingController();
  final _note = TextEditingController();
  LedgerType _type = LedgerType.income;
  DateTime _date = DateTime.now();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _account.dispose();
    _amount.dispose();
    _note.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final amount = num.tryParse(_amount.text.trim()) ?? 0;
    if (amount <= 0) {
      setState(() => _error = 'Enter an amount');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref.read(accountingActionsProvider).add(
            type: _type,
            account: _account.text.trim(),
            amount: amount,
            date: _date,
            note: _note.text.trim(),
          );
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      setState(() => _error = 'Could not save: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(
          AppSpace.xl, AppSpace.lg, AppSpace.xl, AppSpace.xl),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('New entry', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: AppSpace.lg),
          SegmentedButton<LedgerType>(
            segments: const [
              ButtonSegment(
                  value: LedgerType.income,
                  label: Text('Income'),
                  icon: Icon(Icons.south_west)),
              ButtonSegment(
                  value: LedgerType.expense,
                  label: Text('Expense'),
                  icon: Icon(Icons.north_east)),
            ],
            selected: {_type},
            onSelectionChanged: (s) => setState(() => _type = s.first),
          ),
          const SizedBox(height: AppSpace.md),
          TextField(
            controller: _account,
            decoration: const InputDecoration(
              labelText: 'Account / category',
              prefixIcon: Icon(Icons.category_outlined),
              hintText: 'e.g. Cash Sales, Owner Drawing, Rent',
            ),
          ),
          const SizedBox(height: AppSpace.md),
          TextField(
            controller: _amount,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(
              labelText: 'Amount',
              prefixIcon: Icon(Icons.payments_outlined, color: scheme.primary),
            ),
          ),
          const SizedBox(height: AppSpace.md),
          InkWell(
            onTap: () async {
              final picked = await showDatePicker(
                context: context,
                initialDate: _date,
                firstDate: DateTime(2020),
                lastDate: DateTime.now().add(const Duration(days: 1)),
              );
              if (picked != null) setState(() => _date = picked);
            },
            borderRadius: AppRadius.field,
            child: InputDecorator(
              decoration: const InputDecoration(
                labelText: 'Date',
                prefixIcon: Icon(Icons.calendar_today_outlined),
              ),
              child: Text(DateFormat('d MMM yyyy').format(_date)),
            ),
          ),
          const SizedBox(height: AppSpace.md),
          TextField(
            controller: _note,
            decoration: const InputDecoration(
              labelText: 'Note (optional)',
              prefixIcon: Icon(Icons.notes),
            ),
          ),
          if (_error != null) ...[
            const SizedBox(height: AppSpace.md),
            FormErrorBox(_error!),
          ],
          const SizedBox(height: AppSpace.lg),
          FilledButton(
            onPressed: _busy ? null : _save,
            child: _busy ? const ButtonSpinner() : const Text('Save entry'),
          ),
        ],
      ),
    );
  }
}
