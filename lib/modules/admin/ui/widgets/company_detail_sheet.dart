import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/company/domain/company.dart';
import '../../../../core/theme/app_tokens.dart';
import '../../../../core/ui/app_card.dart';
import '../../../../core/ui/status_pill.dart';
import '../../admin_providers.dart';
import 'manage_subscription_sheet.dart';

/// Full tenant view for the admin: subscription + the tenant's team & branches.
class CompanyDetailSheet extends ConsumerWidget {
  const CompanyDetailSheet({super.key, required this.company});
  final Company company;

  static Future<void> show(BuildContext context, Company company) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => CompanyDetailSheet(company: company),
    );
  }

  (Color, String) _statusPill() {
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
  Widget build(BuildContext context, WidgetRef ref) {
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    final users = ref.watch(companyUsersProvider(company.id)).value ?? const [];
    final branches =
        ref.watch(companyBranchesProvider(company.id)).value ?? const [];
    final (pillColor, pillLabel) = _statusPill();

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.75,
      maxChildSize: 0.95,
      builder: (context, controller) => ListView(
        controller: controller,
        padding: const EdgeInsets.all(AppSpace.xl),
        children: [
          Row(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                    color: scheme.primary.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(AppRadius.md)),
                alignment: Alignment.center,
                child: Text(
                  company.name.isNotEmpty
                      ? company.name[0].toUpperCase()
                      : '?',
                  style: TextStyle(
                      color: scheme.primary,
                      fontWeight: FontWeight.w700,
                      fontSize: 20),
                ),
              ),
              const SizedBox(width: AppSpace.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(company.name, style: text.titleLarge),
                    if (company.ownerEmail.isNotEmpty)
                      Text(company.ownerEmail, style: text.bodySmall),
                  ],
                ),
              ),
              StatusPill(label: pillLabel, color: pillColor),
            ],
          ),
          const SizedBox(height: AppSpace.lg),
          AppCard(
            child: Column(
              children: [
                _kv(context, 'Plan', company.plan.label),
                const Divider(height: 18),
                _kv(
                    context,
                    'Expires',
                    company.planExpiresAt == null
                        ? '—'
                        : '${DateFormat('d MMM yyyy').format(company.planExpiresAt!)}'
                            '${company.isActive ? '  (${company.daysLeft}d left)' : ''}'),
                const Divider(height: 18),
                _kv(context, 'Created',
                    company.createdAt == null
                        ? '—'
                        : DateFormat('d MMM yyyy').format(company.createdAt!)),
                const Divider(height: 18),
                _kv(context, 'Team', '${users.length}'),
                const Divider(height: 18),
                _kv(context, 'Branches', '${branches.length}'),
              ],
            ),
          ),
          const SizedBox(height: AppSpace.lg),
          FilledButton.icon(
            onPressed: () {
              Navigator.of(context).pop();
              ManageSubscriptionSheet.show(context, company);
            },
            icon: const Icon(Icons.tune),
            label: Text(company.status == CompanyStatus.pending
                ? 'Approve subscription'
                : 'Manage subscription'),
          ),
          const SizedBox(height: AppSpace.xl),
          Text('Team (${users.length})', style: text.titleSmall),
          const SizedBox(height: AppSpace.sm),
          if (users.isEmpty)
            Text('No users loaded.', style: text.bodySmall)
          else
            for (final u in users)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 16,
                      backgroundColor: scheme.primary.withValues(alpha: 0.12),
                      child: Text(
                        (u.displayName ?? u.email).isNotEmpty
                            ? (u.displayName ?? u.email)[0].toUpperCase()
                            : '?',
                        style: TextStyle(
                            color: scheme.primary,
                            fontWeight: FontWeight.w700,
                            fontSize: 13),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(u.displayName ?? u.email,
                          maxLines: 1, overflow: TextOverflow.ellipsis),
                    ),
                    StatusPill(
                        label: u.role.name,
                        color: u.roleId == 'owner'
                            ? AppColors.brand
                            : AppColors.accent),
                  ],
                ),
              ),
        ],
      ),
    );
  }

  Widget _kv(BuildContext context, String k, String v) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(k, style: Theme.of(context).textTheme.bodyMedium),
        Flexible(
          child: Text(v,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontWeight: FontWeight.w600)),
        ),
      ],
    );
  }
}
