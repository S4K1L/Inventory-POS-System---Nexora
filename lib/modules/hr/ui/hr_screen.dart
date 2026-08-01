import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/company/company_providers.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/ui/app_card.dart';
import '../domain/attendance.dart';
import '../hr_providers.dart';

/// HR — daily attendance for the team.
class HrScreen extends ConsumerWidget {
  const HrScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final team = ref.watch(employeesProvider).value ?? const [];
    final attendance = ref.watch(attendanceProvider).value ?? const {};
    final dateStr = ref.watch(attendanceDateProvider);
    final date = DateTime.tryParse(dateStr) ?? DateTime.now();

    int count(AttendanceStatus s) =>
        attendance.values.where((v) => v == s).length;

    return Padding(
      padding: const EdgeInsets.all(AppSpace.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Text('Attendance',
                  style: Theme.of(context).textTheme.titleMedium),
              const Spacer(),
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(minimumSize: const Size(0, 42)),
                onPressed: () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: date,
                    firstDate: DateTime(2020),
                    lastDate: DateTime.now().add(const Duration(days: 1)),
                  );
                  if (picked != null) {
                    ref.read(attendanceDateProvider.notifier).set(picked);
                  }
                },
                icon: const Icon(Icons.calendar_today_outlined, size: 16),
                label: Text(DateFormat('d MMM yyyy').format(date)),
              ),
            ],
          ),
          const SizedBox(height: AppSpace.lg),
          Row(
            children: [
              _tally('Present', count(AttendanceStatus.present),
                  AppColors.success),
              const SizedBox(width: AppSpace.md),
              _tally('Absent', count(AttendanceStatus.absent), AppColors.danger),
              const SizedBox(width: AppSpace.md),
              _tally('Leave', count(AttendanceStatus.leave), AppColors.warning),
            ],
          ),
          const SizedBox(height: AppSpace.lg),
          Expanded(
            child: team.isEmpty
                ? const Center(child: Text('No team members yet.'))
                : ListView.separated(
                    itemCount: team.length,
                    separatorBuilder: (context, i) =>
                        const SizedBox(height: AppSpace.md),
                    itemBuilder: (context, i) {
                      final m = team[i];
                      return _AttendanceRow(
                        name: m.displayName ?? m.email,
                        role: m.role.name,
                        status: attendance[m.uid],
                        onSet: (s) => ref
                            .read(hrActionsProvider)
                            .mark(m.uid, dateStr, s),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _tally(String label, int value, Color color) {
    return Expanded(
      child: AppCard(
        padding: const EdgeInsets.all(AppSpace.md),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(AppRadius.md)),
              alignment: Alignment.center,
              child: Text('$value',
                  style: TextStyle(
                      color: color,
                      fontWeight: FontWeight.w800,
                      fontSize: 18)),
            ),
            const SizedBox(width: 10),
            Text(label),
          ],
        ),
      ),
    );
  }
}

class _AttendanceRow extends StatelessWidget {
  const _AttendanceRow({
    required this.name,
    required this.role,
    required this.status,
    required this.onSet,
  });

  final String name;
  final String role;
  final AttendanceStatus? status;
  final ValueChanged<AttendanceStatus> onSet;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    return AppCard(
      padding: const EdgeInsets.all(AppSpace.md),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: scheme.primary.withValues(alpha: 0.12),
            child: Text(name.isNotEmpty ? name[0].toUpperCase() : '?',
                style: TextStyle(
                    color: scheme.primary, fontWeight: FontWeight.w700)),
          ),
          const SizedBox(width: AppSpace.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: text.titleSmall),
                Text(role, style: text.bodySmall),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Wrap(
            spacing: 6,
            children: [
              for (final s in AttendanceStatus.values)
                _StatusButton(
                  status: s,
                  selected: status == s,
                  onTap: () => onSet(s),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _StatusButton extends StatelessWidget {
  const _StatusButton(
      {required this.status, required this.selected, required this.onTap});
  final AttendanceStatus status;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: selected ? status.color : scheme.surface,
      borderRadius: BorderRadius.circular(AppRadius.pill),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.pill),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadius.pill),
            border:
                Border.all(color: selected ? status.color : scheme.outline),
          ),
          child: Text(
            status.label,
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
              color: selected ? Colors.white : scheme.onSurface,
            ),
          ),
        ),
      ),
    );
  }
}
