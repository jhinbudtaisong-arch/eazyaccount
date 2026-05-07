import 'package:flutter/material.dart';

import '../../shared/models/member_profile.dart';
import '../../shared/theme/app_theme.dart';
import '../member/member_profile_screen.dart';
import '../subscription/subscription_screen.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({
    super.key,
    required this.member,
    required this.isMemberLoading,
    required this.isMemberSaving,
    required this.onRefreshMember,
    required this.onUpdateMemberProfile,
    required this.onChangeMemberPlan,
    required this.onSignOut,
    this.memberError,
  });

  final MemberProfile? member;
  final bool isMemberLoading;
  final bool isMemberSaving;
  final String? memberError;
  final Future<void> Function() onRefreshMember;
  final MemberProfileUpdater onUpdateMemberProfile;
  final Future<MemberProfile> Function(MemberPlan plan) onChangeMemberPlan;
  final Future<void> Function() onSignOut;

  void _openMemberProfile(BuildContext context) {
    final currentMember = member;
    if (currentMember == null || isMemberLoading) return;

    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => MemberProfileScreen(
          member: currentMember,
          onSave: onUpdateMemberProfile,
        ),
      ),
    );
  }

  void _openSubscription(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => SubscriptionScreen(
          member: member,
          isSaving: isMemberSaving,
          onChangePlan: onChangeMemberPlan,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final currentMember = member;

    return Scaffold(
      appBar: AppBar(title: const Text('ตั้งค่า')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
          children: [
            const SettingsIntro(),
            const SizedBox(height: 18),
            if (isMemberLoading)
              const MemberLoadingCard()
            else if (currentMember != null)
              MemberCard(
                member: currentMember,
                onTap: () => _openMemberProfile(context),
              ),
            if (memberError != null) ...[
              const SizedBox(height: 10),
              MemberErrorCard(
                message: memberError!,
                onRetry: onRefreshMember,
              ),
            ],
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
              title: 'สมาชิก',
              subtitle: currentMember == null
                  ? 'ดูแพ็กเกจและสิทธิ์การใช้งาน'
                  : 'แพ็กเกจปัจจุบัน: ${currentMember.plan.label}',
              trailing: 'ดูแพ็กเกจ',
              accent: amberAccent,
              onTap: () => _openSubscription(context),
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
          'จัดการโปรไฟล์สมาชิก ภาษา การสำรองข้อมูล และแพ็กเกจใช้งาน',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: mutedColor,
              ),
        ),
      ],
    );
  }
}

class MemberCard extends StatelessWidget {
  const MemberCard({
    super.key,
    required this.member,
    required this.onTap,
  });

  final MemberProfile member;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.eazyColors;
    final planColor =
        member.plan == MemberPlan.pro ? amberAccent : primaryColor;

    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              CircleAvatar(
                radius: 27,
                backgroundColor: planColor.withValues(alpha: 0.14),
                foregroundColor: planColor,
                child: const Icon(Icons.person_rounded),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      member.nameForDisplay,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            color: colors.ink,
                            fontWeight: FontWeight.w900,
                          ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      member.email,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: colors.muted,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Chip(
                      label: Text('แพ็กเกจ ${member.plan.label}'),
                      labelStyle: TextStyle(
                        color: member.plan == MemberPlan.pro
                            ? const Color(0xFF3C2A00)
                            : primaryColor,
                        fontWeight: FontWeight.w800,
                      ),
                      backgroundColor: planColor.withValues(alpha: 0.14),
                      side: BorderSide.none,
                      visualDensity: VisualDensity.compact,
                    ),
                  ],
                ),
              ),
              Icon(Icons.edit_rounded, color: colors.muted),
            ],
          ),
        ),
      ),
    );
  }
}

class MemberLoadingCard extends StatelessWidget {
  const MemberLoadingCard({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = context.eazyColors;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            const SizedBox.square(
              dimension: 24,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            const SizedBox(width: 12),
            Text(
              'กำลังโหลดข้อมูลสมาชิก...',
              style: TextStyle(
                color: colors.muted,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class MemberErrorCard extends StatelessWidget {
  const MemberErrorCard({
    super.key,
    required this.message,
    required this.onRetry,
  });

  final String message;
  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) {
    final colors = context.eazyColors;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              message,
              style: TextStyle(
                color: colors.expense,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 10),
            OutlinedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('โหลดข้อมูลสมาชิกอีกครั้ง'),
            ),
          ],
        ),
      ),
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
