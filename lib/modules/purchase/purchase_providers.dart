import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/company/company_providers.dart';
import 'data/firestore_purchases_repository.dart';
import 'domain/purchase.dart';
import 'domain/purchases_repository.dart';

final purchasesRepositoryProvider = Provider<PurchasesRepository>((ref) {
  return FirestorePurchasesRepository(FirebaseFirestore.instance);
});

final _companyIdProvider = Provider<String>((ref) {
  return ref.watch(currentProfileProvider).companyId;
});

final recentPurchasesProvider = StreamProvider<List<Purchase>>((ref) {
  final cid = ref.watch(_companyIdProvider);
  if (cid.isEmpty) return Stream.value(const []);
  return ref.watch(purchasesRepositoryProvider).watchRecentPurchases(cid);
});

/// Runs a receive using the current company + user.
final receivePurchaseProvider = Provider<ReceivePurchase>((ref) {
  final repo = ref.watch(purchasesRepositoryProvider);
  final profile = ref.watch(currentProfileProvider);
  return ReceivePurchase(repo, profile.companyId, profile.uid);
});

class ReceivePurchase {
  ReceivePurchase(this._repo, this._companyId, this._userId);
  final PurchasesRepository _repo;
  final String _companyId;
  final String _userId;

  Future<Purchase> call(PurchaseRequest request) {
    return _repo.receive(
      _companyId,
      PurchaseRequest(
        supplierId: request.supplierId,
        supplierName: request.supplierName,
        items: request.items,
        discount: request.discount,
        tax: request.tax,
        shipping: request.shipping,
        paid: request.paid,
        note: request.note,
        updateCostPrice: request.updateCostPrice,
        userId: _userId,
      ),
    );
  }
}
