import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
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
    expect(find.text('LINE Token'), findsOneWidget);
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
    expect(find.text('LINE 會員後台權限'), findsNothing);
  });

  testWidgets('admin can grant permissions from member list', (tester) async {
    tester.view.physicalSize = const Size(430, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const VeevaAdminApp());

    await tester.tap(find.byIcon(Icons.menu));
    await tester.pumpAndSettle();
    await tester.tap(find.text('權限管理').first);
    await tester.pumpAndSettle();

    expect(find.text('權限管理'), findsWidgets);
    expect(find.text('LINE 會員後台權限'), findsOneWidget);
    expect(find.text('陳怡君'), findsOneWidget);

    await tester.ensureVisible(find.text('授權管理者').first);
    await tester.tap(find.text('授權管理者').first);
    await tester.pumpAndSettle();

    expect(find.text('授權管理者'), findsWidgets);
    expect(find.text('功能權限'), findsOneWidget);
    expect(find.text('會員管理'), findsWidgets);

    await tester.tap(find.text('儲存權限'));
    await tester.pumpAndSettle();

    expect(find.text('管理員'), findsWidgets);
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
