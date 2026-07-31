import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../modules/module.dart';
import '../theme/app_tokens.dart';
import 'access.dart';

/// Renders [child] only if the user has [permission]; otherwise [fallback].
class PermissionGate extends ConsumerWidget {
  const PermissionGate({
    super.key,
    required this.permission,
    required this.child,
    this.fallback = const SizedBox.shrink(),
  });

  final String permission;
  final Widget child;
  final Widget fallback;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ref.watch(accessProvider).can(permission) ? child : fallback;
  }
}

/// Renders [child] only if [featureKey] is enabled for the company.
class FeatureGate extends ConsumerWidget {
  const FeatureGate({
    super.key,
    required this.featureKey,
    required this.child,
    this.fallback = const SizedBox.shrink(),
    this.defaultValue = false,
  });

  final String featureKey;
  final Widget child;
  final Widget fallback;
  final bool defaultValue;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final on = ref
        .watch(accessProvider)
        .feature(featureKey, defaultValue: defaultValue);
    return on ? child : fallback;
  }
}

/// Guards a whole module body. Shows [child] if enabled + permitted; an upgrade
/// prompt for locked premium modules; a "no access" state otherwise. Returns
/// body content only (the shell supplies the frame).
class ModuleGate extends ConsumerWidget {
  const ModuleGate({super.key, required this.module, required this.child});

  final ModuleManifest module;
  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final access = ref.watch(accessProvider);
    if (access.canOpen(module)) return child;
    if (access.isLocked(module)) {
      return _CenteredState(
        icon: Icons.workspace_premium_outlined,
        color: Theme.of(context).colorScheme.tertiary,
        title: '${module.name} is a Pro feature',
        message:
            'This module isn’t part of your current plan. Upgrade to unlock it.',
        actionLabel: 'Upgrade plan',
        onAction: () {},
      );
    }
    return _CenteredState(
      icon: Icons.lock_outline,
      color: Theme.of(context).colorScheme.onSurfaceVariant,
      title: 'No access',
      message: "You don't have permission to view ${module.name}.",
    );
  }
}

class _CenteredState extends StatelessWidget {
  const _CenteredState({
    required this.icon,
    required this.color,
    required this.title,
    required this.message,
    this.actionLabel,
    this.onAction,
  });

  final IconData icon;
  final Color color;
  final String title;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 360),
        child: Padding(
          padding: const EdgeInsets.all(AppSpace.xl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(AppRadius.xl),
                ),
                child: Icon(icon, size: 34, color: color),
              ),
              const SizedBox(height: AppSpace.lg),
              Text(title, textAlign: TextAlign.center, style: text.titleLarge),
              const SizedBox(height: 6),
              Text(message,
                  textAlign: TextAlign.center, style: text.bodyMedium),
              if (actionLabel != null) ...[
                const SizedBox(height: AppSpace.xl),
                FilledButton.icon(
                  onPressed: onAction,
                  icon: const Icon(Icons.workspace_premium_outlined, size: 18),
                  label: Text(actionLabel!),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
