import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/company/company_providers.dart';
import '../../../../core/company/domain/company.dart';
import '../../../../core/theme/app_tokens.dart';
import '../../../../core/ui/app_card.dart';
import '../widgets/company_detail_sheet.dart';
import '../widgets/manage_subscription_sheet.dart';

class ApprovalsSection extends ConsumerWidget {
  const ApprovalsSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final all = ref.watch(allCompaniesProvider).value ?? const [];
    final pending =
        all.where((c) => c.status == CompanyStatus.pending).toList()
          ..sort((a, b) => (a.createdAt ?? DateTime(2000))
              .compareTo(b.createdAt ?? DateTime(2000)));

    if (pending.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 84,
              height: 84,
              decoration: BoxDecoration(
                  color: AppColors.success.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(AppRadius.xl)),
              child: const Icon(Icons.check_circle_outline,
                  size: 40, color: AppColors.success),
            ),
            const SizedBox(height: AppSpace.lg),
            Text('All caught up',
                style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 4),
            const Text('No accounts are waiting for approval.'),
          ],
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(AppSpace.xl),
      itemCount: pending.length,
      separatorBuilder: (context, i) => const SizedBox(height: AppSpace.md),
      itemBuilder: (context, i) => _PendingRow(company: pending[i]),
    );
  }
}

class _PendingRow extends StatelessWidget {
  const _PendingRow({required this.company});
  final Company company;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    return AppCard(
      padding: const EdgeInsets.all(AppSpace.md),
      onTap: () => CompanyDetailSheet.show(context, company),
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
                color: AppColors.warning.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(AppRadius.md)),
            child: const Icon(Icons.hourglass_top_outlined,
                color: AppColors.warning),
          ),
          const SizedBox(width: AppSpace.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(company.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: text.titleSmall),
                const SizedBox(height: 2),
                Text(
                  [
                    if (company.ownerEmail.isNotEmpty) company.ownerEmail,
                    if (company.createdAt != null)
                      'signed up ${DateFormat('d MMM').format(company.createdAt!)}',
                  ].join('  ·  '),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: text.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          FilledButton.icon(
            onPressed: () => ManageSubscriptionSheet.show(context, company),
            style: FilledButton.styleFrom(minimumSize: const Size(0, 40)),
            icon: const Icon(Icons.check, size: 16),
            label: const Text('Approve'),
          ),
        ],
      ),
    );
  }
}
