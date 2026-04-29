import 'money_entry.dart';

class ParsedMoneyItem {
  const ParsedMoneyItem({
    required this.name,
    required this.amount,
    required this.type,
    this.source,
  });

  final String name;
  final num amount;
  final EntryType type;
  final String? source;

  factory ParsedMoneyItem.fromJson(Map<String, dynamic> json) {
    final amount = json['amount'];

    return ParsedMoneyItem(
      name: json['name']?.toString() ?? 'ไม่ระบุรายการ',
      amount: amount is num ? amount : num.tryParse('$amount') ?? 0,
      type: json['type'] == 'income' ? EntryType.income : EntryType.expense,
      source: json['source']?.toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'amount': amount,
      'type': type == EntryType.income ? 'income' : 'expense',
      if (source != null && source!.isNotEmpty) 'source': source,
    };
  }

  String get label {
    final cleanAmount = amount % 1 == 0 ? amount.toInt().toString() : '$amount';
    final prefix = source == null || source!.isEmpty || source == name
        ? name
        : '$source $name';
    if (amount == 0 && type == EntryType.expense) return prefix;
    final spacer = RegExp(r'\d$').hasMatch(prefix) ? ' ' : '';
    return '$prefix$spacer$cleanAmount';
  }
}

class ParsedMoneyEntry {
  const ParsedMoneyEntry({
    required this.rawText,
    required this.items,
  });

  final String rawText;
  final List<ParsedMoneyItem> items;

  factory ParsedMoneyEntry.fromJson(Map<String, dynamic> json) {
    final rawItems = json['items'];

    return ParsedMoneyEntry(
      rawText: json['raw_text']?.toString() ?? '',
      items: rawItems is List
          ? rawItems
              .whereType<Map>()
              .map((item) => ParsedMoneyItem.fromJson(
                    Map<String, dynamic>.from(item),
                  ))
              .toList()
          : const [],
    );
  }

  ParsedMoneyEntry copyWith({
    String? rawText,
    List<ParsedMoneyItem>? items,
  }) {
    return ParsedMoneyEntry(
      rawText: rawText ?? this.rawText,
      items: items ?? this.items,
    );
  }
}
