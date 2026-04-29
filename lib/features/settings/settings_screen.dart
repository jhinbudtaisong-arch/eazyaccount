import 'package:flutter/material.dart';

import '../../shared/theme/app_theme.dart';
import '../subscription/subscription_screen.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key, required this.onSignOut});

  final Future<void> Function() onSignOut;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('ตั้งค่า')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
          children: [
            const SettingsIntro(),
            const SizedBox(height: 18),
            const SettingsTile(
              icon: Icons.language_rounded,
              title: 'ภาษา',
              subtitle: 'ไทย',
              trailing: 'เปลี่ยน',
            ),
            const SizedBox(height: 10),
            const SettingsTile(
              icon: Icons.backup_rounded,
              title: 'สำรองข้อมูล',
              subtitle: 'ข้อมูลถูกบันทึกไว้ใน Supabase local',
              trailing: 'เปิด',
            ),
            const SizedBox(height: 10),
            SettingsTile(
              icon: Icons.workspace_premium_rounded,
              title: 'สมัครสมาชิก',
              subtitle: 'ปลดล็อกรายงานและสำรองข้อมูลอัตโนมัติ',
              trailing: 'ดูแพ็กเกจ',
              accent: amberAccent,
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => const SubscriptionScreen(),
                  ),
                );
              },
            ),
            const SizedBox(height: 10),
            SettingsTile(
              icon: Icons.logout_rounded,
              title: 'ออกจากระบบ',
              subtitle: 'กลับไปหน้าเข้าใช้งาน',
              trailing: 'ออก',
              accent: expenseColor,
              onTap: () {
                onSignOut();
              },
            ),
          ],
        ),
      ),
    );
  }
}

class SettingsIntro extends StatelessWidget {
  const SettingsIntro({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'ตั้งค่าบัญชี',
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                color: inkColor,
                fontWeight: FontWeight.w800,
              ),
        ),
        const SizedBox(height: 6),
        Text(
          'จัดการภาษา การสำรองข้อมูล และแพ็กเกจใช้งาน',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: mutedColor,
              ),
        ),
      ],
    );
  }
}

class SettingsTile extends StatelessWidget {
  const SettingsTile({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.trailing,
    this.accent = primaryColor,
    this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final String trailing;
  final Color accent;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        onTap: onTap,
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        leading: CircleAvatar(
          backgroundColor: accent.withValues(alpha: 0.14),
          foregroundColor: accent,
          child: Icon(icon),
        ),
        title: Text(
          title,
          style: const TextStyle(fontWeight: FontWeight.w800),
        ),
        subtitle: Text(subtitle),
        trailing: Text(
          trailing,
          style: TextStyle(
            color: accent,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    );
  }
}
