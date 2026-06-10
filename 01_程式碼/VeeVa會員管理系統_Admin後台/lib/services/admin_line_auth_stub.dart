import 'admin_line_auth_base.dart';

AdminLineAuthService createAdminLineAuthService({
  required AdminLineConfig config,
}) {
  return StubAdminLineAuthService();
}

class StubAdminLineAuthService implements AdminLineAuthService {
  AdminLineSession _session = const AdminLineSession(
    isInitialized: true,
    isLoggedIn: true,
    isInClient: false,
    isRedirecting: false,
    profile: AdminLineProfile(
      userId: 'line-demo-wang',
      displayName: '王小明',
      email: 'wang@example.com',
    ),
    idToken: 'demo-admin-id-token',
  );

  @override
  Future<AdminLineSession> initialize() async {
    return _session;
  }

  @override
  Future<AdminLineSession> login() async {
    _session = const AdminLineSession(
      isInitialized: true,
      isLoggedIn: true,
      isInClient: false,
      isRedirecting: false,
      profile: AdminLineProfile(
        userId: 'line-demo-wang',
        displayName: '王小明',
        email: 'wang@example.com',
      ),
      idToken: 'demo-admin-id-token',
    );
    return _session;
  }

  @override
  Future<AdminLineSession> logout() async {
    _session = const AdminLineSession(
      isInitialized: true,
      isLoggedIn: false,
      isInClient: false,
      isRedirecting: false,
    );
    return _session;
  }
}
