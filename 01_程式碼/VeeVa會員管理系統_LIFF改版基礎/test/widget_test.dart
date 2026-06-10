import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:veeva_member_app/data/veeva_models.dart' as backend;
import 'package:veeva_member_app/data/veeva_repository.dart';
import 'package:veeva_member_app/main.dart';
import 'package:veeva_member_app/services/liff_service.dart';
import 'package:veeva_member_app/survey_embed_stub.dart';

void main() {
  testWidgets('user can complete the reward flow', (tester) async {
    await tester.pumpWidget(const VeevaMemberApp());

    expect(find.text('填問卷，拿咖啡券'), findsOneWidget);

    await tester.ensureVisible(find.byKey(const Key('start-login-button')));
    await tester.tap(find.byKey(const Key('start-login-button')));
    await tester.pumpAndSettle();
    expect(find.text('會員登入'), findsOneWidget);
    expect(find.text('使用 LINE 登入'), findsOneWidget);
    expect(find.text('使用 Google 登入'), findsNothing);
    expect(find.text('返回活動首頁'), findsNothing);

    await tester.ensureVisible(find.byKey(const Key('line-login-button')));
    await tester.tap(find.byKey(const Key('line-login-button')));
    await tester.pumpAndSettle();
    expect(find.text('跨平台 WebView 預覽區'), findsOneWidget);
    expect(find.text('我已完成問卷，送出審核'), findsOneWidget);

    await tester.ensureVisible(find.byKey(const Key('submit-survey-button')));
    await tester.tap(find.byKey(const Key('submit-survey-button')));
    await tester.pumpAndSettle();
    expect(find.text('Thank You!'), findsOneWidget);

    await tester.tap(find.byKey(const Key('approve-current-member-button')));
    await tester.pumpAndSettle();
    expect(find.text('會員中心'), findsOneWidget);
    expect(find.text('會員功能'), findsOneWidget);
    expect(find.text('編輯會員資料'), findsOneWidget);
    expect(find.text('通知設定'), findsOneWidget);
    expect(find.byKey(const Key('share-member-invite-button')), findsOneWidget);
    expect(find.text('分享給好友'), findsOneWidget);
    expect(find.text('用 LINE 卡片分享你的會員邀請'), findsNothing);
    expect(find.text('https://veeva-8d30c.web.app/r/EUSER'), findsNothing);
    expect(find.text('可使用兌換券'), findsNothing);

    await tester.tap(find.text('兌換券'));
    await tester.pumpAndSettle();
    expect(find.text('兌換券'), findsWidgets);
    expect(find.text('中杯美式咖啡 1 杯'), findsOneWidget);
    expect(find.text('兌換期限 2026/08/31'), findsOneWidget);
    expect(find.text('可使用'), findsOneWidget);
    expect(find.text('無糖綠茶 1 瓶'), findsNothing);
    expect(find.text('醫學書展 100 元折抵券'), findsNothing);
    expect(find.text('醫療口罩 1 盒'), findsNothing);
    expect(find.text('健康便當折價券'), findsNothing);
    expect(find.text('會員點數 300 點'), findsNothing);

    await tester.tap(find.byKey(const Key('redeem-coupon-button')));
    await tester.pumpAndSettle();
    expect(find.text('確認兌換'), findsWidgets);
    expect(find.text('是否要兌換「中杯美式咖啡 1 杯」？'), findsOneWidget);
  });

  testWidgets('customer navigation and system messages are available', (
    tester,
  ) async {
    await tester.pumpWidget(const VeevaMemberApp());

    expect(find.byType(NavigationBar), findsNothing);
    expect(find.byKey(const Key('customer-bottom-nav')), findsOneWidget);
    expect(find.text('兌換券'), findsOneWidget);
    expect(
      ['活動', '最新資訊', '兌換券', '會員']
          .every((label) => find.text(label).evaluate().isNotEmpty),
      isTrue,
    );
    expect(find.byTooltip('Admin 後台'), findsNothing);

    await tester.tap(find.byTooltip('系統訊息'));
    await tester.pumpAndSettle();

    expect(find.text('系統訊息'), findsOneWidget);
    expect(find.text('恭喜您通過審查，請至信箱查看信件'), findsOneWidget);
  });

  testWidgets('member page asks guest to sign in', (tester) async {
    await tester.pumpWidget(const VeevaMemberApp());

    await tester.tap(find.text('會員'));
    await tester.pumpAndSettle();

    expect(find.text('登入會員'), findsOneWidget);
    expect(find.byKey(const Key('member-line-login-button')), findsOneWidget);
    expect(find.byKey(const Key('member-google-login-button')), findsNothing);
    expect(find.text('使用 Google 登入'), findsNothing);
    expect(find.text('會員功能'), findsNothing);

    await tester.tap(find.byKey(const Key('member-line-login-button')));
    await tester.pumpAndSettle();

    expect(find.text('會員功能'), findsOneWidget);
    expect(find.text('編輯會員資料'), findsOneWidget);
  });

  testWidgets('member page shows syncing state while LINE session loads', (
    tester,
  ) async {
    final sessionCompleter = Completer<LiffSession>();

    await tester.pumpWidget(
      VeevaMemberApp(
        liffService: _PendingLiffService(sessionCompleter.future),
      ),
    );

    await tester.tap(find.text('會員'));
    await tester.pump();

    expect(find.text('正在同步 LINE 會員資料'), findsOneWidget);
    expect(find.byKey(const Key('member-line-login-button')), findsNothing);

    sessionCompleter.complete(
      const LiffSession(
        isInitialized: true,
        isLoggedIn: true,
        isInClient: false,
        isRedirecting: false,
        profile: LiffProfile(
          userId: 'pending-line-user',
          displayName: '同步會員',
        ),
        idToken: 'pending-id-token',
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('會員功能'), findsOneWidget);
    expect(find.text('同步會員'), findsOneWidget);
  });

  testWidgets('line login writes member with LINE id token', (tester) async {
    final repository = _RecordingVeevaRepository();

    await tester.pumpWidget(VeevaMemberApp(repository: repository));

    await tester.ensureVisible(find.byKey(const Key('start-login-button')));
    await tester.tap(find.byKey(const Key('start-login-button')));
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.byKey(const Key('line-login-button')));
    await tester.tap(find.byKey(const Key('line-login-button')));
    await tester.pumpAndSettle();

    expect(repository.upsertCount, 1);
    expect(repository.lineUserId, 'demo-line-user');
    expect(repository.displayName, '王小明');
    expect(repository.lineIdToken, 'demo-id-token');
  });

  testWidgets('line login forwards referral code to repository', (
    tester,
  ) async {
    final repository = _RecordingVeevaRepository();

    await tester.pumpWidget(
      VeevaMemberApp(
        repository: repository,
        liffService: const _LoggedInReferralLiffService(),
      ),
    );
    await tester.pumpAndSettle();

    expect(repository.upsertCount, 1);
    expect(repository.referralCode, 'A8D2K');
  });

  testWidgets('member page shows successful referral records', (tester) async {
    final repository = _ReferralRecordsRepository();

    await tester.pumpWidget(
      VeevaMemberApp(
        repository: repository,
        liffService: const _LoggedInMemberLiffService(),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('會員'));
    await tester.pumpAndSettle();

    expect(repository.referralLookupMemberId, isNull);
    expect(find.byKey(const Key('member-feature-referral-records-button')),
        findsOneWidget);
    expect(find.text('陳小華'), findsNothing);

    await tester.ensureVisible(
      find.byKey(const Key('member-feature-referral-records-button')),
    );
    await tester.tap(
      find.byKey(const Key('member-feature-referral-records-button')),
    );
    await tester.pumpAndSettle();

    expect(repository.referralLookupMemberId, 'inviter-line-user');
    expect(find.byKey(const Key('referral-records-dialog')), findsOneWidget);
    expect(find.text('邀請紀錄'), findsWidgets);
    expect(find.text('陳小華'), findsOneWidget);
    expect(find.text('登入時間 2026/06/05 14:20'), findsOneWidget);
    expect(find.text('已登入'), findsOneWidget);
  });

  testWidgets('member page shares invite through LINE target picker', (
    tester,
  ) async {
    final liffService = _RecordingShareLiffService();

    await tester.pumpWidget(VeevaMemberApp(liffService: liffService));
    await tester.pumpAndSettle();

    await tester.tap(find.text('會員'));
    await tester.pumpAndSettle();

    await tester
        .ensureVisible(find.byKey(const Key('share-member-invite-button')));
    await tester.tap(find.byKey(const Key('share-member-invite-button')));
    await tester.pumpAndSettle();

    expect(liffService.shareCount, 1);
    expect(liffService.lastInvite?.inviterName, '分享測試會員');
    expect(liffService.lastInvite?.shareCode, 'EUSER');
    expect(
      liffService.lastInvite?.inviteUrl,
      'https://liff.line.me/2010298394-7PwRtpTY/?open=invite&ref=EUSER',
    );
    expect(find.text('已開啟 LINE 分享視窗'), findsWidgets);
  });

  testWidgets('landing page shows activity news cards', (tester) async {
    await tester.pumpWidget(const VeevaMemberApp());

    expect(find.text('活動消息'), findsOneWidget);
    expect(find.text('填問卷，拿咖啡券'), findsOneWidget);
    expect(find.text('研討會報名提醒'), findsOneWidget);
    expect(find.text('院所限定任務'), findsOneWidget);
    expect(find.text('LINE 登入'), findsNothing);
    expect(find.text('資格審核'), findsNothing);
  });

  testWidgets('member can register for an activity', (tester) async {
    final repository = _RegistrationActivityRepository();
    await tester.pumpWidget(
      VeevaMemberApp(
        repository: repository,
        liffService: const _LoggedInMemberLiffService(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('醫學會講座報名'), findsOneWidget);
    await tester.ensureVisible(find.byKey(const Key('start-login-button')));
    await tester.tap(find.byKey(const Key('start-login-button')));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('activityRegistration')), findsOneWidget);
    expect(find.text('活動報名'), findsWidgets);

    await tester.tap(find.byKey(const Key('activity-register-button')));
    await tester.pumpAndSettle();

    expect(repository.registeredActivityId, 'seminar-live');
    expect(repository.registeredMemberId, 'inviter-line-user');
    expect(find.text('已完成報名'), findsOneWidget);
    expect(find.text('已報名'), findsOneWidget);
  });

  testWidgets('survey activity embeds its configured survey URL',
      (tester) async {
    await tester.pumpWidget(
      VeevaMemberApp(repository: _SurveyUrlRepository()),
    );
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.byKey(const Key('start-login-button')));
    await tester.tap(find.byKey(const Key('start-login-button')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('line-login-button')));
    await tester.pumpAndSettle();

    final survey = tester.widget<EmbeddedSurveyWebForm>(
      find.byType(EmbeddedSurveyWebForm),
    );
    expect(survey.url, _SurveyUrlRepository.customSurveyUrl);

    await tester.tap(find.byKey(const Key('submit-survey-button')));
    await tester.pumpAndSettle();

    final repository = tester
        .widget<VeevaMemberApp>(find.byType(VeevaMemberApp))
        .repository! as _SurveyUrlRepository;
    expect(repository.completedMemberId, 'demo-line-user');
    expect(repository.completedMemberName, '王小明');
    expect(repository.completedActivityId, 'custom-survey');
    expect(repository.completedActivityTitle, '自訂網址問卷');
    expect(repository.completedSurveyUrl, _SurveyUrlRepository.customSurveyUrl);
  });

  testWidgets('medical news page shows list items', (tester) async {
    await tester.pumpWidget(const VeevaMemberApp());

    await tester.tap(find.text('最新資訊'));
    await tester.pumpAndSettle();

    expect(find.text('最新資訊'), findsWidgets);
    expect(find.text('WHO 發布醫療產品警示'), findsOneWidget);
    expect(find.text('FDA 推動即時臨床試驗追蹤試點'), findsOneWidget);
    expect(find.text('FDA 核准遺傳性聽損基因治療'), findsOneWidget);
    expect(find.text('美國急性呼吸道疾病就醫活動維持低水準'), findsOneWidget);
  });
}

class _LoggedInReferralLiffService implements LiffService {
  const _LoggedInReferralLiffService();

  @override
  Future<LiffSession> initialize() async {
    return const LiffSession(
      isInitialized: true,
      isLoggedIn: true,
      isInClient: false,
      isRedirecting: false,
      referralCode: 'A8D2K',
      profile: LiffProfile(
        userId: 'demo-referral-user',
        displayName: '推薦會員',
      ),
      idToken: 'demo-referral-id-token',
    );
  }

  @override
  Future<LiffSession> login({String? postLoginPage}) => initialize();

  @override
  Future<LiffShareResult> shareInvite(LiffInviteMessage invite) async {
    return LiffShareResult.sent();
  }

  @override
  Future<LiffSession> logout() async {
    return const LiffSession(
      isInitialized: true,
      isLoggedIn: false,
      isInClient: false,
      isRedirecting: false,
    );
  }
}

class _PendingLiffService implements LiffService {
  const _PendingLiffService(this.session);

  final Future<LiffSession> session;

  @override
  Future<LiffSession> initialize() => session;

  @override
  Future<LiffSession> login({String? postLoginPage}) => session;

  @override
  Future<LiffShareResult> shareInvite(LiffInviteMessage invite) async {
    return LiffShareResult.sent();
  }

  @override
  Future<LiffSession> logout() async {
    return const LiffSession(
      isInitialized: true,
      isLoggedIn: false,
      isInClient: false,
      isRedirecting: false,
    );
  }
}

class _LoggedInMemberLiffService implements LiffService {
  const _LoggedInMemberLiffService();

  @override
  Future<LiffSession> initialize() async {
    return const LiffSession(
      isInitialized: true,
      isLoggedIn: true,
      isInClient: false,
      isRedirecting: false,
      profile: LiffProfile(
        userId: 'inviter-line-user',
        displayName: '分享者',
      ),
      idToken: 'inviter-id-token',
    );
  }

  @override
  Future<LiffSession> login({String? postLoginPage}) => initialize();

  @override
  Future<LiffShareResult> shareInvite(LiffInviteMessage invite) async {
    return LiffShareResult.sent();
  }

  @override
  Future<LiffSession> logout() async {
    return const LiffSession(
      isInitialized: true,
      isLoggedIn: false,
      isInClient: false,
      isRedirecting: false,
    );
  }
}

class _RecordingShareLiffService implements LiffService {
  int shareCount = 0;
  LiffInviteMessage? lastInvite;

  @override
  Future<LiffSession> initialize() async {
    return const LiffSession(
      isInitialized: true,
      isLoggedIn: true,
      isInClient: true,
      isRedirecting: false,
      profile: LiffProfile(
        userId: 'share-line-user',
        displayName: '分享測試會員',
      ),
      idToken: 'share-id-token',
    );
  }

  @override
  Future<LiffSession> login({String? postLoginPage}) => initialize();

  @override
  Future<LiffShareResult> shareInvite(LiffInviteMessage invite) async {
    shareCount += 1;
    lastInvite = invite;
    return LiffShareResult.sent();
  }

  @override
  Future<LiffSession> logout() async {
    return const LiffSession(
      isInitialized: true,
      isLoggedIn: false,
      isInClient: false,
      isRedirecting: false,
    );
  }
}

class _ReferralRecordsRepository extends DemoVeevaRepository {
  String? referralLookupMemberId;

  @override
  Future<backend.VeevaMember> upsertLineMember({
    required String lineUserId,
    required String displayName,
    String? avatarUrl,
    String? email,
    String? statusMessage,
    String? lineIdToken,
    String? referralCode,
  }) async {
    return backend.VeevaMember(
      id: lineUserId,
      name: displayName,
      hospital: '',
      department: '',
      status: backend.VeevaMemberStatus.loggedIn,
      earnedCoupons: 0,
      invitedCount: 1,
      shareCode: 'INVTR',
      lineUserId: lineUserId,
      avatarUrl: avatarUrl,
      email: email,
      lineStatusMessage: statusMessage,
      lineIdToken: lineIdToken,
      lineIdTokenUpdatedAt: DateTime(2026, 6, 5, 13),
      createdAt: DateTime(2026, 6, 5, 13),
      lastLineLoginAt: DateTime(2026, 6, 5, 13),
    );
  }

  @override
  Future<List<backend.VeevaReferral>> loadReferralRecords(
    String inviterMemberId,
  ) async {
    referralLookupMemberId = inviterMemberId;
    return [
      backend.VeevaReferral(
        id: '${inviterMemberId}_friend-line-user',
        inviterMemberId: inviterMemberId,
        inviterShareCode: 'INVTR',
        inviteeMemberId: 'friend-line-user',
        inviteeLineUserId: 'friend-line-user',
        inviteeName: '陳小華',
        status: 'linked',
        createdAt: DateTime(2026, 6, 5, 14, 20),
        updatedAt: DateTime(2026, 6, 5, 14, 20),
      ),
    ];
  }
}

class _RecordingVeevaRepository extends DemoVeevaRepository {
  int upsertCount = 0;
  String? lineUserId;
  String? displayName;
  String? lineIdToken;
  String? referralCode;

  @override
  Future<backend.VeevaMember> upsertLineMember({
    required String lineUserId,
    required String displayName,
    String? avatarUrl,
    String? email,
    String? statusMessage,
    String? lineIdToken,
    String? referralCode,
  }) {
    upsertCount += 1;
    this.lineUserId = lineUserId;
    this.displayName = displayName;
    this.lineIdToken = lineIdToken;
    this.referralCode = referralCode;
    return super.upsertLineMember(
      lineUserId: lineUserId,
      displayName: displayName,
      avatarUrl: avatarUrl,
      email: email,
      statusMessage: statusMessage,
      lineIdToken: lineIdToken,
      referralCode: referralCode,
    );
  }
}

class _RegistrationActivityRepository extends DemoVeevaRepository {
  String? registeredMemberId;
  String? registeredActivityId;

  @override
  Future<backend.VeevaBootstrap> loadBootstrap() async {
    return const backend.VeevaBootstrap(
      activities: [
        backend.VeevaActivity(
          id: 'seminar-live',
          type: backend.VeevaActivityType.registration,
          label: '開放報名',
          title: '醫學會講座報名',
          description: '活動敘述與報名資訊會顯示在這裡。',
          reward: '活動報名',
          status: backend.VeevaContentStatus.published,
          active: true,
          periodText: '2026/07/01 - 2026/07/15',
          note: '點選參加報名',
        ),
      ],
      news: [],
      rewards: [],
      reviews: [],
    );
  }

  @override
  Future<void> registerActivity({
    required String memberId,
    required String memberName,
    required String activityId,
  }) async {
    registeredMemberId = memberId;
    registeredActivityId = activityId;
  }
}

class _SurveyUrlRepository extends DemoVeevaRepository {
  static const customSurveyUrl =
      'https://privacyportal.onetrust.com/webform/custom-survey';
  String? completedMemberId;
  String? completedMemberName;
  String? completedActivityId;
  String? completedActivityTitle;
  String? completedSurveyUrl;

  @override
  Future<backend.VeevaBootstrap> loadBootstrap() async {
    return const backend.VeevaBootstrap(
      activities: [
        backend.VeevaActivity(
          id: 'custom-survey',
          type: backend.VeevaActivityType.survey,
          label: '限時問卷',
          title: '自訂網址問卷',
          description: '使用後台設定的問卷網址。',
          reward: '咖啡券',
          rewardId: 'COFFEE-8X2L',
          surveyUrl: customSurveyUrl,
          status: backend.VeevaContentStatus.published,
          active: true,
        ),
      ],
      news: [],
      rewards: [],
      reviews: [],
    );
  }

  @override
  Future<void> recordActivityCompletion({
    required String memberId,
    required String memberName,
    required String activityId,
    required String activityTitle,
    required String surveyUrl,
  }) async {
    completedMemberId = memberId;
    completedMemberName = memberName;
    completedActivityId = activityId;
    completedActivityTitle = activityTitle;
    completedSurveyUrl = surveyUrl;
  }
}
