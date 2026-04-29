import '../models/money_entry.dart';

String formatMoney(num amount) {
  final normalized =
      amount % 1 == 0 ? amount.toInt().toString() : amount.toStringAsFixed(2);

  return normalized.replaceAllMapped(
    RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
    (match) => '${match[1]},',
  );
}

String formatTime(DateTime dateTime) {
  final hour = dateTime.hour.toString().padLeft(2, '0');
  final minute = dateTime.minute.toString().padLeft(2, '0');
  return '$hour:$minute น.';
}

String reportTitle(ReportRange range) {
  return switch (range) {
    ReportRange.today => 'วันนี้',
    ReportRange.week => 'สัปดาห์นี้',
    ReportRange.month => 'เดือนนี้',
  };
}
