import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/company/domain/company.dart';
import '../../../../core/theme/app_tokens.dart';
import '../../../../core/ui/app_card.dart';
import '../../../../core/ui/pill_chips.dart';
import '../../../../core/ui/status_pill.dart';
import '../../admin_providers.dart';
import '../widgets/company_detail_sheet.dart';
import '../widgets/manage_subscription_sheet.dart';

class CompaniesSection extends ConsumerWidget {
  const CompaniesSection({super.key});

  static const _filters = [
    null,
    CompanyStatus.approved,
    CompanyStatus.pending,
    CompanyStatus.suspended,
  ];
  static const _filterLabels = ['All', 'Active', 'Pending', 'Suspended'];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final companies = ref.watch(filteredCompaniesProvider);
    final filter = ref.watch(companyFilterProvider);
    final notifier = ref.read(companyFilterProvider.notifier);
    final selected = _filters.indexOf(filter.status);

    return Padding(
      padding: const EdgeInsets.all(AppSpace.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            onChanged: notifier.setQuery,
            decoration: const InputDecoration(
              hintText: 'Search by company or owner email…',
              prefixIcon: Icon(Icons.search),
              isDense: true,
            ),
          ),
          const SizedBox(height: AppSpace.md),
          PillChips(
            labels: _filterLabels,
            selectedIndex: selected < 0 ? 0 : selected,
            onSelected: (i) => notifier.setStatus(_filters[i]),
          ),
          const SizedBox(height: AppSpace.lg),
          Expanded(
            child: companies.isEmpty
                ? const Center(child: Text('No companies match.'))
                : ListView.separated(
                    itemCount: companies.length,
                    separatorBuilder: (context, i) =>
                        const SizedBox(height: AppSpace.md),
                    itemBuilder: (context, i) =>
                        _CompanyRow(company: companies[i]),
                  ),
          ),
        ],
      ),
    );
  }
}

class _CompanyRow extends StatelessWidget {
  const _CompanyRow({required this.company});
  final Company company;

  (Color, String) _pill() {
    if (company.status == CompanyStatus.pending) {
      return (AppColors.warning, 'Pending');
    }
    if (company.status == CompanyStatus.suspended) {
      return (AppColors.danger, 'Suspended');
    }
    if (company.isExpired) return (AppColors.danger, 'Expired');
    return (AppColors.success, 'Active');
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    final (pillColor, pillLabel) = _pill();
    final expiry = company.planExpiresAt;

    return AppCard(
      padding: const EdgeInsets.all(AppSpace.md),
      onTap: () => CompanyDetailSheet.show(context, company),
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
                color: scheme.primary.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(AppRadius.md)),
            alignment: Alignment.center,
            child: Text(
              company.name.isNotEmpty ? company.name[0].toUpperCase() : '?',
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
                Row(
                  children: [
                    Flexible(
                      child: Text(company.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: text.titleSmall),
                    ),
                    const SizedBox(width: 8),
                    StatusPill(label: pillLabel, color: pillColor),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  [
                    if (company.ownerEmail.isNotEmpty) company.ownerEmail,
                    '${company.plan.label} plan',
                    if (expiry != null)
                      company.isExpired
                          ? 'expired ${DateFormat('d MMM').format(expiry)}'
                          : '${company.daysLeft}d left',
                  ].join('  ·  '),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: text.bodySmall,
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          FilledButton(
            onPressed: () => ManageSubscriptionSheet.show(context, company),
            style: FilledButton.styleFrom(minimumSize: const Size(0, 40)),
            child: Text(
                company.status == CompanyStatus.pending ? 'Approve' : 'Manage'),
          ),
        ],
      ),
    );
  }
}
