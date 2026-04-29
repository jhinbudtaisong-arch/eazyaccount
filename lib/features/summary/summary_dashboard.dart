import 'package:flutter/material.dart';

import '../../shared/theme/app_theme.dart';
import '../../shared/utils/formatters.dart';

class SummaryDashboard extends StatelessWidget {
  const SummaryDashboard({
    super.key,
    required this.income,
    required this.expense,
    required this.balance,
  });

  final num income;
  final num expense;
  final num balance;

  @override
  Widget build(BuildContext context) {
    final colors = context.eazyColors;

    return Row(
      children: [
        Expanded(
          child: SummaryTile(
            label: 'รายรับ',
            amount: income,
            color: colors.income,
            icon: Icons.south_west_rounded,
          ),
        ),
        const SizedBox(width: 6),
        Expanded(
          child: SummaryTile(
            label: 'รายจ่าย',
            amount: expense,
            color: colors.expense,
            icon: Icons.north_east_rounded,
          ),
        ),
        const SizedBox(width: 6),
        Expanded(
          child: SummaryTile(
            label: 'เงินคงเหลือ',
            amount: balance,
            color: balance >= 0 ? colors.income : colors.expense,
            icon: Icons.account_balance_wallet_rounded,
          ),
        ),
      ],
    );
  }
}

class SummaryTile extends StatelessWidget {
  const SummaryTile({
    super.key,
    required this.label,
    required this.amount,
    required this.color,
    required this.icon,
  });

  final String label;
  final num amount;
  final Color color;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final colors = context.eazyColors;

    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: color, size: 16),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: colors.muted,
                          fontWeight: FontWeight.w800,
                        ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            FittedBox(
              alignment: Alignment.centerLeft,
              fit: BoxFit.scaleDown,
              child: Text(
                '${formatMoney(amount)} บาท',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      color: color,
                      fontWeight: FontWeight.w900,
                    ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
