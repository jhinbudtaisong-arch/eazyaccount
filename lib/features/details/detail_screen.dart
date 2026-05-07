import 'package:flutter/material.dart';

import '../../shared/models/money_entry.dart';
import '../../shared/theme/app_theme.dart';
import 'detail_table.dart';

class DetailScreen extends StatelessWidget {
  const DetailScreen({
    super.key,
    required this.entries,
    required this.isLoading,
    required this.onRefresh,
    required this.onTogglePendingEntry,
  });

  final List<MoneyEntry> entries;
  final bool isLoading;
  final Future<void> Function() onRefresh;
  final Future<void> Function(String id) onTogglePendingEntry;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('รายละเอียด'),
        actions: [
          IconButton(
            tooltip: 'รีเฟรช',
            onPressed: isLoading ? null : onRefresh,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'ตารางบัญชีวันนี้',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      color: inkColor,
                      fontWeight: FontWeight.w800,
                    ),
              ),
              const SizedBox(height: 6),
              Text(
                'รายการวันนี้ยังรอปิดวัน แตะรายการรอปิดวันเพื่อขีดฆ่าก่อนบันทึกจริง',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: mutedColor,
                    ),
              ),
              const SizedBox(height: 18),
              Expanded(
                child: isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : DetailTable(
                        entries: entries,
                        onTogglePendingEntry: onTogglePendingEntry,
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
