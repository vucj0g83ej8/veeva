// ignore_for_file: avoid_web_libraries_in_flutter

import 'dart:html' as html;
import 'dart:js_util' as js_util;

import 'admin_line_auth_base.dart';

AdminLineAuthService createAdminLineAuthService({
  required AdminLineConfig config,
}) {
  return WebAdminLineAuthService(config: config);
}

class WebAdminLineAuthService implements AdminLineAuthService {
  WebAdminLineAuthService({required this.config});

  final AdminLineConfig config;
  Future<AdminLineSession>? _initFuture;
  bool _isInitialized = false;

  @override
  Future<AdminLineSession> initialize() async {
    if (!config.isConfigured) {
      return AdminLineSession.unconfigured();
    }

    final liff = _liffObject;
    if (liff == null) {
      return AdminLineSession.unavailable('無法載入 LINE LIFF SDK');
    }

    if (_isInitialized) {
      return _readSession(liff);
    }

    final initFuture = _initFuture;
    if (initFuture != null) {
      return initFuture;
    }

    _initFuture = _initializeLiff(liff);
    return _initFuture!;
  }

  Future<AdminLineSession> _initializeLiff(Object liff) async {
    try {
      final initConfig = js_util.jsify({
        'liffId': config.liffId,
        'withLoginOnExternalBrowser': config.withLoginOnExternalBrowser,
      });
      final initPromise = js_util.callMethod<Object>(
        liff,
        'init',
        [initConfig],
      );
      await js_util.promiseToFuture<void>(initPromise);
      _isInitialized = true;
      return _readSession(liff);
    } catch (error) {
      _initFuture = null;
      return AdminLineSession.unavailable('LIFF 初始化失敗：$error');
    }
  }

  @override
  Future<AdminLineSession> login() async {
    final session = await initialize();
    if (session.hasError || session.isLoggedIn || session.isRedirecting) {
      return session;
    }

    final liff = _liffObject;
    if (liff == null) {
      return AdminLineSession.unavailable('無法載入 LINE LIFF SDK');
    }

    js_util.callMethod<Object?>(
      liff,
      'login',
      [
        js_util.jsify({
          'redirectUri': _loginRedirectUri(),
        }),
      ],
    );
    return AdminLineSession.redirecting();
  }

  String _loginRedirectUri() {
    final location = html.window.location;
    final currentPath = location.pathname ?? '/';
    final path = currentPath.isEmpty ? '/' : currentPath;
    return '${location.protocol}//${location.host}$path';
  }

  @override
  Future<AdminLineSession> logout() async {
    final liff = _liffObject;
    if (liff == null) {
      return AdminLineSession.unavailable('無法載入 LINE LIFF SDK');
    }

    try {
      if (_readBool(liff, 'isLoggedIn')) {
        js_util.callMethod<Object?>(liff, 'logout', const []);
      }
      return _readSession(liff);
    } catch (error) {
      return AdminLineSession.unavailable('LINE 登出失敗：$error');
    }
  }

  Object? get _liffObject {
    return js_util.getProperty<Object?>(html.window, 'liff');
  }

  Future<AdminLineSession> _readSession(Object liff) async {
    final isLoggedIn = _readBool(liff, 'isLoggedIn');
    AdminLineProfile? profile;
    String? idToken;

    if (isLoggedIn) {
      profile = await _readProfile(liff);
      idToken = _readOptionalStringFromMethod(liff, 'getIDToken');
    }

    return AdminLineSession(
      isInitialized: true,
      isLoggedIn: isLoggedIn,
      isInClient: _readBool(liff, 'isInClient'),
      isRedirecting: false,
      profile: profile,
      idToken: idToken,
    );
  }

  Future<AdminLineProfile?> _readProfile(Object liff) async {
    try {
      final profilePromise = js_util.callMethod<Object>(
        liff,
        'getProfile',
        const [],
      );
      final profile = await js_util.promiseToFuture<Object>(profilePromise);
      final decodedToken = js_util.callMethod<Object?>(
        liff,
        'getDecodedIDToken',
        const [],
      );
      return AdminLineProfile(
        userId: _readString(profile, 'userId') ?? '',
        displayName: _readString(profile, 'displayName') ?? 'LINE 會員',
        pictureUrl: _readString(profile, 'pictureUrl'),
        statusMessage: _readString(profile, 'statusMessage'),
        email: decodedToken == null ? null : _readString(decodedToken, 'email'),
      );
    } catch (_) {
      return null;
    }
  }

  bool _readBool(Object liff, String method) {
    try {
      final value = js_util.callMethod<Object?>(liff, method, const []);
      return value == true;
    } catch (_) {
      return false;
    }
  }

  String? _readOptionalStringFromMethod(Object liff, String method) {
    try {
      final value = js_util.callMethod<Object?>(liff, method, const []);
      final text = value?.toString();
      if (text == null || text.isEmpty) {
        return null;
      }
      return text;
    } catch (_) {
      return null;
    }
  }

  String? _readString(Object object, String key) {
    final value = js_util.getProperty<Object?>(object, key);
    final text = value?.toString();
    if (text == null || text.isEmpty) {
      return null;
    }
    return text;
  }
}
