enum MemberPlan { free, pro }

extension MemberPlanLabel on MemberPlan {
  String get value {
    switch (this) {
      case MemberPlan.free:
        return 'free';
      case MemberPlan.pro:
        return 'pro';
    }
  }

  String get label {
    switch (this) {
      case MemberPlan.free:
        return 'Free';
      case MemberPlan.pro:
        return 'Pro';
    }
  }

  static MemberPlan fromValue(Object? value) {
    return value == MemberPlan.pro.value ? MemberPlan.pro : MemberPlan.free;
  }
}

class MemberProfile {
  const MemberProfile({
    required this.id,
    required this.email,
    required this.displayName,
    required this.shopName,
    required this.phone,
    required this.plan,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String email;
  final String displayName;
  final String shopName;
  final String phone;
  final MemberPlan plan;
  final String status;
  final DateTime createdAt;
  final DateTime updatedAt;

  String get nameForDisplay {
    if (shopName.trim().isNotEmpty) return shopName.trim();
    if (displayName.trim().isNotEmpty) return displayName.trim();
    if (email.trim().isNotEmpty) return email.trim();
    return 'สมาชิก EazyAccount';
  }

  factory MemberProfile.fromJson(Map<String, dynamic> json) {
    final createdAtText = json['created_at']?.toString();
    final updatedAtText = json['updated_at']?.toString();

    return MemberProfile(
      id: json['id']?.toString() ?? '',
      email: json['email']?.toString() ?? '',
      displayName: json['display_name']?.toString() ?? '',
      shopName: json['shop_name']?.toString() ?? '',
      phone: json['phone']?.toString() ?? '',
      plan: MemberPlanLabel.fromValue(json['member_plan']),
      status: json['member_status']?.toString() ?? 'active',
      createdAt: DateTime.tryParse(createdAtText ?? '') ?? DateTime.now(),
      updatedAt: DateTime.tryParse(updatedAtText ?? '') ?? DateTime.now(),
    );
  }
}
