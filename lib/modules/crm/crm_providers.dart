import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/company/company_providers.dart';
import 'domain/deal.dart';

/// Contract for deal data.
abstract interface class CrmRepository {
  Stream<List<Deal>> watchDeals(String companyId);
  Future<String> createDeal(String companyId, Deal deal);
  Future<void> updateDeal(String companyId, Deal deal);
  Future<void> deleteDeal(String companyId, String dealId);
}

class FirestoreCrmRepository implements CrmRepository {
  FirestoreCrmRepository(this._db);
  final FirebaseFirestore _db;

  CollectionReference<Map<String, dynamic>> _col(String cid) =>
      _db.collection('companies').doc(cid).collection('deals');

  @override
  Stream<List<Deal>> watchDeals(String companyId) {
    return _col(companyId).orderBy('createdAt', descending: true).snapshots().map(
        (s) => s.docs.map((d) => Deal.fromMap(d.id, d.data())).toList());
  }

  @override
  Future<String> createDeal(String companyId, Deal deal) async {
    final ref = _col(companyId).doc();
    await ref.set(deal.toMap());
    return ref.id;
  }

  @override
  Future<void> updateDeal(String companyId, Deal deal) =>
      _col(companyId).doc(deal.id).update(deal.toMap());

  @override
  Future<void> deleteDeal(String companyId, String dealId) =>
      _col(companyId).doc(dealId).delete();
}

final crmRepositoryProvider = Provider<CrmRepository>((ref) {
  return FirestoreCrmRepository(FirebaseFirestore.instance);
});

final dealsProvider = StreamProvider<List<Deal>>((ref) {
  final cid = ref.watch(currentProfileProvider).companyId;
  if (cid.isEmpty) return Stream.value(const []);
  return ref.watch(crmRepositoryProvider).watchDeals(cid);
});

final crmActionsProvider = Provider<CrmActions>((ref) {
  return CrmActions(
    ref.watch(crmRepositoryProvider),
    ref.watch(currentProfileProvider).companyId,
  );
});

class CrmActions {
  CrmActions(this._repo, this._companyId);
  final CrmRepository _repo;
  final String _companyId;

  Future<String> create(Deal d) => _repo.createDeal(_companyId, d);
  Future<void> update(Deal d) => _repo.updateDeal(_companyId, d);
  Future<void> setStage(Deal d, DealStage stage) =>
      _repo.updateDeal(_companyId, d.copyWith(stage: stage));
  Future<void> delete(String id) => _repo.deleteDeal(_companyId, id);
}
