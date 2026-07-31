import 'package:cloud_firestore/cloud_firestore.dart';

import '../../profile/domain/user_profile.dart';
import '../domain/company.dart';
import '../domain/company_repository.dart';

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
    final company = Company(id: companyRef.id, name: companyName);
    final profile = UserProfile(
      uid: ownerUid,
      email: ownerEmail,
      companyId: companyRef.id,
      roleId: 'owner',
      displayName: ownerDisplayName,
    );

    // Create both atomically so a user is never left without a company.
    final batch = _db.batch();
    batch.set(companyRef, company.toMap());
    batch.set(_users.doc(ownerUid), profile.toMap());
    await batch.commit();

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
}
