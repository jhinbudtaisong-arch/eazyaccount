import 'dart:async';

import 'package:flutter/material.dart';

import '../../shared/models/money_entry.dart';
import '../../shared/models/money_totals.dart';
import '../../shared/models/parsed_money_entry.dart';
import '../../shared/services/speech_recognition_service.dart';
import '../../shared/theme/app_theme.dart';
import '../../shared/utils/formatters.dart';
import '../history/history_list.dart';
import '../parser/parsed_tags_card.dart';
import '../speech/speech_button.dart';
import '../summary/summary_dashboard.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({
    super.key,
    required this.entries,
    required this.isLoading,
    required this.isSaving,
    required this.onRefresh,
    required this.onPreviewText,
    required this.onSaveParsedEntry,
    required this.onOpenDetails,
    required this.isDarkMode,
    required this.onToggleThemeMode,
    this.errorMessage,
  });

  final List<MoneyEntry> entries;
  final bool isLoading;
  final bool isSaving;
  final String? errorMessage;
  final Future<void> Function() onRefresh;
  final Future<ParsedMoneyEntry> Function(String rawText) onPreviewText;
  final Future<void> Function(ParsedMoneyEntry entry) onSaveParsedEntry;
  final VoidCallback onOpenDetails;
  final bool isDarkMode;
  final VoidCallback onToggleThemeMode;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  static const Duration _autoSilenceTimeout = Duration(minutes: 2);
  static const Duration _autoSessionDuration = Duration(hours: 1);

  final TextEditingController _textController = TextEditingController(
    text: 'ขายข้าว 50 น้ำ 20 ซื้อถุง 30',
  );
  final SpeechRecognitionService _speechService = SpeechRecognitionService();
  VoiceMode _mode = VoiceMode.push;
  bool _isListening = false;
  bool _isSubmittingSpeech = false;
  bool _autoRestarting = false;
  Timer? _autoStopTimer;
  String? _speechTranscript;
  String? _speechStatus;
  String? _speechError;
  ParsedMoneyEntry? _pendingEntry;

  @override
  void dispose() {
    _autoStopTimer?.cancel();
    _speechService.cancel();
    _textController.dispose();
    super.dispose();
  }

  Future<void> _submitText([String? rawText]) async {
    final text = rawText ?? _textController.text;
    if (text.trim().isEmpty) return;

    final parsed = await widget.onPreviewText(text);
    if (!mounted) return;
    setState(() {
      final current = _pendingEntry;
      if (current == null || current.items.isEmpty) {
        _pendingEntry = parsed;
        return;
      }

      _pendingEntry = current.copyWith(
        rawText: _combineRawText(current.rawText, parsed.rawText),
        items: [...current.items, ...parsed.items],
      );
    });
  }

  Future<void> _savePendingEntry() async {
    final entry = _pendingEntry;
    if (entry == null || entry.items.isEmpty) return;

    await widget.onSaveParsedEntry(entry);
    if (!mounted) return;
    setState(() => _pendingEntry = null);
    _textController.clear();
    if (_mode == VoiceMode.auto) {
      unawaited(_startListening());
    }
  }

  void _removePendingItem(int index) {
    final entry = _pendingEntry;
    if (entry == null || index < 0 || index >= entry.items.length) return;

    final nextItems = [...entry.items]..removeAt(index);
    setState(() {
      _pendingEntry =
          nextItems.isEmpty ? null : entry.copyWith(items: nextItems);
    });
    if (nextItems.isEmpty && _mode == VoiceMode.auto) {
      unawaited(_startListening());
    }
  }

  void _cancelPendingEntry() {
    setState(() => _pendingEntry = null);
    if (_mode == VoiceMode.auto) {
      unawaited(_startListening());
    }
  }

  bool get _hasPendingEntry {
    return _pendingEntry != null && _pendingEntry!.items.isNotEmpty;
  }

  bool get _isBusy {
    return widget.isSaving || _isSubmittingSpeech;
  }

  void _pauseAutoForReview() {
    if (_mode != VoiceMode.auto) return;

    _clearAutoTimer();
    if (_speechService.isListening) {
      unawaited(_speechService.stop());
    }
  }

  Future<void> _handleMicPressed() async {
    if (_mode != VoiceMode.push) {
      _clearAutoTimer();
      setState(() => _mode = VoiceMode.push);
    }

    if (_isListening) {
      await _stopListening();
      return;
    }

    await _startListening();
  }

  Future<void> _handleMicLongPressed() async {
    if (_mode != VoiceMode.auto) {
      setState(() => _mode = VoiceMode.auto);
    }

    if (_isListening || _isBusy || _hasPendingEntry) return;
    await _startListening();
  }

  Future<void> _startListening() async {
    if (_mode == VoiceMode.auto) {
      _resetAutoSilenceTimer();
    }

    setState(() {
      _speechError = null;
      _speechStatus = 'กำลังขอสิทธิ์ไมโครโฟน...';
      _speechTranscript = null;
    });

    final available = await _speechService.initialize(
      onStatus: _handleSpeechStatus,
      onError: _handleSpeechError,
    );

    if (!mounted) return;
    if (!available) {
      _clearAutoTimer();
      setState(() {
        _isListening = false;
        _speechStatus = null;
        _speechError = 'ไม่สามารถเปิด speech recognition ได้';
      });
      return;
    }

    setState(() {
      _isListening = true;
      _speechStatus = _mode == VoiceMode.auto
          ? 'Auto กำลังฟัง จะหยุดเมื่อไม่มีเสียงพูด 2 นาที'
          : 'พูดรายการบัญชีได้เลย';
    });

    try {
      await _listenOnce();
    } catch (error) {
      if (!mounted) return;
      _clearAutoTimer();
      setState(() {
        _isListening = false;
        _speechStatus = null;
        _speechError = '$error';
      });
    }
  }

  Future<void> _listenOnce() {
    return _speechService.startListening(
      onText: _handleSpeechText,
      listenFor: _mode == VoiceMode.auto
          ? _autoSessionDuration
          : const Duration(seconds: 30),
      pauseFor: _mode == VoiceMode.auto
          ? _autoSilenceTimeout
          : const Duration(seconds: 4),
    );
  }

  Future<void> _stopListening({String? status}) async {
    _clearAutoTimer();
    await _speechService.stop();
    if (!mounted) return;
    setState(() {
      _isListening = false;
      _speechStatus = status;
    });
  }

  void _clearAutoTimer() {
    _autoStopTimer?.cancel();
    _autoStopTimer = null;
    _autoRestarting = false;
  }

  void _resetAutoSilenceTimer() {
    if (_mode != VoiceMode.auto) return;

    _autoStopTimer?.cancel();
    _autoStopTimer = Timer(_autoSilenceTimeout, () {
      if (mounted && _mode == VoiceMode.auto) {
        _stopListening(
          status: 'Auto หยุดฟังแล้ว เพราะไม่มีเสียงพูด 2 นาที',
        );
      }
    });
  }

  Future<void> _restartAutoListeningIfNeeded() async {
    if (_mode != VoiceMode.auto ||
        _autoStopTimer == null ||
        _autoRestarting ||
        _isSubmittingSpeech ||
        _hasPendingEntry) {
      return;
    }

    _autoRestarting = true;
    try {
      await _speechService.stop();
      if (!mounted || _mode != VoiceMode.auto) return;
      setState(() {
        _isListening = true;
        _speechStatus = 'Auto กำลังฟัง จะหยุดเมื่อไม่มีเสียงพูด 2 นาที';
      });
      await _listenOnce();
    } catch (error) {
      if (!mounted) return;
      _clearAutoTimer();
      setState(() {
        _isListening = false;
        _speechStatus = null;
        _speechError = '$error';
      });
    } finally {
      _autoRestarting = false;
    }
  }

  void _handleSpeechStatus(String status) {
    if (!mounted) return;
    setState(() {
      _speechStatus = _speechStatusText(status);
      _isListening = _speechService.isListening;
    });

    if ((status == 'done' || status == 'notListening') &&
        _mode == VoiceMode.auto) {
      unawaited(_restartAutoListeningIfNeeded());
    }
  }

  void _handleSpeechError(String message) {
    if (!mounted) return;
    _clearAutoTimer();
    setState(() {
      _isListening = false;
      _speechStatus = null;
      _speechError = _friendlySpeechError(message);
    });
  }

  Future<void> _handleSpeechText(String text, bool isFinal) async {
    if (!mounted || text.isEmpty) return;

    setState(() {
      _speechTranscript = text;
      _textController.text = text;
      _textController.selection = TextSelection.collapsed(offset: text.length);
    });
    if (_mode == VoiceMode.auto) {
      _resetAutoSilenceTimer();
    }

    if (!isFinal || _isSubmittingSpeech) return;

    if (!_canAutoSaveSpeechText(text)) {
      setState(() {
        _speechStatus =
            'ถอดเสียงได้ไม่ชัดพอ ยังไม่บันทึก กรุณาลองพูดใหม่หรือแก้ข้อความแล้วกดบันทึก';
      });
      if (_mode == VoiceMode.auto) {
        unawaited(_restartAutoListeningIfNeeded());
      }
      return;
    }

    _isSubmittingSpeech = true;
    setState(() {
      _isListening = false;
      _speechStatus = 'ถอดเสียงเสร็จ กำลังทำเป็น tag ให้ตรวจ...';
    });

    try {
      await _submitText(text);
      if (!mounted) return;
      _pauseAutoForReview();
      setState(() {
        _speechStatus = 'ตรวจ tag แล้วกดบันทึก หรือกด x เพื่อลบรายการที่ผิด';
      });
    } finally {
      if (mounted) {
        setState(() => _isSubmittingSpeech = false);
        if (_mode == VoiceMode.auto && !_hasPendingEntry) {
          unawaited(_restartAutoListeningIfNeeded());
        }
      }
    }
  }

  bool _canAutoSaveSpeechText(String text) {
    final hasThai = RegExp(r'[\u0E00-\u0E7F]').hasMatch(text);
    final hasAmount = RegExp(r'\d').hasMatch(text);
    return hasThai &&
        (hasAmount && !_looksLikeShoppingMeasurementText(text) ||
            _looksLikeShoppingListText(text));
  }

  bool _looksLikeShoppingListText(String text) {
    final cleaned = text
        .replaceAll(
          RegExp(r'(ซื้อ|รายการ|เพิ่ม|ลิสต์|list|ไว้|ใน)',
              caseSensitive: false),
          ' ',
        )
        .replaceAll(RegExp(r'[,;|]+'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    return cleaned.isNotEmpty &&
        (!RegExp(r'\d').hasMatch(cleaned) ||
            _looksLikeShoppingMeasurementText(cleaned));
  }

  bool _looksLikeShoppingMeasurementText(String text) {
    final hasMeasurement = RegExp(
      r'\d+(?:\.\d+)?\s*(นิ้ว|เมตร|ซม\.?|เซน|มม\.?|หุน|กิโล|โล|กก\.?|ชิ้น|อัน|เส้น|แผ่น|ม้วน|แพ็ค|กล่อง|ถุง|ขวด)',
      caseSensitive: false,
    ).hasMatch(text);
    final hasPrice = RegExp(
      r'(บาท|บ\.|฿|ราคา|รวม|ทั้งหมด)',
      caseSensitive: false,
    ).hasMatch(text);
    return hasMeasurement && !hasPrice;
  }

  String _combineRawText(String current, String next) {
    final first = current.trim();
    final second = next.trim();
    if (first.isEmpty) return second;
    if (second.isEmpty) return first;
    return '$first\n$second';
  }

  String _speechStatusText(String status) {
    switch (status) {
      case 'listening':
        return 'กำลังฟัง...';
      case 'done':
      case 'notListening':
        return 'หยุดฟังแล้ว';
      default:
        return status;
    }
  }

  String _friendlySpeechError(String message) {
    final lower = message.toLowerCase();
    if (lower.contains('not-allowed') ||
        lower.contains('permission') ||
        lower.contains('denied')) {
      return 'ยังใช้ไมค์ไม่ได้: เปิดสิทธิ์ไมโครโฟนให้ localhost ใน browser แล้ว refresh หน้า';
    }
    if (lower.contains('not-found') || lower.contains('audio-capture')) {
      return 'ไม่พบไมโครโฟน กรุณาเช็กไมค์ของเครื่องหรือ browser';
    }
    return message;
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.eazyColors;
    final totals = MoneyTotals.fromEntries(widget.entries);

    return Scaffold(
      appBar: AppBar(
        title: const Text('EazyAccount'),
        actions: [
          IconButton(
            tooltip: widget.isDarkMode ? 'เปิดโหมดสว่าง' : 'เปิดโหมดกลางคืน',
            onPressed: widget.onToggleThemeMode,
            icon: Icon(
              widget.isDarkMode
                  ? Icons.light_mode_rounded
                  : Icons.dark_mode_rounded,
            ),
          ),
          IconButton(
            tooltip: 'รีเฟรช',
            onPressed: widget.isLoading ? null : widget.onRefresh,
            icon: const Icon(Icons.refresh_rounded),
          ),
          IconButton(
            tooltip: 'ดูรายละเอียด',
            onPressed: widget.onOpenDetails,
            icon: const Icon(Icons.receipt_long_rounded),
          ),
        ],
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: widget.onRefresh,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
            children: [
              SummaryDashboard(
                income: totals.income,
                expense: totals.expense,
                balance: totals.balance,
              ),
              const SizedBox(height: 14),
              SpeechButton(
                mode: _mode,
                isListening: _isListening,
                isSaving: widget.isSaving || _isSubmittingSpeech,
                onMicTap: _handleMicPressed,
                onMicLongPress: _handleMicLongPressed,
                transcript: _speechTranscript,
                status: _speechStatus,
                errorMessage: _speechError,
              ),
              if (_pendingEntry != null) ...[
                const SizedBox(height: 14),
                ParsedTagsCard(
                  entry: _pendingEntry!,
                  isSaving: widget.isSaving,
                  onRemoveItem: _removePendingItem,
                  onSave: _savePendingEntry,
                  onCancel: _cancelPendingEntry,
                ),
              ],
              const SizedBox(height: 10),
              _ManualEntryCard(
                controller: _textController,
                isSaving: widget.isSaving,
                isBusy: _isBusy,
                onSubmit: _submitText,
              ),
              if (widget.errorMessage != null) ...[
                const SizedBox(height: 12),
                Text(
                  widget.errorMessage!,
                  style: TextStyle(
                    color: colors.expense,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
              const SizedBox(height: 22),
              if (widget.isLoading)
                const Center(child: CircularProgressIndicator())
              else
                HistoryList(entries: widget.entries),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: widget.onOpenDetails,
                icon: const Icon(Icons.arrow_forward_rounded),
                label: const Text('ดูรายละเอียดทั้งหมด'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ignore: unused_element
class _StoreHero extends StatelessWidget {
  const _StoreHero({
    required this.balance,
    required this.entryCount,
    required this.isDarkMode,
    required this.onToggleThemeMode,
  });

  final num balance;
  final int entryCount;
  final bool isDarkMode;
  final VoidCallback onToggleThemeMode;

  @override
  Widget build(BuildContext context) {
    final colors = context.eazyColors;
    final textTheme = Theme.of(context).textTheme;

    return Container(
      decoration: BoxDecoration(
        color: colors.hero,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: colors.border),
        boxShadow: [
          BoxShadow(
            color: colors.shadow,
            blurRadius: 18,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                height: 44,
                width: 44,
                decoration: BoxDecoration(
                  color: Theme.of(context)
                      .colorScheme
                      .primary
                      .withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  Icons.storefront_rounded,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'บัญชีหน้าร้านวันนี้',
                      style: textTheme.titleMedium?.copyWith(
                        color: colors.ink,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'พูดเหมือนตอนขายจริง ระบบแยกรายรับรายจ่ายให้',
                      style: textTheme.bodySmall?.copyWith(color: colors.muted),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Text(
            '${formatMoney(balance)} บาท',
            style: textTheme.headlineMedium?.copyWith(
              color: balance >= 0 ? colors.income : colors.expense,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'ยอดคงเหลือจาก $entryCount รายการล่าสุด',
            style: textTheme.bodyMedium?.copyWith(
              color: colors.muted,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 14),
          const Row(
            children: [
              Expanded(
                child: _HeroPill(
                  icon: Icons.restaurant_menu_rounded,
                  label: 'ขายอาหาร',
                  value: 'ข้าว น้ำ กับข้าว',
                ),
              ),
              SizedBox(width: 8),
              Expanded(
                child: _HeroPill(
                  icon: Icons.local_mall_rounded,
                  label: 'แม่ค้า',
                  value: 'ของสด ถุง ค่าส่ง',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _HeroPill extends StatelessWidget {
  const _HeroPill({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final colors = context.eazyColors;

    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: colors.surface.withValues(alpha: 0.76),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: colors.border),
      ),
      child: Row(
        children: [
          Icon(icon, color: Theme.of(context).colorScheme.primary, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    color: colors.ink,
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: colors.muted,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ManualEntryCard extends StatelessWidget {
  const _ManualEntryCard({
    required this.controller,
    required this.isSaving,
    required this.isBusy,
    required this.onSubmit,
  });

  final TextEditingController controller;
  final bool isSaving;
  final bool isBusy;
  final Future<void> Function([String? rawText]) onSubmit;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: controller,
              minLines: 1,
              maxLines: 2,
              textInputAction: TextInputAction.done,
              decoration: const InputDecoration(
                labelText: 'รายการภาษาไทย',
                hintText: 'เช่น ซื้อหมู 500 ผัก 200',
              ),
              onSubmitted: (_) {
                if (!isBusy) onSubmit();
              },
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: isSaving ? null : onSubmit,
                icon: isSaving
                    ? const SizedBox.square(
                        dimension: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.sell_rounded),
                label: Text(isSaving ? 'กำลัง parse...' : 'ทำเป็น tag'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
