import 'liff_service_base.dart';

LiffService createLiffService({required LiffConfig config}) {
  return StubLiffService();
}

class StubLiffService implements LiffService {
  LiffSession _session = const LiffSession(
    isInitialized: true,
    isLoggedIn: false,
    isInClient: false,
    isRedirecting: false,
  );

  @override
  Future<LiffSession> initialize() async {
    return _session;
  }

  @override
  Future<LiffSession> login({String? postLoginPage}) async {
    _session = LiffSession(
      isInitialized: true,
      isLoggedIn: true,
      isInClient: false,
      isRedirecting: false,
      postLoginPage: postLoginPage,
      referralCode: Uri.base.queryParameters['ref'],
      profile: const LiffProfile(
        userId: 'demo-line-user',
        displayName: '王小明',
      ),
      idToken: 'demo-id-token',
    );
    return _session;
  }

  @override
  Future<LiffShareResult> shareInvite(LiffInviteMessage invite) async {
    return LiffShareResult.sent();
  }

  @override
  Future<LiffSession> logout() async {
    _session = const LiffSession(
      isInitialized: true,
      isLoggedIn: false,
      isInClient: false,
      isRedirecting: false,
    );
    return _session;
  }
}
