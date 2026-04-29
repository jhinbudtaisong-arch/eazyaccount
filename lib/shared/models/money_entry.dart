enum EntryType { expense, income }

enum ReportRange { today, week, month }

enum VoiceMode { push, auto }

class MoneyEntry {
  const MoneyEntry({
    required this.id,
    required this.title,
    required this.amount,
    required this.type,
    required this.createdAt,
  });

  final String id;
  final String title;
  final num amount;
  final EntryType type;
  final DateTime createdAt;

  factory MoneyEntry.fromEntryItem(Map<String, dynamic> item) {
    final amount = item['amount'];

    return MoneyEntry(
      id: item['id']?.toString() ?? '',
      title: item['name']?.toString() ?? 'ไม่ระบุรายการ',
      amount: amount is num ? amount : num.tryParse('$amount') ?? 0,
      type: item['type'] == 'income' ? EntryType.income : EntryType.expense,
      createdAt: DateTime.tryParse(item['created_at']?.toString() ?? '') ??
          DateTime.now(),
    );
  }
}
