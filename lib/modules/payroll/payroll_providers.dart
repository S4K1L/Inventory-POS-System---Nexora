import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/company/company_providers.dart';
import 'domain/payslip.dart';

abstract interface class PayrollRepository {
  Stream<List<Payslip>> watchPayslips(String companyId, {int limit = 200});
  Future<String> createPayslip(String companyId, Payslip payslip);
  Future<void> deletePayslip(String companyId, String id);
}

class FirestorePayrollRepository implements PayrollRepository {
  FirestorePayrollRepository(this._db);
  final FirebaseFirestore _db;

  CollectionReference<Map<String, dynamic>> _col(String cid) =>
      _db.collection('companies').doc(cid).collection('payslips');

  @override
  Stream<List<Payslip>> watchPayslips(String companyId, {int limit = 200}) {
    return _col(companyId)
        .orderBy('createdAt', descending: true)
        .limit(limit)
        .snapshots()
        .map((s) => s.docs.map((d) => Payslip.fromMap(d.id, d.data())).toList());
  }

  @override
  Future<String> createPayslip(String companyId, Payslip payslip) async {
    final ref = _col(companyId).doc();
    await ref.set(payslip.toMap());
    return ref.id;
  }

  @override
  Future<void> deletePayslip(String companyId, String id) =>
      _col(companyId).doc(id).delete();
}

final payrollRepositoryProvider = Provider<PayrollRepository>((ref) {
  return FirestorePayrollRepository(FirebaseFirestore.instance);
});

final payslipsProvider = StreamProvider<List<Payslip>>((ref) {
  final cid = ref.watch(currentProfileProvider).companyId;
  if (cid.isEmpty) return Stream.value(const []);
  return ref.watch(payrollRepositoryProvider).watchPayslips(cid);
});

final payrollActionsProvider = Provider<PayrollActions>((ref) {
  return PayrollActions(
    ref.watch(payrollRepositoryProvider),
    ref.watch(currentProfileProvider).companyId,
  );
});

class PayrollActions {
  PayrollActions(this._repo, this._companyId);
  final PayrollRepository _repo;
  final String _companyId;

  Future<String> generate({
    required String uid,
    required String employeeName,
    required String month,
    required num basic,
    num bonus = 0,
    num deduction = 0,
  }) {
    return _repo.createPayslip(
      _companyId,
      Payslip(
        id: '',
        uid: uid,
        employeeName: employeeName,
        month: month,
        basic: basic,
        bonus: bonus,
        deduction: deduction,
        createdAt: DateTime.now(),
      ),
    );
  }

  Future<void> delete(String id) => _repo.deletePayslip(_companyId, id);
}
