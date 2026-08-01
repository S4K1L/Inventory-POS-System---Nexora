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
import '../../modules/admin/ui/admin_shell.dart';

/// Central router. The [GoRouter] is created ONCE and re-evaluates its redirect
/// via a [refreshListenable] whenever auth/profile/company change — so the app
/// doesn't rebuild the whole router (and re-navigate) on every stream emission.
final routerProvider = Provider<GoRouter>((ref) {
  final refresh = ValueNotifier<int>(0);
  void bump(Object? prev, Object? next) => refresh.value++;
  // Re-run the redirect when any of these change, without rebuilding the router.
  ref.listen(authStateProvider, bump);
  ref.listen(profileProvider, bump);
  ref.listen(companyProvider, bump);
  ref.onDispose(refresh.dispose);

  return GoRouter(
    initialLocation: '/',
    refreshListenable: refresh,
    redirect: (context, state) {
      final authState = ref.read(authStateProvider);
      final profileState = ref.read(profileProvider);
      final companyState = ref.read(companyProvider);
      final isAdmin = ref.read(isPlatformAdminProvider);

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

      // A platform admin with no tenant is a pure operator: land on /admin.
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
      GoRoute(path: '/admin', builder: (context, state) => const AdminShell()),
      GoRoute(path: '/', builder: (context, state) => const HomeShell()),
    ],
    errorBuilder: (context, state) => Scaffold(
      body: Center(child: Text('Route not found: ${state.uri}')),
    ),
  );
});
