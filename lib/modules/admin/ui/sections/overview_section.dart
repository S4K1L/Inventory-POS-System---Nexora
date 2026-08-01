import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/company/company_providers.dart';
import '../../../../core/company/domain/company.dart';
import '../../../../core/company/domain/plan.dart';
import '../../../../core/theme/app_tokens.dart';
import '../../../../core/ui/app_card.dart';
import '../../../../core/ui/stat_card.dart';
import '../../../../core/ui/status_pill.dart';
import '../../../../core/utils/format.dart';
import '../../admin_providers.dart';
import '../widgets/company_detail_sheet.dart';

class OverviewSection extends ConsumerWidget {
  const OverviewSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stats = ref.watch(adminStatsProvider);
    final all = ref.watch(allCompaniesProvider).value ?? const [];
    final cur = stats.currency;

    final expiring = all
        .where((c) => c.isActive && c.daysLeft <= 7)
        .toList()
      ..sort((a, b) => a.daysLeft.compareTo(b.daysLeft));
    final recent = [...all]
      ..sort((a, b) => (b.createdAt ?? DateTime(2000))
          .compareTo(a.createdAt ?? DateTime(2000)));

    return ListView(
      padding: const EdgeInsets.all(AppSpace.xl),
      children: [
        LayoutBuilder(builder: (context, c) {
          final cols = c.maxWidth >= 1100 ? 4 : (c.maxWidth >= 680 ? 2 : 1);
          return GridView.count(
            crossAxisCount: cols,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: AppSpace.lg,
            crossAxisSpacing: AppSpace.lg,
            childAspectRatio: 1.7,
            children: [
              StatCard(
                  label: 'Monthly Revenue (MRR)',
                  value: Fmt.money(stats.mrr, currency: cur),
                  icon: Icons.payments_outlined,
                  color: AppColors.success),
              StatCard(
                  label: 'Active Tenants',
                  value: stats.active.toString(),
                  icon: Icons.verified_outlined,
                  color: AppColors.brand),
              StatCard(
                  label: 'Pending Approval',
                  value: stats.pending.toString(),
                  icon: Icons.hourglass_top_outlined,
                  color: AppColors.warning),
              StatCard(
                  label: 'Expiring ≤ 7 days',
                  value: stats.expiringSoon.toString(),
                  icon: Icons.timer_outlined,
                  color: AppColors.danger),
              StatCard(
                  label: 'Total Tenants',
                  value: stats.total.toString(),
                  icon: Icons.business_outlined,
                  color: AppColors.brandLight),
              StatCard(
                  label: 'Suspended',
                  value: stats.suspended.toString(),
                  icon: Icons.block,
                  color: AppColors.danger),
              StatCard(
                  label: 'Expired',
                  value: stats.expired.toString(),
                  icon: Icons.event_busy_outlined,
                  color: AppColors.warning),
              StatCard(
                  label: 'Demo Trials',
                  value: (stats.planCounts[PlanTier.demo] ?? 0).toString(),
                  icon: Icons.science_outlined,
                  color: AppColors.accent),
            ],
          );
        }),
        const SizedBox(height: AppSpace.xl),
        LayoutBuilder(builder: (context, c) {
          final wide = c.maxWidth >= 900;
          final plan = _PlanBreakdown(stats: stats);
          final exp = _ListCard(
            title: 'Expiring soon',
            emptyLabel: 'Nothing expiring in 7 days',
            companies: expiring,
            currency: cur,
            trailing: (co) => '${co.daysLeft}d left',
            trailingColor: AppColors.danger,
          );
          return wide
              ? IntrinsicHeight(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Expanded(child: plan),
                      const SizedBox(width: AppSpace.lg),
                      Expanded(child: exp),
                    ],
                  ),
                )
              : Column(children: [
                  plan,
                  const SizedBox(height: AppSpace.lg),
                  exp,
                ]);
        }),
        const SizedBox(height: AppSpace.lg),
        _ListCard(
          title: 'Recent signups',
          emptyLabel: 'No signups yet',
          companies: recent.take(6).toList(),
          currency: cur,
          trailing: (co) => co.createdAt == null
              ? co.status.label
              : DateFormat('d MMM').format(co.createdAt!),
          trailingColor: AppColors.brand,
        ),
      ],
    );
  }
}

class _PlanBreakdown extends StatelessWidget {
  const _PlanBreakdown({required this.stats});
  final AdminStats stats;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final total = stats.active == 0 ? 1 : stats.active;
    Widget bar(PlanTier t, Color color) {
      final n = stats.planCounts[t] ?? 0;
      return Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Expanded(
                  child: Text(t.label,
                      style: const TextStyle(fontWeight: FontWeight.w600))),
              Text('$n'),
            ]),
            const SizedBox(height: 6),
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(
                value: n / total,
                minHeight: 8,
                backgroundColor:
                    Theme.of(context).colorScheme.surfaceContainerHighest,
                valueColor: AlwaysStoppedAnimation(color),
              ),
            ),
          ],
        ),
      );
    }

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Active plans', style: text.titleMedium),
          const SizedBox(height: AppSpace.lg),
          bar(PlanTier.demo, AppColors.accent),
          bar(PlanTier.starter, AppColors.brand),
          bar(PlanTier.pro, AppColors.success),
        ],
      ),
    );
  }
}

class _ListCard extends StatelessWidget {
  const _ListCard({
    required this.title,
    required this.emptyLabel,
    required this.companies,
    required this.currency,
    required this.trailing,
    required this.trailingColor,
  });

  final String title;
  final String emptyLabel;
  final List<Company> companies;
  final String currency;
  final String Function(Company) trailing;
  final Color trailingColor;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: text.titleMedium),
          const SizedBox(height: AppSpace.md),
          if (companies.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Text(emptyLabel, style: text.bodySmall),
            )
          else
            for (final co in companies)
              InkWell(
                onTap: () => CompanyDetailSheet.show(context, co),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(co.name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: text.titleSmall),
                            Text(co.plan.label, style: text.bodySmall),
                          ],
                        ),
                      ),
                      StatusPill(label: trailing(co), color: trailingColor),
                    ],
                  ),
                ),
              ),
        ],
      ),
    );
  }
}
