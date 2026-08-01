import 'package:cloud_firestore/cloud_firestore.dart';

import '../../profile/domain/user_profile.dart';
import '../domain/company.dart';
import '../domain/company_repository.dart';
import '../domain/plan.dart';

/// Firestore implementation. The only file that knows the collection layout.
///
/// Layout:
///   users/{uid}       -> UserProfile
///   companies/{id}    -> Company (with `modules` and `features` maps)
class FirestoreCompanyRepository implements CompanyRepository {
  FirestoreCompanyRepository(this._db);

  final FirebaseFirestore _db;

  CollectionReference<Map<String, dynamic>> get _users =>
      _db.collection('users');
  CollectionReference<Map<String, dynamic>> get _companies =>
      _db.collection('companies');

  @override
  Stream<UserProfile> watchProfile(String uid) {
    return _users.doc(uid).snapshots().map((doc) {
      final data = doc.data();
      if (!doc.exists || data == null) return UserProfile.empty;
      return UserProfile.fromMap(uid, data);
    });
  }

  @override
  Stream<Company> watchCompany(String companyId) {
    if (companyId.isEmpty) return Stream.value(Company.empty);
    return _companies.doc(companyId).snapshots().map((doc) {
      final data = doc.data();
      if (!doc.exists || data == null) return Company.empty;
      return Company.fromMap(companyId, data);
    });
  }

  @override
  Future<String> createCompanyWithOwner({
    required String ownerUid,
    required String ownerEmail,
    required String companyName,
    String? ownerDisplayName,
  }) async {
    final companyRef = _companies.doc();
    final company = Company(
      id: companyRef.id,
      name: companyName,
      status: CompanyStatus.pending, // awaits platform-admin approval
      ownerEmail: ownerEmail,
      createdAt: DateTime.now(),
    );
    final profile = UserProfile(
      uid: ownerUid,
      email: ownerEmail,
      companyId: companyRef.id,
      roleId: 'owner',
      displayName: ownerDisplayName,
    );

    // Step 1: company + owner profile together. (A branch can't go in this
    // batch — the branch security rule reads the owner's profile via get(),
    // which isn't committed yet, so it would be denied.)
    final batch = _db.batch();
    batch.set(companyRef, company.toMap());
    batch.set(_users.doc(ownerUid), profile.toMap());
    await batch.commit();

    // Step 2: the default branch. Now that the profile exists, the branch write
    // is permitted. Non-fatal if it fails — the account is already created and
    // a branch can be added later.
    try {
      await companyRef
          .collection('branches')
          .add({'name': 'Main Branch', 'active': true});
    } catch (_) {
      // Ignore — onboarding still succeeded.
    }

    return companyRef.id;
  }

  @override
  Future<void> setModuleEnabled({
    required String companyId,
    required String moduleId,
    required bool enabled,
  }) {
    return _companies.doc(companyId).set({
      'modules': {moduleId: enabled},
    }, SetOptions(merge: true));
  }

  @override
  Future<void> setFeatureEnabled({
    required String companyId,
    required String featureKey,
    required bool enabled,
  }) {
    return _companies.doc(companyId).set({
      'features': {featureKey: enabled},
    }, SetOptions(merge: true));
  }

  @override
  Stream<List<UserProfile>> watchEmployees(String companyId) {
    if (companyId.isEmpty) return Stream.value(const []);
    return _users
        .where('companyId', isEqualTo: companyId)
        .snapshots()
        .map((snap) => snap.docs
            .map((d) => UserProfile.fromMap(d.id, d.data()))
            .toList());
  }

  @override
  Future<void> addEmployee({
    required String companyId,
    required String uid,
    required String email,
    required String roleId,
    String branchId = '',
    String? displayName,
  }) {
    final profile = UserProfile(
      uid: uid,
      email: email,
      companyId: companyId,
      roleId: roleId,
      branchId: branchId,
      displayName: displayName,
    );
    return _users.doc(uid).set(profile.toMap());
  }

  @override
  Future<void> updateEmployeeRole({
    required String uid,
    required String roleId,
  }) {
    return _users.doc(uid).update({'roleId': roleId});
  }

  @override
  Future<void> setEmployeeActive({
    required String uid,
    required bool active,
  }) {
    return _users.doc(uid).update({'active': active});
  }

  @override
  Stream<List<Company>> watchAllCompanies() {
    return _companies.snapshots().map((snap) {
      final list =
          snap.docs.map((d) => Company.fromMap(d.id, d.data())).toList();
      // Pending first, then by name.
      list.sort((a, b) {
        final aPending = a.status == CompanyStatus.pending;
        final bPending = b.status == CompanyStatus.pending;
        if (aPending != bPending) return aPending ? -1 : 1;
        return a.name.compareTo(b.name);
      });
      return list;
    });
  }

  @override
  Future<void> adminUpdateSubscription({
    required String companyId,
    required CompanyStatus status,
    required PlanTier plan,
    DateTime? planExpiresAt,
  }) {
    return _companies.doc(companyId).set({
      'status': status.id,
      'plan': plan.id,
      'planExpiresAt': planExpiresAt?.toIso8601String(),
    }, SetOptions(merge: true));
  }
}
