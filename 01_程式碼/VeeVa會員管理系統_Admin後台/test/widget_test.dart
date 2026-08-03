import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:veeva_admin_app/data/veeva_models.dart' as backend;
import 'package:veeva_admin_app/data/veeva_repository.dart';
import 'package:veeva_admin_app/main.dart';

void main() {
  testWidgets('admin gate opens dashboard for active LINE admin',
      (tester) async {
    tester.view.physicalSize = const Size(1440, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const VeevaAdminApp());
    await tester.pumpAndSettle();

    expect(find.text('儀表板'), findsWidgets);
    expect(find.text('問卷完成'), findsOneWidget);
  });

  testWidgets('admin gate blocks LINE users without active permission',
      (tester) async {
    tester.view.physicalSize = const Size(440, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(VeevaAdminApp(repository: _NoAdminRepository()));
    await tester.pumpAndSettle();

    expect(find.text('尚未開通後台權限'), findsOneWidget);
    expect(find.text('這個 LINE 帳號尚未啟用後台管理權限。'), findsOneWidget);
    expect(find.text('登出 LINE'), findsOneWidget);
    expect(find.text('問卷完成'), findsNothing);
  });

  testWidgets('admin app shows management dashboard', (tester) async {
    tester.view.physicalSize = const Size(1440, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const VeevaAdminApp(requireLineLogin: false));
    await tester.pumpAndSettle();

    expect(_brandLogo(), findsOneWidget);
    expect(find.text('儀表板'), findsWidgets);
    expect(find.text('問卷完成'), findsOneWidget);
    expect(find.text('待審核'), findsWidgets);
    expect(find.text('最新待審核'), findsOneWidget);
    expect(find.text('目前沒有待審核會員。'), findsOneWidget);

    await tester.tap(find.text('會員管理').first);
    await tester.pumpAndSettle();

    expect(find.text('會員管理'), findsWidgets);
    expect(find.text('已登入會員'), findsWidgets);
    expect(find.text('已登入會員名單'), findsWidgets);
    expect(find.text('LINE Token'), findsNothing);
    expect(find.text('院所 / 科別'), findsNothing);
    expect(find.text('會員名稱'), findsOneWidget);
    expect(find.text('最後一次登入時間'), findsOneWidget);
    expect(find.text('操作'), findsOneWidget);
    expect(find.text('陳怡君'), findsOneWidget);

    await tester.tap(find.text('待審核').last);
    await tester.pumpAndSettle();

    expect(find.text('待審核名單'), findsWidgets);
    expect(find.text('目前沒有待審核會員。'), findsOneWidget);

    await tester.tap(find.text('已審核').last);
    await tester.pumpAndSettle();

    expect(find.text('已審核名單'), findsWidgets);
    expect(find.text('目前沒有已審核待發放會員。'), findsOneWidget);
    expect(find.text('後台管理者權限'), findsNothing);
  });

  testWidgets('admin can set role from member list', (tester) async {
    tester.view.physicalSize = const Size(1440, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const VeevaAdminApp(requireLineLogin: false));
    await tester.pumpAndSettle();

    await tester.tap(find.text('權限管理').first);
    await tester.pumpAndSettle();

    expect(find.text('權限管理'), findsWidgets);
    expect(find.text('後台管理者權限'), findsOneWidget);
    expect(find.text('王小明'), findsOneWidget);
    expect(find.text('陳怡君'), findsNothing);

    await tester.tap(find.text('會員管理').first);
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('編輯會員設定').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('管理員').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('儲存設定').last);
    await tester.pumpAndSettle();

    await tester.tap(find.text('權限管理').first);
    await tester.pumpAndSettle();

    expect(find.text('後台管理者權限'), findsOneWidget);
    expect(find.text('陳怡君'), findsOneWidget);
    expect(find.text('管理員'), findsWidgets);

    await tester.tap(find.text('會員管理').first);
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('編輯會員設定').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('停用帳號').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('儲存設定').last);
    await tester.pumpAndSettle();

    await tester.tap(find.text('權限管理').first);
    await tester.pumpAndSettle();

    expect(find.text('後台管理者權限'), findsOneWidget);
    expect(find.text('陳怡君'), findsNothing);
  });

  testWidgets('member management supports search and pagination',
      (tester) async {
    tester.view.physicalSize = const Size(1440, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(VeevaAdminApp(
      repository: _LargeMemberRepository(),
      requireLineLogin: false,
    ));
    await tester.pumpAndSettle();

    await tester.tap(find.text('會員管理').first);
    await tester.pumpAndSettle();

    expect(find.text('第 1 / 2 頁'), findsOneWidget);
    expect(find.text('測試會員 01'), findsOneWidget);
    expect(find.text('測試會員 09'), findsNothing);

    await tester.ensureVisible(find.byTooltip('下一頁'));
    await tester.tap(find.byTooltip('下一頁'));
    await tester.pumpAndSettle();

    expect(find.text('第 2 / 2 頁'), findsOneWidget);
    expect(find.text('測試會員 09'), findsOneWidget);

    final searchField = find.byWidgetPredicate(
      (widget) =>
          widget is TextField &&
          widget.decoration?.hintText == '搜尋姓名、電話、LINE ID、Email',
    );
    await tester.ensureVisible(searchField);
    await tester.enterText(searchField, 'member13@example.com');
    await tester.pumpAndSettle();

    expect(find.text('符合 1 / 13 筆'), findsOneWidget);
    expect(find.text('第 1 / 1 頁'), findsOneWidget);
    expect(find.text('測試會員 13'), findsOneWidget);
    expect(find.text('測試會員 09'), findsNothing);
  });

  testWidgets('admin app adapts to mobile layout', (tester) async {
    tester.view.physicalSize = const Size(390, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const VeevaAdminApp(requireLineLogin: false));
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.menu), findsOneWidget);
    await tester.tap(find.byIcon(Icons.menu));
    await tester.pumpAndSettle();

    expect(_brandLogo(), findsOneWidget);
    expect(find.byType(DataTable), findsNothing);
    expect(find.text('問卷完成'), findsOneWidget);
    expect(find.text('目前沒有待審核會員。'), findsOneWidget);
    expect(find.text('名單狀態分布'), findsOneWidget);
  });

  testWidgets('admin can manage reward inventory', (tester) async {
    tester.view.physicalSize = const Size(1440, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const VeevaAdminApp(requireLineLogin: false));
    await tester.pumpAndSettle();

    await tester.tap(find.text('兌換券管理').first);
    await tester.pumpAndSettle();

    expect(find.text('兌換券列表'), findsOneWidget);
    expect(find.text('星巴克中杯美式'), findsOneWidget);
    expect(find.text('上架中'), findsWidgets);
    expect(find.text('120'), findsOneWidget);

    await tester.tap(find.text('新增兌換券'));
    await tester.pumpAndSettle();
    expect(find.text('新增兌換券'), findsWidgets);
    expect(_rewardField('已發放'), findsNothing);
    expect(_rewardField('已兌換'), findsNothing);
    final rewardDialog = find.ancestor(
      of: find.text('新增兌換券').last,
      matching: find.byType(Dialog),
    );
    final rewardDialogScroll = find.descendant(
      of: rewardDialog,
      matching: find.byType(SingleChildScrollView),
    );
    await tester.drag(rewardDialogScroll, const Offset(0, -700));
    await tester.pumpAndSettle();
    expect(
      find.textContaining('兌換期限類型', findRichText: true),
      findsOneWidget,
    );
    expect(find.text('不限時'), findsOneWidget);
    expect(_rewardField('兌換日期'), findsNothing);
    await tester.tap(find.text('取消').last);
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.byTooltip('調整庫存').first);
    await tester.tap(find.byTooltip('調整庫存').first);
    await tester.pumpAndSettle();

    await tester.enterText(_rewardField('調整數量'), '15');
    await tester.tap(find.text('套用'));
    await tester.pumpAndSettle();

    expect(find.text('135'), findsOneWidget);

    await tester.tap(find.byTooltip('編輯').first);
    await tester.pumpAndSettle();
    await tester.enterText(_rewardField('商品名稱'), '星巴克大杯拿鐵');
    await tester.tap(find.text('儲存'));
    await tester.pumpAndSettle();

    expect(find.text('星巴克大杯拿鐵'), findsOneWidget);

    await tester.tap(find.byTooltip('預覽').first);
    await tester.pumpAndSettle();
    expect(find.text('兌換券預覽'), findsOneWidget);
    await tester.tap(find.text('關閉'));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('停用').first);
    await tester.pumpAndSettle();

    expect(find.text('已停用'), findsWidgets);

    await tester.tap(find.byTooltip('刪除').first);
    await tester.pumpAndSettle();
    expect(find.text('刪除兌換券'), findsOneWidget);

    await tester.tap(find.text('刪除').last);
    await tester.pumpAndSettle();

    expect(find.text('星巴克大杯拿鐵'), findsNothing);
  });

  testWidgets('admin can open activity and news management', (tester) async {
    tester.view.physicalSize = const Size(1440, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const VeevaAdminApp(requireLineLogin: false));
    await tester.pumpAndSettle();

    await tester.tap(find.text('活動管理').first);
    await tester.pumpAndSettle();

    expect(find.text('活動管理'), findsWidgets);
    expect(find.text('新增活動'), findsOneWidget);
    expect(find.text('填問卷，拿咖啡券'), findsOneWidget);
    expect(find.text('只看進行中'), findsNothing);

    await tester.tap(find.text('最新資訊').first);
    await tester.pumpAndSettle();

    expect(find.text('最新資訊管理'), findsWidgets);
    expect(find.text('新增文章'), findsOneWidget);
    expect(find.text('WHO 發布醫療產品警示'), findsOneWidget);
  });

  testWidgets('admin can create edit preview and update news articles',
      (tester) async {
    tester.view.physicalSize = const Size(1440, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final repository = _SingleNewsRepository();
    await tester.pumpWidget(VeevaAdminApp(
      repository: repository,
      requireLineLogin: false,
    ));
    await tester.pumpAndSettle();

    await tester.tap(find.text('最新資訊').first);
    await tester.pumpAndSettle();

    expect(find.text('原始文章'), findsOneWidget);
    expect(find.text('已發布'), findsWidgets);

    await tester.tap(find.text('新增文章'));
    await tester.pumpAndSettle();

    expect(find.text('文章編輯器'), findsOneWidget);
    expect(find.byTooltip('粗體'), findsOneWidget);
    expect(find.byTooltip('字體大小'), findsOneWidget);

    await tester.enterText(_newsField('文章標題'), '新品上市資訊');
    await tester.enterText(_newsField('列表摘要'), '這是一篇給會員閱讀的最新資訊摘要。');
    await tester.enterText(
        _newsField('文章內容'), '完整文章內容可以在後台編輯，並會儲存在 Firestore。');
    await tester.enterText(_newsField('來源'), 'Veeva');
    await tester.enterText(_newsField('分類'), '產品資訊');
    await tester.tap(find.text('建立'));
    await tester.pumpAndSettle();

    expect(find.text('新品上市資訊'), findsOneWidget);
    expect(repository.savedNews?.title, '新品上市資訊');
    expect(repository.savedNews?.content, contains('完整文章內容'));

    await tester.ensureVisible(find.byTooltip('編輯').first);
    await tester.tap(find.byTooltip('編輯').first);
    await tester.pumpAndSettle();
    await tester.enterText(_newsField('文章標題'), '更新後文章');
    await tester.tap(find.text('儲存'));
    await tester.pumpAndSettle();

    expect(find.text('更新後文章'), findsOneWidget);
    expect(repository.savedNews?.title, '更新後文章');

    await tester.ensureVisible(find.byTooltip('預覽').first);
    await tester.tap(find.byTooltip('預覽').first);
    await tester.pumpAndSettle();
    expect(find.text('文章預覽'), findsOneWidget);
    expect(find.text('更新後文章'), findsWidgets);
    await tester.tap(find.text('關閉'));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('切換狀態').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('草稿').last);
    await tester.pumpAndSettle();

    expect(repository.savedNews?.status, backend.VeevaContentStatus.draft);
    expect(find.text('草稿'), findsWidgets);
  });

  testWidgets('admin can create edit preview and toggle activities',
      (tester) async {
    tester.view.physicalSize = const Size(1440, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(VeevaAdminApp(
      repository: _SingleActivityRepository(),
      requireLineLogin: false,
    ));
    await tester.pumpAndSettle();

    await tester.tap(find.text('活動管理').first);
    await tester.pumpAndSettle();

    expect(find.text('原始活動'), findsOneWidget);
    expect(find.text('封存活動'), findsNothing);
    expect(find.text('活動列表'), findsOneWidget);
    expect(find.text('已封存'), findsOneWidget);
    expect(find.text('進行中'), findsWidgets);

    await tester.tap(find.text('已封存'));
    await tester.pumpAndSettle();
    expect(find.text('封存活動'), findsOneWidget);
    expect(find.text('原始活動'), findsNothing);
    expect(find.text('新增活動'), findsNothing);

    await tester.tap(find.text('活動列表'));
    await tester.pumpAndSettle();
    expect(find.text('原始活動'), findsOneWidget);
    expect(find.text('封存活動'), findsNothing);

    await tester.tap(find.text('新增活動'));
    await tester.pumpAndSettle();

    expect(_activityField('問卷網址'), findsOneWidget);

    await tester.enterText(_activityField('活動名稱'), '端午會員任務');
    await tester.enterText(_activityField('活動概述'), '完成任務即可取得會員獎勵。');
    await tester.enterText(_activityField('獎勵內容'), '咖啡券 1 張');
    await tester.enterText(_activityField('活動日期'), '2026/06/01 - 2026/06/30');
    await tester.tap(find.text('儲存草稿'));
    await tester.pumpAndSettle();

    expect(find.text('端午會員任務'), findsOneWidget);
    expect(find.text('2026/06/01 - 2026/06/30'), findsOneWidget);

    await tester.ensureVisible(find.byTooltip('編輯').first);
    await tester.tap(find.byTooltip('編輯').first);
    await tester.pumpAndSettle();
    await tester.enterText(_activityField('活動名稱'), '更新後活動');
    await tester.tap(find.text('儲存'));
    await tester.pumpAndSettle();

    expect(find.text('更新後活動'), findsOneWidget);

    await tester.ensureVisible(find.byTooltip('預覽').first);
    await tester.tap(find.byTooltip('預覽').first);
    await tester.pumpAndSettle();
    expect(find.text('活動預覽'), findsOneWidget);
    await tester.tap(find.text('關閉'));
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.byTooltip('啟用').first);
    await tester.tap(find.byTooltip('啟用').first);
    await tester.pumpAndSettle();

    expect(find.byTooltip('停用'), findsWidgets);
  });

  testWidgets('LINE navigation sends a text message to a selected member',
      (tester) async {
    tester.view.physicalSize = const Size(1440, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final repository = _MessageCaptureRepository();

    await tester.pumpWidget(VeevaAdminApp(
      repository: repository,
      requireLineLogin: false,
    ));
    await tester.pumpAndSettle();

    await tester.tap(find.text('LINE@'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('發送訊息'));
    await tester.pumpAndSettle();

    expect(find.text('全部會員'), findsOneWidget);
    expect(find.text('王小明'), findsWidgets);
    expect(find.text('陳怡君'), findsOneWidget);
    expect(find.text('您好，我想詢問兌換券。'), findsOneWidget);

    await tester.enterText(
      find.byKey(const ValueKey('line-message-field')),
      '您好，這是一則 LINE 測試訊息。',
    );
    await tester.pump();
    expect(find.text('預覽'), findsNothing);
    await tester.testTextInput.receiveAction(TextInputAction.send);
    await tester.pumpAndSettle();

    expect(repository.sentMember?.name, '王小明');
    expect(repository.sentMessageType, 'text');
    expect(repository.sentSnapshot?['text'], '您好，這是一則 LINE 測試訊息。');
    expect(find.text('發送成功'), findsOneWidget);
  });

  testWidgets('LINE chat stays blank when the selected member has no messages',
      (tester) async {
    tester.view.physicalSize = const Size(1440, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const VeevaAdminApp(
      requireLineLogin: false,
    ));
    await tester.pumpAndSettle();

    await tester.tap(find.text('LINE@'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('發送訊息'));
    await tester.pumpAndSettle();

    expect(find.text('尚無對話紀錄，可從下方開始傳送訊息'), findsNothing);
    expect(find.text('對話紀錄載入失敗，請稍後再試'), findsNothing);
  });

  testWidgets('LINE chat renders sent rich and carousel message previews',
      (tester) async {
    tester.view.physicalSize = const Size(1440, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(VeevaAdminApp(
      repository: _TemplatePreviewRepository(),
      requireLineLogin: false,
    ));
    await tester.pumpAndSettle();

    await tester.tap(find.text('LINE@'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('發送訊息'));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('line-rich-message-preview')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('line-carousel-message-preview')),
      findsOneWidget,
    );
    expect(find.text('第一頁內容'), findsOneWidget);
  });

  testWidgets('LINE chat prioritizes unread members by newest message time',
      (tester) async {
    tester.view.physicalSize = const Size(1440, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final repository = _UnreadMessageRepository();

    await tester.pumpWidget(VeevaAdminApp(
      repository: repository,
      requireLineLogin: false,
    ));
    await tester.pumpAndSettle();

    await tester.tap(find.text('LINE@'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('發送訊息'));
    await tester.pumpAndSettle();

    final chenTile = find.byKey(const ValueKey('line-member-line-demo-chen'));
    final wangTile = find.byKey(const ValueKey('line-member-line-demo-wang'));
    expect(tester.getTopLeft(chenTile).dy,
        lessThan(tester.getTopLeft(wangTile).dy));
    expect(
      find.byKey(const ValueKey('line-unread-line-demo-chen')),
      findsOneWidget,
    );
    final unreadBadge = tester.widget<Container>(
      find.byKey(const ValueKey('line-unread-line-demo-chen')),
    );
    expect(unreadBadge.constraints?.minWidth, 28);
    expect(unreadBadge.constraints?.minHeight, 28);
    expect(
      (unreadBadge.decoration as BoxDecoration).shape,
      BoxShape.circle,
    );
    expect(find.text('1'), findsWidgets);

    await tester.tap(chenTile);
    await tester.pumpAndSettle();
    expect(
      find.descendant(of: chenTile, matching: find.byIcon(Icons.check_circle)),
      findsNothing,
    );
    expect(repository.markedReadLineUserId, 'line-demo-chen');
  });

  testWidgets('LINE chat sends saved single-page and multi-page templates',
      (tester) async {
    tester.view.physicalSize = const Size(1440, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final repository = _MessageCaptureRepository();

    await tester.pumpWidget(VeevaAdminApp(
      repository: repository,
      requireLineLogin: false,
    ));
    await tester.pumpAndSettle();

    await tester.tap(find.text('LINE@'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('發送訊息'));
    await tester.pumpAndSettle();

    await tester.tap(
      find.byKey(const ValueKey('line-template-message-button')),
    );
    await tester.pumpAndSettle();
    expect(find.text('單頁圖文'), findsOneWidget);
    expect(find.text('多頁圖文'), findsOneWidget);
    await tester.tap(find.text('測試單頁模板'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('line-template-send-button')));
    await tester.pumpAndSettle();

    expect(repository.sentMessageType, 'rich');
    expect(repository.sentSnapshot?['id'], 'rich-test');
    expect(find.text('發送成功'), findsOneWidget);
    await tester.tap(find.text('完成'));
    await tester.pumpAndSettle();

    await tester.tap(
      find.byKey(const ValueKey('line-template-message-button')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('多頁圖文'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('測試多頁模板'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('line-template-send-button')));
    await tester.pumpAndSettle();

    expect(repository.sentMessageType, 'carousel');
    expect(repository.sentSnapshot?['id'], 'carousel-test');
  });
}

Finder _activityField(String label) {
  const hints = {
    '問卷網址': 'https://',
    '活動名稱': '請輸入活動名稱',
    '活動概述': '請輸入活動列表與上方摘要使用的活動概述...',
    '獎勵內容': '例如：星巴克美式冰咖啡',
    '活動日期': '例如：2026/06/15 - 2026/07/15',
  };
  return find.byWidgetPredicate(
    (widget) =>
        widget is TextField &&
        (widget.decoration?.labelText == label ||
            widget.decoration?.hintText == hints[label]),
  );
}

Finder _newsField(String label) {
  return find.byWidgetPredicate(
    (widget) => widget is TextField && widget.decoration?.labelText == label,
  );
}

Finder _rewardField(String label) {
  const hints = {
    '商品名稱': '請輸入商品名稱',
  };
  return find.byWidgetPredicate(
    (widget) =>
        widget is TextField &&
        (widget.decoration?.labelText == label ||
            widget.decoration?.hintText == hints[label]),
  );
}

Finder _brandLogo() {
  return find.byWidgetPredicate(
    (widget) =>
        widget is Image &&
        widget.image is AssetImage &&
        (widget.image as AssetImage).assetName == 'assets/brand/veeva-logo.png',
  );
}

class _LargeMemberRepository extends DemoVeevaRepository {
  @override
  Future<backend.VeevaBootstrap> loadBootstrap() async {
    return backend.VeevaBootstrap(
      activities: const [],
      news: const [],
      rewards: const [],
      reviews: const [],
      members: [
        for (var index = 1; index <= 13; index++)
          backend.VeevaMember(
            id: 'line-test-${index.toString().padLeft(2, '0')}',
            name: '測試會員 ${index.toString().padLeft(2, '0')}',
            hospital: '測試醫院',
            department: '測試科別',
            status: backend.VeevaMemberStatus.loggedIn,
            earnedCoupons: 0,
            invitedCount: 0,
            shareCode: 'T${index.toString().padLeft(4, '0')}',
            lineUserId: 'line-test-${index.toString().padLeft(2, '0')}',
            email: 'member$index@example.com',
            lineIdToken: 'token-$index',
            createdAt: DateTime(2026, 5, index, 9),
            lastLineLoginAt: DateTime(2026, 6, 4, 10, 59 - index),
          ),
      ],
      adminUsers: const [],
      activityRecords: const [],
      memberRewards: const [],
      employeeLinks: const [],
      clientSettings: const backend.VeevaClientSettings(),
    );
  }
}

class _SingleActivityRepository extends DemoVeevaRepository {
  @override
  Future<backend.VeevaBootstrap> loadBootstrap() async {
    return backend.VeevaBootstrap(
      activities: const [
        backend.VeevaActivity(
          id: 'single-activity',
          type: backend.VeevaActivityType.survey,
          label: '任務',
          title: '原始活動',
          description: '完成指定任務。',
          reward: '咖啡券',
          rewardId: 'COFFEE-8X2L',
          status: backend.VeevaContentStatus.published,
          active: true,
          periodText: '2026/06/01 - 2026/06/10',
          note: '測試活動',
        ),
        backend.VeevaActivity(
          id: 'archived-activity',
          type: backend.VeevaActivityType.registration,
          label: '歷史活動',
          title: '封存活動',
          description: '已結束並封存的活動。',
          reward: '歷史紀錄',
          status: backend.VeevaContentStatus.archived,
          active: false,
          periodText: '2026/01/01 - 2026/01/31',
          note: '封存測試',
        ),
      ],
      news: const [],
      rewards: [
        backend.VeevaReward(
          id: 'COFFEE-8X2L',
          name: '中杯美式咖啡 1 杯',
          category: '飲品',
          stock: 20,
          issued: 0,
          redeemed: 0,
          expiresAt: DateTime(2026, 8, 31),
          status: backend.VeevaRewardStatus.active,
        ),
      ],
      reviews: const [],
      members: const [],
      adminUsers: const [],
      activityRecords: const [],
      memberRewards: const [],
      employeeLinks: const [],
      clientSettings: const backend.VeevaClientSettings(),
    );
  }
}

class _SingleNewsRepository extends DemoVeevaRepository {
  backend.VeevaNews? savedNews;

  @override
  Future<backend.VeevaBootstrap> loadBootstrap() async {
    return const backend.VeevaBootstrap(
      activities: [],
      news: [
        backend.VeevaNews(
          id: 'single-news',
          date: '2026/06/01',
          source: 'Veeva',
          title: '原始文章',
          summary: '原始文章摘要。',
          status: backend.VeevaContentStatus.published,
          category: '公告',
          content: '原始文章內容。',
        ),
      ],
      rewards: [],
      reviews: [],
      members: [],
      adminUsers: [],
      activityRecords: [],
      memberRewards: [],
      employeeLinks: [],
      clientSettings: backend.VeevaClientSettings(),
    );
  }

  @override
  Future<void> saveNews(backend.VeevaNews news) async {
    savedNews = news;
  }
}

class _NoAdminRepository extends DemoVeevaRepository {
  @override
  Future<backend.VeevaAdminUser?> loadActiveAdminUserByLineUserId(
    String lineUserId,
  ) async {
    return null;
  }
}

class _MessageCaptureRepository extends DemoVeevaRepository {
  backend.VeevaMember? sentMember;
  String? sentMessageType;
  Map<String, Object?>? sentSnapshot;

  @override
  Future<backend.VeevaBootstrap> loadBootstrap() async {
    return const backend.VeevaBootstrap(
      activities: [],
      news: [],
      rewards: [],
      reviews: [],
      members: [],
      adminUsers: [],
      activityRecords: [],
      memberRewards: [],
      employeeLinks: [],
      clientSettings: backend.VeevaClientSettings(
        lineRichMessages: [
          backend.VeevaLineRichMessage(
            id: 'rich-test',
            title: '測試單頁模板',
            imageUrl: 'https://example.com/rich.jpg',
            targetUrl: 'https://example.com/rich',
            altText: '測試單頁圖文訊息',
          ),
        ],
        lineCarouselMessages: [
          backend.VeevaLineCarouselMessage(
            id: 'carousel-test',
            title: '測試多頁模板',
            templateId: 'standard',
            altText: '測試多頁圖文訊息',
            cards: [
              backend.VeevaLineCarouselCard(
                title: '第一頁',
                description: '第一頁內容',
                imageUrl: 'https://example.com/carousel.jpg',
                actionLabel: '立即查看',
                actionUrl: 'https://example.com/carousel',
              ),
            ],
          ),
        ],
      ),
    );
  }

  @override
  Future<void> sendLineMessageTest({
    required backend.VeevaMember member,
    required String messageType,
    required Map<String, Object?> messageSnapshot,
  }) async {
    sentMember = member;
    sentMessageType = messageType;
    sentSnapshot = messageSnapshot;
  }

  @override
  Stream<List<backend.VeevaLineChatMessage>> watchLineConversation(
    String lineUserId,
  ) {
    return Stream.value([
      backend.VeevaLineChatMessage(
        id: 'incoming-test-1',
        lineUserId: lineUserId,
        direction: backend.VeevaLineChatDirection.incoming,
        type: 'text',
        text: '您好，我想詢問兌換券。',
        sentAt: DateTime(2026, 7, 30, 10, 30),
        memberId: 'line-demo-wang',
        memberName: '王小明',
      ),
    ]);
  }
}

class _TemplatePreviewRepository extends _MessageCaptureRepository {
  @override
  Stream<List<backend.VeevaLineChatMessage>> watchLineConversation(
    String lineUserId,
  ) {
    return Stream.value([
      backend.VeevaLineChatMessage(
        id: 'outgoing-rich-test',
        lineUserId: lineUserId,
        direction: backend.VeevaLineChatDirection.outgoing,
        type: 'rich',
        text: '[單頁圖文] 測試單頁模板',
        sentAt: DateTime(2026, 7, 30, 10, 31),
      ),
      backend.VeevaLineChatMessage(
        id: 'outgoing-carousel-test',
        lineUserId: lineUserId,
        direction: backend.VeevaLineChatDirection.outgoing,
        type: 'carousel',
        text: '[多頁圖文] 測試多頁模板',
        sentAt: DateTime(2026, 7, 30, 10, 32),
        messageSnapshot: const backend.VeevaLineCarouselMessage(
          id: 'carousel-test',
          title: '測試多頁模板',
          templateId: 'standard',
          altText: '測試多頁圖文訊息',
          cards: [
            backend.VeevaLineCarouselCard(
              title: '第一頁',
              description: '第一頁內容',
              imageUrl: 'https://example.com/carousel.jpg',
              actionLabel: '立即查看',
              actionUrl: 'https://example.com/carousel',
            ),
          ],
        ).toMap(),
      ),
    ]);
  }
}

class _UnreadMessageRepository extends DemoVeevaRepository {
  String? markedReadLineUserId;

  @override
  Stream<List<backend.VeevaLineConversationSummary>>
      watchLineConversationSummaries() {
    return Stream.value([
      backend.VeevaLineConversationSummary(
        lineUserId: 'line-demo-wang',
        unreadCount: 4,
        lastMessage: '較早的未讀訊息',
        lastMessageAt: DateTime(2026, 8, 3, 10),
      ),
      backend.VeevaLineConversationSummary(
        lineUserId: 'line-demo-chen',
        unreadCount: 1,
        lastMessage: '最新的未讀訊息',
        lastMessageAt: DateTime(2026, 8, 3, 11),
      ),
    ]);
  }

  @override
  Future<void> markLineConversationRead(String lineUserId) async {
    markedReadLineUserId = lineUserId;
  }
}
