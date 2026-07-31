import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/access/access.dart';
import '../../../core/access/gates.dart';
import '../../../core/company/company_providers.dart';
import '../../../core/permissions/permissions.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/ui/app_card.dart';
import '../../../core/ui/status_pill.dart';
import '../../../core/utils/format.dart';
import '../domain/supplier.dart';
import '../suppliers_providers.dart';
import 'supplier_form_screen.dart';

/// Suppliers directory — searchable list with contact info and outstanding due.
class SuppliersScreen extends ConsumerStatefulWidget {
  const SuppliersScreen({super.key});

  @override
  ConsumerState<SuppliersScreen> createState() => _SuppliersScreenState();
}

class _SuppliersScreenState extends ConsumerState<SuppliersScreen> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final suppliersAsync = ref.watch(suppliersProvider);
    final currency = ref.watch(currentCompanyProvider).currency;

    return Padding(
      padding: const EdgeInsets.all(AppSpace.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: TextField(
                  onChanged: (v) =>
                      setState(() => _query = v.trim().toLowerCase()),
                  decoration: const InputDecoration(
                    hintText: 'Search suppliers…',
                    prefixIcon: Icon(Icons.search),
                    isDense: true,
                  ),
                ),
              ),
              const SizedBox(width: AppSpace.md),
              PermissionGate(
                permission: Perm.suppliersManage,
                child: FilledButton.icon(
                  onPressed: () => _openForm(context),
                  style: FilledButton.styleFrom(minimumSize: const Size(0, 48)),
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('Add Supplier'),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpace.lg),
          Expanded(
            child: suppliersAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('Failed to load: $e')),
              data: (suppliers) {
                final active = suppliers.where((s) => s.active).toList();
                if (active.isEmpty) {
                  return _EmptyState(onAdd: () => _openForm(context));
                }
                final list = _query.isEmpty
                    ? active
                    : active
                        .where((s) =>
                            s.name.toLowerCase().contains(_query) ||
                            s.contactPerson.toLowerCase().contains(_query) ||
                            s.phone.contains(_query))
                        .toList();
                if (list.isEmpty) {
                  return const Center(child: Text('No matching suppliers.'));
                }
                return ListView.separated(
                  itemCount: list.length,
                  separatorBuilder: (context, i) =>
                      const SizedBox(height: AppSpace.md),
                  itemBuilder: (context, i) => _SupplierCard(
                    supplier: list[i],
                    currency: currency,
                    onEdit: () => _openForm(context, existing: list[i]),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  void _openForm(BuildContext context, {Supplier? existing}) {
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => SupplierFormScreen(existing: existing),
    ));
  }
}

class _SupplierCard extends ConsumerWidget {
  const _SupplierCard({
    required this.supplier,
    required this.currency,
    required this.onEdit,
  });

  final Supplier supplier;
  final String currency;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    final meta = [
      if (supplier.contactPerson.isNotEmpty) supplier.contactPerson,
      if (supplier.phone.isNotEmpty) supplier.phone,
    ].join('  ·  ');
    final canManage = ref.watch(accessProvider).can(Perm.suppliersManage);

    return AppCard(
      padding: const EdgeInsets.all(AppSpace.md),
      onTap: canManage ? onEdit : null,
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: AppColors.accent.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(AppRadius.md),
            ),
            alignment: Alignment.center,
            child: Text(
              supplier.name.isNotEmpty ? supplier.name[0].toUpperCase() : '?',
              style: const TextStyle(
                  color: AppColors.accent,
                  fontWeight: FontWeight.w700,
                  fontSize: 18),
            ),
          ),
          const SizedBox(width: AppSpace.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(supplier.name,
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
          if (supplier.dueAmount > 0)
            StatusPill(
              label: 'Due ${Fmt.money(supplier.dueAmount, currency: currency)}',
              color: AppColors.warning,
            ),
          if (canManage) ...[
            const SizedBox(width: 4),
            Icon(Icons.chevron_right, color: scheme.onSurfaceVariant),
          ],
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
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 84,
            height: 84,
            decoration: BoxDecoration(
              color: AppColors.accent.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(AppRadius.xl),
            ),
            child: const Icon(Icons.store_outlined,
                size: 40, color: AppColors.accent),
          ),
          const SizedBox(height: AppSpace.lg),
          Text('No suppliers yet', style: text.titleLarge),
          const SizedBox(height: 4),
          Text('Add the vendors you buy stock from.',
              style: text.bodyMedium),
          const SizedBox(height: AppSpace.xl),
          PermissionGate(
            permission: Perm.suppliersManage,
            child: FilledButton.icon(
              onPressed: onAdd,
              icon: const Icon(Icons.add, size: 18),
              label: const Text('Add Supplier'),
            ),
          ),
        ],
      ),
    );
  }
}
