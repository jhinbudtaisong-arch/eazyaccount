import 'package:flutter/material.dart';

import '../../shared/models/member_profile.dart';
import '../../shared/theme/app_theme.dart';

class SubscriptionScreen extends StatefulWidget {
  const SubscriptionScreen({
    super.key,
    required this.member,
    required this.isSaving,
    required this.onChangePlan,
  });

  final MemberProfile? member;
  final bool isSaving;
  final Future<MemberProfile> Function(MemberPlan plan) onChangePlan;

  @override
  State<SubscriptionScreen> createState() => _SubscriptionScreenState();
}

class _SubscriptionScreenState extends State<SubscriptionScreen> {
  MemberProfile? _member;
  bool _isSaving = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _member = widget.member;
    _isSaving = widget.isSaving;
  }

  @override
  void didUpdateWidget(covariant SubscriptionScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.member != oldWidget.member) {
      _member = widget.member;
    }
    if (widget.isSaving != oldWidget.isSaving) {
      _isSaving = widget.isSaving;
    }
  }

  Future<void> _changePlan(MemberPlan plan) async {
    if (_member?.plan == plan || _isSaving) return;

    setState(() {
      _isSaving = true;
      _errorMessage = null;
    });

    try {
      final member = await widget.onChangePlan(plan);
      if (!mounted) return;
      setState(() => _member = member);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('เปลี่ยนเป็นแพ็กเกจ ${plan.label} แล้ว')),
      );
    } catch (error) {
      if (mounted) setState(() => _errorMessage = '$error');
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentPlan = _member?.plan ?? MemberPlan.free;
    final colors = context.eazyColors;

    return Scaffold(
      appBar: AppBar(title: const Text('สมาชิก')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
          children: [
            SubscriptionHeader(member: _member),
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
            PlanCard(
              title: 'Free',
              price: '0 บาท',
              subtitle: 'เหมาะกับทดลองใช้และบันทึกร้านเล็ก',
              features: const [
                'บันทึกรายการด้วยเสียง',
                'ดูรายการล่าสุด',
                'รายงานวันนี้',
              ],
              selected: currentPlan == MemberPlan.free,
              isSaving: _isSaving,
              onPressed: () => _changePlan(MemberPlan.free),
            ),
            const SizedBox(height: 12),
            PlanCard(
              title: 'Pro',
              price: '99 บาท/เดือน',
              subtitle: 'สำหรับร้านที่ใช้ทุกวันและต้องการรายงานครบขึ้น',
              features: const [
                'รายงานสัปดาห์และเดือน',
                'สำรองข้อมูลอัตโนมัติ',
                'ส่งออกข้อมูล',
              ],
              highlighted: true,
              selected: currentPlan == MemberPlan.pro,
              isSaving: _isSaving,
              onPressed: () => _changePlan(MemberPlan.pro),
            ),
          ],
        ),
      ),
    );
  }
}

class SubscriptionHeader extends StatelessWidget {
  const SubscriptionHeader({super.key, required this.member});

  final MemberProfile? member;

  @override
  Widget build(BuildContext context) {
    final colors = context.eazyColors;
    final plan = member?.plan.label ?? 'Free';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'แพ็กเกจสมาชิก',
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                color: colors.ink,
                fontWeight: FontWeight.w800,
              ),
        ),
        const SizedBox(height: 6),
        Text(
          'แพ็กเกจปัจจุบัน: $plan',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: colors.muted,
                fontWeight: FontWeight.w700,
              ),
        ),
      ],
    );
  }
}

class PlanCard extends StatelessWidget {
  const PlanCard({
    super.key,
    required this.title,
    required this.price,
    required this.subtitle,
    required this.features,
    required this.selected,
    required this.isSaving,
    required this.onPressed,
    this.highlighted = false,
  });

  final String title;
  final String price;
  final String subtitle;
  final List<String> features;
  final bool highlighted;
  final bool selected;
  final bool isSaving;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final colors = context.eazyColors;
    final accent = highlighted ? amberAccent : primaryColor;

    return Card(
      color: highlighted ? accent.withValues(alpha: 0.12) : colors.surface,
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    title,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          color: colors.ink,
                          fontWeight: FontWeight.w900,
                        ),
                  ),
                ),
                if (selected)
                  Chip(
                    label: const Text('ใช้งานอยู่'),
                    labelStyle: TextStyle(
                      color: colors.ink,
                      fontWeight: FontWeight.w800,
                    ),
                    backgroundColor: colors.surfaceAlt,
                    side: BorderSide.none,
                  )
                else if (highlighted)
                  const Chip(
                    label: Text('แนะนำ'),
                    backgroundColor: amberAccent,
                    side: BorderSide.none,
                  ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              price,
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    color: accent,
                    fontWeight: FontWeight.w900,
                  ),
            ),
            const SizedBox(height: 4),
            Text(subtitle, style: TextStyle(color: colors.muted)),
            const SizedBox(height: 14),
            ...features.map(
              (feature) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: [
                    Icon(Icons.check_circle_rounded, color: accent, size: 18),
                    const SizedBox(width: 8),
                    Expanded(child: Text(feature)),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8),
            FilledButton(
              onPressed: selected || isSaving ? null : onPressed,
              style: FilledButton.styleFrom(backgroundColor: accent),
              child: Text(
                selected
                    ? 'ใช้งานอยู่'
                    : isSaving
                        ? 'กำลังเปลี่ยนแพ็กเกจ...'
                        : highlighted
                            ? 'อัปเกรดเป็น Pro'
                            : 'ใช้แพ็กเกจ Free',
              ),
            ),
          ],
        ),
      ),
    );
  }
}
