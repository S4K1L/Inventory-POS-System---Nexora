import '../../permissions/permissions.dart';

/// Application-level user record, stored at `users/{uid}` in Firestore.
///
/// This is separate from [AppUser] (which is auth-only: uid + email). The
/// profile is what ties a signed-in user to a company and a role.
class UserProfile {
  const UserProfile({
    required this.uid,
    required this.email,
    required this.companyId,
    required this.roleId,
    this.displayName,
    this.active = true,
  });

  final String uid;
  final String email;
  final String companyId;

  /// Built-in role id (see [Roles]) or a company-defined custom role id.
  final String roleId;

  final String? displayName;
  final bool active;

  static const empty = UserProfile(
    uid: '',
    email: '',
    companyId: '',
    roleId: 'cashier',
  );

  bool get isEmpty => uid.isEmpty;
  bool get hasCompany => companyId.isNotEmpty;

  /// Resolves the built-in role. (Custom roles from Firestore can be layered on
  /// later without changing callers.)
  Role get role => Roles.byId(roleId);

  bool can(String permission) => role.can(permission);

  factory UserProfile.fromMap(String uid, Map<String, dynamic> data) {
    return UserProfile(
      uid: uid,
      email: (data['email'] ?? '') as String,
      companyId: (data['companyId'] ?? '') as String,
      roleId: (data['roleId'] ?? 'cashier') as String,
      displayName: data['displayName'] as String?,
      active: data['active'] != false,
    );
  }

  Map<String, dynamic> toMap() => {
        'email': email,
        'companyId': companyId,
        'roleId': roleId,
        'displayName': displayName,
        'active': active,
      };
}
