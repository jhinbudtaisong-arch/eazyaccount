import 'package:flutter/material.dart';

import '../../shared/models/money_entry.dart';
import '../../shared/models/money_totals.dart';
import '../../shared/theme/app_theme.dart';
import '../../shared/utils/formatters.dart';

class SummaryScreen extends StatefulWidget {
  const SummaryScreen({super.key, required this.entries});

  final List<MoneyEntry> entries;

  @override
  State<SummaryScreen> createState() => _SummaryScreenState();
}

class _SummaryScreenState extends State<SummaryScreen> {
  ReportRange _range = ReportRange.today;
  late DateTime _visibleMonth;
  DateTime? _selectedDay;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _visibleMonth = DateTime(now.year, now.month);
    _selectedDay = DateTime(now.year, now.month, now.day);
  }

  @override
  Widget build(BuildContext context) {
    final totals = MoneyTotals.fromEntries(widget.entries);
    final dailySummaries = _buildDailySummaries(widget.entries);
    final selectedSummary =
        _selectedDay == null ? null : dailySummaries[_dayKey(_selectedDay!)];

    return Scaffold(
      appBar: AppBar(title: const Text('รายงาน')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
          children: [
            Text(
              'ภาพรวมการเงิน',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    color: inkColor,
                    fontWeight: FontWeight.w800,
                  ),
            ),
            const SizedBox(height: 6),
            Text(
              'สรุปรายรับรายจ่ายและดูภาพรวมรายเดือนแบบปฏิทิน',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: mutedColor,
                  ),
            ),
            const SizedBox(height: 18),
            SegmentedButton<ReportRange>(
              segments: const [
                ButtonSegment(value: ReportRange.today, label: Text('วันนี้')),
                ButtonSegment(
                  value: ReportRange.week,
                  label: Text('สัปดาห์'),
                ),
                ButtonSegment(value: ReportRange.month, label: Text('เดือน')),
              ],
              selected: {_range},
              onSelectionChanged: (selected) =>
                  setState(() => _range = selected.first),
            ),
            const SizedBox(height: 18),
            _SummaryTotalsCard(range: _range, totals: totals),
            const SizedBox(height: 16),
            _MonthlyCalendarCard(
              visibleMonth: _visibleMonth,
              selectedDay: _selectedDay,
              dailySummaries: dailySummaries,
              onPreviousMonth: () => setState(() {
                _visibleMonth =
                    DateTime(_visibleMonth.year, _visibleMonth.month - 1);
                _selectedDay = null;
              }),
              onNextMonth: () => setState(() {
                _visibleMonth =
                    DateTime(_visibleMonth.year, _visibleMonth.month + 1);
                _selectedDay = null;
              }),
              onDaySelected: (day) => setState(() => _selectedDay = day),
            ),
            const SizedBox(height: 16),
            _DayDetailCard(
              selectedDay: _selectedDay,
              summary: selectedSummary,
            ),
          ],
        ),
      ),
    );
  }
}

class _SummaryTotalsCard extends StatelessWidget {
  const _SummaryTotalsCard({
    required this.range,
    required this.totals,
  });

  final ReportRange range;
  final MoneyTotals totals;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              reportTitle(range),
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: inkColor,
                    fontWeight: FontWeight.w800,
                  ),
            ),
            const SizedBox(height: 16),
            ClipRRect(
              borderRadius: BorderRadius.circular(999),
              child: LinearProgressIndicator(
                minHeight: 14,
                value: totals.incomeShare,
                color: incomeColor,
                backgroundColor: expenseColor.withValues(alpha: 0.18),
              ),
            ),
            const SizedBox(height: 16),
            SummaryMetric(
              label: 'รายรับ',
              amount: totals.income,
              color: incomeColor,
            ),
            const SizedBox(height: 10),
            SummaryMetric(
              label: 'รายจ่าย',
              amount: totals.expense,
              color: expenseColor,
            ),
            const Divider(height: 28, color: borderColor),
            SummaryMetric(
              label: 'คงเหลือ',
              amount: totals.balance,
              color: primaryColor,
            ),
          ],
        ),
      ),
    );
  }
}

class _MonthlyCalendarCard extends StatelessWidget {
  const _MonthlyCalendarCard({
    required this.visibleMonth,
    required this.selectedDay,
    required this.dailySummaries,
    required this.onPreviousMonth,
    required this.onNextMonth,
    required this.onDaySelected,
  });

  final DateTime visibleMonth;
  final DateTime? selectedDay;
  final Map<DateTime, _DailySummary> dailySummaries;
  final VoidCallback onPreviousMonth;
  final VoidCallback onNextMonth;
  final ValueChanged<DateTime> onDaySelected;

  @override
  Widget build(BuildContext context) {
    final colors = context.eazyColors;
    final days = _monthCells(visibleMonth);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.calendar_month_rounded, color: colors.income),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _monthTitle(visibleMonth),
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          color: colors.ink,
                          fontWeight: FontWeight.w900,
                        ),
                  ),
                ),
                IconButton(
                  tooltip: 'เดือนก่อน',
                  onPressed: onPreviousMonth,
                  icon: const Icon(Icons.chevron_left_rounded),
                ),
                IconButton(
                  tooltip: 'เดือนถัดไป',
                  onPressed: onNextMonth,
                  icon: const Icon(Icons.chevron_right_rounded),
                ),
              ],
            ),
            const SizedBox(height: 8),
            const _WeekdayHeader(),
            const SizedBox(height: 8),
            GridView.builder(
              itemCount: days.length,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 7,
                mainAxisSpacing: 6,
                crossAxisSpacing: 6,
                childAspectRatio: 0.88,
              ),
              itemBuilder: (context, index) {
                final day = days[index];
                if (day == null) return const SizedBox.shrink();

                final key = _dayKey(day);
                return _CalendarDayTile(
                  day: day,
                  summary: dailySummaries[key],
                  isSelected:
                      selectedDay != null && _dayKey(selectedDay!) == key,
                  onTap: () => onDaySelected(day),
                );
              },
            ),
            const SizedBox(height: 12),
            const _CalendarLegend(),
          ],
        ),
      ),
    );
  }
}

class _WeekdayHeader extends StatelessWidget {
  const _WeekdayHeader();

  @override
  Widget build(BuildContext context) {
    final colors = context.eazyColors;
    const labels = ['จ', 'อ', 'พ', 'พฤ', 'ศ', 'ส', 'อา'];

    return Row(
      children: [
        for (final label in labels)
          Expanded(
            child: Center(
              child: Text(
                label,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: colors.muted,
                      fontWeight: FontWeight.w900,
                    ),
              ),
            ),
          ),
      ],
    );
  }
}

class _CalendarDayTile extends StatelessWidget {
  const _CalendarDayTile({
    required this.day,
    required this.summary,
    required this.isSelected,
    required this.onTap,
  });

  final DateTime day;
  final _DailySummary? summary;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.eazyColors;
    final hasEntries = summary != null && summary!.entries.isNotEmpty;
    final accent = _summaryColor(summary, colors);
    final background = hasEntries
        ? Color.alphaBlend(accent.withValues(alpha: 0.16), colors.surface)
        : colors.surfaceAlt.withValues(alpha: 0.45);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
        decoration: BoxDecoration(
          color: background,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected ? accent : colors.border,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Align(
              alignment: Alignment.topLeft,
              child: Text(
                '${day.day}',
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      color: hasEntries ? accent : colors.muted,
                      fontWeight: FontWeight.w900,
                    ),
              ),
            ),
            if (hasEntries)
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  formatMoney(summary!.net.abs()),
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: accent,
                        fontWeight: FontWeight.w900,
                      ),
                ),
              )
            else
              const SizedBox(height: 12),
            Container(
              height: 5,
              width: 24,
              decoration: BoxDecoration(
                color: hasEntries ? accent : colors.border,
                borderRadius: BorderRadius.circular(999),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CalendarLegend extends StatelessWidget {
  const _CalendarLegend();

  @override
  Widget build(BuildContext context) {
    final colors = context.eazyColors;

    return Wrap(
      spacing: 10,
      runSpacing: 8,
      children: [
        _LegendItem(color: colors.income, label: 'รับมากกว่า'),
        _LegendItem(color: colors.expense, label: 'จ่ายมากกว่า'),
        _LegendItem(color: colors.warning, label: 'รับจ่ายเท่ากัน'),
      ],
    );
  }
}

class _LegendItem extends StatelessWidget {
  const _LegendItem({required this.color, required this.label});

  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    final colors = context.eazyColors;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 5),
        Text(
          label,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: colors.muted,
                fontWeight: FontWeight.w700,
              ),
        ),
      ],
    );
  }
}

class _DayDetailCard extends StatelessWidget {
  const _DayDetailCard({
    required this.selectedDay,
    required this.summary,
  });

  final DateTime? selectedDay;
  final _DailySummary? summary;

  @override
  Widget build(BuildContext context) {
    final colors = context.eazyColors;
    final entries = summary?.entries ?? const <MoneyEntry>[];

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    selectedDay == null
                        ? 'รายละเอียดรายวัน'
                        : 'รายละเอียด ${_dayTitle(selectedDay!)}',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          color: colors.ink,
                          fontWeight: FontWeight.w900,
                        ),
                  ),
                ),
                if (summary != null)
                  Text(
                    '${formatMoney(summary!.net)} บาท',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          color: _summaryColor(summary, colors),
                          fontWeight: FontWeight.w900,
                        ),
                  ),
              ],
            ),
            const SizedBox(height: 10),
            if (entries.isEmpty)
              Text(
                selectedDay == null
                    ? 'เลือกวันที่ในปฏิทินเพื่อดูรายการ'
                    : 'วันนี้ยังไม่มีรายการ',
                style:
                    TextStyle(color: colors.muted, fontWeight: FontWeight.w700),
              )
            else ...[
              SummaryMetric(
                label: 'รายรับ',
                amount: summary!.income,
                color: colors.income,
              ),
              const SizedBox(height: 8),
              SummaryMetric(
                label: 'รายจ่าย',
                amount: summary!.expense,
                color: colors.expense,
              ),
              const Divider(height: 24, color: borderColor),
              for (final entry in entries.reversed) _DayEntryRow(entry: entry),
            ],
          ],
        ),
      ),
    );
  }
}

class _DayEntryRow extends StatelessWidget {
  const _DayEntryRow({required this.entry});

  final MoneyEntry entry;

  @override
  Widget build(BuildContext context) {
    final colors = context.eazyColors;
    final isIncome = entry.type == EntryType.income;
    final color = isIncome ? colors.income : colors.expense;

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Icon(
            isIncome ? Icons.south_west_rounded : Icons.north_east_rounded,
            color: color,
            size: 18,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  entry.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: colors.ink,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                Text(
                  formatTime(entry.createdAt),
                  style: TextStyle(color: colors.muted, fontSize: 12),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text(
            '${isIncome ? '+' : '-'}${formatMoney(entry.amount)}',
            style: TextStyle(color: color, fontWeight: FontWeight.w900),
          ),
        ],
      ),
    );
  }
}

class SummaryMetric extends StatelessWidget {
  const SummaryMetric({
    super.key,
    required this.label,
    required this.amount,
    required this.color,
  });

  final String label;
  final num amount;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                color: mutedColor,
                fontWeight: FontWeight.w600,
              ),
        ),
        Text(
          '${formatMoney(amount)} บาท',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: color,
                fontWeight: FontWeight.w800,
              ),
        ),
      ],
    );
  }
}

class _DailySummary {
  _DailySummary();

  final List<MoneyEntry> entries = [];
  num income = 0;
  num expense = 0;

  num get net => income - expense;

  void add(MoneyEntry entry) {
    entries.add(entry);
    switch (entry.type) {
      case EntryType.income:
        income += entry.amount;
      case EntryType.expense:
        expense += entry.amount;
    }
  }
}

Map<DateTime, _DailySummary> _buildDailySummaries(List<MoneyEntry> entries) {
  final summaries = <DateTime, _DailySummary>{};

  for (final entry in entries) {
    final key = _dayKey(entry.createdAt);
    summaries.putIfAbsent(key, _DailySummary.new).add(entry);
  }

  return summaries;
}

List<DateTime?> _monthCells(DateTime month) {
  final firstDay = DateTime(month.year, month.month);
  final daysInMonth = DateTime(month.year, month.month + 1, 0).day;
  final leadingBlanks = firstDay.weekday - DateTime.monday;
  final cells = <DateTime?>[
    for (var i = 0; i < leadingBlanks; i++) null,
    for (var day = 1; day <= daysInMonth; day++)
      DateTime(month.year, month.month, day),
  ];

  while (cells.length % 7 != 0) {
    cells.add(null);
  }

  return cells;
}

DateTime _dayKey(DateTime value) =>
    DateTime(value.year, value.month, value.day);

Color _summaryColor(_DailySummary? summary, EazyColors colors) {
  if (summary == null || summary.entries.isEmpty) return colors.border;
  if (summary.net > 0) return colors.income;
  if (summary.net < 0) return colors.expense;
  return colors.warning;
}

String _monthTitle(DateTime month) {
  const names = [
    'มกราคม',
    'กุมภาพันธ์',
    'มีนาคม',
    'เมษายน',
    'พฤษภาคม',
    'มิถุนายน',
    'กรกฎาคม',
    'สิงหาคม',
    'กันยายน',
    'ตุลาคม',
    'พฤศจิกายน',
    'ธันวาคม',
  ];
  return '${names[month.month - 1]} ${month.year + 543}';
}

String _dayTitle(DateTime day) {
  return '${day.day} ${_monthTitle(DateTime(day.year, day.month))}';
}
