/// Whether a ledger entry brings money in or out.
enum LedgerType {
  income('income', 'Income'),
  expense('expense', 'Expense');

  const LedgerType(this.id, this.label);
  final String id;
  final String label;

  static LedgerType fromId(String? id) =>
      id == 'expense' ? LedgerType.expense : LedgerType.income;
}

/// A cash-book entry. Stored at `companies/{cid}/ledger/{id}`.
class LedgerEntry {
  const LedgerEntry({
    required this.id,
    required this.type,
    required this.account,
    required this.amount,
    required this.date,
    this.note = '',
  });

  final String id;
  final LedgerType type;

  /// Free-text account/category, e.g. "Cash Sales", "Owner Drawing", "Rent".
  final String account;
  final num amount;
  final DateTime date;
  final String note;

  /// Signed effect on cash (+income, −expense).
  num get signed => type == LedgerType.income ? amount : -amount;

  Map<String, dynamic> toMap() => {
        'type': type.id,
        'account': account,
        'amount': amount,
        'date': date.toIso8601String(),
        'note': note,
      };

  factory LedgerEntry.fromMap(String id, Map<String, dynamic> data) {
    return LedgerEntry(
      id: id,
      type: LedgerType.fromId(data['type'] as String?),
      account: (data['account'] ?? '') as String,
      amount: (data['amount'] ?? 0) as num,
      date: DateTime.tryParse((data['date'] ?? '') as String) ?? DateTime.now(),
      note: (data['note'] ?? '') as String,
    );
  }
}
