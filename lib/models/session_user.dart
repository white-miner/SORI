enum UserRole { guest, director, customer }

enum SocialProvider { kakao, naver, google, apple, email }

class SessionUser {
  const SessionUser({
    required this.role,
    required this.name,
    required this.phone,
    required this.provider,
    this.customerId,
    this.authUserId,
    this.providerId,
    this.email = '',
    this.onboardingComplete = false,
    this.shopSetupComplete = false,
    this.activeMode = UserRole.customer,
    this.showFirstChartTutorial = false,
  });

  final UserRole role;
  final String name;
  final String phone;
  final SocialProvider provider;
  final String? customerId;
  final String? authUserId;

  /// OAuth provider 고유 ID (카카오 id 등). 이메일 없이도 매핑에 사용.
  final String? providerId;
  final String email;
  final bool onboardingComplete;
  final bool shopSetupComplete;

  /// 원장 모드 ↔ 고객 모드 토글 현재 값.
  final UserRole activeMode;
  final bool showFirstChartTutorial;

  String get phoneDigits => phone.replaceAll(RegExp(r'\D'), '');

  String get phoneLast4 {
    final d = phoneDigits;
    if (d.length < 4) return d;
    return d.substring(d.length - 4);
  }

  bool get canToggleMode => onboardingComplete && shopSetupComplete;

  bool get needsProfileCompletion =>
      name.trim().isEmpty || phoneDigits.length < 10;

  String get providerLabel => switch (provider) {
        SocialProvider.kakao => '카카오',
        SocialProvider.naver => '네이버',
        SocialProvider.google => 'Google',
        SocialProvider.apple => 'Apple',
        SocialProvider.email => '이메일',
      };

  SessionUser copyWith({
    UserRole? role,
    String? name,
    String? phone,
    SocialProvider? provider,
    String? customerId,
    String? authUserId,
    String? providerId,
    String? email,
    bool? onboardingComplete,
    bool? shopSetupComplete,
    UserRole? activeMode,
    bool? showFirstChartTutorial,
  }) {
    return SessionUser(
      role: role ?? this.role,
      name: name ?? this.name,
      phone: phone ?? this.phone,
      provider: provider ?? this.provider,
      customerId: customerId ?? this.customerId,
      authUserId: authUserId ?? this.authUserId,
      providerId: providerId ?? this.providerId,
      email: email ?? this.email,
      onboardingComplete: onboardingComplete ?? this.onboardingComplete,
      shopSetupComplete: shopSetupComplete ?? this.shopSetupComplete,
      activeMode: activeMode ?? this.activeMode,
      showFirstChartTutorial:
          showFirstChartTutorial ?? this.showFirstChartTutorial,
    );
  }
}
