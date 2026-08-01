import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/company/company_providers.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/ui/app_card.dart';
import '../../../core/ui/form_widgets.dart';
import '../../../core/ui/status_pill.dart';
import '../../../core/utils/format.dart';
import '../branch_overview_providers.dart';
import '../branches_providers.dart';
import '../domain/branch.dart';

/// Owner view: manage branches AND monitor them live — today's sales, orders
/// and stock value per branch, plus a combined roll-up across all branches.
class BranchesScreen extends ConsumerWidget {
  const BranchesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final branchesAsync = ref.watch(branchesProvider);
    final current = ref.watch(currentBranchIdProvider);
    final currency = ref.watch(currentCompanyProvider).currency;

    return Padding(
      padding: const EdgeInsets.all(AppSpace.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Text('Branches', style: Theme.of(context).textTheme.titleMedium),
              const Spacer(),
              FilledButton.icon(
                onPressed: () => _openForm(context),
                style: FilledButton.styleFrom(minimumSize: const Size(0, 48)),
                icon: const Icon(Icons.add, size: 18),
                label: const Text('Add Branch'),
              ),
            ],
          ),
          const SizedBox(height: AppSpace.lg),
          Expanded(
            child: branchesAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('Failed to load: $e')),
              data: (branches) {
                if (branches.isEmpty) {
                  return const Center(child: Text('No branches yet.'));
                }
                final active = branches.where((b) => b.active).toList();

                // Combined roll-up across all active branches.
                num revenue = 0, stockValue = 0;
                int orders = 0;
                for (final b in active) {
                  final o = ref.watch(branchOverviewProvider(b.id));
                  revenue += o.revenue;
                  orders += o.orders;
                  stockValue += o.stockValue;
                }

                return ListView(
                  children: [
                    _CombinedCard(
                      currency: currency,
                      branchCount: active.length,
                      revenue: revenue,
                      orders: orders,
                      stockValue: stockValue,
                    ),
                    const SizedBox(height: AppSpace.lg),
                    Text('All branches',
                        style: Theme.of(context).textTheme.titleSmall),
                    const SizedBox(height: AppSpace.sm),
                    for (final b in branches)
                      Padding(
                        padding: const EdgeInsets.only(bottom: AppSpace.md),
                        child: _BranchCard(
                          branch: b,
                          currency: currency,
                          isCurrent: b.id == current,
                          onEdit: () => _openForm(context, existing: b),
                        ),
                      ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  void _openForm(BuildContext context, {Branch? existing}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => Padding(
        padding:
            EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
        child: _BranchForm(existing: existing),
      ),
    );
  }
}

class _CombinedCard extends StatelessWidget {
  const _CombinedCard({
    required this.currency,
    required this.branchCount,
    required this.revenue,
    required this.orders,
    required this.stockValue,
  });

  final String currency;
  final int branchCount;
  final num revenue;
  final int orders;
  final num stockValue;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpace.xl),
      decoration: BoxDecoration(
        gradient: AppColors.brandGradient,
        borderRadius: AppRadius.card,
        boxShadow: [
          BoxShadow(
            color: AppColors.brand.withValues(alpha: 0.25),
            blurRadius: 22,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.insights, color: Colors.white, size: 20),
              const SizedBox(width: 8),
              Text('All branches · today',
                  style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.9),
                      fontWeight: FontWeight.w600)),
              const Spacer(),
              Text('$branchCount branch${branchCount == 1 ? '' : 'es'}',
                  style: TextStyle(color: Colors.white.withValues(alpha: 0.8))),
            ],
          ),
          const SizedBox(height: AppSpace.lg),
          LayoutBuilder(builder: (context, c) {
            final wide = c.maxWidth >= 520;
            final cells = [
              _cell('Total Sales', Fmt.money(revenue, currency: currency)),
              _cell('Orders', orders.toString()),
              _cell('Stock Value', Fmt.money(stockValue, currency: currency)),
            ];
            return wide
                ? Row(
                    children: [
                      for (final cell in cells) Expanded(child: cell),
                    ],
                  )
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      for (final cell in cells)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: cell,
                        ),
                    ],
                  );
          }),
        ],
      ),
    );
  }

  Widget _cell(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(value,
            style: const TextStyle(
                color: Colors.white,
                fontSize: 24,
                fontWeight: FontWeight.w800)),
        const SizedBox(height: 2),
        Text(label,
            style: TextStyle(color: Colors.white.withValues(alpha: 0.85))),
      ],
    );
  }
}

class _BranchCard extends ConsumerWidget {
  const _BranchCard({
    required this.branch,
    required this.currency,
    required this.isCurrent,
    required this.onEdit,
  });

  final Branch branch;
  final String currency;
  final bool isCurrent;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    final o = ref.watch(branchOverviewProvider(branch.id));

    return AppCard(
      padding: const EdgeInsets.all(AppSpace.md),
      onTap: onEdit,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: scheme.primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(AppRadius.md),
                ),
                child: Icon(Icons.storefront_outlined, color: scheme.primary),
              ),
              const SizedBox(width: AppSpace.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(branch.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: text.titleSmall),
                        ),
                        if (isCurrent) ...[
                          const SizedBox(width: 8),
                          const StatusPill(
                              label: 'Viewing', color: AppColors.brand),
                        ],
                      ],
                    ),
                    if (branch.address.isNotEmpty)
                      Text(branch.address,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: text.bodySmall),
                  ],
                ),
              ),
              if (!branch.active)
                const StatusPill(label: 'Disabled', color: AppColors.danger),
              Icon(Icons.chevron_right, color: scheme.onSurfaceVariant),
            ],
          ),
          const Divider(height: 20),
          Row(
            children: [
              _stat(context, 'Sales today',
                  Fmt.money(o.revenue, currency: currency)),
              _stat(context, 'Orders', o.orders.toString()),
              _stat(context, 'Stock value',
                  Fmt.money(o.stockValue, currency: currency)),
              _stat(context, 'Low stock', o.lowStock.toString(),
                  warn: o.lowStock > 0),
            ],
          ),
        ],
      ),
    );
  }

  Widget _stat(BuildContext context, String label, String value,
      {bool warn = false}) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: warn ? AppColors.warning : null,
              )),
          Text(label, style: Theme.of(context).textTheme.bodySmall),
        ],
      ),
    );
  }
}

class _BranchForm extends ConsumerStatefulWidget {
  const _BranchForm({this.existing});
  final Branch? existing;

  @override
  ConsumerState<_BranchForm> createState() => _BranchFormState();
}

class _BranchFormState extends ConsumerState<_BranchForm> {
  final _formKey = GlobalKey<FormState>();
  late final _name = TextEditingController(text: widget.existing?.name ?? '');
  late final _address =
      TextEditingController(text: widget.existing?.address ?? '');
  late final _phone = TextEditingController(text: widget.existing?.phone ?? '');
  bool _busy = false;
  String? _error;

  bool get _isEdit => widget.existing != null;

  @override
  void dispose() {
    _name.dispose();
    _address.dispose();
    _phone.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    final base = (widget.existing ?? const Branch(id: '', name: '')).copyWith(
      name: _name.text.trim(),
      address: _address.text.trim(),
      phone: _phone.text.trim(),
    );
    try {
      final actions = ref.read(branchActionsProvider);
      if (_isEdit) {
        await actions.update(base);
      } else {
        await actions.create(base);
      }
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      setState(() => _error = 'Could not save: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
          AppSpace.xl, AppSpace.lg, AppSpace.xl, AppSpace.xl),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(_isEdit ? 'Edit branch' : 'New branch',
                style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: AppSpace.lg),
            TextFormField(
              controller: _name,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(
                labelText: 'Branch name',
                prefixIcon: Icon(Icons.storefront_outlined),
              ),
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Enter a name' : null,
            ),
            const SizedBox(height: AppSpace.md),
            TextFormField(
              controller: _address,
              decoration: const InputDecoration(
                labelText: 'Address',
                prefixIcon: Icon(Icons.location_on_outlined),
              ),
            ),
            const SizedBox(height: AppSpace.md),
            TextFormField(
              controller: _phone,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(
                labelText: 'Phone',
                prefixIcon: Icon(Icons.phone_outlined),
              ),
            ),
            if (_isEdit) ...[
              const SizedBox(height: AppSpace.sm),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Active'),
                value: widget.existing!.active,
                onChanged: (v) async {
                  await ref
                      .read(branchActionsProvider)
                      .setActive(widget.existing!.id, v);
                  if (context.mounted) Navigator.of(context).pop();
                },
              ),
            ],
            if (_error != null) ...[
              const SizedBox(height: AppSpace.md),
              FormErrorBox(_error!),
            ],
            const SizedBox(height: AppSpace.lg),
            FilledButton(
              onPressed: _busy ? null : _save,
              child: _busy
                  ? const ButtonSpinner()
                  : Text(_isEdit ? 'Save changes' : 'Add branch'),
            ),
          ],
        ),
      ),
    );
  }
}
