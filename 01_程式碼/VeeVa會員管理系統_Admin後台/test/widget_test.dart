import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:veeva_admin_app/data/veeva_models.dart' as backend;
import 'package:veeva_admin_app/data/veeva_repository.dart';
import 'package:veeva_admin_app/main.dart';

void main() {
  testWidgets('admin app shows management dashboard', (tester) async {
    tester.view.physicalSize = const Size(1440, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const VeevaAdminApp());

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

    await tester.pumpWidget(const VeevaAdminApp());

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

    await tester
        .pumpWidget(VeevaAdminApp(repository: _LargeMemberRepository()));
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

    await tester.pumpWidget(const VeevaAdminApp());

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

    await tester.pumpWidget(const VeevaAdminApp());

    await tester.tap(find.text('兌換券管理').first);
    await tester.pumpAndSettle();

    expect(find.text('兌換券列表'), findsOneWidget);
    expect(find.text('星巴克中杯美式'), findsOneWidget);
    expect(find.text('上架中'), findsWidgets);
    expect(find.text('120'), findsOneWidget);

    await tester.tap(find.text('補庫存').first);
    await tester.pumpAndSettle();

    expect(find.text('140'), findsOneWidget);
  });

  testWidgets('admin can open activity and news management', (tester) async {
    tester.view.physicalSize = const Size(1440, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const VeevaAdminApp());

    await tester.tap(find.text('活動管理').first);
    await tester.pumpAndSettle();

    expect(find.text('活動管理'), findsWidgets);
    expect(find.text('新增活動'), findsOneWidget);
    expect(find.text('填問卷，拿咖啡券'), findsOneWidget);

    await tester.tap(find.text('最新資訊').first);
    await tester.pumpAndSettle();

    expect(find.text('最新資訊管理'), findsWidgets);
    expect(find.text('新增資訊'), findsOneWidget);
    expect(find.text('WHO 發布醫療產品警示'), findsOneWidget);
  });
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
