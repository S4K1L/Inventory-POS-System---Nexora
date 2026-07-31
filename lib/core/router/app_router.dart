import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../auth/auth_providers.dart';
import '../auth/ui/login_screen.dart';
import '../auth/ui/onboarding_screen.dart';
import '../auth/ui/register_screen.dart';
import '../company/company_providers.dart';
import '../shell/home_shell.dart';
import '../shell/splash_screen.dart';

/// Central router. Redirects are driven by two signals:
///   - auth state:  loading -> splash, signed out -> /login
///   - profile:     signed in but no company yet -> /onboarding, else -> app
final routerProvider = Provider<GoRouter>((ref) {
  // Watch both so the redirect re-runs when either resolves.
  final authState = ref.watch(authStateProvider);
  final profileState = ref.watch(profileProvider);

  return GoRouter(
    initialLocation: '/',
    redirect: (context, state) {
      final loc = state.matchedLocation;
      final onAuthPage = loc == '/login' || loc == '/register';

      // Auth status not resolved yet.
      if (authState.isLoading || authState.hasError) {
        return loc == '/splash' ? null : '/splash';
      }

      final signedIn = authState.value?.isNotEmpty ?? false;
      if (!signedIn) {
        return onAuthPage ? null : '/login';
      }

      // Signed in — wait for the profile to load before deciding onboarding.
      if (profileState.isLoading) {
        return loc == '/splash' ? null : '/splash';
      }

      final hasCompany = profileState.value?.hasCompany ?? false;
      if (!hasCompany) {
        return loc == '/onboarding' ? null : '/onboarding';
      }

      // Fully set up — bounce away from auth/splash/onboarding into the app.
      if (loc == '/splash' || onAuthPage || loc == '/onboarding') return '/';
      return null;
    },
    routes: [
      GoRoute(path: '/splash', builder: (context, state) => const SplashScreen()),
      GoRoute(path: '/login', builder: (context, state) => const LoginScreen()),
      GoRoute(path: '/register', builder: (context, state) => const RegisterScreen()),
      GoRoute(path: '/onboarding', builder: (context, state) => const OnboardingScreen()),
      GoRoute(path: '/', builder: (context, state) => const HomeShell()),
    ],
    errorBuilder: (context, state) => Scaffold(
      body: Center(child: Text('Route not found: ${state.uri}')),
    ),
  );
});
