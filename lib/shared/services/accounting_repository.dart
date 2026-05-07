import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase/supabase.dart';

import '../models/member_profile.dart';
import '../models/money_entry.dart';
import '../models/parsed_money_entry.dart';
import 'supabase_config.dart';

class AccountingRepository {
  AccountingRepository(this._client);

  static const _sessionStorageKey = 'eazyaccount.supabase.session.v1';
  static const _pendingEntriesStorageKey = 'eazyaccount.pending.entries.v1';
  static const _memberColumns =
      'id, email, display_name, shop_name, phone, member_plan, member_status, created_at, updated_at';
  static const _knownShoppingListWords = [
    'น้ำแข็ง',
    'น้ำปลา',
    'น้ำตาล',
    'น้ำมัน',
    'แก้วน้ำ',
    'ผักชี',
    'ฝักชี',
    'ฝรั่ง',
    'มาม่า',
    'บะหมี่',
    'แก้ว',
    'ข้าว',
    'หมู',
    'ไก่',
    'ปลา',
    'ผัก',
    'นม',
    'ไข่',
    'ถุง',
    'น้ำ',
  ];

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
    required String displayName,
  }) async {
    final cleanDisplayName = displayName.trim();
    final response = await _client.auth.signUp(
      email: email.trim(),
      password: password,
      data: cleanDisplayName.isEmpty
          ? null
          : {
              'display_name': cleanDisplayName,
              'shop_name': cleanDisplayName,
            },
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

  Future<MemberProfile> fetchCurrentMember() async {
    final user = _requireCurrentUser('กรุณาเข้าสู่ระบบก่อนโหลดข้อมูลสมาชิก');
    final row = await _client
        .from('users')
        .select(_memberColumns)
        .eq('id', user.id)
        .maybeSingle();

    return _memberFromRow(row);
  }

  Future<MemberProfile> updateMemberProfile({
    required String displayName,
    required String shopName,
    required String phone,
  }) async {
    final user = _requireCurrentUser('กรุณาเข้าสู่ระบบก่อนแก้ไขข้อมูลสมาชิก');
    final row = await _client
        .from('users')
        .update({
          'display_name': displayName.trim(),
          'shop_name': shopName.trim(),
          'phone': phone.trim(),
        })
        .eq('id', user.id)
        .select(_memberColumns)
        .maybeSingle();

    return _memberFromRow(row);
  }

  Future<MemberProfile> changeMemberPlan(MemberPlan plan) async {
    final user = _requireCurrentUser('กรุณาเข้าสู่ระบบก่อนเปลี่ยนแพ็กเกจ');
    final row = await _client
        .from('users')
        .update({
          'member_plan': plan.value,
          'member_status': 'active',
          'plan_started_at': DateTime.now().toUtc().toIso8601String(),
        })
        .eq('id', user.id)
        .select(_memberColumns)
        .maybeSingle();

    return _memberFromRow(row);
  }

  Future<void> clearSavedSession() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_sessionStorageKey);
  }

  Future<List<MoneyEntry>> fetchEntries() async {
    final entryRows = await _client.rpc(
      'get_entries_page',
      params: {'page_size': 100},
    );

    if (entryRows is! List || entryRows.isEmpty) return const [];

    final entryIds = [
      for (final row in entryRows)
        if (row is Map && row['id'] != null) row['id'].toString(),
    ];
    if (entryIds.isEmpty) return const [];

    final itemRows = await _client
        .from('entry_items')
        .select('id, entry_id, name, amount, type, created_at')
        .inFilter('entry_id', entryIds)
        .order('created_at', ascending: false)
        .limit(500);

    return itemRows.reversed
        .map<MoneyEntry>((row) => MoneyEntry.fromEntryItem(row))
        .toList(growable: false);
  }

  Future<void> parseAndSave(String rawText) async {
    final parsed = await parseText(rawText);
    await addPendingParsedEntry(parsed);
  }

  Future<ParsedMoneyEntry> parseText(String rawText) async {
    final text = rawText.trim();
    if (text.isEmpty) {
      throw const FormatException('กรุณาพิมพ์รายการก่อนบันทึก');
    }

    _requireSignedIn('กรุณาเข้าสู่ระบบก่อนทำรายการ');

    final measuredPriceEntry = _parseMeasuredPriceText(text);
    if (measuredPriceEntry != null) return measuredPriceEntry;

    final shoppingListEntry =
        AccountingRepository.tryParseShoppingListText(text);
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

  Future<List<MoneyEntry>> fetchPendingEntries() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_currentPendingEntriesStorageKey);
    if (raw == null || raw.isEmpty) return const [];

    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return const [];
      return decoded
          .whereType<Map>()
          .map((item) => MoneyEntry.fromJson(Map<String, dynamic>.from(item)))
          .where((entry) => entry.id.isNotEmpty)
          .toList(growable: false);
    } catch (_) {
      return const [];
    }
  }

  Future<List<MoneyEntry>> addPendingParsedEntry(ParsedMoneyEntry entry) async {
    final text = entry.rawText.trim();
    if (text.isEmpty) {
      throw const FormatException('ไม่มีข้อความต้นฉบับสำหรับบันทึก');
    }
    if (entry.items.isEmpty) {
      throw const FormatException('ไม่มี tag ที่เหลือให้บันทึก');
    }

    _requireSignedIn('กรุณาเข้าสู่ระบบก่อนบันทึกรายการ');

    final now = DateTime.now();
    final baseId = now.microsecondsSinceEpoch;
    final nextEntries = [
      ...await fetchPendingEntries(),
      for (var index = 0; index < entry.items.length; index++)
        MoneyEntry(
          id: 'pending-$baseId-$index',
          title: entry.items[index].name,
          amount: entry.items[index].amount,
          type: entry.items[index].type,
          createdAt: now,
          isPending: true,
        ),
    ];
    await _savePendingEntries(nextEntries);
    return nextEntries;
  }

  Future<List<MoneyEntry>> togglePendingEntry(String id) async {
    final entries = await fetchPendingEntries();
    final nextEntries = [
      for (final entry in entries)
        entry.id == id
            ? entry.copyWith(isDiscarded: !entry.isDiscarded)
            : entry,
    ];
    await _savePendingEntries(nextEntries);
    return nextEntries;
  }

  Future<List<MoneyEntry>> flushDuePendingEntries({DateTime? now}) async {
    final pendingEntries = await fetchPendingEntries();
    if (pendingEntries.isEmpty) return pendingEntries;

    final today = _dayKey(now ?? DateTime.now());
    final dueEntries = pendingEntries
        .where((entry) => _dayKey(entry.createdAt).isBefore(today))
        .toList(growable: false);
    if (dueEntries.isEmpty) return pendingEntries;

    final remainingEntries = pendingEntries
        .where((entry) => !_dayKey(entry.createdAt).isBefore(today))
        .toList(growable: false);
    final entriesToSave =
        dueEntries.where((entry) => !entry.isDiscarded).toList(growable: false);

    if (entriesToSave.isNotEmpty) {
      await saveParsedEntry(
        ParsedMoneyEntry(
          rawText: entriesToSave.map((entry) => entry.title).join('\n'),
          items: [
            for (final entry in entriesToSave)
              ParsedMoneyItem(
                name: entry.title,
                amount: entry.amount,
                type: entry.type,
              ),
          ],
        ),
      );
    }

    await _savePendingEntries(remainingEntries);
    return remainingEntries;
  }

  void _requireSignedIn(String message) {
    if (!isSignedIn) {
      throw AuthException(message);
    }
  }

  Future<void> _savePendingEntries(List<MoneyEntry> entries) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _currentPendingEntriesStorageKey,
      jsonEncode(entries.map((entry) => entry.toJson()).toList()),
    );
  }

  String get _currentPendingEntriesStorageKey {
    final userId = _client.auth.currentUser?.id ?? _accessToken ?? 'anonymous';
    return '$_pendingEntriesStorageKey.$userId';
  }

  DateTime _dayKey(DateTime value) {
    return DateTime(value.year, value.month, value.day);
  }

  User _requireCurrentUser(String message) {
    _requireSignedIn(message);
    final user = _client.auth.currentUser;
    if (user == null) {
      throw AuthException(message);
    }
    return user;
  }

  MemberProfile _memberFromRow(Map<String, dynamic>? row) {
    if (row == null) {
      throw StateError('ไม่พบข้อมูลสมาชิกของบัญชีนี้');
    }
    return MemberProfile.fromJson(Map<String, dynamic>.from(row));
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

  static ParsedMoneyEntry? tryParseShoppingListText(String text) {
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
        .replaceAll(RegExp(r'[\r\n/,;|、，]+'), ' ')
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
    for (final name in _splitShoppingListNames(cleanedText)) {
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

  static List<String> _splitShoppingListNames(String text) {
    final names = <String>[];
    for (final chunk in text.split(' ')) {
      final value = chunk.trim();
      if (value.isEmpty) continue;
      names.addAll(_splitKnownShoppingListWords(value));
    }
    return names;
  }

  static List<String> _splitKnownShoppingListWords(String value) {
    final names = <String>[];
    var remaining = value;

    while (remaining.isNotEmpty) {
      String? matchedName;
      for (final word in _knownShoppingListWords) {
        if (remaining.startsWith(word)) {
          matchedName = word;
          break;
        }
      }

      if (matchedName == null) return [value];
      names.add(matchedName);
      remaining = remaining.substring(matchedName.length);
    }

    return names.length > 1 ? names : [value];
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

  static bool _hasShoppingMeasurement(String text) {
    return RegExp(
      r'\d+(?:\.\d+)?\s*(นิ้ว|เมตร|ซม\.?|เซน|มม\.?|หุน|กิโล|โล|กก\.?|ชิ้น|อัน|เส้น|แผ่น|ม้วน|แพ็ค|กล่อง|ถุง|ขวด)',
      caseSensitive: false,
    ).hasMatch(text);
  }

  static bool _hasMoneyPriceText(String text) {
    return RegExp(
      r'(บาท|บ\.|฿|ราคา|รวม|ทั้งหมด)',
      caseSensitive: false,
    ).hasMatch(text);
  }

  static String _normalizeShoppingItemName(String text) {
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

  static String _stripShoppingCommandWords(String text) {
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
