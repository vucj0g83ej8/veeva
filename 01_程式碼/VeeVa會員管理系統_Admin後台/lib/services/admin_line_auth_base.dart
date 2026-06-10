abstract class AdminLineAuthService {
  Future<AdminLineSession> initialize();

  Future<AdminLineSession> login();

  Future<AdminLineSession> logout();
}

class AdminLineConfig {
  const AdminLineConfig({
    required this.liffId,
    this.withLoginOnExternalBrowser = false,
  });

  factory AdminLineConfig.fromEnvironment() {
    const adminLiffId = String.fromEnvironment('ADMIN_LIFF_ID');
    const sharedLiffId = String.fromEnvironment('LIFF_ID');
    return AdminLineConfig(
      liffId: adminLiffId.trim().isNotEmpty ? adminLiffId : sharedLiffId,
      withLoginOnExternalBrowser: const bool.fromEnvironment(
        'ADMIN_LIFF_AUTO_LOGIN',
        defaultValue: false,
      ),
    );
  }

  final String liffId;
  final bool withLoginOnExternalBrowser;

  bool get isConfigured => liffId.trim().isNotEmpty;
}

class AdminLineSession {
  const AdminLineSession({
    required this.isInitialized,
    required this.isLoggedIn,
    required this.isInClient,
    required this.isRedirecting,
    this.profile,
    this.idToken,
    this.errorMessage,
  });

  factory AdminLineSession.initial() {
    return const AdminLineSession(
      isInitialized: false,
      isLoggedIn: false,
      isInClient: false,
      isRedirecting: false,
    );
  }

  factory AdminLineSession.unconfigured() {
    return const AdminLineSession(
      isInitialized: false,
      isLoggedIn: false,
      isInClient: false,
      isRedirecting: false,
      errorMessage: '尚未設定 Admin LIFF ID',
    );
  }

  factory AdminLineSession.unavailable(String message) {
    return AdminLineSession(
      isInitialized: false,
      isLoggedIn: false,
      isInClient: false,
      isRedirecting: false,
      errorMessage: message,
    );
  }

  factory AdminLineSession.redirecting() {
    return const AdminLineSession(
      isInitialized: true,
      isLoggedIn: false,
      isInClient: false,
      isRedirecting: true,
    );
  }

  final bool isInitialized;
  final bool isLoggedIn;
  final bool isInClient;
  final bool isRedirecting;
  final AdminLineProfile? profile;
  final String? idToken;
  final String? errorMessage;

  bool get hasError => errorMessage != null && errorMessage!.isNotEmpty;
}

class AdminLineProfile {
  const AdminLineProfile({
    required this.userId,
    required this.displayName,
    this.pictureUrl,
    this.statusMessage,
    this.email,
  });

  final String userId;
  final String displayName;
  final String? pictureUrl;
  final String? statusMessage;
  final String? email;
}
