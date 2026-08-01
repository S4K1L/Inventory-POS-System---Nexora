import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../auth/auth_providers.dart';

/// Platform super-admins (the SaaS operator). Identified by email allowlist —
/// the pragmatic bootstrap for a solo operator. For production hardening,
/// switch to Firebase custom claims and mirror this list in firestore.rules.
///
/// EDIT THIS to add/remove platform admins.
const kPlatformAdminEmails = <String>{
  'admin@nexora.net',
  'codewithshakil@gmail.com',
};

bool isPlatformAdminEmail(String email) =>
    kPlatformAdminEmails.contains(email.trim().toLowerCase());

/// True when the signed-in user is a platform super-admin.
final isPlatformAdminProvider = Provider<bool>((ref) {
  final user = ref.watch(currentUserProvider);
  return user.isNotEmpty && isPlatformAdminEmail(user.email);
});
