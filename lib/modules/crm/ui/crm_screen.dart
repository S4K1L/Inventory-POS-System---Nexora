import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/company/company_providers.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/ui/app_card.dart';
import '../../../core/ui/form_widgets.dart';
import '../../../core/utils/format.dart';
import '../crm_providers.dart';
import '../domain/deal.dart';

/// CRM — a simple sales pipeline. Deals grouped by stage with per-stage totals.
class CrmScreen extends ConsumerWidget {
  const CrmScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dealsAsync = ref.watch(dealsProvider);
    final currency = ref.watch(currentCompanyProvider).currency;

    return Padding(
      padding: const EdgeInsets.all(AppSpace.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Text('Pipeline', style: Theme.of(context).textTheme.titleMedium),
              const Spacer(),
              FilledButton.icon(
                onPressed: () => _openForm(context),
                style: FilledButton.styleFrom(minimumSize: const Size(0, 48)),
                icon: const Icon(Icons.add, size: 18),
                label: const Text('Add Deal'),
              ),
            ],
          ),
          const SizedBox(height: AppSpace.lg),
          Expanded(
            child: dealsAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('Failed to load: $e')),
              data: (deals) {
                if (deals.isEmpty) {
                  return _EmptyState(onAdd: () => _openForm(context));
                }
                final openValue = deals
                    .where((d) => d.stage.isOpen)
                    .fold<num>(0, (t, d) => t + d.value);
                final wonValue = deals
                    .where((d) => d.stage == DealStage.won)
                    .fold<num>(0, (t, d) => t + d.value);

                return ListView(
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: _MiniStat(
                            label: 'Open pipeline',
                            value: Fmt.money(openValue, currency: currency),
                            color: AppColors.brand,
                            icon: Icons.trending_up_rounded,
                          ),
                        ),
                        const SizedBox(width: AppSpace.lg),
                        Expanded(
                          child: _MiniStat(
                            label: 'Won',
                            value: Fmt.money(wonValue, currency: currency),
                            color: AppColors.success,
                            icon: Icons.emoji_events_outlined,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpace.xl),
                    for (final stage in DealStage.values)
                      _StageSection(
                        stage: stage,
                        deals: deals.where((d) => d.stage == stage).toList(),
                        currency: currency,
                        onEdit: (d) => _openForm(context, existing: d),
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

  void _openForm(BuildContext context, {Deal? existing}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => Padding(
        padding:
            EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
        child: _DealForm(existing: existing),
      ),
    );
  }
}

class _StageSection extends StatelessWidget {
  const _StageSection({
    required this.stage,
    required this.deals,
    required this.currency,
    required this.onEdit,
  });

  final DealStage stage;
  final List<Deal> deals;
  final String currency;
  final void Function(Deal) onEdit;

  @override
  Widget build(BuildContext context) {
    if (deals.isEmpty) return const SizedBox.shrink();
    final total = deals.fold<num>(0, (t, d) => t + d.value);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: AppSpace.sm),
          child: Row(
            children: [
              Container(
                width: 10,
                height: 10,
                decoration:
                    BoxDecoration(color: stage.color, shape: BoxShape.circle),
              ),
              const SizedBox(width: 8),
              Text('${stage.label} · ${deals.length}',
                  style: Theme.of(context).textTheme.titleSmall),
              const Spacer(),
              Text(Fmt.money(total, currency: currency),
                  style: Theme.of(context).textTheme.bodySmall),
            ],
          ),
        ),
        for (final d in deals)
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpace.md),
            child: _DealCard(deal: d, currency: currency, onEdit: () => onEdit(d)),
          ),
        const SizedBox(height: AppSpace.sm),
      ],
    );
  }
}

class _DealCard extends ConsumerWidget {
  const _DealCard(
      {required this.deal, required this.currency, required this.onEdit});
  final Deal deal;
  final String currency;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final text = Theme.of(context).textTheme;
    final meta = [
      if (deal.contactName.isNotEmpty) deal.contactName,
      if (deal.phone.isNotEmpty) deal.phone,
    ].join('  ·  ');

    return AppCard(
      padding: const EdgeInsets.all(AppSpace.md),
      onTap: onEdit,
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(deal.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: text.titleSmall),
                if (meta.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(meta,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: text.bodySmall),
                ],
              ],
            ),
          ),
          const SizedBox(width: 8),
          if (deal.value > 0)
            Text(Fmt.money(deal.value, currency: currency),
                style: text.titleSmall),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert),
            onSelected: (v) async {
              final actions = ref.read(crmActionsProvider);
              if (v == 'edit') {
                onEdit();
              } else if (v == 'delete') {
                await actions.delete(deal.id);
              } else if (v.startsWith('stage:')) {
                await actions.setStage(deal, DealStage.fromId(v.substring(6)));
              }
            },
            itemBuilder: (_) => [
              const PopupMenuItem(enabled: false, child: Text('Move to')),
              for (final s in DealStage.values)
                if (s != deal.stage)
                  PopupMenuItem(
                    value: 'stage:${s.id}',
                    child: Row(
                      children: [
                        Container(
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(
                                color: s.color, shape: BoxShape.circle)),
                        const SizedBox(width: 8),
                        Text(s.label),
                      ],
                    ),
                  ),
              const PopupMenuDivider(),
              const PopupMenuItem(value: 'edit', child: Text('Edit')),
              const PopupMenuItem(value: 'delete', child: Text('Delete')),
            ],
          ),
        ],
      ),
    );
  }
}

class _MiniStat extends StatelessWidget {
  const _MiniStat(
      {required this.label,
      required this.value,
      required this.color,
      required this.icon});
  final String label;
  final String value;
  final Color color;
  final IconData icon;

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
                borderRadius: BorderRadius.circular(AppRadius.md)),
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
            child: Icon(Icons.handshake_outlined,
                size: 40, color: scheme.primary),
          ),
          const SizedBox(height: AppSpace.lg),
          Text('No deals yet', style: text.titleLarge),
          const SizedBox(height: 4),
          Text('Track leads and opportunities through your pipeline.',
              style: text.bodyMedium),
          const SizedBox(height: AppSpace.xl),
          FilledButton.icon(
            onPressed: onAdd,
            icon: const Icon(Icons.add, size: 18),
            label: const Text('Add Deal'),
          ),
        ],
      ),
    );
  }
}

class _DealForm extends ConsumerStatefulWidget {
  const _DealForm({this.existing});
  final Deal? existing;

  @override
  ConsumerState<_DealForm> createState() => _DealFormState();
}

class _DealFormState extends ConsumerState<_DealForm> {
  final _formKey = GlobalKey<FormState>();
  late final _title = TextEditingController(text: widget.existing?.title ?? '');
  late final _contact =
      TextEditingController(text: widget.existing?.contactName ?? '');
  late final _phone = TextEditingController(text: widget.existing?.phone ?? '');
  late final _value = TextEditingController(
      text: (widget.existing?.value ?? 0) == 0
          ? ''
          : '${widget.existing!.value}');
  late final _note = TextEditingController(text: widget.existing?.note ?? '');
  late DealStage _stage = widget.existing?.stage ?? DealStage.lead;
  bool _busy = false;
  String? _error;

  bool get _isEdit => widget.existing != null;

  @override
  void dispose() {
    for (final c in [_title, _contact, _phone, _value, _note]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    final base = (widget.existing ??
            Deal(id: '', title: '', stage: _stage, createdAt: DateTime.now()))
        .copyWith(
      title: _title.text.trim(),
      contactName: _contact.text.trim(),
      phone: _phone.text.trim(),
      value: num.tryParse(_value.text.trim()) ?? 0,
      note: _note.text.trim(),
      stage: _stage,
    );
    try {
      final actions = ref.read(crmActionsProvider);
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
            Text(_isEdit ? 'Edit deal' : 'New deal',
                style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: AppSpace.lg),
            TextFormField(
              controller: _title,
              decoration: const InputDecoration(
                labelText: 'Deal title',
                prefixIcon: Icon(Icons.title),
              ),
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Enter a title' : null,
            ),
            const SizedBox(height: AppSpace.md),
            TextFormField(
              controller: _contact,
              decoration: const InputDecoration(
                labelText: 'Contact name',
                prefixIcon: Icon(Icons.person_outline),
              ),
            ),
            const SizedBox(height: AppSpace.md),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _phone,
                    keyboardType: TextInputType.phone,
                    decoration: const InputDecoration(
                      labelText: 'Phone',
                      prefixIcon: Icon(Icons.phone_outlined),
                    ),
                  ),
                ),
                const SizedBox(width: AppSpace.md),
                Expanded(
                  child: TextFormField(
                    controller: _value,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(
                      labelText: 'Value',
                      prefixIcon: Icon(Icons.attach_money),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpace.md),
            DropdownButtonFormField<DealStage>(
              initialValue: _stage,
              decoration: const InputDecoration(
                labelText: 'Stage',
                prefixIcon: Icon(Icons.flag_outlined),
              ),
              items: [
                for (final s in DealStage.values)
                  DropdownMenuItem(value: s, child: Text(s.label)),
              ],
              onChanged: (v) => setState(() => _stage = v ?? _stage),
            ),
            const SizedBox(height: AppSpace.md),
            TextFormField(
              controller: _note,
              maxLines: 2,
              decoration: const InputDecoration(
                labelText: 'Note',
                prefixIcon: Icon(Icons.notes),
                alignLabelWithHint: true,
              ),
            ),
            if (_error != null) ...[
              const SizedBox(height: AppSpace.md),
              FormErrorBox(_error!),
            ],
            const SizedBox(height: AppSpace.lg),
            FilledButton(
              onPressed: _busy ? null : _save,
              child: _busy
                  ? const ButtonSpinner()
                  : Text(_isEdit ? 'Save changes' : 'Add deal'),
            ),
          ],
        ),
      ),
    );
  }
}
