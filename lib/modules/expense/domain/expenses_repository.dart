import 'expense.dart';

/// Contract for expense data. Expenses are recorded per branch.
abstract interface class ExpensesRepository {
  Stream<List<Expense>> watchRecentExpenses(String companyId, String branchId,
      {int limit = 200});
  Stream<List<Expense>> watchExpensesSince(
      String companyId, String branchId, DateTime from);
  Future<String> createExpense(
      String companyId, String branchId, Expense expense);
  Future<void> updateExpense(
      String companyId, String branchId, Expense expense);
  Future<void> deleteExpense(
      String companyId, String branchId, String expenseId);
}
