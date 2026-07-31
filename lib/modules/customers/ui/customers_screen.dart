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
import '../domain/customer.dart';
import '../customers_providers.dart';
import 'customer_form_screen.dart';

/// Customer directory — searchable list with contact info, dues and loyalty.
class CustomersScreen extends ConsumerStatefulWidget {
  const CustomersScreen({super.key});

  @override
  ConsumerState<CustomersScreen> createState() => _CustomersScreenState();
}

class _CustomersScreenState extends ConsumerState<CustomersScreen> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final customersAsync = ref.watch(customersProvider);
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
                    hintText: 'Search customers…',
                    prefixIcon: Icon(Icons.search),
                    isDense: true,
                  ),
                ),
              ),
              const SizedBox(width: AppSpace.md),
              PermissionGate(
                permission: Perm.customersManage,
                child: FilledButton.icon(
                  onPressed: () => _openForm(context),
                  style: FilledButton.styleFrom(minimumSize: const Size(0, 48)),
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('Add Customer'),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpace.lg),
          Expanded(
            child: customersAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('Failed to load: $e')),
              data: (customers) {
                final active = customers.where((c) => c.active).toList();
                if (active.isEmpty) {
                  return _EmptyState(onAdd: () => _openForm(context));
                }
                final list = _query.isEmpty
                    ? active
                    : active
                        .where((c) =>
                            c.name.toLowerCase().contains(_query) ||
                            c.phone.contains(_query) ||
                            c.email.toLowerCase().contains(_query))
                        .toList();
                if (list.isEmpty) {
                  return const Center(child: Text('No matching customers.'));
                }
                return ListView.separated(
                  itemCount: list.length,
                  separatorBuilder: (context, i) =>
                      const SizedBox(height: AppSpace.md),
                  itemBuilder: (context, i) => _CustomerCard(
                    customer: list[i],
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

  void _openForm(BuildContext context, {Customer? existing}) {
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => CustomerFormScreen(existing: existing),
    ));
  }
}

class _CustomerCard extends ConsumerWidget {
  const _CustomerCard({
    required this.customer,
    required this.currency,
    required this.onEdit,
  });

  final Customer customer;
  final String currency;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    final meta = [
      if (customer.phone.isNotEmpty) customer.phone,
      if (customer.email.isNotEmpty) customer.email,
    ].join('  ·  ');
    final canManage = ref.watch(accessProvider).can(Perm.customersManage);

    return AppCard(
      padding: const EdgeInsets.all(AppSpace.md),
      onTap: canManage ? onEdit : null,
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: scheme.primary.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(AppRadius.md),
            ),
            alignment: Alignment.center,
            child: Text(
              customer.name.isNotEmpty ? customer.name[0].toUpperCase() : '?',
              style: TextStyle(
                  color: scheme.primary,
                  fontWeight: FontWeight.w700,
                  fontSize: 18),
            ),
          ),
          const SizedBox(width: AppSpace.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(customer.name,
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
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              if (customer.dueAmount > 0)
                StatusPill(
                  label: 'Due ${Fmt.money(customer.dueAmount, currency: currency)}',
                  color: AppColors.danger,
                )
              else if (customer.loyaltyPoints > 0)
                StatusPill(
                  label: '${Fmt.qty(customer.loyaltyPoints)} pts',
                  color: AppColors.brand,
                ),
              if (canManage) ...[
                const SizedBox(height: 6),
                Icon(Icons.chevron_right,
                    size: 18, color: scheme.onSurfaceVariant),
              ],
            ],
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
              borderRadius: BorderRadius.circular(AppRadius.xl),
            ),
            child: Icon(Icons.people_outline, size: 40, color: scheme.primary),
          ),
          const SizedBox(height: AppSpace.lg),
          Text('No customers yet', style: text.titleLarge),
          const SizedBox(height: 4),
          Text('Add customers to track dues and loyalty.',
              style: text.bodyMedium),
          const SizedBox(height: AppSpace.xl),
          PermissionGate(
            permission: Perm.customersManage,
            child: FilledButton.icon(
              onPressed: onAdd,
              icon: const Icon(Icons.add, size: 18),
              label: const Text('Add Customer'),
            ),
          ),
        ],
      ),
    );
  }
}
