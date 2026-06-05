import 'package:flutter/material.dart';

import 'data/firebase_bootstrap.dart';
import 'data/veeva_models.dart' as backend;
import 'data/veeva_repository.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final repository = await createVeevaRepository();
  runApp(VeevaAdminApp(repository: repository));
}

class VeevaAdminApp extends StatelessWidget {
  const VeevaAdminApp({this.repository, super.key});

  final VeevaRepository? repository;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'VeeVa Admin',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        fontFamilyFallback: const [
          'STHeiti',
          'PingFang TC',
          'Microsoft JhengHei',
          'Noto Sans CJK TC',
          'sans-serif',
        ],
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF216B57),
          primary: const Color(0xFF216B57),
          surface: const Color(0xFFF5F7F8),
        ),
        scaffoldBackgroundColor: const Color(0xFFF5F7F8),
        cardTheme: CardTheme(
          color: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
            side: const BorderSide(color: Color(0xFFE4E8EA)),
          ),
        ),
      ),
      home: AdminDashboardShell(
        initialTab: _initialAdminTabFromUri(),
        repository: repository,
      ),
    );
  }

  AdminTab _initialAdminTabFromUri() {
    return switch (Uri.base.queryParameters['adminTab']) {
      'members' || 'pending' || 'approved' => AdminTab.members,
      'activities' => AdminTab.activities,
      'news' => AdminTab.news,
      'rewards' => AdminTab.rewards,
      'permissions' => AdminTab.permissions,
      'settings' => AdminTab.settings,
      _ => AdminTab.dashboard,
    };
  }
}

enum AdminTab {
  dashboard,
  members,
  activities,
  news,
  rewards,
  permissions,
  settings,
}

enum ReviewStatus { pending, approved, rejected }

enum RewardStatus { active, paused, expired }

enum MemberManagementTab { loggedIn, pendingReview, approvedReview }

class AdminReviewItem {
  AdminReviewItem({
    required this.id,
    required this.memberId,
    required this.name,
    required this.hospital,
    required this.department,
    required this.completedAt,
    required this.status,
  });

  factory AdminReviewItem.fromBackend(backend.VeevaReview review) {
    return AdminReviewItem(
      id: review.id,
      memberId: review.memberId,
      name: review.name,
      hospital: review.hospital,
      department: review.department,
      completedAt: _formatAdminDateTime(review.completedAt),
      status: switch (review.status) {
        backend.VeevaReviewStatus.pending => ReviewStatus.pending,
        backend.VeevaReviewStatus.approved => ReviewStatus.approved,
        backend.VeevaReviewStatus.rejected => ReviewStatus.rejected,
      },
    );
  }

  final String id;
  final String memberId;
  final String name;
  final String hospital;
  final String department;
  final String completedAt;
  ReviewStatus status;

  backend.VeevaReview toBackend() {
    return backend.VeevaReview(
      id: id,
      memberId: memberId,
      name: name,
      hospital: hospital,
      department: department,
      status: switch (status) {
        ReviewStatus.pending => backend.VeevaReviewStatus.pending,
        ReviewStatus.approved => backend.VeevaReviewStatus.approved,
        ReviewStatus.rejected => backend.VeevaReviewStatus.rejected,
      },
      completedAt: DateTime.now(),
    );
  }
}

class AdminRewardItem {
  AdminRewardItem({
    required this.id,
    required this.name,
    required this.category,
    required this.stock,
    required this.issued,
    required this.redeemed,
    required this.expiresAt,
    required this.status,
  });

  factory AdminRewardItem.fromBackend(backend.VeevaReward reward) {
    return AdminRewardItem(
      id: reward.id,
      name: reward.name,
      category: reward.category,
      stock: reward.stock,
      issued: reward.issued,
      redeemed: reward.redeemed,
      expiresAt: _formatAdminDate(reward.expiresAt),
      status: switch (reward.status) {
        backend.VeevaRewardStatus.active => RewardStatus.active,
        backend.VeevaRewardStatus.paused => RewardStatus.paused,
        backend.VeevaRewardStatus.expired => RewardStatus.expired,
      },
    );
  }

  final String id;
  final String name;
  final String category;
  int stock;
  int issued;
  int redeemed;
  final String expiresAt;
  RewardStatus status;

  backend.VeevaReward toBackend() {
    return backend.VeevaReward(
      id: id,
      name: name,
      category: category,
      stock: stock,
      issued: issued,
      redeemed: redeemed,
      expiresAt: _parseAdminDate(expiresAt),
      status: switch (status) {
        RewardStatus.active => backend.VeevaRewardStatus.active,
        RewardStatus.paused => backend.VeevaRewardStatus.paused,
        RewardStatus.expired => backend.VeevaRewardStatus.expired,
      },
    );
  }
}

String _formatAdminDate(DateTime date) {
  return '${date.year}/${date.month.toString().padLeft(2, '0')}/${date.day.toString().padLeft(2, '0')}';
}

String _formatAdminDateTime(DateTime date) {
  final hour = date.hour.toString().padLeft(2, '0');
  final minute = date.minute.toString().padLeft(2, '0');
  return '${_formatAdminDate(date)} $hour:$minute';
}

String _memberDateTimeLabel(DateTime? date) {
  return date == null ? '-' : _formatAdminDateTime(date);
}

DateTime? _memberFirstLoginAt(backend.VeevaMember member) {
  return member.createdAt ?? member.lastLineLoginAt;
}

DateTime _parseAdminDate(String value) {
  final normalized = value.replaceAll('/', '-');
  return DateTime.tryParse(normalized) ?? DateTime(2026, 12, 31);
}

class AdminDashboardShell extends StatefulWidget {
  const AdminDashboardShell({
    super.key,
    this.initialTab = AdminTab.dashboard,
    this.repository,
  });

  final AdminTab initialTab;
  final VeevaRepository? repository;

  @override
  State<AdminDashboardShell> createState() => _AdminDashboardShellState();
}

class _AdminDashboardShellState extends State<AdminDashboardShell> {
  late AdminTab tab = widget.initialTab;
  late final VeevaRepository repository =
      widget.repository ?? DemoVeevaRepository();
  bool isLoading = true;
  String? backendError;
  List<backend.VeevaActivity> activities = defaultActivities;
  List<backend.VeevaNews> news = defaultNews;
  final reviews = <AdminReviewItem>[
    AdminReviewItem(
      id: 'demo-review-1',
      memberId: 'demo-review-1',
      name: '張雅雯',
      hospital: '北醫附醫',
      department: '胸腔內科',
      completedAt: '2026/05/08 09:12',
      status: ReviewStatus.pending,
    ),
    AdminReviewItem(
      id: 'demo-review-2',
      memberId: 'demo-review-2',
      name: '吳志誠',
      hospital: '高醫',
      department: '腎臟科',
      completedAt: '2026/05/08 10:04',
      status: ReviewStatus.pending,
    ),
    AdminReviewItem(
      id: 'demo-review-3',
      memberId: 'demo-review-3',
      name: '李佩珊',
      hospital: '亞東醫院',
      department: '小兒科',
      completedAt: '2026/05/08 11:27',
      status: ReviewStatus.pending,
    ),
    AdminReviewItem(
      id: 'demo-review-4',
      memberId: 'demo-review-4',
      name: '王小明',
      hospital: '台大醫院',
      department: '心臟內科',
      completedAt: '2026/05/07 15:42',
      status: ReviewStatus.approved,
    ),
    AdminReviewItem(
      id: 'demo-review-5',
      memberId: 'demo-review-5',
      name: '陳怡君',
      hospital: '榮總',
      department: '家醫科',
      completedAt: '2026/05/07 17:21',
      status: ReviewStatus.approved,
    ),
  ];
  final rewards = <AdminRewardItem>[
    AdminRewardItem(
      id: 'coffee-americano',
      name: '星巴克中杯美式',
      category: '飲品',
      stock: 120,
      issued: 58,
      redeemed: 36,
      expiresAt: '2026/06/30',
      status: RewardStatus.active,
    ),
    AdminRewardItem(
      id: 'convenience-voucher',
      name: '便利商店 100 元購物金',
      category: '禮券',
      stock: 80,
      issued: 42,
      redeemed: 21,
      expiresAt: '2026/07/15',
      status: RewardStatus.active,
    ),
    AdminRewardItem(
      id: 'seminar-discount',
      name: '健康講座報名折扣',
      category: '活動',
      stock: 45,
      issued: 18,
      redeemed: 8,
      expiresAt: '2026/08/01',
      status: RewardStatus.paused,
    ),
    AdminRewardItem(
      id: 'brand-tumbler',
      name: '品牌保溫杯',
      category: '實體贈品',
      stock: 0,
      issued: 30,
      redeemed: 30,
      expiresAt: '2026/05/31',
      status: RewardStatus.paused,
    ),
    AdminRewardItem(
      id: 'old-coffee-batch',
      name: '咖啡券舊活動批次',
      category: '飲品',
      stock: 12,
      issued: 210,
      redeemed: 188,
      expiresAt: '2026/04/30',
      status: RewardStatus.expired,
    ),
  ];
  final members = <backend.VeevaMember>[
    backend.VeevaMember(
      id: 'line-demo-wang',
      name: '王小明',
      hospital: '台大醫院',
      department: '心臟內科',
      status: backend.VeevaMemberStatus.verified,
      earnedCoupons: 3,
      invitedCount: 5,
      shareCode: 'A8D2K',
      lineUserId: 'line-demo-wang',
      email: 'wang@example.com',
      createdAt: DateTime(2026, 5, 7, 9, 30),
      lastLineLoginAt: DateTime(2026, 6, 4, 14, 12),
      isAdmin: true,
      adminRole: 'owner',
    ),
    backend.VeevaMember(
      id: 'line-demo-chen',
      name: '陳怡君',
      hospital: '榮總',
      department: '家醫科',
      status: backend.VeevaMemberStatus.verified,
      earnedCoupons: 2,
      invitedCount: 1,
      shareCode: 'C7K91',
      lineUserId: 'line-demo-chen',
      email: 'chen@example.com',
      createdAt: DateTime(2026, 5, 9, 11, 8),
      lastLineLoginAt: DateTime(2026, 6, 4, 16, 45),
    ),
  ];
  final adminUsers = <backend.VeevaAdminUser>[
    const backend.VeevaAdminUser(
      id: 'line-demo-wang',
      memberId: 'line-demo-wang',
      lineUserId: 'line-demo-wang',
      name: '王小明',
      email: 'wang@example.com',
      role: backend.VeevaAdminRole.owner,
      status: backend.VeevaAdminStatus.active,
      permissions: ['members', 'activities', 'news', 'rewards', 'settings'],
    ),
  ];

  @override
  void initState() {
    super.initState();
    _loadBackend();
  }

  Future<void> _loadBackend() async {
    setState(() {
      isLoading = true;
      backendError = null;
    });
    try {
      final bootstrap = await repository.loadBootstrap();
      if (!mounted) return;
      setState(() {
        final shouldUseBackendUserData = repository is! DemoVeevaRepository;
        if (bootstrap.activities.isNotEmpty) {
          activities = bootstrap.activities;
        }
        if (bootstrap.news.isNotEmpty) {
          news = bootstrap.news;
        }
        if (shouldUseBackendUserData || bootstrap.reviews.isNotEmpty) {
          reviews
            ..clear()
            ..addAll(bootstrap.reviews.map(AdminReviewItem.fromBackend));
        }
        if (bootstrap.rewards.isNotEmpty) {
          rewards
            ..clear()
            ..addAll(bootstrap.rewards.map(AdminRewardItem.fromBackend));
        }
        if (shouldUseBackendUserData || bootstrap.members.isNotEmpty) {
          members
            ..clear()
            ..addAll(bootstrap.members);
        }
        if (shouldUseBackendUserData || bootstrap.adminUsers.isNotEmpty) {
          adminUsers
            ..clear()
            ..addAll(bootstrap.adminUsers);
        }
        isLoading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        backendError = 'Firebase 尚未可用，暫時顯示示範資料。';
        isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isCompact = MediaQuery.sizeOf(context).width < 900;
    final title = _titleFor(tab);
    final titleIcon = _titleIconFor(tab);
    final content = Column(
      children: [
        if (!isCompact)
          _AdminTopBar(
            title: title,
            icon: titleIcon,
            showSearch: tab != AdminTab.members,
          ),
        Expanded(
          child: SingleChildScrollView(
            padding: EdgeInsets.all(isCompact ? 16 : 24),
            child: _buildContent(),
          ),
        ),
      ],
    );

    if (isCompact) {
      return Scaffold(
        appBar: AppBar(
          title: _AdminPageTitle(title: title, icon: titleIcon, compact: true),
          backgroundColor: Colors.white,
          surfaceTintColor: Colors.transparent,
          actions: const [
            Padding(
              padding: EdgeInsets.only(right: 12),
              child: CircleAvatar(child: Icon(Icons.person_outline)),
            ),
          ],
        ),
        drawer: Drawer(
          child: _AdminSidebar(
            selected: tab,
            onSelected: (value) {
              setState(() => tab = value);
              Navigator.of(context).pop();
            },
          ),
        ),
        body: content,
      );
    }

    return Scaffold(
      body: Row(
        children: [
          _AdminSidebar(
            selected: tab,
            onSelected: (value) => setState(() => tab = value),
          ),
          Expanded(child: content),
        ],
      ),
    );
  }

  String _titleFor(AdminTab tab) {
    return switch (tab) {
      AdminTab.dashboard => '儀表板',
      AdminTab.members => '會員管理',
      AdminTab.activities => '活動管理',
      AdminTab.news => '最新資訊管理',
      AdminTab.rewards => '兌換券管理',
      AdminTab.permissions => '權限管理',
      AdminTab.settings => '系統設定',
    };
  }

  IconData? _titleIconFor(AdminTab tab) {
    return switch (tab) {
      AdminTab.permissions => Icons.verified_user_outlined,
      _ => null,
    };
  }

  Widget _buildContent() {
    final content = switch (tab) {
      AdminTab.dashboard => _DashboardContent(reviews: reviews),
      AdminTab.members => _MemberManagement(
          members: members,
          reviews: reviews,
          adminUsers: adminUsers,
          onApprove: _approveReview,
          onSaveMemberSettings: _saveMemberSettings,
        ),
      AdminTab.activities => _ActivityManagement(activities: activities),
      AdminTab.news => _NewsManagement(news: news),
      AdminTab.rewards => _RewardsManagement(
          rewards: rewards,
          onCreate: _showCreateRewardDialog,
          onToggleStatus: _toggleRewardStatus,
          onAddStock: _addRewardStock,
        ),
      AdminTab.permissions => _PermissionsManagement(
          members: members,
          adminUsers: adminUsers,
          onSaveAdminUser: _saveAdminUser,
        ),
      AdminTab.settings => const _PlaceholderPanel(
          icon: Icons.settings_outlined,
          title: '系統設定',
          description: '設定活動期間、獎勵規則、通知模板與管理員權限。',
        ),
    };

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (isLoading) ...[
          const LinearProgressIndicator(minHeight: 2),
          const SizedBox(height: 12),
        ],
        if (backendError != null) ...[
          _BackendNotice(message: backendError!, onRetry: _loadBackend),
          const SizedBox(height: 12),
        ],
        content,
      ],
    );
  }

  Future<void> _approveReview(AdminReviewItem item) async {
    setState(() => item.status = ReviewStatus.approved);
    try {
      await repository.approveReview(item.toBackend());
    } catch (error) {
      setState(() {
        item.status = ReviewStatus.pending;
        backendError = '審核更新失敗：請確認 Firestore API 與 rules 已啟用。';
      });
    }
  }

  Future<void> _toggleRewardStatus(AdminRewardItem reward) async {
    final previous = reward.status;
    setState(() {
      reward.status = reward.status == RewardStatus.active
          ? RewardStatus.paused
          : RewardStatus.active;
    });
    try {
      await repository.saveReward(reward.toBackend());
    } catch (_) {
      setState(() {
        reward.status = previous;
        backendError = '兌換券狀態更新失敗：請確認 Firestore API 與 rules 已啟用。';
      });
    }
  }

  Future<void> _addRewardStock(AdminRewardItem reward) async {
    setState(() => reward.stock += 20);
    try {
      await repository.saveReward(reward.toBackend());
    } catch (_) {
      setState(() {
        reward.stock -= 20;
        backendError = '庫存更新失敗：請確認 Firestore API 與 rules 已啟用。';
      });
    }
  }

  Future<void> _saveAdminUser(backend.VeevaAdminUser adminUser) async {
    final index = adminUsers.indexWhere((item) => item.id == adminUser.id);
    final previous = index == -1 ? null : adminUsers[index];
    final isActive = adminUser.status == backend.VeevaAdminStatus.active;
    setState(() {
      if (index == -1) {
        adminUsers.add(adminUser);
      } else {
        adminUsers[index] = adminUser;
      }
      final memberIndex =
          members.indexWhere((item) => item.id == adminUser.memberId);
      if (memberIndex != -1) {
        final member = members[memberIndex];
        members[memberIndex] = backend.VeevaMember(
          id: member.id,
          name: member.name,
          hospital: member.hospital,
          department: member.department,
          status: member.status,
          accountStatus: member.accountStatus,
          earnedCoupons: member.earnedCoupons,
          invitedCount: member.invitedCount,
          shareCode: member.shareCode,
          lineUserId: member.lineUserId,
          avatarUrl: member.avatarUrl,
          email: member.email,
          lineStatusMessage: member.lineStatusMessage,
          lineIdToken: member.lineIdToken,
          lineIdTokenUpdatedAt: member.lineIdTokenUpdatedAt,
          createdAt: member.createdAt,
          lastLineLoginAt: member.lastLineLoginAt,
          referredByMemberId: member.referredByMemberId,
          referredByShareCode: member.referredByShareCode,
          referredAt: member.referredAt,
          isAdmin: isActive,
          adminRole: isActive ? adminUser.role.name : null,
          updatedAt: member.updatedAt,
        );
      }
    });

    try {
      await repository.saveAdminUser(adminUser);
    } catch (_) {
      setState(() {
        if (previous == null) {
          adminUsers.removeWhere((item) => item.id == adminUser.id);
        } else if (index != -1) {
          adminUsers[index] = previous;
        }
        backendError = '管理權限更新失敗：請確認 Firestore rules 已部署。';
      });
    }
  }

  Future<void> _saveMemberSettings({
    required backend.VeevaMember member,
    backend.VeevaAdminUser? adminUser,
  }) async {
    final previousMembers = [...members];
    final previousAdminUsers = [...adminUsers];
    final isActiveAdmin = adminUser?.status == backend.VeevaAdminStatus.active;

    setState(() {
      final memberIndex = members.indexWhere((item) => item.id == member.id);
      if (memberIndex == -1) {
        members.add(member);
      } else {
        members[memberIndex] = member;
      }

      adminUsers.removeWhere(
        (item) =>
            item.memberId == member.id ||
            item.lineUserId == member.lineUserId ||
            item.id == member.id ||
            item.id == member.lineUserId,
      );
      if (isActiveAdmin && adminUser != null) {
        adminUsers.add(adminUser);
      }
      backendError = null;
    });

    try {
      await repository.saveMemberSettings(
        member: member,
        adminUser: adminUser,
      );
    } catch (_) {
      setState(() {
        members
          ..clear()
          ..addAll(previousMembers);
        adminUsers
          ..clear()
          ..addAll(previousAdminUsers);
        backendError = '會員設定更新失敗：請確認 Firestore rules 已部署。';
      });
    }
  }

  Future<void> _showCreateRewardDialog() async {
    final nameController = TextEditingController();
    final categoryController = TextEditingController(text: '禮券');
    final stockController = TextEditingController(text: '50');
    final expiryController = TextEditingController(text: '2026/08/31');

    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('新增兌換券'),
          content: SizedBox(
            width: 420,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(
                    labelText: '商品名稱',
                    prefixIcon: Icon(Icons.card_giftcard_outlined),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: categoryController,
                  decoration: const InputDecoration(
                    labelText: '分類',
                    prefixIcon: Icon(Icons.category_outlined),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: stockController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: '初始庫存',
                    prefixIcon: Icon(Icons.inventory_2_outlined),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: expiryController,
                  decoration: const InputDecoration(
                    labelText: '兌換期限',
                    prefixIcon: Icon(Icons.event_available_outlined),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('取消'),
            ),
            FilledButton.icon(
              onPressed: () async {
                final stock = int.tryParse(stockController.text.trim()) ?? 0;
                final name = nameController.text.trim();
                if (name.isEmpty || stock <= 0) return;

                final reward = AdminRewardItem(
                  id: createVeevaId('reward'),
                  name: name,
                  category: categoryController.text.trim().isEmpty
                      ? '其他'
                      : categoryController.text.trim(),
                  stock: stock,
                  issued: 0,
                  redeemed: 0,
                  expiresAt: expiryController.text.trim().isEmpty
                      ? '2026/12/31'
                      : expiryController.text.trim(),
                  status: RewardStatus.active,
                );
                setState(() {
                  rewards.insert(0, reward);
                });
                Navigator.of(dialogContext).pop();
                try {
                  await repository.saveReward(reward.toBackend());
                } catch (_) {
                  if (!mounted) return;
                  setState(() {
                    rewards.removeWhere((item) => item.id == reward.id);
                    backendError = '新增兌換券失敗：請確認 Firestore API 與 rules 已啟用。';
                  });
                }
              },
              icon: const Icon(Icons.add),
              label: const Text('建立'),
            ),
          ],
        );
      },
    );

    nameController.dispose();
    categoryController.dispose();
    stockController.dispose();
    expiryController.dispose();
  }
}

class _BackendNotice extends StatelessWidget {
  const _BackendNotice({
    required this.message,
    required this.onRetry,
  });

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0xFFFFF7E8),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFF1D4A5)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          children: [
            const Icon(Icons.info_outline, color: Color(0xFF9A5B10)),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(
                  color: Color(0xFF6B3B08),
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            TextButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('重試'),
            ),
          ],
        ),
      ),
    );
  }
}

class _AdminSidebar extends StatelessWidget {
  const _AdminSidebar({
    required this.selected,
    required this.onSelected,
  });

  final AdminTab selected;
  final ValueChanged<AdminTab> onSelected;

  @override
  Widget build(BuildContext context) {
    final items = [
      (AdminTab.dashboard, Icons.dashboard_outlined, '儀表板'),
      (AdminTab.permissions, Icons.verified_user_outlined, '權限管理'),
      (AdminTab.members, Icons.groups_outlined, '會員管理'),
      (AdminTab.activities, Icons.campaign_outlined, '活動管理'),
      (AdminTab.news, Icons.newspaper_outlined, '最新資訊'),
      (AdminTab.rewards, Icons.confirmation_number_outlined, '兌換券管理'),
      (AdminTab.settings, Icons.settings_outlined, '設定'),
    ];
    return Container(
      width: 232,
      color: const Color(0xFF16241F),
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 10, vertical: 12),
            child: Text(
              'VeeVa Admin',
              style: TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          const SizedBox(height: 20),
          for (final item in items)
            _SidebarItem(
              icon: item.$2,
              label: item.$3,
              selected: selected == item.$1,
              onTap: () => onSelected(item.$1),
            ),
          const Spacer(),
          const Text(
            '活動問卷管理系統',
            style: TextStyle(color: Color(0xFF93A09A), fontSize: 12),
          ),
        ],
      ),
    );
  }
}

class _SidebarItem extends StatelessWidget {
  const _SidebarItem({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: selected ? const Color(0xFF216B57) : Colors.transparent,
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            child: Row(
              children: [
                Icon(icon,
                    color: selected ? Colors.white : const Color(0xFFC4CEC9)),
                const SizedBox(width: 12),
                Text(
                  label,
                  style: TextStyle(
                    color: selected ? Colors.white : const Color(0xFFC4CEC9),
                    fontWeight: FontWeight.w800,
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

class _AdminPageTitle extends StatelessWidget {
  const _AdminPageTitle({
    required this.title,
    this.icon,
    this.compact = false,
  });

  final String title;
  final IconData? icon;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final iconSize = compact ? 32.0 : 38.0;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (icon != null) ...[
          Container(
            width: iconSize,
            height: iconSize,
            decoration: BoxDecoration(
              color: const Color(0xFFE8F5EF),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              icon,
              size: compact ? 18 : 22,
              color: const Color(0xFF216B57),
            ),
          ),
          SizedBox(width: compact ? 8 : 10),
        ],
        Flexible(
          child: Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: compact ? 20 : 24,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
      ],
    );
  }
}

class _AdminTopBar extends StatelessWidget {
  const _AdminTopBar({
    required this.title,
    this.icon,
    this.showSearch = true,
  });

  final String title;
  final IconData? icon;
  final bool showSearch;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 72,
      padding: const EdgeInsets.symmetric(horizontal: 24),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: Color(0xFFE4E8EA))),
      ),
      child: Row(
        children: [
          _AdminPageTitle(title: title, icon: icon),
          const Spacer(),
          if (showSearch) ...[
            SizedBox(
              width: 280,
              child: TextField(
                decoration: InputDecoration(
                  hintText: '搜尋會員、院所、科別',
                  prefixIcon: const Icon(Icons.search),
                  isDense: true,
                  filled: true,
                  fillColor: const Color(0xFFF5F7F8),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 16),
          ],
          const CircleAvatar(child: Icon(Icons.person_outline)),
        ],
      ),
    );
  }
}

class _DashboardContent extends StatelessWidget {
  const _DashboardContent({required this.reviews});

  final List<AdminReviewItem> reviews;

  @override
  Widget build(BuildContext context) {
    final isCompact = MediaQuery.sizeOf(context).width < 900;
    final pending =
        reviews.where((item) => item.status == ReviewStatus.pending).length;
    final approved =
        reviews.where((item) => item.status == ReviewStatus.approved).length;
    final metrics = [
      const _MetricCard(
        label: '問卷完成',
        value: '128',
        icon: Icons.assignment_turned_in_outlined,
      ),
      _MetricCard(
        label: '待審核',
        value: '$pending',
        icon: Icons.pending_actions_outlined,
      ),
      _MetricCard(
        label: '審核通過',
        value: '$approved',
        icon: Icons.verified_user_outlined,
      ),
      const _MetricCard(
        label: '兌換券庫存',
        value: '342',
        icon: Icons.inventory_2_outlined,
      ),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (isCompact)
          Column(
            children: [
              for (final metric in metrics)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: metric,
                ),
            ],
          )
        else
          Row(
            children: [
              for (var index = 0; index < metrics.length; index++) ...[
                Expanded(child: metrics[index]),
                if (index != metrics.length - 1) const SizedBox(width: 16),
              ],
            ],
          ),
        const SizedBox(height: 20),
        if (isCompact)
          Column(
            children: [
              _ReviewTable(
                title: '最新待審核',
                items: reviews
                    .where((item) => item.status == ReviewStatus.pending),
                compact: true,
              ),
              const SizedBox(height: 16),
              const _StatusPanel(),
            ],
          )
        else
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                flex: 2,
                child: _ReviewTable(
                  title: '最新待審核',
                  items: reviews
                      .where((item) => item.status == ReviewStatus.pending),
                  compact: true,
                ),
              ),
              const SizedBox(width: 16),
              const Expanded(child: _StatusPanel()),
            ],
          ),
      ],
    );
  }
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({
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
              child: Icon(icon, color: const Color(0xFF216B57)),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: const TextStyle(color: Color(0xFF6B7671))),
                  const SizedBox(height: 4),
                  Text(
                    value,
                    style: const TextStyle(
                        fontSize: 26, fontWeight: FontWeight.w900),
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

class _ReviewTable extends StatelessWidget {
  const _ReviewTable({
    required this.title,
    required this.items,
    this.compact = false,
  });

  final String title;
  final Iterable<AdminReviewItem> items;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final rows = items.toList();
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title,
                style:
                    const TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
            const SizedBox(height: 14),
            _ReviewListBody(
              rows: rows,
              compact: compact,
            ),
          ],
        ),
      ),
    );
  }
}

class _ReviewListBody extends StatelessWidget {
  const _ReviewListBody({
    required this.rows,
    required this.compact,
    this.emptyMessage = '目前沒有符合條件的資料。',
    this.onApprove,
  });

  final List<AdminReviewItem> rows;
  final ValueChanged<AdminReviewItem>? onApprove;
  final bool compact;
  final String emptyMessage;

  @override
  Widget build(BuildContext context) {
    final isCompact = MediaQuery.sizeOf(context).width < 700;

    if (rows.isEmpty) {
      return _EmptyListMessage(message: emptyMessage);
    }

    if (isCompact) {
      return Column(
        children: [
          for (final item in rows)
            _MobileReviewCard(item: item, onApprove: onApprove),
        ],
      );
    }

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: DataTable(
          headingRowColor: WidgetStateProperty.all(const Color(0xFFF5F7F8)),
          columns: [
            const DataColumn(label: Text('姓名')),
            const DataColumn(label: Text('院所 / 科別')),
            if (!compact) const DataColumn(label: Text('完成時間')),
            const DataColumn(label: Text('狀態')),
            if (onApprove != null) const DataColumn(label: Text('操作')),
          ],
          rows: [
            for (final item in rows)
              DataRow(
                cells: [
                  DataCell(Text(item.name)),
                  DataCell(Text('${item.hospital} / ${item.department}')),
                  if (!compact) DataCell(Text(item.completedAt)),
                  DataCell(_StatusChip(status: item.status)),
                  if (onApprove != null)
                    DataCell(
                      FilledButton(
                        onPressed: () => onApprove!(item),
                        child: const Text('通過'),
                      ),
                    ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}

class _MobileReviewCard extends StatelessWidget {
  const _MobileReviewCard({
    required this.item,
    this.onApprove,
  });

  final AdminReviewItem item;
  final ValueChanged<AdminReviewItem>? onApprove;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFA),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE4E8EA)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  item.name,
                  style: const TextStyle(
                      fontSize: 16, fontWeight: FontWeight.w900),
                ),
              ),
              _StatusChip(status: item.status),
            ],
          ),
          const SizedBox(height: 8),
          Text('${item.hospital} / ${item.department}'),
          const SizedBox(height: 4),
          Text(
            item.completedAt,
            style: const TextStyle(color: Color(0xFF6B7671), fontSize: 12),
          ),
          if (onApprove != null) ...[
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerRight,
              child: FilledButton(
                onPressed: () => onApprove!(item),
                child: const Text('通過'),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.status});

  final ReviewStatus status;

  @override
  Widget build(BuildContext context) {
    final approved = status == ReviewStatus.approved;
    return Chip(
      label: Text(approved ? '已審核' : '待審核'),
      backgroundColor:
          approved ? const Color(0xFFEAF3EA) : const Color(0xFFFFF4D9),
      side: BorderSide.none,
    );
  }
}

class _StatusPanel extends StatelessWidget {
  const _StatusPanel();

  @override
  Widget build(BuildContext context) {
    return const Card(
      child: Padding(
        padding: EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('名單狀態分布',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
            SizedBox(height: 16),
            _ProgressRow(label: '已通過', value: .62),
            _ProgressRow(label: '待審核', value: .22),
            _ProgressRow(label: '未完成', value: .16),
          ],
        ),
      ),
    );
  }
}

class _ProgressRow extends StatelessWidget {
  const _ProgressRow({required this.label, required this.value});

  final String label;
  final double value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(label, style: const TextStyle(fontWeight: FontWeight.w800)),
              const Spacer(),
              Text('${(value * 100).round()}%'),
            ],
          ),
          const SizedBox(height: 8),
          LinearProgressIndicator(value: value, minHeight: 8),
        ],
      ),
    );
  }
}

class _MemberManagement extends StatefulWidget {
  const _MemberManagement({
    required this.members,
    required this.reviews,
    required this.adminUsers,
    required this.onApprove,
    required this.onSaveMemberSettings,
  });

  final List<backend.VeevaMember> members;
  final List<AdminReviewItem> reviews;
  final List<backend.VeevaAdminUser> adminUsers;
  final ValueChanged<AdminReviewItem> onApprove;
  final Future<void> Function({
    required backend.VeevaMember member,
    backend.VeevaAdminUser? adminUser,
  }) onSaveMemberSettings;

  @override
  State<_MemberManagement> createState() => _MemberManagementState();
}

class _MemberManagementState extends State<_MemberManagement> {
  static const int _pageSize = 8;

  final searchController = TextEditingController();
  MemberManagementTab selectedTab = MemberManagementTab.loggedIn;
  String searchQuery = '';
  int loggedInPage = 0;
  int pendingReviewPage = 0;
  int approvedReviewPage = 0;

  @override
  void dispose() {
    searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isCompact = MediaQuery.sizeOf(context).width < 760;
    final normalizedQuery = _normalizeMemberSearch(searchQuery);
    final loggedInMembers = [...widget.members]..sort((a, b) {
        final aTime = a.lastLineLoginAt;
        final bTime = b.lastLineLoginAt;
        if (aTime != null && bTime != null) {
          return bTime.compareTo(aTime);
        }
        if (aTime != null) return -1;
        if (bTime != null) return 1;
        return a.name.compareTo(b.name);
      });
    final filteredLoggedInMembers = loggedInMembers
        .where((member) => _memberMatchesSearch(member, normalizedQuery))
        .toList();
    final pending = widget.reviews
        .where((item) => item.status == ReviewStatus.pending)
        .length;
    final approved = widget.reviews
        .where((item) => item.status == ReviewStatus.approved)
        .length;
    final selectedReviewStatus =
        selectedTab == MemberManagementTab.approvedReview
            ? ReviewStatus.approved
            : ReviewStatus.pending;
    final reviewRows = widget.reviews
        .where((item) => item.status == selectedReviewStatus)
        .toList();
    final filteredReviewRows = reviewRows
        .where((item) => _reviewMatchesSearch(item, normalizedQuery))
        .toList();
    final title = switch (selectedTab) {
      MemberManagementTab.loggedIn => '已登入會員名單',
      MemberManagementTab.pendingReview => '待審核名單',
      MemberManagementTab.approvedReview => '已審核名單',
    };
    final visibleCount = selectedTab == MemberManagementTab.loggedIn
        ? filteredLoggedInMembers.length
        : filteredReviewRows.length;
    final unfilteredCount = selectedTab == MemberManagementTab.loggedIn
        ? loggedInMembers.length
        : reviewRows.length;
    final pageIndex = _clampedPage(_pageFor(selectedTab), visibleCount);
    final pagedLoggedInMembers =
        _pageItems(filteredLoggedInMembers, pageIndex, _pageSize);
    final pagedReviewRows =
        _pageItems(filteredReviewRows, pageIndex, _pageSize);
    final countText = normalizedQuery.isEmpty
        ? '共 $visibleCount 筆'
        : '符合 $visibleCount / $unfilteredCount 筆';
    final metrics = [
      _MetricCard(
        label: '已登入會員',
        value: '${loggedInMembers.length}',
        icon: Icons.groups_outlined,
      ),
      _MetricCard(
        label: '待審核會員',
        value: '$pending',
        icon: Icons.pending_actions_outlined,
      ),
      _MetricCard(
        label: '已審核會員',
        value: '$approved',
        icon: Icons.verified_user_outlined,
      ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (isCompact)
          Column(
            children: [
              for (final metric in metrics)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: metric,
                ),
            ],
          )
        else
          Row(
            children: [
              for (var index = 0; index < metrics.length; index++) ...[
                Expanded(child: metrics[index]),
                if (index != metrics.length - 1) const SizedBox(width: 16),
              ],
            ],
          ),
        const SizedBox(height: 20),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        title,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                    Text(
                      countText,
                      style: const TextStyle(color: Color(0xFF6B7671)),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                _MemberSearchField(
                  controller: searchController,
                  onChanged: (value) => setState(() {
                    searchQuery = value;
                    _resetPages();
                  }),
                  onClear: searchQuery.trim().isEmpty
                      ? null
                      : () => setState(() {
                            searchController.clear();
                            searchQuery = '';
                            _resetPages();
                          }),
                ),
                const SizedBox(height: 16),
                _MemberStatusTabs(
                  selectedTab: selectedTab,
                  loggedInCount: loggedInMembers.length,
                  pendingCount: pending,
                  approvedCount: approved,
                  onChanged: (tab) => setState(() {
                    selectedTab = tab;
                    _setPageFor(tab, 0);
                  }),
                ),
                const SizedBox(height: 16),
                if (selectedTab == MemberManagementTab.loggedIn)
                  _LoggedInMemberListBody(
                    members: pagedLoggedInMembers,
                    adminUsers: widget.adminUsers,
                    compact: isCompact,
                    emptyMessage: normalizedQuery.isEmpty
                        ? '尚無已登入會員。會員從 LIFF 完成 LINE 登入後會出現在這裡。'
                        : '查無符合條件的已登入會員。',
                    onSettingChanged: _changeMemberSetting,
                  )
                else
                  _ReviewListBody(
                    rows: pagedReviewRows,
                    compact: isCompact,
                    emptyMessage: normalizedQuery.isEmpty
                        ? selectedTab == MemberManagementTab.pendingReview
                            ? '目前沒有待審核會員。'
                            : '目前沒有已審核會員。'
                        : '查無符合條件的會員。',
                    onApprove: selectedTab == MemberManagementTab.pendingReview
                        ? widget.onApprove
                        : null,
                  ),
                if (visibleCount > 0) ...[
                  const SizedBox(height: 14),
                  _MemberPaginationBar(
                    currentPage: pageIndex,
                    pageSize: _pageSize,
                    totalItems: visibleCount,
                    onPageChanged: (page) => setState(
                      () => _setPageFor(selectedTab, page),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }

  int _pageFor(MemberManagementTab tab) {
    return switch (tab) {
      MemberManagementTab.loggedIn => loggedInPage,
      MemberManagementTab.pendingReview => pendingReviewPage,
      MemberManagementTab.approvedReview => approvedReviewPage,
    };
  }

  void _setPageFor(MemberManagementTab tab, int page) {
    switch (tab) {
      case MemberManagementTab.loggedIn:
        loggedInPage = page;
        break;
      case MemberManagementTab.pendingReview:
        pendingReviewPage = page;
        break;
      case MemberManagementTab.approvedReview:
        approvedReviewPage = page;
        break;
    }
  }

  void _resetPages() {
    loggedInPage = 0;
    pendingReviewPage = 0;
    approvedReviewPage = 0;
  }

  Future<void> _changeMemberSetting(
    backend.VeevaMember member,
    _MemberSettingSelection selection,
  ) async {
    final existing = _adminFor(member);
    final selectedRole = _roleForMemberSettingSelection(selection);
    final isAdmin = selectedRole != null;
    final accountStatus = selection == _MemberSettingSelection.disabledAccount
        ? backend.VeevaMemberAccountStatus.disabled
        : backend.VeevaMemberAccountStatus.active;
    final updatedMember = _memberWithSettings(
      member,
      accountStatus: accountStatus,
      isAdmin: isAdmin,
      adminRole: selectedRole?.name,
    );
    if (!isAdmin) {
      final adminUserToRemove = existing == null
          ? null
          : backend.VeevaAdminUser(
              id: existing.id,
              memberId: existing.memberId,
              lineUserId: existing.lineUserId,
              name: existing.name,
              email: existing.email,
              avatarUrl: existing.avatarUrl,
              role: existing.role,
              status: backend.VeevaAdminStatus.disabled,
              permissions: const [],
              grantedAt: existing.grantedAt,
              updatedAt: existing.updatedAt,
            );
      await widget.onSaveMemberSettings(
        member: updatedMember,
        adminUser: adminUserToRemove,
      );
      return;
    }
    final role = selectedRole;
    final adminUser = backend.VeevaAdminUser(
      id: existing?.id ?? member.id,
      memberId: member.id,
      lineUserId: member.lineUserId ?? member.id,
      name: member.name,
      email: member.email,
      avatarUrl: member.avatarUrl,
      role: role,
      status: backend.VeevaAdminStatus.active,
      permissions: _permissionsForRole(role),
      grantedAt: existing?.grantedAt ?? DateTime.now(),
    );
    await widget.onSaveMemberSettings(
      member: updatedMember,
      adminUser: adminUser,
    );
  }

  backend.VeevaAdminUser? _adminFor(backend.VeevaMember member) {
    for (final admin in widget.adminUsers) {
      if (admin.memberId == member.id ||
          admin.lineUserId == member.lineUserId) {
        return admin;
      }
    }
    return null;
  }
}

class _LoggedInMemberListBody extends StatelessWidget {
  const _LoggedInMemberListBody({
    required this.members,
    required this.adminUsers,
    required this.compact,
    required this.emptyMessage,
    required this.onSettingChanged,
  });

  final List<backend.VeevaMember> members;
  final List<backend.VeevaAdminUser> adminUsers;
  final bool compact;
  final String emptyMessage;
  final Future<void> Function(
    backend.VeevaMember member,
    _MemberSettingSelection selection,
  ) onSettingChanged;

  @override
  Widget build(BuildContext context) {
    if (members.isEmpty) {
      return _EmptyListMessage(message: emptyMessage);
    }

    if (compact) {
      return Column(
        children: [
          for (final member in members)
            _LoggedInMemberCard(
              member: member,
              adminUser: _adminFor(member),
              onSettingChanged: (selection) =>
                  onSettingChanged(member, selection),
            ),
        ],
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final availableWidth =
            constraints.maxWidth.isFinite ? constraints.maxWidth : 920.0;
        final tableWidth = availableWidth < 772 ? 772.0 : availableWidth;
        final contentWidth = tableWidth - 32 - 60;
        final nameWidth = contentWidth * .30;
        final firstLoginWidth = contentWidth * .22;
        final lastLoginWidth = contentWidth * .22;
        final settingWidth =
            contentWidth - nameWidth - firstLoginWidth - lastLoginWidth;

        return SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: SizedBox(
            width: tableWidth,
            child: DataTable(
              horizontalMargin: 16,
              columnSpacing: 20,
              headingRowColor: WidgetStateProperty.all(const Color(0xFFF1F4F3)),
              dataRowMinHeight: 72,
              dataRowMaxHeight: 88,
              columns: [
                DataColumn(label: _TableHeaderLabel('會員名稱', width: nameWidth)),
                DataColumn(
                  label: _TableHeaderLabel('第一次登入時間', width: firstLoginWidth),
                ),
                DataColumn(
                  label: _TableHeaderLabel('最後一次登入時間', width: lastLoginWidth),
                ),
                DataColumn(
                  label: _TableHeaderLabel('會員設定', width: settingWidth),
                ),
              ],
              rows: [
                for (final member in members)
                  DataRow(
                    cells: [
                      DataCell(
                        SizedBox(
                          width: nameWidth,
                          child: _MemberNameOnly(member: member),
                        ),
                      ),
                      DataCell(
                        SizedBox(
                          width: firstLoginWidth,
                          child: Text(
                            _memberDateTimeLabel(_memberFirstLoginAt(member)),
                          ),
                        ),
                      ),
                      DataCell(
                        SizedBox(
                          width: lastLoginWidth,
                          child: Text(
                            _memberDateTimeLabel(member.lastLineLoginAt),
                          ),
                        ),
                      ),
                      DataCell(
                        SizedBox(
                          width: settingWidth,
                          child: _MemberSettingDropdown(
                            width: settingWidth,
                            member: member,
                            adminUser: _adminFor(member),
                            onChanged: (selection) =>
                                onSettingChanged(member, selection),
                          ),
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  backend.VeevaAdminUser? _adminFor(backend.VeevaMember member) {
    for (final admin in adminUsers) {
      if (admin.memberId == member.id ||
          admin.lineUserId == member.lineUserId) {
        return admin;
      }
    }
    return null;
  }
}

class _LoggedInMemberCard extends StatelessWidget {
  const _LoggedInMemberCard({
    required this.member,
    required this.adminUser,
    required this.onSettingChanged,
  });

  final backend.VeevaMember member;
  final backend.VeevaAdminUser? adminUser;
  final ValueChanged<_MemberSettingSelection> onSettingChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFA),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE4E8EA)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _MemberNameOnly(member: member),
          const SizedBox(height: 10),
          _MemberTimeLine(
            label: '第一次登入',
            value: _memberDateTimeLabel(_memberFirstLoginAt(member)),
          ),
          const SizedBox(height: 6),
          _MemberTimeLine(
            label: '最後一次登入',
            value: _memberDateTimeLabel(member.lastLineLoginAt),
          ),
          const SizedBox(height: 12),
          _MemberSettingDropdown(
            width: double.infinity,
            member: member,
            adminUser: adminUser,
            onChanged: onSettingChanged,
          ),
        ],
      ),
    );
  }
}

class _TableHeaderLabel extends StatelessWidget {
  const _TableHeaderLabel(this.text, {required this.width});

  final String text;
  final double width;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      child: Text(
        text,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }
}

class _MemberTimeLine extends StatelessWidget {
  const _MemberTimeLine({
    required this.label,
    required this.value,
  });

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SizedBox(
          width: 92,
          child: Text(
            label,
            style: const TextStyle(color: Color(0xFF6B7671)),
          ),
        ),
        Expanded(
          child: Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
        ),
      ],
    );
  }
}

enum _MemberSettingSelection {
  regular,
  owner,
  manager,
  editor,
  viewer,
  disabledAccount,
}

class _MemberNameOnly extends StatelessWidget {
  const _MemberNameOnly({required this.member});

  final backend.VeevaMember member;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.max,
      children: [
        CircleAvatar(
          radius: 18,
          backgroundImage:
              member.avatarUrl == null ? null : NetworkImage(member.avatarUrl!),
          child: member.avatarUrl == null
              ? Text(member.name.characters.first)
              : null,
        ),
        const SizedBox(width: 10),
        Flexible(
          child: Text(
            member.name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontWeight: FontWeight.w900),
          ),
        ),
      ],
    );
  }
}

class _MemberSettingDropdown extends StatelessWidget {
  const _MemberSettingDropdown({
    required this.member,
    required this.adminUser,
    required this.onChanged,
    this.width = 176,
  });

  final backend.VeevaMember member;
  final backend.VeevaAdminUser? adminUser;
  final ValueChanged<_MemberSettingSelection> onChanged;
  final double width;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      child: DropdownButtonFormField<_MemberSettingSelection>(
        value: _selectionForMemberSetting(member, adminUser),
        isExpanded: true,
        decoration: const InputDecoration(
          isDense: true,
          border: OutlineInputBorder(),
          contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        ),
        items: [
          for (final selection in _memberSettingSelections)
            DropdownMenuItem(
              value: selection,
              child: Text(_memberSettingSelectionLabel(selection)),
            ),
        ],
        onChanged: (selection) {
          if (selection == null) return;
          onChanged(selection);
        },
      ),
    );
  }
}

class _MemberSearchField extends StatelessWidget {
  const _MemberSearchField({
    required this.controller,
    required this.onChanged,
    this.onClear,
  });

  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  final VoidCallback? onClear;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      onChanged: onChanged,
      textInputAction: TextInputAction.search,
      decoration: InputDecoration(
        hintText: '搜尋姓名、LINE ID、Email、院所、科別',
        prefixIcon: const Icon(Icons.search),
        suffixIcon: onClear == null
            ? null
            : IconButton(
                tooltip: '清除搜尋',
                onPressed: onClear,
                icon: const Icon(Icons.close),
              ),
        filled: true,
        fillColor: const Color(0xFFF8FAFA),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: Color(0xFFE4E8EA)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: Color(0xFFE4E8EA)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: Color(0xFF216B57), width: 1.4),
        ),
      ),
    );
  }
}

class _MemberPaginationBar extends StatelessWidget {
  const _MemberPaginationBar({
    required this.currentPage,
    required this.pageSize,
    required this.totalItems,
    required this.onPageChanged,
  });

  final int currentPage;
  final int pageSize;
  final int totalItems;
  final ValueChanged<int> onPageChanged;

  @override
  Widget build(BuildContext context) {
    final totalPages = ((totalItems - 1) ~/ pageSize) + 1;
    final start = currentPage * pageSize + 1;
    final rawEnd = (currentPage + 1) * pageSize;
    final end = rawEnd > totalItems ? totalItems : rawEnd;
    final canGoBack = currentPage > 0;
    final canGoForward = currentPage < totalPages - 1;
    final isCompact = MediaQuery.sizeOf(context).width < 620;
    final pageText = '第 ${currentPage + 1} / $totalPages 頁';
    final rangeText = '$start-$end 筆';
    final controls = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          tooltip: '上一頁',
          onPressed: canGoBack ? () => onPageChanged(currentPage - 1) : null,
          icon: const Icon(Icons.chevron_left),
        ),
        Container(
          constraints: const BoxConstraints(minWidth: 96),
          alignment: Alignment.center,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: const Color(0xFFF8FAFA),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: const Color(0xFFE4E8EA)),
          ),
          child: Text(
            pageText,
            style: const TextStyle(fontWeight: FontWeight.w800),
          ),
        ),
        IconButton(
          tooltip: '下一頁',
          onPressed: canGoForward ? () => onPageChanged(currentPage + 1) : null,
          icon: const Icon(Icons.chevron_right),
        ),
      ],
    );

    final summary = Text(
      '每頁 $pageSize 筆 · $rangeText',
      style: const TextStyle(color: Color(0xFF6B7671)),
    );

    if (isCompact) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          summary,
          const SizedBox(height: 8),
          controls,
        ],
      );
    }

    return Row(
      children: [
        summary,
        const Spacer(),
        controls,
      ],
    );
  }
}

class _EmptyListMessage extends StatelessWidget {
  const _EmptyListMessage({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFA),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE4E8EA)),
      ),
      child: Text(message),
    );
  }
}

class _PermissionsManagement extends StatefulWidget {
  const _PermissionsManagement({
    required this.members,
    required this.adminUsers,
    required this.onSaveAdminUser,
  });

  final List<backend.VeevaMember> members;
  final List<backend.VeevaAdminUser> adminUsers;
  final Future<void> Function(backend.VeevaAdminUser adminUser) onSaveAdminUser;

  @override
  State<_PermissionsManagement> createState() => _PermissionsManagementState();
}

class _PermissionsManagementState extends State<_PermissionsManagement> {
  @override
  Widget build(BuildContext context) {
    final activeAdmins = widget.adminUsers
        .where((item) => item.status == backend.VeevaAdminStatus.active)
        .length;
    final disabledMembers = widget.members
        .where(
          (item) =>
              item.accountStatus == backend.VeevaMemberAccountStatus.disabled,
        )
        .length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: _MetricCard(
                label: '管理者總數',
                value: '$activeAdmins',
                icon: Icons.groups_outlined,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _MetricCard(
                label: '啟用管理者',
                value: '$activeAdmins',
                icon: Icons.admin_panel_settings_outlined,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _MetricCard(
                label: '停用帳號',
                value: '$disabledMembers',
                icon: Icons.block_outlined,
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),
        _LineMemberAdminPanel(
          members: widget.members,
          adminUsers: widget.adminUsers,
          onEditPermission: _openPermissionDialog,
        ),
      ],
    );
  }

  Future<void> _openPermissionDialog(backend.VeevaMember member) async {
    final existing = _adminFor(member);
    var role = existing?.role ?? backend.VeevaAdminRole.manager;
    var status = existing?.status ?? backend.VeevaAdminStatus.active;
    final selected = <String>{
      ...(existing?.permissions ?? _permissionsForRole(role)),
    };

    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: Text(existing == null ? '授權管理者' : '編輯管理權限'),
              content: SizedBox(
                width: 520,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _MemberPermissionHeader(member: member),
                      const SizedBox(height: 18),
                      DropdownButtonFormField<backend.VeevaAdminRole>(
                        value: role,
                        decoration: const InputDecoration(
                          labelText: '管理角色',
                          prefixIcon: Icon(Icons.badge_outlined),
                        ),
                        items: [
                          for (final item in backend.VeevaAdminRole.values)
                            DropdownMenuItem(
                              value: item,
                              child: Text(_adminRoleLabel(item)),
                            ),
                        ],
                        onChanged: (value) {
                          if (value == null) return;
                          setDialogState(() {
                            role = value;
                            selected.clear();
                            if (status == backend.VeevaAdminStatus.active) {
                              selected.addAll(_permissionsForRole(value));
                            }
                          });
                        },
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<backend.VeevaAdminStatus>(
                        value: status,
                        decoration: const InputDecoration(
                          labelText: '管理權限狀態',
                          prefixIcon: Icon(Icons.toggle_on_outlined),
                        ),
                        items: [
                          for (final item in backend.VeevaAdminStatus.values)
                            DropdownMenuItem(
                              value: item,
                              child: Text(_adminStatusLabel(item)),
                            ),
                        ],
                        onChanged: (value) {
                          if (value == null) return;
                          setDialogState(() {
                            status = value;
                            if (value == backend.VeevaAdminStatus.disabled) {
                              selected.clear();
                            } else if (selected.isEmpty) {
                              selected.addAll(_permissionsForRole(role));
                            }
                          });
                        },
                      ),
                      const SizedBox(height: 18),
                      const Text(
                        '功能權限',
                        style: TextStyle(fontWeight: FontWeight.w900),
                      ),
                      const SizedBox(height: 8),
                      for (final permission in _adminPermissionOptions)
                        CheckboxListTile(
                          value: selected.contains(permission.id),
                          dense: true,
                          contentPadding: EdgeInsets.zero,
                          title: Text(permission.label),
                          subtitle: Text(permission.description),
                          onChanged: (checked) {
                            setDialogState(() {
                              if (checked == true) {
                                selected.add(permission.id);
                              } else {
                                selected.remove(permission.id);
                              }
                            });
                          },
                        ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(),
                  child: const Text('取消'),
                ),
                FilledButton.icon(
                  onPressed: status == backend.VeevaAdminStatus.active &&
                          selected.isEmpty
                      ? null
                      : () async {
                          final adminUser = backend.VeevaAdminUser(
                            id: member.id,
                            memberId: member.id,
                            lineUserId: member.lineUserId ?? member.id,
                            name: member.name,
                            email: member.email,
                            avatarUrl: member.avatarUrl,
                            role: role,
                            status: status,
                            permissions:
                                status == backend.VeevaAdminStatus.disabled
                                    ? const []
                                    : (selected.toList()..sort()),
                            grantedAt: existing?.grantedAt ?? DateTime.now(),
                          );
                          await widget.onSaveAdminUser(adminUser);
                          if (dialogContext.mounted) {
                            Navigator.of(dialogContext).pop();
                          }
                        },
                  icon: const Icon(Icons.save_outlined),
                  label: const Text('儲存權限'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  backend.VeevaAdminUser? _adminFor(backend.VeevaMember member) {
    for (final admin in widget.adminUsers) {
      if (admin.memberId == member.id ||
          admin.lineUserId == member.lineUserId) {
        return admin;
      }
    }
    return null;
  }
}

class _LineMemberAdminPanel extends StatelessWidget {
  const _LineMemberAdminPanel({
    required this.members,
    required this.adminUsers,
    required this.onEditPermission,
  });

  final List<backend.VeevaMember> members;
  final List<backend.VeevaAdminUser> adminUsers;
  final ValueChanged<backend.VeevaMember> onEditPermission;

  @override
  Widget build(BuildContext context) {
    final isCompact = MediaQuery.sizeOf(context).width < 760;
    final adminRows = [
      for (final admin in adminUsers)
        if (admin.status == backend.VeevaAdminStatus.active)
          (_memberForAdmin(admin), admin),
    ]..sort((a, b) {
        final adminA = a.$2.status == backend.VeevaAdminStatus.active;
        final adminB = b.$2.status == backend.VeevaAdminStatus.active;
        if (adminA != adminB) return adminA ? -1 : 1;
        return a.$1.name.compareTo(b.$1.name);
      });

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(
                  Icons.admin_panel_settings_outlined,
                  color: Color(0xFF216B57),
                ),
                const SizedBox(width: 10),
                const Expanded(
                  child: Text(
                    '後台管理者權限',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
                  ),
                ),
                Text(
                  '共 ${adminRows.length} 位啟用管理者',
                  style: const TextStyle(color: Color(0xFF6B7671)),
                ),
              ],
            ),
            const SizedBox(height: 14),
            if (adminRows.isEmpty)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFA),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFFE4E8EA)),
                ),
                child: const Text('目前沒有啟用中的管理者。請到會員管理的已登入會員清單設定管理職位。'),
              )
            else if (isCompact)
              Column(
                children: [
                  for (final row in adminRows)
                    _LineMemberAdminCard(
                      member: row.$1,
                      adminUser: row.$2,
                      onEditPermission: () => onEditPermission(row.$1),
                    ),
                ],
              )
            else
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: DataTable(
                  headingRowColor:
                      WidgetStateProperty.all(const Color(0xFFF1F4F3)),
                  dataRowMinHeight: 72,
                  dataRowMaxHeight: 88,
                  columns: const [
                    DataColumn(label: Text('管理者')),
                    DataColumn(label: Text('後台角色')),
                    DataColumn(label: Text('狀態')),
                    DataColumn(label: Text('權限')),
                    DataColumn(label: Text('操作')),
                  ],
                  rows: [
                    for (final row in adminRows)
                      _memberAdminDataRow(row.$1, row.$2),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  DataRow _memberAdminDataRow(
    backend.VeevaMember member,
    backend.VeevaAdminUser adminUser,
  ) {
    return DataRow(
      cells: [
        DataCell(_MemberIdentity(member: member)),
        DataCell(_AdminRoleChip(adminUser: adminUser)),
        DataCell(Text(_adminStatusLabel(adminUser.status))),
        DataCell(
          SizedBox(
            width: 240,
            child: Text(
              adminUser.permissions.isEmpty
                  ? '尚未授權'
                  : adminUser.permissions.map(_permissionLabel).join('、'),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ),
        DataCell(
          TextButton.icon(
            onPressed: () => onEditPermission(member),
            icon: const Icon(Icons.manage_accounts_outlined),
            label: const Text('編輯'),
          ),
        ),
      ],
    );
  }

  backend.VeevaMember _memberForAdmin(backend.VeevaAdminUser adminUser) {
    for (final member in members) {
      if (member.id == adminUser.memberId ||
          member.lineUserId == adminUser.lineUserId) {
        return member;
      }
    }
    return backend.VeevaMember(
      id: adminUser.memberId,
      name: adminUser.name,
      hospital: '',
      department: '',
      status: backend.VeevaMemberStatus.loggedIn,
      earnedCoupons: 0,
      invitedCount: 0,
      shareCode: adminUser.memberId.length >= 5
          ? adminUser.memberId.substring(0, 5)
          : adminUser.memberId,
      lineUserId: adminUser.lineUserId,
      email: adminUser.email,
      avatarUrl: adminUser.avatarUrl,
      isAdmin: adminUser.status == backend.VeevaAdminStatus.active,
      adminRole: adminUser.role.name,
    );
  }
}

class _LineMemberAdminCard extends StatelessWidget {
  const _LineMemberAdminCard({
    required this.member,
    required this.adminUser,
    required this.onEditPermission,
  });

  final backend.VeevaMember member;
  final backend.VeevaAdminUser adminUser;
  final VoidCallback onEditPermission;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFA),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE4E8EA)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: _MemberIdentity(member: member)),
              _AdminRoleChip(adminUser: adminUser),
            ],
          ),
          const SizedBox(height: 10),
          Text('狀態：${_adminStatusLabel(adminUser.status)}'),
          const SizedBox(height: 8),
          Text(
            adminUser.permissions.isEmpty
                ? '權限：尚未授權'
                : '權限：${adminUser.permissions.map(_permissionLabel).join('、')}',
          ),
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerRight,
            child: FilledButton.tonalIcon(
              onPressed: onEditPermission,
              icon: const Icon(Icons.manage_accounts_outlined),
              label: const Text('編輯權限'),
            ),
          ),
        ],
      ),
    );
  }
}

class _MemberIdentity extends StatelessWidget {
  const _MemberIdentity({required this.member});

  final backend.VeevaMember member;

  @override
  Widget build(BuildContext context) {
    final identifier = member.email?.isNotEmpty == true
        ? member.email!
        : member.lineUserId ?? member.id;

    return Row(
      mainAxisSize: MainAxisSize.max,
      children: [
        CircleAvatar(
          radius: 18,
          backgroundImage:
              member.avatarUrl == null ? null : NetworkImage(member.avatarUrl!),
          child: member.avatarUrl == null
              ? Text(member.name.characters.first)
              : null,
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                member.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.w900),
              ),
              Text(
                identifier,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 12, color: Color(0xFF6B7671)),
              ),
              if (member.lineUserId?.isNotEmpty == true &&
                  identifier != member.lineUserId)
                Text(
                  'LINE ID：${member.lineUserId}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style:
                      const TextStyle(fontSize: 12, color: Color(0xFF6B7671)),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _MemberPermissionHeader extends StatelessWidget {
  const _MemberPermissionHeader({required this.member});

  final backend.VeevaMember member;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFA),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE4E8EA)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: _MemberIdentity(member: member),
      ),
    );
  }
}

class _AdminRoleChip extends StatelessWidget {
  const _AdminRoleChip({required this.adminUser});

  final backend.VeevaAdminUser? adminUser;

  @override
  Widget build(BuildContext context) {
    if (adminUser == null) {
      return const Chip(
        label: Text('未授權'),
        backgroundColor: Color(0xFFF1F2F3),
        side: BorderSide.none,
      );
    }
    final active = adminUser!.status == backend.VeevaAdminStatus.active;
    return Chip(
      label: Text(
        active ? _adminRoleLabel(adminUser!.role) : '已停用',
      ),
      backgroundColor:
          active ? const Color(0xFFEAF3EA) : const Color(0xFFFFF4D9),
      side: BorderSide.none,
    );
  }
}

class _AdminPermissionOption {
  const _AdminPermissionOption({
    required this.id,
    required this.label,
    required this.description,
  });

  final String id;
  final String label;
  final String description;
}

const _adminPermissionOptions = [
  _AdminPermissionOption(
    id: 'members',
    label: '會員管理',
    description: '檢視會員、審核會員與授權後台管理者',
  ),
  _AdminPermissionOption(
    id: 'activities',
    label: '活動管理',
    description: '新增、編輯與上下架活動',
  ),
  _AdminPermissionOption(
    id: 'news',
    label: '最新資訊',
    description: '新增、編輯與發布最新資訊',
  ),
  _AdminPermissionOption(
    id: 'rewards',
    label: '兌換券管理',
    description: '管理兌換券、庫存與上下架狀態',
  ),
  _AdminPermissionOption(
    id: 'settings',
    label: '系統設定',
    description: '管理後台權限與系統參數',
  ),
];

List<String> _permissionsForRole(backend.VeevaAdminRole role) {
  return switch (role) {
    backend.VeevaAdminRole.owner => [
        'members',
        'activities',
        'news',
        'rewards',
        'settings',
      ],
    backend.VeevaAdminRole.manager => [
        'members',
        'activities',
        'news',
        'rewards',
      ],
    backend.VeevaAdminRole.editor => ['activities', 'news', 'rewards'],
    backend.VeevaAdminRole.viewer => ['members'],
  };
}

const _memberSettingSelections = [
  _MemberSettingSelection.regular,
  _MemberSettingSelection.owner,
  _MemberSettingSelection.manager,
  _MemberSettingSelection.editor,
  _MemberSettingSelection.viewer,
  _MemberSettingSelection.disabledAccount,
];

_MemberSettingSelection _selectionForMemberSetting(
  backend.VeevaMember member,
  backend.VeevaAdminUser? adminUser,
) {
  if (member.accountStatus == backend.VeevaMemberAccountStatus.disabled) {
    return _MemberSettingSelection.disabledAccount;
  }
  if (adminUser == null ||
      adminUser.status != backend.VeevaAdminStatus.active) {
    return _MemberSettingSelection.regular;
  }
  return switch (adminUser.role) {
    backend.VeevaAdminRole.owner => _MemberSettingSelection.owner,
    backend.VeevaAdminRole.manager => _MemberSettingSelection.manager,
    backend.VeevaAdminRole.editor => _MemberSettingSelection.editor,
    backend.VeevaAdminRole.viewer => _MemberSettingSelection.viewer,
  };
}

backend.VeevaAdminRole? _roleForMemberSettingSelection(
  _MemberSettingSelection selection,
) {
  return switch (selection) {
    _MemberSettingSelection.owner => backend.VeevaAdminRole.owner,
    _MemberSettingSelection.manager => backend.VeevaAdminRole.manager,
    _MemberSettingSelection.editor => backend.VeevaAdminRole.editor,
    _MemberSettingSelection.viewer => backend.VeevaAdminRole.viewer,
    _MemberSettingSelection.regular ||
    _MemberSettingSelection.disabledAccount =>
      null,
  };
}

String _memberSettingSelectionLabel(_MemberSettingSelection selection) {
  return switch (selection) {
    _MemberSettingSelection.regular => '一般會員',
    _MemberSettingSelection.owner => '擁有者',
    _MemberSettingSelection.manager => '管理員',
    _MemberSettingSelection.editor => '編輯者',
    _MemberSettingSelection.viewer => '檢視者',
    _MemberSettingSelection.disabledAccount => '停用帳號',
  };
}

String _permissionLabel(String id) {
  for (final option in _adminPermissionOptions) {
    if (option.id == id) return option.label;
  }
  return id;
}

String _adminRoleLabel(backend.VeevaAdminRole role) {
  return switch (role) {
    backend.VeevaAdminRole.owner => '擁有者',
    backend.VeevaAdminRole.manager => '管理員',
    backend.VeevaAdminRole.editor => '編輯者',
    backend.VeevaAdminRole.viewer => '檢視者',
  };
}

String _adminStatusLabel(backend.VeevaAdminStatus status) {
  return switch (status) {
    backend.VeevaAdminStatus.active => '啟用',
    backend.VeevaAdminStatus.disabled => '停用',
  };
}

backend.VeevaMember _memberWithSettings(
  backend.VeevaMember member, {
  required backend.VeevaMemberAccountStatus accountStatus,
  required bool isAdmin,
  String? adminRole,
}) {
  return backend.VeevaMember(
    id: member.id,
    name: member.name,
    hospital: member.hospital,
    department: member.department,
    status: member.status,
    accountStatus: accountStatus,
    earnedCoupons: member.earnedCoupons,
    invitedCount: member.invitedCount,
    shareCode: member.shareCode,
    lineUserId: member.lineUserId,
    avatarUrl: member.avatarUrl,
    email: member.email,
    lineStatusMessage: member.lineStatusMessage,
    lineIdToken: member.lineIdToken,
    lineIdTokenUpdatedAt: member.lineIdTokenUpdatedAt,
    createdAt: member.createdAt,
    lastLineLoginAt: member.lastLineLoginAt,
    referredByMemberId: member.referredByMemberId,
    referredByShareCode: member.referredByShareCode,
    referredAt: member.referredAt,
    isAdmin: isAdmin,
    adminRole: adminRole,
    updatedAt: member.updatedAt,
  );
}

String _memberStatusLabel(backend.VeevaMemberStatus status) {
  return switch (status) {
    backend.VeevaMemberStatus.guest => '訪客',
    backend.VeevaMemberStatus.loggedIn => '已登入',
    backend.VeevaMemberStatus.pendingReview => '待審核',
    backend.VeevaMemberStatus.verified => '已驗證',
  };
}

String _memberAccountStatusLabel(backend.VeevaMemberAccountStatus status) {
  return switch (status) {
    backend.VeevaMemberAccountStatus.active => '啟用帳號',
    backend.VeevaMemberAccountStatus.disabled => '停用帳號',
  };
}

String _reviewStatusLabel(ReviewStatus status) {
  return switch (status) {
    ReviewStatus.pending => '待審核',
    ReviewStatus.approved => '已審核',
    ReviewStatus.rejected => '已退回',
  };
}

String _normalizeMemberSearch(String value) {
  return value.trim().toLowerCase();
}

bool _memberMatchesSearch(backend.VeevaMember member, String query) {
  if (query.isEmpty) return true;
  return _normalizeMemberSearch([
    member.id,
    member.name,
    member.hospital,
    member.department,
    member.shareCode,
    member.lineUserId,
    member.email,
    member.lineStatusMessage,
    _memberStatusLabel(member.status),
    _memberAccountStatusLabel(member.accountStatus),
    _memberDateTimeLabel(_memberFirstLoginAt(member)),
    _memberDateTimeLabel(member.lastLineLoginAt),
  ].whereType<String>().join(' '))
      .contains(query);
}

bool _reviewMatchesSearch(AdminReviewItem item, String query) {
  if (query.isEmpty) return true;
  return _normalizeMemberSearch([
    item.id,
    item.memberId,
    item.name,
    item.hospital,
    item.department,
    item.completedAt,
    _reviewStatusLabel(item.status),
  ].join(' '))
      .contains(query);
}

int _clampedPage(int page, int totalItems) {
  if (totalItems <= 0) return 0;
  final lastPage = (totalItems - 1) ~/ _MemberManagementState._pageSize;
  if (page < 0) return 0;
  if (page > lastPage) return lastPage;
  return page;
}

List<T> _pageItems<T>(List<T> items, int page, int pageSize) {
  if (items.isEmpty) return const [];
  final start = page * pageSize;
  if (start >= items.length) return const [];
  final rawEnd = start + pageSize;
  final end = rawEnd > items.length ? items.length : rawEnd;
  return items.sublist(start, end);
}

class _MemberStatusTabs extends StatelessWidget {
  const _MemberStatusTabs({
    required this.selectedTab,
    required this.loggedInCount,
    required this.pendingCount,
    required this.approvedCount,
    required this.onChanged,
  });

  final MemberManagementTab selectedTab;
  final int loggedInCount;
  final int pendingCount;
  final int approvedCount;
  final ValueChanged<MemberManagementTab> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: Color(0xFFE4E8EA))),
      ),
      child: Row(
        children: [
          _MemberStatusTab(
            label: '已登入會員',
            count: loggedInCount,
            selected: selectedTab == MemberManagementTab.loggedIn,
            onTap: () => onChanged(MemberManagementTab.loggedIn),
          ),
          _MemberStatusTab(
            label: '待審核',
            count: pendingCount,
            selected: selectedTab == MemberManagementTab.pendingReview,
            onTap: () => onChanged(MemberManagementTab.pendingReview),
          ),
          _MemberStatusTab(
            label: '已審核',
            count: approvedCount,
            selected: selectedTab == MemberManagementTab.approvedReview,
            onTap: () => onChanged(MemberManagementTab.approvedReview),
          ),
        ],
      ),
    );
  }
}

class _MemberStatusTab extends StatelessWidget {
  const _MemberStatusTab({
    required this.label,
    required this.count,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final int count;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = selected ? const Color(0xFF216B57) : const Color(0xFF6B7671);
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(0, 0, 28, 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  label,
                  style: TextStyle(
                    color: color,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: selected
                        ? const Color(0xFFEAF3EA)
                        : const Color(0xFFF1F3F2),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    '$count',
                    style: TextStyle(
                      color: color,
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Container(
              height: 3,
              width: 76,
              decoration: BoxDecoration(
                color: selected ? const Color(0xFF216B57) : Colors.transparent,
                borderRadius: BorderRadius.circular(999),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ActivityManagement extends StatelessWidget {
  const _ActivityManagement({required this.activities});

  final List<backend.VeevaActivity> activities;

  @override
  Widget build(BuildContext context) {
    return _ManagementTable(
      icon: Icons.campaign_outlined,
      title: '活動管理',
      actionLabel: '新增活動',
      columns: const ['活動名稱', '狀態', '活動期間', '備註'],
      rows: [
        for (final activity in activities)
          [
            activity.title,
            activity.active ? '進行中' : _contentStatusLabel(activity.status),
            activity.periodText ?? '未設定',
            activity.note ?? activity.reward,
          ],
      ],
    );
  }
}

class _NewsManagement extends StatelessWidget {
  const _NewsManagement({required this.news});

  final List<backend.VeevaNews> news;

  @override
  Widget build(BuildContext context) {
    return _ManagementTable(
      icon: Icons.newspaper_outlined,
      title: '最新資訊管理',
      actionLabel: '新增資訊',
      columns: const ['標題', '狀態', '發布日期', '分類'],
      rows: [
        for (final item in news)
          [
            item.title,
            _contentStatusLabel(item.status),
            item.date,
            item.category ?? item.source,
          ],
      ],
    );
  }
}

String _contentStatusLabel(backend.VeevaContentStatus status) {
  return switch (status) {
    backend.VeevaContentStatus.draft => '草稿',
    backend.VeevaContentStatus.scheduled => '排程中',
    backend.VeevaContentStatus.published => '已發布',
    backend.VeevaContentStatus.archived => '已封存',
  };
}

class _ManagementTable extends StatelessWidget {
  const _ManagementTable({
    required this.icon,
    required this.title,
    required this.actionLabel,
    required this.columns,
    required this.rows,
  });

  final IconData icon;
  final String title;
  final String actionLabel;
  final List<String> columns;
  final List<List<String>> rows;

  @override
  Widget build(BuildContext context) {
    final isCompact = MediaQuery.sizeOf(context).width < 760;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: const Color(0xFF216B57)),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                FilledButton.icon(
                  onPressed: () {},
                  icon: const Icon(Icons.add),
                  label: Text(actionLabel),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (isCompact)
              Column(
                children: [
                  for (final row in rows)
                    Container(
                      width: double.infinity,
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFA),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: const Color(0xFFE4E8EA)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            row.first,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          const SizedBox(height: 8),
                          for (var index = 1; index < row.length; index++)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 4),
                              child: Text('${columns[index]}：${row[index]}'),
                            ),
                        ],
                      ),
                    ),
                ],
              )
            else
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: DataTable(
                  headingRowColor:
                      WidgetStateProperty.all(const Color(0xFFF5F7F8)),
                  columns: [
                    for (final column in columns)
                      DataColumn(label: Text(column)),
                    const DataColumn(label: Text('操作')),
                  ],
                  rows: [
                    for (final row in rows)
                      DataRow(
                        cells: [
                          for (final cell in row) DataCell(Text(cell)),
                          const DataCell(
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                OutlinedButton(
                                  onPressed: null,
                                  child: Text('編輯'),
                                ),
                                SizedBox(width: 8),
                                FilledButton.tonal(
                                  onPressed: null,
                                  child: Text('預覽'),
                                ),
                              ],
                            ),
                          ),
                        ],
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

class _RewardsManagement extends StatefulWidget {
  const _RewardsManagement({
    required this.rewards,
    required this.onCreate,
    required this.onToggleStatus,
    required this.onAddStock,
  });

  final List<AdminRewardItem> rewards;
  final VoidCallback onCreate;
  final ValueChanged<AdminRewardItem> onToggleStatus;
  final ValueChanged<AdminRewardItem> onAddStock;

  @override
  State<_RewardsManagement> createState() => _RewardsManagementState();
}

class _RewardsManagementState extends State<_RewardsManagement> {
  String query = '';
  RewardStatus? filter;

  @override
  Widget build(BuildContext context) {
    final isCompact = MediaQuery.sizeOf(context).width < 760;
    final visibleRewards = widget.rewards.where((reward) {
      final keyword = query.trim();
      final matchesQuery = keyword.isEmpty ||
          reward.name.contains(keyword) ||
          reward.category.contains(keyword);
      final matchesFilter = filter == null || reward.status == filter;
      return matchesQuery && matchesFilter;
    }).toList();
    final activeCount = widget.rewards
        .where((reward) => reward.status == RewardStatus.active)
        .length;
    final totalStock =
        widget.rewards.fold<int>(0, (total, reward) => total + reward.stock);
    final totalIssued =
        widget.rewards.fold<int>(0, (total, reward) => total + reward.issued);
    final totalRedeemed =
        widget.rewards.fold<int>(0, (total, reward) => total + reward.redeemed);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (isCompact)
          Column(
            children: [
              _MetricCard(
                label: '上架中',
                value: '$activeCount',
                icon: Icons.verified_outlined,
              ),
              const SizedBox(height: 12),
              _MetricCard(
                label: '總庫存',
                value: '$totalStock',
                icon: Icons.inventory_2_outlined,
              ),
              const SizedBox(height: 12),
              _MetricCard(
                label: '已發放',
                value: '$totalIssued',
                icon: Icons.send_outlined,
              ),
              const SizedBox(height: 12),
              _MetricCard(
                label: '已兌換',
                value: '$totalRedeemed',
                icon: Icons.redeem_outlined,
              ),
            ],
          )
        else
          Row(
            children: [
              Expanded(
                child: _MetricCard(
                  label: '上架中',
                  value: '$activeCount',
                  icon: Icons.verified_outlined,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _MetricCard(
                  label: '總庫存',
                  value: '$totalStock',
                  icon: Icons.inventory_2_outlined,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _MetricCard(
                  label: '已發放',
                  value: '$totalIssued',
                  icon: Icons.send_outlined,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _MetricCard(
                  label: '已兌換',
                  value: '$totalRedeemed',
                  icon: Icons.redeem_outlined,
                ),
              ),
            ],
          ),
        const SizedBox(height: 20),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _RewardToolbar(
                  isCompact: isCompact,
                  filter: filter,
                  onQueryChanged: (value) => setState(() => query = value),
                  onFilterChanged: (value) => setState(() => filter = value),
                  onCreate: widget.onCreate,
                ),
                const SizedBox(height: 16),
                if (isCompact)
                  Column(
                    children: [
                      for (final reward in visibleRewards)
                        _RewardMobileCard(
                          reward: reward,
                          onToggleStatus: () => widget.onToggleStatus(reward),
                          onAddStock: () => widget.onAddStock(reward),
                        ),
                    ],
                  )
                else
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: DataTable(
                      columnSpacing: 24,
                      horizontalMargin: 16,
                      headingRowColor:
                          WidgetStateProperty.all(const Color(0xFFF5F7F8)),
                      columns: const [
                        DataColumn(label: Text('兌換券')),
                        DataColumn(label: Text('分類')),
                        DataColumn(label: Text('庫存')),
                        DataColumn(label: Text('發放 / 兌換')),
                        DataColumn(label: Text('期限')),
                        DataColumn(label: Text('狀態')),
                        DataColumn(label: Text('操作')),
                      ],
                      rows: [
                        for (final reward in visibleRewards)
                          DataRow(
                            cells: [
                              DataCell(Text(reward.name)),
                              DataCell(Text(reward.category)),
                              DataCell(Text('${reward.stock}')),
                              DataCell(Text(
                                  '${reward.issued} / ${reward.redeemed}')),
                              DataCell(Text(reward.expiresAt)),
                              DataCell(
                                  _RewardStatusChip(status: reward.status)),
                              DataCell(
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    OutlinedButton(
                                      onPressed: reward.status ==
                                              RewardStatus.expired
                                          ? null
                                          : () => widget.onToggleStatus(reward),
                                      child: Text(
                                        reward.status == RewardStatus.active
                                            ? '停用'
                                            : '啟用',
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    FilledButton.tonal(
                                      onPressed: () =>
                                          widget.onAddStock(reward),
                                      child: const Text('補庫存'),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _RewardToolbar extends StatelessWidget {
  const _RewardToolbar({
    required this.isCompact,
    required this.filter,
    required this.onQueryChanged,
    required this.onFilterChanged,
    required this.onCreate,
  });

  final bool isCompact;
  final RewardStatus? filter;
  final ValueChanged<String> onQueryChanged;
  final ValueChanged<RewardStatus?> onFilterChanged;
  final VoidCallback onCreate;

  @override
  Widget build(BuildContext context) {
    const title = Text(
      '兌換券列表',
      style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
    );
    final search = SizedBox(
      width: isCompact ? double.infinity : 260,
      child: TextField(
        onChanged: onQueryChanged,
        decoration: InputDecoration(
          hintText: '搜尋商品或分類',
          prefixIcon: const Icon(Icons.search),
          isDense: true,
          filled: true,
          fillColor: const Color(0xFFF5F7F8),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide.none,
          ),
        ),
      ),
    );
    final filterMenu = DropdownButtonFormField<RewardStatus?>(
      value: filter,
      decoration: InputDecoration(
        isDense: true,
        filled: true,
        fillColor: const Color(0xFFF5F7F8),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide.none,
        ),
      ),
      items: const [
        DropdownMenuItem(value: null, child: Text('全部狀態')),
        DropdownMenuItem(value: RewardStatus.active, child: Text('上架中')),
        DropdownMenuItem(value: RewardStatus.paused, child: Text('已停用')),
        DropdownMenuItem(value: RewardStatus.expired, child: Text('已過期')),
      ],
      onChanged: onFilterChanged,
    );

    if (isCompact) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(child: title),
              IconButton.filled(
                onPressed: onCreate,
                icon: const Icon(Icons.add),
                tooltip: '新增兌換券',
              ),
            ],
          ),
          const SizedBox(height: 12),
          search,
          const SizedBox(height: 12),
          filterMenu,
        ],
      );
    }

    return Row(
      children: [
        const Expanded(child: title),
        search,
        const SizedBox(width: 12),
        SizedBox(width: 160, child: filterMenu),
        const SizedBox(width: 12),
        FilledButton.icon(
          onPressed: onCreate,
          icon: const Icon(Icons.add),
          label: const Text('新增兌換券'),
        ),
      ],
    );
  }
}

class _RewardMobileCard extends StatelessWidget {
  const _RewardMobileCard({
    required this.reward,
    required this.onToggleStatus,
    required this.onAddStock,
  });

  final AdminRewardItem reward;
  final VoidCallback onToggleStatus;
  final VoidCallback onAddStock;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFA),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE4E8EA)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  reward.name,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              _RewardStatusChip(status: reward.status),
            ],
          ),
          const SizedBox(height: 8),
          Text('${reward.category} · 期限 ${reward.expiresAt}'),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _MiniInfo(label: '庫存', value: '${reward.stock}'),
              _MiniInfo(label: '已發放', value: '${reward.issued}'),
              _MiniInfo(label: '已兌換', value: '${reward.redeemed}'),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              OutlinedButton(
                onPressed: reward.status == RewardStatus.expired
                    ? null
                    : onToggleStatus,
                child: Text(
                  reward.status == RewardStatus.active ? '停用' : '啟用',
                ),
              ),
              const SizedBox(width: 8),
              FilledButton.tonal(
                onPressed: onAddStock,
                child: const Text('補庫存'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MiniInfo extends StatelessWidget {
  const _MiniInfo({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE4E8EA)),
      ),
      child: Text('$label $value'),
    );
  }
}

class _RewardStatusChip extends StatelessWidget {
  const _RewardStatusChip({required this.status});

  final RewardStatus status;

  @override
  Widget build(BuildContext context) {
    final label = switch (status) {
      RewardStatus.active => '上架中',
      RewardStatus.paused => '已停用',
      RewardStatus.expired => '已過期',
    };
    final color = switch (status) {
      RewardStatus.active => const Color(0xFFEAF3EA),
      RewardStatus.paused => const Color(0xFFFFF4D9),
      RewardStatus.expired => const Color(0xFFF1F2F3),
    };

    return Chip(
      label: Text(label),
      backgroundColor: color,
      side: BorderSide.none,
    );
  }
}

class _PlaceholderPanel extends StatelessWidget {
  const _PlaceholderPanel({
    required this.icon,
    required this.title,
    required this.description,
  });

  final IconData icon;
  final String title;
  final String description;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Row(
          children: [
            Icon(icon, size: 48, color: const Color(0xFF216B57)),
            const SizedBox(width: 18),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: const TextStyle(
                          fontSize: 22, fontWeight: FontWeight.w900)),
                  const SizedBox(height: 8),
                  Text(description),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
