import 'package:flutter/material.dart';

import '../../shared/theme/app_theme.dart';

class SubscriptionScreen extends StatelessWidget {
  const SubscriptionScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('สมัครสมาชิก')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
          children: const [
            SubscriptionHeader(),
            SizedBox(height: 18),
            PlanCard(
              title: 'Free',
              price: '0 ฿',
              subtitle: 'เหมาะกับทดลองใช้',
              features: [
                'บันทึกรายการด้วยเสียง',
                'ดูรายการล่าสุด',
                'รายงานวันนี้'
              ],
            ),
            SizedBox(height: 12),
            PlanCard(
              title: 'Pro',
              price: '99 ฿/เดือน',
              subtitle: 'สำหรับร้านที่ใช้ทุกวัน',
              features: [
                'รายงานสัปดาห์และเดือน',
                'สำรองข้อมูลอัตโนมัติ',
                'ส่งออกข้อมูล'
              ],
              highlighted: true,
            ),
          ],
        ),
      ),
    );
  }
}

class SubscriptionHeader extends StatelessWidget {
  const SubscriptionHeader({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'เลือกแพ็กเกจ',
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                color: inkColor,
                fontWeight: FontWeight.w800,
              ),
        ),
        const SizedBox(height: 6),
        Text(
          'เริ่มฟรีก่อน แล้วอัปเกรดเมื่อร้านต้องการรายงานและสำรองข้อมูล',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: mutedColor,
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
    this.highlighted = false,
  });

  final String title;
  final String price;
  final String subtitle;
  final List<String> features;
  final bool highlighted;

  @override
  Widget build(BuildContext context) {
    final accent = highlighted ? amberAccent : primaryColor;

    return Card(
      color: highlighted ? const Color(0xFFFFF8E2) : Colors.white,
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
                          color: inkColor,
                          fontWeight: FontWeight.w900,
                        ),
                  ),
                ),
                if (highlighted)
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
            Text(subtitle, style: const TextStyle(color: mutedColor)),
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
              onPressed: () {},
              style: FilledButton.styleFrom(backgroundColor: accent),
              child: Text(highlighted ? 'อัปเกรดเป็น Pro' : 'ใช้แพ็กเกจ Free'),
            ),
          ],
        ),
      ),
    );
  }
}
