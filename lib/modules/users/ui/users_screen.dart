import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/company/company_providers.dart';
import '../../../core/permissions/permissions.dart';
import '../../../core/profile/domain/user_profile.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/ui/app_card.dart';
import '../../../core/ui/status_pill.dart';
import '../../branches/branches_providers.dart';
import 'add_employee_sheet.dart';

/// Staff management — owner/manager view of the team. Add employees, change
/// their role, or disable access.
class UsersScreen extends ConsumerWidget {
  const UsersScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final employeesAsync = ref.watch(employeesProvider);
    final me = ref.watch(currentProfileProvider);

    return Padding(
      padding: const EdgeInsets.all(AppSpace.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Text('Team', style: Theme.of(context).textTheme.titleMedium),
              const Spacer(),
              FilledButton.icon(
                onPressed: () => AddEmployeeSheet.show(context),
                style: FilledButton.styleFrom(minimumSize: const Size(0, 48)),
                icon: const Icon(Icons.person_add_alt_1, size: 18),
                label: const Text('Add Employee'),
              ),
            ],
          ),
          const SizedBox(height: AppSpace.lg),
          Expanded(
            child: employeesAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('Failed to load team: $e')),
              data: (employees) {
                final sorted = [...employees]..sort((a, b) {
                    // Owner first, then by name.
                    if (a.roleId == 'owner') return -1;
                    if (b.roleId == 'owner') return 1;
                    return (a.displayName ?? a.email)
                        .compareTo(b.displayName ?? b.email);
                  });
                if (sorted.isEmpty) {
                  return const Center(child: Text('No team members yet.'));
                }
                return ListView.separated(
                  itemCount: sorted.length,
                  separatorBuilder: (context, i) =>
                      const SizedBox(height: AppSpace.md),
                  itemBuilder: (context, i) =>
                      _EmployeeCard(employee: sorted[i], isMe: sorted[i].uid == me.uid),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _EmployeeCard extends ConsumerWidget {
  const _EmployeeCard({required this.employee, required this.isMe});
  final UserProfile employee;
  final bool isMe;

  bool get _isOwner => employee.roleId == 'owner';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    final name = employee.displayName ?? employee.email;
    final admin = ref.read(userAdminProvider);
    final branches = ref.watch(branchesProvider).value ?? const [];
    final branchMatches =
        branches.where((b) => b.id == employee.branchId);
    final branchName = employee.branchId.isEmpty
        ? 'All branches'
        : (branchMatches.isEmpty ? null : branchMatches.first.name);
    // Owner can manage others, but not themselves or the owner record here.
    final canManage = !isMe && !_isOwner;

    return AppCard(
      padding: const EdgeInsets.all(AppSpace.md),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              gradient: _isOwner ? AppColors.brandGradient : null,
              color: _isOwner ? null : scheme.primary.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(AppRadius.md),
            ),
            alignment: Alignment.center,
            child: Text(
              name.isNotEmpty ? name[0].toUpperCase() : '?',
              style: TextStyle(
                color: _isOwner ? Colors.white : scheme.primary,
                fontWeight: FontWeight.w700,
                fontSize: 18,
              ),
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
                      child: Text(name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: text.titleSmall),
                    ),
                    if (isMe) ...[
                      const SizedBox(width: 6),
                      Text('(you)', style: text.bodySmall),
                    ],
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  branchName == null
                      ? employee.email
                      : '${employee.email}  ·  $branchName',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: text.bodySmall,
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          if (!employee.active)
            const StatusPill(label: 'Disabled', color: AppColors.danger)
          else
            StatusPill(
              label: employee.role.name,
              color: _isOwner ? AppColors.brand : AppColors.accent,
            ),
          if (canManage)
            PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert),
              onSelected: (value) async {
                switch (value) {
                  case 'disable':
                    await admin.setActive(employee.uid, false);
                  case 'enable':
                    await admin.setActive(employee.uid, true);
                  default:
                    if (value.startsWith('role:')) {
                      await admin.setRole(employee.uid, value.substring(5));
                    }
                }
              },
              itemBuilder: (_) => [
                const PopupMenuItem(
                    enabled: false, child: Text('Change role')),
                for (final r in Roles.all.where((r) => r.id != 'owner'))
                  PopupMenuItem(
                    value: 'role:${r.id}',
                    child: Row(
                      children: [
                        if (r.id == employee.roleId)
                          const Icon(Icons.check, size: 16)
                        else
                          const SizedBox(width: 16),
                        const SizedBox(width: 8),
                        Text(r.name),
                      ],
                    ),
                  ),
                const PopupMenuDivider(),
                if (employee.active)
                  const PopupMenuItem(
                    value: 'disable',
                    child: ListTile(
                      leading: Icon(Icons.block, color: AppColors.danger),
                      title: Text('Disable access'),
                      contentPadding: EdgeInsets.zero,
                    ),
                  )
                else
                  const PopupMenuItem(
                    value: 'enable',
                    child: ListTile(
                      leading: Icon(Icons.check_circle_outline),
                      title: Text('Enable access'),
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
              ],
            ),
        ],
      ),
    );
  }
}
