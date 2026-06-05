import 'dart:async';

import 'package:flutter/material.dart';

import 'data/firebase_bootstrap.dart';
import 'data/veeva_models.dart' as backend;
import 'data/veeva_repository.dart';
import 'services/liff_service.dart';
import 'short_link_redirect_stub.dart'
    if (dart.library.html) 'short_link_redirect_web.dart';
import 'survey_embed_stub.dart' if (dart.library.html) 'survey_embed_web.dart';

const _defaultLiffId = '2010298394-7PwRtpTY';
const _configuredLiffId = String.fromEnvironment(
  'LIFF_ID',
  defaultValue: _defaultLiffId,
);
Future<void> main() async {
  if (redirectShortReferralLinkIfNeeded(liffId: _configuredLiffId)) {
    return;
  }
  WidgetsFlutterBinding.ensureInitialized();
  final repository = await createVeevaRepository();
  runApp(VeevaMemberApp(repository: repository));
}

class VeevaMemberApp extends StatefulWidget {
  const VeevaMemberApp({
    this.liffService,
    this.repository,
    super.key,
  });

  final LiffService? liffService;
  final VeevaRepository? repository;

  @override
  State<VeevaMemberApp> createState() => _VeevaMemberAppState();
}

class _VeevaMemberAppState extends State<VeevaMemberApp> {
  late final AppState state;

  @override
  void initState() {
    super.initState();
    state = AppState.demo(
      repository: widget.repository ?? DemoVeevaRepository(),
      liffService: widget.liffService ??
          createLiffService(config: LiffConfig.fromEnvironment()),
    );
    state.isLiffBusy = true;
    _initializeApp();
  }

  Future<void> _initializeApp() async {
    await state.loadBackendData();
    await state.initializeLiff();
    if (mounted) {
      state.notifyStateChanged();
    }
  }

  @override
  void dispose() {
    state.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AppScope(
      state: state,
      notify: state.notifyStateChanged,
      child: MaterialApp(
        title: 'VeeVa 會員管理系統',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light(),
        builder: (context, child) {
          return ScrollConfiguration(
            behavior: const _VeevaScrollBehavior(),
            child: child ?? const SizedBox.shrink(),
          );
        },
        home: const AppShell(),
      ),
    );
  }
}

class _VeevaScrollBehavior extends MaterialScrollBehavior {
  const _VeevaScrollBehavior();

  @override
  Widget buildOverscrollIndicator(
    BuildContext context,
    Widget child,
    ScrollableDetails details,
  ) {
    return child;
  }

  @override
  ScrollPhysics getScrollPhysics(BuildContext context) {
    return const ClampingScrollPhysics();
  }
}

class AppScope extends InheritedNotifier<AppState> {
  const AppScope({
    required this.state,
    required this.notify,
    required super.child,
    super.key,
  }) : super(notifier: state);

  final AppState state;
  final VoidCallback notify;

  static AppScope of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<AppScope>();
    assert(scope != null, 'AppScope not found');
    return scope!;
  }
}

class AppState extends ChangeNotifier {
  AppState({
    required this.repository,
    required this.liffService,
    required this.liffSession,
    required this.member,
    required this.coupons,
    required this.reviewItems,
    required this.activities,
    required this.medicalNews,
    required this.currentPage,
    this.isLiffBusy = false,
    this.isInviteShareBusy = false,
    this.authError,
    this.dataError,
    this.inviteShareMessage,
    this.inviteShareIsError = false,
  });

  factory AppState.demo({
    required VeevaRepository repository,
    required LiffService liffService,
  }) {
    return AppState(
      repository: repository,
      liffService: liffService,
      liffSession: LiffSession.initial(),
      member: MemberProfile.guest(),
      currentPage: _requestedAppPageFromLaunchUri() ?? AppPage.landing,
      coupons: defaultCoupons,
      reviewItems: defaultReviews.map(ReviewItem.fromBackend).toList(),
      activities: defaultActivities.map(ActivityNews.fromBackend).toList(),
      medicalNews: defaultNews.map(MedicalNewsItem.fromBackend).toList(),
    );
  }

  final VeevaRepository repository;
  MemberProfile member;
  List<Coupon> coupons;
  List<ReviewItem> reviewItems;
  List<ActivityNews> activities;
  List<MedicalNewsItem> medicalNews;
  AppPage currentPage;
  final LiffService liffService;
  LiffSession liffSession;
  bool isLiffBusy;
  bool isInviteShareBusy;
  String? authError;
  String? dataError;
  String? inviteShareMessage;
  bool inviteShareIsError;

  void notifyStateChanged() {
    notifyListeners();
  }

  String? get loginNoticeText {
    if (authError != null) {
      return authError;
    }
    if (isLiffBusy) {
      return '正在連線 LINE...';
    }
    if (liffSession.hasError) {
      return liffSession.errorMessage;
    }
    if (liffSession.isLoggedIn) {
      final name = liffSession.profile?.displayName;
      return name == null ? '已完成 LINE 登入' : '已登入 LINE：$name';
    }
    return null;
  }

  bool get loginNoticeIsError {
    return authError != null || liffSession.hasError;
  }

  Future<void> loadBackendData() async {
    try {
      final bootstrap = await repository.loadBootstrap();
      if (bootstrap.activities.isNotEmpty) {
        activities =
            bootstrap.activities.map(ActivityNews.fromBackend).toList();
      }
      if (bootstrap.news.isNotEmpty) {
        medicalNews = bootstrap.news.map(MedicalNewsItem.fromBackend).toList();
      }
      if (bootstrap.rewards.isNotEmpty) {
        coupons = bootstrap.rewards
            .where(
                (reward) => reward.status == backend.VeevaRewardStatus.active)
            .map(Coupon.fromBackend)
            .toList();
      }
      if (bootstrap.reviews.isNotEmpty) {
        reviewItems = bootstrap.reviews.map(ReviewItem.fromBackend).toList();
      }
      dataError = null;
    } catch (_) {
      dataError = 'Firebase 資料讀取失敗，已暫時使用本機示範資料。';
    }
  }

  Future<void> initializeLiff() async {
    isLiffBusy = true;
    authError = null;
    try {
      liffSession = await liffService.initialize();
      final requestedPage = _requestedPageFromLaunchUri();
      if (liffSession.isLoggedIn) {
        await _syncLineProfileToMember();
        final nextPage =
            _pageFromName(liffSession.postLoginPage) ?? requestedPage;
        if (nextPage != null) {
          currentPage = nextPage;
        }
      } else if (requestedPage != null) {
        currentPage = requestedPage;
      }
    } catch (error) {
      authError = 'LIFF 初始化失敗：$error';
    } finally {
      isLiffBusy = false;
    }
  }

  Future<void> loginWithLine({required AppPage nextPage}) async {
    isLiffBusy = true;
    authError = null;
    try {
      liffSession = await liffService.login(postLoginPage: nextPage.name);
      if (liffSession.isRedirecting) {
        return;
      }
      if (!liffSession.isLoggedIn) {
        authError = liffSession.errorMessage ?? '尚未完成 LINE 登入';
        return;
      }
      await _syncLineProfileToMember();
      currentPage = nextPage;
    } catch (error) {
      authError = 'LINE 登入失敗：$error';
    } finally {
      isLiffBusy = false;
    }
  }

  Future<void> shareMemberInvite() async {
    isInviteShareBusy = true;
    inviteShareMessage = null;
    inviteShareIsError = false;
    try {
      final result = await liffService.shareInvite(
        LiffInviteMessage(
          inviterName: member.name,
          shareCode: member.shareCode,
          inviteUrl: _memberLiffInviteLink(member),
        ),
      );
      inviteShareMessage = result.message;
      inviteShareIsError = !result.success;
    } catch (error) {
      inviteShareMessage = '分享邀請失敗，請稍後再試。';
      inviteShareIsError = true;
    } finally {
      isInviteShareBusy = false;
    }
  }

  void loginWithDemoProvider({required AppPage nextPage}) {
    member = const MemberProfile(
      name: '王小明',
      hospital: '台大醫院',
      department: '心臟內科',
      status: MemberStatus.loggedIn,
      earnedCoupons: 0,
      invitedCount: 0,
      shareCode: 'A8D2K',
    );
    currentPage = nextPage;
    authError = null;
  }

  void completeSurvey() {
    member = member.copyWith(status: MemberStatus.pendingReview);
    currentPage = AppPage.thankYou;
    unawaited(repository.submitReview(member.toBackend()));
  }

  void approveCurrentMember() {
    member = member.copyWith(
      status: MemberStatus.verified,
      earnedCoupons: 3,
      invitedCount: 5,
    );
    final exists = reviewItems.any((item) => item.name == member.name);
    if (!exists) {
      reviewItems = [
        ...reviewItems,
        ReviewItem(
          member.name,
          member.hospital,
          member.department,
          ReviewStatus.approved,
        ),
      ];
    }
    unawaited(
      repository.approveReview(
        backend.VeevaReview(
          id: member.lineUserId ?? member.name,
          memberId: member.lineUserId ?? member.name,
          name: member.name,
          hospital: member.hospital,
          department: member.department,
          status: backend.VeevaReviewStatus.approved,
          completedAt: DateTime.now(),
        ),
      ),
    );
  }

  Future<void> _syncLineProfileToMember() async {
    final profile = liffSession.profile;
    final displayName = profile?.displayName.trim();
    if (profile?.userId == null || profile!.userId.isEmpty) {
      member = member.copyWith(
        name: displayName == null || displayName.isEmpty
            ? 'LINE 會員'
            : displayName,
        status: MemberStatus.loggedIn,
        lineUserId: profile?.userId,
        avatarUrl: profile?.pictureUrl,
      );
      return;
    }

    try {
      final remoteMember = await repository.upsertLineMember(
        lineUserId: profile.userId,
        displayName: displayName ?? 'LINE 會員',
        avatarUrl: profile.pictureUrl,
        email: profile.email,
        statusMessage: profile.statusMessage,
        lineIdToken: liffSession.idToken,
        referralCode: _pendingReferralCode(),
      );
      member = MemberProfile.fromBackend(remoteMember);
    } catch (_) {
      member = member.copyWith(
        name: displayName == null || displayName.isEmpty
            ? 'LINE 會員'
            : displayName,
        status: MemberStatus.loggedIn,
        lineUserId: profile.userId,
        avatarUrl: profile.pictureUrl,
      );
    }
  }

  String? _pendingReferralCode() {
    final code = liffSession.referralCode ??
        _referralCodeFromUri(Uri.base) ??
        _referralCodeFromLiffState(Uri.base);
    final text = code?.trim();
    if (text == null || text.isEmpty) {
      return null;
    }
    return text;
  }

  AppPage? _pageFromName(String? name) {
    if (name == null || name.isEmpty) {
      return null;
    }
    for (final page in AppPage.values) {
      if (page.name == name) {
        return page;
      }
    }
    return null;
  }

  AppPage? _requestedPageFromLaunchUri() {
    return _requestedAppPageFromLaunchUri();
  }
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

String? _queryValueFromUri(Uri uri, List<String> keys) {
  for (final key in keys) {
    final value = uri.queryParameters[key];
    if (value != null && value.trim().isNotEmpty) {
      return value;
    }
  }
  return null;
}

String? _queryValueFromLiffState(Uri uri, List<String> keys) {
  final state = uri.queryParameters['liff.state'];
  if (state == null || state.isEmpty) {
    return null;
  }
  final stateUri = Uri.tryParse(state);
  if (stateUri != null) {
    final value = _queryValueFromUri(stateUri, keys);
    if (value != null && value.trim().isNotEmpty) {
      return value;
    }
  }
  final query = state.startsWith('?') ? state.substring(1) : state;
  final values = Uri.splitQueryString(query);
  for (final key in keys) {
    final value = values[key];
    if (value != null && value.trim().isNotEmpty) {
      return value;
    }
  }
  return null;
}

AppPage? _requestedAppPageFromLaunchUri() {
  final target = _queryValueFromUri(Uri.base, const ['open', 'page']) ??
      _queryValueFromLiffState(Uri.base, const ['open', 'page']);
  final normalized = target?.trim().toLowerCase();
  if (_referralCodeFromShortPath(Uri.base) != null) {
    return AppPage.memberCenter;
  }
  return switch (normalized) {
    'invite' || 'member' || 'membercenter' => AppPage.memberCenter,
    'coupon' || 'coupons' => AppPage.coupon,
    'news' => AppPage.news,
    'survey' => AppPage.survey,
    _ => null,
  };
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
  return Uri.splitQueryString(query)['ref'] ??
      Uri.splitQueryString(query)['shareCode'] ??
      Uri.splitQueryString(query)['invite'];
}

enum AppPage {
  landing,
  news,
  login,
  survey,
  thankYou,
  memberCenter,
  coupon,
}

enum MemberStatus { guest, loggedIn, pendingReview, verified }

enum MemberAccountStatus { active, disabled }

enum CouponStatus { available, used, expired }

enum ReviewStatus { pending, approved, rejected }

String _formatDate(DateTime date) {
  return '${date.year}/${date.month.toString().padLeft(2, '0')}/${date.day.toString().padLeft(2, '0')}';
}

String _formatDateTime(DateTime date) {
  final value = date.toLocal();
  final dateText = _formatDate(value);
  final hour = value.hour.toString().padLeft(2, '0');
  final minute = value.minute.toString().padLeft(2, '0');
  return '$dateText $hour:$minute';
}

const veevaSurveyUrl =
    'https://privacyportal.onetrust.com/webform/3d676ed2-16b1-4c48-97f8-a911923a3adf/0dad5f26-4fad-41d6-a15d-836c329695e1';

class MemberProfile {
  const MemberProfile({
    required this.name,
    required this.hospital,
    required this.department,
    required this.status,
    this.accountStatus = MemberAccountStatus.active,
    required this.earnedCoupons,
    required this.invitedCount,
    required this.shareCode,
    this.lineUserId,
    this.avatarUrl,
    this.referredByMemberId,
    this.referredByShareCode,
    this.referredAt,
  });

  factory MemberProfile.guest() {
    return const MemberProfile(
      name: '訪客',
      hospital: '',
      department: '',
      status: MemberStatus.guest,
      accountStatus: MemberAccountStatus.active,
      earnedCoupons: 0,
      invitedCount: 0,
      shareCode: 'A8D2K',
    );
  }

  factory MemberProfile.fromBackend(backend.VeevaMember member) {
    return MemberProfile(
      name: member.name,
      hospital: member.hospital,
      department: member.department,
      status: _memberStatusFromBackend(member.status),
      accountStatus: _memberAccountStatusFromBackend(member.accountStatus),
      earnedCoupons: member.earnedCoupons,
      invitedCount: member.invitedCount,
      shareCode: member.shareCode,
      lineUserId: member.lineUserId ?? member.id,
      avatarUrl: member.avatarUrl,
      referredByMemberId: member.referredByMemberId,
      referredByShareCode: member.referredByShareCode,
      referredAt: member.referredAt,
    );
  }

  final String name;
  final String hospital;
  final String department;
  final MemberStatus status;
  final MemberAccountStatus accountStatus;
  final int earnedCoupons;
  final int invitedCount;
  final String shareCode;
  final String? lineUserId;
  final String? avatarUrl;
  final String? referredByMemberId;
  final String? referredByShareCode;
  final DateTime? referredAt;

  MemberProfile copyWith({
    String? name,
    String? hospital,
    String? department,
    MemberStatus? status,
    MemberAccountStatus? accountStatus,
    int? earnedCoupons,
    int? invitedCount,
    String? shareCode,
    String? lineUserId,
    String? avatarUrl,
    String? referredByMemberId,
    String? referredByShareCode,
    DateTime? referredAt,
  }) {
    return MemberProfile(
      name: name ?? this.name,
      hospital: hospital ?? this.hospital,
      department: department ?? this.department,
      status: status ?? this.status,
      accountStatus: accountStatus ?? this.accountStatus,
      earnedCoupons: earnedCoupons ?? this.earnedCoupons,
      invitedCount: invitedCount ?? this.invitedCount,
      shareCode: shareCode ?? this.shareCode,
      lineUserId: lineUserId ?? this.lineUserId,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      referredByMemberId: referredByMemberId ?? this.referredByMemberId,
      referredByShareCode: referredByShareCode ?? this.referredByShareCode,
      referredAt: referredAt ?? this.referredAt,
    );
  }

  backend.VeevaMember toBackend() {
    return backend.VeevaMember(
      id: lineUserId ?? name,
      name: name,
      hospital: hospital,
      department: department,
      status: _memberStatusToBackend(status),
      accountStatus: _memberAccountStatusToBackend(accountStatus),
      earnedCoupons: earnedCoupons,
      invitedCount: invitedCount,
      shareCode: shareCode,
      lineUserId: lineUserId,
      avatarUrl: avatarUrl,
      referredByMemberId: referredByMemberId,
      referredByShareCode: referredByShareCode,
      referredAt: referredAt,
    );
  }
}

MemberStatus _memberStatusFromBackend(backend.VeevaMemberStatus status) {
  return switch (status) {
    backend.VeevaMemberStatus.guest => MemberStatus.guest,
    backend.VeevaMemberStatus.loggedIn => MemberStatus.loggedIn,
    backend.VeevaMemberStatus.pendingReview => MemberStatus.pendingReview,
    backend.VeevaMemberStatus.verified => MemberStatus.verified,
  };
}

backend.VeevaMemberStatus _memberStatusToBackend(MemberStatus status) {
  return switch (status) {
    MemberStatus.guest => backend.VeevaMemberStatus.guest,
    MemberStatus.loggedIn => backend.VeevaMemberStatus.loggedIn,
    MemberStatus.pendingReview => backend.VeevaMemberStatus.pendingReview,
    MemberStatus.verified => backend.VeevaMemberStatus.verified,
  };
}

MemberAccountStatus _memberAccountStatusFromBackend(
  backend.VeevaMemberAccountStatus status,
) {
  return switch (status) {
    backend.VeevaMemberAccountStatus.active => MemberAccountStatus.active,
    backend.VeevaMemberAccountStatus.disabled => MemberAccountStatus.disabled,
  };
}

backend.VeevaMemberAccountStatus _memberAccountStatusToBackend(
  MemberAccountStatus status,
) {
  return switch (status) {
    MemberAccountStatus.active => backend.VeevaMemberAccountStatus.active,
    MemberAccountStatus.disabled => backend.VeevaMemberAccountStatus.disabled,
  };
}

class Coupon {
  const Coupon({
    required this.code,
    required this.title,
    required this.status,
    required this.expiresAt,
  });

  factory Coupon.fromBackend(backend.VeevaReward reward) {
    return Coupon(
      code: reward.id.toUpperCase(),
      title: reward.name,
      status: switch (reward.status) {
        backend.VeevaRewardStatus.active => CouponStatus.available,
        backend.VeevaRewardStatus.paused => CouponStatus.expired,
        backend.VeevaRewardStatus.expired => CouponStatus.expired,
      },
      expiresAt: reward.expiresAt,
    );
  }

  final String code;
  final String title;
  final CouponStatus status;
  final DateTime expiresAt;
}

final defaultCoupons = <Coupon>[
  Coupon(
    code: 'COFFEE-8X2L',
    title: '中杯美式咖啡 1 杯',
    status: CouponStatus.available,
    expiresAt: DateTime(2026, 8, 31),
  ),
  Coupon(
    code: 'TEA-42QK',
    title: '無糖綠茶 1 瓶',
    status: CouponStatus.available,
    expiresAt: DateTime(2026, 9, 15),
  ),
  Coupon(
    code: 'BOOK-7P9A',
    title: '醫學書展 100 元折抵券',
    status: CouponStatus.available,
    expiresAt: DateTime(2026, 10, 5),
  ),
  Coupon(
    code: 'MASK-M3D8',
    title: '醫療口罩 1 盒',
    status: CouponStatus.available,
    expiresAt: DateTime(2026, 7, 20),
  ),
  Coupon(
    code: 'BENTO-Q6R2',
    title: '健康便當折價券',
    status: CouponStatus.available,
    expiresAt: DateTime(2026, 9, 30),
  ),
  Coupon(
    code: 'POINT-L5N1',
    title: '會員點數 300 點',
    status: CouponStatus.available,
    expiresAt: DateTime(2026, 12, 31),
  ),
];

class ReviewItem {
  ReviewItem(this.name, this.hospital, this.department, this.status);

  factory ReviewItem.fromBackend(backend.VeevaReview review) {
    return ReviewItem(
      review.name,
      review.hospital,
      review.department,
      switch (review.status) {
        backend.VeevaReviewStatus.pending => ReviewStatus.pending,
        backend.VeevaReviewStatus.approved => ReviewStatus.approved,
        backend.VeevaReviewStatus.rejected => ReviewStatus.rejected,
      },
    );
  }

  final String name;
  final String hospital;
  final String department;
  ReviewStatus status;
}

class AppTheme {
  static ThemeData light() {
    const primary = Color(0xFF216B57);
    const secondary = Color(0xFFC58A2A);
    const surface = Color(0xFFF7F8F4);
    return ThemeData(
      useMaterial3: true,
      fontFamily: 'Roboto',
      colorScheme: ColorScheme.fromSeed(
        seedColor: primary,
        primary: primary,
        secondary: secondary,
        surface: surface,
      ),
      scaffoldBackgroundColor: surface,
      splashFactory: NoSplash.splashFactory,
      highlightColor: Colors.transparent,
      hoverColor: Colors.transparent,
      focusColor: Colors.transparent,
      appBarTheme: const AppBarTheme(
        centerTitle: false,
        backgroundColor: surface,
        elevation: 0,
        scrolledUnderElevation: 0,
        shadowColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
      ),
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: _NoPageTransitionsBuilder(),
          TargetPlatform.iOS: _NoPageTransitionsBuilder(),
          TargetPlatform.macOS: _NoPageTransitionsBuilder(),
          TargetPlatform.windows: _NoPageTransitionsBuilder(),
          TargetPlatform.linux: _NoPageTransitionsBuilder(),
        },
      ),
      cardTheme: CardTheme(
        color: Colors.white,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: const BorderSide(color: Color(0xFFE2E5DC)),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(0, 48),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(0, 48),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      ),
    );
  }
}

class _NoPageTransitionsBuilder extends PageTransitionsBuilder {
  const _NoPageTransitionsBuilder();

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    return child;
  }
}

class AppShell extends StatelessWidget {
  const AppShell({super.key});

  @override
  Widget build(BuildContext context) {
    final scope = AppScope.of(context);
    final isLogin = scope.state.currentPage == AppPage.login;
    return Scaffold(
      appBar: AppBar(
        title: isLogin ? const SizedBox.shrink() : const Text('顧客端 App'),
        leading: isLogin
            ? IconButton(
                tooltip: '返回上一頁',
                onPressed: () {
                  scope.state.currentPage = AppPage.landing;
                  scope.notify();
                },
                icon: const Icon(Icons.arrow_back),
              )
            : null,
        actions: [
          if (!isLogin) const _SystemMessagesButton(),
          const SizedBox(width: 8),
        ],
      ),
      body: RepaintBoundary(
        child: switch (scope.state.currentPage) {
          AppPage.landing => const LandingPage(),
          AppPage.news => const MedicalNewsPage(),
          AppPage.login => const LoginPage(),
          AppPage.survey => const SurveyPage(),
          AppPage.thankYou => const ThankYouPage(),
          AppPage.memberCenter => const MemberCenterPage(),
          AppPage.coupon => const CouponPage(),
        },
      ),
      bottomNavigationBar: isLogin
          ? null
          : _CustomerBottomNav(
              selectedIndex: _selectedCustomerIndex(scope.state.currentPage),
              onDestinationSelected: (index) {
                scope.state.currentPage = switch (index) {
                  0 => AppPage.landing,
                  1 => AppPage.news,
                  2 => AppPage.coupon,
                  3 => AppPage.memberCenter,
                  _ => AppPage.landing,
                };
                scope.notify();
              },
            ),
    );
  }

  int _selectedCustomerIndex(AppPage page) {
    return switch (page) {
      AppPage.news => 1,
      AppPage.coupon => 2,
      AppPage.memberCenter => 3,
      _ => 0,
    };
  }
}

class _CustomerBottomNav extends StatelessWidget {
  const _CustomerBottomNav({
    required this.selectedIndex,
    required this.onDestinationSelected,
  });

  final int selectedIndex;
  final ValueChanged<int> onDestinationSelected;

  static const _items = [
    _CustomerBottomNavItem(
      label: '活動',
      icon: Icons.campaign_outlined,
      selectedIcon: Icons.campaign,
    ),
    _CustomerBottomNavItem(
      label: '最新資訊',
      icon: Icons.newspaper_outlined,
      selectedIcon: Icons.newspaper,
    ),
    _CustomerBottomNavItem(
      label: '兌換券',
      icon: Icons.confirmation_number_outlined,
      selectedIcon: Icons.confirmation_number,
    ),
    _CustomerBottomNavItem(
      label: '會員',
      icon: Icons.account_circle_outlined,
      selectedIcon: Icons.account_circle,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: DecoratedBox(
        key: const Key('customer-bottom-nav'),
        decoration: const BoxDecoration(
          color: Colors.white,
          border: Border(top: BorderSide(color: Color(0xFFDDE7E1))),
        ),
        child: SafeArea(
          top: false,
          child: SizedBox(
            height: 62,
            child: Row(
              children: [
                for (var index = 0; index < _items.length; index++)
                  Expanded(
                    child: _CustomerBottomNavButton(
                      item: _items[index],
                      selected: selectedIndex == index,
                      onTap: () => onDestinationSelected(index),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _CustomerBottomNavItem {
  const _CustomerBottomNavItem({
    required this.label,
    required this.icon,
    required this.selectedIcon,
  });

  final String label;
  final IconData icon;
  final IconData selectedIcon;
}

class _CustomerBottomNavButton extends StatelessWidget {
  const _CustomerBottomNavButton({
    required this.item,
    required this.selected,
    required this.onTap,
  });

  final _CustomerBottomNavItem item;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = selected ? const Color(0xFF216B57) : const Color(0xFF5F6F68);
    return Semantics(
      button: true,
      selected: selected,
      label: item.label,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              selected ? item.selectedIcon : item.icon,
              color: color,
              size: 24,
            ),
            const SizedBox(height: 4),
            Text(
              item.label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: color,
                fontSize: 12,
                fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                letterSpacing: 0,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SystemMessagesButton extends StatefulWidget {
  const _SystemMessagesButton();

  @override
  State<_SystemMessagesButton> createState() => _SystemMessagesButtonState();
}

class _SystemMessagesButtonState extends State<_SystemMessagesButton> {
  static const messages = [
    '恭喜您通過審查，請至信箱查看信件',
    '您的會員資料已更新完成',
    '新活動已上架，歡迎查看活動消息',
  ];
  final LayerLink _layerLink = LayerLink();
  OverlayEntry? _entry;

  @override
  void dispose() {
    _entry?.remove();
    super.dispose();
  }

  void _toggleMessages() {
    if (_entry != null) {
      _hideMessages();
      return;
    }

    _entry = OverlayEntry(
      builder: (context) {
        return Stack(
          children: [
            Positioned.fill(
              child: GestureDetector(
                behavior: HitTestBehavior.translucent,
                onTap: _hideMessages,
              ),
            ),
            CompositedTransformFollower(
              link: _layerLink,
              targetAnchor: Alignment.bottomRight,
              followerAnchor: Alignment.topRight,
              offset: const Offset(0, 10),
              child: const _SystemMessagesPanel(messages: messages),
            ),
          ],
        );
      },
    );
    Overlay.of(context).insert(_entry!);
  }

  void _hideMessages() {
    _entry?.remove();
    _entry = null;
  }

  @override
  Widget build(BuildContext context) {
    return CompositedTransformTarget(
      link: _layerLink,
      child: IconButton.filledTonal(
        tooltip: '系統訊息',
        onPressed: _toggleMessages,
        icon: const Icon(Icons.notifications_outlined),
      ),
    );
  }
}

class _SystemMessagesPanel extends StatelessWidget {
  const _SystemMessagesPanel({required this.messages});

  final List<String> messages;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: Container(
        width: 320,
        constraints: const BoxConstraints(maxWidth: 320),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: const Color(0xFFE2E5DC)),
        ),
        clipBehavior: Clip.hardEdge,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(18, 16, 18, 10),
              child: Text(
                '系統訊息',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
              ),
            ),
            for (var index = 0; index < messages.length; index++) ...[
              if (index > 0)
                const Divider(height: 1, indent: 18, endIndent: 18),
              Padding(
                padding: const EdgeInsets.fromLTRB(18, 14, 18, 14),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      margin: const EdgeInsets.only(top: 7),
                      decoration: const BoxDecoration(
                        color: Color(0xFF216B57),
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        messages[index],
                        style: const TextStyle(
                          height: 1.45,
                          color: Color(0xFF26342F),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class LandingPage extends StatelessWidget {
  const LandingPage({super.key});

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final isWide = width >= 900;
    return SingleChildScrollView(
      key: const ValueKey('landing'),
      physics: const ClampingScrollPhysics(),
      padding: EdgeInsets.symmetric(
        horizontal: isWide ? 56 : 20,
        vertical: isWide ? 40 : 24,
      ),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1120),
          child: const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _ActivityHeader(),
              SizedBox(height: 22),
              _ActivityNewsGrid(),
            ],
          ),
        ),
      ),
    );
  }
}

class _ActivityHeader extends StatelessWidget {
  const _ActivityHeader();

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '活動消息',
          style: textTheme.headlineMedium?.copyWith(
            fontWeight: FontWeight.w800,
            color: const Color(0xFF153B32),
            letterSpacing: 0,
          ),
        ),
      ],
    );
  }
}

class ActivityNews {
  const ActivityNews({
    required this.label,
    required this.title,
    required this.description,
    required this.reward,
    required this.icon,
    required this.active,
  });

  factory ActivityNews.fromBackend(backend.VeevaActivity activity) {
    return ActivityNews(
      label: activity.label,
      title: activity.title,
      description: activity.description,
      reward: activity.reward,
      icon: activity.active
          ? Icons.local_cafe_outlined
          : Icons.event_available_outlined,
      active: activity.active,
    );
  }

  final String label;
  final String title;
  final String description;
  final String reward;
  final IconData icon;
  final bool active;
}

class _ActivityNewsGrid extends StatelessWidget {
  const _ActivityNewsGrid();

  @override
  Widget build(BuildContext context) {
    final items = AppScope.of(context).state.activities;
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 920
            ? 3
            : constraints.maxWidth >= 620
                ? 2
                : 1;
        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: items.length,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: columns,
            crossAxisSpacing: 16,
            mainAxisSpacing: 16,
            childAspectRatio: columns == 1 ? 1.42 : .92,
          ),
          itemBuilder: (context, index) {
            return _ActivityNewsCard(news: items[index]);
          },
        );
      },
    );
  }
}

class _ActivityNewsCard extends StatelessWidget {
  const _ActivityNewsCard({required this.news});

  final ActivityNews news;

  @override
  Widget build(BuildContext context) {
    final scope = AppScope.of(context);
    final cardColor =
        news.active ? const Color(0xFFFFFBF1) : const Color(0xFFF7FBF8);
    final accentColor =
        news.active ? const Color(0xFFC58A2A) : const Color(0xFF216B57);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE2E5DC)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 52,
                  height: 52,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFFE2E5DC)),
                  ),
                  child: Icon(news.icon, color: accentColor),
                ),
                const Spacer(),
                _SoftTag(label: news.label, color: accentColor),
              ],
            ),
            const SizedBox(height: 20),
            Text(
              news.title,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: const Color(0xFF243A33),
                    letterSpacing: 0,
                  ),
            ),
            const SizedBox(height: 10),
            Expanded(
              child: Text(
                news.description,
                style: const TextStyle(height: 1.45, color: Color(0xFF4C5A55)),
              ),
            ),
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFFE2E5DC)),
              ),
              child: Row(
                children: [
                  Icon(Icons.card_giftcard_outlined,
                      size: 18, color: accentColor),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      news.reward,
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                  ),
                ],
              ),
            ),
            const Spacer(),
            Align(
              alignment: Alignment.bottomRight,
              child: FilledButton.icon(
                key: news.active ? const Key('start-login-button') : null,
                onPressed: news.active
                    ? () {
                        scope.state.currentPage = AppPage.login;
                        scope.notify();
                      }
                    : null,
                style: FilledButton.styleFrom(
                  backgroundColor: news.active
                      ? const Color(0xFF216B57)
                      : const Color(0xFFDDE7E1),
                  foregroundColor:
                      news.active ? Colors.white : const Color(0xFF67746E),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                icon:
                    Icon(news.active ? Icons.arrow_forward : Icons.lock_clock),
                label: Text(news.active ? '立即開始' : '尚未開放'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SoftTag extends StatelessWidget {
  const _SoftTag({
    required this.label,
    required this.color,
  });

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: color.withOpacity(.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        child: Text(
          label,
          style: TextStyle(
            color: color,
            fontSize: 12,
            fontWeight: FontWeight.w800,
            letterSpacing: 0,
          ),
        ),
      ),
    );
  }
}

Future<void> _startLineLogin(BuildContext context, AppPage nextPage) async {
  final scope = AppScope.of(context);
  scope.state.isLiffBusy = true;
  scope.state.authError = null;
  scope.notify();
  await scope.state.loginWithLine(nextPage: nextPage);
  if (context.mounted) {
    scope.notify();
  }
}

class _LiffStatusNotice extends StatelessWidget {
  const _LiffStatusNotice({
    required this.text,
    required this.isError,
  });

  final String text;
  final bool isError;

  @override
  Widget build(BuildContext context) {
    final color = isError ? const Color(0xFF9A3412) : const Color(0xFF216B57);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: color.withOpacity(.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(.22)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              isError ? Icons.info_outline : Icons.check_circle_outline,
              size: 18,
              color: color,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                text,
                style: TextStyle(
                  color: color,
                  fontSize: 13,
                  height: 1.45,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class LoginPage extends StatelessWidget {
  const LoginPage({super.key});

  @override
  Widget build(BuildContext context) {
    final scope = AppScope.of(context);
    final state = scope.state;
    return Center(
      key: const ValueKey('login'),
      child: SingleChildScrollView(
        physics: const ClampingScrollPhysics(),
        padding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 360),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                '會員登入',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0,
                    ),
              ),
              const SizedBox(height: 28),
              if (state.loginNoticeText != null) ...[
                _LiffStatusNotice(
                  text: state.loginNoticeText!,
                  isError: state.loginNoticeIsError,
                ),
                const SizedBox(height: 14),
              ],
              _SocialLoginButton(
                key: const Key('line-login-button'),
                backgroundColor: const Color(0xFF06C755),
                foregroundColor: Colors.white,
                icon: const _BrandIcon(
                  asset: 'assets/brand/line-login-icon.png',
                  size: 28,
                ),
                label: '使用 LINE 登入',
                onPressed: state.isLiffBusy
                    ? null
                    : () => _startLineLogin(context, AppPage.survey),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class SurveyPage extends StatelessWidget {
  const SurveyPage({super.key});

  @override
  Widget build(BuildContext context) {
    final scope = AppScope.of(context);
    return _PageFrame(
      key: const ValueKey('survey'),
      title: 'Veeva 問卷填寫',
      subtitle: '請直接在下方完成 Veeva 問卷，完成後按下頁面下方按鈕送出審核。',
      maxWidth: 1280,
      padding: const EdgeInsets.fromLTRB(8, 12, 8, 20),
      showHeader: false,
      child: EmbeddedSurveyWebForm(
        url: veevaSurveyUrl,
        onSurveyCompleted: () {
          scope.state.completeSurvey();
          scope.notify();
        },
      ),
    );
  }
}

class ThankYouPage extends StatelessWidget {
  const ThankYouPage({super.key});

  @override
  Widget build(BuildContext context) {
    final scope = AppScope.of(context);
    return LayoutBuilder(
      key: const ValueKey('thankYou'),
      builder: (context, constraints) {
        return SingleChildScrollView(
          physics: const ClampingScrollPhysics(),
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight),
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 520),
                  child: SizedBox(
                    width: double.infinity,
                    child: Card(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: 28,
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.check_circle_outline, size: 72),
                            const SizedBox(height: 16),
                            const Text(
                              'Thank You!',
                              style: TextStyle(
                                fontSize: 28,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(height: 10),
                            const Text('審查結果將會寄至您的信箱'),
                            const SizedBox(height: 22),
                            FilledButton.icon(
                              key: const Key('approve-current-member-button'),
                              onPressed: () {
                                scope.state.approveCurrentMember();
                                scope.state.currentPage = AppPage.memberCenter;
                                scope.notify();
                              },
                              icon: const Icon(Icons.verified_outlined),
                              label: const Text('回首頁'),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class MemberCenterPage extends StatelessWidget {
  const MemberCenterPage({super.key});

  @override
  Widget build(BuildContext context) {
    final scope = AppScope.of(context);
    final state = scope.state;
    final member = state.member;
    final isLoggedIn = member.status != MemberStatus.guest;
    final verified = member.status == MemberStatus.verified;
    if (!isLoggedIn) {
      final isSyncingLineMember =
          state.isLiffBusy || state.liffSession.isLoggedIn;
      return _PageFrame(
        key: const ValueKey('memberLogin'),
        title: '會員中心',
        subtitle: '',
        child: isSyncingLineMember
            ? const _MemberSyncingNotice()
            : const _MemberLoginPrompt(),
      );
    }
    return _PageFrame(
      key: const ValueKey('memberCenter'),
      title: '會員中心',
      subtitle: verified ? '已完成資格驗證' : '完成問卷後即可啟用完整會員功能。',
      child: Column(
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      _MemberAvatar(
                        name: member.name,
                        avatarUrl: member.avatarUrl,
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              member.name,
                              style: const TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            Text(
                              verified
                                  ? '${member.hospital} | ${member.department}'
                                  : '尚未完成會員流程',
                            ),
                          ],
                        ),
                      ),
                      _Tag(label: verified ? '已驗證' : '未完成'),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      Expanded(
                        child: _StatTile(
                          label: '已得券',
                          value: '${member.earnedCoupons}',
                          icon: Icons.local_cafe_outlined,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _StatTile(
                          label: '已邀請',
                          value: '${member.invitedCount}',
                          icon: Icons.group_add_outlined,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          const _MemberFeatureList(),
          const SizedBox(height: 16),
          const _MemberInviteShareCard(),
        ],
      ),
    );
  }
}

String _memberLiffInviteLink(MemberProfile member) {
  return Uri.https(
    'liff.line.me',
    '/$_configuredLiffId/',
    {
      'open': 'invite',
      'ref': member.shareCode,
    },
  ).toString();
}

Future<void> _shareMemberInvite(BuildContext context) async {
  final scope = AppScope.of(context);
  scope.state.inviteShareMessage = null;
  scope.notify();
  await scope.state.shareMemberInvite();
  if (!context.mounted) return;
  scope.notify();
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text(scope.state.inviteShareMessage ?? '已開啟 LINE 分享視窗')),
  );
}

class _MemberInviteShareCard extends StatelessWidget {
  const _MemberInviteShareCard();

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context).state;
    return Card(
      key: const Key('member-invite-share-card'),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: const Color(0xFFEAF3EA),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.ios_share_outlined,
                    color: Color(0xFF216B57),
                  ),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text(
                    '邀請好友',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                SizedBox(
                  width: 132,
                  height: 48,
                  child: FilledButton(
                    key: const Key('share-member-invite-button'),
                    onPressed: state.isInviteShareBusy
                        ? null
                        : () => _shareMemberInvite(context),
                    style: FilledButton.styleFrom(
                      padding: EdgeInsets.zero,
                      alignment: Alignment.center,
                    ),
                    child: Center(
                      child: state.isInviteShareBusy
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.4,
                                color: Colors.white,
                              ),
                            )
                          : const Text(
                              '分享給好友',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontWeight: FontWeight.w800,
                                letterSpacing: 0,
                              ),
                            ),
                    ),
                  ),
                ),
              ],
            ),
            if (state.inviteShareMessage != null) ...[
              const SizedBox(height: 14),
              _LiffStatusNotice(
                text: state.inviteShareMessage!,
                isError: state.inviteShareIsError,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _MemberAvatar extends StatelessWidget {
  const _MemberAvatar({
    required this.name,
    required this.avatarUrl,
  });

  static const double size = 56;

  final String name;
  final String? avatarUrl;

  @override
  Widget build(BuildContext context) {
    final url = avatarUrl;
    if (url == null || url.isEmpty) {
      return _MemberAvatarFallback(name: name);
    }
    return RepaintBoundary(
      child: ClipOval(
        child: Image.network(
          url,
          width: size,
          height: size,
          fit: BoxFit.cover,
          cacheWidth: 112,
          cacheHeight: 112,
          filterQuality: FilterQuality.low,
          gaplessPlayback: true,
          loadingBuilder: (context, child, loadingProgress) {
            if (loadingProgress == null) {
              return child;
            }
            return _MemberAvatarFallback(name: name);
          },
          errorBuilder: (context, error, stackTrace) {
            return _MemberAvatarFallback(name: name);
          },
        ),
      ),
    );
  }
}

class _MemberAvatarFallback extends StatelessWidget {
  const _MemberAvatarFallback({required this.name});

  final String name;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        color: Color(0xFFEAF3EA),
      ),
      child: SizedBox(
        width: _MemberAvatar.size,
        height: _MemberAvatar.size,
        child: Center(
          child: Text(
            _avatarInitial(name),
            style: const TextStyle(
              color: Color(0xFF216B57),
              fontSize: 20,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
      ),
    );
  }
}

void _showReferralRecordsDialog(BuildContext context) {
  final scope = AppScope.of(context);
  final member = scope.state.member;
  showDialog<void>(
    context: context,
    builder: (dialogContext) {
      return _ReferralRecordsDialog(
        memberId: member.lineUserId ?? member.name,
        repository: scope.state.repository,
      );
    },
  );
}

class _ReferralRecordsDialog extends StatefulWidget {
  const _ReferralRecordsDialog({
    required this.memberId,
    required this.repository,
  });

  final String memberId;
  final VeevaRepository repository;

  @override
  State<_ReferralRecordsDialog> createState() => _ReferralRecordsDialogState();
}

class _ReferralRecordsDialogState extends State<_ReferralRecordsDialog> {
  late Future<List<backend.VeevaReferral>> _recordsFuture;

  @override
  void initState() {
    super.initState();
    _recordsFuture = _loadRecords();
  }

  Future<List<backend.VeevaReferral>> _loadRecords() {
    return widget.repository.loadReferralRecords(widget.memberId);
  }

  void _refreshRecords() {
    setState(() {
      _recordsFuture = _loadRecords();
    });
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      key: const Key('referral-records-dialog'),
      scrollable: true,
      insetPadding: const EdgeInsets.all(20),
      titlePadding: const EdgeInsets.fromLTRB(24, 22, 16, 8),
      contentPadding: const EdgeInsets.fromLTRB(24, 8, 24, 10),
      actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      title: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: const Color(0xFFEAF3EA),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(
              Icons.group_add_outlined,
              color: Color(0xFF216B57),
            ),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Text(
              '邀請紀錄',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
            ),
          ),
          IconButton(
            tooltip: '關閉',
            onPressed: () => Navigator.of(context).pop(),
            icon: const Icon(Icons.close),
          ),
        ],
      ),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
        child: FutureBuilder<List<backend.VeevaReferral>>(
          future: _recordsFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return const _ReferralRecordsStatus(
                label: '正在讀取邀請紀錄',
                progress: true,
              );
            }
            if (snapshot.hasError) {
              return _ReferralRecordsStatus(
                label: '邀請紀錄讀取失敗',
                icon: Icons.info_outline,
                action: TextButton.icon(
                  onPressed: _refreshRecords,
                  icon: const Icon(Icons.refresh),
                  label: const Text('重試'),
                ),
              );
            }
            final records = snapshot.data ?? const <backend.VeevaReferral>[];
            if (records.isEmpty) {
              return const _ReferralRecordsStatus(
                label: '目前尚無邀請成功紀錄',
                icon: Icons.person_add_disabled_outlined,
              );
            }
            return Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Row(
                    children: [
                      const Expanded(
                        child: Text(
                          '好友透過分享連結完成 LINE 登入',
                          style: TextStyle(
                            color: Color(0xFF5F6F68),
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      _Tag(label: '${records.length} 位'),
                    ],
                  ),
                ),
                for (var index = 0; index < records.length; index++) ...[
                  _ReferralRecordTile(record: records[index]),
                  if (index != records.length - 1) const Divider(height: 1),
                ],
              ],
            );
          },
        ),
      ),
      actions: [
        TextButton.icon(
          key: const Key('refresh-referral-records-button'),
          onPressed: _refreshRecords,
          icon: const Icon(Icons.refresh),
          label: const Text('重新整理'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('關閉'),
        ),
      ],
    );
  }
}

class _ReferralRecordsStatus extends StatelessWidget {
  const _ReferralRecordsStatus({
    required this.label,
    this.icon,
    this.progress = false,
    this.action,
  });

  final String label;
  final IconData? icon;
  final bool progress;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0xFFF7F8F4),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE2E5DC)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
        child: Row(
          children: [
            if (progress)
              const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2.4),
              )
            else
              Icon(icon ?? Icons.info_outline, color: const Color(0xFF6B7671)),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                label,
                style: const TextStyle(
                  color: Color(0xFF5F6F68),
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            if (action != null) ...[
              const SizedBox(width: 8),
              action!,
            ],
          ],
        ),
      ),
    );
  }
}

class _ReferralRecordTile extends StatelessWidget {
  const _ReferralRecordTile({required this.record});

  final backend.VeevaReferral record;

  @override
  Widget build(BuildContext context) {
    final createdAt = record.createdAt;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        children: [
          CircleAvatar(
            radius: 20,
            backgroundColor: const Color(0xFFEAF3EA),
            child: Text(
              _avatarInitial(record.inviteeName),
              style: const TextStyle(
                color: Color(0xFF216B57),
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  record.inviteeName.isEmpty ? 'LINE 會員' : record.inviteeName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  createdAt == null
                      ? '登入時間同步中'
                      : '登入時間 ${_formatDateTime(createdAt)}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Color(0xFF6B7671),
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          const _Tag(label: '已登入'),
        ],
      ),
    );
  }
}

String _avatarInitial(String name) {
  final text = name.trim();
  if (text.isEmpty) {
    return 'L';
  }
  return text.characters.first.toUpperCase();
}

class _MemberLoginPrompt extends StatelessWidget {
  const _MemberLoginPrompt();

  @override
  Widget build(BuildContext context) {
    final scope = AppScope.of(context);
    final state = scope.state;
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 360),
        child: Card(
          child: Padding(
            padding: const EdgeInsets.all(22),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Icon(Icons.account_circle_outlined, size: 56),
                const SizedBox(height: 16),
                const Text(
                  '登入會員',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 22),
                if (state.loginNoticeText != null) ...[
                  _LiffStatusNotice(
                    text: state.loginNoticeText!,
                    isError: state.loginNoticeIsError,
                  ),
                  const SizedBox(height: 14),
                ],
                _SocialLoginButton(
                  key: const Key('member-line-login-button'),
                  backgroundColor: const Color(0xFF06C755),
                  foregroundColor: Colors.white,
                  icon: const _BrandIcon(
                    asset: 'assets/brand/line-login-icon.png',
                    size: 28,
                  ),
                  label: '使用 LINE 登入',
                  onPressed: state.isLiffBusy
                      ? null
                      : () => _startLineLogin(context, AppPage.memberCenter),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _MemberSyncingNotice extends StatelessWidget {
  const _MemberSyncingNotice();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 360),
        child: const Card(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  width: 32,
                  height: 32,
                  child: CircularProgressIndicator(strokeWidth: 3),
                ),
                SizedBox(height: 18),
                Text(
                  '正在同步 LINE 會員資料',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
                ),
                SizedBox(height: 8),
                Text(
                  '請稍候，系統正在確認您的登入狀態。',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Color(0xFF5F6F68), height: 1.45),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _MemberFeatureList extends StatelessWidget {
  const _MemberFeatureList();

  static const items = [
    _MemberFeatureItem(
      icon: Icons.edit_outlined,
      title: '編輯會員資料',
      subtitle: '更新姓名、院所、科別與聯絡方式',
    ),
    _MemberFeatureItem(
      icon: Icons.notifications_active_outlined,
      title: '通知設定',
      subtitle: '管理活動、兌換券與系統訊息提醒',
    ),
    _MemberFeatureItem(
      icon: Icons.history_outlined,
      title: '活動紀錄',
      subtitle: '查看問卷、活動參與與審核狀態',
    ),
    _MemberFeatureItem(
      icon: Icons.group_add_outlined,
      title: '邀請紀錄',
      subtitle: '追蹤好友邀請與推薦成果',
      action: _MemberFeatureAction.referralRecords,
    ),
    _MemberFeatureItem(
      icon: Icons.support_agent_outlined,
      title: '客服協助',
      subtitle: '回報兌換問題或會員資料異常',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '會員功能',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 12),
            for (var index = 0; index < items.length; index++) ...[
              _MemberFeatureTile(
                key: items[index].action == _MemberFeatureAction.referralRecords
                    ? const Key('member-feature-referral-records-button')
                    : null,
                item: items[index],
                onTap:
                    items[index].action == _MemberFeatureAction.referralRecords
                        ? () => _showReferralRecordsDialog(context)
                        : () {},
              ),
              if (index != items.length - 1) const Divider(height: 1),
            ],
          ],
        ),
      ),
    );
  }
}

class _MemberFeatureItem {
  const _MemberFeatureItem({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.action,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final _MemberFeatureAction? action;
}

enum _MemberFeatureAction { referralRecords }

class _MemberFeatureTile extends StatelessWidget {
  const _MemberFeatureTile({
    required this.item,
    required this.onTap,
    super.key,
  });

  final _MemberFeatureItem item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(item.icon),
      title: Text(
        item.title,
        style: const TextStyle(fontWeight: FontWeight.w800),
      ),
      subtitle: Text(item.subtitle),
      trailing: const Icon(Icons.chevron_right),
      onTap: onTap,
    );
  }
}

class MedicalNewsPage extends StatelessWidget {
  const MedicalNewsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return _PageFrame(
      key: const ValueKey('medicalNews'),
      title: '最新資訊',
      subtitle: '',
      maxWidth: 1120,
      child: _MedicalNewsGrid(items: AppScope.of(context).state.medicalNews),
    );
  }
}

class MedicalNewsItem {
  const MedicalNewsItem({
    required this.date,
    required this.source,
    required this.title,
    required this.summary,
  });

  factory MedicalNewsItem.fromBackend(backend.VeevaNews news) {
    return MedicalNewsItem(
      date: news.date,
      source: news.source,
      title: news.title,
      summary: news.summary,
    );
  }

  final String date;
  final String source;
  final String title;
  final String summary;
}

class _MedicalNewsGrid extends StatelessWidget {
  const _MedicalNewsGrid({required this.items});

  final List<MedicalNewsItem> items;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 940
            ? 3
            : constraints.maxWidth >= 640
                ? 2
                : 1;
        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: items.length,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: columns,
            crossAxisSpacing: 14,
            mainAxisSpacing: 14,
            mainAxisExtent: 84,
          ),
          itemBuilder: (context, index) {
            return _MedicalNewsCard(item: items[index]);
          },
        );
      },
    );
  }
}

class _MedicalNewsCard extends StatelessWidget {
  const _MedicalNewsCard({required this.item});

  final MedicalNewsItem item;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0xFFF7FBF8),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE2E5DC)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Container(
              width: 40,
              height: 40,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFFE2E5DC)),
              ),
              child: const Icon(
                Icons.medical_information_outlined,
                size: 20,
                color: Color(0xFF216B57),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF243A33),
                      height: 1.2,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '${item.date} · ${item.source}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF6B7671),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            const Icon(
              Icons.chevron_right,
              color: Color(0xFF98A29D),
            ),
          ],
        ),
      ),
    );
  }
}

class CouponPage extends StatelessWidget {
  const CouponPage({super.key});

  @override
  Widget build(BuildContext context) {
    final coupons = AppScope.of(context).state.coupons;
    return _PageFrame(
      key: const ValueKey('coupon'),
      title: '兌換券',
      subtitle: '',
      child: Column(
        children: [
          for (final coupon in coupons)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _RedeemCouponCard(
                coupon: coupon,
                onRedeem: () => _showRedeemDialog(context, coupon),
              ),
            ),
        ],
      ),
    );
  }

  void _showRedeemDialog(BuildContext context, Coupon coupon) {
    showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('確認兌換'),
          content: Text('是否要兌換「${coupon.title}」？'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('確認兌換'),
            ),
          ],
        );
      },
    );
  }
}

class _RedeemCouponCard extends StatelessWidget {
  const _RedeemCouponCard({
    required this.coupon,
    required this.onRedeem,
  });

  final Coupon coupon;
  final VoidCallback onRedeem;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: const Color(0xFFEAF3EA),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(
                Icons.confirmation_number_outlined,
                color: Color(0xFF216B57),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    coupon.title,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text('兌換期限 ${_formatDate(coupon.expiresAt)}'),
                ],
              ),
            ),
            FilledButton(
              key: coupon.code == 'COFFEE-8X2L'
                  ? const Key('redeem-coupon-button')
                  : null,
              onPressed: onRedeem,
              child: const Text('兌換'),
            ),
          ],
        ),
      ),
    );
  }
}

class _PageFrame extends StatelessWidget {
  const _PageFrame({
    required this.title,
    required this.subtitle,
    required this.child,
    this.maxWidth = 760,
    this.padding = const EdgeInsets.all(20),
    this.showHeader = true,
    super.key,
  });

  final String title;
  final String subtitle;
  final Widget child;
  final double maxWidth;
  final EdgeInsetsGeometry padding;
  final bool showHeader;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      physics: const ClampingScrollPhysics(),
      padding: padding,
      child: Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: maxWidth),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (showHeader) ...[
                Text(
                  title,
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0,
                      ),
                ),
                const SizedBox(height: 8),
                Text(subtitle),
                const SizedBox(height: 20),
              ],
              child,
            ],
          ),
        ),
      ),
    );
  }
}

class _Tag extends StatelessWidget {
  const _Tag({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0xFFEAF3EA),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: const Color(0xFFD7E4D7)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        child: Text(
          label,
          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12),
        ),
      ),
    );
  }
}

class _SocialLoginButton extends StatelessWidget {
  const _SocialLoginButton({
    required this.backgroundColor,
    required this.foregroundColor,
    required this.icon,
    required this.label,
    required this.onPressed,
    super.key,
  });

  final Color backgroundColor;
  final Color foregroundColor;
  final Widget icon;
  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null;
    final effectiveBackground =
        enabled ? backgroundColor : backgroundColor.withOpacity(.56);
    final effectiveForeground =
        enabled ? foregroundColor : foregroundColor.withOpacity(.72);
    return SizedBox(
      height: 48,
      child: Material(
        color: effectiveBackground,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: BorderSide(color: effectiveBackground),
        ),
        clipBehavior: Clip.hardEdge,
        child: InkWell(
          onTap: onPressed,
          child: Stack(
            alignment: Alignment.center,
            children: [
              Positioned(left: 14, child: icon),
              Text(
                label,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: effectiveForeground,
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BrandIcon extends StatelessWidget {
  const _BrandIcon({
    required this.asset,
    required this.size,
  });

  final String asset;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      asset,
      width: size,
      height: size,
      fit: BoxFit.contain,
    );
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile({
    required this.label,
    required this.value,
    required this.icon,
  });

  final String label;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Row(
          children: [
            Icon(icon),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label),
                  const SizedBox(height: 4),
                  Text(
                    value,
                    style: const TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
