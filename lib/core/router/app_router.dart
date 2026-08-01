import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../auth/auth_providers.dart';
import '../auth/ui/account_status_screen.dart';
import '../auth/ui/login_screen.dart';
import '../auth/ui/onboarding_screen.dart';
import '../auth/ui/register_screen.dart';
import '../company/company_providers.dart';
import '../platform/platform_admin.dart';
import '../shell/home_shell.dart';
import '../shell/splash_screen.dart';
import '../../modules/admin/ui/admin_dashboard_screen.dart';

/// Central router. Redirects are driven by auth state, then the profile
/// (company assigned?), then the company's subscription (approved + active?),
/// with a super-admin route for the platform operator.
final routerProvider = Provider<GoRouter>((ref) {
  final authState = ref.watch(authStateProvider);
  final profileState = ref.watch(profileProvider);
  final companyState = ref.watch(companyProvider);
  final isAdmin = ref.watch(isPlatformAdminProvider);

  return GoRouter(
    initialLocation: '/',
    redirect: (context, state) {
      final loc = state.matchedLocation;
      final onAuthPage = loc == '/login' || loc == '/register';

      if (authState.isLoading || authState.hasError) {
        return loc == '/splash' ? null : '/splash';
      }

      final signedIn = authState.value?.isNotEmpty ?? false;
      if (!signedIn) {
        return onAuthPage ? null : '/login';
      }

      // Signed in — resolve the profile.
      if (profileState.isLoading) return loc == '/splash' ? null : '/splash';
      final hasCompany = profileState.value?.hasCompany ?? false;

      // A platform admin with no tenant is a pure operator: land on /admin,
      // never the store app or onboarding.
      if (!hasCompany && isAdmin) {
        return loc == '/admin' ? null : '/admin';
      }
      if (!hasCompany) return loc == '/onboarding' ? null : '/onboarding';

      // The platform admin can always reach the admin dashboard.
      if (loc == '/admin') return isAdmin ? null : '/';

      // Resolve the company + its subscription state.
      if (companyState.isLoading) return loc == '/splash' ? null : '/splash';
      final company = companyState.value;
      final active = company?.isActive ?? false;
      if (!active) {
        return loc == '/account-status' ? null : '/account-status';
      }

      // Fully set up and active.
      if (loc == '/splash' ||
          onAuthPage ||
          loc == '/onboarding' ||
          loc == '/account-status') {
        return '/';
      }
      return null;
    },
    routes: [
      GoRoute(path: '/splash', builder: (context, state) => const SplashScreen()),
      GoRoute(path: '/login', builder: (context, state) => const LoginScreen()),
      GoRoute(path: '/register', builder: (context, state) => const RegisterScreen()),
      GoRoute(path: '/onboarding', builder: (context, state) => const OnboardingScreen()),
      GoRoute(path: '/account-status', builder: (context, state) => const AccountStatusScreen()),
      GoRoute(path: '/admin', builder: (context, state) => const AdminDashboardScreen()),
      GoRoute(path: '/', builder: (context, state) => const HomeShell()),
    ],
    errorBuilder: (context, state) => Scaffold(
      body: Center(child: Text('Route not found: ${state.uri}')),
    ),
  );
});
