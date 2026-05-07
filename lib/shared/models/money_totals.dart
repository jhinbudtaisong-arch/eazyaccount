import 'money_entry.dart';

class MoneyTotals {
  const MoneyTotals({
    required this.income,
    required this.expense,
  });

  final num income;
  final num expense;

  num get balance => income - expense;

  double get incomeShare {
    final total = income + expense;
    if (total == 0) return 0;
    return (income / total).toDouble();
  }

  static MoneyTotals fromEntries(Iterable<MoneyEntry> entries) {
    num income = 0;
    num expense = 0;

    for (final entry in entries) {
      if (entry.isDiscarded) continue;

      switch (entry.type) {
        case EntryType.income:
          income += entry.amount;
        case EntryType.expense:
          expense += entry.amount;
      }
    }

    return MoneyTotals(income: income, expense: expense);
  }
}
