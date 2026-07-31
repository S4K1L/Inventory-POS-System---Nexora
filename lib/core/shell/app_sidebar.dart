import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../access/access.dart';
import '../auth/auth_providers.dart';
import '../company/company_providers.dart';
import '../modules/module.dart';
import '../theme/app_tokens.dart';
import '../ui/brand_logo.dart';

/// Navigation sidebar (RestroBit style): logo, a profile card, module nav
/// grouped into labelled sections, and a sign-out row. Used as a fixed rail on
/// wide layouts and inside the drawer on narrow ones.
class AppSidebar extends ConsumerWidget {
  const AppSidebar({
    super.key,
    required this.selected,
    required this.onSelect,
  });

  /// -1 = Dashboard/Home; otherwise index into visible modules.
  final int selected;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final access = ref.watch(accessProvider);
    final modules = access.visibleModules();
    final company = ref.watch(currentCompanyProvider);
    final profile = ref.watch(currentProfileProvider);
    final scheme = Theme.of(context).colorScheme;

    // Group visible modules by their section label, preserving order.
    final groups = <String, List<(int, ModuleManifest)>>{};
    for (var i = 0; i < modules.length; i++) {
      groups.putIfAbsent(modules[i].group, () => []).add((i, modules[i]));
    }

    final navChildren = <Widget>[
      _SectionLabel('Menu'),
      _NavItem(
        icon: Icons.grid_view_rounded,
        label: 'Dashboard',
        selected: selected == -1,
        onTap: () => onSelect(-1),
      ),
      // 'Menu' group modules (Inventory/POS/Sales) right under Dashboard.
      for (final entry in groups['Menu'] ?? const [])
        _NavItem(
          icon: entry.$2.icon,
          label: entry.$2.name,
          selected: selected == entry.$1,
          locked: access.isLocked(entry.$2),
          onTap: () => onSelect(entry.$1),
        ),
      // Remaining sections.
      for (final section in groups.keys.where((g) => g != 'Menu')) ...[
        _SectionLabel(section),
        for (final entry in groups[section]!)
          _NavItem(
            icon: entry.$2.icon,
            label: entry.$2.name,
            selected: selected == entry.$1,
            locked: access.isLocked(entry.$2),
            onTap: () => onSelect(entry.$1),
          ),
      ],
    ];

    return Container(
      width: 268,
      decoration: BoxDecoration(
        color: scheme.surface,
        border: Border(right: BorderSide(color: scheme.outline)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 22, 20, 16),
            child: const BrandLogo(size: 34),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
            child: _ProfileCard(
              name: profile.displayName ?? profile.email,
              role: profile.role.name,
            ),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
              children: navChildren,
            ),
          ),
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.all(10),
            child: _NavItem(
              icon: Icons.logout,
              label: 'Sign out',
              selected: false,
              onTap: () => ref.read(authRepositoryProvider).signOut(),
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(bottom: 10, left: 26),
            child: Text(company.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                    fontSize: 11.5, color: scheme.onSurfaceVariant)),
          ),
        ],
      ),
    );
  }
}

class _ProfileCard extends StatelessWidget {
  const _ProfileCard({required this.name, required this.role});
  final String name;
  final String role;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final initial = name.isNotEmpty ? name[0].toUpperCase() : '?';
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: scheme.outline),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              gradient: AppColors.brandGradient,
              borderRadius: BorderRadius.circular(10),
            ),
            alignment: Alignment.center,
            child: Text(initial,
                style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 16)),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontSize: 14, fontWeight: FontWeight.w700)),
                Text(role,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        fontSize: 12, color: scheme.onSurfaceVariant)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.label);
  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 14, 12, 8),
      child: Text(label.toUpperCase(),
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.1,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          )),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
    this.locked = false,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final bool locked;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final fg = selected
        ? scheme.primary
        : locked
            ? scheme.onSurfaceVariant.withValues(alpha: 0.7)
            : scheme.onSurface;
    return Padding(
      padding: const EdgeInsets.only(bottom: 3),
      child: Material(
        color:
            selected ? scheme.primary.withValues(alpha: 0.10) : Colors.transparent,
        borderRadius: AppRadius.field,
        child: InkWell(
          onTap: onTap,
          borderRadius: AppRadius.field,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
            child: Row(
              children: [
                Icon(locked ? Icons.lock_outline : icon, size: 20, color: fg),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(label,
                      style: TextStyle(
                        fontSize: 14.5,
                        fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                        color: fg,
                      )),
                ),
                if (selected && !locked)
                  Container(
                    width: 6,
                    height: 6,
                    decoration: BoxDecoration(
                        color: scheme.primary, shape: BoxShape.circle),
                  ),
                if (locked)
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: scheme.tertiary.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text('PRO',
                        style: TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.w800,
                            color: scheme.tertiary)),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
