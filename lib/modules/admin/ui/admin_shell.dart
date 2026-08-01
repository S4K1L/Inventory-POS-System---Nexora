import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/auth/auth_providers.dart';
import '../../../core/company/company_providers.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/ui/brand_logo.dart';
import '../admin_providers.dart';
import 'sections/approvals_section.dart';
import 'sections/companies_section.dart';
import 'sections/overview_section.dart';
import 'sections/settings_section.dart';

class _AdminNav {
  const _AdminNav(this.label, this.icon, this.builder);
  final String label;
  final IconData icon;
  final Widget Function() builder;
}

/// The platform super-admin control center: a multi-section app for running
/// the whole Nexora SaaS.
class AdminShell extends ConsumerStatefulWidget {
  const AdminShell({super.key});

  @override
  ConsumerState<AdminShell> createState() => _AdminShellState();
}

class _AdminShellState extends ConsumerState<AdminShell> {
  int _index = 0;
  final _scaffoldKey = GlobalKey<ScaffoldState>();

  static final _sections = <_AdminNav>[
    _AdminNav('Overview', Icons.grid_view_rounded, () => const OverviewSection()),
    _AdminNav('Companies', Icons.business_outlined, () => const CompaniesSection()),
    _AdminNav('Approvals', Icons.hourglass_top_outlined, () => const ApprovalsSection()),
    _AdminNav('Settings', Icons.settings_outlined, () => const SettingsSection()),
  ];

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.sizeOf(context).width >= 900;
    final scheme = Theme.of(context).colorScheme;

    void select(int i) {
      setState(() => _index = i);
      if (!wide) Navigator.of(context).maybePop();
    }

    return Scaffold(
      key: _scaffoldKey,
      drawer: wide ? null : Drawer(width: 250, child: _sidebar(select)),
      body: SafeArea(
        child: Row(
          children: [
            if (wide) _sidebar(select),
            Expanded(
              child: Column(
                children: [
                  Container(
                    height: 66,
                    padding:
                        const EdgeInsets.symmetric(horizontal: AppSpace.lg),
                    color: scheme.surface,
                    child: Row(
                      children: [
                        if (!wide)
                          IconButton(
                            icon: const Icon(Icons.menu),
                            onPressed: () =>
                                _scaffoldKey.currentState?.openDrawer(),
                          ),
                        Text(_sections[_index].label,
                            style: Theme.of(context).textTheme.titleLarge),
                      ],
                    ),
                  ),
                  const Divider(height: 1),
                  Expanded(child: _sections[_index].builder()),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _sidebar(ValueChanged<int> onSelect) {
    final scheme = Theme.of(context).colorScheme;
    final pending = ref.watch(adminStatsProvider).pending;
    final hasCompany = ref.watch(currentProfileProvider).hasCompany;

    return Container(
      width: 250,
      decoration: BoxDecoration(
        color: scheme.surface,
        border: Border(right: BorderSide(color: scheme.outline)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 22, 20, 8),
            child: Row(
              children: [
                const BrandLogo(size: 30, showWordmark: false),
                const SizedBox(width: 10),
                const Text('Nexora',
                    style: TextStyle(
                        fontSize: 18, fontWeight: FontWeight.w800)),
                const SizedBox(width: 8),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                  decoration: BoxDecoration(
                    color: scheme.primary.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(AppRadius.sm),
                  ),
                  child: Text('ADMIN',
                      style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          color: scheme.primary)),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              children: [
                for (var i = 0; i < _sections.length; i++)
                  _NavItem(
                    icon: _sections[i].icon,
                    label: _sections[i].label,
                    selected: _index == i,
                    badge: _sections[i].label == 'Approvals' && pending > 0
                        ? '$pending'
                        : null,
                    onTap: () => onSelect(i),
                  ),
              ],
            ),
          ),
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.all(10),
            child: hasCompany
                ? _NavItem(
                    icon: Icons.arrow_back,
                    label: 'Back to app',
                    selected: false,
                    onTap: () => context.go('/'),
                  )
                : _NavItem(
                    icon: Icons.logout,
                    label: 'Sign out',
                    selected: false,
                    onTap: () => ref.read(authRepositoryProvider).signOut(),
                  ),
          ),
        ],
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
    this.badge,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;
  final String? badge;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final fg = selected ? scheme.primary : scheme.onSurface;
    return Padding(
      padding: const EdgeInsets.only(bottom: 3),
      child: Material(
        color: selected
            ? scheme.primary.withValues(alpha: 0.10)
            : Colors.transparent,
        borderRadius: AppRadius.field,
        child: InkWell(
          onTap: onTap,
          borderRadius: AppRadius.field,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
            child: Row(
              children: [
                Icon(icon, size: 20, color: fg),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(label,
                      style: TextStyle(
                        fontSize: 14.5,
                        fontWeight:
                            selected ? FontWeight.w700 : FontWeight.w500,
                        color: fg,
                      )),
                ),
                if (badge != null)
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppColors.warning,
                      borderRadius: BorderRadius.circular(AppRadius.pill),
                    ),
                    child: Text(badge!,
                        style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            color: Colors.white)),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
