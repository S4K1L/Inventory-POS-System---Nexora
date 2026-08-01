import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../company/company_providers.dart';
import '../../company/domain/company.dart';
import '../../platform/platform_admin.dart';
import '../../theme/app_tokens.dart';
import '../../ui/brand_logo.dart';
import '../auth_providers.dart';

/// Shown when a signed-in user's company isn't active — pending approval,
/// suspended, or its plan has expired. Blocks the app until resolved.
class AccountStatusScreen extends ConsumerWidget {
  const AccountStatusScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final company = ref.watch(currentCompanyProvider);
    final isAdmin = ref.watch(isPlatformAdminProvider);
    final theme = Theme.of(context);

    final (icon, color, title, message) = _state(company);

    return Scaffold(
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 440),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(AppSpace.xl),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const BrandLogo(size: 46),
                const SizedBox(height: AppSpace.xxl),
                Container(
                  width: 84,
                  height: 84,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(AppRadius.xl),
                  ),
                  child: Icon(icon, size: 40, color: color),
                ),
                const SizedBox(height: AppSpace.lg),
                Text(title,
                    textAlign: TextAlign.center, style: theme.textTheme.headlineSmall),
                const SizedBox(height: 8),
                Text(message,
                    textAlign: TextAlign.center, style: theme.textTheme.bodyMedium),
                const SizedBox(height: AppSpace.xl),
                if (isAdmin) ...[
                  FilledButton.icon(
                    onPressed: () => context.go('/admin'),
                    icon: const Icon(Icons.admin_panel_settings_outlined),
                    label: const Text('Open admin dashboard'),
                  ),
                  const SizedBox(height: 8),
                ],
                OutlinedButton(
                  onPressed: () => ref.read(authRepositoryProvider).signOut(),
                  child: const Text('Sign out'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  (IconData, Color, String, String) _state(Company company) {
    if (company.status == CompanyStatus.suspended) {
      return (
        Icons.pause_circle_outline,
        AppColors.danger,
        'Account suspended',
        'Your account has been suspended. Please contact support to restore access.'
      );
    }
    if (company.isExpired) {
      return (
        Icons.timer_off_outlined,
        AppColors.warning,
        'Subscription expired',
        'Your ${company.plan.label} plan has ended. Renew to continue using Nexora.'
      );
    }
    // Pending.
    return (
      Icons.hourglass_top_outlined,
      AppColors.brand,
      'Waiting for approval',
      'Your account has been created and is awaiting admin approval. '
          "You'll get access as soon as it's approved."
    );
  }
}
