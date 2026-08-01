import 'package:cloud_firestore/cloud_firestore.dart';

import '../domain/expense.dart';
import '../domain/expenses_repository.dart';

/// Firestore implementation. Data at
/// `companies/{cid}/branches/{bid}/expenses/{id}`.
class FirestoreExpensesRepository implements ExpensesRepository {
  FirestoreExpensesRepository(this._db);

  final FirebaseFirestore _db;

  CollectionReference<Map<String, dynamic>> _col(String cid, String bid) => _db
      .collection('companies')
      .doc(cid)
      .collection('branches')
      .doc(bid)
      .collection('expenses');

  @override
  Stream<List<Expense>> watchRecentExpenses(String companyId, String branchId,
      {int limit = 200}) {
    if (branchId.isEmpty) return Stream.value(const []);
    return _col(companyId, branchId)
        .orderBy('date', descending: true)
        .limit(limit)
        .snapshots()
        .map((s) => s.docs.map((d) => Expense.fromMap(d.id, d.data())).toList());
  }

  @override
  Stream<List<Expense>> watchExpensesSince(
      String companyId, String branchId, DateTime from) {
    if (branchId.isEmpty) return Stream.value(const []);
    return _col(companyId, branchId)
        .where('date', isGreaterThanOrEqualTo: from.toIso8601String())
        .snapshots()
        .map((s) => s.docs.map((d) => Expense.fromMap(d.id, d.data())).toList());
  }

  @override
  Future<String> createExpense(
      String companyId, String branchId, Expense expense) async {
    final ref = _col(companyId, branchId).doc();
    await ref.set(expense.toMap());
    return ref.id;
  }

  @override
  Future<void> updateExpense(
      String companyId, String branchId, Expense expense) {
    return _col(companyId, branchId).doc(expense.id).update(expense.toMap());
  }

  @override
  Future<void> deleteExpense(
      String companyId, String branchId, String expenseId) {
    return _col(companyId, branchId).doc(expenseId).delete();
  }
}
