import '../../profile/domain/user_profile.dart';
import 'company.dart';

/// Contract for reading/writing tenants and memberships. As with auth, the app
/// depends on this interface, not on Firestore.
abstract interface class CompanyRepository {
  /// Streams the profile at `users/{uid}` (or [UserProfile.empty] if none yet).
  Stream<UserProfile> watchProfile(String uid);

  /// Streams a company document.
  Stream<Company> watchCompany(String companyId);

  /// Creates a brand-new company and makes [ownerUid] its Owner. Returns the
  /// new company id. Used during first-time onboarding after registration.
  Future<String> createCompanyWithOwner({
    required String ownerUid,
    required String ownerEmail,
    required String companyName,
    String? ownerDisplayName,
  });

  /// Persists module on/off overrides for a company.
  Future<void> setModuleEnabled({
    required String companyId,
    required String moduleId,
    required bool enabled,
  });

  /// Persists a feature flag for a company.
  Future<void> setFeatureEnabled({
    required String companyId,
    required String featureKey,
    required bool enabled,
  });
}
