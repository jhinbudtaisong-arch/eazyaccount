import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase/supabase.dart';

import '../models/money_entry.dart';
import '../models/parsed_money_entry.dart';
import 'supabase_config.dart';

class AccountingRepository {
  AccountingRepository(this._client);

  static const _sessionStorageKey = 'eazyaccount.supabase.session.v1';

  final SupabaseClient _client;
  String? _accessToken;

  bool get isSignedIn => _accessToken != null;

  Future<bool> restoreSavedSession() async {
    final prefs = await SharedPreferences.getInstance();
    final sessionJson = prefs.getString(_sessionStorageKey);
    if (sessionJson == null || sessionJson.isEmpty) {
      _applyAuthHeaders(supabaseAnonKey);
      return false;
    }

    try {
      final response = await _client.auth.recoverSession(sessionJson);
      final session = response.session;
      final token = session?.accessToken;
      if (session == null || token == null || token.isEmpty) {
        await clearSavedSession();
        return false;
      }

      _accessToken = token;
      _applyAuthHeaders(token);
      await prefs.setString(_sessionStorageKey, jsonEncode(session.toJson()));
      return true;
    } catch (_) {
      await clearSavedSession();
      return false;
    }
  }

  Future<void> signInWithEmailPassword({
    required String email,
    required String password,
  }) async {
    final response = await _client.auth.signInWithPassword(
      email: email.trim(),
      password: password,
    );
    await _saveSession(response.session);
  }

  Future<void> signUpWithEmailPassword({
    required String email,
    required String password,
  }) async {
    final response = await _client.auth.signUp(
      email: email.trim(),
      password: password,
    );

    if (response.session == null) {
      throw const AuthException(
        'สมัครสำเร็จแล้ว กรุณายืนยันอีเมลก่อนเข้าสู่ระบบ',
      );
    }

    await _saveSession(response.session);
  }

  Future<void> signOut() async {
    _accessToken = null;
    _applyAuthHeaders(supabaseAnonKey);
    await clearSavedSession();
    await _client.auth.signOut();
  }

  Future<void> clearSavedSession() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_sessionStorageKey);
  }

  Future<List<MoneyEntry>> fetchEntries() async {
    final rows = await _client
        .from('entry_items')
        .select('id, name, amount, type, created_at')
        .order('created_at', ascending: false)
        .limit(100);

    return rows.reversed
        .map<MoneyEntry>((row) => MoneyEntry.fromEntryItem(row))
        .toList(growable: false);
  }

  Future<void> parseAndSave(String rawText) async {
    final text = rawText.trim();
    if (text.isEmpty) {
      throw const FormatException('กรุณาพิมพ์รายการก่อนบันทึก');
    }

    _requireSignedIn('กรุณาเข้าสู่ระบบก่อนบันทึกรายการ');

    final measuredPriceEntry = _parseMeasuredPriceText(text);
    if (measuredPriceEntry != null) {
      await saveParsedEntry(measuredPriceEntry);
      return;
    }

    final shoppingListEntry = _parseShoppingListText(text);
    if (shoppingListEntry != null) {
      await saveParsedEntry(shoppingListEntry);
      return;
    }

    final response = await _client.functions.invoke(
      'ai-engine',
      body: {
        'raw_text': text,
        'save': true,
      },
    );

    if (response.status >= 400) {
      throw StateError('บันทึกไม่สำเร็จ: ${response.data}');
    }
  }

  Future<ParsedMoneyEntry> parseText(String rawText) async {
    final text = rawText.trim();
    if (text.isEmpty) {
      throw const FormatException('กรุณาพิมพ์รายการก่อนบันทึก');
    }

    _requireSignedIn('กรุณาเข้าสู่ระบบก่อนทำรายการ');

    final measuredPriceEntry = _parseMeasuredPriceText(text);
    if (measuredPriceEntry != null) return measuredPriceEntry;

    final shoppingListEntry = _parseShoppingListText(text);
    if (shoppingListEntry != null) return shoppingListEntry;

    final response = await _client.functions.invoke(
      'ai-engine',
      body: {
        'raw_text': text,
        'save': false,
      },
    );

    if (response.status >= 400) {
      throw StateError(_friendlyFunctionError(
        'Parse ไม่สำเร็จ',
        response.data,
      ));
    }

    final data = response.data;
    if (data is! Map) {
      throw StateError('Parse ไม่สำเร็จ: response ไม่ถูกต้อง');
    }

    final parsed = ParsedMoneyEntry.fromJson(Map<String, dynamic>.from(data));
    if (parsed.items.isEmpty) {
      throw const FormatException('ไม่พบรายการที่อ่านได้');
    }
    return parsed;
  }

  Future<void> saveParsedEntry(ParsedMoneyEntry entry) async {
    final text = entry.rawText.trim();
    if (text.isEmpty) {
      throw const FormatException('ไม่มีข้อความต้นฉบับสำหรับบันทึก');
    }
    if (entry.items.isEmpty) {
      throw const FormatException('ไม่มี tag ที่เหลือให้บันทึก');
    }

    _requireSignedIn('กรุณาเข้าสู่ระบบก่อนบันทึกรายการ');

    await _client.rpc(
      'create_entry_with_items',
      params: {
        'p_raw_text': text,
        'p_items': entry.items.map((item) => item.toJson()).toList(),
      },
    );
  }

  void _requireSignedIn(String message) {
    if (!isSignedIn) {
      throw AuthException(message);
    }
  }

  void _applyAuthHeaders(String bearerToken) {
    _client.headers = {
      'apikey': supabaseAnonKey,
      'Authorization': 'Bearer $bearerToken',
    };
  }

  Future<void> _saveSession(Session? session) async {
    final token = session?.accessToken;
    if (session == null || token == null || token.isEmpty) {
      throw const AuthException('เข้าสู่ระบบไม่สำเร็จ');
    }

    _accessToken = token;
    _applyAuthHeaders(token);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_sessionStorageKey, jsonEncode(session.toJson()));
  }

  String _friendlyFunctionError(String prefix, Object? data) {
    final message = data.toString();
    if (message.contains('OPENAI_API_KEY is not set')) {
      return '$prefix: ระบบอ่านรูปใบเสร็จยังไม่ได้ตั้งค่า OPENAI_API_KEY '
          'ตอนนี้ยังใช้สแกนบิลไม่ได้ แต่ยังพิมพ์รายการแล้วกดทำเป็น tag ได้';
    }
    if (message.contains('insufficient_quota') ||
        message.contains('exceeded your current quota')) {
      return '$prefix: OpenAI API quota ไม่พอ กรุณาเช็ก billing/usage '
          'ของ API key หรือเปลี่ยน key ที่มีเครดิต';
    }
    return '$prefix: $data';
  }

  ParsedMoneyEntry? _parseShoppingListText(String text) {
    final hasNumber = RegExp(r'\d').hasMatch(text);
    final isMeasurementList =
        _hasShoppingMeasurement(text) && !_hasMoneyPriceText(text);
    if (hasNumber && !isMeasurementList) return null;

    final cleanedText = text
        .replaceAll(
          RegExp(
            r'^(ซื้อ|รายการ|เพิ่ม|ใส่|เอา|จด|ลิสต์|list)\s*',
            caseSensitive: false,
          ),
          '',
        )
        .replaceAll(
          RegExp(
            r'\s*(ไว้ในลิสต์|ลงลิสต์|เข้าลิสต์|ในลิสต์)$',
            caseSensitive: false,
          ),
          '',
        )
        .replaceAll(RegExp(r'[,;|]+'), ' ')
        .replaceAll(RegExp(r'\s+(และ|กับ)\s+'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();

    if (cleanedText.isEmpty) return null;

    if (isMeasurementList) {
      return ParsedMoneyEntry(
        rawText: text,
        items: [
          ParsedMoneyItem(
            name: _normalizeShoppingItemName(cleanedText),
            amount: 0,
            type: EntryType.expense,
          ),
        ],
      );
    }

    final names = <String>{};
    for (final name in cleanedText.split(' ')) {
      final value = name.trim();
      if (value.isNotEmpty) names.add(value);
    }

    if (names.isEmpty) return null;

    return ParsedMoneyEntry(
      rawText: text,
      items: [
        for (final name in names)
          ParsedMoneyItem(name: name, amount: 0, type: EntryType.expense),
      ],
    );
  }

  ParsedMoneyEntry? _parseMeasuredPriceText(String text) {
    final match = RegExp(
      r'^\s*(.+?\d+(?:\.\d+)?\s*(?:นิ้ว|เมตร|ซม\.?|เซน|มม\.?|หุน|กิโล|โล|กก\.?|ชิ้น|อัน|เส้น|แผ่น|ม้วน|แพ็ค|กล่อง|ถุง|ขวด))\s*(?:ราคา|รวม|ทั้งหมด)?\s*(\d+(?:,\d{3})*(?:\.\d+)?)\s*(?:บาท|บ\.|฿)\s*$',
      caseSensitive: false,
    ).firstMatch(text);

    if (match == null) return null;

    final name = _normalizeShoppingItemName(
      _stripShoppingCommandWords(match.group(1) ?? ''),
    );
    final amountText = (match.group(2) ?? '').replaceAll(',', '');
    final amount = num.tryParse(amountText);
    if (name.isEmpty || amount == null) return null;

    return ParsedMoneyEntry(
      rawText: text,
      items: [
        ParsedMoneyItem(name: name, amount: amount, type: EntryType.expense),
      ],
    );
  }

  bool _hasShoppingMeasurement(String text) {
    return RegExp(
      r'\d+(?:\.\d+)?\s*(นิ้ว|เมตร|ซม\.?|เซน|มม\.?|หุน|กิโล|โล|กก\.?|ชิ้น|อัน|เส้น|แผ่น|ม้วน|แพ็ค|กล่อง|ถุง|ขวด)',
      caseSensitive: false,
    ).hasMatch(text);
  }

  bool _hasMoneyPriceText(String text) {
    return RegExp(
      r'(บาท|บ\.|฿|ราคา|รวม|ทั้งหมด)',
      caseSensitive: false,
    ).hasMatch(text);
  }

  String _normalizeShoppingItemName(String text) {
    return text
        .replaceAllMapped(
          RegExp(r'([^\s\d])(\d)'),
          (match) => '${match[1]} ${match[2]}',
        )
        .replaceAllMapped(
          RegExp(r'(\d)([^\s\d])'),
          (match) => '${match[1]} ${match[2]}',
        )
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  String _stripShoppingCommandWords(String text) {
    return text
        .replaceAll(
          RegExp(
            r'^(ซื้อ|รายการ|เพิ่ม|ใส่|เอา|จด|ลิสต์|list)\s*',
            caseSensitive: false,
          ),
          '',
        )
        .trim();
  }
}
