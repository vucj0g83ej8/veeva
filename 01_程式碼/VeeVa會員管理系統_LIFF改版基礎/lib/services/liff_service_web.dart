// ignore_for_file: avoid_web_libraries_in_flutter

import 'dart:html' as html;
import 'dart:js_util' as js_util;

import 'liff_service_base.dart';

const _postLoginPageKey = 'veeva_liff_post_login_page';

LiffService createLiffService({required LiffConfig config}) {
  return WebLiffService(config: config);
}

class WebLiffService implements LiffService {
  WebLiffService({required this.config});

  final LiffConfig config;
  Future<LiffSession>? _initFuture;
  bool _isInitialized = false;

  @override
  Future<LiffSession> initialize() async {
    if (!config.isConfigured) {
      return LiffSession.unconfigured();
    }

    final liff = _liffObject;
    if (liff == null) {
      return LiffSession.unavailable('無法載入 LINE LIFF SDK');
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

  Future<LiffSession> _initializeLiff(Object liff) async {
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
      return LiffSession.unavailable('LIFF 初始化失敗：$error');
    }
  }

  @override
  Future<LiffSession> login({String? postLoginPage}) async {
    if (postLoginPage != null) {
      html.window.sessionStorage[_postLoginPageKey] = postLoginPage;
    }

    final session = await initialize();
    if (session.hasError || session.isLoggedIn || session.isRedirecting) {
      return session;
    }

    if (session.isInClient) {
      return session.copyWith(
        errorMessage: 'LINE App 內已完成初始化，但目前仍未登入',
      );
    }

    final liff = _liffObject;
    if (liff == null) {
      return LiffSession.unavailable('無法載入 LINE LIFF SDK');
    }

    js_util.callMethod<Object?>(
      liff,
      'login',
      [
        js_util.jsify({
          'redirectUri': html.window.location.href,
        }),
      ],
    );
    return LiffSession.redirecting();
  }

  @override
  Future<LiffSession> logout() async {
    final liff = _liffObject;
    if (liff == null) {
      return LiffSession.unavailable('無法載入 LINE LIFF SDK');
    }

    try {
      final isLoggedIn = _readBool(liff, 'isLoggedIn');
      if (isLoggedIn) {
        js_util.callMethod<Object?>(liff, 'logout', const []);
      }
      html.window.sessionStorage.remove(_postLoginPageKey);
      return _readSession(liff);
    } catch (error) {
      return LiffSession.unavailable('LINE 登出失敗：$error');
    }
  }

  Object? get _liffObject {
    return js_util.getProperty<Object?>(html.window, 'liff');
  }

  Future<LiffSession> _readSession(Object liff) async {
    final isLoggedIn = _readBool(liff, 'isLoggedIn');
    final isInClient = _readBool(liff, 'isInClient');
    LiffProfile? profile;
    String? idToken;

    if (isLoggedIn) {
      profile = await _readProfile(liff);
      idToken = _readOptionalStringFromMethod(liff, 'getIDToken');
    }

    final postLoginPage = html.window.sessionStorage[_postLoginPageKey];
    if (postLoginPage != null && isLoggedIn) {
      html.window.sessionStorage.remove(_postLoginPageKey);
    }

    return LiffSession(
      isInitialized: true,
      isLoggedIn: isLoggedIn,
      isInClient: isInClient,
      isRedirecting: false,
      profile: profile,
      idToken: idToken,
      os: _readOptionalStringFromMethod(liff, 'getOS'),
      lineVersion: _readOptionalStringFromMethod(liff, 'getLineVersion'),
      liffVersion: _readOptionalStringFromMethod(liff, 'getVersion'),
      postLoginPage: postLoginPage,
    );
  }

  Future<LiffProfile?> _readProfile(Object liff) async {
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
      return LiffProfile(
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
      return js_util.callMethod<bool>(liff, method, const []);
    } catch (_) {
      return false;
    }
  }

  String? _readOptionalStringFromMethod(Object liff, String method) {
    try {
      final value = js_util.callMethod<Object?>(liff, method, const []);
      return value?.toString();
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
