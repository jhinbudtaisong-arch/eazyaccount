import 'package:flutter/material.dart';

import '../../shared/models/money_entry.dart';
import '../../shared/theme/app_theme.dart';
import '../../shared/utils/formatters.dart';

class DetailTable extends StatelessWidget {
  const DetailTable({
    super.key,
    required this.entries,
    required this.onTogglePendingEntry,
  });

  final List<MoneyEntry> entries;
  final Future<void> Function(String id) onTogglePendingEntry;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const DetailHeader(),
        const SizedBox(height: 8),
        Expanded(
          child: Card(
            child: entries.isEmpty
                ? const Center(child: Text('ยังไม่มีรายการ'))
                : ListView.separated(
                    itemCount: entries.length,
                    separatorBuilder: (_, __) => const Divider(
                      height: 1,
                      color: borderColor,
                    ),
                    itemBuilder: (context, index) {
                      final reverseIndex = entries.length - 1 - index;
                      return DetailRow(
                        entry: entries[reverseIndex],
                        onTogglePendingEntry: onTogglePendingEntry,
                      );
                    },
                  ),
          ),
        ),
      ],
    );
  }
}

class DetailHeader extends StatelessWidget {
  const DetailHeader({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: inkColor,
        borderRadius: BorderRadius.circular(8),
      ),
      child: const Row(
        children: [
          Expanded(flex: 2, child: HeaderText('รายการ')),
          Expanded(child: HeaderText('รายจ่าย')),
          Expanded(child: HeaderText('รายรับ')),
        ],
      ),
    );
  }
}

class HeaderText extends StatelessWidget {
  const HeaderText(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        color: Colors.white,
        fontWeight: FontWeight.w800,
      ),
    );
  }
}

class DetailRow extends StatelessWidget {
  const DetailRow({
    super.key,
    required this.entry,
    required this.onTogglePendingEntry,
  });

  final MoneyEntry entry;
  final Future<void> Function(String id) onTogglePendingEntry;

  @override
  Widget build(BuildContext context) {
    final isExpense = entry.type == EntryType.expense;
    final colors = context.eazyColors;
    final titleStyle = TextStyle(
      color: entry.isDiscarded ? colors.muted : colors.ink,
      fontWeight: FontWeight.w700,
      decoration:
          entry.isDiscarded ? TextDecoration.lineThrough : TextDecoration.none,
      decorationThickness: 2,
    );

    return InkWell(
      onTap: entry.isPending ? () => onTogglePendingEntry(entry.id) : null,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        child: Row(
          children: [
            Expanded(
              flex: 2,
              child: Row(
                children: [
                  if (entry.isPending) ...[
                    Icon(
                      entry.isDiscarded
                          ? Icons.check_circle_rounded
                          : Icons.schedule_rounded,
                      size: 16,
                      color: entry.isDiscarded ? colors.muted : colors.warning,
                    ),
                    const SizedBox(width: 6),
                  ],
                  Expanded(
                    child: Text(
                      entry.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: titleStyle,
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: Text(
                isExpense ? '${formatMoney(entry.amount)} ฿' : '-',
                style: TextStyle(
                  color: entry.isDiscarded
                      ? colors.muted
                      : isExpense
                          ? expenseColor
                          : mutedColor,
                  fontWeight: isExpense ? FontWeight.w800 : FontWeight.w500,
                  decoration: entry.isDiscarded
                      ? TextDecoration.lineThrough
                      : TextDecoration.none,
                  decorationThickness: 2,
                ),
              ),
            ),
            Expanded(
              child: Text(
                isExpense ? '-' : '${formatMoney(entry.amount)} ฿',
                style: TextStyle(
                  color: entry.isDiscarded
                      ? colors.muted
                      : isExpense
                          ? mutedColor
                          : incomeColor,
                  fontWeight: isExpense ? FontWeight.w500 : FontWeight.w800,
                  decoration: entry.isDiscarded
                      ? TextDecoration.lineThrough
                      : TextDecoration.none,
                  decorationThickness: 2,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
