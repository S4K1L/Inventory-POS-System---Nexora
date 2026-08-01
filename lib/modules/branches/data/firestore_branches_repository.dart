import 'package:cloud_firestore/cloud_firestore.dart';

import '../domain/branch.dart';
import '../domain/branches_repository.dart';

/// Firestore implementation. Data at `companies/{cid}/branches/{id}`.
class FirestoreBranchesRepository implements BranchesRepository {
  FirestoreBranchesRepository(this._db);

  final FirebaseFirestore _db;

  CollectionReference<Map<String, dynamic>> _col(String cid) =>
      _db.collection('companies').doc(cid).collection('branches');

  @override
  Stream<List<Branch>> watchBranches(String companyId) {
    return _col(companyId).orderBy('name').snapshots().map(
        (s) => s.docs.map((d) => Branch.fromMap(d.id, d.data())).toList());
  }

  @override
  Future<String> createBranch(String companyId, Branch branch) async {
    final ref = _col(companyId).doc();
    await ref.set(branch.toMap());
    return ref.id;
  }

  @override
  Future<void> updateBranch(String companyId, Branch branch) {
    return _col(companyId).doc(branch.id).update(branch.toMap());
  }

  @override
  Future<void> setBranchActive(
      String companyId, String branchId, bool active) {
    return _col(companyId).doc(branchId).update({'active': active});
  }
}
