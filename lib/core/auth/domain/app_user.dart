/// A signed-in user, independent of any auth backend.
///
/// Deliberately framework-agnostic: nothing here mentions Firebase, so the
/// same model works when you swap to a custom backend later.
class AppUser {
  const AppUser({
    required this.uid,
    required this.email,
    this.displayName,
  });

  final String uid;
  final String email;
  final String? displayName;

  static const empty = AppUser(uid: '', email: '');

  bool get isEmpty => uid.isEmpty;
  bool get isNotEmpty => uid.isNotEmpty;
}
