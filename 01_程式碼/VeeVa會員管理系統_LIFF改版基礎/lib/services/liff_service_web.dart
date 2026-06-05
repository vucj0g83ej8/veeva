// ignore_for_file: avoid_web_libraries_in_flutter

import 'dart:html' as html;
import 'dart:js_util' as js_util;

import 'liff_service_base.dart';

const _postLoginPageKey = 'veeva_liff_post_login_page';
const _referralCodeKey = 'veeva_liff_referral_code';
const _inviteCoffeeImageUrl =
    'https://veeva-8d30c.web.app/assets/share/coffee-member-gift-v1.jpg';

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

    final earlySession = await _readSessionFromEarlyInit(liff);
    if (earlySession != null) {
      return earlySession;
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

  Future<LiffSession?> _readSessionFromEarlyInit(Object liff) async {
    final ready = js_util.getProperty<Object?>(html.window, 'veevaLiffReady');
    if (ready == null) {
      return null;
    }
    try {
      await js_util.promiseToFuture<Object?>(ready);
      final error = _readOptionalWindowString('veevaLiffInitError');
      if (error != null) {
        return LiffSession.unavailable('LIFF 初始化失敗：$error');
      }
      _isInitialized = true;
      return _readSession(liff);
    } catch (error) {
      return LiffSession.unavailable('LIFF 初始化失敗：$error');
    }
  }

  @override
  Future<LiffSession> login({String? postLoginPage}) async {
    if (postLoginPage != null) {
      html.window.sessionStorage[_postLoginPageKey] = postLoginPage;
    }
    final referralCode = _referralCodeFromLocation();
    if (referralCode != null) {
      html.window.sessionStorage[_referralCodeKey] = referralCode;
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
  Future<LiffShareResult> shareInvite(LiffInviteMessage invite) async {
    final session = await initialize();
    if (session.hasError) {
      return LiffShareResult.unavailable(
        session.errorMessage ?? 'LINE 分享功能尚未初始化',
      );
    }
    if (!session.isLoggedIn) {
      return LiffShareResult.unavailable('請先使用 LINE 登入後再分享邀請。');
    }

    final liff = _liffObject;
    if (liff == null) {
      return LiffShareResult.unavailable('無法載入 LINE LIFF SDK');
    }
    if (!_isShareTargetPickerAvailable(liff)) {
      return LiffShareResult.unavailable(
        '此 LINE 環境尚未支援分享功能，請確認已在 LIFF 設定啟用 shareTargetPicker。',
      );
    }

    try {
      final sharePromise = js_util.callMethod<Object>(
        liff,
        'shareTargetPicker',
        [
          js_util.jsify([_inviteFlexMessage(invite)]),
        ],
      );
      await js_util.promiseToFuture<Object?>(sharePromise);
      return LiffShareResult.sent();
    } catch (error) {
      return LiffShareResult.unavailable('尚未完成分享或分享已取消。');
    }
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
      html.window.sessionStorage.remove(_referralCodeKey);
      return _readSession(liff);
    } catch (error) {
      return LiffSession.unavailable('LINE 登出失敗：$error');
    }
  }

  Object? get _liffObject {
    return js_util.getProperty<Object?>(html.window, 'liff');
  }

  String? _readOptionalWindowString(String key) {
    final value = js_util.getProperty<Object?>(html.window, key);
    final text = value?.toString();
    if (text == null || text.isEmpty) {
      return null;
    }
    return text;
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
    final referralCode = _referralCodeFromLocation() ??
        html.window.sessionStorage[_referralCodeKey];
    if (postLoginPage != null && isLoggedIn) {
      html.window.sessionStorage.remove(_postLoginPageKey);
    }
    if (referralCode != null && isLoggedIn) {
      html.window.sessionStorage.remove(_referralCodeKey);
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
      referralCode: referralCode,
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

  bool _isShareTargetPickerAvailable(Object liff) {
    try {
      return js_util.callMethod<bool>(
        liff,
        'isApiAvailable',
        const ['shareTargetPicker'],
      );
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

  String? _referralCodeFromLocation() {
    final code = _referralCodeFromUri(Uri.base) ??
        _referralCodeFromShortPath(Uri.base) ??
        _referralCodeFromLiffState(Uri.base);
    final text = code?.trim();
    if (text == null || text.isEmpty) {
      return null;
    }
    return text;
  }

  String? _referralCodeFromUri(Uri uri) {
    return uri.queryParameters['ref'] ??
        uri.queryParameters['shareCode'] ??
        uri.queryParameters['invite'];
  }

  String? _referralCodeFromShortPath(Uri uri) {
    if (uri.pathSegments.length != 2 || uri.pathSegments.first != 'r') {
      return null;
    }
    final code = uri.pathSegments.last
        .trim()
        .replaceAll(RegExp('[^a-zA-Z0-9]'), '')
        .toUpperCase();
    return code.isEmpty ? null : code;
  }

  String? _referralCodeFromLiffState(Uri uri) {
    final state = uri.queryParameters['liff.state'];
    if (state == null || state.isEmpty) {
      return null;
    }
    final stateUri = Uri.tryParse(state);
    if (stateUri != null) {
      final code = _referralCodeFromUri(stateUri);
      if (code != null && code.trim().isNotEmpty) {
        return code;
      }
    }
    final query = state.startsWith('?') ? state.substring(1) : state;
    final values = Uri.splitQueryString(query);
    return values['ref'] ?? values['shareCode'] ?? values['invite'];
  }
}

Map<String, Object?> _inviteFlexMessage(LiffInviteMessage invite) {
  final inviterName = invite.inviterName.trim().isEmpty
      ? 'VeeVa 會員'
      : invite.inviterName.trim();
  return {
    'type': 'flex',
    'altText': '加入會員送咖啡，立即領取免費咖啡券',
    'contents': {
      'type': 'bubble',
      'hero': {
        'type': 'image',
        'url': _inviteCoffeeImageUrl,
        'size': 'full',
        'aspectRatio': '1:1',
        'aspectMode': 'cover',
        'action': {
          'type': 'uri',
          'label': '立即加入',
          'uri': invite.inviteUrl,
        },
      },
      'body': {
        'type': 'box',
        'layout': 'vertical',
        'spacing': 'sm',
        'contents': [
          {
            'type': 'text',
            'text': '加入會員送咖啡',
            'weight': 'bold',
            'size': 'xl',
            'color': '#5A351D',
          },
          {
            'type': 'text',
            'text': '$inviterName 邀請你加入 VeeVa 會員，完成加入即可取得咖啡好禮。',
            'wrap': true,
            'size': 'sm',
            'color': '#6B4A32',
          },
          {
            'type': 'text',
            'text': '簡單加入，好禮立即送！',
            'wrap': true,
            'size': 'sm',
            'weight': 'bold',
            'color': '#9A5A1F',
          },
        ],
      },
      'footer': {
        'type': 'box',
        'layout': 'vertical',
        'contents': [
          {
            'type': 'button',
            'style': 'primary',
            'color': '#8B4E20',
            'action': {
              'type': 'uri',
              'label': '立即加入領咖啡',
              'uri': invite.inviteUrl,
            },
          },
        ],
      },
    },
  };
}
