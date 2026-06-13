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

    expect(find.text('VeeVa Admin'), findsOneWidget);
    expect(find.text('儀表板'), findsWidgets);
    expect(find.text('問卷完成'), findsOneWidget);
    expect(find.text('待審核'), findsWidgets);
    expect(find.byType(DataTable), findsOneWidget);

    await tester.tap(find.text('會員管理').first);
    await tester.pumpAndSettle();

    expect(find.text('會員管理'), findsWidgets);
    expect(find.text('已登入會員'), findsWidgets);
    expect(find.text('已登入會員名單'), findsWidgets);
    expect(find.text('LINE Token'), findsNothing);
    expect(find.text('院所 / 科別'), findsNothing);
    expect(find.text('會員名稱'), findsOneWidget);
    expect(find.text('第一次登入時間'), findsOneWidget);
    expect(find.text('最後一次登入時間'), findsOneWidget);
    expect(find.text('會員設定'), findsOneWidget);
    expect(find.text('陳怡君'), findsOneWidget);

    await tester.tap(find.text('待審核').last);
    await tester.pumpAndSettle();

    expect(find.text('待審核名單'), findsWidgets);
    expect(find.text('張雅雯'), findsOneWidget);
    expect(find.text('通過'), findsWidgets);

    await tester.tap(find.text('已審核').last);
    await tester.pumpAndSettle();

    expect(find.text('已審核名單'), findsWidgets);
    expect(find.text('王小明'), findsWidgets);
    expect(find.text('後台管理者權限'), findsNothing);
  });

  testWidgets('admin can set role from member list', (tester) async {
    tester.view.physicalSize = const Size(1440, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const VeevaAdminApp(requireLineLogin: false));

    await tester.tap(find.text('權限管理').first);
    await tester.pumpAndSettle();

    expect(find.text('權限管理'), findsWidgets);
    expect(find.text('後台管理者權限'), findsOneWidget);
    expect(find.text('王小明'), findsOneWidget);
    expect(find.text('陳怡君'), findsNothing);

    await tester.tap(find.text('會員管理').first);
    await tester.pumpAndSettle();

    final unassignedRoleDropdown = find
        .ancestor(
          of: find.text('一般會員'),
          matching: find.byWidgetPredicate(
            (widget) => widget is DropdownButtonFormField,
          ),
        )
        .first;
    await tester.tap(unassignedRoleDropdown);
    await tester.pumpAndSettle();
    await tester.tap(find.text('管理員').last);
    await tester.pumpAndSettle();

    await tester.tap(find.text('權限管理').first);
    await tester.pumpAndSettle();

    expect(find.text('後台管理者權限'), findsOneWidget);
    expect(find.text('陳怡君'), findsOneWidget);
    expect(find.text('管理員'), findsWidgets);

    await tester.tap(find.text('會員管理').first);
    await tester.pumpAndSettle();

    final managerDropdown = find
        .ancestor(
          of: find.text('管理員'),
          matching: find.byWidgetPredicate(
            (widget) => widget is DropdownButtonFormField,
          ),
        )
        .first;
    await tester.tap(managerDropdown);
    await tester.pumpAndSettle();
    await tester.tap(find.text('停用帳號').last);
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
          widget.decoration?.hintText == '搜尋姓名、LINE ID、Email、院所、科別',
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

    expect(find.byIcon(Icons.menu), findsOneWidget);
    await tester.tap(find.byIcon(Icons.menu));
    await tester.pumpAndSettle();

    expect(find.text('VeeVa Admin'), findsOneWidget);
    expect(find.byType(DataTable), findsNothing);
    expect(find.text('問卷完成'), findsOneWidget);
    expect(find.text('張雅雯'), findsOneWidget);
    expect(find.text('名單狀態分布'), findsOneWidget);
  });

  testWidgets('admin can manage reward inventory', (tester) async {
    tester.view.physicalSize = const Size(1440, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const VeevaAdminApp(requireLineLogin: false));

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
    expect(find.text('兌換期限類型'), findsOneWidget);
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
    expect(find.byTooltip('小標題'), findsOneWidget);

    await tester.enterText(_newsField('文章標題'), '新品上市資訊');
    await tester.enterText(_newsField('摘要'), '這是一篇給會員閱讀的最新資訊摘要。');
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
    await tester.enterText(_activityField('活動說明'), '完成任務即可取得會員獎勵。');
    await tester.enterText(_activityField('獎勵內容'), '咖啡券 1 張');
    await tester.enterText(_activityField('活動期間'), '2026/06/01 - 2026/06/30');
    await tester.tap(find.text('建立'));
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

    await tester.ensureVisible(find.byTooltip('停用').first);
    await tester.tap(find.byTooltip('停用').first);
    await tester.pumpAndSettle();

    expect(find.byTooltip('啟用'), findsWidgets);
  });
}

Finder _activityField(String label) {
  return find.byWidgetPredicate(
    (widget) => widget is TextField && widget.decoration?.labelText == label,
  );
}

Finder _newsField(String label) {
  return find.byWidgetPredicate(
    (widget) => widget is TextField && widget.decoration?.labelText == label,
  );
}

Finder _rewardField(String label) {
  return find.byWidgetPredicate(
    (widget) => widget is TextField && widget.decoration?.labelText == label,
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
