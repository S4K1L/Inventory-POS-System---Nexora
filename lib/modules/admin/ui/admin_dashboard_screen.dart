import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/auth/auth_providers.dart';
import '../../../core/company/company_providers.dart';
import '../../../core/company/domain/company.dart';
import '../../../core/company/domain/plan.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/ui/app_card.dart';
import '../../../core/ui/brand_logo.dart';
import '../../../core/ui/status_pill.dart';

/// Super-admin control panel: approve signups and manage each tenant's plan.
class AdminDashboardScreen extends ConsumerWidget {
  const AdminDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final companiesAsync = ref.watch(allCompaniesProvider);
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: AppSpace.xl, vertical: AppSpace.lg),
              decoration: BoxDecoration(
                color: scheme.surface,
                border: Border(bottom: BorderSide(color: scheme.outline)),
              ),
              child: Row(
                children: [
                  const BrandLogo(size: 32),
                  const SizedBox(width: 12),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: scheme.primary.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(AppRadius.sm),
                    ),
                    child: Text('ADMIN',
                        style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            color: scheme.primary)),
                  ),
                  const Spacer(),
                  if (ref.watch(currentProfileProvider).hasCompany)
                    OutlinedButton.icon(
                      onPressed: () => context.go('/'),
                      icon: const Icon(Icons.arrow_back, size: 18),
                      label: const Text('Back to app'),
                    )
                  else
                    OutlinedButton.icon(
                      onPressed: () =>
                          ref.read(authRepositoryProvider).signOut(),
                      icon: const Icon(Icons.logout, size: 18),
                      label: const Text('Sign out'),
                    ),
                ],
              ),
            ),
            Expanded(
              child: companiesAsync.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, _) => Center(
                    child: Padding(
                  padding: const EdgeInsets.all(AppSpace.xl),
                  child: Text('Failed to load companies:\n$e',
                      textAlign: TextAlign.center),
                )),
                data: (companies) => _Body(companies: companies),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Body extends StatelessWidget {
  const _Body({required this.companies});
  final List<Company> companies;

  @override
  Widget build(BuildContext context) {
    final pending =
        companies.where((c) => c.status == CompanyStatus.pending).length;
    final active = companies.where((c) => c.isActive).length;

    return ListView(
      padding: const EdgeInsets.all(AppSpace.xl),
      children: [
        LayoutBuilder(builder: (context, c) {
          final wide = c.maxWidth >= 680;
          final cards = [
            _stat('Total tenants', companies.length.toString(),
                Icons.business_outlined, AppColors.brand),
            _stat('Pending approval', pending.toString(),
                Icons.hourglass_top_outlined, AppColors.warning),
            _stat('Active', active.toString(), Icons.check_circle_outline,
                AppColors.success),
          ];
          return wide
              ? Row(
                  children: [
                    for (var i = 0; i < cards.length; i++) ...[
                      if (i > 0) const SizedBox(width: AppSpace.lg),
                      Expanded(child: cards[i]),
                    ]
                  ],
                )
              : Column(
                  children: [
                    for (final card in cards) ...[
                      card,
                      const SizedBox(height: AppSpace.md)
                    ]
                  ],
                );
        }),
        const SizedBox(height: AppSpace.xl),
        Text('Companies', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: AppSpace.sm),
        if (companies.isEmpty)
          const Padding(
            padding: EdgeInsets.all(40),
            child: Center(child: Text('No companies yet.')),
          )
        else
          for (final company in companies)
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpace.md),
              child: _CompanyRow(company: company),
            ),
      ],
    );
  }

  Widget _stat(String label, String value, IconData icon, Color color) {
    return _StatCardMini(
        label: label, value: value, icon: icon, color: color);
  }
}

class _StatCardMini extends StatelessWidget {
  const _StatCardMini(
      {required this.label,
      required this.value,
      required this.icon,
      required this.color});
  final String label;
  final String value;
  final IconData icon;
  final Color color;

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
                Text(value, style: text.headlineSmall),
                Text(label, style: text.bodySmall),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CompanyRow extends ConsumerWidget {
  const _CompanyRow({required this.company});
  final Company company;

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
    final (pillColor, pillLabel) = _statusPill();
    final expiry = company.planExpiresAt;

    return AppCard(
      padding: const EdgeInsets.all(AppSpace.md),
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
            onPressed: () => _manage(context, ref),
            style: FilledButton.styleFrom(minimumSize: const Size(0, 40)),
            child: Text(
                company.status == CompanyStatus.pending ? 'Approve' : 'Manage'),
          ),
        ],
      ),
    );
  }

  void _manage(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => Padding(
        padding:
            EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
        child: _ManageSheet(company: company),
      ),
    );
  }
}

class _ManageSheet extends ConsumerStatefulWidget {
  const _ManageSheet({required this.company});
  final Company company;

  @override
  ConsumerState<_ManageSheet> createState() => _ManageSheetState();
}

class _ManageSheetState extends ConsumerState<_ManageSheet> {
  late PlanTier _plan = widget.company.plan;
  int _months = 1;
  bool _busy = false;

  Future<void> _run(Future<void> Function(AdminSubscription a) action) async {
    setState(() => _busy = true);
    try {
      await action(ref.read(adminSubscriptionProvider));
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Failed: $e')));
        setState(() => _busy = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.company;
    final text = Theme.of(context).textTheme;
    final isDemo = _plan == PlanTier.demo;

    return Padding(
      padding: const EdgeInsets.fromLTRB(
          AppSpace.xl, AppSpace.lg, AppSpace.xl, AppSpace.xl),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(c.name, style: text.titleLarge),
          if (c.ownerEmail.isNotEmpty)
            Text(c.ownerEmail, style: text.bodySmall),
          const SizedBox(height: AppSpace.lg),
          Text('Plan', style: text.bodySmall),
          const SizedBox(height: 6),
          SegmentedButton<PlanTier>(
            segments: const [
              ButtonSegment(value: PlanTier.demo, label: Text('Demo')),
              ButtonSegment(value: PlanTier.starter, label: Text('Starter')),
              ButtonSegment(value: PlanTier.pro, label: Text('Pro')),
            ],
            selected: {_plan},
            onSelectionChanged: (s) => setState(() => _plan = s.first),
          ),
          const SizedBox(height: AppSpace.md),
          if (isDemo)
            Container(
              padding: const EdgeInsets.all(AppSpace.md),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                borderRadius: AppRadius.field,
              ),
              child: Row(
                children: [
                  const Icon(Icons.info_outline, size: 18),
                  const SizedBox(width: 8),
                  Text('Demo runs for 7 days.', style: text.bodyMedium),
                ],
              ),
            )
          else
            Row(
              children: [
                Text('Duration', style: text.bodyMedium),
                const Spacer(),
                IconButton(
                  onPressed: _months > 1
                      ? () => setState(() => _months--)
                      : null,
                  icon: const Icon(Icons.remove_circle_outline),
                ),
                Text('$_months month${_months == 1 ? '' : 's'}',
                    style: text.titleMedium),
                IconButton(
                  onPressed: () => setState(() => _months++),
                  icon: const Icon(Icons.add_circle_outline),
                ),
              ],
            ),
          const SizedBox(height: AppSpace.lg),
          if (_busy)
            const Center(child: Padding(
              padding: EdgeInsets.all(8),
              child: CircularProgressIndicator(),
            ))
          else ...[
            FilledButton.icon(
              onPressed: () => _run((a) => c.status == CompanyStatus.approved
                  ? a.changePlan(c, _plan, months: _months)
                  : a.approve(c.id, _plan, months: _months)),
              icon: const Icon(Icons.check),
              label: Text(c.status == CompanyStatus.approved
                  ? 'Update plan'
                  : 'Approve & activate'),
            ),
            const SizedBox(height: 8),
            if (c.status == CompanyStatus.approved)
              OutlinedButton.icon(
                onPressed: () => _run((a) => a.extend(c, months: _months)),
                icon: const Icon(Icons.more_time),
                label: Text(isDemo
                    ? 'Extend 7 days'
                    : 'Extend $_months month${_months == 1 ? '' : 's'}'),
              ),
            const SizedBox(height: 8),
            if (c.status != CompanyStatus.suspended)
              TextButton.icon(
                onPressed: () => _run((a) => a.suspend(c)),
                style: TextButton.styleFrom(foregroundColor: AppColors.danger),
                icon: const Icon(Icons.block),
                label: const Text('Suspend account'),
              ),
          ],
        ],
      ),
    );
  }
}
