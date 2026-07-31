import 'app_user.dart';

/// Contract for authentication. The app depends on THIS, never on Firebase
/// directly. To move off Firebase later, write a new implementation
/// (e.g. ApiAuthRepository) and swap the provider — no other code changes.
abstract interface class AuthRepository {
  /// Emits the current user (or [AppUser.empty] when signed out) and every
  /// change afterwards.
  Stream<AppUser> authStateChanges();

  /// The current user synchronously, or [AppUser.empty] if signed out.
  AppUser get currentUser;

  Future<void> signInWithEmail({
    required String email,
    required String password,
  });

  Future<void> registerWithEmail({
    required String email,
    required String password,
    String? displayName,
  });

  Future<void> sendPasswordReset(String email);

  Future<void> signOut();
}

/// Thrown by [AuthRepository] implementations with a user-friendly message.
class AuthException implements Exception {
  const AuthException(this.message);
  final String message;
  @override
  String toString() => message;
}
