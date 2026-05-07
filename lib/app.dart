import 'dart:async';

import 'package:flutter/material.dart';

import 'features/auth/auth_screen.dart';
import 'features/details/detail_screen.dart';
import 'features/home/home_screen.dart';
import 'features/settings/settings_screen.dart';
import 'features/summary/summary_screen.dart';
import 'shared/models/member_profile.dart';
import 'shared/models/money_entry.dart';
import 'shared/models/parsed_money_entry.dart';
import 'shared/services/accounting_repository.dart';
import 'shared/theme/app_theme.dart';

class EazyAccountApp extends StatefulWidget {
  const EazyAccountApp({super.key, required this.repository});

  final AccountingRepository repository;

  @override
  State<EazyAccountApp> createState() => _EazyAccountAppState();
}

class _EazyAccountAppState extends State<EazyAccountApp> {
  ThemeMode _themeMode = ThemeMode.light;

  void _toggleThemeMode() {
    setState(() {
      _themeMode =
          _themeMode == ThemeMode.dark ? ThemeMode.light : ThemeMode.dark;
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'EazyAccount',
      debugShowCheckedModeBanner: false,
      theme: buildAppTheme(),
      darkTheme: buildAppDarkTheme(),
      themeMode: _themeMode,
      home: AuthGate(
        repository: widget.repository,
        isDarkMode: _themeMode == ThemeMode.dark,
        onToggleThemeMode: _toggleThemeMode,
      ),
    );
  }
}

class AuthGate extends StatefulWidget {
  const AuthGate({
    super.key,
    required this.repository,
    required this.isDarkMode,
    required this.onToggleThemeMode,
  });

  final AccountingRepository repository;
  final bool isDarkMode;
  final VoidCallback onToggleThemeMode;

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  bool _isSignedIn = false;
  bool _isCheckingAuth = true;
  String? _authError;

  @override
  void initState() {
    super.initState();
    _restoreSession();
  }

  Future<void> _restoreSession() async {
    final isSignedIn = await widget.repository.restoreSavedSession();
    if (!mounted) return;
    setState(() {
      _isSignedIn = isSignedIn;
      _isCheckingAuth = false;
    });
  }

  Future<void> _signIn(String email, String password) async {
    setState(() => _authError = null);

    try {
      await widget.repository.signInWithEmailPassword(
        email: email,
        password: password,
      );
      if (mounted) setState(() => _isSignedIn = true);
    } catch (error) {
      if (mounted) setState(() => _authError = '$error');
    }
  }

  Future<void> _signUp(
    String email,
    String password,
    String displayName,
  ) async {
    setState(() => _authError = null);

    try {
      await widget.repository.signUpWithEmailPassword(
        email: email,
        password: password,
        displayName: displayName,
      );
      if (mounted) setState(() => _isSignedIn = true);
    } catch (error) {
      if (mounted) setState(() => _authError = '$error');
    }
  }

  Future<void> _signOut() async {
    await widget.repository.signOut();
    if (mounted) setState(() => _isSignedIn = false);
  }

  @override
  Widget build(BuildContext context) {
    if (_isCheckingAuth) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (!_isSignedIn) {
      return AuthScreen(
        errorMessage: _authError,
        onSignIn: _signIn,
        onSignUp: _signUp,
      );
    }

    return AppShell(
      repository: widget.repository,
      onSignOut: _signOut,
      isDarkMode: widget.isDarkMode,
      onToggleThemeMode: widget.onToggleThemeMode,
    );
  }
}

class AppShell extends StatefulWidget {
  const AppShell({
    super.key,
    required this.repository,
    required this.onSignOut,
    required this.isDarkMode,
    required this.onToggleThemeMode,
  });

  final AccountingRepository repository;
  final Future<void> Function() onSignOut;
  final bool isDarkMode;
  final VoidCallback onToggleThemeMode;

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int _selectedIndex = 0;
  bool _isLoading = true;
  bool _isSaving = false;
  bool _isMemberLoading = true;
  bool _isMemberSaving = false;
  String? _errorMessage;
  String? _memberError;
  List<MoneyEntry> _savedEntries = const [];
  List<MoneyEntry> _pendingEntries = const [];
  MemberProfile? _member;
  Timer? _midnightTimer;

  List<MoneyEntry> get _entries => [..._savedEntries, ..._pendingEntries];

  @override
  void initState() {
    super.initState();
    _loadEntries();
    _loadMember();
    _scheduleMidnightFlush();
  }

  @override
  void dispose() {
    _midnightTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadEntries() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      await widget.repository.flushDuePendingEntries();
      final entries = await widget.repository.fetchEntries();
      final pendingEntries = await widget.repository.fetchPendingEntries();
      if (!mounted) return;
      setState(() {
        _savedEntries = entries;
        _pendingEntries = pendingEntries;
      });
    } catch (error) {
      if (mounted) setState(() => _errorMessage = '$error');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _flushPendingEntries() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      await widget.repository.flushDuePendingEntries();
      final entries = await widget.repository.fetchEntries();
      final pendingEntries = await widget.repository.fetchPendingEntries();
      if (!mounted) return;
      setState(() {
        _savedEntries = entries;
        _pendingEntries = pendingEntries;
      });
    } catch (error) {
      if (mounted) setState(() => _errorMessage = '$error');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
        _scheduleMidnightFlush();
      }
    }
  }

  Future<void> _loadMember() async {
    setState(() {
      _isMemberLoading = true;
      _memberError = null;
    });

    try {
      final member = await widget.repository.fetchCurrentMember();
      if (!mounted) return;
      setState(() => _member = member);
    } catch (error) {
      if (mounted) setState(() => _memberError = '$error');
    } finally {
      if (mounted) setState(() => _isMemberLoading = false);
    }
  }

  Future<ParsedMoneyEntry> _previewRawText(String rawText) async {
    setState(() {
      _isSaving = true;
      _errorMessage = null;
    });

    try {
      return await widget.repository.parseText(rawText);
    } catch (error) {
      if (mounted) setState(() => _errorMessage = '$error');
      rethrow;
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _saveParsedEntry(ParsedMoneyEntry entry) async {
    setState(() {
      _isSaving = true;
      _errorMessage = null;
    });

    try {
      final pendingEntries =
          await widget.repository.addPendingParsedEntry(entry);
      if (!mounted) return;
      setState(() => _pendingEntries = pendingEntries);
    } catch (error) {
      if (mounted) setState(() => _errorMessage = '$error');
      rethrow;
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _togglePendingEntry(String id) async {
    setState(() => _errorMessage = null);

    try {
      final pendingEntries = await widget.repository.togglePendingEntry(id);
      if (!mounted) return;
      setState(() => _pendingEntries = pendingEntries);
    } catch (error) {
      if (mounted) setState(() => _errorMessage = '$error');
    }
  }

  void _scheduleMidnightFlush() {
    _midnightTimer?.cancel();
    final now = DateTime.now();
    final nextMidnight = DateTime(now.year, now.month, now.day + 1);
    _midnightTimer = Timer(nextMidnight.difference(now), _flushPendingEntries);
  }

  Future<MemberProfile> _updateMemberProfile({
    required String displayName,
    required String shopName,
    required String phone,
  }) async {
    setState(() {
      _isMemberSaving = true;
      _memberError = null;
    });

    try {
      final member = await widget.repository.updateMemberProfile(
        displayName: displayName,
        shopName: shopName,
        phone: phone,
      );
      if (mounted) setState(() => _member = member);
      return member;
    } catch (error) {
      if (mounted) setState(() => _memberError = '$error');
      rethrow;
    } finally {
      if (mounted) setState(() => _isMemberSaving = false);
    }
  }

  Future<MemberProfile> _changeMemberPlan(MemberPlan plan) async {
    setState(() {
      _isMemberSaving = true;
      _memberError = null;
    });

    try {
      final member = await widget.repository.changeMemberPlan(plan);
      if (mounted) setState(() => _member = member);
      return member;
    } catch (error) {
      if (mounted) setState(() => _memberError = '$error');
      rethrow;
    } finally {
      if (mounted) setState(() => _isMemberSaving = false);
    }
  }

  Future<void> _signOut() async {
    await widget.onSignOut();
  }

  @override
  Widget build(BuildContext context) {
    final pages = [
      HomeScreen(
        entries: _entries,
        isLoading: _isLoading,
        isSaving: _isSaving,
        errorMessage: _errorMessage,
        onRefresh: _loadEntries,
        onPreviewText: _previewRawText,
        onSaveParsedEntry: _saveParsedEntry,
        onTogglePendingEntry: _togglePendingEntry,
        onOpenDetails: () => setState(() => _selectedIndex = 1),
        isDarkMode: widget.isDarkMode,
        onToggleThemeMode: widget.onToggleThemeMode,
      ),
      DetailScreen(
        entries: _entries,
        isLoading: _isLoading,
        onRefresh: _loadEntries,
        onTogglePendingEntry: _togglePendingEntry,
      ),
      SummaryScreen(entries: _entries),
      SettingsScreen(
        member: _member,
        isMemberLoading: _isMemberLoading,
        isMemberSaving: _isMemberSaving,
        memberError: _memberError,
        onRefreshMember: _loadMember,
        onUpdateMemberProfile: _updateMemberProfile,
        onChangeMemberPlan: _changeMemberPlan,
        onSignOut: _signOut,
      ),
    ];

    return Scaffold(
      body: IndexedStack(index: _selectedIndex, children: pages),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: (index) =>
            setState(() => _selectedIndex = index),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home_rounded),
            label: 'Home',
          ),
          NavigationDestination(
            icon: Icon(Icons.table_rows_outlined),
            selectedIcon: Icon(Icons.table_rows_rounded),
            label: 'รายละเอียด',
          ),
          NavigationDestination(
            icon: Icon(Icons.bar_chart_outlined),
            selectedIcon: Icon(Icons.bar_chart_rounded),
            label: 'รายงาน',
          ),
          NavigationDestination(
            icon: Icon(Icons.settings_outlined),
            selectedIcon: Icon(Icons.settings_rounded),
            label: 'ตั้งค่า',
          ),
        ],
      ),
    );
  }
}
