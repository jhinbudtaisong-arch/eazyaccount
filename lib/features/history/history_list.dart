import 'package:flutter/material.dart';

import '../../shared/models/money_entry.dart';
import '../../shared/theme/app_theme.dart';
import '../../shared/utils/formatters.dart';

class HistoryList extends StatefulWidget {
  const HistoryList({super.key, required this.entries});

  final List<MoneyEntry> entries;

  @override
  State<HistoryList> createState() => _HistoryListState();
}

class _HistoryListState extends State<HistoryList> {
  final Set<String> _completedShoppingIds = {};

  @override
  void didUpdateWidget(covariant HistoryList oldWidget) {
    super.didUpdateWidget(oldWidget);
    final currentIds = widget.entries.map((entry) => entry.id).toSet();
    _completedShoppingIds.removeWhere((id) => !currentIds.contains(id));
  }

  void _toggleShoppingItem(String id) {
    setState(() {
      if (!_completedShoppingIds.add(id)) {
        _completedShoppingIds.remove(id);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final recentEntries =
        widget.entries.reversed.take(3).toList(growable: false);
    final shoppingEntries = widget.entries.reversed
        .where((entry) => entry.type == EntryType.expense && entry.amount == 0)
        .take(3)
        .toList(growable: false);

    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 520;
        final recentList = _HistorySection(
          title: 'รายการล่าสุด',
          countText: '${widget.entries.length} รายการ',
          emptyText:
              'ยังไม่มีรายการ ลองกดไมค์แล้วพูด หรือพิมพ์รายการทดสอบได้เลย',
          compact: compact,
          children: [
            for (final entry in recentEntries)
              HistoryListTile(entry: entry, compact: compact),
          ],
        );
        final shoppingList = _HistorySection(
          title: 'รายการที่ต้องซื้อ',
          countText: '${shoppingEntries.length} รายการ',
          emptyText: 'ยังไม่มีรายการซื้อ',
          compact: compact,
          children: [
            for (final entry in shoppingEntries)
              HistoryListTile(
                entry: entry,
                compact: true,
                isCompleted: _completedShoppingIds.contains(entry.id),
                onTap: () => _toggleShoppingItem(entry.id),
              ),
          ],
        );

        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: recentList),
            SizedBox(width: compact ? 8 : 12),
            Expanded(child: shoppingList),
          ],
        );
      },
    );
  }
}

class _HistorySection extends StatelessWidget {
  const _HistorySection({
    required this.title,
    required this.countText,
    required this.emptyText,
    required this.children,
    this.compact = false,
  });

  final String title;
  final String countText;
  final String emptyText;
  final List<Widget> children;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final colors = context.eazyColors;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: colors.ink,
                      fontSize: compact ? 17 : null,
                      fontWeight: FontWeight.w800,
                    ),
              ),
            ),
            Text(
              compact ? countText.split(' ').first : countText,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: colors.muted,
                    fontSize: compact ? 12 : null,
                    fontWeight: FontWeight.w700,
                  ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        if (children.isEmpty)
          EmptyHistory(message: emptyText, compact: compact)
        else
          for (final child in children)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: child,
            ),
      ],
    );
  }
}

class EmptyHistory extends StatelessWidget {
  const EmptyHistory({super.key, required this.message, this.compact = false});

  final String message;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final colors = context.eazyColors;

    return Card(
      child: Padding(
        padding: EdgeInsets.all(compact ? 10 : 16),
        child: Text(
          message,
          maxLines: compact ? 2 : null,
          overflow: compact ? TextOverflow.ellipsis : null,
          style: TextStyle(color: colors.muted, fontWeight: FontWeight.w700),
        ),
      ),
    );
  }
}

class HistoryListTile extends StatelessWidget {
  const HistoryListTile({
    super.key,
    required this.entry,
    this.compact = false,
    this.isCompleted = false,
    this.onTap,
  });

  final MoneyEntry entry;
  final bool compact;
  final bool isCompleted;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.eazyColors;
    final isIncome = entry.type == EntryType.income;
    final color = isIncome ? colors.income : colors.expense;

    return ListTile(
      onTap: onTap,
      dense: compact,
      minLeadingWidth: compact ? 24 : null,
      horizontalTitleGap: compact ? 8 : null,
      contentPadding: EdgeInsets.symmetric(
        horizontal: compact ? 8 : 16,
        vertical: compact ? 0 : 2,
      ),
      tileColor: colors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(color: colors.border),
      ),
      leading: CircleAvatar(
        radius: compact ? 14 : 18,
        backgroundColor: isCompleted
            ? colors.muted.withValues(alpha: 0.12)
            : color.withValues(alpha: 0.14),
        foregroundColor: isCompleted ? colors.muted : color,
        child: Icon(
          isCompleted
              ? Icons.check_rounded
              : isIncome
                  ? Icons.south_west_rounded
                  : Icons.north_east_rounded,
          size: compact ? 16 : 20,
        ),
      ),
      title: Text(
        entry.title,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          color: isCompleted ? colors.muted : colors.ink,
          fontSize: compact ? 15 : null,
          fontWeight: FontWeight.w800,
          decoration:
              isCompleted ? TextDecoration.lineThrough : TextDecoration.none,
          decorationThickness: 2,
        ),
      ),
      subtitle: compact
          ? null
          : Text(
              formatTime(entry.createdAt),
              style: TextStyle(color: colors.muted),
            ),
      trailing: _HistoryAmount(
        entry: entry,
        color: isCompleted ? colors.muted : color,
        compact: compact,
        isCompleted: isCompleted,
      ),
    );
  }
}

class _HistoryAmount extends StatelessWidget {
  const _HistoryAmount({
    required this.entry,
    required this.color,
    required this.compact,
    required this.isCompleted,
  });

  final MoneyEntry entry;
  final Color color;
  final bool compact;
  final bool isCompleted;

  @override
  Widget build(BuildContext context) {
    final isIncome = entry.type == EntryType.income;
    final isShoppingItem = entry.type == EntryType.expense && entry.amount == 0;

    return Text(
      isShoppingItem
          ? isCompleted
              ? compact
                  ? 'แล้ว'
                  : 'ทำแล้ว'
              : compact
                  ? 'ซื้อ'
                  : 'ต้องซื้อ'
          : '${isIncome ? '+' : '-'}${formatMoney(entry.amount)}${compact ? '' : ' บาท'}',
      style: TextStyle(
        color: color,
        fontSize: compact ? 12 : null,
        fontWeight: FontWeight.w900,
      ),
    );
  }
}
