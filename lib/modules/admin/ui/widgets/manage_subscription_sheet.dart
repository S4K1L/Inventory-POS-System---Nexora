import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/company/company_providers.dart';
import '../../../../core/company/domain/company.dart';
import '../../../../core/company/domain/plan.dart';
import '../../../../core/platform/platform_providers.dart';
import '../../../../core/theme/app_tokens.dart';
import '../../../../core/utils/format.dart';

/// Admin sheet to approve a company or change its subscription.
class ManageSubscriptionSheet extends ConsumerStatefulWidget {
  const ManageSubscriptionSheet({super.key, required this.company});
  final Company company;

  static Future<void> show(BuildContext context, Company company) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => Padding(
        padding:
            EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
        child: ManageSubscriptionSheet(company: company),
      ),
    );
  }

  @override
  ConsumerState<ManageSubscriptionSheet> createState() =>
      _ManageSubscriptionSheetState();
}

class _ManageSubscriptionSheetState
    extends ConsumerState<ManageSubscriptionSheet> {
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
    final config = ref.watch(currentPlatformConfigProvider);
    final isDemo = _plan == PlanTier.demo;
    final approved = c.status == CompanyStatus.approved;

    final price = _plan == PlanTier.starter
        ? config.starterPrice
        : _plan == PlanTier.pro
            ? config.proPrice
            : 0;

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
            _infoBox(context,
                'Demo runs for ${config.demoDays} days (free trial).')
          else
            Column(
              children: [
                Row(
                  children: [
                    Text('Duration', style: text.bodyMedium),
                    const Spacer(),
                    IconButton(
                      onPressed:
                          _months > 1 ? () => setState(() => _months--) : null,
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
                if (price > 0)
                  _infoBox(
                    context,
                    'Billed ${Fmt.money(price, currency: config.currency)}/mo · '
                    'total ${Fmt.money(price * _months, currency: config.currency)} '
                    'for $_months month${_months == 1 ? '' : 's'}.',
                  ),
              ],
            ),
          const SizedBox(height: AppSpace.lg),
          if (_busy)
            const Center(
                child: Padding(
              padding: EdgeInsets.all(8),
              child: CircularProgressIndicator(),
            ))
          else ...[
            FilledButton.icon(
              onPressed: () => _run((a) => approved
                  ? a.changePlan(c, _plan,
                      months: _months, demoDays: config.demoDays)
                  : a.approve(c.id, _plan,
                      months: _months, demoDays: config.demoDays)),
              icon: const Icon(Icons.check),
              label: Text(approved ? 'Update plan' : 'Approve & activate'),
            ),
            const SizedBox(height: 8),
            if (approved)
              OutlinedButton.icon(
                onPressed: () => _run(
                    (a) => a.extend(c, months: _months, demoDays: config.demoDays)),
                icon: const Icon(Icons.more_time),
                label: Text(isDemo
                    ? 'Extend ${config.demoDays} days'
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

  Widget _infoBox(BuildContext context, String msg) {
    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.all(AppSpace.md),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: AppRadius.field,
      ),
      child: Row(
        children: [
          const Icon(Icons.info_outline, size: 18),
          const SizedBox(width: 8),
          Expanded(
              child: Text(msg, style: Theme.of(context).textTheme.bodyMedium)),
        ],
      ),
    );
  }
}
