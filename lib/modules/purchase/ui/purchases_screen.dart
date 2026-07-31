import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/access/gates.dart';
import '../../../core/company/company_providers.dart';
import '../../../core/permissions/permissions.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/ui/app_card.dart';
import '../../../core/ui/status_pill.dart';
import '../../../core/utils/format.dart';
import '../domain/purchase.dart';
import '../purchase_providers.dart';
import 'purchase_form_screen.dart';

/// Purchase history (goods received). Create a new purchase to add stock.
class PurchasesScreen extends ConsumerWidget {
  const PurchasesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final purchasesAsync = ref.watch(recentPurchasesProvider);
    final currency = ref.watch(currentCompanyProvider).currency;

    return Padding(
      padding: const EdgeInsets.all(AppSpace.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Text('Purchase Orders',
                  style: Theme.of(context).textTheme.titleMedium),
              const Spacer(),
              PermissionGate(
                permission: Perm.purchaseManage,
                child: FilledButton.icon(
                  onPressed: () => _create(context),
                  style: FilledButton.styleFrom(minimumSize: const Size(0, 48)),
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('Receive Purchase'),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpace.lg),
          Expanded(
            child: purchasesAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('Failed to load: $e')),
              data: (purchases) {
                if (purchases.isEmpty) {
                  return _EmptyState(onCreate: () => _create(context));
                }
                return ListView.separated(
                  itemCount: purchases.length,
                  separatorBuilder: (context, i) =>
                      const SizedBox(height: AppSpace.md),
                  itemBuilder: (context, i) =>
                      _PurchaseCard(purchase: purchases[i], currency: currency),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  void _create(BuildContext context) {
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => const PurchaseFormScreen(),
    ));
  }
}

class _PurchaseCard extends StatelessWidget {
  const _PurchaseCard({required this.purchase, required this.currency});
  final Purchase purchase;
  final String currency;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final supplier =
        purchase.supplierName.isEmpty ? 'No supplier' : purchase.supplierName;
    return AppCard(
      padding: const EdgeInsets.all(AppSpace.md),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: AppColors.success.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(AppRadius.md),
            ),
            child: const Icon(Icons.local_shipping_outlined,
                color: AppColors.success, size: 20),
          ),
          const SizedBox(width: AppSpace.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(purchase.billNo, style: text.titleSmall),
                const SizedBox(height: 2),
                Text(
                  '$supplier  ·  ${DateFormat('d MMM, h:mm a').format(purchase.createdAt)}  ·  '
                  '${purchase.itemCount} item${purchase.itemCount == 1 ? '' : 's'}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: text.bodySmall,
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(Fmt.money(purchase.total, currency: currency),
                  style: text.titleSmall),
              const SizedBox(height: 4),
              if (purchase.due > 0)
                StatusPill(
                    label: 'Due ${Fmt.money(purchase.due, currency: currency)}',
                    color: AppColors.warning)
              else
                const StatusPill(label: 'Paid', color: AppColors.success),
            ],
          ),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.onCreate});
  final VoidCallback onCreate;

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
              color: AppColors.success.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(AppRadius.xl),
            ),
            child: const Icon(Icons.local_shipping_outlined,
                size: 40, color: AppColors.success),
          ),
          const SizedBox(height: AppSpace.lg),
          Text('No purchases yet', style: text.titleLarge),
          const SizedBox(height: 4),
          Text('Receive stock from a supplier to get started.',
              style: text.bodyMedium),
          const SizedBox(height: AppSpace.xl),
          PermissionGate(
            permission: Perm.purchaseManage,
            child: FilledButton.icon(
              onPressed: onCreate,
              icon: const Icon(Icons.add, size: 18),
              label: const Text('Receive Purchase'),
            ),
          ),
        ],
      ),
    );
  }
}
