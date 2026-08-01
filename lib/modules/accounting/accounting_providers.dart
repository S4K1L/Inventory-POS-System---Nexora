import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/company/company_providers.dart';
import '../customers/customers_providers.dart';
import '../suppliers/suppliers_providers.dart';
import 'domain/ledger_entry.dart';

abstract interface class AccountingRepository {
  Stream<List<LedgerEntry>> watchLedger(String companyId, {int limit = 300});
  Future<String> addEntry(String companyId, LedgerEntry entry);
  Future<void> deleteEntry(String companyId, String id);
}

class FirestoreAccountingRepository implements AccountingRepository {
  FirestoreAccountingRepository(this._db);
  final FirebaseFirestore _db;

  CollectionReference<Map<String, dynamic>> _col(String cid) =>
      _db.collection('companies').doc(cid).collection('ledger');

  @override
  Stream<List<LedgerEntry>> watchLedger(String companyId, {int limit = 300}) {
    return _col(companyId)
        .orderBy('date', descending: true)
        .limit(limit)
        .snapshots()
        .map((s) =>
            s.docs.map((d) => LedgerEntry.fromMap(d.id, d.data())).toList());
  }

  @override
  Future<String> addEntry(String companyId, LedgerEntry entry) async {
    final ref = _col(companyId).doc();
    await ref.set(entry.toMap());
    return ref.id;
  }

  @override
  Future<void> deleteEntry(String companyId, String id) =>
      _col(companyId).doc(id).delete();
}

final accountingRepositoryProvider = Provider<AccountingRepository>((ref) {
  return FirestoreAccountingRepository(FirebaseFirestore.instance);
});

final ledgerProvider = StreamProvider<List<LedgerEntry>>((ref) {
  final cid = ref.watch(currentProfileProvider).companyId;
  if (cid.isEmpty) return Stream.value(const []);
  return ref.watch(accountingRepositoryProvider).watchLedger(cid);
});

/// Company-wide account snapshot: cash from the ledger, receivables from
/// customer dues, payables from supplier dues.
final accountingSummaryProvider = Provider<AccountingSummary>((ref) {
  final ledger = ref.watch(ledgerProvider).value ?? const [];
  final customers = ref.watch(customersProvider).value ?? const [];
  final suppliers = ref.watch(suppliersProvider).value ?? const [];

  final cash = ledger.fold<num>(0, (t, e) => t + e.signed);
  final receivables =
      customers.fold<num>(0, (t, c) => t + c.dueAmount);
  final payables = suppliers.fold<num>(0, (t, s) => t + s.dueAmount);
  return AccountingSummary(
      cash: cash, receivables: receivables, payables: payables);
});

class AccountingSummary {
  const AccountingSummary({
    required this.cash,
    required this.receivables,
    required this.payables,
  });
  final num cash;
  final num receivables;
  final num payables;
}

final accountingActionsProvider = Provider<AccountingActions>((ref) {
  return AccountingActions(
    ref.watch(accountingRepositoryProvider),
    ref.watch(currentProfileProvider).companyId,
  );
});

class AccountingActions {
  AccountingActions(this._repo, this._companyId);
  final AccountingRepository _repo;
  final String _companyId;

  Future<String> add({
    required LedgerType type,
    required String account,
    required num amount,
    required DateTime date,
    String note = '',
  }) {
    return _repo.addEntry(
      _companyId,
      LedgerEntry(
        id: '',
        type: type,
        account: account,
        amount: amount,
        date: date,
        note: note,
      ),
    );
  }

  Future<void> delete(String id) => _repo.deleteEntry(_companyId, id);
}
