import 'package:flutter/material.dart';

import 'data/firebase_bootstrap.dart';
import 'data/veeva_models.dart' as backend;
import 'data/veeva_repository.dart';
import 'services/admin_line_auth_base.dart';
import 'services/admin_line_auth_stub.dart'
    if (dart.library.html) 'services/admin_line_auth_web.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final repository = await createVeevaRepository();
  runApp(VeevaAdminApp(repository: repository));
}

class VeevaAdminApp extends StatelessWidget {
  const VeevaAdminApp({
    this.repository,
    this.authService,
    this.requireLineLogin = true,
    super.key,
  });

  final VeevaRepository? repository;
  final AdminLineAuthService? authService;
  final bool requireLineLogin;

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
      home: requireLineLogin
          ? AdminAuthGate(
              initialTab: _initialAdminTabFromUri(),
              repository: repository ?? DemoVeevaRepository(),
              authService: authService ??
                  createAdminLineAuthService(
                    config: AdminLineConfig.fromEnvironment(),
                  ),
            )
          : AdminDashboardShell(
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

enum _RewardExpiryMode { unlimited, limited }

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
    this.imageUrl,
  });

  factory AdminRewardItem.fromBackend(backend.VeevaReward reward) {
    return AdminRewardItem(
      id: reward.id,
      name: reward.name,
      category: reward.category,
      stock: reward.stock,
      issued: reward.issued,
      redeemed: reward.redeemed,
      expiresAt: _formatRewardExpiry(reward.expiresAt),
      status: switch (reward.status) {
        backend.VeevaRewardStatus.active => RewardStatus.active,
        backend.VeevaRewardStatus.paused => RewardStatus.paused,
        backend.VeevaRewardStatus.expired => RewardStatus.expired,
      },
      imageUrl: reward.imageUrl,
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
  final String? imageUrl;

  AdminRewardItem copyWith({
    String? name,
    String? category,
    int? stock,
    int? issued,
    int? redeemed,
    String? expiresAt,
    RewardStatus? status,
    Object? imageUrl = _unchangedRewardImageUrl,
  }) {
    return AdminRewardItem(
      id: id,
      name: name ?? this.name,
      category: category ?? this.category,
      stock: stock ?? this.stock,
      issued: issued ?? this.issued,
      redeemed: redeemed ?? this.redeemed,
      expiresAt: expiresAt ?? this.expiresAt,
      status: status ?? this.status,
      imageUrl: identical(imageUrl, _unchangedRewardImageUrl)
          ? this.imageUrl
          : imageUrl as String?,
    );
  }

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
      imageUrl: imageUrl,
    );
  }
}

const _unchangedRewardImageUrl = Object();
const _rewardUnlimitedExpiryLabel = '不限時';
const _rewardUnlimitedExpiryYear = 9999;
const _rewardCategoryOptions = [
  '禮券',
  '餐飲',
  '飲品',
  '折抵',
  '實體贈品',
  '點數',
  '其他',
];

String _formatAdminDate(DateTime date) {
  return '${date.year}/${date.month.toString().padLeft(2, '0')}/${date.day.toString().padLeft(2, '0')}';
}

String _formatRewardExpiry(DateTime date) {
  if (_isUnlimitedRewardExpiryDate(date)) {
    return _rewardUnlimitedExpiryLabel;
  }
  return _formatAdminDate(date);
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
  if (_isUnlimitedRewardExpiryText(value)) {
    return DateTime(_rewardUnlimitedExpiryYear, 12, 31);
  }
  final normalized = value.trim().replaceAll('/', '-');
  return DateTime.tryParse(normalized) ?? DateTime(2026, 12, 31);
}

bool _isValidAdminDate(String value) {
  return DateTime.tryParse(value.trim().replaceAll('/', '-')) != null;
}

bool _isUnlimitedRewardExpiryText(String value) {
  final normalized = value.trim();
  return normalized == _rewardUnlimitedExpiryLabel ||
      normalized == '9999/12/31' ||
      normalized == '9999-12-31';
}

bool _isUnlimitedRewardExpiryDate(DateTime date) {
  return date.year >= _rewardUnlimitedExpiryYear;
}

enum _AdminAuthViewState {
  checking,
  signedOut,
  redirecting,
  unauthorized,
  disabled,
  error,
}

class AdminAuthGate extends StatefulWidget {
  const AdminAuthGate({
    required this.initialTab,
    required this.repository,
    required this.authService,
    super.key,
  });

  final AdminTab initialTab;
  final VeevaRepository repository;
  final AdminLineAuthService authService;

  @override
  State<AdminAuthGate> createState() => _AdminAuthGateState();
}

class _AdminAuthGateState extends State<AdminAuthGate> {
  _AdminAuthViewState viewState = _AdminAuthViewState.checking;
  AdminLineSession session = AdminLineSession.initial();
  backend.VeevaAdminUser? adminUser;
  String? message;

  @override
  void initState() {
    super.initState();
    _checkExistingSession();
  }

  Future<void> _checkExistingSession() async {
    setState(() {
      viewState = _AdminAuthViewState.checking;
      message = null;
    });
    await _handleSession(await widget.authService.initialize());
  }

  Future<void> _loginWithLine() async {
    setState(() {
      viewState = _AdminAuthViewState.checking;
      message = null;
    });
    await _handleSession(await widget.authService.login());
  }

  Future<void> _logout() async {
    setState(() {
      viewState = _AdminAuthViewState.checking;
      adminUser = null;
      message = null;
    });
    await widget.authService.logout();
    if (!mounted) return;
    setState(() {
      session = AdminLineSession.initial();
      viewState = _AdminAuthViewState.signedOut;
    });
  }

  Future<void> _handleSession(AdminLineSession nextSession) async {
    if (!mounted) return;
    session = nextSession;

    if (nextSession.isRedirecting) {
      setState(() {
        viewState = _AdminAuthViewState.redirecting;
        message = '正在前往 LINE 登入頁面。';
      });
      return;
    }

    if (nextSession.hasError) {
      setState(() {
        viewState = _AdminAuthViewState.error;
        message = nextSession.errorMessage;
      });
      return;
    }

    if (!nextSession.isLoggedIn) {
      setState(() {
        viewState = _AdminAuthViewState.signedOut;
        message = null;
      });
      return;
    }

    final profile = nextSession.profile;
    if (profile == null || profile.userId.trim().isEmpty) {
      setState(() {
        viewState = _AdminAuthViewState.error;
        message = '無法取得 LINE 帳號資料，請重新登入。';
      });
      return;
    }

    try {
      final activeAdmin = await widget.repository
          .loadActiveAdminUserByLineUserId(profile.userId);
      if (!mounted) return;
      if (activeAdmin == null) {
        setState(() {
          viewState = _AdminAuthViewState.unauthorized;
          message = '這個 LINE 帳號尚未啟用後台管理權限。';
        });
        return;
      }

      final member = await widget.repository.loadMember(activeAdmin.memberId);
      if (!mounted) return;
      if (member?.accountStatus == backend.VeevaMemberAccountStatus.disabled) {
        setState(() {
          viewState = _AdminAuthViewState.disabled;
          message = '這個 LINE 帳號目前已停用，無法進入後台。';
        });
        return;
      }

      setState(() {
        adminUser = activeAdmin;
        viewState = _AdminAuthViewState.checking;
        message = null;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        viewState = _AdminAuthViewState.error;
        message = '後台權限檢查失敗，請確認 Firestore 已可讀取管理者資料。';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final activeAdmin = adminUser;
    if (activeAdmin != null) {
      return AdminDashboardShell(
        initialTab: widget.initialTab,
        repository: widget.repository,
        currentAdmin: activeAdmin,
        onLogout: _logout,
      );
    }

    return _AdminAuthScreen(
      state: viewState,
      session: session,
      message: message,
      onLogin: _loginWithLine,
      onRetry: _checkExistingSession,
      onLogout: _logout,
    );
  }
}

class _AdminAuthScreen extends StatelessWidget {
  const _AdminAuthScreen({
    required this.state,
    required this.session,
    required this.message,
    required this.onLogin,
    required this.onRetry,
    required this.onLogout,
  });

  final _AdminAuthViewState state;
  final AdminLineSession session;
  final String? message;
  final VoidCallback onLogin;
  final VoidCallback onRetry;
  final VoidCallback onLogout;

  @override
  Widget build(BuildContext context) {
    final isBusy = state == _AdminAuthViewState.checking ||
        state == _AdminAuthViewState.redirecting;
    final profile = session.profile;
    final title = switch (state) {
      _AdminAuthViewState.checking => '正在檢查登入狀態',
      _AdminAuthViewState.redirecting => '正在開啟 LINE 登入',
      _AdminAuthViewState.signedOut => 'VeeVa Admin 後台登入',
      _AdminAuthViewState.unauthorized => '尚未開通後台權限',
      _AdminAuthViewState.disabled => '帳號已停用',
      _AdminAuthViewState.error => '登入檢查失敗',
    };
    final description = message ??
        switch (state) {
          _AdminAuthViewState.checking => '請稍候，正在確認 LINE 登入與後台權限。',
          _AdminAuthViewState.redirecting => '請在 LINE 登入頁完成授權。',
          _AdminAuthViewState.signedOut => '請使用已授權的 LINE 帳號登入後台。',
          _AdminAuthViewState.unauthorized => '請先由既有管理者在權限管理頁面開通此會員。',
          _AdminAuthViewState.disabled => '請聯絡管理者重新啟用帳號。',
          _AdminAuthViewState.error => '請稍後重試，或確認 Admin LIFF 設定是否正確。',
        };

    return Scaffold(
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 440),
          child: Card(
            margin: const EdgeInsets.all(20),
            child: Padding(
              padding: const EdgeInsets.all(28),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Container(
                    width: 52,
                    height: 52,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: const Color(0xFFE8F5EF),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      Icons.admin_panel_settings_outlined,
                      color: Color(0xFF216B57),
                      size: 28,
                    ),
                  ),
                  const SizedBox(height: 18),
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    description,
                    style: const TextStyle(
                      color: Color(0xFF61706A),
                      fontWeight: FontWeight.w600,
                      height: 1.5,
                    ),
                  ),
                  if (profile != null) ...[
                    const SizedBox(height: 16),
                    _AdminAuthProfile(profile: profile),
                  ],
                  const SizedBox(height: 22),
                  if (isBusy)
                    const Center(child: CircularProgressIndicator())
                  else if (state == _AdminAuthViewState.signedOut)
                    FilledButton.icon(
                      onPressed: onLogin,
                      icon: const Icon(Icons.login),
                      label: const Text('使用 LINE 登入'),
                    )
                  else
                    Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: [
                        FilledButton.icon(
                          onPressed: onRetry,
                          icon: const Icon(Icons.refresh),
                          label: const Text('重新檢查'),
                        ),
                        if (session.isLoggedIn)
                          OutlinedButton.icon(
                            onPressed: onLogout,
                            icon: const Icon(Icons.logout),
                            label: const Text('登出 LINE'),
                          )
                        else
                          OutlinedButton.icon(
                            onPressed: onLogin,
                            icon: const Icon(Icons.login),
                            label: const Text('使用 LINE 登入'),
                          ),
                      ],
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _AdminAuthProfile extends StatelessWidget {
  const _AdminAuthProfile({required this.profile});

  final AdminLineProfile profile;

  @override
  Widget build(BuildContext context) {
    final displayName =
        profile.displayName.trim().isEmpty ? 'LINE 會員' : profile.displayName;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0xFFF5F7F8),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE4E8EA)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            CircleAvatar(
              backgroundImage: profile.pictureUrl == null
                  ? null
                  : NetworkImage(profile.pictureUrl!),
              child: profile.pictureUrl == null
                  ? Text(displayName.characters.first)
                  : null,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    displayName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w900),
                  ),
                  Text(
                    profile.email?.isNotEmpty == true
                        ? profile.email!
                        : 'LINE ID：${profile.userId}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Color(0xFF61706A),
                      fontSize: 12,
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

class AdminDashboardShell extends StatefulWidget {
  const AdminDashboardShell({
    super.key,
    this.initialTab = AdminTab.dashboard,
    this.repository,
    this.currentAdmin,
    this.onLogout,
  });

  final AdminTab initialTab;
  final VeevaRepository? repository;
  final backend.VeevaAdminUser? currentAdmin;
  final Future<void> Function()? onLogout;

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
          activities = [...bootstrap.activities];
        }
        if (bootstrap.news.isNotEmpty) {
          news = [...bootstrap.news];
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
            adminUser: widget.currentAdmin,
            onLogout: widget.onLogout,
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
          actions: [
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: _AdminAccountMenu(
                adminUser: widget.currentAdmin,
                onLogout: widget.onLogout,
              ),
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
      AdminTab.activities => _ActivityManagement(
          activities: activities,
          onCreate: () => _showActivityDialog(),
          onEdit: (activity) => _showActivityDialog(activity: activity),
          onToggleActive: _toggleActivityActive,
          onArchive: _archiveActivity,
        ),
      AdminTab.news => _NewsManagement(news: news),
      AdminTab.rewards => _RewardsManagement(
          rewards: rewards,
          onCreate: () => _showRewardDialog(),
          onEdit: (reward) => _showRewardDialog(reward: reward),
          onPreview: _showRewardPreview,
          onToggleStatus: _toggleRewardStatus,
          onAdjustStock: _showRewardStockDialog,
          onExpire: _expireReward,
          onDelete: _deleteReward,
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

  Future<void> _saveActivity(backend.VeevaActivity activity) async {
    final index = activities.indexWhere((item) => item.id == activity.id);
    final previous = index == -1 ? null : activities[index];
    setState(() {
      backendError = null;
      if (index == -1) {
        activities.insert(0, activity);
      } else {
        activities[index] = activity;
      }
    });
    try {
      await repository.saveActivity(activity);
    } catch (_) {
      if (!mounted) return;
      setState(() {
        if (previous == null) {
          activities.removeWhere((item) => item.id == activity.id);
        } else if (index != -1) {
          activities[index] = previous;
        }
        backendError = '活動資料儲存失敗：請確認 Firestore API 與 rules 已啟用。';
      });
    }
  }

  Future<void> _toggleActivityActive(backend.VeevaActivity activity) async {
    final updated = backend.VeevaActivity(
      id: activity.id,
      type: activity.type,
      label: activity.label,
      title: activity.title,
      description: activity.description,
      reward: activity.reward,
      status: activity.active
          ? backend.VeevaContentStatus.archived
          : backend.VeevaContentStatus.published,
      active: !activity.active,
      periodText: activity.periodText,
      note: activity.note,
      imageUrl: activity.imageUrl,
      surveyUrl: activity.surveyUrl,
    );
    await _saveActivity(updated);
  }

  Future<void> _archiveActivity(backend.VeevaActivity activity) async {
    final updated = backend.VeevaActivity(
      id: activity.id,
      type: activity.type,
      label: activity.label,
      title: activity.title,
      description: activity.description,
      reward: activity.reward,
      status: backend.VeevaContentStatus.archived,
      active: false,
      periodText: activity.periodText,
      note: activity.note,
      imageUrl: activity.imageUrl,
      surveyUrl: activity.surveyUrl,
    );
    await _saveActivity(updated);
  }

  Future<void> _showActivityDialog({backend.VeevaActivity? activity}) async {
    final isEditing = activity != null;
    const noRewardValue = '__no_reward__';
    final labelController =
        TextEditingController(text: activity?.label ?? '限時活動');
    final titleController = TextEditingController(text: activity?.title ?? '');
    final descriptionController =
        TextEditingController(text: activity?.description ?? '');
    final rewardController =
        TextEditingController(text: activity?.reward ?? '咖啡券');
    final rewardOptions = rewards
        .where((reward) => reward.status != RewardStatus.expired)
        .toList();
    var selectedRewardId = activity?.rewardId;
    if (selectedRewardId == null && !isEditing && rewardOptions.isNotEmpty) {
      selectedRewardId = rewardOptions.first.id;
      rewardController.text = rewardOptions.first.name;
    }
    final periodController =
        TextEditingController(text: activity?.periodText ?? '');
    final noteController = TextEditingController(text: activity?.note ?? '');
    final imageController =
        TextEditingController(text: activity?.imageUrl ?? '');
    final surveyUrlController = TextEditingController(
        text: activity?.surveyUrl ?? defaultVeevaSurveyUrl);
    var activityType = activity?.type ?? backend.VeevaActivityType.survey;
    var status = activity?.status ?? backend.VeevaContentStatus.published;
    var active = activity?.active ?? true;
    String? formError;
    backend.VeevaActivity? pendingActivity;

    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: Text(isEditing ? '編輯活動' : '新增活動'),
              content: SizedBox(
                width: 560,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (formError != null) ...[
                        _InlineError(message: formError!),
                        const SizedBox(height: 12),
                      ],
                      DropdownButtonFormField<backend.VeevaActivityType>(
                        value: activityType,
                        decoration: const InputDecoration(
                          labelText: '活動類型',
                          prefixIcon: Icon(Icons.category_outlined),
                        ),
                        items: [
                          for (final type in backend.VeevaActivityType.values)
                            DropdownMenuItem(
                              value: type,
                              child: Text(_activityTypeLabel(type)),
                            ),
                        ],
                        onChanged: (value) {
                          if (value == null) return;
                          setDialogState(() {
                            activityType = value;
                            if (value ==
                                    backend.VeevaActivityType.registration &&
                                rewardController.text.trim() == '咖啡券') {
                              rewardController.text = '活動報名';
                            }
                            if (value ==
                                backend.VeevaActivityType.registration) {
                              selectedRewardId = null;
                            } else if (selectedRewardId == null &&
                                rewardOptions.isNotEmpty) {
                              selectedRewardId = rewardOptions.first.id;
                              rewardController.text = rewardOptions.first.name;
                              if (surveyUrlController.text.trim().isEmpty) {
                                surveyUrlController.text =
                                    defaultVeevaSurveyUrl;
                              }
                            }
                          });
                        },
                      ),
                      const SizedBox(height: 12),
                      if (activityType == backend.VeevaActivityType.survey) ...[
                        TextField(
                          controller: surveyUrlController,
                          keyboardType: TextInputType.url,
                          decoration: const InputDecoration(
                            labelText: '問卷網址',
                            prefixIcon: Icon(Icons.link_outlined),
                          ),
                        ),
                        const SizedBox(height: 12),
                      ],
                      TextField(
                        controller: titleController,
                        decoration: const InputDecoration(
                          labelText: '活動名稱',
                          prefixIcon: Icon(Icons.campaign_outlined),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: labelController,
                        decoration: const InputDecoration(
                          labelText: '活動標籤',
                          prefixIcon: Icon(Icons.label_outline),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: descriptionController,
                        minLines: 3,
                        maxLines: 5,
                        decoration: const InputDecoration(
                          labelText: '活動說明',
                          alignLabelWithHint: true,
                          prefixIcon: Icon(Icons.notes_outlined),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: rewardController,
                              decoration: const InputDecoration(
                                labelText: '獎勵內容',
                                prefixIcon: Icon(Icons.redeem_outlined),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: TextField(
                              controller: periodController,
                              decoration: const InputDecoration(
                                labelText: '活動期間',
                                prefixIcon: Icon(Icons.date_range_outlined),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        value: selectedRewardId != null &&
                                rewardOptions.any(
                                  (reward) => reward.id == selectedRewardId,
                                )
                            ? selectedRewardId
                            : noRewardValue,
                        decoration: const InputDecoration(
                          labelText: '完成後發放兌換券',
                          prefixIcon: Icon(Icons.confirmation_number_outlined),
                        ),
                        items: [
                          DropdownMenuItem(
                            value: noRewardValue,
                            child: Text(
                              activityType == backend.VeevaActivityType.survey
                                  ? '請選擇兌換券'
                                  : '不發放兌換券',
                            ),
                          ),
                          for (final reward in rewardOptions)
                            DropdownMenuItem(
                              value: reward.id,
                              child: Text('${reward.name}（${reward.category}）'),
                            ),
                        ],
                        onChanged: (value) {
                          if (value == null) return;
                          if (value == noRewardValue) {
                            setDialogState(() {
                              selectedRewardId = null;
                            });
                            return;
                          }
                          final selectedReward = rewardOptions.firstWhere(
                            (reward) => reward.id == value,
                          );
                          setDialogState(() {
                            selectedRewardId = value;
                            rewardController.text = selectedReward.name;
                          });
                        },
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: noteController,
                        decoration: const InputDecoration(
                          labelText: '備註',
                          prefixIcon: Icon(Icons.sticky_note_2_outlined),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: imageController,
                        decoration: const InputDecoration(
                          labelText: '圖片網址',
                          prefixIcon: Icon(Icons.image_outlined),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: DropdownButtonFormField<
                                backend.VeevaContentStatus>(
                              value: status,
                              decoration: const InputDecoration(
                                labelText: '發布狀態',
                                prefixIcon: Icon(Icons.flag_outlined),
                              ),
                              items: [
                                for (final item
                                    in backend.VeevaContentStatus.values)
                                  DropdownMenuItem(
                                    value: item,
                                    child: Text(_contentStatusLabel(item)),
                                  ),
                              ],
                              onChanged: (value) {
                                if (value == null) return;
                                setDialogState(() {
                                  status = value;
                                  if (value ==
                                      backend.VeevaContentStatus.archived) {
                                    active = false;
                                  }
                                });
                              },
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: SwitchListTile(
                              value: active,
                              contentPadding: EdgeInsets.zero,
                              title: const Text('前台顯示'),
                              subtitle: const Text('啟用後活動會出現在會員端'),
                              onChanged: (value) {
                                setDialogState(() {
                                  active = value;
                                  if (value) {
                                    status =
                                        backend.VeevaContentStatus.published;
                                  }
                                });
                              },
                            ),
                          ),
                        ],
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
                  onPressed: () async {
                    final title = titleController.text.trim();
                    final description = descriptionController.text.trim();
                    final reward = _fallbackText(
                      rewardController.text,
                      activityType == backend.VeevaActivityType.registration
                          ? '活動報名'
                          : '兌換券',
                    );
                    if (title.isEmpty || description.isEmpty) {
                      setDialogState(() {
                        formError = '請至少填寫活動名稱與活動說明。';
                      });
                      return;
                    }
                    if (activityType == backend.VeevaActivityType.survey &&
                        (selectedRewardId == null ||
                            selectedRewardId!.isEmpty ||
                            !rewardOptions.any(
                                (reward) => reward.id == selectedRewardId))) {
                      setDialogState(() {
                        formError = '問卷活動需要選擇完成後要發放的兌換券。';
                      });
                      return;
                    }
                    final surveyUrl = _optionalText(surveyUrlController.text);
                    if (activityType == backend.VeevaActivityType.survey &&
                        !_isHttpUrl(surveyUrl)) {
                      setDialogState(() {
                        formError = '請填入正確的問卷網址。';
                      });
                      return;
                    }

                    pendingActivity = backend.VeevaActivity(
                      id: activity?.id ?? createVeevaId('activity'),
                      type: activityType,
                      label: _fallbackText(labelController.text, '活動'),
                      title: title,
                      description: description,
                      reward: reward,
                      rewardId: selectedRewardId,
                      status: active
                          ? backend.VeevaContentStatus.published
                          : status,
                      active: active,
                      periodText: _optionalText(periodController.text),
                      note: _optionalText(noteController.text),
                      imageUrl: _optionalText(imageController.text),
                      surveyUrl:
                          activityType == backend.VeevaActivityType.survey
                              ? surveyUrl
                              : null,
                    );
                    Navigator.of(dialogContext).pop();
                  },
                  icon: Icon(isEditing ? Icons.save_outlined : Icons.add),
                  label: Text(isEditing ? '儲存' : '建立'),
                ),
              ],
            );
          },
        );
      },
    );

    final activityToSave = pendingActivity;
    if (activityToSave != null) {
      await _saveActivity(activityToSave);
    }

    await Future<void>.delayed(const Duration(milliseconds: 250));
    labelController.dispose();
    titleController.dispose();
    descriptionController.dispose();
    rewardController.dispose();
    periodController.dispose();
    noteController.dispose();
    imageController.dispose();
    surveyUrlController.dispose();
  }

  Future<void> _saveReward(
    AdminRewardItem reward, {
    String errorMessage = '兌換券資料儲存失敗：請確認 Firestore API 與 rules 已啟用。',
  }) async {
    final index = rewards.indexWhere((item) => item.id == reward.id);
    final previous = index == -1 ? null : rewards[index];
    setState(() {
      backendError = null;
      if (index == -1) {
        rewards.insert(0, reward);
      } else {
        rewards[index] = reward;
      }
    });
    try {
      await repository.saveReward(reward.toBackend());
    } catch (_) {
      if (!mounted) return;
      setState(() {
        if (previous == null) {
          rewards.removeWhere((item) => item.id == reward.id);
        } else if (index != -1) {
          rewards[index] = previous;
        }
        backendError = errorMessage;
      });
    }
  }

  Future<void> _toggleRewardStatus(AdminRewardItem reward) async {
    if (reward.status == RewardStatus.expired) return;
    final nextStatus = reward.status == RewardStatus.active
        ? RewardStatus.paused
        : RewardStatus.active;
    await _saveReward(
      reward.copyWith(status: nextStatus),
      errorMessage: '兌換券狀態更新失敗：請確認 Firestore API 與 rules 已啟用。',
    );
  }

  Future<void> _expireReward(AdminRewardItem reward) async {
    if (reward.status == RewardStatus.expired) return;
    final confirmed = await showDialog<bool>(
          context: context,
          builder: (dialogContext) {
            return AlertDialog(
              title: const Text('設為已過期'),
              content: Text('確定要將「${reward.name}」設為已過期嗎？已發放與已兌換數量會保留。'),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(false),
                  child: const Text('取消'),
                ),
                FilledButton.icon(
                  onPressed: () => Navigator.of(dialogContext).pop(true),
                  icon: const Icon(Icons.event_busy_outlined),
                  label: const Text('設為已過期'),
                ),
              ],
            );
          },
        ) ??
        false;
    if (!confirmed) return;

    await _saveReward(
      reward.copyWith(status: RewardStatus.expired),
      errorMessage: '兌換券過期狀態更新失敗：請確認 Firestore API 與 rules 已啟用。',
    );
  }

  Future<void> _deleteReward(AdminRewardItem reward) async {
    final confirmed = await showDialog<bool>(
          context: context,
          builder: (dialogContext) {
            return AlertDialog(
              title: const Text('刪除兌換券'),
              content: Text('確定要刪除「${reward.name}」嗎？刪除後會從兌換券清單移除。'),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(false),
                  child: const Text('取消'),
                ),
                FilledButton.icon(
                  onPressed: () => Navigator.of(dialogContext).pop(true),
                  icon: const Icon(Icons.delete_outline),
                  label: const Text('刪除'),
                ),
              ],
            );
          },
        ) ??
        false;
    if (!confirmed) return;

    final index = rewards.indexWhere((item) => item.id == reward.id);
    if (index == -1) return;
    final previous = rewards[index];
    setState(() {
      backendError = null;
      rewards.removeAt(index);
    });

    try {
      await repository.deleteReward(reward.id);
    } catch (_) {
      if (!mounted) return;
      final insertIndex = index <= rewards.length ? index : rewards.length;
      setState(() {
        rewards.insert(insertIndex, previous);
        backendError = '兌換券刪除失敗：請確認 Firestore API 與 rules 已啟用。';
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

  Future<void> _showRewardDialog({AdminRewardItem? reward}) async {
    final isEditing = reward != null;
    final nameController = TextEditingController(text: reward?.name ?? '');
    final categoryOptions = [..._rewardCategoryOptions];
    final existingCategory = reward?.category.trim();
    if (existingCategory != null &&
        existingCategory.isNotEmpty &&
        !categoryOptions.contains(existingCategory)) {
      categoryOptions.insert(0, existingCategory);
    }
    var category = existingCategory?.isNotEmpty == true
        ? existingCategory!
        : _rewardCategoryOptions.first;
    final stockController =
        TextEditingController(text: '${reward?.stock ?? 50}');
    final hasLimitedExpiry =
        reward != null && !_isUnlimitedRewardExpiryText(reward.expiresAt);
    var expiryMode = hasLimitedExpiry
        ? _RewardExpiryMode.limited
        : _RewardExpiryMode.unlimited;
    final expiryController = TextEditingController(
        text: hasLimitedExpiry
            ? reward.expiresAt
            : _formatAdminDate(DateTime.now().add(const Duration(days: 90))));
    final imageController = TextEditingController(text: reward?.imageUrl ?? '');
    var status = reward?.status ?? RewardStatus.active;
    String? formError;
    AdminRewardItem? pendingReward;

    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            Future<void> pickExpiryDate() async {
              final initialDate = _parseAdminDate(expiryController.text);
              final picked = await showDatePicker(
                context: dialogContext,
                initialDate: initialDate.year >= _rewardUnlimitedExpiryYear
                    ? DateTime.now()
                    : initialDate,
                firstDate: DateTime(2020),
                lastDate: DateTime(_rewardUnlimitedExpiryYear - 1, 12, 31),
              );
              if (picked == null) return;
              setDialogState(() {
                expiryController.text = _formatAdminDate(picked);
              });
            }

            return AlertDialog(
              title: Text(isEditing ? '編輯兌換券' : '新增兌換券'),
              content: SizedBox(
                width: 560,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (formError != null) ...[
                        _InlineError(message: formError!),
                        const SizedBox(height: 12),
                      ],
                      TextField(
                        controller: nameController,
                        decoration: const InputDecoration(
                          labelText: '商品名稱',
                          prefixIcon: Icon(Icons.card_giftcard_outlined),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: DropdownButtonFormField<String>(
                              value: category,
                              decoration: const InputDecoration(
                                labelText: '分類',
                                prefixIcon: Icon(Icons.category_outlined),
                              ),
                              items: [
                                for (final option in categoryOptions)
                                  DropdownMenuItem(
                                    value: option,
                                    child: Text(option),
                                  ),
                              ],
                              onChanged: (value) {
                                if (value == null) return;
                                setDialogState(() => category = value);
                              },
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: DropdownButtonFormField<RewardStatus>(
                              value: status,
                              decoration: const InputDecoration(
                                labelText: '狀態',
                                prefixIcon:
                                    Icon(Icons.check_circle_outline_outlined),
                              ),
                              items: const [
                                DropdownMenuItem(
                                  value: RewardStatus.active,
                                  child: Text('上架中'),
                                ),
                                DropdownMenuItem(
                                  value: RewardStatus.paused,
                                  child: Text('已停用'),
                                ),
                                DropdownMenuItem(
                                  value: RewardStatus.expired,
                                  child: Text('已過期'),
                                ),
                              ],
                              onChanged: (value) {
                                if (value == null) return;
                                setDialogState(() => status = value);
                              },
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: stockController,
                              keyboardType: TextInputType.number,
                              decoration: const InputDecoration(
                                labelText: '可用庫存',
                                prefixIcon: Icon(Icons.inventory_2_outlined),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<_RewardExpiryMode>(
                        value: expiryMode,
                        decoration: const InputDecoration(
                          labelText: '兌換期限類型',
                          prefixIcon: Icon(Icons.schedule_outlined),
                        ),
                        items: const [
                          DropdownMenuItem(
                            value: _RewardExpiryMode.unlimited,
                            child: Text(_rewardUnlimitedExpiryLabel),
                          ),
                          DropdownMenuItem(
                            value: _RewardExpiryMode.limited,
                            child: Text('限時'),
                          ),
                        ],
                        onChanged: (value) {
                          if (value == null) return;
                          setDialogState(() => expiryMode = value);
                        },
                      ),
                      if (expiryMode == _RewardExpiryMode.limited) ...[
                        const SizedBox(height: 12),
                        TextField(
                          controller: expiryController,
                          readOnly: true,
                          onTap: pickExpiryDate,
                          decoration: InputDecoration(
                            labelText: '兌換日期',
                            hintText: 'YYYY/MM/DD',
                            prefixIcon:
                                const Icon(Icons.event_available_outlined),
                            suffixIcon: IconButton(
                              tooltip: '選擇日期',
                              onPressed: pickExpiryDate,
                              icon: const Icon(Icons.calendar_month_outlined),
                            ),
                          ),
                        ),
                      ],
                      const SizedBox(height: 12),
                      TextField(
                        controller: imageController,
                        decoration: const InputDecoration(
                          labelText: '圖片網址',
                          prefixIcon: Icon(Icons.image_outlined),
                        ),
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
                  onPressed: () {
                    final name = nameController.text.trim();
                    final stock = int.tryParse(stockController.text.trim());
                    final issued = reward?.issued ?? 0;
                    final redeemed = reward?.redeemed ?? 0;
                    final expiresAt = expiryMode == _RewardExpiryMode.unlimited
                        ? _rewardUnlimitedExpiryLabel
                        : expiryController.text.trim();

                    if (name.isEmpty) {
                      setDialogState(() => formError = '請填寫商品名稱。');
                      return;
                    }
                    if (stock == null || stock < 0) {
                      setDialogState(() => formError = '可用庫存必須是 0 以上的數字。');
                      return;
                    }
                    if (expiryMode == _RewardExpiryMode.limited &&
                        !_isValidAdminDate(expiresAt)) {
                      setDialogState(
                          () => formError = '兌換期限請使用 YYYY/MM/DD 格式。');
                      return;
                    }

                    pendingReward = AdminRewardItem(
                      id: reward?.id ?? createVeevaId('reward'),
                      name: name,
                      category: category,
                      stock: stock,
                      issued: issued,
                      redeemed: redeemed,
                      expiresAt: expiresAt,
                      status: status,
                      imageUrl: _optionalText(imageController.text),
                    );
                    Navigator.of(dialogContext).pop();
                  },
                  icon: Icon(isEditing ? Icons.save_outlined : Icons.add),
                  label: Text(isEditing ? '儲存' : '建立'),
                ),
              ],
            );
          },
        );
      },
    );

    final rewardToSave = pendingReward;
    if (rewardToSave != null) {
      await _saveReward(rewardToSave);
    }

    await Future<void>.delayed(const Duration(milliseconds: 250));
    nameController.dispose();
    stockController.dispose();
    expiryController.dispose();
    imageController.dispose();
  }

  Future<void> _showRewardStockDialog(AdminRewardItem reward) async {
    final amountController = TextEditingController(text: '20');
    var isAdding = true;
    String? formError;
    AdminRewardItem? pendingReward;

    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final parsedAmount =
                int.tryParse(amountController.text.trim()) ?? 0;
            final nextStock = isAdding
                ? reward.stock + parsedAmount
                : reward.stock - parsedAmount;
            return AlertDialog(
              title: const Text('調整庫存'),
              content: SizedBox(
                width: 420,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (formError != null) ...[
                      _InlineError(message: formError!),
                      const SizedBox(height: 12),
                    ],
                    _RewardSummaryTile(reward: reward),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<bool>(
                      value: isAdding,
                      decoration: const InputDecoration(
                        labelText: '調整方式',
                        prefixIcon: Icon(Icons.tune_outlined),
                      ),
                      items: const [
                        DropdownMenuItem(value: true, child: Text('增加庫存')),
                        DropdownMenuItem(value: false, child: Text('扣除庫存')),
                      ],
                      onChanged: (value) {
                        if (value == null) return;
                        setDialogState(() {
                          isAdding = value;
                          formError = null;
                        });
                      },
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: amountController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: '調整數量',
                        prefixIcon: Icon(Icons.add_box_outlined),
                      ),
                      onChanged: (_) => setDialogState(() => formError = null),
                    ),
                    const SizedBox(height: 12),
                    _MiniInfo(
                      label: '調整後庫存',
                      value:
                          parsedAmount > 0 ? '$nextStock' : '${reward.stock}',
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
                  onPressed: () {
                    final amount = int.tryParse(amountController.text.trim());
                    if (amount == null || amount <= 0) {
                      setDialogState(() => formError = '請輸入大於 0 的調整數量。');
                      return;
                    }
                    final updatedStock = isAdding
                        ? reward.stock + amount
                        : reward.stock - amount;
                    if (updatedStock < 0) {
                      setDialogState(() => formError = '扣除後庫存不能小於 0。');
                      return;
                    }
                    pendingReward = reward.copyWith(stock: updatedStock);
                    Navigator.of(dialogContext).pop();
                  },
                  icon: const Icon(Icons.save_outlined),
                  label: const Text('套用'),
                ),
              ],
            );
          },
        );
      },
    );

    final rewardToSave = pendingReward;
    if (rewardToSave != null) {
      await _saveReward(
        rewardToSave,
        errorMessage: '庫存更新失敗：請確認 Firestore API 與 rules 已啟用。',
      );
    }

    await Future<void>.delayed(const Duration(milliseconds: 250));
    amountController.dispose();
  }

  void _showRewardPreview(AdminRewardItem reward) {
    showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('兌換券預覽'),
          content: SizedBox(
            width: 500,
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      _RewardStatusChip(status: reward.status),
                      const SizedBox(width: 8),
                      Text(
                        reward.category,
                        style: const TextStyle(
                          color: Color(0xFF61706A),
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Text(
                    reward.name,
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 14),
                  _ActivityDetailLine(
                    icon: Icons.inventory_2_outlined,
                    label: '庫存',
                    value: '${reward.stock}',
                  ),
                  _ActivityDetailLine(
                    icon: Icons.send_outlined,
                    label: '發放',
                    value: '${reward.issued}',
                  ),
                  _ActivityDetailLine(
                    icon: Icons.redeem_outlined,
                    label: '兌換',
                    value: '${reward.redeemed}',
                  ),
                  _ActivityDetailLine(
                    icon: Icons.event_available_outlined,
                    label: '期限',
                    value: reward.expiresAt,
                  ),
                  if (reward.imageUrl?.isNotEmpty == true)
                    _ActivityDetailLine(
                      icon: Icons.image_outlined,
                      label: '圖片',
                      value: reward.imageUrl!,
                    ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('關閉'),
            ),
            FilledButton.icon(
              onPressed: () {
                Navigator.of(dialogContext).pop();
                _showRewardDialog(reward: reward);
              },
              icon: const Icon(Icons.edit_outlined),
              label: const Text('編輯'),
            ),
          ],
        );
      },
    );
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

class _InlineError extends StatelessWidget {
  const _InlineError({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0xFFFFF4F0),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFF0B8A8)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(
          children: [
            const Icon(Icons.error_outline, color: Color(0xFFAD3B24)),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(
                  color: Color(0xFF7A2718),
                  fontWeight: FontWeight.w800,
                ),
              ),
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
    this.adminUser,
    this.onLogout,
  });

  final String title;
  final IconData? icon;
  final bool showSearch;
  final backend.VeevaAdminUser? adminUser;
  final Future<void> Function()? onLogout;

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
          _AdminAccountMenu(adminUser: adminUser, onLogout: onLogout),
        ],
      ),
    );
  }
}

class _AdminAccountMenu extends StatelessWidget {
  const _AdminAccountMenu({
    required this.adminUser,
    required this.onLogout,
  });

  final backend.VeevaAdminUser? adminUser;
  final Future<void> Function()? onLogout;

  @override
  Widget build(BuildContext context) {
    final user = adminUser;
    if (user == null) {
      return const CircleAvatar(child: Icon(Icons.person_outline));
    }

    return PopupMenuButton<String>(
      tooltip: '管理者帳號',
      onSelected: (value) {
        if (value == 'logout') {
          onLogout?.call();
        }
      },
      itemBuilder: (context) => [
        PopupMenuItem<String>(
          enabled: false,
          child: SizedBox(
            width: 220,
            child: Row(
              children: [
                _AdminAvatar(adminUser: user),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        user.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.w900),
                      ),
                      Text(
                        _adminRoleLabel(user.role),
                        style: const TextStyle(
                          color: Color(0xFF61706A),
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        if (onLogout != null)
          const PopupMenuItem<String>(
            value: 'logout',
            child: Row(
              children: [
                Icon(Icons.logout),
                SizedBox(width: 10),
                Text('登出 LINE'),
              ],
            ),
          ),
      ],
      child: _AdminAvatar(adminUser: user),
    );
  }
}

class _AdminAvatar extends StatelessWidget {
  const _AdminAvatar({required this.adminUser});

  final backend.VeevaAdminUser adminUser;

  @override
  Widget build(BuildContext context) {
    final name = adminUser.name.trim().isEmpty ? 'A' : adminUser.name.trim();
    return CircleAvatar(
      backgroundImage: adminUser.avatarUrl == null
          ? null
          : NetworkImage(adminUser.avatarUrl!),
      child: adminUser.avatarUrl == null ? Text(name.characters.first) : null,
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

class _ActivityManagement extends StatefulWidget {
  const _ActivityManagement({
    required this.activities,
    required this.onCreate,
    required this.onEdit,
    required this.onToggleActive,
    required this.onArchive,
  });

  final List<backend.VeevaActivity> activities;
  final VoidCallback onCreate;
  final ValueChanged<backend.VeevaActivity> onEdit;
  final Future<void> Function(backend.VeevaActivity activity) onToggleActive;
  final Future<void> Function(backend.VeevaActivity activity) onArchive;

  @override
  State<_ActivityManagement> createState() => _ActivityManagementState();
}

class _ActivityManagementState extends State<_ActivityManagement> {
  String query = '';
  String? statusFilter;

  @override
  Widget build(BuildContext context) {
    final isCompact = MediaQuery.sizeOf(context).width < 820;
    final visibleActivities = widget.activities.where(_matchesFilter).toList()
      ..sort((a, b) {
        if (a.active != b.active) return a.active ? -1 : 1;
        return a.title.compareTo(b.title);
      });
    final activeCount =
        widget.activities.where((activity) => activity.active).length;
    final publishedCount = widget.activities
        .where((activity) =>
            activity.status == backend.VeevaContentStatus.published)
        .length;
    final draftCount = widget.activities
        .where(
            (activity) => activity.status == backend.VeevaContentStatus.draft)
        .length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (isCompact)
          Column(
            children: [
              _MetricCard(
                label: '進行中',
                value: '$activeCount',
                icon: Icons.play_circle_outline,
              ),
              const SizedBox(height: 12),
              _MetricCard(
                label: '已發布',
                value: '$publishedCount',
                icon: Icons.public_outlined,
              ),
              const SizedBox(height: 12),
              _MetricCard(
                label: '草稿',
                value: '$draftCount',
                icon: Icons.edit_note_outlined,
              ),
            ],
          )
        else
          Row(
            children: [
              Expanded(
                child: _MetricCard(
                  label: '進行中',
                  value: '$activeCount',
                  icon: Icons.play_circle_outline,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _MetricCard(
                  label: '已發布',
                  value: '$publishedCount',
                  icon: Icons.public_outlined,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _MetricCard(
                  label: '草稿',
                  value: '$draftCount',
                  icon: Icons.edit_note_outlined,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _MetricCard(
                  label: '活動總數',
                  value: '${widget.activities.length}',
                  icon: Icons.campaign_outlined,
                ),
              ),
            ],
          ),
        const SizedBox(height: 18),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _ActivityHeader(onCreate: widget.onCreate),
                const SizedBox(height: 16),
                _ActivityFilters(
                  query: query,
                  statusFilter: statusFilter,
                  onQueryChanged: (value) => setState(() => query = value),
                  onStatusChanged: (value) =>
                      setState(() => statusFilter = value),
                ),
                const SizedBox(height: 16),
                if (visibleActivities.isEmpty)
                  const _EmptyListMessage(message: '目前沒有符合條件的活動。')
                else if (isCompact)
                  Column(
                    children: [
                      for (final activity in visibleActivities)
                        _ActivityMobileCard(
                          activity: activity,
                          onEdit: widget.onEdit,
                          onPreview: _showPreview,
                          onToggleActive: widget.onToggleActive,
                          onArchive: widget.onArchive,
                        ),
                    ],
                  )
                else
                  _ActivityDataTable(
                    activities: visibleActivities,
                    onEdit: widget.onEdit,
                    onPreview: _showPreview,
                    onToggleActive: widget.onToggleActive,
                    onArchive: widget.onArchive,
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  bool _matchesFilter(backend.VeevaActivity activity) {
    final keyword = query.trim().toLowerCase();
    final matchesQuery = keyword.isEmpty ||
        [
          activity.title,
          activity.label,
          activity.description,
          activity.reward,
          _activityTypeLabel(activity.type),
          activity.surveyUrl,
          activity.periodText,
          activity.note,
          _activityStatusLabel(activity),
        ].whereType<String>().any((value) {
          return value.toLowerCase().contains(keyword);
        });
    final matchesStatus = statusFilter == null ||
        (statusFilter == _activityActiveFilterValue && activity.active) ||
        activity.status.name == statusFilter;
    return matchesQuery && matchesStatus;
  }

  void _showPreview(backend.VeevaActivity activity) {
    showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('活動預覽'),
          content: SizedBox(
            width: 520,
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      _ActivityStatusChip(activity: activity),
                      const SizedBox(width: 8),
                      Text(
                        activity.label,
                        style: const TextStyle(
                          color: Color(0xFF61706A),
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Text(
                    activity.title,
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    activity.description,
                    style: const TextStyle(height: 1.5),
                  ),
                  const SizedBox(height: 14),
                  _ActivityDetailLine(
                    icon: Icons.redeem_outlined,
                    label: '獎勵',
                    value: activity.reward,
                  ),
                  _ActivityDetailLine(
                    icon: _activityTypeIcon(activity.type),
                    label: '類型',
                    value: _activityTypeLabel(activity.type),
                  ),
                  if (activity.type == backend.VeevaActivityType.survey)
                    _ActivityDetailLine(
                      icon: Icons.link_outlined,
                      label: '問卷網址',
                      value: activity.surveyUrl ?? defaultVeevaSurveyUrl,
                    ),
                  _ActivityDetailLine(
                    icon: Icons.date_range_outlined,
                    label: '期間',
                    value: activity.periodText ?? '未設定',
                  ),
                  if (activity.note?.isNotEmpty == true)
                    _ActivityDetailLine(
                      icon: Icons.sticky_note_2_outlined,
                      label: '備註',
                      value: activity.note!,
                    ),
                  if (activity.imageUrl?.isNotEmpty == true)
                    _ActivityDetailLine(
                      icon: Icons.image_outlined,
                      label: '圖片',
                      value: activity.imageUrl!,
                    ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('關閉'),
            ),
            FilledButton.icon(
              onPressed: () {
                Navigator.of(dialogContext).pop();
                widget.onEdit(activity);
              },
              icon: const Icon(Icons.edit_outlined),
              label: const Text('編輯'),
            ),
          ],
        );
      },
    );
  }
}

class _ActivityHeader extends StatelessWidget {
  const _ActivityHeader({required this.onCreate});

  final VoidCallback onCreate;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Icon(Icons.campaign_outlined, color: Color(0xFF216B57)),
        const SizedBox(width: 10),
        const Expanded(
          child: Text(
            '活動管理',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
          ),
        ),
        FilledButton.icon(
          onPressed: onCreate,
          icon: const Icon(Icons.add),
          label: const Text('新增活動'),
        ),
      ],
    );
  }
}

class _ActivityFilters extends StatelessWidget {
  const _ActivityFilters({
    required this.query,
    required this.statusFilter,
    required this.onQueryChanged,
    required this.onStatusChanged,
  });

  final String query;
  final String? statusFilter;
  final ValueChanged<String> onQueryChanged;
  final ValueChanged<String?> onStatusChanged;

  @override
  Widget build(BuildContext context) {
    final isCompact = MediaQuery.sizeOf(context).width < 760;
    final search = TextField(
      onChanged: onQueryChanged,
      decoration: InputDecoration(
        hintText: '搜尋活動名稱、標籤、獎勵、備註',
        prefixIcon: const Icon(Icons.search),
        isDense: true,
        filled: true,
        fillColor: const Color(0xFFF5F7F8),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide.none,
        ),
      ),
    );
    final statusDropdown = DropdownButtonFormField<String?>(
      value: statusFilter,
      decoration: InputDecoration(
        labelText: '狀態',
        isDense: true,
        filled: true,
        fillColor: const Color(0xFFF5F7F8),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide.none,
        ),
      ),
      items: [
        const DropdownMenuItem<String?>(
          value: null,
          child: Text('全部狀態'),
        ),
        const DropdownMenuItem<String?>(
          value: _activityActiveFilterValue,
          child: Text('進行中'),
        ),
        for (final status in backend.VeevaContentStatus.values)
          DropdownMenuItem<String?>(
            value: status.name,
            child: Text(_contentStatusLabel(status)),
          ),
      ],
      onChanged: onStatusChanged,
    );

    if (isCompact) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          search,
          const SizedBox(height: 10),
          statusDropdown,
        ],
      );
    }

    return Row(
      children: [
        Expanded(flex: 2, child: search),
        const SizedBox(width: 12),
        SizedBox(width: 180, child: statusDropdown),
      ],
    );
  }
}

class _ActivityDataTable extends StatelessWidget {
  const _ActivityDataTable({
    required this.activities,
    required this.onEdit,
    required this.onPreview,
    required this.onToggleActive,
    required this.onArchive,
  });

  final List<backend.VeevaActivity> activities;
  final ValueChanged<backend.VeevaActivity> onEdit;
  final ValueChanged<backend.VeevaActivity> onPreview;
  final Future<void> Function(backend.VeevaActivity activity) onToggleActive;
  final Future<void> Function(backend.VeevaActivity activity) onArchive;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: DataTable(
          headingRowColor: WidgetStateProperty.all(const Color(0xFFF5F7F8)),
          horizontalMargin: 16,
          columnSpacing: 18,
          columns: const [
            DataColumn(label: Text('活動名稱')),
            DataColumn(label: Text('類型')),
            DataColumn(label: Text('狀態')),
            DataColumn(label: Text('獎勵')),
            DataColumn(label: Text('活動期間')),
            DataColumn(label: Text('備註')),
            DataColumn(label: Text('操作')),
          ],
          rows: [
            for (final activity in activities)
              DataRow(
                cells: [
                  DataCell(_ActivityTitleCell(activity: activity)),
                  DataCell(_ActivityTypeChip(type: activity.type)),
                  DataCell(_ActivityStatusChip(activity: activity)),
                  DataCell(Text(activity.reward)),
                  DataCell(Text(activity.periodText ?? '未設定')),
                  DataCell(
                    SizedBox(
                      width: 180,
                      child: Text(
                        activity.note ?? '-',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                  DataCell(
                    _ActivityActions(
                      activity: activity,
                      onEdit: onEdit,
                      onPreview: onPreview,
                      onToggleActive: onToggleActive,
                      onArchive: onArchive,
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

class _ActivityMobileCard extends StatelessWidget {
  const _ActivityMobileCard({
    required this.activity,
    required this.onEdit,
    required this.onPreview,
    required this.onToggleActive,
    required this.onArchive,
  });

  final backend.VeevaActivity activity;
  final ValueChanged<backend.VeevaActivity> onEdit;
  final ValueChanged<backend.VeevaActivity> onPreview;
  final Future<void> Function(backend.VeevaActivity activity) onToggleActive;
  final Future<void> Function(backend.VeevaActivity activity) onArchive;

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
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: _ActivityTitleCell(activity: activity)),
              const SizedBox(width: 8),
              _ActivityStatusChip(activity: activity),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            activity.description,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 10),
          _ActivityDetailLine(
            icon: Icons.redeem_outlined,
            label: '獎勵',
            value: activity.reward,
          ),
          _ActivityDetailLine(
            icon: _activityTypeIcon(activity.type),
            label: '類型',
            value: _activityTypeLabel(activity.type),
          ),
          _ActivityDetailLine(
            icon: Icons.date_range_outlined,
            label: '期間',
            value: activity.periodText ?? '未設定',
          ),
          if (activity.note?.isNotEmpty == true)
            _ActivityDetailLine(
              icon: Icons.sticky_note_2_outlined,
              label: '備註',
              value: activity.note!,
            ),
          const SizedBox(height: 10),
          _ActivityActions(
            activity: activity,
            onEdit: onEdit,
            onPreview: onPreview,
            onToggleActive: onToggleActive,
            onArchive: onArchive,
          ),
        ],
      ),
    );
  }
}

class _ActivityTitleCell extends StatelessWidget {
  const _ActivityTitleCell({required this.activity});

  final backend.VeevaActivity activity;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 220,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            activity.title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 3),
          Text(
            activity.label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: Color(0xFF61706A), fontSize: 12),
          ),
        ],
      ),
    );
  }
}

class _ActivityActions extends StatelessWidget {
  const _ActivityActions({
    required this.activity,
    required this.onEdit,
    required this.onPreview,
    required this.onToggleActive,
    required this.onArchive,
  });

  final backend.VeevaActivity activity;
  final ValueChanged<backend.VeevaActivity> onEdit;
  final ValueChanged<backend.VeevaActivity> onPreview;
  final Future<void> Function(backend.VeevaActivity activity) onToggleActive;
  final Future<void> Function(backend.VeevaActivity activity) onArchive;

  @override
  Widget build(BuildContext context) {
    final canArchive = activity.status != backend.VeevaContentStatus.archived;
    return SizedBox(
      width: 128,
      height: 36,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _ActivityActionIconButton(
            tooltip: '編輯',
            icon: Icons.edit_outlined,
            onPressed: () => onEdit(activity),
          ),
          _ActivityActionIconButton(
            tooltip: '預覽',
            icon: Icons.visibility_outlined,
            onPressed: () => onPreview(activity),
          ),
          _ActivityActionIconButton(
            tooltip: activity.active ? '停用' : '啟用',
            icon: activity.active
                ? Icons.pause_circle_outline
                : Icons.play_circle_outline,
            onPressed: () => onToggleActive(activity),
          ),
          _ActivityActionIconButton(
            tooltip: '封存',
            icon: Icons.archive_outlined,
            onPressed: canArchive ? () => onArchive(activity) : null,
          ),
        ],
      ),
    );
  }
}

class _ActivityActionIconButton extends StatelessWidget {
  const _ActivityActionIconButton({
    required this.tooltip,
    required this.icon,
    required this.onPressed,
  });

  final String tooltip;
  final IconData icon;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null;
    final color = enabled
        ? Theme.of(context).colorScheme.onSurface
        : Theme.of(context).disabledColor;
    return Tooltip(
      message: tooltip,
      child: Semantics(
        button: true,
        enabled: enabled,
        label: tooltip,
        child: MouseRegion(
          cursor: enabled ? SystemMouseCursors.click : SystemMouseCursors.basic,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: onPressed,
            child: SizedBox(
              width: 32,
              height: 36,
              child: Center(
                child: Icon(icon, size: 20, color: color),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ActivityStatusChip extends StatelessWidget {
  const _ActivityStatusChip({required this.activity});

  final backend.VeevaActivity activity;

  @override
  Widget build(BuildContext context) {
    final color = _activityStatusColor(activity);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        _activityStatusLabel(activity),
        style: const TextStyle(
          color: Color(0xFF16362E),
          fontSize: 12,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

class _ActivityTypeChip extends StatelessWidget {
  const _ActivityTypeChip({required this.type});

  final backend.VeevaActivityType type;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: const Color(0xFFEAF3EA),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(_activityTypeIcon(type),
              size: 15, color: const Color(0xFF216B57)),
          const SizedBox(width: 5),
          Text(
            _activityTypeLabel(type),
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800),
          ),
        ],
      ),
    );
  }
}

class _ActivityDetailLine extends StatelessWidget {
  const _ActivityDetailLine({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: const Color(0xFF61706A)),
          const SizedBox(width: 8),
          SizedBox(
            width: 42,
            child: Text(
              label,
              style: const TextStyle(
                color: Color(0xFF61706A),
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(child: Text(value)),
        ],
      ),
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

const _activityActiveFilterValue = 'active';

String _activityTypeLabel(backend.VeevaActivityType type) {
  return switch (type) {
    backend.VeevaActivityType.survey => '問卷',
    backend.VeevaActivityType.registration => '活動報名',
  };
}

IconData _activityTypeIcon(backend.VeevaActivityType type) {
  return switch (type) {
    backend.VeevaActivityType.survey => Icons.fact_check_outlined,
    backend.VeevaActivityType.registration => Icons.event_available_outlined,
  };
}

String _activityStatusLabel(backend.VeevaActivity activity) {
  if (activity.active) {
    return '進行中';
  }
  return _contentStatusLabel(activity.status);
}

Color _activityStatusColor(backend.VeevaActivity activity) {
  if (activity.active) {
    return const Color(0xFFEAF3EA);
  }
  return switch (activity.status) {
    backend.VeevaContentStatus.draft => const Color(0xFFEFF3F6),
    backend.VeevaContentStatus.scheduled => const Color(0xFFEAF0FF),
    backend.VeevaContentStatus.published => const Color(0xFFE8F5EF),
    backend.VeevaContentStatus.archived => const Color(0xFFFFF4D9),
  };
}

String _fallbackText(String value, String fallback) {
  final text = value.trim();
  return text.isEmpty ? fallback : text;
}

String? _optionalText(String value) {
  final text = value.trim();
  return text.isEmpty ? null : text;
}

bool _isHttpUrl(String? value) {
  final text = value?.trim();
  if (text == null || text.isEmpty) {
    return false;
  }
  final uri = Uri.tryParse(text);
  return uri != null &&
      uri.host.isNotEmpty &&
      (uri.scheme == 'https' || uri.scheme == 'http');
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
    required this.onEdit,
    required this.onPreview,
    required this.onToggleStatus,
    required this.onAdjustStock,
    required this.onExpire,
    required this.onDelete,
  });

  final List<AdminRewardItem> rewards;
  final VoidCallback onCreate;
  final ValueChanged<AdminRewardItem> onToggleStatus;
  final ValueChanged<AdminRewardItem> onEdit;
  final ValueChanged<AdminRewardItem> onPreview;
  final ValueChanged<AdminRewardItem> onAdjustStock;
  final ValueChanged<AdminRewardItem> onExpire;
  final ValueChanged<AdminRewardItem> onDelete;

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
      final keyword = query.trim().toLowerCase();
      final matchesQuery = keyword.isEmpty ||
          reward.name.toLowerCase().contains(keyword) ||
          reward.category.toLowerCase().contains(keyword) ||
          reward.expiresAt.contains(keyword);
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
                      if (visibleRewards.isEmpty)
                        const _EmptyListMessage(message: '目前沒有符合條件的兌換券。')
                      else
                        for (final reward in visibleRewards)
                          _RewardMobileCard(
                            reward: reward,
                            onEdit: () => widget.onEdit(reward),
                            onPreview: () => widget.onPreview(reward),
                            onToggleStatus: () => widget.onToggleStatus(reward),
                            onAdjustStock: () => widget.onAdjustStock(reward),
                            onExpire: () => widget.onExpire(reward),
                            onDelete: () => widget.onDelete(reward),
                          ),
                    ],
                  )
                else if (visibleRewards.isEmpty)
                  const _EmptyListMessage(message: '目前沒有符合條件的兌換券。')
                else
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: _RewardDataTable(
                      rewards: visibleRewards,
                      onEdit: widget.onEdit,
                      onPreview: widget.onPreview,
                      onToggleStatus: widget.onToggleStatus,
                      onAdjustStock: widget.onAdjustStock,
                      onExpire: widget.onExpire,
                      onDelete: widget.onDelete,
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

class _RewardDataTable extends StatelessWidget {
  const _RewardDataTable({
    required this.rewards,
    required this.onEdit,
    required this.onPreview,
    required this.onToggleStatus,
    required this.onAdjustStock,
    required this.onExpire,
    required this.onDelete,
  });

  final List<AdminRewardItem> rewards;
  final ValueChanged<AdminRewardItem> onEdit;
  final ValueChanged<AdminRewardItem> onPreview;
  final ValueChanged<AdminRewardItem> onToggleStatus;
  final ValueChanged<AdminRewardItem> onAdjustStock;
  final ValueChanged<AdminRewardItem> onExpire;
  final ValueChanged<AdminRewardItem> onDelete;

  @override
  Widget build(BuildContext context) {
    return DataTable(
      columnSpacing: 24,
      horizontalMargin: 16,
      headingRowColor: WidgetStateProperty.all(const Color(0xFFF5F7F8)),
      columns: const [
        DataColumn(label: Text('兌換券')),
        DataColumn(label: Text('分類')),
        DataColumn(label: Text('可用庫存')),
        DataColumn(label: Text('發放 / 兌換')),
        DataColumn(label: Text('期限')),
        DataColumn(label: Text('狀態')),
        DataColumn(label: Text('操作')),
      ],
      rows: [
        for (final reward in rewards)
          DataRow(
            cells: [
              DataCell(_RewardNameCell(reward: reward)),
              DataCell(Text(reward.category)),
              DataCell(Text('${reward.stock}')),
              DataCell(Text('${reward.issued} / ${reward.redeemed}')),
              DataCell(Text(reward.expiresAt)),
              DataCell(_RewardStatusChip(status: reward.status)),
              DataCell(
                _RewardActions(
                  reward: reward,
                  onEdit: () => onEdit(reward),
                  onPreview: () => onPreview(reward),
                  onToggleStatus: () => onToggleStatus(reward),
                  onAdjustStock: () => onAdjustStock(reward),
                  onExpire: () => onExpire(reward),
                  onDelete: () => onDelete(reward),
                ),
              ),
            ],
          ),
      ],
    );
  }
}

class _RewardNameCell extends StatelessWidget {
  const _RewardNameCell({required this.reward});

  final AdminRewardItem reward;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 220,
      child: Text(
        reward.name,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(fontWeight: FontWeight.w900),
      ),
    );
  }
}

class _RewardMobileCard extends StatelessWidget {
  const _RewardMobileCard({
    required this.reward,
    required this.onEdit,
    required this.onPreview,
    required this.onToggleStatus,
    required this.onAdjustStock,
    required this.onExpire,
    required this.onDelete,
  });

  final AdminRewardItem reward;
  final VoidCallback onEdit;
  final VoidCallback onPreview;
  final VoidCallback onToggleStatus;
  final VoidCallback onAdjustStock;
  final VoidCallback onExpire;
  final VoidCallback onDelete;

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
          Align(
            alignment: Alignment.centerRight,
            child: _RewardActions(
              reward: reward,
              onEdit: onEdit,
              onPreview: onPreview,
              onToggleStatus: onToggleStatus,
              onAdjustStock: onAdjustStock,
              onExpire: onExpire,
              onDelete: onDelete,
            ),
          ),
        ],
      ),
    );
  }
}

class _RewardActions extends StatelessWidget {
  const _RewardActions({
    required this.reward,
    required this.onEdit,
    required this.onPreview,
    required this.onToggleStatus,
    required this.onAdjustStock,
    required this.onExpire,
    required this.onDelete,
  });

  final AdminRewardItem reward;
  final VoidCallback onEdit;
  final VoidCallback onPreview;
  final VoidCallback onToggleStatus;
  final VoidCallback onAdjustStock;
  final VoidCallback onExpire;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final canChangeStatus = reward.status != RewardStatus.expired;
    return SizedBox(
      width: 240,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _RewardActionIconButton(
            tooltip: '編輯',
            onPressed: onEdit,
            icon: Icons.edit_outlined,
          ),
          _RewardActionIconButton(
            tooltip: '預覽',
            onPressed: onPreview,
            icon: Icons.visibility_outlined,
          ),
          _RewardActionIconButton(
            tooltip: reward.status == RewardStatus.active ? '停用' : '啟用',
            onPressed: canChangeStatus ? onToggleStatus : null,
            icon: reward.status == RewardStatus.active
                ? Icons.pause_circle_outline
                : Icons.play_circle_outline,
          ),
          _RewardActionIconButton(
            tooltip: '調整庫存',
            onPressed: onAdjustStock,
            icon: Icons.inventory_2_outlined,
          ),
          _RewardActionIconButton(
            tooltip: '設為已過期',
            onPressed: canChangeStatus ? onExpire : null,
            icon: Icons.event_busy_outlined,
          ),
          _RewardActionIconButton(
            tooltip: '刪除',
            onPressed: onDelete,
            icon: Icons.delete_outline,
          ),
        ],
      ),
    );
  }
}

class _RewardActionIconButton extends StatelessWidget {
  const _RewardActionIconButton({
    required this.tooltip,
    required this.onPressed,
    required this.icon,
  });

  final String tooltip;
  final VoidCallback? onPressed;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: tooltip,
      onPressed: onPressed,
      icon: Icon(icon),
      iconSize: 20,
      padding: EdgeInsets.zero,
      visualDensity: VisualDensity.compact,
      constraints: const BoxConstraints.tightFor(width: 36, height: 36),
    );
  }
}

class _RewardSummaryTile extends StatelessWidget {
  const _RewardSummaryTile({required this.reward});

  final AdminRewardItem reward;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFA),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE4E8EA)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            reward.name,
            style: const TextStyle(fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 6),
          Text(
              '目前庫存 ${reward.stock} · 已發放 ${reward.issued} · 已兌換 ${reward.redeemed}'),
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
        padding: const EdgeInsets.all(32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 42, color: const Color(0xFF216B57)),
            const SizedBox(height: 18),
            Text(
              title,
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 10),
            Text(
              description,
              style: const TextStyle(color: Color(0xFF61706A)),
            ),
          ],
        ),
      ),
    );
  }
}
