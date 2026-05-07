import 'package:flutter/material.dart';

import '../../shared/models/member_profile.dart';
import '../../shared/theme/app_theme.dart';

typedef MemberProfileUpdater = Future<MemberProfile> Function({
  required String displayName,
  required String shopName,
  required String phone,
});

class MemberProfileScreen extends StatefulWidget {
  const MemberProfileScreen({
    super.key,
    required this.member,
    required this.onSave,
  });

  final MemberProfile member;
  final MemberProfileUpdater onSave;

  @override
  State<MemberProfileScreen> createState() => _MemberProfileScreenState();
}

class _MemberProfileScreenState extends State<MemberProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _displayNameController;
  late final TextEditingController _shopNameController;
  late final TextEditingController _phoneController;
  bool _isSaving = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _displayNameController = TextEditingController(
      text: widget.member.displayName,
    );
    _shopNameController = TextEditingController(text: widget.member.shopName);
    _phoneController = TextEditingController(text: widget.member.phone);
  }

  @override
  void dispose() {
    _displayNameController.dispose();
    _shopNameController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isSaving = true;
      _errorMessage = null;
    });

    try {
      final member = await widget.onSave(
        displayName: _displayNameController.text,
        shopName: _shopNameController.text,
        phone: _phoneController.text,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('บันทึกข้อมูลสมาชิกแล้ว')),
      );
      Navigator.of(context).pop(member);
    } catch (error) {
      if (mounted) setState(() => _errorMessage = '$error');
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.eazyColors;

    return Scaffold(
      appBar: AppBar(title: const Text('ข้อมูลสมาชิก')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
          children: [
            _MemberSummary(member: widget.member),
            const SizedBox(height: 16),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Form(
                  key: _formKey,
                  child: Column(
                    children: [
                      TextFormField(
                        initialValue: widget.member.email,
                        enabled: false,
                        decoration: const InputDecoration(
                          labelText: 'อีเมล',
                          prefixIcon: Icon(Icons.email_outlined),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _displayNameController,
                        enabled: !_isSaving,
                        textInputAction: TextInputAction.next,
                        decoration: const InputDecoration(
                          labelText: 'ชื่อสมาชิก',
                          prefixIcon: Icon(Icons.person_outline_rounded),
                        ),
                        validator: (value) {
                          if ((value ?? '').trim().isEmpty) {
                            return 'กรุณากรอกชื่อสมาชิก';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _shopNameController,
                        enabled: !_isSaving,
                        textInputAction: TextInputAction.next,
                        decoration: const InputDecoration(
                          labelText: 'ชื่อร้าน',
                          prefixIcon: Icon(Icons.storefront_outlined),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _phoneController,
                        enabled: !_isSaving,
                        keyboardType: TextInputType.phone,
                        textInputAction: TextInputAction.done,
                        decoration: const InputDecoration(
                          labelText: 'เบอร์โทร',
                          prefixIcon: Icon(Icons.phone_outlined),
                        ),
                        onFieldSubmitted: (_) {
                          if (!_isSaving) _save();
                        },
                      ),
                    ],
                  ),
                ),
              ),
            ),
            if (_errorMessage != null) ...[
              const SizedBox(height: 12),
              Text(
                _errorMessage!,
                style: TextStyle(
                  color: colors.expense,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
            const SizedBox(height: 18),
            FilledButton.icon(
              onPressed: _isSaving ? null : _save,
              icon: _isSaving
                  ? const SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.save_rounded),
              label: Text(_isSaving ? 'กำลังบันทึก...' : 'บันทึกข้อมูลสมาชิก'),
            ),
          ],
        ),
      ),
    );
  }
}

class _MemberSummary extends StatelessWidget {
  const _MemberSummary({required this.member});

  final MemberProfile member;

  @override
  Widget build(BuildContext context) {
    final colors = context.eazyColors;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            CircleAvatar(
              radius: 26,
              backgroundColor: colors.hero,
              foregroundColor: Theme.of(context).colorScheme.primary,
              child: const Icon(Icons.workspace_premium_rounded),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    member.nameForDisplay,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          color: colors.ink,
                          fontWeight: FontWeight.w900,
                        ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'แพ็กเกจ ${member.plan.label}',
                    style: TextStyle(
                      color: colors.muted,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
