import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/company/company_providers.dart';
import '../branches/branches_providers.dart';
import 'data/firestore_expenses_repository.dart';
import 'domain/expense.dart';
import 'domain/expenses_repository.dart';

final expensesRepositoryProvider = Provider<ExpensesRepository>((ref) {
  return FirestoreExpensesRepository(FirebaseFirestore.instance);
});

final _companyIdProvider = Provider<String>((ref) {
  return ref.watch(currentProfileProvider).companyId;
});

final recentExpensesProvider = StreamProvider<List<Expense>>((ref) {
  final cid = ref.watch(_companyIdProvider);
  final bid = ref.watch(currentBranchIdProvider);
  if (cid.isEmpty || bid.isEmpty) return Stream.value(const []);
  return ref.watch(expensesRepositoryProvider).watchRecentExpenses(cid, bid);
});

/// Expenses since the first of the current month — powers monthly totals.
final monthExpensesProvider = StreamProvider<List<Expense>>((ref) {
  final cid = ref.watch(_companyIdProvider);
  final bid = ref.watch(currentBranchIdProvider);
  if (cid.isEmpty || bid.isEmpty) return Stream.value(const []);
  final now = DateTime.now();
  final monthStart = DateTime(now.year, now.month);
  return ref
      .watch(expensesRepositoryProvider)
      .watchExpensesSince(cid, bid, monthStart);
});

/// Aggregated month/today expense totals.
final expenseStatsProvider = Provider<ExpenseStats>((ref) {
  final month = ref.watch(monthExpensesProvider).value ?? const [];
  final now = DateTime.now();
  final todayKey = DateTime(now.year, now.month, now.day);
  num today = 0;
  num monthTotal = 0;
  for (final e in month) {
    monthTotal += e.amount;
    final d = DateTime(e.date.year, e.date.month, e.date.day);
    if (d == todayKey) today += e.amount;
  }
  return ExpenseStats(today: today, month: monthTotal);
});

class ExpenseStats {
  const ExpenseStats({required this.today, required this.month});
  final num today;
  final num month;
}

final expenseActionsProvider = Provider<ExpenseActions>((ref) {
  final repo = ref.watch(expensesRepositoryProvider);
  final profile = ref.watch(currentProfileProvider);
  final branchId = ref.watch(currentBranchIdProvider);
  return ExpenseActions(repo, profile.companyId, branchId, profile.uid);
});

class ExpenseActions {
  ExpenseActions(this._repo, this._companyId, this._branchId, this._userId);
  final ExpensesRepository _repo;
  final String _companyId;
  final String _branchId;
  final String _userId;

  Future<String> create({
    required String category,
    required num amount,
    required DateTime date,
    String note = '',
  }) {
    return _repo.createExpense(
      _companyId,
      _branchId,
      Expense(
        id: '',
        category: category,
        amount: amount,
        date: date,
        note: note,
        userId: _userId,
      ),
    );
  }

  Future<void> delete(String id) =>
      _repo.deleteExpense(_companyId, _branchId, id);
}
