import 'package:flutter/material.dart';

import '../modules/module.dart';
import '../theme/app_tokens.dart';

/// Temporary body for modules that aren't built yet.
class ModulePlaceholder extends StatelessWidget {
  const ModulePlaceholder({super.key, required this.module});
  final ModuleManifest module;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 84,
            height: 84,
            decoration: BoxDecoration(
              color: scheme.primary.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(AppRadius.xl),
            ),
            child: Icon(module.icon, size: 40, color: scheme.primary),
          ),
          const SizedBox(height: AppSpace.lg),
          Text('${module.name} module', style: text.titleLarge),
          const SizedBox(height: 4),
          Text('Coming soon — this module is enabled and ready to build.',
              style: text.bodyMedium),
        ],
      ),
    );
  }
}
