import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:veeva_member_app/data/veeva_models.dart' as backend;
import 'package:veeva_member_app/data/veeva_repository.dart';
import 'package:veeva_member_app/main.dart';

void main() {
  testWidgets('user can complete the reward flow', (tester) async {
    await tester.pumpWidget(const VeevaMemberApp());

    expect(find.text('填問卷，拿咖啡券'), findsOneWidget);

    await tester.ensureVisible(find.byKey(const Key('start-login-button')));
    await tester.tap(find.byKey(const Key('start-login-button')));
    await tester.pumpAndSettle();
    expect(find.text('會員登入'), findsOneWidget);
    expect(find.text('使用 LINE 登入'), findsOneWidget);
    expect(find.text('使用 Google 登入'), findsOneWidget);
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
    expect(find.text('可使用兌換券'), findsNothing);

    await tester.tap(find.text('兌換券'));
    await tester.pumpAndSettle();
    expect(find.text('兌換券'), findsWidgets);
    expect(find.text('中杯美式咖啡 1 杯'), findsOneWidget);
    expect(find.text('兌換期限 2026/08/31'), findsOneWidget);
    expect(find.text('無糖綠茶 1 瓶'), findsOneWidget);
    expect(find.text('醫學書展 100 元折抵券'), findsOneWidget);
    expect(find.text('醫療口罩 1 盒'), findsOneWidget);
    expect(find.text('健康便當折價券'), findsOneWidget);
    expect(find.text('會員點數 300 點'), findsOneWidget);

    await tester.tap(find.byKey(const Key('redeem-coupon-button')));
    await tester.pumpAndSettle();
    expect(find.text('確認兌換'), findsWidgets);
    expect(find.text('是否要兌換「中杯美式咖啡 1 杯」？'), findsOneWidget);
  });

  testWidgets('customer navigation and system messages are available', (
    tester,
  ) async {
    await tester.pumpWidget(const VeevaMemberApp());

    expect(find.byType(NavigationBar), findsOneWidget);
    expect(find.byType(NavigationDestination), findsNWidgets(4));
    expect(find.text('兌換券'), findsOneWidget);
    final destinations = tester.widgetList<NavigationDestination>(
      find.byType(NavigationDestination),
    );
    expect(
      destinations.map((item) => item.label),
      ['活動', '最新資訊', '兌換券', '會員'],
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
    expect(find.byKey(const Key('member-google-login-button')), findsOneWidget);
    expect(find.text('會員功能'), findsNothing);

    await tester.tap(find.byKey(const Key('member-line-login-button')));
    await tester.pumpAndSettle();

    expect(find.text('會員功能'), findsOneWidget);
    expect(find.text('編輯會員資料'), findsOneWidget);
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

  testWidgets('landing page shows activity news cards', (tester) async {
    await tester.pumpWidget(const VeevaMemberApp());

    expect(find.text('活動消息'), findsOneWidget);
    expect(find.text('填問卷，拿咖啡券'), findsOneWidget);
    expect(find.text('研討會報名提醒'), findsOneWidget);
    expect(find.text('院所限定任務'), findsOneWidget);
    expect(find.text('LINE 登入'), findsNothing);
    expect(find.text('資格審核'), findsNothing);
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

class _RecordingVeevaRepository extends DemoVeevaRepository {
  int upsertCount = 0;
  String? lineUserId;
  String? displayName;
  String? lineIdToken;

  @override
  Future<backend.VeevaMember> upsertLineMember({
    required String lineUserId,
    required String displayName,
    String? avatarUrl,
    String? email,
    String? statusMessage,
    String? lineIdToken,
  }) {
    upsertCount += 1;
    this.lineUserId = lineUserId;
    this.displayName = displayName;
    this.lineIdToken = lineIdToken;
    return super.upsertLineMember(
      lineUserId: lineUserId,
      displayName: displayName,
      avatarUrl: avatarUrl,
      email: email,
      statusMessage: statusMessage,
      lineIdToken: lineIdToken,
    );
  }
}
