abstract class LiffService {
  Future<LiffSession> initialize();

  Future<LiffSession> login({String? postLoginPage});

  Future<LiffSession> logout();
}

class LiffConfig {
  const LiffConfig({
    required this.liffId,
    this.withLoginOnExternalBrowser = false,
  });

  factory LiffConfig.fromEnvironment() {
    return const LiffConfig(
      liffId: String.fromEnvironment('LIFF_ID'),
      withLoginOnExternalBrowser: bool.fromEnvironment(
        'LIFF_AUTO_LOGIN',
        defaultValue: false,
      ),
    );
  }

  final String liffId;
  final bool withLoginOnExternalBrowser;

  bool get isConfigured => liffId.trim().isNotEmpty;
}

class LiffSession {
  const LiffSession({
    required this.isInitialized,
    required this.isLoggedIn,
    required this.isInClient,
    required this.isRedirecting,
    this.profile,
    this.idToken,
    this.os,
    this.lineVersion,
    this.liffVersion,
    this.postLoginPage,
    this.errorMessage,
  });

  factory LiffSession.initial() {
    return const LiffSession(
      isInitialized: false,
      isLoggedIn: false,
      isInClient: false,
      isRedirecting: false,
    );
  }

  factory LiffSession.unconfigured() {
    return const LiffSession(
      isInitialized: false,
      isLoggedIn: false,
      isInClient: false,
      isRedirecting: false,
      errorMessage: 'LINE 登入尚未設定 LIFF_ID',
    );
  }

  factory LiffSession.unavailable(String message) {
    return LiffSession(
      isInitialized: false,
      isLoggedIn: false,
      isInClient: false,
      isRedirecting: false,
      errorMessage: message,
    );
  }

  factory LiffSession.redirecting() {
    return const LiffSession(
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
  final LiffProfile? profile;
  final String? idToken;
  final String? os;
  final String? lineVersion;
  final String? liffVersion;
  final String? postLoginPage;
  final String? errorMessage;

  bool get hasError => errorMessage != null && errorMessage!.isNotEmpty;

  LiffSession copyWith({
    bool? isInitialized,
    bool? isLoggedIn,
    bool? isInClient,
    bool? isRedirecting,
    LiffProfile? profile,
    String? idToken,
    String? os,
    String? lineVersion,
    String? liffVersion,
    String? postLoginPage,
    String? errorMessage,
  }) {
    return LiffSession(
      isInitialized: isInitialized ?? this.isInitialized,
      isLoggedIn: isLoggedIn ?? this.isLoggedIn,
      isInClient: isInClient ?? this.isInClient,
      isRedirecting: isRedirecting ?? this.isRedirecting,
      profile: profile ?? this.profile,
      idToken: idToken ?? this.idToken,
      os: os ?? this.os,
      lineVersion: lineVersion ?? this.lineVersion,
      liffVersion: liffVersion ?? this.liffVersion,
      postLoginPage: postLoginPage ?? this.postLoginPage,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }
}

class LiffProfile {
  const LiffProfile({
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
