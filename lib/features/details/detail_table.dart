import 'package:flutter/material.dart';

import '../../shared/models/money_entry.dart';
import '../../shared/theme/app_theme.dart';
import '../../shared/utils/formatters.dart';

class DetailTable extends StatelessWidget {
  const DetailTable({super.key, required this.entries});

  final List<MoneyEntry> entries;

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
                      return DetailRow(entry: entries[reverseIndex]);
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
  const DetailRow({super.key, required this.entry});

  final MoneyEntry entry;

  @override
  Widget build(BuildContext context) {
    final isExpense = entry.type == EntryType.expense;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      child: Row(
        children: [
          Expanded(
            flex: 2,
            child: Text(
              entry.title,
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
          Expanded(
            child: Text(
              isExpense ? '${formatMoney(entry.amount)} ฿' : '-',
              style: TextStyle(
                color: isExpense ? expenseColor : mutedColor,
                fontWeight: isExpense ? FontWeight.w800 : FontWeight.w500,
              ),
            ),
          ),
          Expanded(
            child: Text(
              isExpense ? '-' : '${formatMoney(entry.amount)} ฿',
              style: TextStyle(
                color: isExpense ? mutedColor : incomeColor,
                fontWeight: isExpense ? FontWeight.w500 : FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
