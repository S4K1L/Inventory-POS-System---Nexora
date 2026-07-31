import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'data/firebase_auth_repository.dart';
import 'domain/app_user.dart';
import 'domain/auth_repository.dart';

/// The single seam for swapping auth backends.
///
/// Today it returns [FirebaseAuthRepository]. When you build the custom
/// backend, override this provider to return an ApiAuthRepository and the rest
/// of the app is unaffected.
final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return FirebaseAuthRepository(FirebaseAuth.instance);
});

/// Streams the current user; [AppUser.empty] when signed out.
final authStateProvider = StreamProvider<AppUser>((ref) {
  return ref.watch(authRepositoryProvider).authStateChanges();
});

/// Convenience: the current user or [AppUser.empty] while loading.
final currentUserProvider = Provider<AppUser>((ref) {
  return ref.watch(authStateProvider).value ?? AppUser.empty;
});
