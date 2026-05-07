import 'package:flutter/material.dart';

import '../../shared/theme/app_theme.dart';

class AuthScreen extends StatefulWidget {
  const AuthScreen({
    super.key,
    required this.onSignIn,
    required this.onSignUp,
    this.errorMessage,
  });

  final Future<void> Function(String email, String password) onSignIn;
  final Future<void> Function(
    String email,
    String password,
    String displayName,
  ) onSignUp;
  final String? errorMessage;

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final _formKey = GlobalKey<FormState>();
  final _displayNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isSigningUp = false;
  bool _isSubmitting = false;
  bool _obscurePassword = true;

  @override
  void dispose() {
    _displayNameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSubmitting = true);
    final displayName = _displayNameController.text.trim();
    final email = _emailController.text.trim();
    final password = _passwordController.text;

    if (_isSigningUp) {
      await widget.onSignUp(email, password, displayName);
    } else {
      await widget.onSignIn(email, password);
    }

    if (mounted) setState(() => _isSubmitting = false);
  }

  @override
  Widget build(BuildContext context) {
    final actionLabel = _isSigningUp ? 'สมัครสมาชิก' : 'เข้าสู่ระบบ';

    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(24, 32, 24, 24),
          children: [
            const CircleAvatar(
              radius: 28,
              backgroundColor: softTeal,
              foregroundColor: primaryColor,
              child: Icon(Icons.mic_rounded, size: 30),
            ),
            const SizedBox(height: 28),
            Text(
              'EazyAccount',
              style: Theme.of(context).textTheme.displaySmall?.copyWith(
                    color: inkColor,
                    fontWeight: FontWeight.w900,
                  ),
            ),
            const SizedBox(height: 10),
            Text(
              'บัญชีรายรับรายจ่ายสำหรับร้านเล็ก พูดหรือพิมพ์ภาษาไทยแล้วบันทึกเข้าบัญชีของคุณทันที',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: mutedColor,
                    height: 1.35,
                  ),
            ),
            const SizedBox(height: 32),
            SegmentedButton<bool>(
              segments: const [
                ButtonSegment(
                  value: false,
                  icon: Icon(Icons.login_rounded),
                  label: Text('เข้าสู่ระบบ'),
                ),
                ButtonSegment(
                  value: true,
                  icon: Icon(Icons.person_add_alt_1_rounded),
                  label: Text('สมัคร'),
                ),
              ],
              selected: {_isSigningUp},
              onSelectionChanged: _isSubmitting
                  ? null
                  : (selected) {
                      setState(() => _isSigningUp = selected.first);
                    },
            ),
            const SizedBox(height: 16),
            Form(
              key: _formKey,
              child: Column(
                children: [
                  if (_isSigningUp) ...[
                    TextFormField(
                      controller: _displayNameController,
                      enabled: !_isSubmitting,
                      textInputAction: TextInputAction.next,
                      decoration: const InputDecoration(
                        labelText: 'ชื่อสมาชิกหรือชื่อร้าน',
                        prefixIcon: Icon(Icons.storefront_outlined),
                      ),
                      validator: (value) {
                        if (!_isSigningUp) return null;
                        final name = value?.trim() ?? '';
                        if (name.isEmpty) {
                          return 'กรุณากรอกชื่อสมาชิกหรือชื่อร้าน';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 12),
                  ],
                  TextFormField(
                    controller: _emailController,
                    enabled: !_isSubmitting,
                    keyboardType: TextInputType.emailAddress,
                    autofillHints: const [AutofillHints.email],
                    textInputAction: TextInputAction.next,
                    decoration: const InputDecoration(
                      labelText: 'อีเมล',
                      prefixIcon: Icon(Icons.email_outlined),
                    ),
                    validator: (value) {
                      final email = value?.trim() ?? '';
                      if (email.isEmpty) return 'กรุณากรอกอีเมล';
                      if (!email.contains('@')) return 'อีเมลไม่ถูกต้อง';
                      return null;
                    },
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _passwordController,
                    enabled: !_isSubmitting,
                    obscureText: _obscurePassword,
                    autofillHints: const [AutofillHints.password],
                    textInputAction: TextInputAction.done,
                    decoration: InputDecoration(
                      labelText: 'รหัสผ่าน',
                      prefixIcon: const Icon(Icons.lock_outline_rounded),
                      suffixIcon: IconButton(
                        tooltip:
                            _obscurePassword ? 'แสดงรหัสผ่าน' : 'ซ่อนรหัสผ่าน',
                        onPressed: () {
                          setState(
                            () => _obscurePassword = !_obscurePassword,
                          );
                        },
                        icon: Icon(
                          _obscurePassword
                              ? Icons.visibility_outlined
                              : Icons.visibility_off_outlined,
                        ),
                      ),
                    ),
                    validator: (value) {
                      final password = value ?? '';
                      if (password.isEmpty) return 'กรุณากรอกรหัสผ่าน';
                      if (_isSigningUp && password.length < 8) {
                        return 'รหัสผ่านต้องมีอย่างน้อย 8 ตัวอักษร';
                      }
                      return null;
                    },
                    onFieldSubmitted: (_) {
                      if (!_isSubmitting) _submit();
                    },
                  ),
                ],
              ),
            ),
            if (widget.errorMessage != null) ...[
              const SizedBox(height: 12),
              Text(
                widget.errorMessage!,
                style: const TextStyle(
                  color: expenseColor,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
            const SizedBox(height: 18),
            FilledButton.icon(
              onPressed: _isSubmitting ? null : _submit,
              icon: _isSubmitting
                  ? const SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Icon(
                      _isSigningUp
                          ? Icons.person_add_alt_1_rounded
                          : Icons.login_rounded,
                    ),
              label: Text(_isSubmitting ? 'กำลังเชื่อมต่อ...' : actionLabel),
            ),
            const SizedBox(height: 14),
            Text(
              _isSigningUp
                  ? 'สมัครครั้งเดียว แล้วเปิดแอปครั้งต่อไปจะกลับมาหน้าไมค์อัตโนมัติ'
                  : 'ใช้บัญชีเดิมเพื่อโหลดข้อมูลร้านของคุณจาก Supabase',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: mutedColor,
                    fontWeight: FontWeight.w600,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}
