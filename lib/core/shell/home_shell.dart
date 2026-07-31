import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../access/access.dart';
import '../access/gates.dart';
import '../company/company_providers.dart';
import '../modules/module.dart';
import '../theme/app_tokens.dart';
import '../theme/theme_mode_provider.dart';
import '../../modules/dashboard/dashboard_screen.dart';
import 'app_sidebar.dart';
import 'module_screens.dart';

/// Main app frame after sign-in: a fixed sidebar on wide screens, a drawer on
/// narrow ones, and a clean top bar over the active module's body.
class HomeShell extends ConsumerStatefulWidget {
  const HomeShell({super.key});

  @override
  ConsumerState<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends ConsumerState<HomeShell> {
  int _selected = -1; // -1 = Dashboard
  final _scaffoldKey = GlobalKey<ScaffoldState>();

  @override
  Widget build(BuildContext context) {
    final access = ref.watch(accessProvider);
    final modules = access.visibleModules();
    final wide = MediaQuery.sizeOf(context).width >= 900;

    final module =
        (_selected >= 0 && _selected < modules.length) ? modules[_selected] : null;
    final title = module?.name ?? 'Dashboard';
    final subtitle = module == null
        ? "Here's how your business is doing"
        : _subtitleFor(module);

    final body = module == null
        ? const DashboardScreen()
        : ModuleGate(module: module, child: screenForModule(module));

    void select(int i) {
      setState(() => _selected = i);
      if (!wide) Navigator.of(context).maybePop();
    }

    return Scaffold(
      key: _scaffoldKey,
      drawer: wide
          ? null
          : Drawer(
              width: 264,
              child: AppSidebar(selected: _selected, onSelect: select),
            ),
      body: SafeArea(
        child: Row(
          children: [
            if (wide) AppSidebar(selected: _selected, onSelect: select),
            Expanded(
              child: Column(
                children: [
                  _TopBar(
                    title: title,
                    subtitle: subtitle,
                    showMenu: !wide,
                    onMenu: () => _scaffoldKey.currentState?.openDrawer(),
                  ),
                  const Divider(height: 1),
                  Expanded(child: body),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _subtitleFor(ModuleManifest m) {
    switch (m.id) {
      case ModuleId.inventory:
        return 'Manage products, stock and categories';
      case ModuleId.pos:
        return 'Ring up sales quickly';
      default:
        return 'Nexora · ${m.name}';
    }
  }
}

class _TopBar extends ConsumerWidget {
  const _TopBar({
    required this.title,
    required this.subtitle,
    required this.showMenu,
    required this.onMenu,
  });

  final String title;
  final String subtitle;
  final bool showMenu;
  final VoidCallback onMenu;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final compact = MediaQuery.sizeOf(context).width < 720;
    final isDark = ref.watch(themeModeProvider) == ThemeMode.dark;
    final profile = ref.watch(currentProfileProvider);
    final name = profile.displayName ?? profile.email;

    return Container(
      height: 74,
      color: scheme.surface,
      padding: const EdgeInsets.symmetric(horizontal: AppSpace.lg),
      child: Row(
        children: [
          if (showMenu)
            IconButton(icon: const Icon(Icons.menu), onPressed: onMenu),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: text.titleLarge),
                Text(subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: text.bodySmall),
              ],
            ),
          ),
          if (!compact) ...[
            _SearchBox(),
            const SizedBox(width: 10),
          ],
          _RoundIconButton(
            icon: isDark ? Icons.dark_mode_outlined : Icons.light_mode_outlined,
            onTap: () => ref.read(themeModeProvider.notifier).toggle(),
          ),
          const SizedBox(width: 10),
          _RoundIconButton(
            icon: Icons.notifications_none_rounded,
            onTap: () {},
            badge: true,
          ),
          const SizedBox(width: 10),
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              gradient: AppColors.brandGradient,
              borderRadius: BorderRadius.circular(AppRadius.md),
            ),
            alignment: Alignment.center,
            child: Text(
              name.isNotEmpty ? name[0].toUpperCase() : '?',
              style: const TextStyle(
                  color: Colors.white, fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }
}

class _SearchBox extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      width: 240,
      height: 42,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest,
        borderRadius: AppRadius.field,
        border: Border.all(color: scheme.outline),
      ),
      child: Row(
        children: [
          Icon(Icons.search, size: 18, color: scheme.onSurfaceVariant),
          const SizedBox(width: 8),
          Expanded(
            child: TextField(
              decoration: InputDecoration(
                isCollapsed: true,
                border: InputBorder.none,
                hintText: 'Search…',
                hintStyle:
                    TextStyle(color: scheme.onSurfaceVariant, fontSize: 14),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _RoundIconButton extends StatelessWidget {
  const _RoundIconButton({
    required this.icon,
    required this.onTap,
    this.badge = false,
  });

  final IconData icon;
  final VoidCallback onTap;
  final bool badge;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Stack(
      children: [
        Container(
          decoration: BoxDecoration(
            color: scheme.surfaceContainerHighest,
            borderRadius: AppRadius.field,
            border: Border.all(color: scheme.outline),
          ),
          child: IconButton(icon: Icon(icon, size: 20), onPressed: onTap),
        ),
        if (badge)
          Positioned(
            right: 8,
            top: 8,
            child: Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                color: scheme.error,
                shape: BoxShape.circle,
                border: Border.all(color: scheme.surface, width: 1.5),
              ),
            ),
          ),
      ],
    );
  }
}
