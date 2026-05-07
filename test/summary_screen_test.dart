import 'package:eazyaccount/features/summary/summary_screen.dart';
import 'package:eazyaccount/shared/models/money_entry.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('filterEntriesForReportRange', () {
    final now = DateTime(2026, 5, 7, 15, 30);
    final entries = [
      _entry('yesterday', DateTime(2026, 5, 6, 23, 59)),
      _entry('today', DateTime(2026, 5, 7, 8)),
      _entry('tomorrow', DateTime(2026, 5, 8, 9)),
      _entry('last week', DateTime(2026, 5, 3, 12)),
      _entry('this week', DateTime(2026, 5, 4, 9)),
      _entry('last month', DateTime(2026, 4, 30, 12)),
    ];

    test('keeps only today entries for today range', () {
      final filtered = filterEntriesForReportRange(
        entries,
        ReportRange.today,
        now: now,
      );

      expect(filtered.map((entry) => entry.id), ['today']);
    });

    test('keeps current Monday-Sunday entries for week range', () {
      final filtered = filterEntriesForReportRange(
        entries,
        ReportRange.week,
        now: now,
      );

      expect(filtered.map((entry) => entry.id), [
        'yesterday',
        'today',
        'tomorrow',
        'this week',
      ]);
    });

    test('keeps current calendar month entries for month range', () {
      final filtered = filterEntriesForReportRange(
        entries,
        ReportRange.month,
        now: now,
      );

      expect(filtered.map((entry) => entry.id), [
        'yesterday',
        'today',
        'tomorrow',
        'last week',
        'this week',
      ]);
    });
  });
}

MoneyEntry _entry(String id, DateTime createdAt) {
  return MoneyEntry(
    id: id,
    title: id,
    amount: 1,
    type: EntryType.expense,
    createdAt: createdAt,
  );
}
