import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/company/company_providers.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/ui/app_card.dart';
import '../../../core/ui/form_widgets.dart';
import '../../../core/utils/format.dart';
import '../domain/payslip.dart';
import '../payroll_providers.dart';

/// Payroll — generate and list monthly payslips.
class PayrollScreen extends ConsumerWidget {
  const PayrollScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final payslipsAsync = ref.watch(payslipsProvider);
    final currency = ref.watch(currentCompanyProvider).currency;

    return Padding(
      padding: const EdgeInsets.all(AppSpace.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Text('Payslips', style: Theme.of(context).textTheme.titleMedium),
              const Spacer(),
              FilledButton.icon(
                onPressed: () => _openForm(context),
                style: FilledButton.styleFrom(minimumSize: const Size(0, 48)),
                icon: const Icon(Icons.add, size: 18),
                label: const Text('Generate Payslip'),
              ),
            ],
          ),
          const SizedBox(height: AppSpace.lg),
          Expanded(
            child: payslipsAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('Failed to load: $e')),
              data: (payslips) {
                if (payslips.isEmpty) {
                  return _EmptyState(onAdd: () => _openForm(context));
                }
                return ListView(
                  children: _grouped(context, ref, currency, payslips),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _grouped(BuildContext context, WidgetRef ref, String currency,
      List<Payslip> payslips) {
    final widgets = <Widget>[];
    String? currentMonth;
    for (final p in payslips) {
      if (p.month != currentMonth) {
        currentMonth = p.month;
        final monthTotal = payslips
            .where((x) => x.month == p.month)
            .fold<num>(0, (t, x) => t + x.net);
        widgets.add(Padding(
          padding: EdgeInsets.only(
              top: widgets.isEmpty ? 0 : AppSpace.lg, bottom: AppSpace.sm),
          child: Row(
            children: [
              Text(_monthLabel(p.month),
                  style: Theme.of(context).textTheme.titleSmall),
              const Spacer(),
              Text(Fmt.money(monthTotal, currency: currency),
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
        child: _PayslipCard(
          payslip: p,
          currency: currency,
          onDelete: () => ref.read(payrollActionsProvider).delete(p.id),
        ),
      ));
    }
    return widgets;
  }

  String _monthLabel(String month) {
    final d = DateTime.tryParse('$month-01');
    return d == null ? month : DateFormat('MMMM yyyy').format(d);
  }

  void _openForm(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => Padding(
        padding:
            EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
        child: const _PayslipForm(),
      ),
    );
  }
}

class _PayslipCard extends StatelessWidget {
  const _PayslipCard(
      {required this.payslip, required this.currency, required this.onDelete});
  final Payslip payslip;
  final String currency;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    return AppCard(
      padding: const EdgeInsets.all(AppSpace.md),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: scheme.primary.withValues(alpha: 0.12),
            child: Text(
                payslip.employeeName.isNotEmpty
                    ? payslip.employeeName[0].toUpperCase()
                    : '?',
                style: TextStyle(
                    color: scheme.primary, fontWeight: FontWeight.w700)),
          ),
          const SizedBox(width: AppSpace.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(payslip.employeeName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: text.titleSmall),
                const SizedBox(height: 2),
                Text(
                  'Basic ${Fmt.money(payslip.basic, currency: currency)}'
                  '${payslip.bonus > 0 ? ' · Bonus ${Fmt.money(payslip.bonus, currency: currency)}' : ''}'
                  '${payslip.deduction > 0 ? ' · -${Fmt.money(payslip.deduction, currency: currency)}' : ''}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: text.bodySmall,
                ),
              ],
            ),
          ),
          Text(Fmt.money(payslip.net, currency: currency),
              style: text.titleSmall),
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

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.onAdd});
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 84,
            height: 84,
            decoration: BoxDecoration(
                color: scheme.primary.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(AppRadius.xl)),
            child: Icon(Icons.payments_outlined, size: 40, color: scheme.primary),
          ),
          const SizedBox(height: AppSpace.lg),
          Text('No payslips yet', style: text.titleLarge),
          const SizedBox(height: 4),
          Text('Generate monthly payslips for your team.',
              style: text.bodyMedium),
          const SizedBox(height: AppSpace.xl),
          FilledButton.icon(
            onPressed: onAdd,
            icon: const Icon(Icons.add, size: 18),
            label: const Text('Generate Payslip'),
          ),
        ],
      ),
    );
  }
}

class _PayslipForm extends ConsumerStatefulWidget {
  const _PayslipForm();

  @override
  ConsumerState<_PayslipForm> createState() => _PayslipFormState();
}

class _PayslipFormState extends ConsumerState<_PayslipForm> {
  final _basic = TextEditingController();
  final _bonus = TextEditingController();
  final _deduction = TextEditingController();
  String? _uid;
  DateTime _month = DateTime(DateTime.now().year, DateTime.now().month);
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _basic.dispose();
    _bonus.dispose();
    _deduction.dispose();
    super.dispose();
  }

  num _v(TextEditingController c) => num.tryParse(c.text.trim()) ?? 0;
  String get _monthStr =>
      '${_month.year.toString().padLeft(4, '0')}-${_month.month.toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    final team = ref.watch(employeesProvider).value ?? const [];
    final net = _v(_basic) + _v(_bonus) - _v(_deduction);
    final currency = ref.watch(currentCompanyProvider).currency;

    return Padding(
      padding: const EdgeInsets.fromLTRB(
          AppSpace.xl, AppSpace.lg, AppSpace.xl, AppSpace.xl),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Generate payslip',
              style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: AppSpace.lg),
          DropdownButtonFormField<String>(
            initialValue: _uid,
            isExpanded: true,
            decoration: const InputDecoration(
              labelText: 'Employee',
              prefixIcon: Icon(Icons.person_outline),
            ),
            items: [
              for (final m in team)
                DropdownMenuItem(
                    value: m.uid, child: Text(m.displayName ?? m.email)),
            ],
            onChanged: (v) => setState(() => _uid = v),
          ),
          const SizedBox(height: AppSpace.md),
          InkWell(
            onTap: () async {
              final picked = await showDatePicker(
                context: context,
                initialDate: _month,
                firstDate: DateTime(2020),
                lastDate: DateTime.now().add(const Duration(days: 31)),
              );
              if (picked != null) {
                setState(() => _month = DateTime(picked.year, picked.month));
              }
            },
            borderRadius: AppRadius.field,
            child: InputDecorator(
              decoration: const InputDecoration(
                labelText: 'Month',
                prefixIcon: Icon(Icons.calendar_month_outlined),
              ),
              child: Text(DateFormat('MMMM yyyy').format(_month)),
            ),
          ),
          const SizedBox(height: AppSpace.md),
          Row(
            children: [
              Expanded(child: _numField(_basic, 'Basic')),
              const SizedBox(width: AppSpace.md),
              Expanded(child: _numField(_bonus, 'Bonus')),
              const SizedBox(width: AppSpace.md),
              Expanded(child: _numField(_deduction, 'Deduction')),
            ],
          ),
          const SizedBox(height: AppSpace.md),
          Container(
            padding: const EdgeInsets.all(AppSpace.md),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              borderRadius: AppRadius.field,
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Net pay'),
                Text(Fmt.money(net, currency: currency),
                    style: Theme.of(context).textTheme.titleMedium),
              ],
            ),
          ),
          if (_error != null) ...[
            const SizedBox(height: AppSpace.md),
            FormErrorBox(_error!),
          ],
          const SizedBox(height: AppSpace.lg),
          FilledButton(
            onPressed: _busy ? null : () => _save(team),
            child:
                _busy ? const ButtonSpinner() : const Text('Generate payslip'),
          ),
        ],
      ),
    );
  }

  Widget _numField(TextEditingController c, String label) {
    return TextField(
      controller: c,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      onChanged: (_) => setState(() {}),
      decoration: InputDecoration(labelText: label, isDense: true),
    );
  }

  Future<void> _save(List team) async {
    if (_uid == null) {
      setState(() => _error = 'Select an employee');
      return;
    }
    if (_v(_basic) <= 0) {
      setState(() => _error = 'Enter a basic salary');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final m = team.firstWhere((e) => e.uid == _uid);
      await ref.read(payrollActionsProvider).generate(
            uid: _uid!,
            employeeName: m.displayName ?? m.email,
            month: _monthStr,
            basic: _v(_basic),
            bonus: _v(_bonus),
            deduction: _v(_deduction),
          );
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      setState(() => _error = 'Could not save: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }
}
