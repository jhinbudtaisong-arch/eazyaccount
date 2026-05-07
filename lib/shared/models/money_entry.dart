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
    this.isPending = false,
    this.isDiscarded = false,
  });

  final String id;
  final String title;
  final num amount;
  final EntryType type;
  final DateTime createdAt;
  final bool isPending;
  final bool isDiscarded;

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

  factory MoneyEntry.fromJson(Map<String, dynamic> json) {
    final amount = json['amount'];

    return MoneyEntry(
      id: json['id']?.toString() ?? '',
      title: json['title']?.toString() ?? 'ไม่ระบุรายการ',
      amount: amount is num ? amount : num.tryParse('$amount') ?? 0,
      type: json['type'] == 'income' ? EntryType.income : EntryType.expense,
      createdAt: DateTime.tryParse(json['created_at']?.toString() ?? '') ??
          DateTime.now(),
      isPending: json['is_pending'] == true,
      isDiscarded: json['is_discarded'] == true,
    );
  }

  MoneyEntry copyWith({
    String? id,
    String? title,
    num? amount,
    EntryType? type,
    DateTime? createdAt,
    bool? isPending,
    bool? isDiscarded,
  }) {
    return MoneyEntry(
      id: id ?? this.id,
      title: title ?? this.title,
      amount: amount ?? this.amount,
      type: type ?? this.type,
      createdAt: createdAt ?? this.createdAt,
      isPending: isPending ?? this.isPending,
      isDiscarded: isDiscarded ?? this.isDiscarded,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'amount': amount,
      'type': type == EntryType.income ? 'income' : 'expense',
      'created_at': createdAt.toIso8601String(),
      'is_pending': isPending,
      'is_discarded': isDiscarded,
    };
  }
}
