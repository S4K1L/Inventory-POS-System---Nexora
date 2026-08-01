/// Common expense categories from the spec. Stored as the string [id]; a
/// company can also use any custom label.
class ExpenseCategories {
  ExpenseCategories._();

  static const presets = <String>[
    'Rent',
    'Salary',
    'Electricity',
    'Internet',
    'Fuel',
    'Transport',
    'Marketing',
    'Supplies',
    'Maintenance',
    'Other',
  ];
}

/// A recorded expense. Stored at `companies/{cid}/expenses/{id}`.
class Expense {
  const Expense({
    required this.id,
    required this.category,
    required this.amount,
    required this.date,
    this.note = '',
    this.userId = '',
  });

  final String id;
  final String category;
  final num amount;
  final DateTime date;
  final String note;
  final String userId;

  Expense copyWith({
    String? category,
    num? amount,
    DateTime? date,
    String? note,
  }) {
    return Expense(
      id: id,
      category: category ?? this.category,
      amount: amount ?? this.amount,
      date: date ?? this.date,
      note: note ?? this.note,
      userId: userId,
    );
  }

  Map<String, dynamic> toMap() => {
        'category': category,
        'amount': amount,
        'date': date.toIso8601String(),
        'note': note,
        'userId': userId,
      };

  factory Expense.fromMap(String id, Map<String, dynamic> data) {
    return Expense(
      id: id,
      category: (data['category'] ?? 'Other') as String,
      amount: (data['amount'] ?? 0) as num,
      date: DateTime.tryParse((data['date'] ?? '') as String) ?? DateTime.now(),
      note: (data['note'] ?? '') as String,
      userId: (data['userId'] ?? '') as String,
    );
  }
}
