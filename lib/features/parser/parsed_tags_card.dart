import 'package:flutter/material.dart';

import '../../shared/models/money_entry.dart';
import '../../shared/models/parsed_money_entry.dart';
import '../../shared/theme/app_theme.dart';

class ParsedTagsCard extends StatelessWidget {
  const ParsedTagsCard({
    super.key,
    required this.entry,
    required this.isSaving,
    required this.onRemoveItem,
    required this.onSave,
    required this.onCancel,
  });

  final ParsedMoneyEntry entry;
  final bool isSaving;
  final ValueChanged<int> onRemoveItem;
  final VoidCallback onSave;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    final colors = context.eazyColors;
    final incomeTotal = entry.items
        .where((item) => item.type == EntryType.income)
        .fold<num>(0, (sum, item) => sum + item.amount);
    final expenseTotal = entry.items
        .where((item) => item.type == EntryType.expense)
        .fold<num>(0, (sum, item) => sum + item.amount);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.sell_rounded,
                    color: Theme.of(context).colorScheme.primary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'ตรวจรายการก่อนบันทึก',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          color: colors.ink,
                          fontWeight: FontWeight.w800,
                        ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (var index = 0; index < entry.items.length; index++)
                  _ParsedTag(
                    item: entry.items[index],
                    onDeleted: () => onRemoveItem(index),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              'รายรับ ${_formatAmount(incomeTotal)}  รายจ่าย ${_formatAmount(expenseTotal)}',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: colors.muted,
                    fontWeight: FontWeight.w800,
                  ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: isSaving ? null : onCancel,
                    icon: const Icon(Icons.close_rounded),
                    label: const Text('ยกเลิก'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: isSaving || entry.items.isEmpty ? null : onSave,
                    icon: isSaving
                        ? const SizedBox.square(
                            dimension: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.check_rounded),
                    label: const Text('บันทึก'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ParsedTag extends StatelessWidget {
  const _ParsedTag({
    required this.item,
    required this.onDeleted,
  });

  final ParsedMoneyItem item;
  final VoidCallback onDeleted;

  @override
  Widget build(BuildContext context) {
    final colors = context.eazyColors;
    final isIncome = item.type == EntryType.income;
    final color = isIncome ? colors.income : colors.expense;
    final background = Color.alphaBlend(
      color.withValues(alpha: 0.12),
      colors.surface,
    );

    return Chip(
      avatar: Icon(
        isIncome ? Icons.arrow_downward_rounded : Icons.arrow_upward_rounded,
        size: 16,
        color: color,
      ),
      label: Text(
        item.label,
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w800,
        ),
      ),
      backgroundColor: background,
      side: BorderSide(color: color.withValues(alpha: 0.35)),
      deleteIcon: Icon(Icons.close_rounded, size: 18, color: color),
      onDeleted: onDeleted,
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
    );
  }
}

String _formatAmount(num amount) {
  return amount % 1 == 0 ? amount.toInt().toString() : '$amount';
}
