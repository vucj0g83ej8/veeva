import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:excel/excel.dart' as xlsx;
import 'package:qr_flutter/qr_flutter.dart';

import 'data/firebase_bootstrap.dart';
import 'data/veeva_models.dart' as backend;
import 'data/veeva_repository.dart';
import 'services/admin_line_auth_base.dart';
import 'services/admin_line_auth_stub.dart'
    if (dart.library.html) 'services/admin_line_auth_web.dart';
import 'services/admin_image_picker_stub.dart'
    if (dart.library.html) 'services/admin_image_picker_web.dart';
import 'widgets/admin_image_drop_overlay_stub.dart'
    if (dart.library.html) 'widgets/admin_image_drop_overlay_web.dart';
import 'widgets/rich_article_editor_stub.dart'
    if (dart.library.html) 'widgets/rich_article_editor_web.dart';
import 'services/admin_voucher_importer_base.dart';
import 'services/admin_voucher_importer_stub.dart'
    if (dart.library.html) 'services/admin_voucher_importer_web.dart';
import 'services/admin_excel_downloader_stub.dart'
    if (dart.library.html) 'services/admin_excel_downloader_web.dart';

class _BrandColors {
  static const primary = Color(0xFFFF9812);
  static const sidebar = Color(0xFF303236);
  static const surface = Color(0xFFFFFAF3);
  static const border = Color(0xFFEADFCE);
}

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
          seedColor: _BrandColors.primary,
          primary: _BrandColors.primary,
          surface: _BrandColors.surface,
        ),
        scaffoldBackgroundColor: _BrandColors.surface,
        cardTheme: CardTheme(
          color: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
            side: const BorderSide(color: _BrandColors.border),
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
      'reward-distribution' ||
      'rewardDistribution' =>
        AdminTab.rewardDistribution,
      'news' => AdminTab.news,
      'rewards' => AdminTab.rewards,
      'permissions' => AdminTab.permissions,
      'employees' || 'staff' => AdminTab.employees,
      'settings' => AdminTab.settings,
      _ => AdminTab.dashboard,
    };
  }
}

enum AdminTab {
  dashboard,
  members,
  activities,
  rewardDistribution,
  news,
  rewards,
  permissions,
  employees,
  settings,
}

enum ReviewStatus { pending, approved, rejected }

enum RewardStatus { active, paused, expired }

enum _RewardExpiryMode { unlimited, limited }

enum MemberManagementTab {
  loggedIn,
  pendingReview,
  approvedReview,
  issuedReview,
  notIssuedReview,
}

enum ReviewRewardIssueStatus { pending, issued, notIssued }

enum _MemberReviewActionMode { approve, rewardDecision, issued, notIssued }

const String _memberReviewSurveyActivityId = 'survey-coffee';

class AdminReviewItem {
  AdminReviewItem({
    required this.id,
    required this.memberId,
    required this.name,
    required this.hospital,
    required this.department,
    required this.completedAt,
    required this.status,
    this.rewardIssueStatus,
    this.rewardIssueReason,
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
      rewardIssueStatus: review.rewardIssueStatus,
      rewardIssueReason: review.rewardIssueReason,
    );
  }

  final String id;
  final String memberId;
  final String name;
  final String hospital;
  final String department;
  final String completedAt;
  ReviewStatus status;
  String? rewardIssueStatus;
  String? rewardIssueReason;

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
      rewardIssueStatus: rewardIssueStatus,
      rewardIssueReason: rewardIssueReason,
    );
  }
}

class _MemberReviewChecklistItem {
  const _MemberReviewChecklistItem({
    required this.member,
    required this.surveyRecord,
    required this.rewardIssueStatus,
    this.review,
    this.rewardIssueReason,
  });

  final backend.VeevaMember member;
  final backend.VeevaActivityRecord? surveyRecord;
  final AdminReviewItem? review;
  final ReviewRewardIssueStatus rewardIssueStatus;
  final String? rewardIssueReason;

  bool get surveySubmitted {
    final status = surveyRecord?.status;
    return status == 'pendingReview' || status == 'completed';
  }

  bool get surveyApproved => surveyRecord?.status == 'completed';

  bool get memberApproved =>
      member.status == backend.VeevaMemberStatus.verified;

  bool get canApprove => surveySubmitted && !memberApproved;

  bool get rewardIssued => rewardIssueStatus == ReviewRewardIssueStatus.issued;

  bool get rewardNotIssued =>
      rewardIssueStatus == ReviewRewardIssueStatus.notIssued;

  bool get canDecideReward =>
      memberApproved && rewardIssueStatus == ReviewRewardIssueStatus.pending;

  String get rewardIssueLabel {
    return switch (rewardIssueStatus) {
      ReviewRewardIssueStatus.pending => '待發放',
      ReviewRewardIssueStatus.issued => '已發放',
      ReviewRewardIssueStatus.notIssued => '未發放',
    };
  }

  String get surveyStatusLabel {
    return switch (surveyRecord?.status) {
      'completed' => '已通過',
      'pendingReview' => '審核中',
      'registered' => '填寫中',
      'rejected' => '可重填',
      _ => '未填寫',
    };
  }

  DateTime? get updatedAt =>
      surveyRecord?.updatedAt ??
      surveyRecord?.completedAt ??
      surveyRecord?.registeredAt ??
      member.phoneVerifiedAt ??
      member.lastLineLoginAt;
}

ReviewRewardIssueStatus _reviewRewardIssueStatusFromName(String? value) {
  return switch (value) {
    'issued' => ReviewRewardIssueStatus.issued,
    'notIssued' => ReviewRewardIssueStatus.notIssued,
    _ => ReviewRewardIssueStatus.pending,
  };
}

String _reviewRewardIssueStatusName(ReviewRewardIssueStatus status) {
  return switch (status) {
    ReviewRewardIssueStatus.pending => 'pending',
    ReviewRewardIssueStatus.issued => 'issued',
    ReviewRewardIssueStatus.notIssued => 'notIssued',
  };
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
    this.voucherTotal = 0,
    this.voucherAvailable = 0,
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
      voucherTotal: reward.voucherTotal,
      voucherAvailable: reward.voucherAvailable,
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
  final int voucherTotal;
  final int voucherAvailable;

  AdminRewardItem copyWith({
    String? name,
    String? category,
    int? stock,
    int? issued,
    int? redeemed,
    String? expiresAt,
    RewardStatus? status,
    Object? imageUrl = _unchangedRewardImageUrl,
    int? voucherTotal,
    int? voucherAvailable,
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
      voucherTotal: voucherTotal ?? this.voucherTotal,
      voucherAvailable: voucherAvailable ?? this.voucherAvailable,
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
      voucherTotal: voucherTotal,
      voucherAvailable: voucherAvailable,
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

String _memberPhoneLabel(backend.VeevaMember member) {
  final phone = member.phoneNumber?.trim();
  return phone == null || phone.isEmpty ? '-' : phone;
}

backend.VeevaMember? _referrerFor(
  backend.VeevaMember member,
  List<backend.VeevaMember> members,
) {
  final referrerId = member.referredByMemberId?.trim();
  if (referrerId == null || referrerId.isEmpty) return null;
  for (final candidate in members) {
    if (candidate.id == referrerId ||
        candidate.lineUserId == referrerId ||
        candidate.shareCode == member.referredByShareCode) {
      return candidate;
    }
  }
  return null;
}

String _referrerFallbackLabel(backend.VeevaMember member) {
  final referrerId = member.referredByMemberId?.trim();
  if (referrerId == null || referrerId.isEmpty) return '-';
  final shareCode = member.referredByShareCode?.trim();
  if (shareCode != null && shareCode.isNotEmpty) {
    return shareCode;
  }
  return referrerId;
}

String _referrerNameFor(
  backend.VeevaMember member,
  List<backend.VeevaMember> members,
) {
  return _referrerFor(member, members)?.name ?? _referrerFallbackLabel(member);
}

bool _memberWasReferredBy(
  backend.VeevaMember member,
  backend.VeevaMember referrer,
) {
  final referrerId = member.referredByMemberId?.trim();
  final referrerShareCode = member.referredByShareCode?.trim();
  return referrerId == referrer.id ||
      referrerId == referrer.lineUserId ||
      referrerShareCode == referrer.shareCode;
}

List<backend.VeevaMember> _referralsForMember(
  backend.VeevaMember referrer,
  List<backend.VeevaMember> members,
) {
  final referrals = [
    for (final member in members)
      if (member.id != referrer.id && _memberWasReferredBy(member, referrer))
        member,
  ];
  referrals.sort((a, b) {
    final aTime = a.referredAt ?? a.createdAt ?? a.lastLineLoginAt;
    final bTime = b.referredAt ?? b.createdAt ?? b.lastLineLoginAt;
    if (aTime != null && bTime != null) return bTime.compareTo(aTime);
    if (aTime != null) return -1;
    if (bTime != null) return 1;
    return a.name.compareTo(b.name);
  });
  return referrals;
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
  static const _cachedAdminSessionKey = 'veevaAdminSession';
  static const _cachedAdminSessionTtl = Duration(hours: 8);

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
    widget.authService.writeLocalValue(_cachedAdminSessionKey, '');
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
      final cachedAdmin = _readCachedAdmin(profile.userId);
      if (cachedAdmin != null && mounted) {
        setState(() {
          adminUser = cachedAdmin;
          viewState = _AdminAuthViewState.checking;
          message = null;
        });
      }

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
      _cacheAdmin(activeAdmin);
    } catch (_) {
      if (!mounted) return;
      if (adminUser != null) {
        return;
      }
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

  backend.VeevaAdminUser? _readCachedAdmin(String lineUserId) {
    final raw = widget.authService.readLocalValue(_cachedAdminSessionKey);
    if (raw == null || raw.isEmpty) return null;
    final parts = raw.split('|');
    if (parts.length < 9) return null;
    final cachedAt = int.tryParse(parts[0]);
    if (cachedAt == null) return null;
    final age = DateTime.now().millisecondsSinceEpoch - cachedAt;
    if (age > _cachedAdminSessionTtl.inMilliseconds) return null;
    if (parts[2] != lineUserId) return null;
    return backend.VeevaAdminUser(
      id: parts[1],
      memberId: parts[3],
      lineUserId: parts[2],
      name: parts[4],
      email: parts[5].isEmpty ? null : parts[5],
      avatarUrl: parts[6].isEmpty ? null : parts[6],
      role: _adminRoleFromCache(parts[7]),
      status: backend.VeevaAdminStatus.active,
      permissions: parts[8].isEmpty ? const [] : parts[8].split(','),
    );
  }

  void _cacheAdmin(backend.VeevaAdminUser admin) {
    widget.authService.writeLocalValue(
      _cachedAdminSessionKey,
      [
        DateTime.now().millisecondsSinceEpoch,
        admin.id,
        admin.lineUserId,
        admin.memberId,
        admin.name,
        admin.email ?? '',
        admin.avatarUrl ?? '',
        admin.role.name,
        admin.permissions.join(','),
      ].join('|'),
    );
  }

  backend.VeevaAdminRole _adminRoleFromCache(String value) {
    for (final role in backend.VeevaAdminRole.values) {
      if (role.name == value) return role;
    }
    return backend.VeevaAdminRole.viewer;
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
                      color: const Color(0xFFFFF2DF),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      Icons.admin_panel_settings_outlined,
                      color: Color(0xFFC66D00),
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
                      color: Color(0xFF8A8D8F),
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
        color: const Color(0xFFFFFAF3),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFEADFCE)),
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
                      color: Color(0xFF8A8D8F),
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
  backend.VeevaClientSettings clientSettings =
      const backend.VeevaClientSettings();
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
  final activityRecords = <backend.VeevaActivityRecord>[];
  final memberRewards = <backend.VeevaMemberReward>[];
  final employeeLinks = <backend.VeevaEmployeeActivityLink>[];
  final employeeAttributions = <backend.VeevaMemberEmployeeAttribution>[];
  Timer? _backendRefreshTimer;

  @override
  void initState() {
    super.initState();
    _loadBackend();
    _backendRefreshTimer = Timer.periodic(
      const Duration(seconds: 20),
      (_) => unawaited(_loadBackend(showLoading: false)),
    );
  }

  @override
  void dispose() {
    _backendRefreshTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadBackend({bool showLoading = true}) async {
    if (showLoading) {
      setState(() {
        isLoading = true;
        backendError = null;
      });
    }
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
        clientSettings = bootstrap.clientSettings;
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
        if (shouldUseBackendUserData || bootstrap.activityRecords.isNotEmpty) {
          activityRecords
            ..clear()
            ..addAll(bootstrap.activityRecords);
        }
        if (shouldUseBackendUserData || bootstrap.memberRewards.isNotEmpty) {
          memberRewards
            ..clear()
            ..addAll(bootstrap.memberRewards);
        }
        if (shouldUseBackendUserData || bootstrap.employeeLinks.isNotEmpty) {
          employeeLinks
            ..clear()
            ..addAll(bootstrap.employeeLinks);
        }
        if (shouldUseBackendUserData ||
            bootstrap.employeeAttributions.isNotEmpty) {
          employeeAttributions
            ..clear()
            ..addAll(bootstrap.employeeAttributions);
        }
        isLoading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        backendError = 'Firebase 尚未可用，暫時顯示示範資料。';
        if (showLoading) {
          isLoading = false;
        }
      });
    }
  }

  void _selectTab(AdminTab value) {
    setState(() => tab = value);
    if (value == AdminTab.members) {
      unawaited(_loadBackend(showLoading: false));
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
              _selectTab(value);
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
            onSelected: _selectTab,
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
      AdminTab.rewardDistribution => '獎勵發放',
      AdminTab.news => '最新資訊管理',
      AdminTab.rewards => '兌換券管理',
      AdminTab.permissions => '權限管理',
      AdminTab.employees => '員工管理',
      AdminTab.settings => '系統設定',
    };
  }

  IconData? _titleIconFor(AdminTab tab) {
    return switch (tab) {
      AdminTab.permissions => Icons.verified_user_outlined,
      AdminTab.employees => Icons.badge_outlined,
      _ => null,
    };
  }

  Widget _buildContent() {
    final content = switch (tab) {
      AdminTab.dashboard => _DashboardContent(
          rewards: rewards,
          members: members,
          activityRecords: activityRecords,
        ),
      AdminTab.members => _MemberManagement(
          activities: activities,
          members: members,
          reviews: reviews,
          rewards: rewards,
          memberRewards: memberRewards,
          activityRecords: activityRecords,
          adminUsers: adminUsers,
          onApprove: _approveReview,
          onSaveMemberSettings: _saveMemberSettings,
          onDeleteMember: _deleteMember,
          onGrantReward: _grantRewardToMember,
          onSaveReviewRewardDecision: _saveReviewRewardDecision,
        ),
      AdminTab.activities => _ActivityManagement(
          activities: activities,
          onCreate: () => _showActivityDialog(),
          onEdit: (activity) => _showActivityDialog(activity: activity),
          onToggleActive: _toggleActivityActive,
          onArchive: _archiveActivity,
        ),
      AdminTab.rewardDistribution => _RewardDistributionManagement(
          activities: activities,
          rewards: rewards,
          members: members,
          activityRecords: activityRecords,
          memberRewards: memberRewards,
          onGrantReward: _grantRewardToMember,
          onRejectActivityCompletion: _rejectActivityCompletion,
        ),
      AdminTab.news => _NewsManagement(
          news: news,
          newsEnabled: clientSettings.newsEnabled,
          onCreate: () => _showNewsDialog(),
          onEdit: (item) => _showNewsDialog(newsItem: item),
          onStatusChanged: _setNewsStatus,
          onNewsEnabledChanged: _setNewsEnabled,
        ),
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
      AdminTab.employees => _EmployeeManagement(
          members: members,
          activities: activities,
          activityRecords: activityRecords,
          employeeLinks: employeeLinks,
          employeeAttributions: employeeAttributions,
          onSaveEmployeeStatus: _saveEmployeeStatus,
          onCreateEmployeeActivityLink: _createEmployeeActivityLink,
        ),
      AdminTab.settings => const _PlaceholderPanel(
          icon: Icons.settings_outlined,
          title: '系統設定',
          description: '後續如有額外新增功能，會在此頁新增',
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

  Future<void> _saveReviewRewardDecision({
    required backend.VeevaMember member,
    required ReviewRewardIssueStatus rewardIssueStatus,
    String? reason,
  }) async {
    final previousReviews = [...reviews];
    final statusName = _reviewRewardIssueStatusName(rewardIssueStatus);
    final memberIds = {
      member.id,
      if (member.lineUserId != null && member.lineUserId!.trim().isNotEmpty)
        member.lineUserId!.trim(),
    };
    final trimmedReason = reason?.trim();

    setState(() {
      final index = reviews.indexWhere(
        (item) =>
            memberIds.contains(item.id) || memberIds.contains(item.memberId),
      );
      if (index == -1) {
        reviews.add(
          AdminReviewItem(
            id: member.id,
            memberId: member.id,
            name: member.name,
            hospital: member.hospital,
            department: member.department,
            completedAt: _formatAdminDateTime(DateTime.now()),
            status: ReviewStatus.approved,
            rewardIssueStatus: statusName,
            rewardIssueReason:
                rewardIssueStatus == ReviewRewardIssueStatus.notIssued
                    ? trimmedReason
                    : null,
          ),
        );
      } else {
        reviews[index].status = ReviewStatus.approved;
        reviews[index].rewardIssueStatus = statusName;
        reviews[index].rewardIssueReason =
            rewardIssueStatus == ReviewRewardIssueStatus.notIssued
                ? trimmedReason
                : null;
      }
      backendError = null;
    });

    try {
      await repository.saveReviewRewardDecision(
        member: member,
        rewardIssueStatus: statusName,
        reason: trimmedReason,
      );
    } catch (_) {
      if (!mounted) return;
      setState(() {
        reviews
          ..clear()
          ..addAll(previousReviews);
        backendError = '審核發放狀態更新失敗：請確認 Firestore rules 已部署。';
      });
      rethrow;
    }
  }

  Future<void> _rejectActivityCompletion(
    backend.VeevaActivityRecord record,
  ) async {
    final previousRecords = [...activityRecords];
    final previousMemberRewards = [...memberRewards];
    final rejectedRecord = backend.VeevaActivityRecord(
      id: record.id,
      activityId: record.activityId,
      activityTitle: record.activityTitle,
      activityType: record.activityType,
      memberId: record.memberId,
      memberName: record.memberName,
      memberAvatarUrl: record.memberAvatarUrl,
      memberLineUserId: record.memberLineUserId,
      status: 'rejected',
      registeredAt: record.registeredAt,
      updatedAt: DateTime.now(),
    );

    setState(() {
      final index = activityRecords.indexWhere((item) => item.id == record.id);
      if (index == -1) {
        activityRecords.add(rejectedRecord);
      } else {
        activityRecords[index] = rejectedRecord;
      }
      memberRewards.removeWhere((item) {
        if (item.status != 'pending' || item.activityId != record.activityId) {
          return false;
        }
        final isParticipantReward = item.source == 'activityCompletion' &&
            item.memberId == record.memberId;
        final isReferrerReward = item.source == 'referralActivityCompletion' &&
            item.sourceMemberId == record.memberId;
        return isParticipantReward || isReferrerReward;
      });
      backendError = null;
    });

    try {
      await repository.rejectActivityCompletion(record);
    } catch (_) {
      if (!mounted) return;
      setState(() {
        activityRecords
          ..clear()
          ..addAll(previousRecords);
        memberRewards
          ..clear()
          ..addAll(previousMemberRewards);
        backendError = '不允許更新失敗：請確認 Firestore rules 已部署。';
      });
      rethrow;
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
      completionRewardId: activity.completionRewardId,
      referrerRewardId: activity.referrerRewardId,
      status: backend.VeevaContentStatus.published,
      active: !activity.active,
      periodText: activity.periodText,
      location: activity.location,
      activityTime: activity.activityTime,
      organizer: activity.organizer,
      note: activity.note,
      noticeItems: activity.noticeItems,
      imageUrl: activity.imageUrl,
      shareImageUrl: activity.shareImageUrl,
      surveyUrl: activity.surveyUrl,
      actionUrl: activity.actionUrl,
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
      completionRewardId: activity.completionRewardId,
      referrerRewardId: activity.referrerRewardId,
      status: backend.VeevaContentStatus.archived,
      active: false,
      periodText: activity.periodText,
      location: activity.location,
      activityTime: activity.activityTime,
      organizer: activity.organizer,
      note: activity.note,
      noticeItems: activity.noticeItems,
      imageUrl: activity.imageUrl,
      shareImageUrl: activity.shareImageUrl,
      surveyUrl: activity.surveyUrl,
      actionUrl: activity.actionUrl,
    );
    await _saveActivity(updated);
  }

  Future<void> _showActivityDialog({backend.VeevaActivity? activity}) async {
    final isEditing = activity != null;
    final activityId = activity?.id ?? createVeevaId('activity');
    const noRewardValue = '__no_reward__';
    final labelOptions = <String>[
      '限時活動',
      '即將開始',
      '報名中',
      '會員限定',
      '問卷活動',
      '活動報名',
      '任務活動',
      '簽到活動',
      '外部連結',
      '邀請好友',
    ];
    final currentLabel = activity?.label.trim();
    if (currentLabel != null &&
        currentLabel.isNotEmpty &&
        !labelOptions.contains(currentLabel)) {
      labelOptions.insert(0, currentLabel);
    }
    var selectedLabel =
        currentLabel?.isNotEmpty == true ? currentLabel! : labelOptions.first;
    final titleController = TextEditingController(text: activity?.title ?? '');
    final descriptionController =
        TextEditingController(text: activity?.description ?? '');
    final rewardController =
        TextEditingController(text: activity?.reward ?? '咖啡券');
    final rewardOptions = rewards
        .where((reward) => reward.status != RewardStatus.expired)
        .toList();
    var selectedCompletionRewardId = activity?.completionRewardId;
    var selectedReferrerRewardId = activity?.referrerRewardId;
    var enableReferrerReward = selectedReferrerRewardId != null &&
        selectedReferrerRewardId.trim().isNotEmpty;
    if ((rewardController.text.trim().isEmpty ||
            rewardController.text == '咖啡券') &&
        selectedCompletionRewardId != null) {
      for (final reward in rewardOptions) {
        if (reward.id == selectedCompletionRewardId) {
          rewardController.text = reward.name;
          break;
        }
      }
    }
    final periodController =
        TextEditingController(text: activity?.periodText ?? '');
    final locationController =
        TextEditingController(text: activity?.location ?? '');
    final activityTimeController =
        TextEditingController(text: activity?.activityTime ?? '');
    final organizerController =
        TextEditingController(text: activity?.organizer ?? 'VeeVa Member');
    final noteController = TextEditingController(text: activity?.note ?? '');
    final noticeItemsController = TextEditingController(
      text: activity == null ? '' : activity.noticeItems.join('\n'),
    );
    final imageController =
        TextEditingController(text: activity?.imageUrl ?? '');
    final shareImageController =
        TextEditingController(text: activity?.shareImageUrl ?? '');
    final surveyUrlController = TextEditingController(
        text: activity?.surveyUrl ?? defaultVeevaSurveyUrl);
    final actionUrlController = TextEditingController(
      text: activity?.actionUrl ??
          (activity != null && activity.type != backend.VeevaActivityType.survey
              ? activity.surveyUrl ?? ''
              : ''),
    );
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
            String rewardNameFor(String? rewardId) {
              if (rewardId == null || rewardId.trim().isEmpty) {
                return '不發放';
              }
              for (final reward in rewardOptions) {
                if (reward.id == rewardId) {
                  return reward.name;
                }
              }
              return rewardId;
            }

            backend.VeevaActivity buildActivity({required bool draft}) {
              final isDraft = draft && !isEditing;
              final title = _fallbackText(
                titleController.text,
                isDraft ? '未命名活動' : '',
              );
              final description = _fallbackText(
                descriptionController.text,
                isDraft ? '尚未填寫活動概述。' : '',
              );
              final reward = _fallbackText(
                rewardController.text,
                activityType == backend.VeevaActivityType.registration
                    ? '活動報名'
                    : '兌換券',
              );
              final surveyUrl = _optionalText(surveyUrlController.text);
              final actionUrl = _optionalText(actionUrlController.text);
              final savedStatus =
                  isDraft ? backend.VeevaContentStatus.draft : status;
              return backend.VeevaActivity(
                id: activityId,
                type: activityType,
                label: selectedLabel,
                title: title,
                description: description,
                reward: reward,
                completionRewardId: selectedCompletionRewardId,
                referrerRewardId:
                    enableReferrerReward ? selectedReferrerRewardId : null,
                status: active && !isDraft
                    ? backend.VeevaContentStatus.published
                    : savedStatus,
                active: active && !isDraft,
                periodText: _optionalText(periodController.text),
                location: _optionalText(locationController.text),
                activityTime: _optionalText(activityTimeController.text),
                organizer: _optionalText(organizerController.text),
                note: _optionalText(noteController.text),
                noticeItems: _stringLines(noticeItemsController.text),
                imageUrl: _optionalText(imageController.text),
                shareImageUrl: _optionalText(shareImageController.text),
                surveyUrl: activityType == backend.VeevaActivityType.survey
                    ? surveyUrl
                    : null,
                actionUrl: activityType == backend.VeevaActivityType.external ||
                        activityType == backend.VeevaActivityType.task
                    ? actionUrl
                    : null,
              );
            }

            bool validate({required bool draft}) {
              final title = titleController.text.trim();
              final description = descriptionController.text.trim();
              final surveyUrl = _optionalText(surveyUrlController.text);
              final actionUrl = _optionalText(actionUrlController.text);
              if (!draft && (title.isEmpty || description.isEmpty)) {
                setDialogState(() => formError = '請至少填寫活動名稱與活動概述。');
                return false;
              }
              if (!draft &&
                  selectedCompletionRewardId != null &&
                  selectedCompletionRewardId!.isNotEmpty &&
                  !rewardOptions.any(
                    (reward) => reward.id == selectedCompletionRewardId,
                  )) {
                setDialogState(() => formError = '請選擇正確的完成任務獎勵兌換券。');
                return false;
              }
              if (!draft &&
                  enableReferrerReward &&
                  (selectedReferrerRewardId == null ||
                      selectedReferrerRewardId!.isEmpty ||
                      !rewardOptions.any(
                        (reward) => reward.id == selectedReferrerRewardId,
                      ))) {
                setDialogState(() => formError = '請選擇邀請者加碼獎勵兌換券。');
                return false;
              }
              if (!draft &&
                  activityType == backend.VeevaActivityType.survey &&
                  !_isHttpUrl(surveyUrl)) {
                setDialogState(() => formError = '問卷活動請填入正確的活動網址。');
                return false;
              }
              if (!draft &&
                  (activityType == backend.VeevaActivityType.external ||
                      activityType == backend.VeevaActivityType.task) &&
                  !_isHttpUrl(actionUrl)) {
                setDialogState(() => formError = '外部連結或任務活動請填入正確的操作連結。');
                return false;
              }
              setDialogState(() => formError = null);
              return true;
            }

            void previewActivity() {
              final preview = buildActivity(draft: true);
              showDialog<void>(
                context: dialogContext,
                builder: (previewContext) {
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
                                _ActivityStatusChip(activity: preview),
                                const SizedBox(width: 8),
                                Text(
                                  preview.label,
                                  style: const TextStyle(
                                    color: Color(0xFF8A8D8F),
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 14),
                            Text(
                              preview.title,
                              style: const TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            const SizedBox(height: 14),
                            _ActivityDetailLine(
                              icon: Icons.notes_outlined,
                              label: '活動概述',
                              value: preview.description,
                            ),
                            if (preview.note?.isNotEmpty == true)
                              _ActivityDetailLine(
                                icon: Icons.sticky_note_2_outlined,
                                label: '活動內容',
                                value: preview.note!,
                              ),
                            _ActivityDetailLine(
                              icon: Icons.redeem_outlined,
                              label: '完成獎勵',
                              value: rewardNameFor(preview.completionRewardId),
                            ),
                            _ActivityDetailLine(
                              icon: Icons.group_add_outlined,
                              label: '邀請者獎勵',
                              value: rewardNameFor(preview.referrerRewardId),
                            ),
                            _ActivityDetailLine(
                              icon: _activityTypeIcon(preview.type),
                              label: '類型',
                              value: _activityTypeLabel(preview.type),
                            ),
                            _ActivityDetailLine(
                              icon: Icons.date_range_outlined,
                              label: '活動日期',
                              value: preview.periodText ?? '未設定',
                            ),
                            _ActivityDetailLine(
                              icon: Icons.schedule_outlined,
                              label: '時間',
                              value: preview.activityTime ?? '依活動公告為準',
                            ),
                            _ActivityDetailLine(
                              icon: Icons.place_outlined,
                              label: '地點',
                              value: preview.location ?? '依活動類型預設',
                            ),
                            _ActivityDetailLine(
                              icon: Icons.apartment_outlined,
                              label: '主辦單位',
                              value: preview.organizer ?? 'VeeVa Member',
                            ),
                            if (preview.noticeItems.isNotEmpty)
                              _ActivityDetailLine(
                                icon: Icons.info_outline,
                                label: '注意事項',
                                value: preview.noticeItems.join('、'),
                              ),
                          ],
                        ),
                      ),
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.of(previewContext).pop(),
                        child: const Text('關閉'),
                      ),
                    ],
                  );
                },
              );
            }

            void saveActivity({required bool draft}) {
              if (!validate(draft: draft)) {
                return;
              }
              pendingActivity = buildActivity(draft: draft);
              Navigator.of(dialogContext).pop();
            }

            final size = MediaQuery.sizeOf(context);
            final horizontalInset = size.width < 760 ? 10.0 : 36.0;
            final verticalInset = size.height < 760 ? 10.0 : 24.0;
            final dialogWidth =
                (size.width - horizontalInset * 2).clamp(360.0, 1060.0);
            final dialogHeight =
                (size.height - verticalInset * 2).clamp(560.0, 920.0);

            return Dialog(
              insetPadding: EdgeInsets.symmetric(
                horizontal: horizontalInset,
                vertical: verticalInset,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              clipBehavior: Clip.antiAlias,
              child: SizedBox(
                width: dialogWidth.toDouble(),
                height: dialogHeight.toDouble(),
                child: Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.fromLTRB(28, 22, 28, 20),
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        border: Border(
                          bottom: BorderSide(color: Color(0xFFEADFCE)),
                        ),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  isEditing ? '編輯活動' : '新增活動',
                                  style: const TextStyle(
                                    color: Color(0xFF303236),
                                    fontSize: 28,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                const Text(
                                  '新增一個活動並設定相關資訊，帶給會員更好的活動體驗。',
                                  style: TextStyle(
                                    color: Color(0xFF8A8D8F),
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          OutlinedButton.icon(
                            onPressed: previewActivity,
                            icon: const Icon(Icons.visibility_outlined),
                            label: const Text('預覽'),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: const Color(0xFF303236),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 22,
                                vertical: 16,
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          FilledButton.icon(
                            onPressed: () => saveActivity(draft: !isEditing),
                            icon: Icon(
                              isEditing
                                  ? Icons.save_outlined
                                  : Icons.edit_note_outlined,
                            ),
                            label: Text(isEditing ? '儲存' : '儲存草稿'),
                            style: FilledButton.styleFrom(
                              backgroundColor: const Color(0xFFFF9812),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 24,
                                vertical: 16,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          IconButton(
                            tooltip: '關閉',
                            onPressed: () => Navigator.of(dialogContext).pop(),
                            icon: const Icon(Icons.close),
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.all(28),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            if (formError != null) ...[
                              _InlineError(message: formError!),
                              const SizedBox(height: 14),
                            ],
                            _ActivityFormSection(
                              number: 1,
                              title: '基本資訊',
                              child: LayoutBuilder(
                                builder: (context, constraints) {
                                  final twoColumns =
                                      constraints.maxWidth >= 760;
                                  final typeField = Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      const _ActivityFieldLabel(
                                        text: '活動類型',
                                        required: true,
                                      ),
                                      DropdownButtonFormField<
                                          backend.VeevaActivityType>(
                                        value: activityType,
                                        decoration: _activityInputDecoration(
                                          hintText: '請選擇活動類型',
                                          icon: Icons.category_outlined,
                                        ),
                                        items: [
                                          for (final type in backend
                                              .VeevaActivityType.values)
                                            DropdownMenuItem(
                                              value: type,
                                              child: Text(
                                                  _activityTypeLabel(type)),
                                            ),
                                        ],
                                        onChanged: (value) {
                                          if (value == null) return;
                                          setDialogState(() {
                                            activityType = value;
                                            if (value ==
                                                    backend.VeevaActivityType
                                                        .registration &&
                                                rewardController.text.trim() ==
                                                    '咖啡券') {
                                              rewardController.text = '活動報名';
                                            }
                                            if (value ==
                                                    backend.VeevaActivityType
                                                        .survey &&
                                                surveyUrlController.text
                                                    .trim()
                                                    .isEmpty) {
                                              surveyUrlController.text =
                                                  defaultVeevaSurveyUrl;
                                            }
                                          });
                                        },
                                      ),
                                    ],
                                  );
                                  final labelField = Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      const _ActivityFieldLabel(
                                        text: '活動標籤',
                                        required: true,
                                      ),
                                      DropdownButtonFormField<String>(
                                        value: selectedLabel,
                                        decoration: _activityInputDecoration(
                                          hintText: '請選擇活動標籤',
                                          icon: Icons.label_outline,
                                        ),
                                        items: [
                                          for (final option in labelOptions)
                                            DropdownMenuItem(
                                              value: option,
                                              child: Text(option),
                                            ),
                                        ],
                                        onChanged: (value) {
                                          if (value == null) return;
                                          setDialogState(
                                              () => selectedLabel = value);
                                        },
                                      ),
                                    ],
                                  );
                                  final linkField = activityType ==
                                          backend.VeevaActivityType.survey
                                      ? Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            const _ActivityFieldLabel(
                                              text: '問卷網址',
                                              required: true,
                                            ),
                                            TextField(
                                              controller: surveyUrlController,
                                              keyboardType: TextInputType.url,
                                              decoration:
                                                  _activityInputDecoration(
                                                hintText: 'https://',
                                                icon: Icons.link_outlined,
                                                helperText: '會員點擊填寫問卷後會開啟此網址。',
                                              ),
                                            ),
                                          ],
                                        )
                                      : Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            _ActivityFieldLabel(
                                              text: activityType ==
                                                          backend
                                                              .VeevaActivityType
                                                              .external ||
                                                      activityType ==
                                                          backend
                                                              .VeevaActivityType
                                                              .task
                                                  ? '操作連結'
                                                  : '外部連結',
                                              required: activityType ==
                                                      backend.VeevaActivityType
                                                          .external ||
                                                  activityType ==
                                                      backend.VeevaActivityType
                                                          .task,
                                            ),
                                            TextField(
                                              controller: actionUrlController,
                                              keyboardType: TextInputType.url,
                                              decoration:
                                                  _activityInputDecoration(
                                                hintText: 'https://',
                                                icon: Icons.link_outlined,
                                                helperText: activityType ==
                                                            backend
                                                                .VeevaActivityType
                                                                .external ||
                                                        activityType ==
                                                            backend
                                                                .VeevaActivityType
                                                                .task
                                                    ? '會員點擊主按鈕後會開啟此連結。'
                                                    : '選填，目前此活動類型不會自動開啟外部連結。',
                                              ),
                                            ),
                                          ],
                                        );
                                  return Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.stretch,
                                    children: [
                                      if (twoColumns)
                                        Row(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Expanded(child: typeField),
                                            const SizedBox(width: 26),
                                            Expanded(child: labelField),
                                          ],
                                        )
                                      else ...[
                                        typeField,
                                        const SizedBox(height: 16),
                                        labelField,
                                      ],
                                      const SizedBox(height: 16),
                                      const _ActivityFieldLabel(
                                        text: '活動名稱',
                                        required: true,
                                      ),
                                      TextField(
                                        controller: titleController,
                                        maxLength: 100,
                                        decoration: _activityInputDecoration(
                                          hintText: '請輸入活動名稱',
                                          icon: Icons.campaign_outlined,
                                        ),
                                      ),
                                      const SizedBox(height: 10),
                                      linkField,
                                      const SizedBox(height: 16),
                                      const _ActivityFieldLabel(text: '活動概述'),
                                      TextField(
                                        controller: descriptionController,
                                        minLines: 3,
                                        maxLines: 5,
                                        maxLength: 500,
                                        decoration: _activityInputDecoration(
                                          hintText: '請輸入活動列表與上方摘要使用的活動概述...',
                                          icon: Icons.notes_outlined,
                                        ),
                                      ),
                                      const SizedBox(height: 16),
                                      const _ActivityFieldLabel(text: '活動內容'),
                                      TextField(
                                        controller: noteController,
                                        minLines: 4,
                                        maxLines: 7,
                                        maxLength: 600,
                                        decoration: _activityInputDecoration(
                                          hintText: '請輸入活動詳情頁「活動內容」區塊文字...',
                                          icon: Icons.sticky_note_2_outlined,
                                        ),
                                      ),
                                      const SizedBox(height: 16),
                                      const _ActivityFieldLabel(text: '注意事項'),
                                      TextField(
                                        controller: noticeItemsController,
                                        minLines: 4,
                                        maxLines: 6,
                                        maxLength: 400,
                                        decoration: _activityInputDecoration(
                                          hintText:
                                              '每行一項，例如：\n本活動名額有限，請盡早完成報名。\n如有任何問題，請聯繫主辦單位。',
                                          icon: Icons.info_outline,
                                          helperText: '前台「注意事項」會依照每一行顯示為一個項目。',
                                        ),
                                      ),
                                    ],
                                  );
                                },
                              ),
                            ),
                            _ActivityFormSection(
                              number: 2,
                              title: '活動資訊',
                              child: LayoutBuilder(
                                builder: (context, constraints) {
                                  final twoColumns =
                                      constraints.maxWidth >= 760;
                                  final rewardField = Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      const _ActivityFieldLabel(text: '獎勵內容'),
                                      TextField(
                                        controller: rewardController,
                                        decoration: _activityInputDecoration(
                                          hintText: '例如：星巴克美式冰咖啡',
                                          icon: Icons.card_giftcard_outlined,
                                        ),
                                      ),
                                    ],
                                  );
                                  final periodField = Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      const _ActivityFieldLabel(text: '活動日期'),
                                      TextField(
                                        controller: periodController,
                                        decoration: _activityInputDecoration(
                                          hintText:
                                              '例如：2026/06/15 - 2026/07/15',
                                          icon: Icons.calendar_month_outlined,
                                          suffixIcon: const Icon(
                                            Icons.event_outlined,
                                            size: 20,
                                          ),
                                        ),
                                      ),
                                    ],
                                  );
                                  final timeField = Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      const _ActivityFieldLabel(text: '活動時間'),
                                      TextField(
                                        controller: activityTimeController,
                                        decoration: _activityInputDecoration(
                                          hintText: '例如：09:00 - 17:00',
                                          icon: Icons.schedule_outlined,
                                        ),
                                      ),
                                    ],
                                  );
                                  final locationField = Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      const _ActivityFieldLabel(text: '活動地點'),
                                      TextField(
                                        controller: locationController,
                                        decoration: _activityInputDecoration(
                                          hintText: '例如：台北國際會議中心 201 會議室',
                                          icon: Icons.place_outlined,
                                          helperText: '前台活動列表與活動資訊頁都會顯示此地點。',
                                        ),
                                      ),
                                    ],
                                  );
                                  final organizerField = Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      const _ActivityFieldLabel(text: '主辦單位'),
                                      TextField(
                                        controller: organizerController,
                                        decoration: _activityInputDecoration(
                                          hintText: '例如：台灣醫學會',
                                          icon: Icons.apartment_outlined,
                                        ),
                                      ),
                                    ],
                                  );
                                  return Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.stretch,
                                    children: [
                                      if (twoColumns)
                                        Row(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Expanded(child: rewardField),
                                            const SizedBox(width: 26),
                                            Expanded(child: periodField),
                                          ],
                                        )
                                      else ...[
                                        rewardField,
                                        const SizedBox(height: 16),
                                        periodField,
                                      ],
                                      const SizedBox(height: 16),
                                      if (twoColumns)
                                        Row(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Expanded(child: timeField),
                                            const SizedBox(width: 26),
                                            Expanded(child: locationField),
                                          ],
                                        )
                                      else ...[
                                        timeField,
                                        const SizedBox(height: 16),
                                        locationField,
                                      ],
                                      const SizedBox(height: 16),
                                      organizerField,
                                      const SizedBox(height: 18),
                                      const _ActivityFieldLabel(
                                        text: '獎勵設定',
                                      ),
                                      Container(
                                        padding: const EdgeInsets.all(16),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFFFFFAF3),
                                          border: Border.all(
                                            color: const Color(0xFFEADFCE),
                                          ),
                                          borderRadius:
                                              BorderRadius.circular(8),
                                        ),
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.stretch,
                                          children: [
                                            DropdownButtonFormField<String>(
                                              value: selectedCompletionRewardId !=
                                                          null &&
                                                      rewardOptions.any(
                                                        (reward) =>
                                                            reward.id ==
                                                            selectedCompletionRewardId,
                                                      )
                                                  ? selectedCompletionRewardId
                                                  : noRewardValue,
                                              decoration:
                                                  _activityInputDecoration(
                                                labelText: '完成任務獎勵',
                                                hintText: '不發放兌換券',
                                                icon: Icons
                                                    .confirmation_number_outlined,
                                                helperText:
                                                    '會員完成活動或問卷後，發放給會員本人。',
                                              ),
                                              items: [
                                                const DropdownMenuItem(
                                                  value: noRewardValue,
                                                  child: Text('不發放兌換券'),
                                                ),
                                                for (final reward
                                                    in rewardOptions)
                                                  DropdownMenuItem(
                                                    value: reward.id,
                                                    child: Text(
                                                      '${reward.name}（${reward.category}）',
                                                    ),
                                                  ),
                                              ],
                                              onChanged: (value) {
                                                if (value == null) return;
                                                if (value == noRewardValue) {
                                                  setDialogState(() {
                                                    selectedCompletionRewardId =
                                                        null;
                                                  });
                                                  return;
                                                }
                                                final selectedReward =
                                                    rewardOptions.firstWhere(
                                                  (reward) =>
                                                      reward.id == value,
                                                );
                                                setDialogState(() {
                                                  selectedCompletionRewardId =
                                                      value;
                                                  rewardController.text =
                                                      selectedReward.name;
                                                });
                                              },
                                            ),
                                            const SizedBox(height: 14),
                                            SwitchListTile.adaptive(
                                              contentPadding: EdgeInsets.zero,
                                              value: enableReferrerReward,
                                              activeColor:
                                                  const Color(0xFFFF9812),
                                              title: const Text(
                                                '啟用邀請者加碼獎勵',
                                                style: TextStyle(
                                                  fontWeight: FontWeight.w900,
                                                ),
                                              ),
                                              subtitle: const Text(
                                                '朋友透過邀請連結加入並完成此活動後，發放給原邀請者。',
                                              ),
                                              onChanged: (value) {
                                                setDialogState(() {
                                                  enableReferrerReward = value;
                                                  if (!value) {
                                                    selectedReferrerRewardId =
                                                        null;
                                                  }
                                                });
                                              },
                                            ),
                                            if (enableReferrerReward) ...[
                                              const SizedBox(height: 10),
                                              DropdownButtonFormField<String>(
                                                value: selectedReferrerRewardId !=
                                                            null &&
                                                        rewardOptions.any(
                                                          (reward) =>
                                                              reward.id ==
                                                              selectedReferrerRewardId,
                                                        )
                                                    ? selectedReferrerRewardId
                                                    : noRewardValue,
                                                decoration:
                                                    _activityInputDecoration(
                                                  labelText: '邀請者加碼獎勵',
                                                  hintText: '請選擇兌換券',
                                                  icon:
                                                      Icons.group_add_outlined,
                                                  helperText: '只有啟用二段式獎勵時才會發放。',
                                                ),
                                                items: [
                                                  const DropdownMenuItem(
                                                    value: noRewardValue,
                                                    child: Text('請選擇兌換券'),
                                                  ),
                                                  for (final reward
                                                      in rewardOptions)
                                                    DropdownMenuItem(
                                                      value: reward.id,
                                                      child: Text(
                                                        '${reward.name}（${reward.category}）',
                                                      ),
                                                    ),
                                                ],
                                                onChanged: (value) {
                                                  if (value == null) return;
                                                  setDialogState(() {
                                                    selectedReferrerRewardId =
                                                        value == noRewardValue
                                                            ? null
                                                            : value;
                                                  });
                                                },
                                              ),
                                            ],
                                          ],
                                        ),
                                      ),
                                    ],
                                  );
                                },
                              ),
                            ),
                            _ActivityFormSection(
                              number: 3,
                              title: '活動圖片',
                              child: _ActivityImageUploadSection(
                                controller: imageController,
                                shareController: shareImageController,
                                storageFolder:
                                    'public/activities/$activityId/cover',
                                onUpload: repository.uploadImage,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
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
    titleController.dispose();
    descriptionController.dispose();
    rewardController.dispose();
    periodController.dispose();
    locationController.dispose();
    activityTimeController.dispose();
    organizerController.dispose();
    noteController.dispose();
    noticeItemsController.dispose();
    imageController.dispose();
    surveyUrlController.dispose();
    actionUrlController.dispose();
  }

  Future<void> _saveNews(
    backend.VeevaNews newsItem, {
    String errorMessage = '最新資訊儲存失敗：請確認 Firestore API 與 rules 已啟用。',
  }) async {
    final index = news.indexWhere((item) => item.id == newsItem.id);
    final previous = index == -1 ? null : news[index];
    setState(() {
      backendError = null;
      if (index == -1) {
        news.insert(0, newsItem);
      } else {
        news[index] = newsItem;
      }
    });
    try {
      await repository.saveNews(newsItem);
    } catch (_) {
      if (!mounted) return;
      setState(() {
        if (previous == null) {
          news.removeWhere((item) => item.id == newsItem.id);
        } else if (index != -1) {
          news[index] = previous;
        }
        backendError = errorMessage;
      });
    }
  }

  Future<void> _setNewsEnabled(bool enabled) async {
    final previous = clientSettings;
    final next = backend.VeevaClientSettings(newsEnabled: enabled);
    setState(() {
      clientSettings = next;
      backendError = null;
    });

    try {
      await repository.saveClientSettings(next);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(enabled ? '前端已顯示最新資訊頁面。' : '前端已隱藏最新資訊頁面。'),
        ),
      );
    } catch (_) {
      if (!mounted) return;
      setState(() {
        clientSettings = previous;
        backendError = '最新資訊頁面顯示設定更新失敗：請確認 Firestore rules 已部署。';
      });
    }
  }

  Future<void> _setNewsStatus(
    backend.VeevaNews newsItem,
    backend.VeevaContentStatus status,
  ) async {
    final updated = backend.VeevaNews(
      id: newsItem.id,
      date: newsItem.date,
      source: newsItem.source,
      title: newsItem.title,
      summary: newsItem.summary,
      status: status,
      category: newsItem.category,
      imageUrl: newsItem.imageUrl,
      content: newsItem.content,
      detailContent: newsItem.detailContent,
      keyPoints: newsItem.keyPoints,
      externalUrl: newsItem.externalUrl,
      helpfulCount: newsItem.helpfulCount,
    );
    await _saveNews(
      updated,
      errorMessage: '最新資訊狀態更新失敗：請確認 Firestore API 與 rules 已啟用。',
    );
  }

  Future<void> _showNewsDialog({backend.VeevaNews? newsItem}) async {
    final isEditing = newsItem != null;
    final newsId = newsItem?.id ?? createVeevaId('news');
    final titleController = TextEditingController(text: newsItem?.title ?? '');
    final summaryController =
        TextEditingController(text: newsItem?.summary ?? '');
    final contentController = TextEditingController(
      text: newsItem?.detailContent ?? newsItem?.content ?? '',
    );
    final sourceController =
        TextEditingController(text: newsItem?.source ?? 'Veeva');
    final categoryController =
        TextEditingController(text: newsItem?.category ?? '醫療新知');
    final dateController = TextEditingController(
        text: newsItem?.date ?? _formatAdminDate(DateTime.now()));
    final imageController =
        TextEditingController(text: newsItem?.imageUrl ?? '');
    final externalUrlController =
        TextEditingController(text: newsItem?.externalUrl ?? '');
    final initialStatus =
        newsItem?.status ?? backend.VeevaContentStatus.published;

    final newsToSave = await showDialog<backend.VeevaNews>(
      context: context,
      builder: (dialogContext) {
        return _NewsEditorDialog(
          newsItem: newsItem,
          newsId: newsId,
          isEditing: isEditing,
          titleController: titleController,
          summaryController: summaryController,
          contentController: contentController,
          sourceController: sourceController,
          categoryController: categoryController,
          dateController: dateController,
          imageController: imageController,
          externalUrlController: externalUrlController,
          initialStatus: initialStatus,
          coverImageStorageFolder: 'public/news/$newsId/cover',
          articleImageStorageFolder: 'public/news/$newsId/content',
          onUploadImage: repository.uploadImage,
        );
      },
    );

    if (newsToSave != null) {
      await _saveNews(newsToSave);
    }

    await Future<void>.delayed(const Duration(milliseconds: 250));
    titleController.dispose();
    summaryController.dispose();
    contentController.dispose();
    sourceController.dispose();
    categoryController.dispose();
    dateController.dispose();
    imageController.dispose();
    externalUrlController.dispose();
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

  Future<void> _importRewardVoucherLinks(
    AdminRewardItem reward,
    ImportedVoucherLinks imported,
  ) async {
    try {
      final added = await repository.importRewardVoucherLinks(
        reward: reward.toBackend(),
        links: imported.links,
        fileName: imported.fileName,
      );
      if (!mounted) return;
      final duplicateCount = imported.count - added;
      final adjustedStock =
          duplicateCount > 0 ? reward.stock - duplicateCount : reward.stock;
      final updatedReward = reward.copyWith(
        stock: adjustedStock < 0 ? 0 : adjustedStock,
        voucherTotal: reward.voucherTotal + added,
        voucherAvailable: reward.voucherAvailable + added,
      );
      await repository.saveReward(updatedReward.toBackend());
      if (!mounted) return;
      setState(() {
        final index = rewards.indexWhere((item) => item.id == reward.id);
        if (index == -1) {
          rewards.insert(0, updatedReward);
        } else {
          rewards[index] = updatedReward;
        }
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            duplicateCount > 0
                ? '已匯入 $added 筆兌換連結，略過 $duplicateCount 筆重複連結。'
                : '已匯入 $added 筆兌換連結。',
          ),
        ),
      );
    } catch (_) {
      if (!mounted) return;
      final rollbackStock = reward.stock - imported.count;
      final rolledBackReward = reward.copyWith(
        stock: rollbackStock < 0 ? 0 : rollbackStock,
      );
      setState(() {
        final index = rewards.indexWhere((item) => item.id == reward.id);
        if (index == -1) {
          rewards.insert(0, rolledBackReward);
        } else {
          rewards[index] = rolledBackReward;
        }
        backendError = '兌換連結匯入失敗：請確認 Firestore rules 已部署。';
      });
      await repository.saveReward(rolledBackReward.toBackend());
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
          phoneNumber: member.phoneNumber,
          phoneVerified: member.phoneVerified,
          phoneVerifiedAt: member.phoneVerifiedAt,
          lineStatusMessage: member.lineStatusMessage,
          lineIdToken: member.lineIdToken,
          lineIdTokenUpdatedAt: member.lineIdTokenUpdatedAt,
          createdAt: member.createdAt,
          lastLineLoginAt: member.lastLineLoginAt,
          referredByMemberId: member.referredByMemberId,
          referredByShareCode: member.referredByShareCode,
          referredAt: member.referredAt,
          referralRewardGrantedActivityId:
              member.referralRewardGrantedActivityId,
          referralRewardGrantedRewardId: member.referralRewardGrantedRewardId,
          referralRewardGrantedReferrerId:
              member.referralRewardGrantedReferrerId,
          referralRewardGrantedAt: member.referralRewardGrantedAt,
          isAdmin: isActive,
          adminRole: isActive ? adminUser.role.name : null,
          isEmployee: member.isEmployee,
          employeeStatus: member.employeeStatus,
          employeeCode: member.employeeCode,
          employeeCreatedAt: member.employeeCreatedAt,
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

  Future<void> _deleteMember(backend.VeevaMember member) async {
    final previousMembers = [...members];
    final previousAdminUsers = [...adminUsers];
    final previousReviews = [...reviews];
    final previousActivityRecords = [...activityRecords];
    final previousMemberRewards = [...memberRewards];
    final previousEmployeeLinks = [...employeeLinks];
    final memberIds = {
      member.id,
      if (member.lineUserId != null && member.lineUserId!.trim().isNotEmpty)
        member.lineUserId!.trim(),
    };

    bool matchesMemberId(String? value) =>
        value != null && memberIds.contains(value);

    setState(() {
      members.removeWhere((item) => memberIds.contains(item.id));
      adminUsers.removeWhere(
        (item) =>
            matchesMemberId(item.id) ||
            matchesMemberId(item.memberId) ||
            matchesMemberId(item.lineUserId),
      );
      reviews.removeWhere(
        (item) => matchesMemberId(item.id) || matchesMemberId(item.memberId),
      );
      activityRecords.removeWhere((item) => matchesMemberId(item.memberId));
      memberRewards.removeWhere(
        (item) =>
            matchesMemberId(item.memberId) ||
            matchesMemberId(item.sourceMemberId),
      );
      employeeLinks.removeWhere(
        (item) => matchesMemberId(item.employeeMemberId),
      );
      backendError = null;
    });

    try {
      await repository
          .deleteMember(member)
          .timeout(const Duration(seconds: 25));
      unawaited(_loadBackend());
    } catch (_) {
      if (!mounted) return;
      setState(() {
        members
          ..clear()
          ..addAll(previousMembers);
        adminUsers
          ..clear()
          ..addAll(previousAdminUsers);
        reviews
          ..clear()
          ..addAll(previousReviews);
        activityRecords
          ..clear()
          ..addAll(previousActivityRecords);
        memberRewards
          ..clear()
          ..addAll(previousMemberRewards);
        employeeLinks
          ..clear()
          ..addAll(previousEmployeeLinks);
        backendError = '會員刪除失敗：請確認 Firestore rules 已部署。';
      });
      rethrow;
    }
  }

  Future<void> _saveEmployeeStatus({
    required backend.VeevaMember member,
    required bool enabled,
  }) async {
    final previousMembers = [...members];
    final updatedMember = _memberWithEmployeeStatus(
      member,
      enabled: enabled,
      employeeCode: member.employeeCode,
      employeeCreatedAt: member.employeeCreatedAt,
    );

    setState(() {
      final index = members.indexWhere((item) => item.id == member.id);
      if (index == -1) {
        members.add(updatedMember);
      } else {
        members[index] = updatedMember;
      }
      backendError = null;
    });

    try {
      await repository.saveEmployeeStatus(member: member, enabled: enabled);
      await _loadBackend();
    } catch (_) {
      if (!mounted) return;
      setState(() {
        members
          ..clear()
          ..addAll(previousMembers);
        backendError = '員工設定更新失敗：請確認 Firestore rules 已部署。';
      });
      rethrow;
    }
  }

  Future<backend.VeevaEmployeeActivityLink> _createEmployeeActivityLink({
    required backend.VeevaMember employee,
    required backend.VeevaActivity activity,
  }) async {
    try {
      final link = await repository.createEmployeeActivityLink(
        employee: employee,
        activity: activity,
      );
      if (mounted) {
        setState(() {
          final index = employeeLinks.indexWhere((item) => item.id == link.id);
          if (index == -1) {
            employeeLinks.add(link);
          } else {
            employeeLinks[index] = link;
          }
          backendError = null;
        });
      }
      return link;
    } catch (_) {
      if (mounted) {
        setState(() => backendError = 'QR Code 建立失敗：請確認 Firestore rules 已部署。');
      }
      rethrow;
    }
  }

  Future<void> _grantRewardToMember({
    required backend.VeevaMember member,
    required AdminRewardItem reward,
    required int quantity,
    String? note,
    backend.VeevaActivity? activity,
    backend.VeevaMember? sourceMember,
    String source = 'manualAdmin',
    bool preventDuplicate = false,
    bool showSnackBar = true,
  }) async {
    if (quantity <= 0) {
      setState(() => backendError = '發送兌換券失敗：數量必須大於 0。');
      throw StateError('invalid quantity');
    }
    if (reward.status != RewardStatus.active || reward.stock < quantity) {
      setState(() => backendError = '發送兌換券失敗：兌換券未上架或庫存不足。');
      throw StateError('reward unavailable');
    }

    final previousMembers = [...members];
    final previousMemberRewards = [...memberRewards];
    final previousActivityRecords = [...activityRecords];
    final previousRewards = [
      for (final item in rewards)
        item.copyWith(
          name: item.name,
          category: item.category,
          stock: item.stock,
          issued: item.issued,
          redeemed: item.redeemed,
          expiresAt: item.expiresAt,
          status: item.status,
        ),
    ];
    final updatedMember = _memberWithEarnedCoupons(
      member,
      earnedCoupons: member.earnedCoupons + quantity,
    );
    final updatedReward = reward.copyWith(
      stock: reward.stock - quantity,
      issued: reward.issued + quantity,
    );
    final now = DateTime.now();
    final newMemberRewards = [
      for (var index = 0; index < quantity; index += 1)
        backend.VeevaMemberReward(
          id: activity == null && quantity != 1
              ? '${member.id}-${reward.id}-${now.millisecondsSinceEpoch}-$index'
              : _rewardGrantDocumentId(
                  memberId: member.id,
                  rewardId: reward.id,
                  activityId:
                      activity?.id ?? now.millisecondsSinceEpoch.toString(),
                  source: source,
                  sourceMemberId: sourceMember?.id,
                ),
          memberId: member.id,
          rewardId: reward.id,
          rewardName: reward.name,
          rewardImageUrl: reward.imageUrl,
          status: 'issued',
          source: source,
          activityId: activity?.id,
          activityTitle: activity?.title,
          sourceMemberId: sourceMember?.id,
          sourceMemberName: sourceMember?.name,
          issuedAt: now,
          expiresAt: _parseAdminDate(reward.expiresAt),
        ),
    ];

    setState(() {
      final memberIndex = members.indexWhere((item) => item.id == member.id);
      if (memberIndex != -1) {
        members[memberIndex] = updatedMember;
      }
      final rewardIndex = rewards.indexWhere((item) => item.id == reward.id);
      if (rewardIndex != -1) {
        rewards[rewardIndex] = updatedReward;
      }
      memberRewards.removeWhere(
        (item) => newMemberRewards.any((newItem) => newItem.id == item.id),
      );
      memberRewards.addAll(newMemberRewards);
      if (source == 'referralActivityCompletion' &&
          sourceMember != null &&
          activity != null) {
        final sourceMemberIndex =
            members.indexWhere((item) => item.id == sourceMember.id);
        if (sourceMemberIndex != -1) {
          members[sourceMemberIndex] = _memberWithReferralRewardGranted(
            members[sourceMemberIndex],
            activityId: activity.id,
            rewardId: reward.id,
            referrerId: member.id,
            grantedAt: now,
          );
        }
      }
      if (source == 'activityCompletion' && activity != null) {
        final recordIndex = activityRecords.indexWhere(
          (item) =>
              item.activityId == activity.id && item.memberId == member.id,
        );
        final completedRecord = backend.VeevaActivityRecord(
          id: _activityCompletionDocumentId(
            memberId: member.id,
            activityId: activity.id,
          ),
          activityId: activity.id,
          activityTitle: activity.title,
          activityType: activity.type.name,
          memberId: member.id,
          memberName: member.name,
          memberAvatarUrl: member.avatarUrl,
          memberLineUserId: member.lineUserId,
          status: 'completed',
          registeredAt: recordIndex == -1
              ? null
              : activityRecords[recordIndex].registeredAt,
          completedAt: recordIndex == -1
              ? now
              : activityRecords[recordIndex].completedAt ?? now,
          updatedAt: now,
        );
        if (recordIndex == -1) {
          activityRecords.add(completedRecord);
        } else {
          activityRecords[recordIndex] = completedRecord;
        }
      }
      backendError = null;
    });

    try {
      await repository.grantRewardToMember(
        member: member,
        reward: reward.toBackend(),
        quantity: quantity,
        note: note,
        activity: activity,
        sourceMember: sourceMember,
        source: source,
        preventDuplicate: preventDuplicate,
      );
      if (!mounted) return;
      if (showSnackBar) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('已發送 ${reward.name} × $quantity 給 ${member.name}。'),
          ),
        );
      }
    } catch (_) {
      if (!mounted) return;
      setState(() {
        members
          ..clear()
          ..addAll(previousMembers);
        memberRewards
          ..clear()
          ..addAll(previousMemberRewards);
        activityRecords
          ..clear()
          ..addAll(previousActivityRecords);
        rewards
          ..clear()
          ..addAll(previousRewards);
        backendError = '發送兌換券失敗：請確認 Firestore rules 已部署，且兌換券庫存足夠。';
      });
      rethrow;
    }
  }

  Future<void> _showRewardDialog({AdminRewardItem? reward}) async {
    final isEditing = reward != null;
    final rewardId = reward?.id ?? createVeevaId('reward');
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
    final voucherImporter = createAdminVoucherImporter();
    ImportedVoucherLinks? pendingVoucherImport;
    var isImportingVouchers = false;
    String? formError;
    AdminRewardItem? pendingReward;

    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            void saveReward() {
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
                setDialogState(() => formError = '兌換期限請使用 YYYY/MM/DD 格式。');
                return;
              }

              pendingReward = AdminRewardItem(
                id: rewardId,
                name: name,
                category: category,
                stock: stock,
                issued: issued,
                redeemed: redeemed,
                expiresAt: expiresAt,
                status: status,
                imageUrl: _optionalText(imageController.text),
                voucherTotal: reward?.voucherTotal ?? 0,
                voucherAvailable: reward?.voucherAvailable ?? 0,
              );
              Navigator.of(dialogContext).pop();
            }

            Future<void> pickVoucherLinks() async {
              setDialogState(() {
                isImportingVouchers = true;
                formError = null;
              });
              try {
                final imported = await voucherImporter.pickVoucherLinks();
                if (imported == null) {
                  setDialogState(() => isImportingVouchers = false);
                  return;
                }
                if (imported.links.isEmpty) {
                  setDialogState(() {
                    isImportingVouchers = false;
                    formError = '檔案內沒有找到 http 或 https 開頭的兌換連結。';
                  });
                  return;
                }
                final currentStock =
                    int.tryParse(stockController.text.trim()) ?? 0;
                final previousPendingCount = pendingVoucherImport?.count ?? 0;
                final defaultNewRewardStock = !isEditing &&
                    previousPendingCount == 0 &&
                    currentStock == 50;
                final baseStock = defaultNewRewardStock
                    ? 0
                    : currentStock - previousPendingCount;
                final nextStock = (baseStock + imported.count).clamp(0, 999999);
                setDialogState(() {
                  pendingVoucherImport = imported;
                  stockController.text = '$nextStock';
                  isImportingVouchers = false;
                });
              } catch (_) {
                setDialogState(() {
                  isImportingVouchers = false;
                  formError = '兌換連結匯入失敗，請確認檔案格式為 .xlsx、.csv 或 .txt。';
                });
              }
            }

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

            final size = MediaQuery.sizeOf(context);
            final horizontalInset = size.width < 760 ? 10.0 : 36.0;
            final verticalInset = size.height < 760 ? 10.0 : 24.0;
            final dialogWidth =
                (size.width - horizontalInset * 2).clamp(360.0, 980.0);
            final dialogHeight =
                (size.height - verticalInset * 2).clamp(560.0, 900.0);

            return Dialog(
              insetPadding: EdgeInsets.symmetric(
                horizontal: horizontalInset,
                vertical: verticalInset,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              clipBehavior: Clip.antiAlias,
              child: SizedBox(
                width: dialogWidth.toDouble(),
                height: dialogHeight.toDouble(),
                child: Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.fromLTRB(28, 22, 24, 20),
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        border: Border(
                          bottom: BorderSide(color: Color(0xFFEADFCE)),
                        ),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  isEditing ? '編輯兌換券' : '新增兌換券',
                                  style: const TextStyle(
                                    color: Color(0xFF303236),
                                    fontSize: 28,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                const Text(
                                  '設定兌換券內容、庫存、兌換期限與圖片。',
                                  style: TextStyle(
                                    color: Color(0xFF8A8D8F),
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          TextButton(
                            onPressed: () => Navigator.of(dialogContext).pop(),
                            child: const Text('取消'),
                          ),
                          const SizedBox(width: 8),
                          FilledButton.icon(
                            onPressed: saveReward,
                            icon: Icon(
                              isEditing ? Icons.save_outlined : Icons.add,
                            ),
                            label: Text(isEditing ? '儲存' : '建立'),
                            style: FilledButton.styleFrom(
                              backgroundColor: const Color(0xFFFF9812),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 24,
                                vertical: 16,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          IconButton(
                            tooltip: '關閉',
                            onPressed: () => Navigator.of(dialogContext).pop(),
                            icon: const Icon(Icons.close),
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.all(28),
                        child: _RewardFormSection(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (formError != null) ...[
                                _InlineError(message: formError!),
                                const SizedBox(height: 18),
                              ],
                              const _ActivityFieldLabel(
                                text: '商品名稱',
                                required: true,
                              ),
                              TextField(
                                controller: nameController,
                                maxLength: 50,
                                decoration: _rewardInputDecoration(
                                  hintText: '請輸入商品名稱',
                                ),
                              ),
                              const SizedBox(height: 14),
                              LayoutBuilder(
                                builder: (context, constraints) {
                                  final twoColumns =
                                      constraints.maxWidth >= 720;
                                  final categoryField = Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      const _ActivityFieldLabel(
                                        text: '分類',
                                        required: true,
                                      ),
                                      DropdownButtonFormField<String>(
                                        value: category,
                                        decoration: _rewardInputDecoration(
                                          hintText: '請選擇分類',
                                          icon: Icons.category_outlined,
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
                                          setDialogState(
                                              () => category = value);
                                        },
                                      ),
                                    ],
                                  );
                                  final statusField = Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      const _ActivityFieldLabel(
                                        text: '狀態',
                                        required: true,
                                      ),
                                      DropdownButtonFormField<RewardStatus>(
                                        value: status,
                                        decoration: _rewardInputDecoration(
                                          hintText: '請選擇狀態',
                                          icon: Icons
                                              .check_circle_outline_outlined,
                                          fillColor: const Color(0xFFFFF7E8),
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
                                    ],
                                  );
                                  if (!twoColumns) {
                                    return Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.stretch,
                                      children: [
                                        categoryField,
                                        const SizedBox(height: 14),
                                        statusField,
                                      ],
                                    );
                                  }
                                  return Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Expanded(child: categoryField),
                                      const SizedBox(width: 28),
                                      Expanded(child: statusField),
                                    ],
                                  );
                                },
                              ),
                              const SizedBox(height: 14),
                              LayoutBuilder(
                                builder: (context, constraints) {
                                  final fieldWidth = constraints.maxWidth >= 720
                                      ? (constraints.maxWidth - 28) / 2
                                      : double.infinity;
                                  return SizedBox(
                                    width: fieldWidth,
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        const _ActivityFieldLabel(
                                          text: '可用庫存',
                                          required: true,
                                        ),
                                        TextField(
                                          controller: stockController,
                                          keyboardType: TextInputType.number,
                                          decoration: _rewardInputDecoration(
                                            hintText: '請輸入庫存',
                                            suffixText: '張',
                                          ),
                                        ),
                                      ],
                                    ),
                                  );
                                },
                              ),
                              const SizedBox(height: 28),
                              const Divider(height: 1),
                              const SizedBox(height: 26),
                              LayoutBuilder(
                                builder: (context, constraints) {
                                  final twoColumns =
                                      constraints.maxWidth >= 720;
                                  final expiryField = Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      const _ActivityFieldLabel(
                                        text: '兌換期限類型',
                                        required: true,
                                      ),
                                      DropdownButtonFormField<
                                          _RewardExpiryMode>(
                                        value: expiryMode,
                                        decoration: _rewardInputDecoration(
                                          hintText: '請選擇兌換期限',
                                          icon: Icons.schedule_outlined,
                                        ),
                                        items: const [
                                          DropdownMenuItem(
                                            value: _RewardExpiryMode.unlimited,
                                            child: Text(
                                                _rewardUnlimitedExpiryLabel),
                                          ),
                                          DropdownMenuItem(
                                            value: _RewardExpiryMode.limited,
                                            child: Text('限時'),
                                          ),
                                        ],
                                        onChanged: (value) {
                                          if (value == null) return;
                                          setDialogState(
                                              () => expiryMode = value);
                                        },
                                      ),
                                      if (expiryMode ==
                                          _RewardExpiryMode.limited) ...[
                                        const SizedBox(height: 14),
                                        TextField(
                                          controller: expiryController,
                                          readOnly: true,
                                          onTap: pickExpiryDate,
                                          decoration: _rewardInputDecoration(
                                            hintText: 'YYYY/MM/DD',
                                            icon:
                                                Icons.event_available_outlined,
                                            suffixIcon: IconButton(
                                              tooltip: '選擇日期',
                                              onPressed: pickExpiryDate,
                                              icon: const Icon(Icons
                                                  .calendar_month_outlined),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ],
                                  );
                                  final infoBox = _RewardExpiryInfoBox(
                                    expiryMode: expiryMode,
                                  );
                                  if (!twoColumns) {
                                    return Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.stretch,
                                      children: [
                                        expiryField,
                                        const SizedBox(height: 14),
                                        infoBox,
                                      ],
                                    );
                                  }
                                  return Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Expanded(child: expiryField),
                                      const SizedBox(width: 28),
                                      Expanded(child: infoBox),
                                    ],
                                  );
                                },
                              ),
                              const SizedBox(height: 28),
                              _RewardImageUploadSection(
                                controller: imageController,
                                storageFolder: 'public/rewards/$rewardId/cover',
                                onUpload: repository.uploadImage,
                              ),
                              const SizedBox(height: 18),
                              _RewardVoucherImportSection(
                                currentReward: reward,
                                pendingImport: pendingVoucherImport,
                                isImporting: isImportingVouchers,
                                onImport: pickVoucherLinks,
                                onClear: pendingVoucherImport == null
                                    ? null
                                    : () {
                                        final currentStock = int.tryParse(
                                              stockController.text.trim(),
                                            ) ??
                                            0;
                                        final nextStock = (currentStock -
                                                pendingVoucherImport!.count)
                                            .clamp(0, 999999);
                                        setDialogState(() {
                                          pendingVoucherImport = null;
                                          stockController.text = '$nextStock';
                                        });
                                      },
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );

    final rewardToSave = pendingReward;
    if (rewardToSave != null) {
      await _saveReward(rewardToSave);
      final importToSave = pendingVoucherImport;
      if (importToSave != null && importToSave.links.isNotEmpty) {
        await _importRewardVoucherLinks(rewardToSave, importToSave);
      }
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
                          color: Color(0xFF8A8D8F),
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

class _ActivityFormSection extends StatelessWidget {
  const _ActivityFormSection({
    required this.number,
    required this.title,
    required this.child,
  });

  final int number;
  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFEADFCE)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 24,
                height: 24,
                alignment: Alignment.center,
                decoration: const BoxDecoration(
                  color: Color(0xFFFF9812),
                  shape: BoxShape.circle,
                ),
                child: Text(
                  '$number',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Text(
                title,
                style: const TextStyle(
                  color: Color(0xFF303236),
                  fontSize: 17,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          child,
        ],
      ),
    );
  }
}

class _ActivityFieldLabel extends StatelessWidget {
  const _ActivityFieldLabel({
    required this.text,
    this.required = false,
  });

  final String text;
  final bool required;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: RichText(
        text: TextSpan(
          style: const TextStyle(
            color: Color(0xFF6F7073),
            fontSize: 13,
            fontWeight: FontWeight.w800,
          ),
          children: [
            TextSpan(text: text),
            if (required)
              const TextSpan(
                text: ' *',
                style: TextStyle(color: Color(0xFFD14332)),
              ),
          ],
        ),
      ),
    );
  }
}

class _RewardFormSection extends StatelessWidget {
  const _RewardFormSection({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(30),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFEADFCE)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(
                Icons.card_giftcard_outlined,
                color: Color(0xFFFF9812),
                size: 28,
              ),
              SizedBox(width: 12),
              Text(
                '基本資訊',
                style: TextStyle(
                  color: Color(0xFFFF9812),
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
          const SizedBox(height: 28),
          child,
        ],
      ),
    );
  }
}

class _RewardExpiryInfoBox extends StatelessWidget {
  const _RewardExpiryInfoBox({required this.expiryMode});

  final _RewardExpiryMode expiryMode;

  @override
  Widget build(BuildContext context) {
    final message = expiryMode == _RewardExpiryMode.unlimited
        ? '不限時的兌換券將不會過期，會員可隨時使用。'
        : '限時兌換券到期後會自動視為過期，會員將無法再使用。';
    return Container(
      width: double.infinity,
      constraints: const BoxConstraints(minHeight: 86),
      padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 18),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF7E8),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.info_outline,
            color: Color(0xFFFF9812),
            size: 24,
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                color: Color(0xFF8A8D8F),
                fontSize: 15,
                height: 1.7,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _RewardVoucherImportSection extends StatelessWidget {
  const _RewardVoucherImportSection({
    required this.currentReward,
    required this.pendingImport,
    required this.isImporting,
    required this.onImport,
    required this.onClear,
  });

  final AdminRewardItem? currentReward;
  final ImportedVoucherLinks? pendingImport;
  final bool isImporting;
  final VoidCallback onImport;
  final VoidCallback? onClear;

  @override
  Widget build(BuildContext context) {
    final reward = currentReward;
    final pending = pendingImport;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFEADFCE)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Icon(
                Icons.table_chart_outlined,
                color: Color(0xFFFF9812),
                size: 28,
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  '批量兌換連結',
                  style: TextStyle(
                    color: Color(0xFF303236),
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              OutlinedButton.icon(
                onPressed: isImporting ? null : onImport,
                icon: isImporting
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.upload_file_outlined),
                label: Text(isImporting ? '讀取中' : '匯入 Excel / CSV'),
              ),
            ],
          ),
          const SizedBox(height: 14),
          const Text(
            '支援 .xlsx、.csv、.txt。系統會自動抓取檔案內所有 http / https 連結，發放時每位會員只會拿到一條未使用連結。',
            style: TextStyle(
              color: Color(0xFF8A8D8F),
              fontSize: 13,
              height: 1.5,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _VoucherPoolChip(
                icon: Icons.link_outlined,
                label: '連結總數 ${reward?.voucherTotal ?? 0}',
              ),
              _VoucherPoolChip(
                icon: Icons.inventory_2_outlined,
                label: '可用連結 ${reward?.voucherAvailable ?? 0}',
              ),
              if (pending != null)
                _VoucherPoolChip(
                  icon: Icons.add_circle_outline,
                  label: '待匯入 ${pending.count}',
                  highlight: true,
                ),
            ],
          ),
          if (pending != null) ...[
            const SizedBox(height: 16),
            DecoratedBox(
              decoration: BoxDecoration(
                color: const Color(0xFFFFF7E8),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                child: Row(
                  children: [
                    const Icon(
                      Icons.check_circle_outline,
                      color: Color(0xFFFF9812),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        '${pending.fileName}：找到 ${pending.count} 筆兌換連結',
                        style: const TextStyle(
                          color: Color(0xFF6F7073),
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    TextButton(
                      onPressed: onClear,
                      child: const Text('移除'),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _VoucherPoolChip extends StatelessWidget {
  const _VoucherPoolChip({
    required this.icon,
    required this.label,
    this.highlight = false,
  });

  final IconData icon;
  final String label;
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: highlight ? const Color(0xFFFFF2DF) : const Color(0xFFF1F3F2),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: const Color(0xFFC66D00)),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(
              color: Color(0xFFC66D00),
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _RewardImageUploadSection extends StatefulWidget {
  const _RewardImageUploadSection({
    required this.controller,
    required this.storageFolder,
    required this.onUpload,
  });

  final TextEditingController controller;
  final String storageFolder;
  final _AdminImageUploader onUpload;

  @override
  State<_RewardImageUploadSection> createState() =>
      _RewardImageUploadSectionState();
}

class _RewardImageUploadSectionState extends State<_RewardImageUploadSection> {
  bool _isDragging = false;
  bool _isUploading = false;
  String? _error;
  String? _uploadNote;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onControllerChanged);
  }

  @override
  void didUpdateWidget(_RewardImageUploadSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_onControllerChanged);
      widget.controller.addListener(_onControllerChanged);
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onControllerChanged);
    super.dispose();
  }

  void _onControllerChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    final imageUrl = widget.controller.text.trim();
    final hasImage = imageUrl.isNotEmpty;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFEADFCE)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Icon(
                Icons.image_outlined,
                color: Color(0xFFFF9812),
                size: 28,
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  '兌換券圖片',
                  style: TextStyle(
                    color: Color(0xFF303236),
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              const Text(
                '建議上傳 JPG / PNG，建議尺寸 1280 × 720px',
                style: TextStyle(
                  color: Color(0xFF8A8D8F),
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(width: 14),
              OutlinedButton(
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('可上傳橫式兌換券圖，建議比例 16:9。'),
                    ),
                  );
                },
                child: const Text('範例'),
              ),
            ],
          ),
          const SizedBox(height: 18),
          LayoutBuilder(
            builder: (context, constraints) {
              final twoColumns = constraints.maxWidth >= 760 && hasImage;
              final preview = _buildImageDropTarget(imageUrl: imageUrl);
              if (!twoColumns) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    preview,
                    if (hasImage) ...[
                      const SizedBox(height: 16),
                      _buildImageInfo(imageUrl),
                    ],
                  ],
                );
              }
              return Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  SizedBox(width: 360, child: preview),
                  const SizedBox(width: 34),
                  Expanded(child: _buildImageInfo(imageUrl)),
                ],
              );
            },
          ),
          if (_error != null) ...[
            const SizedBox(height: 12),
            Text(
              _error!,
              style: const TextStyle(
                color: Color(0xFFAD3B24),
                fontSize: 13,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildImageDropTarget({required String imageUrl}) {
    final hasImage = imageUrl.isNotEmpty;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 160),
      height: hasImage ? 210 : 220,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: _isDragging ? const Color(0xFFFFF2DF) : const Color(0xFFFFFAF3),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color:
              _isDragging ? const Color(0xFFFF9812) : const Color(0xFFEADFCE),
          width: _isDragging ? 1.6 : 1,
        ),
      ),
      child: Stack(
        children: [
          Positioned.fill(
            child: hasImage
                ? Image.network(
                    _imagePreviewUrl(imageUrl),
                    key: ValueKey(_imagePreviewUrl(imageUrl)),
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => _RewardImageEmptyState(
                      isDragging: _isDragging,
                      hasError: true,
                    ),
                  )
                : _RewardImageEmptyState(isDragging: _isDragging),
          ),
          Positioned.fill(
            child: AdminImageDropOverlay(
              onImage: _uploadImage,
              onHoverChanged: (value) {
                if (mounted) {
                  setState(() => _isDragging = value);
                }
              },
            ),
          ),
          if (_isUploading)
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.82),
                ),
                child: const Center(
                  child: SizedBox(
                    width: 34,
                    height: 34,
                    child: CircularProgressIndicator(strokeWidth: 3),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildImageInfo(String imageUrl) {
    final fileName = _imageFileNameFromUrl(imageUrl);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Row(
          children: [
            Icon(Icons.check_circle, color: Color(0xFFFF9812), size: 28),
            SizedBox(width: 10),
            Text(
              '已上傳圖片',
              style: TextStyle(
                color: Color(0xFFFF9812),
                fontSize: 18,
                fontWeight: FontWeight.w900,
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        Text(
          '檔案名稱：$fileName',
          style: const TextStyle(
            color: Color(0xFF6F7073),
            fontSize: 14,
            height: 1.5,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          _uploadNote ?? '圖片連結已儲存。拖曳新圖片到左側可直接替換。',
          style: const TextStyle(
            color: Color(0xFF6F7073),
            fontSize: 14,
            height: 1.5,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 22),
        Wrap(
          spacing: 14,
          runSpacing: 10,
          children: [
            OutlinedButton.icon(
              onPressed: _isUploading ? null : _pickAndUpload,
              icon: const Icon(Icons.category_outlined),
              label: const Text('更換圖片'),
            ),
            OutlinedButton.icon(
              onPressed: _isUploading
                  ? null
                  : () {
                      widget.controller.clear();
                      setState(() {
                        _error = null;
                        _uploadNote = null;
                      });
                    },
              icon: const Icon(Icons.delete_outline),
              label: const Text('移除圖片'),
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFFE0463E),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Future<void> _pickAndUpload() async {
    final image = await pickAdminImage();
    if (image == null) {
      return;
    }
    await _uploadImage(image);
  }

  Future<void> _uploadImage(PickedAdminImage image) async {
    final validationError = _adminImageValidationError(image);
    if (validationError != null) {
      setState(() {
        _error = validationError;
        _uploadNote = null;
      });
      return;
    }

    setState(() {
      _isUploading = true;
      _error = null;
    });

    try {
      final url = await widget.onUpload(
        path: _imageStoragePath(
          folder: widget.storageFolder,
          fileName: image.name,
          contentType: image.contentType,
        ),
        bytes: image.bytes,
        contentType: image.contentType,
      );
      if (url.trim().isEmpty) {
        throw StateError('empty download url');
      }
      if (!mounted) return;
      widget.controller.text = url;
      setState(() {
        _isUploading = false;
        _error = null;
        _uploadNote = _compressionSummary(image);
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isUploading = false;
        _error = '圖片上傳失敗，請確認 Firebase Storage bucket 已建立並部署 rules。';
      });
    }
  }
}

class _RewardImageEmptyState extends StatelessWidget {
  const _RewardImageEmptyState({
    required this.isDragging,
    this.hasError = false,
  });

  final bool isDragging;
  final bool hasError;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 18),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              hasError
                  ? Icons.broken_image_outlined
                  : Icons.cloud_upload_outlined,
              size: 42,
              color:
                  hasError ? const Color(0xFFAD3B24) : const Color(0xFFFF9812),
            ),
            const SizedBox(height: 12),
            Text(
              hasError
                  ? '圖片無法預覽，請重新上傳'
                  : isDragging
                      ? '放開即可上傳圖片'
                      : '拖曳圖片到這裡，或點擊選擇圖片',
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Color(0xFF303236),
                fontSize: 16,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              '上傳後會用於兌換券內容或預覽畫面。',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Color(0xFF8A8D8F),
                fontSize: 12,
                height: 1.4,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ActivityImageUploadSection extends StatefulWidget {
  const _ActivityImageUploadSection({
    required this.controller,
    required this.shareController,
    required this.storageFolder,
    required this.onUpload,
  });

  final TextEditingController controller;
  final TextEditingController shareController;
  final String storageFolder;
  final _AdminImageUploader onUpload;

  @override
  State<_ActivityImageUploadSection> createState() =>
      _ActivityImageUploadSectionState();
}

class _ActivityImageUploadSectionState
    extends State<_ActivityImageUploadSection> {
  bool _isDragging = false;
  bool _isUploading = false;
  String? _error;
  String? _uploadNote;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onControllerChanged);
    widget.shareController.addListener(_onControllerChanged);
  }

  @override
  void didUpdateWidget(_ActivityImageUploadSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_onControllerChanged);
      widget.controller.addListener(_onControllerChanged);
    }
    if (oldWidget.shareController != widget.shareController) {
      oldWidget.shareController.removeListener(_onControllerChanged);
      widget.shareController.addListener(_onControllerChanged);
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onControllerChanged);
    widget.shareController.removeListener(_onControllerChanged);
    super.dispose();
  }

  void _onControllerChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    final imageUrl = widget.controller.text.trim();
    final hasImage = imageUrl.isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          height: hasImage ? 236 : 210,
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            color:
                _isDragging ? const Color(0xFFFFF2DF) : const Color(0xFFFFFAF3),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: _isDragging
                  ? const Color(0xFFFF9812)
                  : const Color(0xFFEADFCE),
              width: _isDragging ? 1.6 : 1,
            ),
          ),
          child: Stack(
            children: [
              Positioned.fill(
                child: hasImage
                    ? Image.network(
                        _imagePreviewUrl(imageUrl),
                        key: ValueKey(_imagePreviewUrl(imageUrl)),
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => _ActivityImageEmptyState(
                          isDragging: _isDragging,
                          hasError: true,
                        ),
                      )
                    : _ActivityImageEmptyState(isDragging: _isDragging),
              ),
              if (hasImage)
                Positioned.fill(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.black.withOpacity(0.02),
                          Colors.black.withOpacity(0.52),
                        ],
                      ),
                    ),
                  ),
                ),
              Positioned.fill(
                child: AdminImageDropOverlay(
                  onImage: _uploadImage,
                  onHoverChanged: (value) {
                    if (mounted) {
                      setState(() => _isDragging = value);
                    }
                  },
                ),
              ),
              if (hasImage)
                Positioned(
                  left: 18,
                  right: 18,
                  bottom: 16,
                  child: IgnorePointer(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text(
                          '活動圖片',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _uploadNote ?? '拖曳新圖片到這裡，或點擊更換圖片。',
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              if (hasImage)
                Positioned(
                  top: 12,
                  right: 12,
                  child: Material(
                    color: Colors.white.withOpacity(0.94),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: IconButton(
                      tooltip: '移除圖片',
                      onPressed: _isUploading
                          ? null
                          : () {
                              widget.controller.clear();
                              widget.shareController.clear();
                              setState(() {
                                _error = null;
                                _uploadNote = null;
                              });
                            },
                      icon: const Icon(Icons.delete_outline),
                      color: const Color(0xFFAD3B24),
                    ),
                  ),
                ),
              if (_isUploading)
                Positioned.fill(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.82),
                    ),
                    child: const Center(
                      child: SizedBox(
                        width: 34,
                        height: 34,
                        child: CircularProgressIndicator(strokeWidth: 3),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          '支援 JPG、PNG、WebP、GIF。原圖上限 10MB，會自動壓縮成 WebP，並同步產生 LINE 分享用 JPG。',
          style: TextStyle(
            color: Color(0xFF8A8D8F),
            fontSize: 12,
            height: 1.4,
            fontWeight: FontWeight.w700,
          ),
        ),
        if (_error != null) ...[
          const SizedBox(height: 8),
          Text(
            _error!,
            style: const TextStyle(
              color: Color(0xFFAD3B24),
              fontSize: 12,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
        if (_uploadNote != null && !hasImage) ...[
          const SizedBox(height: 8),
          Text(
            _uploadNote!,
            style: const TextStyle(
              color: Color(0xFFC66D00),
              fontSize: 12,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ],
    );
  }

  Future<void> _uploadImage(PickedAdminImage image) async {
    final validationError = _adminImageValidationError(image);
    if (validationError != null) {
      setState(() {
        _error = validationError;
        _uploadNote = null;
      });
      return;
    }

    setState(() {
      _isUploading = true;
      _error = null;
    });

    try {
      final url = await widget.onUpload(
        path: _imageStoragePath(
          folder: widget.storageFolder,
          fileName: image.name,
          contentType: image.contentType,
        ),
        bytes: image.bytes,
        contentType: image.contentType,
      );
      String? shareUrl;
      if (image.hasShareVariant) {
        shareUrl = await widget.onUpload(
          path: _imageStoragePath(
            folder: '${widget.storageFolder}/share',
            fileName: image.shareName ?? image.name,
            contentType: image.shareContentType ?? 'image/jpeg',
          ),
          bytes: image.shareBytes!,
          contentType: image.shareContentType ?? 'image/jpeg',
        );
        if (shareUrl.trim().isEmpty) {
          throw StateError('empty share download url');
        }
      }
      if (url.trim().isEmpty) {
        throw StateError('empty download url');
      }
      if (!mounted) return;
      widget.controller.text = url;
      if (shareUrl != null) {
        widget.shareController.text = shareUrl;
      }
      setState(() {
        _isUploading = false;
        _error = null;
        _uploadNote = _compressionSummary(image);
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isUploading = false;
        _error = '圖片上傳失敗，請確認 Firebase Storage bucket 已建立並部署 rules。';
      });
    }
  }
}

class _ActivityImageEmptyState extends StatelessWidget {
  const _ActivityImageEmptyState({
    required this.isDragging,
    this.hasError = false,
  });

  final bool isDragging;
  final bool hasError;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 18),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              hasError
                  ? Icons.broken_image_outlined
                  : Icons.cloud_upload_outlined,
              size: 42,
              color:
                  hasError ? const Color(0xFFAD3B24) : const Color(0xFFFF9812),
            ),
            const SizedBox(height: 12),
            Text(
              hasError
                  ? '圖片無法預覽，請重新上傳'
                  : isDragging
                      ? '放開即可上傳圖片'
                      : '拖曳圖片到這裡，或點擊選擇圖片',
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Color(0xFF303236),
                fontSize: 16,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              '建議使用橫式圖片，前台活動列表與活動詳情會自動套用。',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Color(0xFF8A8D8F),
                fontSize: 12,
                height: 1.4,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

InputDecoration _activityInputDecoration({
  required String hintText,
  String? labelText,
  IconData? icon,
  Widget? suffixIcon,
  String? helperText,
}) {
  return InputDecoration(
    labelText: labelText,
    hintText: hintText,
    helperText: helperText,
    prefixIcon: icon == null ? null : Icon(icon),
    suffixIcon: suffixIcon,
    filled: true,
    fillColor: Colors.white,
    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(8),
      borderSide: const BorderSide(color: Color(0xFFEADFCE)),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(8),
      borderSide: const BorderSide(color: Color(0xFFEADFCE)),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(8),
      borderSide: const BorderSide(color: Color(0xFFFF9812), width: 1.4),
    ),
  );
}

InputDecoration _rewardInputDecoration({
  required String hintText,
  IconData? icon,
  Widget? suffixIcon,
  String? suffixText,
  Color fillColor = Colors.white,
}) {
  return InputDecoration(
    hintText: hintText,
    prefixIcon: icon == null ? null : Icon(icon),
    suffixIcon: suffixIcon,
    suffixText: suffixText,
    filled: true,
    fillColor: fillColor,
    contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(8),
      borderSide: const BorderSide(color: Color(0xFFEADFCE)),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(8),
      borderSide: const BorderSide(color: Color(0xFFEADFCE)),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(8),
      borderSide: const BorderSide(color: Color(0xFFFF9812), width: 1.4),
    ),
  );
}

typedef _AdminImageUploader = Future<String> Function({
  required String path,
  required Uint8List bytes,
  required String contentType,
});

class _ImageUploadField extends StatefulWidget {
  const _ImageUploadField({
    required this.controller,
    required this.label,
    required this.storageFolder,
    required this.onUpload,
    this.helperText,
  });

  final TextEditingController controller;
  final String label;
  final String storageFolder;
  final _AdminImageUploader onUpload;
  final String? helperText;

  @override
  State<_ImageUploadField> createState() => _ImageUploadFieldState();
}

class _ImageUploadFieldState extends State<_ImageUploadField> {
  bool _isUploading = false;
  String? _error;
  String? _uploadNote;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onControllerChanged);
  }

  @override
  void didUpdateWidget(_ImageUploadField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_onControllerChanged);
      widget.controller.addListener(_onControllerChanged);
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onControllerChanged);
    super.dispose();
  }

  void _onControllerChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    final imageUrl = widget.controller.text.trim();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFAF3),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFEADFCE)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.image_outlined, color: Color(0xFFC66D00)),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  widget.label,
                  style: const TextStyle(
                    color: Color(0xFF303236),
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              Text(
                '原圖上限 ${_formatBytes(adminImageSourceMaxBytes)}',
                style: const TextStyle(
                  color: Color(0xFF8A8D8F),
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          if (widget.helperText?.isNotEmpty == true) ...[
            const SizedBox(height: 6),
            Text(
              '${widget.helperText!}\n會自動壓縮成 WebP，最長邊 1280px，目標約 ${_formatBytes(adminImageTargetBytes)}。',
              style: const TextStyle(
                color: Color(0xFF8A8D8F),
                fontSize: 12,
                height: 1.35,
              ),
            ),
          ],
          const SizedBox(height: 10),
          if (imageUrl.isNotEmpty) ...[
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.network(
                _imagePreviewUrl(imageUrl),
                key: ValueKey(_imagePreviewUrl(imageUrl)),
                height: 150,
                width: double.infinity,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) {
                  return Container(
                    height: 110,
                    alignment: Alignment.center,
                    color: const Color(0xFFF1F4F3),
                    child: const Text('圖片無法預覽'),
                  );
                },
              ),
            ),
            const SizedBox(height: 10),
          ],
          Row(
            children: [
              FilledButton.icon(
                onPressed: _isUploading ? null : _pickAndUpload,
                icon: _isUploading
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.cloud_upload_outlined),
                label: Text(_isUploading ? '上傳中' : '上傳圖片'),
              ),
              if (imageUrl.isNotEmpty) ...[
                const SizedBox(width: 8),
                TextButton.icon(
                  onPressed: _isUploading
                      ? null
                      : () {
                          widget.controller.clear();
                          setState(() {
                            _error = null;
                            _uploadNote = null;
                          });
                        },
                  icon: const Icon(Icons.delete_outline),
                  label: const Text('移除'),
                ),
              ],
            ],
          ),
          if (_isUploading) ...[
            const SizedBox(height: 10),
            const LinearProgressIndicator(minHeight: 2),
          ],
          if (_error != null) ...[
            const SizedBox(height: 10),
            Text(
              _error!,
              style: const TextStyle(
                color: Color(0xFFAD3B24),
                fontSize: 12,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
          if (_uploadNote != null) ...[
            const SizedBox(height: 10),
            Text(
              _uploadNote!,
              style: const TextStyle(
                color: Color(0xFFC66D00),
                fontSize: 12,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _pickAndUpload() async {
    final image = await pickAdminImage();
    if (image == null) {
      return;
    }
    final validationError = _adminImageValidationError(image);
    if (validationError != null) {
      setState(() => _error = validationError);
      return;
    }

    setState(() {
      _isUploading = true;
      _error = null;
    });

    try {
      final path = _imageStoragePath(
        folder: widget.storageFolder,
        fileName: image.name,
        contentType: image.contentType,
      );
      final url = await widget.onUpload(
        path: path,
        bytes: image.bytes,
        contentType: image.contentType,
      );
      if (url.trim().isEmpty) {
        throw StateError('empty download url');
      }
      if (!mounted) return;
      widget.controller.text = url;
      setState(() {
        _isUploading = false;
        _error = null;
        _uploadNote = _compressionSummary(image);
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isUploading = false;
        _error = '圖片上傳失敗，請確認 Firebase Storage bucket 已建立並部署 rules。';
      });
    }
  }
}

class _AdminSidebar extends StatefulWidget {
  const _AdminSidebar({
    required this.selected,
    required this.onSelected,
  });

  final AdminTab selected;
  final ValueChanged<AdminTab> onSelected;

  @override
  State<_AdminSidebar> createState() => _AdminSidebarState();
}

class _AdminSidebarState extends State<_AdminSidebar> {
  late bool _activityExpanded = _isActivityGroup(widget.selected);

  @override
  void didUpdateWidget(covariant _AdminSidebar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_isActivityGroup(oldWidget.selected) &&
        _isActivityGroup(widget.selected)) {
      _activityExpanded = true;
    }
  }

  static bool _isActivityGroup(AdminTab tab) {
    return tab == AdminTab.activities || tab == AdminTab.rewardDistribution;
  }

  void _toggleActivityGroup() {
    final isSelectedGroup = _isActivityGroup(widget.selected);
    setState(() {
      _activityExpanded = !_activityExpanded;
    });
    if (!isSelectedGroup && _activityExpanded) {
      widget.onSelected(AdminTab.activities);
    }
  }

  @override
  Widget build(BuildContext context) {
    final activityGroupSelected = _isActivityGroup(widget.selected);
    return Container(
      width: 232,
      color: _BrandColors.sidebar,
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: SizedBox(
              width: double.infinity,
              height: 64,
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Image.asset(
                  'assets/brand/veeva-logo.png',
                  width: double.infinity,
                  fit: BoxFit.contain,
                  alignment: Alignment.center,
                ),
              ),
            ),
          ),
          const SizedBox(height: 20),
          _SidebarItem(
            icon: Icons.dashboard_outlined,
            label: '儀表板',
            selected: widget.selected == AdminTab.dashboard,
            onTap: () => widget.onSelected(AdminTab.dashboard),
          ),
          _SidebarItem(
            icon: Icons.verified_user_outlined,
            label: '權限管理',
            selected: widget.selected == AdminTab.permissions,
            onTap: () => widget.onSelected(AdminTab.permissions),
          ),
          _SidebarItem(
            icon: Icons.groups_outlined,
            label: '會員管理',
            selected: widget.selected == AdminTab.members,
            onTap: () => widget.onSelected(AdminTab.members),
          ),
          _SidebarItem(
            icon: Icons.badge_outlined,
            label: '員工管理',
            selected: widget.selected == AdminTab.employees,
            onTap: () => widget.onSelected(AdminTab.employees),
          ),
          _SidebarGroupHeader(
            icon: Icons.campaign_outlined,
            label: '活動管理',
            selected: activityGroupSelected,
            expanded: _activityExpanded,
            onTap: _toggleActivityGroup,
          ),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 180),
            switchInCurve: Curves.easeOutCubic,
            switchOutCurve: Curves.easeInCubic,
            child: _activityExpanded
                ? Column(
                    key: const ValueKey('activity-subnav-open'),
                    children: [
                      _SidebarSubItem(
                        label: '活動',
                        selected: widget.selected == AdminTab.activities,
                        onTap: () => widget.onSelected(AdminTab.activities),
                      ),
                      _SidebarSubItem(
                        label: '獎勵發放',
                        selected:
                            widget.selected == AdminTab.rewardDistribution,
                        onTap: () =>
                            widget.onSelected(AdminTab.rewardDistribution),
                      ),
                    ],
                  )
                : const SizedBox.shrink(
                    key: ValueKey('activity-subnav-closed'),
                  ),
          ),
          _SidebarItem(
            icon: Icons.newspaper_outlined,
            label: '最新資訊',
            selected: widget.selected == AdminTab.news,
            onTap: () => widget.onSelected(AdminTab.news),
          ),
          _SidebarItem(
            icon: Icons.confirmation_number_outlined,
            label: '兌換券管理',
            selected: widget.selected == AdminTab.rewards,
            onTap: () => widget.onSelected(AdminTab.rewards),
          ),
          _SidebarItem(
            icon: Icons.settings_outlined,
            label: '設定',
            selected: widget.selected == AdminTab.settings,
            onTap: () => widget.onSelected(AdminTab.settings),
          ),
          const Spacer(),
          const Text(
            '活動問卷管理系統',
            style: TextStyle(color: Color(0xFFB2B0AA), fontSize: 12),
          ),
        ],
      ),
    );
  }
}

class _SidebarGroupHeader extends StatelessWidget {
  const _SidebarGroupHeader({
    required this.icon,
    required this.label,
    required this.selected,
    required this.expanded,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final bool expanded;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Material(
        color: selected ? const Color(0xFF5A3A12) : Colors.transparent,
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            child: Row(
              children: [
                Icon(icon, color: const Color(0xFFD5D0C7)),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    label,
                    style: const TextStyle(
                      color: Color(0xFFFFF2DF),
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                AnimatedRotation(
                  turns: expanded ? 0.5 : 0,
                  duration: const Duration(milliseconds: 180),
                  curve: Curves.easeOutCubic,
                  child: const Icon(
                    Icons.expand_more,
                    color: Color(0xFFB2B0AA),
                    size: 18,
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

class _SidebarSubItem extends StatelessWidget {
  const _SidebarSubItem({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 28, bottom: 8),
      child: Material(
        color: selected ? const Color(0xFFC66D00) : Colors.transparent,
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Row(
              children: [
                Container(
                  width: 6,
                  height: 6,
                  decoration: BoxDecoration(
                    color: selected ? Colors.white : const Color(0xFFB2B0AA),
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    label,
                    style: TextStyle(
                      color: selected ? Colors.white : const Color(0xFFD5D0C7),
                      fontWeight: FontWeight.w800,
                    ),
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
        color: selected ? const Color(0xFFC66D00) : Colors.transparent,
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            child: Row(
              children: [
                Icon(icon,
                    color: selected ? Colors.white : const Color(0xFFD5D0C7)),
                const SizedBox(width: 12),
                Text(
                  label,
                  style: TextStyle(
                    color: selected ? Colors.white : const Color(0xFFD5D0C7),
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
              color: const Color(0xFFFFF2DF),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              icon,
              size: compact ? 18 : 22,
              color: const Color(0xFFC66D00),
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
        border: Border(bottom: BorderSide(color: Color(0xFFEADFCE))),
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
                  fillColor: const Color(0xFFFFFAF3),
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
                          color: Color(0xFF8A8D8F),
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
  const _DashboardContent({
    required this.rewards,
    required this.members,
    required this.activityRecords,
  });

  final List<AdminRewardItem> rewards;
  final List<backend.VeevaMember> members;
  final List<backend.VeevaActivityRecord> activityRecords;

  @override
  Widget build(BuildContext context) {
    final isCompact = MediaQuery.sizeOf(context).width < 900;
    final reviewRows = _memberReviewRows;
    final pendingRows =
        reviewRows.where((item) => !item.memberApproved).toList();
    final approved = reviewRows.where((item) => item.memberApproved).length;
    final completedQuestionnaires = _completedQuestionnaireCount;
    final availableRewardStock = rewards
        .where((item) => item.status == RewardStatus.active)
        .fold<int>(0, (total, reward) => total + reward.stock);
    final memberStatusSummary = _memberStatusSummary;
    final metrics = [
      _MetricCard(
        label: '問卷完成',
        value: '$completedQuestionnaires',
        icon: Icons.assignment_turned_in_outlined,
      ),
      _MetricCard(
        label: '待審核',
        value: '${pendingRows.length}',
        icon: Icons.pending_actions_outlined,
      ),
      _MetricCard(
        label: '審核通過',
        value: '$approved',
        icon: Icons.verified_user_outlined,
      ),
      _MetricCard(
        label: '兌換券庫存',
        value: '$availableRewardStock',
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
              _DashboardPendingReviewTable(rows: pendingRows.take(6).toList()),
              const SizedBox(height: 16),
              _StatusPanel(summary: memberStatusSummary),
            ],
          )
        else
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                flex: 2,
                child: _DashboardPendingReviewTable(
                    rows: pendingRows.take(6).toList()),
              ),
              const SizedBox(width: 16),
              Expanded(child: _StatusPanel(summary: memberStatusSummary)),
            ],
          ),
      ],
    );
  }

  int get _completedQuestionnaireCount {
    final keys = <String>{};

    for (final record in activityRecords) {
      if (!_isSurveyRecord(record) || !_isSubmittedSurveyRecord(record)) {
        continue;
      }
      final activityKey = record.activityId.trim().isEmpty
          ? record.id
          : '${record.memberId}:${record.activityId}';
      keys.add('completion:$activityKey');
    }

    return keys.length;
  }

  bool _isSurveyRecord(backend.VeevaActivityRecord record) {
    return record.activityId == _memberReviewSurveyActivityId;
  }

  bool _isSubmittedSurveyRecord(backend.VeevaActivityRecord record) {
    return record.status == 'pendingReview' || record.status == 'completed';
  }

  _DashboardStatusSummary get _memberStatusSummary {
    var approvedCount = 0;
    var pendingCount = 0;
    var incompleteCount = 0;
    for (final member in members) {
      if (member.status == backend.VeevaMemberStatus.verified) {
        approvedCount += 1;
      } else if (_isPhoneVerified(member)) {
        pendingCount += 1;
      } else {
        incompleteCount += 1;
      }
    }
    return _DashboardStatusSummary(
      approved: approvedCount,
      pending: pendingCount,
      incomplete: incompleteCount,
    );
  }

  List<_MemberReviewChecklistItem> get _memberReviewRows {
    final rows = <_MemberReviewChecklistItem>[];
    for (final member in members) {
      if (!_isPhoneVerified(member)) continue;
      rows.add(
        _MemberReviewChecklistItem(
          member: member,
          surveyRecord: _surveyRecordFor(member),
          rewardIssueStatus: ReviewRewardIssueStatus.pending,
        ),
      );
    }
    rows.sort((a, b) {
      final aTime = a.updatedAt;
      final bTime = b.updatedAt;
      if (aTime != null && bTime != null) return bTime.compareTo(aTime);
      if (aTime != null) return -1;
      if (bTime != null) return 1;
      return a.member.name.compareTo(b.member.name);
    });
    return rows;
  }

  bool _isPhoneVerified(backend.VeevaMember member) {
    return member.phoneVerified || member.phoneVerifiedAt != null;
  }

  backend.VeevaActivityRecord? _surveyRecordFor(backend.VeevaMember member) {
    backend.VeevaActivityRecord? selected;
    for (final record in activityRecords) {
      if (record.activityId != _memberReviewSurveyActivityId) continue;
      final memberLineUserId = member.lineUserId?.trim();
      final recordLineUserId = record.memberLineUserId?.trim();
      final matchesMember = record.memberId == member.id ||
          (memberLineUserId != null &&
              memberLineUserId.isNotEmpty &&
              record.memberId == memberLineUserId) ||
          (memberLineUserId != null &&
              memberLineUserId.isNotEmpty &&
              recordLineUserId != null &&
              recordLineUserId.isNotEmpty &&
              recordLineUserId == memberLineUserId);
      if (!matchesMember) continue;
      if (selected == null ||
          _dashboardSurveyRecordPriority(record) >
              _dashboardSurveyRecordPriority(selected)) {
        selected = record;
      }
    }
    return selected;
  }

  int _dashboardSurveyRecordPriority(backend.VeevaActivityRecord record) {
    if (record.status == 'completed') return 4;
    if (record.status == 'pendingReview') return 3;
    if (record.status == 'registered') return 2;
    if (record.status == 'rejected') return 1;
    return 0;
  }
}

class _DashboardPendingReviewTable extends StatelessWidget {
  const _DashboardPendingReviewTable({required this.rows});

  final List<_MemberReviewChecklistItem> rows;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '最新待審核',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 14),
            if (rows.isEmpty)
              const _EmptyListMessage(message: '目前沒有待審核會員。')
            else
              _FullWidthDataTable(
                minWidth: 620,
                child: DataTable(
                  headingRowColor:
                      WidgetStateProperty.all(const Color(0xFFFFFAF3)),
                  columns: const [
                    DataColumn(label: Text('會員')),
                    DataColumn(label: Text('電話')),
                    DataColumn(label: Text('電話驗證')),
                    DataColumn(label: Text('問卷調查')),
                    DataColumn(label: Text('最後更新')),
                  ],
                  rows: [
                    for (final item in rows)
                      DataRow(
                        cells: [
                          DataCell(_MemberReviewIdentity(member: item.member)),
                          DataCell(Text(item.member.phoneNumber ?? '-')),
                          const DataCell(
                            _ChecklistStatusCell(
                              done: true,
                              label: '電話驗證已完成',
                            ),
                          ),
                          DataCell(
                            _ChecklistStatusCell(
                              done: item.surveySubmitted,
                              label: item.surveyStatusLabel,
                            ),
                          ),
                          DataCell(Text(_memberDateTimeLabel(item.updatedAt))),
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

class _DashboardStatusSummary {
  const _DashboardStatusSummary({
    required this.approved,
    required this.pending,
    required this.incomplete,
  });

  final int approved;
  final int pending;
  final int incomplete;

  int get total => approved + pending + incomplete;
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
                color: const Color(0xFFFFF2DF),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: const Color(0xFFC66D00)),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: const TextStyle(color: Color(0xFF8A8D8F))),
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

class _MemberReviewChecklistListBody extends StatelessWidget {
  const _MemberReviewChecklistListBody({
    required this.rows,
    required this.allMembers,
    required this.compact,
    required this.actionMode,
    required this.emptyMessage,
    required this.onApprove,
    required this.onConfirmIssue,
    required this.onRejectIssue,
  });

  final List<_MemberReviewChecklistItem> rows;
  final List<backend.VeevaMember> allMembers;
  final bool compact;
  final _MemberReviewActionMode actionMode;
  final String emptyMessage;
  final ValueChanged<_MemberReviewChecklistItem> onApprove;
  final ValueChanged<_MemberReviewChecklistItem> onConfirmIssue;
  final ValueChanged<_MemberReviewChecklistItem> onRejectIssue;

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
            _MobileMemberReviewChecklistCard(
              item: item,
              allMembers: allMembers,
              actionMode: actionMode,
              onApprove: onApprove,
              onConfirmIssue: onConfirmIssue,
              onRejectIssue: onRejectIssue,
            ),
        ],
      );
    }
    return _FullWidthDataTable(
      minWidth: compact ? 780 : 920,
      child: DataTable(
        headingRowColor: WidgetStateProperty.all(const Color(0xFFFFFAF3)),
        columns: [
          const DataColumn(label: Text('會員')),
          const DataColumn(label: Text('推薦人')),
          const DataColumn(label: Text('電話')),
          const DataColumn(label: Text('電話驗證')),
          const DataColumn(label: Text('問卷調查')),
          const DataColumn(label: Text('最後更新')),
          DataColumn(
            label: Text(
              actionMode == _MemberReviewActionMode.notIssued ? '備注' : '操作',
            ),
          ),
        ],
        rows: [
          for (final item in rows)
            DataRow(
              cells: [
                DataCell(_MemberReviewIdentity(member: item.member)),
                DataCell(
                  _MemberReferrerCell(
                    member: item.member,
                    allMembers: allMembers,
                  ),
                ),
                DataCell(Text(item.member.phoneNumber ?? '-')),
                const DataCell(
                    _ChecklistStatusCell(done: true, label: '電話驗證已完成')),
                DataCell(
                  _ChecklistStatusCell(
                    done: item.surveySubmitted,
                    label: item.surveyStatusLabel,
                  ),
                ),
                DataCell(Text(_memberDateTimeLabel(item.updatedAt))),
                DataCell(
                  _MemberReviewActionCell(
                    item: item,
                    mode: actionMode,
                    onApprove: onApprove,
                    onConfirmIssue: onConfirmIssue,
                    onRejectIssue: onRejectIssue,
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }
}

class _MobileMemberReviewChecklistCard extends StatelessWidget {
  const _MobileMemberReviewChecklistCard({
    required this.item,
    required this.allMembers,
    required this.actionMode,
    required this.onApprove,
    required this.onConfirmIssue,
    required this.onRejectIssue,
  });

  final _MemberReviewChecklistItem item;
  final List<backend.VeevaMember> allMembers;
  final _MemberReviewActionMode actionMode;
  final ValueChanged<_MemberReviewChecklistItem> onApprove;
  final ValueChanged<_MemberReviewChecklistItem> onConfirmIssue;
  final ValueChanged<_MemberReviewChecklistItem> onRejectIssue;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFAF3),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFEADFCE)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _MemberReviewIdentity(member: item.member),
          const SizedBox(height: 10),
          _MemberWidgetLine(
            label: '推薦人',
            child: _MemberReferrerCell(
              member: item.member,
              allMembers: allMembers,
              compact: true,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            item.member.phoneNumber ?? '未記錄電話',
            style: const TextStyle(color: Color(0xFF6F6357)),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              const _ChecklistStatusCell(done: true, label: '電話驗證'),
              _ChecklistStatusCell(
                done: item.surveySubmitted,
                label: '問卷調查：${item.surveyStatusLabel}',
              ),
              _ChecklistStatusCell(
                done: item.rewardIssued,
                label: item.rewardIssueLabel,
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            '最後更新：${_memberDateTimeLabel(item.updatedAt)}',
            style: const TextStyle(color: Color(0xFF8A8D8F), fontSize: 12),
          ),
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerRight,
            child: _MemberReviewActionCell(
              item: item,
              mode: actionMode,
              onApprove: onApprove,
              onConfirmIssue: onConfirmIssue,
              onRejectIssue: onRejectIssue,
            ),
          ),
        ],
      ),
    );
  }
}

class _MemberReviewActionCell extends StatelessWidget {
  const _MemberReviewActionCell({
    required this.item,
    required this.mode,
    required this.onApprove,
    required this.onConfirmIssue,
    required this.onRejectIssue,
  });

  final _MemberReviewChecklistItem item;
  final _MemberReviewActionMode mode;
  final ValueChanged<_MemberReviewChecklistItem> onApprove;
  final ValueChanged<_MemberReviewChecklistItem> onConfirmIssue;
  final ValueChanged<_MemberReviewChecklistItem> onRejectIssue;

  @override
  Widget build(BuildContext context) {
    return switch (mode) {
      _MemberReviewActionMode.approve => FilledButton.icon(
          onPressed: item.canApprove ? () => onApprove(item) : null,
          icon: const Icon(Icons.verified_user_outlined),
          label: const Text('審核通過'),
        ),
      _MemberReviewActionMode.rewardDecision => Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            FilledButton.icon(
              onPressed:
                  item.canDecideReward ? () => onConfirmIssue(item) : null,
              icon: const Icon(Icons.card_giftcard_outlined),
              label: const Text('確認發放'),
            ),
            OutlinedButton.icon(
              onPressed:
                  item.canDecideReward ? () => onRejectIssue(item) : null,
              icon: const Icon(Icons.block_outlined),
              label: const Text('不允許'),
            ),
          ],
        ),
      _MemberReviewActionMode.issued => const _ChecklistStatusCell(
          done: true,
          label: '已發放',
        ),
      _MemberReviewActionMode.notIssued => ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 260),
          child: Tooltip(
            message: item.rewardIssueReason?.trim().isNotEmpty == true
                ? item.rewardIssueReason!
                : '未填寫備注',
            child: Text(
              item.rewardIssueReason?.trim().isNotEmpty == true
                  ? item.rewardIssueReason!
                  : '-',
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Color(0xFF6F6357),
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
    };
  }
}

class _MemberReviewIdentity extends StatelessWidget {
  const _MemberReviewIdentity({required this.member});

  final backend.VeevaMember member;

  @override
  Widget build(BuildContext context) {
    final avatarUrl = member.avatarUrl;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        CircleAvatar(
          radius: 18,
          backgroundImage: avatarUrl == null || avatarUrl.isEmpty
              ? null
              : NetworkImage(avatarUrl),
          child: avatarUrl == null || avatarUrl.isEmpty
              ? const Icon(Icons.person_outline, size: 18)
              : null,
        ),
        const SizedBox(width: 10),
        Flexible(
          child: Text(
            member.name,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontWeight: FontWeight.w900),
          ),
        ),
      ],
    );
  }
}

class _ChecklistStatusCell extends StatelessWidget {
  const _ChecklistStatusCell({
    required this.done,
    required this.label,
  });

  final bool done;
  final String label;

  @override
  Widget build(BuildContext context) {
    final color = done ? const Color(0xFF1F7A5C) : const Color(0xFFC66D00);
    final background = done ? const Color(0xFFE7F4EE) : const Color(0xFFFFF2DF);
    return Tooltip(
      message: label,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: background,
          borderRadius: BorderRadius.circular(999),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              done
                  ? Icons.check_circle_outline
                  : Icons.pending_actions_outlined,
              size: 18,
              color: color,
            ),
          ],
        ),
      ),
    );
  }
}

class _StatusPanel extends StatelessWidget {
  const _StatusPanel({required this.summary});

  final _DashboardStatusSummary summary;

  @override
  Widget build(BuildContext context) {
    final total = summary.total;
    double ratio(int value) => total == 0 ? 0 : value / total;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('名單狀態分布',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
            const SizedBox(height: 16),
            _ProgressRow(
              label: '已通過 (${summary.approved})',
              value: ratio(summary.approved),
            ),
            _ProgressRow(
              label: '待審核 (${summary.pending})',
              value: ratio(summary.pending),
            ),
            _ProgressRow(
              label: '未完成 (${summary.incomplete})',
              value: ratio(summary.incomplete),
            ),
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
    required this.activities,
    required this.members,
    required this.reviews,
    required this.rewards,
    required this.memberRewards,
    required this.activityRecords,
    required this.adminUsers,
    required this.onApprove,
    required this.onSaveMemberSettings,
    required this.onDeleteMember,
    required this.onGrantReward,
    required this.onSaveReviewRewardDecision,
  });

  final List<backend.VeevaActivity> activities;
  final List<backend.VeevaMember> members;
  final List<AdminReviewItem> reviews;
  final List<AdminRewardItem> rewards;
  final List<backend.VeevaMemberReward> memberRewards;
  final List<backend.VeevaActivityRecord> activityRecords;
  final List<backend.VeevaAdminUser> adminUsers;
  final ValueChanged<AdminReviewItem> onApprove;
  final Future<void> Function({
    required backend.VeevaMember member,
    backend.VeevaAdminUser? adminUser,
  }) onSaveMemberSettings;
  final Future<void> Function(backend.VeevaMember member) onDeleteMember;
  final Future<void> Function({
    required backend.VeevaMember member,
    required AdminRewardItem reward,
    required int quantity,
    String? note,
    backend.VeevaActivity? activity,
    backend.VeevaMember? sourceMember,
    String source,
    bool preventDuplicate,
    bool showSnackBar,
  }) onGrantReward;
  final Future<void> Function({
    required backend.VeevaMember member,
    required ReviewRewardIssueStatus rewardIssueStatus,
    String? reason,
  }) onSaveReviewRewardDecision;

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
  int issuedReviewPage = 0;
  int notIssuedReviewPage = 0;
  bool isExportingMembers = false;

  @override
  void dispose() {
    searchController.dispose();
    super.dispose();
  }

  Future<void> _exportMemberExcel({
    required List<backend.VeevaMember> loggedInMembers,
    required List<_MemberReviewChecklistItem> pendingRows,
    required List<_MemberReviewChecklistItem> approvedRows,
    required List<_MemberReviewChecklistItem> issuedRows,
    required List<_MemberReviewChecklistItem> notIssuedRows,
  }) async {
    setState(() => isExportingMembers = true);
    try {
      final excel = xlsx.Excel.createExcel();
      _appendLoggedInMemberSheet(excel, loggedInMembers);
      _appendReviewMemberSheet(excel, '待審核', pendingRows);
      _appendReviewMemberSheet(excel, '已審核', approvedRows);
      _appendReviewMemberSheet(excel, '已發放', issuedRows);
      _appendReviewMemberSheet(excel, '未發放', notIssuedRows);
      excel.delete('Sheet1');

      final encoded = excel.encode();
      if (encoded == null) {
        throw StateError('Excel 檔案產生失敗');
      }

      await downloadAdminExcelFile(
        fileName: 'VeeVa會員管理_${_exportTimestamp()}.xlsx',
        bytes: Uint8List.fromList(encoded),
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('會員資料 Excel 已產生。')),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('會員資料匯出失敗，請稍後再試。')),
      );
    } finally {
      if (mounted) {
        setState(() => isExportingMembers = false);
      }
    }
  }

  void _appendLoggedInMemberSheet(
    xlsx.Excel excel,
    List<backend.VeevaMember> members,
  ) {
    final sheet = excel['已登入會員'];
    final headers = [
      '會員名稱',
      '電話',
      '推薦人',
      'LINE User ID',
      'Email',
      '分享碼',
      '會員狀態',
      '帳號狀態',
      '電話驗證',
      '電話驗證時間',
      '第一次登入時間',
      '最後一次登入時間',
      '建立時間',
      '更新時間',
      '已得券',
      '已邀請',
    ];
    sheet.appendRow(_excelCells(headers));
    for (final member in members) {
      sheet.appendRow(
        _excelCells([
          member.name,
          _memberPhoneLabel(member),
          _referrerNameFor(member, widget.members),
          member.lineUserId ?? member.id,
          member.email,
          member.shareCode,
          _memberStatusLabel(member.status),
          _memberAccountStatusLabel(member.accountStatus),
          _yesNo(member.phoneVerified || member.phoneVerifiedAt != null),
          _memberDateTimeLabel(member.phoneVerifiedAt),
          _memberDateTimeLabel(_memberFirstLoginAt(member)),
          _memberDateTimeLabel(member.lastLineLoginAt),
          _memberDateTimeLabel(member.createdAt),
          _memberDateTimeLabel(member.updatedAt),
          member.earnedCoupons,
          member.invitedCount,
        ]),
      );
    }
    _formatMemberExportSheet(sheet, headers.length);
  }

  void _appendReviewMemberSheet(
    xlsx.Excel excel,
    String sheetName,
    List<_MemberReviewChecklistItem> rows,
  ) {
    final sheet = excel[sheetName];
    final headers = [
      '會員名稱',
      '電話',
      '推薦人',
      'LINE User ID',
      'Email',
      '會員狀態',
      '電話驗證',
      '電話驗證時間',
      '問卷調查',
      '問卷更新時間',
      '獎勵發放狀態',
      '未發放原因',
      '最後一次登入時間',
      '分享碼',
    ];
    sheet.appendRow(_excelCells(headers));
    for (final row in rows) {
      final member = row.member;
      sheet.appendRow(
        _excelCells([
          member.name,
          _memberPhoneLabel(member),
          _referrerNameFor(member, widget.members),
          member.lineUserId ?? member.id,
          member.email,
          _memberStatusLabel(member.status),
          _yesNo(member.phoneVerified || member.phoneVerifiedAt != null),
          _memberDateTimeLabel(member.phoneVerifiedAt),
          row.surveyStatusLabel,
          _memberDateTimeLabel(row.updatedAt),
          row.rewardIssueLabel,
          row.rewardIssueReason,
          _memberDateTimeLabel(member.lastLineLoginAt),
          member.shareCode,
        ]),
      );
    }
    _formatMemberExportSheet(sheet, headers.length);
  }

  List<xlsx.CellValue?> _excelCells(List<Object?> values) {
    return [
      for (final value in values)
        xlsx.TextCellValue(
          value == null || value.toString().trim().isEmpty
              ? '-'
              : value.toString(),
        ),
    ];
  }

  void _formatMemberExportSheet(xlsx.Sheet sheet, int columnCount) {
    const widths = <double>[
      18,
      18,
      18,
      28,
      28,
      14,
      14,
      14,
      14,
      20,
      20,
      20,
      20,
      20,
      12,
      12,
    ];
    for (var index = 0; index < columnCount; index++) {
      sheet.setColumnWidth(
        index,
        index < widths.length ? widths[index] : 18,
      );
    }
  }

  String _yesNo(bool value) => value ? '是' : '否';

  String _exportTimestamp() {
    final now = DateTime.now();
    String two(int value) => value.toString().padLeft(2, '0');
    return [
      now.year.toString(),
      two(now.month),
      two(now.day),
      '_',
      two(now.hour),
      two(now.minute),
    ].join();
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
        .where((member) => _memberMatchesSearch(
              member,
              normalizedQuery,
              referrerName: _referrerNameFor(member, widget.members),
            ))
        .toList();
    final reviewChecklistRows =
        _buildMemberReviewChecklistRows(loggedInMembers);
    final pendingRows =
        reviewChecklistRows.where((item) => !item.memberApproved).toList();
    final approvedRows = reviewChecklistRows
        .where(
          (item) =>
              item.memberApproved &&
              item.rewardIssueStatus == ReviewRewardIssueStatus.pending,
        )
        .toList();
    final issuedRows = reviewChecklistRows
        .where(
          (item) =>
              item.memberApproved &&
              item.rewardIssueStatus == ReviewRewardIssueStatus.issued,
        )
        .toList();
    final notIssuedRows = reviewChecklistRows
        .where(
          (item) =>
              item.memberApproved &&
              item.rewardIssueStatus == ReviewRewardIssueStatus.notIssued,
        )
        .toList();
    final activeReviewRows = switch (selectedTab) {
      MemberManagementTab.approvedReview => approvedRows,
      MemberManagementTab.issuedReview => issuedRows,
      MemberManagementTab.notIssuedReview => notIssuedRows,
      _ => pendingRows,
    };
    final filteredReviewRows = activeReviewRows
        .where((item) => _memberReviewChecklistMatchesSearch(
              item,
              normalizedQuery,
              referrerName: _referrerNameFor(item.member, widget.members),
            ))
        .toList();
    final title = switch (selectedTab) {
      MemberManagementTab.loggedIn => '已登入會員名單',
      MemberManagementTab.pendingReview => '待審核名單',
      MemberManagementTab.approvedReview => '已審核名單',
      MemberManagementTab.issuedReview => '已發放名單',
      MemberManagementTab.notIssuedReview => '未發放名單',
    };
    final visibleCount = selectedTab == MemberManagementTab.loggedIn
        ? filteredLoggedInMembers.length
        : filteredReviewRows.length;
    final unfilteredCount = selectedTab == MemberManagementTab.loggedIn
        ? loggedInMembers.length
        : activeReviewRows.length;
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
        value: '${pendingRows.length}',
        icon: Icons.pending_actions_outlined,
      ),
      _MetricCard(
        label: '已審核待發放',
        value: '${approvedRows.length}',
        icon: Icons.verified_user_outlined,
      ),
      _MetricCard(
        label: '已發放',
        value: '${issuedRows.length}',
        icon: Icons.card_giftcard_outlined,
      ),
      _MetricCard(
        label: '未發放',
        value: '${notIssuedRows.length}',
        icon: Icons.block_outlined,
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
                    if (!isCompact)
                      Text(
                        countText,
                        style: const TextStyle(color: Color(0xFF8A8D8F)),
                      ),
                    const SizedBox(width: 12),
                    OutlinedButton.icon(
                      onPressed: isExportingMembers
                          ? null
                          : () => _exportMemberExcel(
                                loggedInMembers: loggedInMembers,
                                pendingRows: pendingRows,
                                approvedRows: approvedRows,
                                issuedRows: issuedRows,
                                notIssuedRows: notIssuedRows,
                              ),
                      icon: isExportingMembers
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.file_download_outlined),
                      label: Text(isExportingMembers ? '匯出中' : '匯出 Excel'),
                    ),
                  ],
                ),
                if (isCompact) ...[
                  const SizedBox(height: 8),
                  Text(
                    countText,
                    style: const TextStyle(color: Color(0xFF8A8D8F)),
                  ),
                ],
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
                  pendingCount: pendingRows.length,
                  approvedCount: approvedRows.length,
                  issuedCount: issuedRows.length,
                  notIssuedCount: notIssuedRows.length,
                  onChanged: (tab) => setState(() {
                    selectedTab = tab;
                    _setPageFor(tab, 0);
                  }),
                ),
                const SizedBox(height: 16),
                if (selectedTab == MemberManagementTab.loggedIn)
                  _LoggedInMemberListBody(
                    members: pagedLoggedInMembers,
                    allMembers: widget.members,
                    adminUsers: widget.adminUsers,
                    compact: isCompact,
                    emptyMessage: normalizedQuery.isEmpty
                        ? '尚無已登入會員。會員從 LIFF 完成 LINE 登入後會出現在這裡。'
                        : '查無符合條件的已登入會員。',
                    onEditSettings: _openMemberSettingsDialog,
                    onGrantReward: _openGrantRewardDialog,
                    onDeleteMember: _confirmDeleteMember,
                  )
                else
                  _MemberReviewChecklistListBody(
                    rows: pagedReviewRows,
                    allMembers: widget.members,
                    compact: isCompact,
                    actionMode: _actionModeFor(selectedTab),
                    emptyMessage: normalizedQuery.isEmpty
                        ? _emptyMessageFor(selectedTab)
                        : '查無符合條件的會員。',
                    onApprove: _approveMemberReview,
                    onConfirmIssue: _confirmMemberReviewRewardIssue,
                    onRejectIssue: _openMemberReviewRejectDialog,
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

  List<_MemberReviewChecklistItem> _buildMemberReviewChecklistRows(
    List<backend.VeevaMember> members,
  ) {
    final rows = <_MemberReviewChecklistItem>[];
    for (final member in members) {
      if (!_isPhoneVerified(member)) continue;
      final surveyRecord = _surveyRecordFor(member);
      final review = _reviewForMember(member);
      rows.add(
        _MemberReviewChecklistItem(
          member: member,
          surveyRecord: surveyRecord,
          review: review,
          rewardIssueStatus: _rewardIssueStatusFor(member, review),
          rewardIssueReason: review?.rewardIssueReason,
        ),
      );
    }
    rows.sort((a, b) {
      final aTime = a.updatedAt;
      final bTime = b.updatedAt;
      if (aTime != null && bTime != null) return bTime.compareTo(aTime);
      if (aTime != null) return -1;
      if (bTime != null) return 1;
      return a.member.name.compareTo(b.member.name);
    });
    return rows;
  }

  AdminReviewItem? _reviewForMember(backend.VeevaMember member) {
    final memberIds = {
      member.id,
      if (member.lineUserId != null && member.lineUserId!.trim().isNotEmpty)
        member.lineUserId!.trim(),
    };
    for (final review in widget.reviews) {
      if (memberIds.contains(review.id) ||
          memberIds.contains(review.memberId)) {
        return review;
      }
    }
    return null;
  }

  ReviewRewardIssueStatus _rewardIssueStatusFor(
    backend.VeevaMember member,
    AdminReviewItem? review,
  ) {
    final activity = _activityForId(_memberReviewSurveyActivityId);
    if (activity != null && _hasIssuedCompletionReward(activity, member)) {
      return ReviewRewardIssueStatus.issued;
    }
    return _reviewRewardIssueStatusFromName(review?.rewardIssueStatus);
  }

  _MemberReviewActionMode _actionModeFor(MemberManagementTab tab) {
    return switch (tab) {
      MemberManagementTab.pendingReview => _MemberReviewActionMode.approve,
      MemberManagementTab.approvedReview =>
        _MemberReviewActionMode.rewardDecision,
      MemberManagementTab.issuedReview => _MemberReviewActionMode.issued,
      MemberManagementTab.notIssuedReview => _MemberReviewActionMode.notIssued,
      MemberManagementTab.loggedIn => _MemberReviewActionMode.approve,
    };
  }

  String _emptyMessageFor(MemberManagementTab tab) {
    return switch (tab) {
      MemberManagementTab.pendingReview => '目前沒有待審核會員。',
      MemberManagementTab.approvedReview => '目前沒有已審核待發放會員。',
      MemberManagementTab.issuedReview => '目前沒有已發放會員。',
      MemberManagementTab.notIssuedReview => '目前沒有未發放會員。',
      MemberManagementTab.loggedIn => '尚無會員資料。',
    };
  }

  bool _isPhoneVerified(backend.VeevaMember member) {
    return member.phoneVerified || member.phoneVerifiedAt != null;
  }

  backend.VeevaActivityRecord? _surveyRecordFor(backend.VeevaMember member) {
    backend.VeevaActivityRecord? selected;
    for (final record in widget.activityRecords) {
      if (record.activityId != _memberReviewSurveyActivityId) continue;
      final memberLineUserId = member.lineUserId?.trim();
      final recordLineUserId = record.memberLineUserId?.trim();
      final matchesMember = record.memberId == member.id ||
          (memberLineUserId != null &&
              memberLineUserId.isNotEmpty &&
              record.memberId == memberLineUserId) ||
          (memberLineUserId != null &&
              memberLineUserId.isNotEmpty &&
              recordLineUserId != null &&
              recordLineUserId.isNotEmpty &&
              recordLineUserId == memberLineUserId);
      if (!matchesMember) continue;
      if (selected == null ||
          _surveyRecordPriority(record) > _surveyRecordPriority(selected)) {
        selected = record;
      }
    }
    return selected;
  }

  int _surveyRecordPriority(backend.VeevaActivityRecord record) {
    if (record.status == 'completed') return 4;
    if (record.status == 'pendingReview') return 3;
    if (record.status == 'registered') return 2;
    if (record.status == 'rejected') return 1;
    return 0;
  }

  Future<void> _approveMemberReview(_MemberReviewChecklistItem item) async {
    if (!item.canApprove) return;
    final member = item.member;

    try {
      final latestMember = _memberForId(member.id) ?? member;
      final adminUser = _adminFor(latestMember);
      final approvedMember = _memberWithSettings(
        latestMember,
        status: backend.VeevaMemberStatus.verified,
        accountStatus: latestMember.accountStatus,
        isAdmin: adminUser?.status == backend.VeevaAdminStatus.active,
        adminRole: adminUser?.role.name,
      );
      await widget.onSaveMemberSettings(
        member: approvedMember,
        adminUser: adminUser,
      );
      await widget.onSaveReviewRewardDecision(
        member: approvedMember,
        rewardIssueStatus: ReviewRewardIssueStatus.pending,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('已審核通過 ${member.name}，請在已審核區確認是否發放獎勵。'),
        ),
      );
    } catch (_) {
      _showMemberReviewError('審核通過失敗：請確認 Firestore rules 已部署。');
    }
  }

  Future<void> _confirmMemberReviewRewardIssue(
    _MemberReviewChecklistItem item,
  ) async {
    if (!item.canDecideReward) return;
    final member = item.member;
    final activity = _activityForId(_memberReviewSurveyActivityId);
    if (activity == null) {
      _showMemberReviewError('發放失敗：找不到填寫線上問卷活動設定。');
      return;
    }
    final completionReward = _rewardForId(activity.completionRewardId);
    if (completionReward == null) {
      _showMemberReviewError('發放失敗：此活動尚未設定完成獎勵。');
      return;
    }

    try {
      if (!_hasIssuedCompletionReward(activity, member)) {
        await widget.onGrantReward(
          member: member,
          reward: completionReward,
          quantity: 1,
          note: '會員審核後人工確認發放',
          activity: activity,
          source: 'activityCompletion',
          preventDuplicate: true,
          showSnackBar: false,
        );
      }

      final referrerReward = _rewardForId(activity.referrerRewardId);
      final referrerId = member.referredByMemberId?.trim();
      if (referrerReward != null &&
          referrerId != null &&
          referrerId.isNotEmpty &&
          !_referralRewardAlreadyUsed(member)) {
        final referrer = _memberForId(referrerId);
        if (referrer != null) {
          await widget.onGrantReward(
            member: referrer,
            reward: referrerReward,
            quantity: 1,
            note: '邀請者加碼獎勵',
            activity: activity,
            sourceMember: member,
            source: 'referralActivityCompletion',
            preventDuplicate: true,
            showSnackBar: false,
          );
        }
      }

      final latestMember = _memberForId(member.id) ?? member;
      await widget.onSaveReviewRewardDecision(
        member: latestMember,
        rewardIssueStatus: ReviewRewardIssueStatus.issued,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text('已發放 ${completionReward.name} 給 ${member.name}。')),
      );
    } catch (_) {
      _showMemberReviewError('發放失敗：請確認兌換券庫存、活動設定與 Firestore rules。');
    }
  }

  Future<void> _openMemberReviewRejectDialog(
    _MemberReviewChecklistItem item,
  ) async {
    if (!item.canDecideReward) return;
    final reasonController = TextEditingController();
    final reason = await showDialog<String>(
      context: context,
      builder: (context) {
        var canSubmit = false;
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: Text('不允許發放給 ${item.member.name}'),
              content: SizedBox(
                width: 420,
                child: TextField(
                  controller: reasonController,
                  maxLines: 4,
                  decoration: const InputDecoration(
                    labelText: '未通過原因',
                    hintText: '請輸入未通過原因',
                  ),
                  onChanged: (value) => setDialogState(
                    () => canSubmit = value.trim().isNotEmpty,
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('取消'),
                ),
                FilledButton(
                  onPressed: canSubmit
                      ? () => Navigator.of(context).pop(
                            reasonController.text.trim(),
                          )
                      : null,
                  child: const Text('確認'),
                ),
              ],
            );
          },
        );
      },
    );
    reasonController.dispose();
    if (reason == null || reason.trim().isEmpty) return;

    try {
      final latestMember = _memberForId(item.member.id) ?? item.member;
      await widget.onSaveReviewRewardDecision(
        member: latestMember,
        rewardIssueStatus: ReviewRewardIssueStatus.notIssued,
        reason: reason,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('已將 ${item.member.name} 移至未發放。')),
      );
    } catch (_) {
      _showMemberReviewError('未發放狀態更新失敗：請確認 Firestore rules 已部署。');
    }
  }

  backend.VeevaActivity? _activityForId(String activityId) {
    for (final activity in widget.activities) {
      if (activity.id == activityId) return activity;
    }
    return null;
  }

  AdminRewardItem? _rewardForId(String? rewardId) {
    if (rewardId == null || rewardId.trim().isEmpty) return null;
    for (final reward in widget.rewards) {
      if (reward.id == rewardId) return reward;
    }
    return null;
  }

  backend.VeevaMember? _memberForId(String memberId) {
    for (final member in widget.members) {
      if (member.id == memberId || member.lineUserId == memberId) {
        return member;
      }
    }
    return null;
  }

  bool _hasIssuedCompletionReward(
    backend.VeevaActivity activity,
    backend.VeevaMember member,
  ) {
    final rewardId = activity.completionRewardId;
    if (rewardId == null) return false;
    return widget.memberRewards.any(
      (item) =>
          item.memberId == member.id &&
          item.rewardId == rewardId &&
          item.activityId == activity.id &&
          item.source == 'activityCompletion' &&
          (item.status == 'issued' || item.status == 'redeemed'),
    );
  }

  bool _referralRewardAlreadyUsed(backend.VeevaMember participant) {
    return participant.referralRewardGrantedAt != null ||
        participant.referralRewardGrantedActivityId != null ||
        widget.memberRewards.any(
          (item) =>
              item.source == 'referralActivityCompletion' &&
              item.sourceMemberId == participant.id &&
              (item.status == 'issued' || item.status == 'redeemed'),
        );
  }

  void _showMemberReviewError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  int _pageFor(MemberManagementTab tab) {
    return switch (tab) {
      MemberManagementTab.loggedIn => loggedInPage,
      MemberManagementTab.pendingReview => pendingReviewPage,
      MemberManagementTab.approvedReview => approvedReviewPage,
      MemberManagementTab.issuedReview => issuedReviewPage,
      MemberManagementTab.notIssuedReview => notIssuedReviewPage,
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
      case MemberManagementTab.issuedReview:
        issuedReviewPage = page;
        break;
      case MemberManagementTab.notIssuedReview:
        notIssuedReviewPage = page;
        break;
    }
  }

  void _resetPages() {
    loggedInPage = 0;
    pendingReviewPage = 0;
    approvedReviewPage = 0;
    issuedReviewPage = 0;
    notIssuedReviewPage = 0;
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

  Future<void> _openMemberSettingsDialog(backend.VeevaMember member) async {
    final existing = _adminFor(member);
    var selection = _selectionForMemberSetting(member, existing);
    var isSaving = false;
    String? formError;

    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('編輯會員設定'),
              content: SizedBox(
                width: 560,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _MemberPermissionHeader(member: member),
                      const SizedBox(height: 18),
                      const Text(
                        '會員設定',
                        style: TextStyle(fontWeight: FontWeight.w900),
                      ),
                      const SizedBox(height: 8),
                      for (final item in _memberSettingSelections)
                        RadioListTile<_MemberSettingSelection>(
                          value: item,
                          groupValue: selection,
                          contentPadding: EdgeInsets.zero,
                          title: Text(_memberSettingSelectionLabel(item)),
                          subtitle:
                              Text(_memberSettingSelectionDescription(item)),
                          onChanged: isSaving
                              ? null
                              : (value) {
                                  if (value == null) return;
                                  setDialogState(() {
                                    selection = value;
                                    formError = null;
                                  });
                                },
                        ),
                      if (formError != null) ...[
                        const SizedBox(height: 8),
                        _InlineError(message: formError!),
                      ],
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed:
                      isSaving ? null : () => Navigator.of(dialogContext).pop(),
                  child: const Text('取消'),
                ),
                FilledButton.icon(
                  onPressed: isSaving
                      ? null
                      : () async {
                          setDialogState(() {
                            isSaving = true;
                            formError = null;
                          });
                          try {
                            await _changeMemberSetting(member, selection);
                            if (dialogContext.mounted) {
                              Navigator.of(dialogContext).pop();
                            }
                          } catch (_) {
                            if (!dialogContext.mounted) return;
                            setDialogState(() {
                              isSaving = false;
                              formError = '會員設定儲存失敗，請稍後再試。';
                            });
                          }
                        },
                  icon: isSaving
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.save_outlined),
                  label: Text(isSaving ? '儲存中' : '儲存設定'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _openGrantRewardDialog(backend.VeevaMember member) async {
    final availableRewards = widget.rewards
        .where(
          (reward) => reward.status == RewardStatus.active && reward.stock > 0,
        )
        .toList()
      ..sort((a, b) => a.name.compareTo(b.name));
    AdminRewardItem? selectedReward =
        availableRewards.isEmpty ? null : availableRewards.first;
    final quantityController = TextEditingController(text: '1');
    final noteController = TextEditingController();
    var isSending = false;
    String? formError;

    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final reward = selectedReward;
            return AlertDialog(
              title: const Text('發送兌換券'),
              content: SizedBox(
                width: 560,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _MemberPermissionHeader(member: member),
                      const SizedBox(height: 18),
                      if (availableRewards.isEmpty)
                        const _EmptyListMessage(
                          message: '目前沒有可發送的兌換券。請先到兌換券管理新增並上架兌換券。',
                        )
                      else ...[
                        DropdownButtonFormField<AdminRewardItem>(
                          value: selectedReward,
                          isExpanded: true,
                          decoration: const InputDecoration(
                            labelText: '選擇兌換券',
                            prefixIcon:
                                Icon(Icons.confirmation_number_outlined),
                          ),
                          items: [
                            for (final item in availableRewards)
                              DropdownMenuItem(
                                value: item,
                                child: Text('${item.name}（庫存 ${item.stock}）'),
                              ),
                          ],
                          onChanged: isSending
                              ? null
                              : (value) {
                                  setDialogState(() {
                                    selectedReward = value;
                                    formError = null;
                                  });
                                },
                        ),
                        if (reward != null) ...[
                          const SizedBox(height: 12),
                          _RewardGrantSummary(reward: reward),
                        ],
                        const SizedBox(height: 12),
                        TextField(
                          controller: quantityController,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: '發送數量',
                            prefixIcon: Icon(Icons.format_list_numbered),
                            suffixText: '張',
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: noteController,
                          maxLines: 3,
                          decoration: const InputDecoration(
                            labelText: '備註（選填）',
                            prefixIcon: Icon(Icons.notes_outlined),
                          ),
                        ),
                      ],
                      if (formError != null) ...[
                        const SizedBox(height: 12),
                        _InlineError(message: formError!),
                      ],
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: isSending
                      ? null
                      : () => Navigator.of(dialogContext).pop(),
                  child: const Text('取消'),
                ),
                FilledButton.icon(
                  onPressed: isSending || selectedReward == null
                      ? null
                      : () async {
                          final reward = selectedReward;
                          final quantity =
                              int.tryParse(quantityController.text.trim());
                          if (reward == null) return;
                          if (quantity == null || quantity <= 0) {
                            setDialogState(() => formError = '請輸入正確的發送數量。');
                            return;
                          }
                          if (quantity > reward.stock) {
                            setDialogState(
                              () =>
                                  formError = '發送數量不可超過目前庫存 ${reward.stock} 張。',
                            );
                            return;
                          }

                          setDialogState(() {
                            isSending = true;
                            formError = null;
                          });
                          try {
                            await widget.onGrantReward(
                              member: member,
                              reward: reward,
                              quantity: quantity,
                              note: noteController.text,
                            );
                            if (dialogContext.mounted) {
                              Navigator.of(dialogContext).pop();
                            }
                          } catch (_) {
                            if (!dialogContext.mounted) return;
                            setDialogState(() {
                              isSending = false;
                              formError = '兌換券發送失敗，請確認庫存與 Firestore 設定。';
                            });
                          }
                        },
                  icon: isSending
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.card_giftcard_outlined),
                  label: Text(isSending ? '發送中' : '發送兌換券'),
                ),
              ],
            );
          },
        );
      },
    );

    quantityController.dispose();
    noteController.dispose();
  }

  Future<void> _confirmDeleteMember(backend.VeevaMember member) async {
    var isDeleting = false;
    String? formError;

    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('刪除會員'),
              content: SizedBox(
                width: 560,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _MemberPermissionHeader(member: member),
                    const SizedBox(height: 18),
                    const Text(
                      '刪除後會同步清除此會員的登入資料、後台權限、活動紀錄、審核紀錄、兌換券、系統訊息、推薦與員工 QR Code 關聯紀錄。',
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      '此操作無法復原，請確認後再刪除。',
                      style: TextStyle(
                        color: Color(0xFFB42318),
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    if (formError != null) ...[
                      const SizedBox(height: 12),
                      _InlineError(message: formError!),
                    ],
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: isDeleting
                      ? null
                      : () => Navigator.of(dialogContext).pop(),
                  child: const Text('取消'),
                ),
                FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFFB42318),
                    foregroundColor: Colors.white,
                  ),
                  onPressed: isDeleting
                      ? null
                      : () async {
                          setDialogState(() {
                            isDeleting = true;
                            formError = null;
                          });
                          try {
                            await widget.onDeleteMember(member);
                            if (dialogContext.mounted) {
                              Navigator.of(dialogContext).pop();
                            }
                          } catch (_) {
                            if (!dialogContext.mounted) return;
                            setDialogState(() {
                              isDeleting = false;
                              formError = '會員刪除失敗，請稍後再試。';
                            });
                          }
                        },
                  icon: isDeleting
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.delete_outline),
                  label: Text(isDeleting ? '刪除中' : '確認刪除'),
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

class _LoggedInMemberListBody extends StatelessWidget {
  const _LoggedInMemberListBody({
    required this.members,
    required this.allMembers,
    required this.adminUsers,
    required this.compact,
    required this.emptyMessage,
    required this.onEditSettings,
    required this.onGrantReward,
    required this.onDeleteMember,
  });

  final List<backend.VeevaMember> members;
  final List<backend.VeevaMember> allMembers;
  final List<backend.VeevaAdminUser> adminUsers;
  final bool compact;
  final String emptyMessage;
  final ValueChanged<backend.VeevaMember> onEditSettings;
  final ValueChanged<backend.VeevaMember> onGrantReward;
  final ValueChanged<backend.VeevaMember> onDeleteMember;

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
              allMembers: allMembers,
              adminUser: _adminFor(member),
              onEditSettings: () => onEditSettings(member),
              onGrantReward: () => onGrantReward(member),
              onDeleteMember: () => onDeleteMember(member),
            ),
        ],
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final availableWidth =
            constraints.maxWidth.isFinite ? constraints.maxWidth : 920.0;
        final tableWidth = availableWidth < 780 ? 780.0 : availableWidth;
        final contentWidth = tableWidth - 32 - 60;
        final nameWidth = contentWidth * .26;
        final referrerWidth = contentWidth * .16;
        final phoneWidth = contentWidth * .17;
        final lastLoginWidth = contentWidth * .21;
        final settingWidth = contentWidth -
            nameWidth -
            referrerWidth -
            phoneWidth -
            lastLoginWidth;

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
                    label: _TableHeaderLabel('推薦人', width: referrerWidth)),
                DataColumn(label: _TableHeaderLabel('電話', width: phoneWidth)),
                DataColumn(
                  label: _TableHeaderLabel('最後一次登入時間', width: lastLoginWidth),
                ),
                DataColumn(
                  label: _TableHeaderLabel('操作', width: settingWidth),
                ),
              ],
              rows: [
                for (final member in members)
                  DataRow(
                    cells: [
                      DataCell(
                        SizedBox(
                          width: nameWidth,
                          child: _MemberNameOnly(
                            member: member,
                          ),
                        ),
                      ),
                      DataCell(
                        SizedBox(
                          width: referrerWidth,
                          child: _MemberReferrerCell(
                            member: member,
                            allMembers: allMembers,
                          ),
                        ),
                      ),
                      DataCell(
                        SizedBox(
                          width: phoneWidth,
                          child: Text(_memberPhoneLabel(member)),
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
                          child: _MemberRowActions(
                            member: member,
                            adminUser: _adminFor(member),
                            onEditSettings: () => onEditSettings(member),
                            onGrantReward: () => onGrantReward(member),
                            onDeleteMember: () => onDeleteMember(member),
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
    required this.allMembers,
    required this.adminUser,
    required this.onEditSettings,
    required this.onGrantReward,
    required this.onDeleteMember,
  });

  final backend.VeevaMember member;
  final List<backend.VeevaMember> allMembers;
  final backend.VeevaAdminUser? adminUser;
  final VoidCallback onEditSettings;
  final VoidCallback onGrantReward;
  final VoidCallback onDeleteMember;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFAF3),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFEADFCE)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _MemberNameOnly(member: member),
          const SizedBox(height: 12),
          _MemberWidgetLine(
            label: '推薦人',
            child: _MemberReferrerCell(
              member: member,
              allMembers: allMembers,
              compact: true,
            ),
          ),
          const SizedBox(height: 12),
          _MemberTimeLine(
            label: '電話',
            value: _memberPhoneLabel(member),
          ),
          const SizedBox(height: 12),
          _MemberTimeLine(
            label: '最後一次登入',
            value: _memberDateTimeLabel(member.lastLineLoginAt),
          ),
          const SizedBox(height: 12),
          _MemberRowActions(
            member: member,
            adminUser: adminUser,
            onEditSettings: onEditSettings,
            onGrantReward: onGrantReward,
            onDeleteMember: onDeleteMember,
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

class _MemberWidgetLine extends StatelessWidget {
  const _MemberWidgetLine({
    required this.label,
    required this.child,
  });

  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SizedBox(
          width: 92,
          child: Text(
            label,
            style: const TextStyle(color: Color(0xFF8A8D8F)),
          ),
        ),
        Expanded(child: child),
      ],
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
            style: const TextStyle(color: Color(0xFF8A8D8F)),
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

class _MemberReferrerCell extends StatelessWidget {
  const _MemberReferrerCell({
    required this.member,
    required this.allMembers,
    this.compact = false,
  });

  final backend.VeevaMember member;
  final List<backend.VeevaMember> allMembers;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final referrer = _referrerFor(member, allMembers);
    if (referrer == null) {
      return Text(
        _referrerFallbackLabel(member),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(fontWeight: FontWeight.w700),
      );
    }

    final avatarUrl = referrer.avatarUrl?.trim();
    final avatarSize = compact ? 14.0 : 16.0;
    final fallbackInitial =
        referrer.name.trim().isEmpty ? '推' : referrer.name.characters.first;

    return Tooltip(
      message: '查看推薦清單',
      child: InkWell(
        onTap: () => _openMemberReferralListDialog(
          context,
          referrer: referrer,
          allMembers: allMembers,
        ),
        borderRadius: BorderRadius.circular(999),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 2),
          child: Row(
            mainAxisSize: MainAxisSize.max,
            children: [
              CircleAvatar(
                radius: avatarSize,
                backgroundColor: const Color(0xFFFFEED6),
                backgroundImage: avatarUrl == null || avatarUrl.isEmpty
                    ? null
                    : NetworkImage(avatarUrl),
                child: avatarUrl == null || avatarUrl.isEmpty
                    ? Text(
                        fallbackInitial,
                        style: TextStyle(
                          color: const Color(0xFFC66D00),
                          fontSize: compact ? 11 : 12,
                          fontWeight: FontWeight.w900,
                        ),
                      )
                    : null,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  referrer.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

void _openMemberReferralListDialog(
  BuildContext context, {
  required backend.VeevaMember referrer,
  required List<backend.VeevaMember> allMembers,
}) {
  final referrals = _referralsForMember(referrer, allMembers);
  showDialog<void>(
    context: context,
    builder: (dialogContext) {
      return AlertDialog(
        title: Text('${referrer.name} 的推薦清單'),
        content: SizedBox(
          width: 760,
          child: referrals.isEmpty
              ? const _EmptyListMessage(message: '目前沒有推薦會員紀錄。')
              : Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '共 ${referrals.length} 位會員',
                      style: const TextStyle(
                        color: Color(0xFF6F6357),
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 12),
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxHeight: 420),
                      child: SingleChildScrollView(
                        child: _MemberReferralList(referrals: referrals),
                      ),
                    ),
                  ],
                ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('關閉'),
          ),
        ],
      );
    },
  );
}

class _MemberReferralList extends StatelessWidget {
  const _MemberReferralList({
    required this.referrals,
  });

  final List<backend.VeevaMember> referrals;

  @override
  Widget build(BuildContext context) {
    return _FullWidthDataTable(
      minWidth: 720,
      child: DataTable(
        headingRowColor: WidgetStateProperty.all(const Color(0xFFF1F4F3)),
        columns: const [
          DataColumn(label: Text('會員')),
          DataColumn(label: Text('電話')),
          DataColumn(label: Text('電話驗證')),
          DataColumn(label: Text('推薦時間')),
        ],
        rows: [
          for (final referral in referrals)
            DataRow(
              cells: [
                DataCell(_ReferralMemberCell(member: referral)),
                DataCell(Text(_memberPhoneLabel(referral))),
                DataCell(_SmallDoneIcon(
                  done: referral.phoneVerified ||
                      referral.phoneVerifiedAt != null,
                )),
                DataCell(Text(_memberDateTimeLabel(
                  referral.referredAt ??
                      referral.createdAt ??
                      referral.lastLineLoginAt,
                ))),
              ],
            ),
        ],
      ),
    );
  }
}

class _ReferralMemberCell extends StatelessWidget {
  const _ReferralMemberCell({required this.member});

  final backend.VeevaMember member;

  @override
  Widget build(BuildContext context) {
    final avatarUrl = member.avatarUrl?.trim();
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        CircleAvatar(
          radius: 18,
          backgroundColor: const Color(0xFFFFEED6),
          backgroundImage: avatarUrl == null || avatarUrl.isEmpty
              ? null
              : NetworkImage(avatarUrl),
          child: avatarUrl == null || avatarUrl.isEmpty
              ? Text(
                  member.name.trim().isEmpty
                      ? '會'
                      : member.name.characters.first,
                  style: const TextStyle(
                    color: Color(0xFFC66D00),
                    fontWeight: FontWeight.w900,
                  ),
                )
              : null,
        ),
        const SizedBox(width: 10),
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 220),
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

enum _MemberSettingSelection {
  regular,
  owner,
  manager,
  editor,
  viewer,
  disabledAccount,
}

class _MemberNameOnly extends StatelessWidget {
  const _MemberNameOnly({
    required this.member,
  });

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
        Expanded(
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

class _FullWidthDataTable extends StatelessWidget {
  const _FullWidthDataTable({
    required this.child,
    required this.minWidth,
  });

  final Widget child;
  final double minWidth;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final availableWidth =
            constraints.maxWidth.isFinite ? constraints.maxWidth : minWidth;
        final tableWidth =
            availableWidth < minWidth ? minWidth : availableWidth;

        return SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: ConstrainedBox(
              constraints: BoxConstraints(minWidth: tableWidth),
              child: child,
            ),
          ),
        );
      },
    );
  }
}

class _MemberRowActions extends StatelessWidget {
  const _MemberRowActions({
    required this.member,
    required this.adminUser,
    required this.onEditSettings,
    required this.onGrantReward,
    required this.onDeleteMember,
  });

  final backend.VeevaMember member;
  final backend.VeevaAdminUser? adminUser;
  final VoidCallback onEditSettings;
  final VoidCallback onGrantReward;
  final VoidCallback onDeleteMember;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        IconButton.outlined(
          onPressed: onEditSettings,
          tooltip: '編輯會員設定',
          icon: const Icon(Icons.edit_outlined),
        ),
        IconButton.filledTonal(
          onPressed: onGrantReward,
          tooltip: '發送兌換券',
          icon: const Icon(Icons.card_giftcard_outlined),
        ),
        IconButton.outlined(
          style: IconButton.styleFrom(
            foregroundColor: const Color(0xFFB42318),
            side: const BorderSide(color: Color(0xFFF3B4AE)),
          ),
          onPressed: onDeleteMember,
          tooltip: '刪除會員',
          icon: const Icon(Icons.delete_outline),
        ),
      ],
    );
  }
}

class _RewardGrantSummary extends StatelessWidget {
  const _RewardGrantSummary({required this.reward});

  final AdminRewardItem reward;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFAF3),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFEADFCE)),
      ),
      child: Wrap(
        spacing: 18,
        runSpacing: 8,
        children: [
          _MiniInfo(label: '分類', value: reward.category),
          _MiniInfo(label: '庫存', value: '${reward.stock}'),
          _MiniInfo(label: '已發放', value: '${reward.issued}'),
          _MiniInfo(label: '期限', value: reward.expiresAt),
        ],
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
        hintText: '搜尋姓名、電話、LINE ID、Email',
        prefixIcon: const Icon(Icons.search),
        suffixIcon: onClear == null
            ? null
            : IconButton(
                tooltip: '清除搜尋',
                onPressed: onClear,
                icon: const Icon(Icons.close),
              ),
        filled: true,
        fillColor: const Color(0xFFFFFAF3),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: Color(0xFFEADFCE)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: Color(0xFFEADFCE)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: Color(0xFFC66D00), width: 1.4),
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
            color: const Color(0xFFFFFAF3),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: const Color(0xFFEADFCE)),
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
      style: const TextStyle(color: Color(0xFF8A8D8F)),
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
        color: const Color(0xFFFFFAF3),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFEADFCE)),
      ),
      child: Text(message),
    );
  }
}

class _EmployeeManagement extends StatefulWidget {
  const _EmployeeManagement({
    required this.members,
    required this.activities,
    required this.activityRecords,
    required this.employeeLinks,
    required this.employeeAttributions,
    required this.onSaveEmployeeStatus,
    required this.onCreateEmployeeActivityLink,
  });

  final List<backend.VeevaMember> members;
  final List<backend.VeevaActivity> activities;
  final List<backend.VeevaActivityRecord> activityRecords;
  final List<backend.VeevaEmployeeActivityLink> employeeLinks;
  final List<backend.VeevaMemberEmployeeAttribution> employeeAttributions;
  final Future<void> Function({
    required backend.VeevaMember member,
    required bool enabled,
  }) onSaveEmployeeStatus;
  final Future<backend.VeevaEmployeeActivityLink> Function({
    required backend.VeevaMember employee,
    required backend.VeevaActivity activity,
  }) onCreateEmployeeActivityLink;

  @override
  State<_EmployeeManagement> createState() => _EmployeeManagementState();
}

class _EmployeeManagementState extends State<_EmployeeManagement> {
  final searchController = TextEditingController();
  String searchQuery = '';

  @override
  void dispose() {
    searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isCompact = MediaQuery.sizeOf(context).width < 760;
    final employees = widget.members
        .where(
            (member) => member.isEmployee || member.employeeStatus == 'active')
        .where((member) => _employeeMatchesSearch(member, searchQuery))
        .toList()
      ..sort((a, b) => a.name.compareTo(b.name));
    final activeEmployees =
        employees.where((member) => member.employeeStatus != 'disabled').length;
    final totalVisitCount = widget.employeeLinks.fold<int>(
      0,
      (total, link) => total + link.visitCount,
    );
    final totalRegisteredCount = widget.employeeLinks.fold<int>(
      0,
      (total, link) => total + link.registeredCount,
    );
    final totalPhoneVerifiedCount = widget.employeeLinks.fold<int>(
      0,
      (total, link) => total + link.phoneVerifiedCount,
    );
    final totalQuestionnaireCount = widget.employeeLinks.fold<int>(
      0,
      (total, link) => total + _questionnaireCountForLink(link),
    );
    final metrics = [
      _MetricCard(
        label: '員工總數',
        value: '${employees.length}',
        icon: Icons.badge_outlined,
      ),
      _MetricCard(
        label: '啟用員工',
        value: '$activeEmployees',
        icon: Icons.verified_user_outlined,
      ),
      _MetricCard(
        label: 'QR 進站',
        value: '$totalVisitCount',
        icon: Icons.qr_code_2_outlined,
      ),
      _MetricCard(
        label: '問卷',
        value: '$totalQuestionnaireCount',
        icon: Icons.assignment_turned_in_outlined,
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
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  alignment: WrapAlignment.spaceBetween,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    const Text(
                      '員工管理',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    FilledButton.icon(
                      onPressed: _openAddEmployeeDialog,
                      icon: const Icon(Icons.person_add_alt_1_outlined),
                      label: const Text('新增員工'),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                _MemberSearchField(
                  controller: searchController,
                  onChanged: (value) => setState(() => searchQuery = value),
                  onClear: searchQuery.trim().isEmpty
                      ? null
                      : () => setState(() {
                            searchController.clear();
                            searchQuery = '';
                          }),
                ),
                const SizedBox(height: 16),
                if (employees.isEmpty)
                  const _EmptyListMessage(
                    message: '目前尚未建立員工。請從已登入會員中新增員工。',
                  )
                else if (isCompact)
                  Column(
                    children: [
                      for (final employee in employees)
                        _EmployeeCard(
                          employee: employee,
                          links: _linksForEmployee(employee),
                          questionnaireCountForEmployee:
                              _questionnaireCountForEmployee(employee),
                          onQrCode: () => _openQrCodeDialog(employee),
                          onPerformance: () => _openPerformanceDialog(employee),
                          onToggle: () => _toggleEmployee(employee),
                        ),
                    ],
                  )
                else
                  _EmployeeDataTable(
                    employees: employees,
                    linksForEmployee: _linksForEmployee,
                    questionnaireCountForEmployee:
                        _questionnaireCountForEmployee,
                    onQrCode: _openQrCodeDialog,
                    onPerformance: _openPerformanceDialog,
                    onToggle: _toggleEmployee,
                  ),
                if (totalRegisteredCount > 0 ||
                    totalPhoneVerifiedCount > 0) ...[
                  const SizedBox(height: 12),
                  Text(
                    '總註冊 $totalRegisteredCount 人，完成電話驗證 $totalPhoneVerifiedCount 人，問卷 $totalQuestionnaireCount 份。',
                    style: const TextStyle(color: Color(0xFF8A8D8F)),
                  ),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }

  List<backend.VeevaEmployeeActivityLink> _linksForEmployee(
    backend.VeevaMember employee,
  ) {
    return widget.employeeLinks
        .where((link) => link.employeeMemberId == employee.id)
        .toList()
      ..sort((a, b) => a.activityTitle.compareTo(b.activityTitle));
  }

  List<backend.VeevaMemberEmployeeAttribution> _attributionsForEmployee(
    backend.VeevaMember employee,
  ) {
    return widget.employeeAttributions
        .where((item) => item.employeeMemberId == employee.id)
        .toList()
      ..sort((a, b) {
        final aTime = a.registeredAt ?? a.createdAt;
        final bTime = b.registeredAt ?? b.createdAt;
        if (aTime != null && bTime != null) return bTime.compareTo(aTime);
        if (aTime != null) return -1;
        if (bTime != null) return 1;
        return a.memberName.compareTo(b.memberName);
      });
  }

  List<backend.VeevaMemberEmployeeAttribution> _attributionsForLink(
    backend.VeevaEmployeeActivityLink link,
  ) {
    return widget.employeeAttributions
        .where((item) =>
            item.employeeLinkId == link.id ||
            (item.employeeMemberId == link.employeeMemberId &&
                item.activityId == link.activityId))
        .toList();
  }

  int _questionnaireCountForEmployee(backend.VeevaMember employee) {
    return _linksForEmployee(employee).fold<int>(
        0, (total, link) => total + _questionnaireCountForLink(link));
  }

  int _questionnaireCountForLink(backend.VeevaEmployeeActivityLink link) {
    return _attributionsForLink(link)
        .where(_hasSubmittedQuestionnaireForAttribution)
        .length;
  }

  bool _hasSubmittedQuestionnaireForAttribution(
    backend.VeevaMemberEmployeeAttribution attribution,
  ) {
    return widget.activityRecords.any((record) {
      if (record.activityId != attribution.activityId) return false;
      final attributionLineUserId = attribution.memberLineUserId?.trim();
      final recordLineUserId = record.memberLineUserId?.trim();
      final sameMember = record.memberId == attribution.memberId ||
          (attributionLineUserId != null &&
              attributionLineUserId.isNotEmpty &&
              recordLineUserId != null &&
              recordLineUserId.isNotEmpty &&
              recordLineUserId == attributionLineUserId);
      if (!sameMember) return false;
      return record.status == 'pendingReview' || record.status == 'completed';
    });
  }

  backend.VeevaMember? _memberForAttribution(
    backend.VeevaMemberEmployeeAttribution attribution,
  ) {
    final attributionLineUserId = attribution.memberLineUserId?.trim();
    for (final member in widget.members) {
      final memberLineUserId = member.lineUserId?.trim();
      if (member.id == attribution.memberId ||
          (attributionLineUserId != null &&
              attributionLineUserId.isNotEmpty &&
              memberLineUserId != null &&
              memberLineUserId.isNotEmpty &&
              memberLineUserId == attributionLineUserId)) {
        return member;
      }
    }
    return null;
  }

  bool _hasPhoneVerifiedForAttribution(
    backend.VeevaMemberEmployeeAttribution attribution,
  ) {
    final member = _memberForAttribution(attribution);
    if (member != null) {
      return member.phoneVerified || member.phoneVerifiedAt != null;
    }
    return attribution.phoneVerifiedAt != null;
  }

  Future<void> _openAddEmployeeDialog() async {
    final candidates = widget.members
        .where(
            (member) => !member.isEmployee && member.employeeStatus != 'active')
        .toList()
      ..sort((a, b) => a.name.compareTo(b.name));
    var query = '';
    backend.VeevaMember? selected;
    var isSaving = false;
    String? formError;

    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final filtered = candidates
                .where((member) => _employeeMatchesSearch(member, query))
                .take(30)
                .toList();
            return AlertDialog(
              title: const Text('新增員工'),
              content: SizedBox(
                width: 560,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextField(
                      decoration: const InputDecoration(
                        labelText: '搜尋現有會員',
                        prefixIcon: Icon(Icons.search),
                      ),
                      onChanged: (value) => setDialogState(() {
                        query = value;
                        selected = null;
                      }),
                    ),
                    const SizedBox(height: 12),
                    if (filtered.isEmpty)
                      const _EmptyListMessage(message: '沒有可新增為員工的會員。')
                    else
                      Flexible(
                        child: ListView.separated(
                          shrinkWrap: true,
                          itemCount: filtered.length,
                          separatorBuilder: (_, __) => const Divider(height: 1),
                          itemBuilder: (context, index) {
                            final member = filtered[index];
                            final checked = selected?.id == member.id;
                            return ListTile(
                              contentPadding: EdgeInsets.zero,
                              leading: _MemberAvatar(member: member),
                              title: Text(member.name),
                              subtitle: Text(member.email ?? 'LINE 會員'),
                              trailing: checked
                                  ? const Icon(
                                      Icons.check_circle,
                                      color: Color(0xFFC66D00),
                                    )
                                  : null,
                              onTap: isSaving
                                  ? null
                                  : () => setDialogState(() {
                                        selected = member;
                                        formError = null;
                                      }),
                            );
                          },
                        ),
                      ),
                    if (formError != null) ...[
                      const SizedBox(height: 12),
                      _InlineError(message: formError!),
                    ],
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed:
                      isSaving ? null : () => Navigator.of(dialogContext).pop(),
                  child: const Text('取消'),
                ),
                FilledButton.icon(
                  onPressed: isSaving
                      ? null
                      : () async {
                          final member = selected;
                          if (member == null) {
                            setDialogState(() => formError = '請先選擇一位會員。');
                            return;
                          }
                          setDialogState(() {
                            isSaving = true;
                            formError = null;
                          });
                          try {
                            await widget.onSaveEmployeeStatus(
                              member: member,
                              enabled: true,
                            );
                            if (dialogContext.mounted) {
                              Navigator.of(dialogContext).pop();
                            }
                          } catch (_) {
                            if (!dialogContext.mounted) return;
                            setDialogState(() {
                              isSaving = false;
                              formError = '新增員工失敗，請稍後再試。';
                            });
                          }
                        },
                  icon: isSaving
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.save_outlined),
                  label: Text(isSaving ? '新增中' : '新增員工'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _openQrCodeDialog(backend.VeevaMember employee) async {
    final selectableActivities = widget.activities
        .where((activity) =>
            activity.status != backend.VeevaContentStatus.archived &&
            activity.active)
        .toList()
      ..sort((a, b) => a.title.compareTo(b.title));
    backend.VeevaActivity? selectedActivity =
        selectableActivities.isEmpty ? null : selectableActivities.first;
    backend.VeevaEmployeeActivityLink? currentLink;
    var isCreating = false;
    String? formError;

    backend.VeevaEmployeeActivityLink? existingFor(
      backend.VeevaActivity? activity,
    ) {
      if (activity == null) return null;
      for (final link in widget.employeeLinks) {
        if (link.employeeMemberId == employee.id &&
            link.activityId == activity.id) {
          return link;
        }
      }
      return null;
    }

    currentLink = existingFor(selectedActivity);

    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: Text('${employee.name} 的 QR Code'),
              content: SizedBox(
                width: 600,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _EmployeeHeader(member: employee),
                      const SizedBox(height: 16),
                      if (selectableActivities.isEmpty)
                        const _EmptyListMessage(
                            message: '目前沒有可建立 QR Code 的啟用活動。')
                      else ...[
                        DropdownButtonFormField<backend.VeevaActivity>(
                          value: selectedActivity,
                          isExpanded: true,
                          decoration: const InputDecoration(
                            labelText: '選擇活動',
                            prefixIcon: Icon(Icons.event_available_outlined),
                          ),
                          items: [
                            for (final activity in selectableActivities)
                              DropdownMenuItem(
                                value: activity,
                                child: Text(activity.title),
                              ),
                          ],
                          onChanged: isCreating
                              ? null
                              : (activity) => setDialogState(() {
                                    selectedActivity = activity;
                                    currentLink = existingFor(activity);
                                    formError = null;
                                  }),
                        ),
                        const SizedBox(height: 16),
                        if (currentLink == null)
                          const _EmptyListMessage(
                            message: '這位員工尚未建立此活動的 QR Code。點擊建立後，該活動會和員工績效綁定。',
                          )
                        else
                          _EmployeeQrPreview(link: currentLink!),
                      ],
                      if (formError != null) ...[
                        const SizedBox(height: 12),
                        _InlineError(message: formError!),
                      ],
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: isCreating
                      ? null
                      : () => Navigator.of(dialogContext).pop(),
                  child: const Text('關閉'),
                ),
                if (selectableActivities.isNotEmpty)
                  FilledButton.icon(
                    onPressed: isCreating
                        ? null
                        : () async {
                            final activity = selectedActivity;
                            if (activity == null) return;
                            setDialogState(() {
                              isCreating = true;
                              formError = null;
                            });
                            try {
                              final link =
                                  await widget.onCreateEmployeeActivityLink(
                                employee: employee,
                                activity: activity,
                              );
                              if (!dialogContext.mounted) return;
                              setDialogState(() {
                                currentLink = link;
                                isCreating = false;
                              });
                            } catch (_) {
                              if (!dialogContext.mounted) return;
                              setDialogState(() {
                                isCreating = false;
                                formError = 'QR Code 建立失敗，請稍後再試。';
                              });
                            }
                          },
                    icon: isCreating
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.qr_code_2_outlined),
                    label: Text(currentLink == null ? '建立 QR Code' : '重新整理 QR'),
                  ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _openPerformanceDialog(backend.VeevaMember employee) async {
    final links = _linksForEmployee(employee);
    final attributions = _attributionsForEmployee(employee);
    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text('${employee.name} 的績效紀錄'),
          content: SizedBox(
            width: 760,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _EmployeeHeader(member: employee),
                  const SizedBox(height: 16),
                  Align(
                    alignment: Alignment.centerRight,
                    child: FilledButton.tonalIcon(
                      onPressed: attributions.isEmpty
                          ? null
                          : () => _openReferralListDialog(employee),
                      icon: const Icon(Icons.list_alt_outlined),
                      label: const Text('推薦清單'),
                    ),
                  ),
                  const SizedBox(height: 12),
                  if (links.isEmpty)
                    const _EmptyListMessage(message: '尚未建立任何活動 QR Code。')
                  else
                    _EmployeePerformanceTable(
                      links: links,
                      questionnaireCountForLink: _questionnaireCountForLink,
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
          ],
        );
      },
    );
  }

  Future<void> _openReferralListDialog(backend.VeevaMember employee) async {
    final attributions = _attributionsForEmployee(employee);
    final grouped = <String, List<backend.VeevaMemberEmployeeAttribution>>{};
    for (final attribution in attributions) {
      final date = attribution.registeredAt ?? attribution.createdAt;
      final key = date == null ? '未記錄日期' : _formatAdminDate(date);
      grouped.putIfAbsent(key, () => []).add(attribution);
    }
    final dateKeys = grouped.keys.toList()
      ..sort((a, b) {
        if (a == '未記錄日期') return 1;
        if (b == '未記錄日期') return -1;
        return b.compareTo(a);
      });
    DateTime? selectedDate;

    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final selectedDateKey =
                selectedDate == null ? '全部日期' : _formatAdminDate(selectedDate!);
            final visibleDateKeys = selectedDate == null
                ? dateKeys
                : dateKeys.where((key) => key == selectedDateKey).toList();
            final visibleCount = visibleDateKeys.fold<int>(
              0,
              (total, key) => total + (grouped[key]?.length ?? 0),
            );

            return AlertDialog(
              title: Text('${employee.name} 的推薦清單'),
              content: SizedBox(
                width: 820,
                child: attributions.isEmpty
                    ? const _EmptyListMessage(message: '目前沒有推薦會員紀錄。')
                    : Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: OutlinedButton.icon(
                                  onPressed: () async {
                                    final now = DateTime.now();
                                    final picked = await showDatePicker(
                                      context: dialogContext,
                                      initialDate: selectedDate ?? now,
                                      firstDate: DateTime(2020),
                                      lastDate:
                                          now.add(const Duration(days: 365)),
                                      helpText: '選擇查詢日期',
                                      cancelText: '取消',
                                      confirmText: '套用',
                                    );
                                    if (picked == null) return;
                                    setDialogState(() {
                                      selectedDate = picked;
                                    });
                                  },
                                  icon:
                                      const Icon(Icons.calendar_month_outlined),
                                  label: Align(
                                    alignment: Alignment.centerLeft,
                                    child: Text(
                                      selectedDate == null
                                          ? '全部日期'
                                          : _formatAdminDate(selectedDate!),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ),
                              ),
                              if (selectedDate != null) ...[
                                const SizedBox(width: 8),
                                IconButton.outlined(
                                  onPressed: () => setDialogState(() {
                                    selectedDate = null;
                                  }),
                                  tooltip: '清除日期',
                                  icon: const Icon(Icons.close),
                                ),
                              ],
                              const SizedBox(width: 12),
                              _MiniInfo(label: '顯示', value: '$visibleCount 人'),
                            ],
                          ),
                          const SizedBox(height: 14),
                          ConstrainedBox(
                            constraints: const BoxConstraints(maxHeight: 460),
                            child: SingleChildScrollView(
                              child: visibleDateKeys.isEmpty
                                  ? const _EmptyListMessage(
                                      message: '這個日期沒有推薦會員紀錄。',
                                    )
                                  : Column(
                                      mainAxisSize: MainAxisSize.min,
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        for (final dateKey
                                            in visibleDateKeys) ...[
                                          Text(
                                            '$dateKey · ${grouped[dateKey]!.length} 人',
                                            style: const TextStyle(
                                              fontSize: 16,
                                              fontWeight: FontWeight.w900,
                                            ),
                                          ),
                                          const SizedBox(height: 8),
                                          _EmployeeReferralList(
                                            attributions: grouped[dateKey]!,
                                            phoneVerified:
                                                _hasPhoneVerifiedForAttribution,
                                            questionnaireDone:
                                                _hasSubmittedQuestionnaireForAttribution,
                                          ),
                                          const SizedBox(height: 16),
                                        ],
                                      ],
                                    ),
                            ),
                          ),
                        ],
                      ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(),
                  child: const Text('關閉'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _toggleEmployee(backend.VeevaMember employee) async {
    final enabled = employee.employeeStatus == 'disabled';
    await widget.onSaveEmployeeStatus(member: employee, enabled: enabled);
  }

  bool _employeeMatchesSearch(backend.VeevaMember member, String query) {
    final normalized = _normalizeMemberSearch(query);
    if (normalized.isEmpty) return true;
    final haystack = [
      member.name,
      member.email ?? '',
      member.lineUserId ?? '',
      member.employeeCode ?? '',
    ].join(' ').toLowerCase();
    return haystack.contains(normalized);
  }
}

class _EmployeeDataTable extends StatelessWidget {
  const _EmployeeDataTable({
    required this.employees,
    required this.linksForEmployee,
    required this.questionnaireCountForEmployee,
    required this.onQrCode,
    required this.onPerformance,
    required this.onToggle,
  });

  final List<backend.VeevaMember> employees;
  final List<backend.VeevaEmployeeActivityLink> Function(
    backend.VeevaMember employee,
  ) linksForEmployee;
  final int Function(backend.VeevaMember employee)
      questionnaireCountForEmployee;
  final ValueChanged<backend.VeevaMember> onQrCode;
  final ValueChanged<backend.VeevaMember> onPerformance;
  final ValueChanged<backend.VeevaMember> onToggle;

  @override
  Widget build(BuildContext context) {
    return _FullWidthDataTable(
      minWidth: 980,
      child: DataTable(
        headingRowColor: WidgetStateProperty.all(const Color(0xFFF1F4F3)),
        dataRowMinHeight: 78,
        dataRowMaxHeight: 96,
        columns: const [
          DataColumn(label: Text('員工')),
          DataColumn(label: Text('狀態')),
          DataColumn(label: Text('QR 數')),
          DataColumn(label: Text('進站')),
          DataColumn(label: Text('註冊')),
          DataColumn(label: Text('電話驗證')),
          DataColumn(label: Text('問卷')),
          DataColumn(label: Text('操作')),
        ],
        rows: [
          for (final employee in employees)
            _employeeRow(employee, linksForEmployee(employee)),
        ],
      ),
    );
  }

  DataRow _employeeRow(
    backend.VeevaMember employee,
    List<backend.VeevaEmployeeActivityLink> links,
  ) {
    final enabled = employee.employeeStatus != 'disabled';
    final visits = links.fold<int>(0, (total, link) => total + link.visitCount);
    final registered =
        links.fold<int>(0, (total, link) => total + link.registeredCount);
    final verified =
        links.fold<int>(0, (total, link) => total + link.phoneVerifiedCount);
    final questionnaires = questionnaireCountForEmployee(employee);
    return DataRow(
      cells: [
        DataCell(_EmployeeHeader(member: employee)),
        DataCell(_EmployeeStatusChip(enabled: enabled)),
        DataCell(Text('${links.length}')),
        DataCell(Text('$visits')),
        DataCell(Text('$registered')),
        DataCell(Text('$verified')),
        DataCell(Text('$questionnaires')),
        DataCell(
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              IconButton.filledTonal(
                onPressed: enabled ? () => onQrCode(employee) : null,
                tooltip: 'QR Code',
                icon: const Icon(Icons.qr_code_2_outlined),
              ),
              IconButton.outlined(
                onPressed: () => onPerformance(employee),
                tooltip: '績效',
                icon: const Icon(Icons.insights_outlined),
              ),
              IconButton(
                onPressed: () => onToggle(employee),
                tooltip: enabled ? '停用' : '啟用',
                icon: Icon(enabled ? Icons.block_outlined : Icons.play_arrow),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _EmployeeCard extends StatelessWidget {
  const _EmployeeCard({
    required this.employee,
    required this.links,
    required this.questionnaireCountForEmployee,
    required this.onQrCode,
    required this.onPerformance,
    required this.onToggle,
  });

  final backend.VeevaMember employee;
  final List<backend.VeevaEmployeeActivityLink> links;
  final int questionnaireCountForEmployee;
  final VoidCallback onQrCode;
  final VoidCallback onPerformance;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final enabled = employee.employeeStatus != 'disabled';
    final visits = links.fold<int>(0, (total, link) => total + link.visitCount);
    final registered =
        links.fold<int>(0, (total, link) => total + link.registeredCount);
    final verified =
        links.fold<int>(0, (total, link) => total + link.phoneVerifiedCount);
    final questionnaires = questionnaireCountForEmployee;
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFAF3),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFEADFCE)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: _EmployeeHeader(member: employee)),
              _EmployeeStatusChip(enabled: enabled),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 10,
            runSpacing: 8,
            children: [
              _MiniInfo(label: 'QR 數', value: '${links.length}'),
              _MiniInfo(label: '進站', value: '$visits'),
              _MiniInfo(label: '註冊', value: '$registered'),
              _MiniInfo(label: '電話驗證', value: '$verified'),
              _MiniInfo(label: '問卷', value: '$questionnaires'),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              IconButton.filledTonal(
                onPressed: enabled ? onQrCode : null,
                tooltip: 'QR Code',
                icon: const Icon(Icons.qr_code_2_outlined),
              ),
              IconButton.outlined(
                onPressed: onPerformance,
                tooltip: '績效',
                icon: const Icon(Icons.insights_outlined),
              ),
              IconButton(
                onPressed: onToggle,
                tooltip: enabled ? '停用' : '啟用',
                icon: Icon(enabled ? Icons.block_outlined : Icons.play_arrow),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _EmployeeHeader extends StatelessWidget {
  const _EmployeeHeader({required this.member});

  final backend.VeevaMember member;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _MemberAvatar(member: member),
        const SizedBox(width: 10),
        Flexible(
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
                member.employeeCode ?? member.email ?? '員工',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: Color(0xFF8A8D8F), fontSize: 12),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _MemberAvatar extends StatelessWidget {
  const _MemberAvatar({required this.member});

  final backend.VeevaMember member;

  @override
  Widget build(BuildContext context) {
    final avatarUrl = member.avatarUrl;
    return CircleAvatar(
      radius: 20,
      backgroundColor: const Color(0xFFFFF2DF),
      backgroundImage: avatarUrl == null || avatarUrl.isEmpty
          ? null
          : NetworkImage(avatarUrl),
      child: avatarUrl == null || avatarUrl.isEmpty
          ? Text(
              member.name.isEmpty ? '員' : member.name.characters.first,
              style: const TextStyle(fontWeight: FontWeight.w900),
            )
          : null,
    );
  }
}

class _EmployeeStatusChip extends StatelessWidget {
  const _EmployeeStatusChip({required this.enabled});

  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return Chip(
      avatar: Icon(
        enabled ? Icons.check_circle_outline : Icons.block_outlined,
        size: 17,
        color: enabled ? const Color(0xFFC66D00) : const Color(0xFFAD3B24),
      ),
      label: Text(enabled ? '啟用' : '停用'),
      backgroundColor:
          enabled ? const Color(0xFFFFF2DF) : const Color(0xFFFFF4EF),
      side: BorderSide.none,
    );
  }
}

class _EmployeeQrPreview extends StatelessWidget {
  const _EmployeeQrPreview({required this.link});

  final backend.VeevaEmployeeActivityLink link;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFAF3),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFEADFCE)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          QrImageView(
            data: link.url,
            version: QrVersions.auto,
            size: 220,
            backgroundColor: Colors.white,
          ),
          const SizedBox(height: 12),
          Text(
            link.activityTitle,
            textAlign: TextAlign.center,
            style: const TextStyle(fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 8),
          SelectableText(
            link.url,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Color(0xFFC66D00)),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            alignment: WrapAlignment.center,
            children: [
              FilledButton.tonalIcon(
                onPressed: () async {
                  await Clipboard.setData(ClipboardData(text: link.url));
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('已複製 QR Code 連結')),
                    );
                  }
                },
                icon: const Icon(Icons.copy_outlined),
                label: const Text('複製連結'),
              ),
              OutlinedButton.icon(
                onPressed: () async {
                  await Clipboard.setData(ClipboardData(text: link.code));
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('已複製追蹤代碼')),
                    );
                  }
                },
                icon: const Icon(Icons.tag_outlined),
                label: Text(link.code),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _EmployeeReferralList extends StatelessWidget {
  const _EmployeeReferralList({
    required this.attributions,
    required this.phoneVerified,
    required this.questionnaireDone,
  });

  final List<backend.VeevaMemberEmployeeAttribution> attributions;
  final bool Function(backend.VeevaMemberEmployeeAttribution attribution)
      phoneVerified;
  final bool Function(backend.VeevaMemberEmployeeAttribution attribution)
      questionnaireDone;

  @override
  Widget build(BuildContext context) {
    return _FullWidthDataTable(
      minWidth: 720,
      child: DataTable(
        headingRowColor: WidgetStateProperty.all(const Color(0xFFF1F4F3)),
        columns: const [
          DataColumn(label: Text('會員')),
          DataColumn(label: Text('活動')),
          DataColumn(label: Text('電話驗證')),
          DataColumn(label: Text('問卷')),
          DataColumn(label: Text('時間')),
        ],
        rows: [
          for (final attribution in attributions)
            DataRow(
              cells: [
                DataCell(_EmployeeReferralMemberCell(attribution: attribution)),
                DataCell(Text(attribution.activityTitle)),
                DataCell(_SmallDoneIcon(done: phoneVerified(attribution))),
                DataCell(_SmallDoneIcon(done: questionnaireDone(attribution))),
                DataCell(Text(_memberDateTimeLabel(
                  attribution.registeredAt ?? attribution.createdAt,
                ))),
              ],
            ),
        ],
      ),
    );
  }
}

class _EmployeeReferralMemberCell extends StatelessWidget {
  const _EmployeeReferralMemberCell({required this.attribution});

  final backend.VeevaMemberEmployeeAttribution attribution;

  @override
  Widget build(BuildContext context) {
    final avatarUrl = attribution.memberAvatarUrl;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        CircleAvatar(
          radius: 18,
          backgroundColor: const Color(0xFFFFF2DF),
          backgroundImage: avatarUrl == null || avatarUrl.isEmpty
              ? null
              : NetworkImage(avatarUrl),
          child: avatarUrl == null || avatarUrl.isEmpty
              ? Text(
                  attribution.memberName.isEmpty
                      ? '會'
                      : attribution.memberName.characters.first,
                  style: const TextStyle(fontWeight: FontWeight.w900),
                )
              : null,
        ),
        const SizedBox(width: 10),
        Flexible(
          child: Text(
            attribution.memberName,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontWeight: FontWeight.w900),
          ),
        ),
      ],
    );
  }
}

class _SmallDoneIcon extends StatelessWidget {
  const _SmallDoneIcon({required this.done});

  final bool done;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: done ? '已完成' : '未完成',
      child: Icon(
        done ? Icons.check_circle_outline : Icons.radio_button_unchecked,
        color: done ? const Color(0xFFC66D00) : const Color(0xFF8A8D8F),
        size: 20,
      ),
    );
  }
}

class _EmployeePerformanceTable extends StatelessWidget {
  const _EmployeePerformanceTable({
    required this.links,
    required this.questionnaireCountForLink,
  });

  final List<backend.VeevaEmployeeActivityLink> links;
  final int Function(backend.VeevaEmployeeActivityLink link)
      questionnaireCountForLink;

  @override
  Widget build(BuildContext context) {
    return _FullWidthDataTable(
      minWidth: 700,
      child: DataTable(
        headingRowColor: WidgetStateProperty.all(const Color(0xFFF1F4F3)),
        columns: const [
          DataColumn(label: Text('活動')),
          DataColumn(label: Text('進站')),
          DataColumn(label: Text('註冊')),
          DataColumn(label: Text('電話驗證')),
          DataColumn(label: Text('問卷')),
          DataColumn(label: Text('最後進站')),
        ],
        rows: [
          for (final link in links)
            DataRow(
              cells: [
                DataCell(Text(link.activityTitle)),
                DataCell(Text('${link.visitCount}')),
                DataCell(Text('${link.registeredCount}')),
                DataCell(Text('${link.phoneVerifiedCount}')),
                DataCell(Text('${questionnaireCountForLink(link)}')),
                DataCell(Text(_memberDateTimeLabel(link.lastVisitedAt))),
              ],
            ),
        ],
      ),
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
        _PermissionMetrics(
          items: [
            (
              label: '管理者總數',
              value: '$activeAdmins',
              icon: Icons.groups_outlined,
            ),
            (
              label: '啟用管理者',
              value: '$activeAdmins',
              icon: Icons.admin_panel_settings_outlined,
            ),
            (
              label: '停用帳號',
              value: '$disabledMembers',
              icon: Icons.block_outlined,
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

class _PermissionMetrics extends StatelessWidget {
  const _PermissionMetrics({required this.items});

  final List<({String label, String value, IconData icon})> items;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isMobile = constraints.maxWidth < 560;
        if (isMobile) {
          return Column(
            children: [
              for (var index = 0; index < items.length; index++) ...[
                _PermissionMobileMetricCard(item: items[index]),
                if (index != items.length - 1) const SizedBox(height: 10),
              ],
            ],
          );
        }

        return Row(
          children: [
            for (var index = 0; index < items.length; index++) ...[
              Expanded(
                child: _MetricCard(
                  label: items[index].label,
                  value: items[index].value,
                  icon: items[index].icon,
                ),
              ),
              if (index != items.length - 1) const SizedBox(width: 16),
            ],
          ],
        );
      },
    );
  }
}

class _PermissionMobileMetricCard extends StatelessWidget {
  const _PermissionMobileMetricCard({required this.item});

  final ({String label, String value, IconData icon}) item;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: const Color(0xFFFFF2DF),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                item.icon,
                color: const Color(0xFFC66D00),
                size: 23,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                item.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Color(0xFF6F7073),
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            const SizedBox(width: 10),
            Text(
              item.value,
              style: const TextStyle(
                color: Color(0xFF303236),
                fontSize: 26,
                fontWeight: FontWeight.w900,
              ),
            ),
          ],
        ),
      ),
    );
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
                  color: Color(0xFFC66D00),
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
                  style: const TextStyle(color: Color(0xFF8A8D8F)),
                ),
              ],
            ),
            const SizedBox(height: 14),
            if (adminRows.isEmpty)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFFAF3),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFFEADFCE)),
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
              _FullWidthDataTable(
                minWidth: 820,
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
        color: const Color(0xFFFFFAF3),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFEADFCE)),
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
        color: const Color(0xFFFFFAF3),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFEADFCE)),
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
          active ? const Color(0xFFFFF2DF) : const Color(0xFFFFF4D9),
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

String _memberSettingSelectionDescription(_MemberSettingSelection selection) {
  return switch (selection) {
    _MemberSettingSelection.regular => '可正常使用會員功能，不開放後台管理權限。',
    _MemberSettingSelection.owner => '完整後台權限，適合系統主要負責人。',
    _MemberSettingSelection.manager => '可管理會員、活動、最新資訊與兌換券。',
    _MemberSettingSelection.editor => '可編輯活動、最新資訊與兌換券內容。',
    _MemberSettingSelection.viewer => '僅可檢視會員資料，不可修改內容。',
    _MemberSettingSelection.disabledAccount => '停用會員帳號，之後可用於限制登入與使用功能。',
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

String _rewardGrantDocumentId({
  required String memberId,
  required String rewardId,
  required String activityId,
  required String source,
  String? sourceMemberId,
}) {
  return [
    memberId,
    rewardId,
    activityId,
    source,
    sourceMemberId ?? 'self',
  ].map(_firestoreDocumentSegment).join('_');
}

String _activityCompletionDocumentId({
  required String memberId,
  required String activityId,
}) {
  return [memberId, activityId].map(_firestoreDocumentSegment).join('_');
}

String _firestoreDocumentSegment(String value) {
  final segment = value.trim().replaceAll(RegExp(r'[/#?\[\]]'), '_');
  return segment.isEmpty ? 'unknown' : segment;
}

backend.VeevaMember _memberWithSettings(
  backend.VeevaMember member, {
  required backend.VeevaMemberAccountStatus accountStatus,
  required bool isAdmin,
  backend.VeevaMemberStatus? status,
  String? adminRole,
}) {
  return backend.VeevaMember(
    id: member.id,
    name: member.name,
    hospital: member.hospital,
    department: member.department,
    status: status ?? member.status,
    accountStatus: accountStatus,
    earnedCoupons: member.earnedCoupons,
    invitedCount: member.invitedCount,
    shareCode: member.shareCode,
    lineUserId: member.lineUserId,
    avatarUrl: member.avatarUrl,
    email: member.email,
    phoneNumber: member.phoneNumber,
    phoneVerified: member.phoneVerified,
    phoneVerifiedAt: member.phoneVerifiedAt,
    lineStatusMessage: member.lineStatusMessage,
    lineIdToken: member.lineIdToken,
    lineIdTokenUpdatedAt: member.lineIdTokenUpdatedAt,
    createdAt: member.createdAt,
    lastLineLoginAt: member.lastLineLoginAt,
    referredByMemberId: member.referredByMemberId,
    referredByShareCode: member.referredByShareCode,
    referredAt: member.referredAt,
    referralRewardGrantedActivityId: member.referralRewardGrantedActivityId,
    referralRewardGrantedRewardId: member.referralRewardGrantedRewardId,
    referralRewardGrantedReferrerId: member.referralRewardGrantedReferrerId,
    referralRewardGrantedAt: member.referralRewardGrantedAt,
    isAdmin: isAdmin,
    adminRole: adminRole,
    isEmployee: member.isEmployee,
    employeeStatus: member.employeeStatus,
    employeeCode: member.employeeCode,
    employeeCreatedAt: member.employeeCreatedAt,
    updatedAt: member.updatedAt,
  );
}

backend.VeevaMember _memberWithEarnedCoupons(
  backend.VeevaMember member, {
  required int earnedCoupons,
}) {
  return backend.VeevaMember(
    id: member.id,
    name: member.name,
    hospital: member.hospital,
    department: member.department,
    status: member.status,
    accountStatus: member.accountStatus,
    earnedCoupons: earnedCoupons,
    invitedCount: member.invitedCount,
    shareCode: member.shareCode,
    lineUserId: member.lineUserId,
    avatarUrl: member.avatarUrl,
    email: member.email,
    phoneNumber: member.phoneNumber,
    phoneVerified: member.phoneVerified,
    phoneVerifiedAt: member.phoneVerifiedAt,
    lineStatusMessage: member.lineStatusMessage,
    lineIdToken: member.lineIdToken,
    lineIdTokenUpdatedAt: member.lineIdTokenUpdatedAt,
    createdAt: member.createdAt,
    lastLineLoginAt: member.lastLineLoginAt,
    referredByMemberId: member.referredByMemberId,
    referredByShareCode: member.referredByShareCode,
    referredAt: member.referredAt,
    referralRewardGrantedActivityId: member.referralRewardGrantedActivityId,
    referralRewardGrantedRewardId: member.referralRewardGrantedRewardId,
    referralRewardGrantedReferrerId: member.referralRewardGrantedReferrerId,
    referralRewardGrantedAt: member.referralRewardGrantedAt,
    isAdmin: member.isAdmin,
    adminRole: member.adminRole,
    isEmployee: member.isEmployee,
    employeeStatus: member.employeeStatus,
    employeeCode: member.employeeCode,
    employeeCreatedAt: member.employeeCreatedAt,
    updatedAt: member.updatedAt,
  );
}

backend.VeevaMember _memberWithReferralRewardGranted(
  backend.VeevaMember member, {
  required String activityId,
  required String rewardId,
  required String referrerId,
  required DateTime grantedAt,
}) {
  return backend.VeevaMember(
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
    phoneNumber: member.phoneNumber,
    phoneVerified: member.phoneVerified,
    phoneVerifiedAt: member.phoneVerifiedAt,
    lineStatusMessage: member.lineStatusMessage,
    lineIdToken: member.lineIdToken,
    lineIdTokenUpdatedAt: member.lineIdTokenUpdatedAt,
    createdAt: member.createdAt,
    lastLineLoginAt: member.lastLineLoginAt,
    referredByMemberId: member.referredByMemberId,
    referredByShareCode: member.referredByShareCode,
    referredAt: member.referredAt,
    referralRewardGrantedActivityId: activityId,
    referralRewardGrantedRewardId: rewardId,
    referralRewardGrantedReferrerId: referrerId,
    referralRewardGrantedAt: grantedAt,
    isAdmin: member.isAdmin,
    adminRole: member.adminRole,
    isEmployee: member.isEmployee,
    employeeStatus: member.employeeStatus,
    employeeCode: member.employeeCode,
    employeeCreatedAt: member.employeeCreatedAt,
    updatedAt: member.updatedAt,
  );
}

backend.VeevaMember _memberWithEmployeeStatus(
  backend.VeevaMember member, {
  required bool enabled,
  String? employeeCode,
  DateTime? employeeCreatedAt,
}) {
  return backend.VeevaMember(
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
    phoneNumber: member.phoneNumber,
    phoneVerified: member.phoneVerified,
    phoneVerifiedAt: member.phoneVerifiedAt,
    lineStatusMessage: member.lineStatusMessage,
    lineIdToken: member.lineIdToken,
    lineIdTokenUpdatedAt: member.lineIdTokenUpdatedAt,
    createdAt: member.createdAt,
    lastLineLoginAt: member.lastLineLoginAt,
    referredByMemberId: member.referredByMemberId,
    referredByShareCode: member.referredByShareCode,
    referredAt: member.referredAt,
    referralRewardGrantedActivityId: member.referralRewardGrantedActivityId,
    referralRewardGrantedRewardId: member.referralRewardGrantedRewardId,
    referralRewardGrantedReferrerId: member.referralRewardGrantedReferrerId,
    referralRewardGrantedAt: member.referralRewardGrantedAt,
    isAdmin: member.isAdmin,
    adminRole: member.adminRole,
    isEmployee: enabled,
    employeeStatus: enabled ? 'active' : 'disabled',
    employeeCode: employeeCode,
    employeeCreatedAt:
        enabled ? employeeCreatedAt ?? DateTime.now() : employeeCreatedAt,
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

String _normalizeMemberSearch(String value) {
  return value.trim().toLowerCase();
}

bool _memberMatchesSearch(
  backend.VeevaMember member,
  String query, {
  String? referrerName,
}) {
  if (query.isEmpty) return true;
  final normalizedQuery = _normalizeMemberSearch(query);
  final digitQuery = _searchDigits(query);
  final normalizedValues = _normalizeMemberSearch([
    member.id,
    member.name,
    member.hospital,
    member.department,
    member.shareCode,
    member.lineUserId,
    member.email,
    member.phoneNumber,
    member.lineStatusMessage,
    referrerName,
    _memberStatusLabel(member.status),
    _memberAccountStatusLabel(member.accountStatus),
    _memberDateTimeLabel(_memberFirstLoginAt(member)),
    _memberDateTimeLabel(member.lastLineLoginAt),
    ..._phoneSearchVariants(member.phoneNumber),
  ].whereType<String>().join(' '));
  if (normalizedValues.contains(normalizedQuery)) return true;
  if (digitQuery.isEmpty) return false;
  return _searchDigits(normalizedValues).contains(digitQuery);
}

String _searchDigits(String value) {
  return value.replaceAll(RegExp(r'[^0-9]'), '');
}

List<String> _phoneSearchVariants(String? phoneNumber) {
  final phone = phoneNumber?.trim();
  if (phone == null || phone.isEmpty) return const [];
  final digits = _searchDigits(phone);
  if (digits.isEmpty) return [phone];
  final variants = <String>{phone, digits};
  if (digits.startsWith('886') && digits.length > 3) {
    variants.add('0${digits.substring(3)}');
  }
  if (digits.startsWith('0') && digits.length > 1) {
    variants.add('886${digits.substring(1)}');
  }
  return variants.toList();
}

bool _memberReviewChecklistMatchesSearch(
  _MemberReviewChecklistItem item,
  String query, {
  String? referrerName,
}) {
  if (query.isEmpty) return true;
  final digitQuery = _searchDigits(query);
  final values = _normalizeMemberSearch([
    item.member.id,
    item.member.name,
    item.member.lineUserId,
    item.member.email,
    item.member.phoneNumber,
    referrerName,
    item.surveyRecord?.activityTitle,
    item.surveyStatusLabel,
    item.rewardIssueLabel,
    item.rewardIssueReason,
    ..._phoneSearchVariants(item.member.phoneNumber),
  ].whereType<String>().join(' '));
  if (values.contains(query)) return true;
  if (digitQuery.isEmpty) return false;
  return _searchDigits(values).contains(digitQuery);
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
    required this.issuedCount,
    required this.notIssuedCount,
    required this.onChanged,
  });

  final MemberManagementTab selectedTab;
  final int loggedInCount;
  final int pendingCount;
  final int approvedCount;
  final int issuedCount;
  final int notIssuedCount;
  final ValueChanged<MemberManagementTab> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: Color(0xFFEADFCE))),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
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
            _MemberStatusTab(
              label: '已發放',
              count: issuedCount,
              selected: selectedTab == MemberManagementTab.issuedReview,
              onTap: () => onChanged(MemberManagementTab.issuedReview),
            ),
            _MemberStatusTab(
              label: '未發放',
              count: notIssuedCount,
              selected: selectedTab == MemberManagementTab.notIssuedReview,
              onTap: () => onChanged(MemberManagementTab.notIssuedReview),
            ),
          ],
        ),
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
    final color = selected ? const Color(0xFFC66D00) : const Color(0xFF8A8D8F);
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
                        ? const Color(0xFFFFF2DF)
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
                color: selected ? const Color(0xFFC66D00) : Colors.transparent,
                borderRadius: BorderRadius.circular(999),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RewardDistributionManagement extends StatefulWidget {
  const _RewardDistributionManagement({
    required this.activities,
    required this.rewards,
    required this.members,
    required this.activityRecords,
    required this.memberRewards,
    required this.onGrantReward,
    required this.onRejectActivityCompletion,
  });

  final List<backend.VeevaActivity> activities;
  final List<AdminRewardItem> rewards;
  final List<backend.VeevaMember> members;
  final List<backend.VeevaActivityRecord> activityRecords;
  final List<backend.VeevaMemberReward> memberRewards;
  final Future<void> Function({
    required backend.VeevaMember member,
    required AdminRewardItem reward,
    required int quantity,
    String? note,
    backend.VeevaActivity? activity,
    backend.VeevaMember? sourceMember,
    String source,
    bool preventDuplicate,
    bool showSnackBar,
  }) onGrantReward;
  final Future<void> Function(backend.VeevaActivityRecord record)
      onRejectActivityCompletion;

  @override
  State<_RewardDistributionManagement> createState() =>
      _RewardDistributionManagementState();
}

class _RewardDistributionManagementState
    extends State<_RewardDistributionManagement> {
  static const int _memberRewardPageSize = 10;

  Set<String> issuingParticipantIds = {};
  Set<String> rejectingParticipantIds = {};
  Set<String> batchIssuingMemberIds = {};
  final memberRewardSearchController = TextEditingController();
  String memberRewardSearchQuery = '';
  int memberRewardPage = 0;

  @override
  void dispose() {
    memberRewardSearchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isCompact = MediaQuery.sizeOf(context).width < 760;
    final rewardActivities = widget.activities
        .where(
          (activity) =>
              activity.status != backend.VeevaContentStatus.archived &&
              (activity.completionRewardId != null ||
                  activity.referrerRewardId != null),
        )
        .toList();
    final memberRewardSummaries = _memberRewardSummaries();
    final filteredMemberRewardSummaries =
        _filterMemberRewardSummaries(memberRewardSummaries);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(
                      Icons.card_giftcard_outlined,
                      color: Color(0xFFC66D00),
                    ),
                    const SizedBox(width: 10),
                    const Expanded(
                      child: Text(
                        '獎勵發放',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                    FilledButton.icon(
                      onPressed: _openBatchDistributionDialog,
                      icon: const Icon(Icons.playlist_add_check_outlined),
                      label: const Text('批量發放'),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                if (rewardActivities.isEmpty)
                  const _EmptyListMessage(message: '目前沒有活動設定完成後發放兌換券。')
                else if (isCompact)
                  Column(
                    children: [
                      for (final activity in rewardActivities)
                        _DistributionActivityCard(
                          activity: activity,
                          participantCount: _participantsFor(activity).length,
                          issuedCount: _issuedCountFor(activity),
                          completionIssuedCount:
                              _completionIssuedRewardCountFor(activity),
                          referralIssuedCount:
                              _referralIssuedRewardCountFor(activity),
                          manualIssuedCount:
                              _manualIssuedRewardCountFor(activity),
                          totalIssuedCount:
                              _totalIssuedRewardCountFor(activity),
                          onOpen: () => _openDistributionDialog(activity),
                        ),
                    ],
                  )
                else
                  _FullWidthDataTable(
                    minWidth: 1200,
                    child: DataTable(
                      horizontalMargin: 16,
                      columnSpacing: 24,
                      headingRowColor:
                          WidgetStateProperty.all(const Color(0xFFFFFAF3)),
                      columns: const [
                        DataColumn(label: Text('活動')),
                        DataColumn(label: Text('完成獎勵')),
                        DataColumn(label: Text('邀請獎勵')),
                        DataColumn(label: Text('手動發放')),
                        DataColumn(label: Text('參加者')),
                        DataColumn(label: Text('發放狀態')),
                        DataColumn(label: Text('已發放總數')),
                        DataColumn(label: Text('狀態')),
                        DataColumn(label: Text('操作')),
                      ],
                      rows: [
                        for (final activity in rewardActivities)
                          DataRow(
                            cells: [
                              DataCell(_ActivityTitleCell(activity: activity)),
                              DataCell(Text(
                                  '${_completionIssuedRewardCountFor(activity)} 張')),
                              DataCell(Text(
                                  '${_referralIssuedRewardCountFor(activity)} 張')),
                              DataCell(Text(
                                  '${_manualIssuedRewardCountFor(activity)} 張')),
                              DataCell(Text(
                                  '${_participantsFor(activity).length} 位')),
                              DataCell(Text(_distributionTextFor(activity))),
                              DataCell(Text(
                                  '${_totalIssuedRewardCountFor(activity)} 張')),
                              DataCell(_ActivityStatusChip(activity: activity)),
                              DataCell(
                                FilledButton.icon(
                                  onPressed: () =>
                                      _openDistributionDialog(activity),
                                  icon:
                                      const Icon(Icons.card_giftcard_outlined),
                                  label: const Text('發放獎勵'),
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
        const SizedBox(height: 20),
        _buildMemberRewardOverview(
          summaries: memberRewardSummaries,
          filteredSummaries: filteredMemberRewardSummaries,
        ),
      ],
    );
  }

  Widget _buildMemberRewardOverview({
    required List<_MemberRewardSummary> summaries,
    required List<_MemberRewardSummary> filteredSummaries,
  }) {
    final normalizedQuery = memberRewardSearchQuery.trim();
    final totalItems = filteredSummaries.length;
    final maxPage =
        totalItems == 0 ? 0 : ((totalItems - 1) ~/ _memberRewardPageSize);
    final safePage = memberRewardPage > maxPage ? maxPage : memberRewardPage;
    if (safePage != memberRewardPage) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          setState(() => memberRewardPage = safePage);
        }
      });
    }
    final start = safePage * _memberRewardPageSize;
    final end = (start + _memberRewardPageSize) > totalItems
        ? totalItems
        : start + _memberRewardPageSize;
    final pageSummaries = totalItems == 0
        ? <_MemberRewardSummary>[]
        : filteredSummaries.sublist(start, end);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.inventory_2_outlined, color: Color(0xFFC66D00)),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    '會員兌換券總覽',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            _MemberSearchField(
              controller: memberRewardSearchController,
              onChanged: (value) => setState(() {
                memberRewardSearchQuery = value;
                memberRewardPage = 0;
              }),
              onClear: normalizedQuery.isEmpty
                  ? null
                  : () => setState(() {
                        memberRewardSearchController.clear();
                        memberRewardSearchQuery = '';
                        memberRewardPage = 0;
                      }),
            ),
            const SizedBox(height: 12),
            if (summaries.isEmpty)
              const _EmptyListMessage(message: '目前沒有任何兌換券發放紀錄。')
            else if (filteredSummaries.isEmpty)
              const _EmptyListMessage(message: '查無符合條件的會員兌換券紀錄。')
            else
              Column(
                children: [
                  _FullWidthDataTable(
                    minWidth: 1080,
                    child: DataTable(
                      horizontalMargin: 16,
                      columnSpacing: 22,
                      headingRowColor:
                          WidgetStateProperty.all(const Color(0xFFFFFAF3)),
                      columns: const [
                        DataColumn(label: Text('會員')),
                        DataColumn(label: Text('電話')),
                        DataColumn(label: Text('完成獎勵')),
                        DataColumn(label: Text('邀請獎勵')),
                        DataColumn(label: Text('手動發放')),
                        DataColumn(label: Text('可使用')),
                        DataColumn(label: Text('已使用')),
                        DataColumn(label: Text('總取得')),
                        DataColumn(label: Text('操作')),
                      ],
                      rows: [
                        for (final summary in pageSummaries)
                          DataRow(
                            cells: [
                              DataCell(_DistributionMemberCell(
                                member: summary.member,
                              )),
                              DataCell(Text(_memberPhoneLabel(summary.member))),
                              DataCell(Text('${summary.completionCount}')),
                              DataCell(Text('${summary.referralCount}')),
                              DataCell(Text('${summary.manualCount}')),
                              DataCell(Text('${summary.availableCount}')),
                              DataCell(Text('${summary.redeemedCount}')),
                              DataCell(
                                Text(
                                  '${summary.totalCount}',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                              ),
                              DataCell(
                                TextButton.icon(
                                  onPressed: () =>
                                      _openMemberRewardDetails(summary),
                                  icon: const Icon(Icons.list_alt_outlined),
                                  label: const Text('查看明細'),
                                ),
                              ),
                            ],
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  _MemberPaginationBar(
                    currentPage: safePage,
                    pageSize: _memberRewardPageSize,
                    totalItems: totalItems,
                    onPageChanged: (page) => setState(
                      () => memberRewardPage = page,
                    ),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  List<_MemberRewardSummary> _filterMemberRewardSummaries(
    List<_MemberRewardSummary> summaries,
  ) {
    final query = memberRewardSearchQuery.trim().toLowerCase();
    if (query.isEmpty) return summaries;
    return summaries.where((summary) {
      final member = summary.member;
      if (_memberMatchesSearch(member, query)) return true;
      final fields = <String?>[
        for (final reward in summary.rewards) ...[
          reward.rewardName,
          reward.activityTitle ?? '',
          reward.sourceMemberName ?? '',
          _rewardGrantSourceLabel(reward),
          _rewardGrantStatusLabel(reward),
        ],
      ];
      final normalizedValues = _normalizeMemberSearch(
        fields.whereType<String>().join(' '),
      );
      return normalizedValues.contains(query);
    }).toList();
  }

  AdminRewardItem? _rewardFor(String? rewardId) {
    if (rewardId == null) return null;
    for (final reward in widget.rewards) {
      if (reward.id == rewardId) return reward;
    }
    return null;
  }

  List<_MemberRewardSummary> _memberRewardSummaries() {
    final rewardsByMember = <String, List<backend.VeevaMemberReward>>{};
    for (final reward in widget.memberRewards) {
      if (reward.status == 'rejected' || reward.memberId.trim().isEmpty) {
        continue;
      }
      rewardsByMember.putIfAbsent(reward.memberId, () => []).add(reward);
    }

    final summaries = [
      for (final entry in rewardsByMember.entries)
        _MemberRewardSummary(
          member: _memberForId(entry.key),
          rewards: entry.value
            ..sort((a, b) {
              final aTime = a.issuedAt;
              final bTime = b.issuedAt;
              if (aTime != null && bTime != null) {
                return bTime.compareTo(aTime);
              }
              if (aTime != null) return -1;
              if (bTime != null) return 1;
              return a.rewardName.compareTo(b.rewardName);
            }),
        ),
    ];
    summaries.sort((a, b) {
      if (a.totalCount != b.totalCount) return b.totalCount - a.totalCount;
      return a.member.name.compareTo(b.member.name);
    });
    return summaries;
  }

  Future<void> _openMemberRewardDetails(
    _MemberRewardSummary summary,
  ) async {
    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text('${summary.member.name} 的兌換券明細'),
          content: SizedBox(
            width: 920,
            child: summary.rewards.isEmpty
                ? const _EmptyListMessage(message: '目前沒有兌換券明細。')
                : SingleChildScrollView(
                    child: _FullWidthDataTable(
                      minWidth: 900,
                      child: DataTable(
                        horizontalMargin: 12,
                        columnSpacing: 18,
                        headingRowColor:
                            WidgetStateProperty.all(const Color(0xFFFFFAF3)),
                        columns: const [
                          DataColumn(label: Text('來源')),
                          DataColumn(label: Text('活動')),
                          DataColumn(label: Text('兌換券')),
                          DataColumn(label: Text('關聯會員')),
                          DataColumn(label: Text('發放時間')),
                          DataColumn(label: Text('狀態')),
                        ],
                        rows: [
                          for (final reward in summary.rewards)
                            DataRow(
                              cells: [
                                DataCell(Text(_rewardGrantSourceLabel(reward))),
                                DataCell(Text(reward.activityTitle ?? '-')),
                                DataCell(Text(reward.rewardName)),
                                DataCell(Text(_rewardGrantRelatedMemberLabel(
                                  reward,
                                ))),
                                DataCell(Text(
                                  _memberDateTimeLabel(reward.issuedAt),
                                )),
                                DataCell(Text(_rewardGrantStatusLabel(reward))),
                              ],
                            ),
                        ],
                      ),
                    ),
                  ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('關閉'),
            ),
          ],
        );
      },
    );
  }

  String _rewardGrantSourceLabel(backend.VeevaMemberReward reward) {
    return switch (reward.source) {
      'activityCompletion' => '完成獎勵',
      'referralActivityCompletion' => '邀請獎勵',
      'manualBatch' || 'manualAdmin' => '手動發放',
      null || '' => '其他',
      _ => reward.source!,
    };
  }

  String _rewardGrantRelatedMemberLabel(backend.VeevaMemberReward reward) {
    if (reward.source == 'activityCompletion') return '本人完成';
    if (reward.source == 'referralActivityCompletion') {
      final sourceMemberId = reward.sourceMemberId;
      if (sourceMemberId != null && sourceMemberId.trim().isNotEmpty) {
        return _memberForId(sourceMemberId).name;
      }
      return reward.sourceMemberName ?? '-';
    }
    return '-';
  }

  String _rewardGrantStatusLabel(backend.VeevaMemberReward reward) {
    return switch (reward.status) {
      'issued' => '可使用',
      'redeemed' => '已使用',
      'pending' => '待確認',
      'rejected' => '已取消',
      'expired' => '已過期',
      _ => reward.status,
    };
  }

  List<_DistributionParticipant> _participantsFor(
    backend.VeevaActivity activity,
  ) {
    final byMemberId = <String, backend.VeevaActivityRecord>{};
    for (final record in widget.activityRecords) {
      if (record.activityId != activity.id || record.memberId.trim().isEmpty) {
        continue;
      }
      final existing = byMemberId[record.memberId];
      if (existing == null ||
          _activityRecordPriority(record) >=
              _activityRecordPriority(existing)) {
        byMemberId[record.memberId] = record;
      }
    }
    final participants = [
      for (final record in byMemberId.values)
        if (record.status != 'rejected')
          _DistributionParticipant(
            record: record,
            member: _memberForRecord(record),
          ),
    ];
    participants.sort((a, b) {
      if (a.record.isCompleted != b.record.isCompleted) {
        return a.record.isCompleted ? -1 : 1;
      }
      return a.member.name.compareTo(b.member.name);
    });
    return participants;
  }

  int _activityRecordPriority(backend.VeevaActivityRecord record) {
    if (record.isCompleted) return 4;
    if (record.status == 'pendingReview') return 3;
    if (record.status == 'rejected') return 2;
    if (record.status == 'registered') return 1;
    return 0;
  }

  backend.VeevaMember _memberForRecord(backend.VeevaActivityRecord record) {
    for (final member in widget.members) {
      if (member.id == record.memberId ||
          member.lineUserId == record.memberLineUserId) {
        return member;
      }
    }
    return backend.VeevaMember(
      id: record.memberId,
      name: record.memberName,
      hospital: '',
      department: '',
      status: backend.VeevaMemberStatus.loggedIn,
      earnedCoupons: 0,
      invitedCount: 0,
      shareCode: record.memberId.length >= 5
          ? record.memberId.substring(record.memberId.length - 5)
          : record.memberId.padRight(5, 'X'),
      lineUserId: record.memberLineUserId ?? record.memberId,
      avatarUrl: record.memberAvatarUrl,
    );
  }

  backend.VeevaMember _memberForId(String memberId) {
    for (final member in widget.members) {
      if (member.id == memberId || member.lineUserId == memberId) {
        return member;
      }
    }
    return backend.VeevaMember(
      id: memberId,
      name: memberId,
      hospital: '',
      department: '',
      status: backend.VeevaMemberStatus.loggedIn,
      earnedCoupons: 0,
      invitedCount: 0,
      shareCode: memberId.length >= 5
          ? memberId.substring(memberId.length - 5)
          : memberId.padRight(5, 'X'),
      lineUserId: memberId,
    );
  }

  int _issuedCountFor(backend.VeevaActivity activity) {
    return _participantsFor(activity)
        .where(
            (participant) => _hasIssuedCompletionReward(activity, participant))
        .length;
  }

  int _totalIssuedRewardCountFor(backend.VeevaActivity activity) {
    return widget.memberRewards
        .where(
          (reward) =>
              reward.activityId == activity.id &&
              (reward.status == 'issued' || reward.status == 'redeemed'),
        )
        .length;
  }

  int _completionIssuedRewardCountFor(backend.VeevaActivity activity) {
    return _issuedRewardCountForSource(activity, 'activityCompletion');
  }

  int _referralIssuedRewardCountFor(backend.VeevaActivity activity) {
    return _issuedRewardCountForSource(activity, 'referralActivityCompletion');
  }

  int _manualIssuedRewardCountFor(backend.VeevaActivity activity) {
    return widget.memberRewards.where((reward) {
      if (reward.activityId != activity.id || !_isIssuedGrant(reward)) {
        return false;
      }
      return reward.source != 'activityCompletion' &&
          reward.source != 'referralActivityCompletion';
    }).length;
  }

  int _issuedRewardCountForSource(
    backend.VeevaActivity activity,
    String source,
  ) {
    return widget.memberRewards
        .where(
          (reward) =>
              reward.activityId == activity.id &&
              reward.source == source &&
              _isIssuedGrant(reward),
        )
        .length;
  }

  String _distributionTextFor(backend.VeevaActivity activity) {
    final participants = _participantsFor(activity);
    if (participants.isEmpty) return '尚無參加者';
    final issued = _issuedCountFor(activity);
    final ready = participants.where((item) {
      if (item.record.status == 'rejected') return false;
      return item.record.isCompleted ||
          activity.type == backend.VeevaActivityType.registration ||
          _completionRewardGrant(activity, item) != null;
    }).length;
    final pending = ready > issued ? ready - issued : 0;
    return '已發放 $issued / 待確認 $pending';
  }

  backend.VeevaMemberReward? _completionRewardGrant(
    backend.VeevaActivity activity,
    _DistributionParticipant participant,
  ) {
    final rewardId = activity.completionRewardId;
    if (rewardId == null) return null;
    for (final item in widget.memberRewards) {
      if (item.memberId == participant.member.id &&
          item.rewardId == rewardId &&
          item.activityId == activity.id &&
          item.source == 'activityCompletion' &&
          item.status != 'rejected') {
        return item;
      }
    }
    return null;
  }

  bool _isIssuedGrant(backend.VeevaMemberReward item) {
    return item.status == 'issued' || item.status == 'redeemed';
  }

  bool _isPendingGrant(backend.VeevaMemberReward item) {
    return item.status == 'pending';
  }

  bool _hasIssuedCompletionReward(
    backend.VeevaActivity activity,
    _DistributionParticipant participant,
  ) {
    final grant = _completionRewardGrant(activity, participant);
    return grant != null && _isIssuedGrant(grant);
  }

  backend.VeevaMemberReward? _referrerRewardGrant(
    backend.VeevaActivity activity,
    backend.VeevaMember participant,
  ) {
    final rewardId = activity.referrerRewardId;
    if (rewardId == null) return null;
    for (final item in widget.memberRewards) {
      if (item.rewardId == rewardId &&
          item.activityId == activity.id &&
          item.source == 'referralActivityCompletion' &&
          item.sourceMemberId == participant.id &&
          item.status != 'rejected') {
        return item;
      }
    }
    return null;
  }

  bool _referralRewardAlreadyUsed(backend.VeevaMember participant) {
    return participant.referralRewardGrantedAt != null ||
        participant.referralRewardGrantedActivityId != null ||
        widget.memberRewards.any(
          (item) =>
              item.source == 'referralActivityCompletion' &&
              item.sourceMemberId == participant.id &&
              _isIssuedGrant(item),
        );
  }

  String _referrerRewardStatus(
    backend.VeevaActivity activity,
    backend.VeevaMember participant,
  ) {
    if (activity.referrerRewardId == null) return '未設定';
    if (participant.referredByMemberId == null ||
        participant.referredByMemberId!.trim().isEmpty) {
      return '無邀請者';
    }
    final grant = _referrerRewardGrant(activity, participant);
    if (grant != null && !_isIssuedGrant(grant)) {
      return '待確認';
    }
    if (grant != null && _isIssuedGrant(grant)) {
      return '已發放給邀請者';
    }
    final grantedActivityId = participant.referralRewardGrantedActivityId;
    if (grantedActivityId != null &&
        grantedActivityId.isNotEmpty &&
        grantedActivityId != activity.id) {
      return '已於其他活動觸發';
    }
    return '發放完成獎勵時一併處理';
  }

  Future<void> _openDistributionDialog(backend.VeevaActivity activity) async {
    var participants = _participantsFor(activity);
    String? formError;

    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: Text('發放獎勵：${activity.title}'),
              content: SizedBox(
                width: 920,
                child: participants.isEmpty
                    ? const _EmptyListMessage(
                        message: '目前沒有參加者紀錄。會員報名或完成活動後會出現在這裡。',
                      )
                    : SingleChildScrollView(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: [
                                _ActivityTypeChip(type: activity.type),
                                _ActivityStatusChip(activity: activity),
                                _DistributionInfoChip(
                                  icon: Icons.groups_outlined,
                                  label: '${participants.length} 位參加者',
                                ),
                                _DistributionInfoChip(
                                  icon: Icons.card_giftcard_outlined,
                                  label: _distributionTextFor(activity),
                                ),
                              ],
                            ),
                            const SizedBox(height: 14),
                            _FullWidthDataTable(
                              minWidth: 860,
                              child: DataTable(
                                horizontalMargin: 12,
                                columnSpacing: 18,
                                headingRowColor: WidgetStateProperty.all(
                                  const Color(0xFFFFFAF3),
                                ),
                                columns: const [
                                  DataColumn(label: Text('參加者')),
                                  DataColumn(label: Text('狀態')),
                                  DataColumn(label: Text('完成獎勵')),
                                  DataColumn(label: Text('邀請者獎勵')),
                                  DataColumn(label: Text('操作')),
                                ],
                                rows: [
                                  for (final participant in participants)
                                    _participantRow(
                                      activity: activity,
                                      participant: participant,
                                      setDialogState: setDialogState,
                                      refreshParticipants: () {
                                        participants =
                                            _participantsFor(activity);
                                      },
                                      setFormError: (value) {
                                        formError = value;
                                      },
                                    ),
                                ],
                              ),
                            ),
                            if (formError != null) ...[
                              const SizedBox(height: 12),
                              _InlineError(message: formError!),
                            ],
                          ],
                        ),
                      ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(),
                  child: const Text('關閉'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _openBatchDistributionDialog() async {
    final availableRewards = widget.rewards
        .where(
          (reward) => reward.status == RewardStatus.active && reward.stock > 0,
        )
        .toList()
      ..sort((a, b) => a.name.compareTo(b.name));
    if (availableRewards.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('目前沒有可發放的兌換券。')),
      );
      return;
    }

    backend.VeevaActivity? selectedActivity;
    AdminRewardItem selectedReward = availableRewards.first;
    final searchController = TextEditingController();
    final noteController = TextEditingController(text: '手動批量發放');
    var selectedMemberIds = <String>{};
    var query = '';
    var isSending = false;
    String? formError;

    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final candidates = _batchMemberCandidates(
              activity: selectedActivity,
              reward: selectedReward,
              query: query,
            );
            final visibleIds = candidates.map((item) => item.member.id).toSet();
            final selectedVisibleCount =
                selectedMemberIds.intersection(visibleIds).length;
            final allVisibleSelected = visibleIds.isNotEmpty &&
                selectedVisibleCount == visibleIds.length;
            final selectedCount = selectedMemberIds.length;
            final canSend = selectedCount > 0 &&
                selectedReward.stock >= selectedCount &&
                !isSending;

            return AlertDialog(
              title: const Text('批量發放兌換券'),
              content: SizedBox(
                width: 920,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Wrap(
                        spacing: 12,
                        runSpacing: 12,
                        children: [
                          SizedBox(
                            width: 360,
                            child: DropdownButtonFormField<AdminRewardItem>(
                              value: selectedReward,
                              isExpanded: true,
                              decoration: const InputDecoration(
                                labelText: '發放兌換券',
                                prefixIcon: Icon(Icons.card_giftcard_outlined),
                              ),
                              items: [
                                for (final reward in availableRewards)
                                  DropdownMenuItem(
                                    value: reward,
                                    child: Text(
                                      '${reward.name}（庫存 ${reward.stock}）',
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                              ],
                              onChanged: isSending
                                  ? null
                                  : (value) {
                                      if (value == null) return;
                                      setDialogState(() {
                                        selectedReward = value;
                                        selectedMemberIds = {};
                                        formError = null;
                                      });
                                    },
                            ),
                          ),
                          SizedBox(
                            width: 360,
                            child:
                                DropdownButtonFormField<backend.VeevaActivity?>(
                              value: selectedActivity,
                              isExpanded: true,
                              decoration: const InputDecoration(
                                labelText: '關聯活動（選填）',
                                prefixIcon: Icon(Icons.campaign_outlined),
                              ),
                              items: [
                                const DropdownMenuItem<backend.VeevaActivity?>(
                                  value: null,
                                  child: Text('不關聯活動，單純發券'),
                                ),
                                for (final activity in widget.activities)
                                  DropdownMenuItem<backend.VeevaActivity?>(
                                    value: activity,
                                    child: Text(
                                      activity.title,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                              ],
                              onChanged: isSending
                                  ? null
                                  : (value) {
                                      setDialogState(() {
                                        selectedActivity = value;
                                        selectedMemberIds = {};
                                        formError = null;
                                      });
                                    },
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: noteController,
                        decoration: const InputDecoration(
                          labelText: '備註（選填）',
                          prefixIcon: Icon(Icons.notes_outlined),
                        ),
                        enabled: !isSending,
                      ),
                      const SizedBox(height: 12),
                      _MemberSearchField(
                        controller: searchController,
                        onChanged: (value) => setDialogState(() {
                          query = value;
                        }),
                        onClear: query.trim().isEmpty
                            ? null
                            : () => setDialogState(() {
                                  searchController.clear();
                                  query = '';
                                }),
                      ),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          _DistributionInfoChip(
                            icon: Icons.groups_outlined,
                            label: '已選 $selectedCount 位',
                          ),
                          _DistributionInfoChip(
                            icon: Icons.inventory_2_outlined,
                            label: '可用庫存 ${selectedReward.stock} 張',
                          ),
                          TextButton.icon(
                            onPressed: isSending || visibleIds.isEmpty
                                ? null
                                : () => setDialogState(() {
                                      if (allVisibleSelected) {
                                        selectedMemberIds = {
                                          ...selectedMemberIds,
                                        }..removeAll(visibleIds);
                                      } else {
                                        selectedMemberIds = {
                                          ...selectedMemberIds,
                                          ...visibleIds,
                                        };
                                      }
                                      formError = null;
                                    }),
                            icon: Icon(
                              allVisibleSelected
                                  ? Icons.check_box_outlined
                                  : Icons.check_box_outline_blank,
                            ),
                            label: Text(allVisibleSelected ? '取消全選' : '全選目前清單'),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      if (candidates.isEmpty)
                        const _EmptyListMessage(message: '沒有符合條件的會員。')
                      else
                        _FullWidthDataTable(
                          minWidth: 920,
                          child: DataTable(
                            horizontalMargin: 12,
                            columnSpacing: 18,
                            headingRowColor: WidgetStateProperty.all(
                              const Color(0xFFFFFAF3),
                            ),
                            columns: const [
                              DataColumn(label: Text('選取')),
                              DataColumn(label: Text('會員')),
                              DataColumn(label: Text('電話')),
                              DataColumn(label: Text('活動狀態')),
                              DataColumn(label: Text('兌換券狀態')),
                            ],
                            rows: [
                              for (final candidate in candidates)
                                DataRow(
                                  selected: selectedMemberIds
                                      .contains(candidate.member.id),
                                  cells: [
                                    DataCell(
                                      Checkbox(
                                        value: selectedMemberIds
                                            .contains(candidate.member.id),
                                        onChanged: isSending
                                            ? null
                                            : (checked) => setDialogState(() {
                                                  selectedMemberIds = {
                                                    ...selectedMemberIds,
                                                  };
                                                  if (checked == true) {
                                                    selectedMemberIds.add(
                                                      candidate.member.id,
                                                    );
                                                  } else {
                                                    selectedMemberIds.remove(
                                                      candidate.member.id,
                                                    );
                                                  }
                                                  formError = null;
                                                }),
                                      ),
                                    ),
                                    DataCell(_DistributionMemberCell(
                                      member: candidate.member,
                                    )),
                                    DataCell(
                                      Text(_memberPhoneLabel(candidate.member)),
                                    ),
                                    DataCell(Text(candidate.activityStatus)),
                                    DataCell(Text(candidate.rewardStatus)),
                                  ],
                                ),
                            ],
                          ),
                        ),
                      if (formError != null) ...[
                        const SizedBox(height: 12),
                        _InlineError(message: formError!),
                      ],
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: isSending
                      ? null
                      : () => Navigator.of(dialogContext).pop(),
                  child: const Text('取消'),
                ),
                FilledButton.icon(
                  onPressed: canSend
                      ? () async {
                          final selectedMembers = [
                            for (final member in widget.members)
                              if (selectedMemberIds.contains(member.id)) member,
                          ];
                          if (selectedMembers.isEmpty) {
                            setDialogState(() => formError = '請先選擇會員。');
                            return;
                          }
                          if (selectedMembers.length > selectedReward.stock) {
                            setDialogState(
                              () => formError = '選取人數超過庫存，請減少會員或更換兌換券。',
                            );
                            return;
                          }

                          setDialogState(() {
                            isSending = true;
                            formError = null;
                            batchIssuingMemberIds = {
                              ...batchIssuingMemberIds,
                              ...selectedMemberIds,
                            };
                          });

                          try {
                            for (final member in selectedMembers) {
                              final currentReward = widget.rewards.firstWhere(
                                (item) => item.id == selectedReward.id,
                                orElse: () => selectedReward,
                              );
                              await widget.onGrantReward(
                                member: member,
                                reward: currentReward,
                                quantity: 1,
                                note: noteController.text,
                                activity: selectedActivity,
                                source: 'manualBatch',
                                preventDuplicate: false,
                                showSnackBar: false,
                              );
                            }
                            if (!dialogContext.mounted) return;
                            Navigator.of(dialogContext).pop();
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    '已批量發放 ${selectedReward.name} 給 ${selectedMembers.length} 位會員。',
                                  ),
                                ),
                              );
                            }
                          } catch (_) {
                            if (!dialogContext.mounted) return;
                            setDialogState(() {
                              isSending = false;
                              formError = '批量發放失敗，請確認庫存、兌換券狀態與 Firestore 設定。';
                            });
                          } finally {
                            if (mounted) {
                              setState(() {
                                batchIssuingMemberIds = {
                                  ...batchIssuingMemberIds,
                                }..removeAll(selectedMemberIds);
                              });
                            }
                            if (dialogContext.mounted) {
                              setDialogState(() {});
                            }
                          }
                        }
                      : null,
                  icon: isSending
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.card_giftcard_outlined),
                  label: Text(isSending ? '發放中' : '確認批量發放'),
                ),
              ],
            );
          },
        );
      },
    );

    searchController.dispose();
    noteController.dispose();
  }

  List<_BatchDistributionCandidate> _batchMemberCandidates({
    required backend.VeevaActivity? activity,
    required AdminRewardItem reward,
    required String query,
  }) {
    final normalizedQuery = _normalizeMemberSearch(query);
    final candidates = [
      for (final member in widget.members)
        if (_memberMatchesSearch(member, normalizedQuery))
          _BatchDistributionCandidate(
            member: member,
            activityStatus: _batchActivityStatus(activity, member),
            rewardStatus: _batchRewardStatus(activity, reward, member),
          ),
    ];
    candidates.sort((a, b) {
      final aPriority = _batchActivityStatusPriority(a.activityStatus);
      final bPriority = _batchActivityStatusPriority(b.activityStatus);
      if (aPriority != bPriority) return aPriority.compareTo(bPriority);
      return a.member.name.compareTo(b.member.name);
    });
    return candidates;
  }

  String _batchActivityStatus(
    backend.VeevaActivity? activity,
    backend.VeevaMember member,
  ) {
    if (activity == null) return '未關聯活動';
    final record = _recordForMember(activity, member);
    if (record == null) return '未參加';
    return _participantStatusText(record);
  }

  int _batchActivityStatusPriority(String status) {
    return switch (status) {
      '未參加' => 0,
      '未關聯活動' => 1,
      '已參加' => 2,
      '審核中' => 3,
      '已完成' => 4,
      _ => 5,
    };
  }

  String _batchRewardStatus(
    backend.VeevaActivity? activity,
    AdminRewardItem reward,
    backend.VeevaMember member,
  ) {
    for (final item in widget.memberRewards) {
      final sameActivity = activity == null
          ? item.activityId == null || item.activityId!.isEmpty
          : item.activityId == activity.id;
      if (item.memberId == member.id &&
          item.rewardId == reward.id &&
          item.source == 'manualBatch' &&
          sameActivity &&
          item.status != 'rejected') {
        return _isIssuedGrant(item) ? '已領過' : '待確認';
      }
    }
    return batchIssuingMemberIds.contains(member.id) ? '發放中' : '尚未發放';
  }

  backend.VeevaActivityRecord? _recordForMember(
    backend.VeevaActivity activity,
    backend.VeevaMember member,
  ) {
    backend.VeevaActivityRecord? selected;
    for (final record in widget.activityRecords) {
      if (record.activityId != activity.id ||
          (record.memberId != member.id &&
              record.memberLineUserId != member.lineUserId)) {
        continue;
      }
      if (selected == null ||
          _activityRecordPriority(record) >=
              _activityRecordPriority(selected)) {
        selected = record;
      }
    }
    return selected;
  }

  DataRow _participantRow({
    required backend.VeevaActivity activity,
    required _DistributionParticipant participant,
    required StateSetter setDialogState,
    required VoidCallback refreshParticipants,
    required ValueChanged<String?> setFormError,
  }) {
    final completionRewardGrant = _completionRewardGrant(activity, participant);
    final hasCompletionReward =
        completionRewardGrant != null && _isIssuedGrant(completionRewardGrant);
    final hasPendingCompletionReward =
        completionRewardGrant != null && _isPendingGrant(completionRewardGrant);
    final completionReward = _rewardFor(activity.completionRewardId);
    final isIssuing = issuingParticipantIds.contains(participant.member.id);
    final isRejecting = rejectingParticipantIds.contains(participant.member.id);
    final isReadyForReward = participant.record.isCompleted ||
        activity.type == backend.VeevaActivityType.registration ||
        hasPendingCompletionReward;
    final canIssue =
        isReadyForReward && completionReward != null && !hasCompletionReward;
    final canReject = (participant.record.status == 'pendingReview' ||
            participant.record.isCompleted) &&
        !hasCompletionReward &&
        !isIssuing &&
        !isRejecting;
    return DataRow(
      cells: [
        DataCell(_DistributionMemberCell(member: participant.member)),
        DataCell(Text(_participantStatusText(participant.record))),
        DataCell(
          Text(
            activity.completionRewardId == null
                ? '未設定'
                : participant.record.status == 'rejected'
                    ? '可重新填寫'
                    : hasCompletionReward
                        ? '已發放'
                        : hasPendingCompletionReward
                            ? '待確認'
                            : !isReadyForReward
                                ? '尚未完成'
                                : completionReward == null
                                    ? '找不到兌換券'
                                    : completionReward.name,
          ),
        ),
        DataCell(Text(_referrerRewardStatus(activity, participant.member))),
        DataCell(
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              FilledButton.icon(
                onPressed: !canIssue || isIssuing || isRejecting
                    ? null
                    : () async {
                        setDialogState(() {
                          setFormError(null);
                          issuingParticipantIds = {
                            ...issuingParticipantIds,
                            participant.member.id,
                          };
                        });
                        try {
                          final bonusText = await _grantActivityReward(
                            activity,
                            participant.member,
                          );
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  '已發放 ${completionReward.name} 給 ${participant.member.name}$bonusText。',
                                ),
                              ),
                            );
                          }
                        } catch (_) {
                          setDialogState(() {
                            setFormError('發放失敗，請確認庫存、兌換券狀態與 Firestore 設定。');
                          });
                        } finally {
                          if (mounted) {
                            setState(() {
                              issuingParticipantIds = {
                                ...issuingParticipantIds,
                              }..remove(participant.member.id);
                            });
                          }
                          setDialogState(() {});
                        }
                      },
                icon: isIssuing
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Icon(
                        hasCompletionReward
                            ? Icons.check_circle_outline
                            : Icons.card_giftcard_outlined,
                      ),
                label: Text(
                  hasCompletionReward
                      ? '已發放'
                      : isIssuing
                          ? '發放中'
                          : hasPendingCompletionReward
                              ? '確認發放'
                              : '發放',
                ),
              ),
              OutlinedButton.icon(
                onPressed: !canReject
                    ? null
                    : () async {
                        setDialogState(() {
                          setFormError(null);
                          rejectingParticipantIds = {
                            ...rejectingParticipantIds,
                            participant.member.id,
                          };
                        });
                        try {
                          await widget
                              .onRejectActivityCompletion(participant.record);
                          refreshParticipants();
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  '已將 ${participant.member.name} 標記為不允許，可重新填寫問卷。',
                                ),
                              ),
                            );
                          }
                        } catch (_) {
                          setDialogState(() {
                            setFormError('不允許更新失敗，請確認 Firestore 設定。');
                          });
                        } finally {
                          if (mounted) {
                            setState(() {
                              rejectingParticipantIds = {
                                ...rejectingParticipantIds,
                              }..remove(participant.member.id);
                            });
                          }
                          setDialogState(() {});
                        }
                      },
                icon: isRejecting
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.block_outlined),
                label: Text(isRejecting ? '處理中' : '不允許'),
              ),
            ],
          ),
        ),
      ],
    );
  }

  String _participantStatusText(backend.VeevaActivityRecord record) {
    if (record.status == 'rejected') return '不允許';
    if (record.status == 'pendingReview') return '審核中';
    if (record.isCompleted) return '已完成';
    return '已參加';
  }

  Future<String> _grantActivityReward(
    backend.VeevaActivity activity,
    backend.VeevaMember participant,
  ) async {
    final completionReward = _rewardFor(activity.completionRewardId);
    if (completionReward == null) {
      throw StateError('completion reward missing');
    }
    await widget.onGrantReward(
      member: participant,
      reward: completionReward,
      quantity: 1,
      note: '活動完成獎勵',
      activity: activity,
      source: 'activityCompletion',
      preventDuplicate: true,
    );

    final referrerReward = _rewardFor(activity.referrerRewardId);
    final referrerId = participant.referredByMemberId?.trim();
    if (referrerReward == null ||
        referrerId == null ||
        referrerId.isEmpty ||
        _referralRewardAlreadyUsed(participant)) {
      return '';
    }

    final referrer = _memberForId(referrerId);
    await widget.onGrantReward(
      member: referrer,
      reward: referrerReward,
      quantity: 1,
      note: '邀請者加碼獎勵',
      activity: activity,
      sourceMember: participant,
      source: 'referralActivityCompletion',
      preventDuplicate: true,
    );
    return '，並已自動發放邀請者加碼';
  }
}

class _DistributionActivityCard extends StatelessWidget {
  const _DistributionActivityCard({
    required this.activity,
    required this.participantCount,
    required this.issuedCount,
    required this.completionIssuedCount,
    required this.referralIssuedCount,
    required this.manualIssuedCount,
    required this.totalIssuedCount,
    required this.onOpen,
  });

  final backend.VeevaActivity activity;
  final int participantCount;
  final int issuedCount;
  final int completionIssuedCount;
  final int referralIssuedCount;
  final int manualIssuedCount;
  final int totalIssuedCount;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFAF3),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFEADFCE)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            activity.title,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 8),
          _ActivityStatusChip(activity: activity),
          const SizedBox(height: 8),
          Text('完成獎勵：$completionIssuedCount 張'),
          const SizedBox(height: 4),
          Text('邀請獎勵：$referralIssuedCount 張'),
          const SizedBox(height: 4),
          Text('手動發放：$manualIssuedCount 張'),
          const SizedBox(height: 4),
          Text('參加者：$participantCount 位，已發放 $issuedCount 張'),
          const SizedBox(height: 4),
          Text('已發放總數：$totalIssuedCount 張'),
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerRight,
            child: FilledButton.icon(
              onPressed: onOpen,
              icon: const Icon(Icons.card_giftcard_outlined),
              label: const Text('發放獎勵'),
            ),
          ),
        ],
      ),
    );
  }
}

class _DistributionParticipant {
  const _DistributionParticipant({
    required this.record,
    required this.member,
  });

  final backend.VeevaActivityRecord record;
  final backend.VeevaMember member;
}

class _MemberRewardSummary {
  const _MemberRewardSummary({
    required this.member,
    required this.rewards,
  });

  final backend.VeevaMember member;
  final List<backend.VeevaMemberReward> rewards;

  int get completionCount =>
      rewards.where((reward) => reward.source == 'activityCompletion').length;

  int get referralCount => rewards
      .where((reward) => reward.source == 'referralActivityCompletion')
      .length;

  int get manualCount => rewards
      .where((reward) =>
          reward.source != 'activityCompletion' &&
          reward.source != 'referralActivityCompletion')
      .length;

  int get availableCount =>
      rewards.where((reward) => reward.status == 'issued').length;

  int get redeemedCount =>
      rewards.where((reward) => reward.status == 'redeemed').length;

  int get totalCount => rewards.length;
}

class _BatchDistributionCandidate {
  const _BatchDistributionCandidate({
    required this.member,
    required this.activityStatus,
    required this.rewardStatus,
  });

  final backend.VeevaMember member;
  final String activityStatus;
  final String rewardStatus;
}

class _DistributionInfoChip extends StatelessWidget {
  const _DistributionInfoChip({
    required this.icon,
    required this.label,
  });

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF2DF),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: const Color(0xFFC66D00)),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(
              color: Color(0xFFC66D00),
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _DistributionMemberCell extends StatelessWidget {
  const _DistributionMemberCell({required this.member});

  final backend.VeevaMember member;

  @override
  Widget build(BuildContext context) {
    final avatarUrl = member.avatarUrl;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        CircleAvatar(
          radius: 18,
          backgroundImage: avatarUrl == null ? null : NetworkImage(avatarUrl),
          child: avatarUrl == null && member.name.isNotEmpty
              ? Text(member.name.characters.first)
              : null,
        ),
        const SizedBox(width: 10),
        Flexible(
          child: Text(
            member.name,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontWeight: FontWeight.w800),
          ),
        ),
      ],
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
  _ActivityListPage currentPage = _ActivityListPage.active;

  @override
  Widget build(BuildContext context) {
    final isCompact = MediaQuery.sizeOf(context).width < 820;
    final archivedActivities =
        widget.activities.where(_isArchivedActivity).toList();
    final activeActivities = widget.activities
        .where((activity) => !_isArchivedActivity(activity))
        .toList();
    final isArchivePage = currentPage == _ActivityListPage.archived;
    final sourceActivities =
        isArchivePage ? archivedActivities : activeActivities;
    final visibleActivities = sourceActivities.where(_matchesFilter).toList()
      ..sort((a, b) {
        if (a.active != b.active) return a.active ? -1 : 1;
        return a.title.compareTo(b.title);
      });
    final activeCount =
        activeActivities.where((activity) => activity.active).length;
    final publishedCount = activeActivities
        .where((activity) =>
            activity.status == backend.VeevaContentStatus.published)
        .length;
    final draftCount = activeActivities
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
                  value: '${activeActivities.length}',
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
                _ActivityHeader(
                  onCreate: widget.onCreate,
                  showCreateButton: !isArchivePage,
                ),
                const SizedBox(height: 14),
                _ActivityPageTabs(
                  selected: currentPage,
                  activeCount: activeActivities.length,
                  archivedCount: archivedActivities.length,
                  onChanged: (value) {
                    setState(() {
                      currentPage = value;
                      statusFilter = null;
                    });
                  },
                ),
                const SizedBox(height: 16),
                _ActivityFilters(
                  query: query,
                  statusFilter: statusFilter,
                  showStatusFilter: !isArchivePage,
                  onQueryChanged: (value) => setState(() => query = value),
                  onStatusChanged: (value) =>
                      setState(() => statusFilter = value),
                ),
                const SizedBox(height: 16),
                if (visibleActivities.isEmpty)
                  _EmptyListMessage(
                    message: isArchivePage ? '目前沒有已封存的活動。' : '目前沒有符合條件的活動。',
                  )
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
          activity.actionUrl,
          activity.periodText,
          activity.activityTime,
          activity.location,
          activity.organizer,
          activity.note,
          ...activity.noticeItems,
          _activityStatusLabel(activity),
        ].whereType<String>().any((value) {
          return value.toLowerCase().contains(keyword);
        });
    final matchesStatus = currentPage == _ActivityListPage.archived ||
        statusFilter == null ||
        (statusFilter == _activityActiveFilterValue && activity.active) ||
        activity.status.name == statusFilter;
    return matchesQuery && matchesStatus;
  }

  bool _isArchivedActivity(backend.VeevaActivity activity) {
    return activity.status == backend.VeevaContentStatus.archived;
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
                          color: Color(0xFF8A8D8F),
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
                  if (activity.actionUrl?.isNotEmpty == true)
                    _ActivityDetailLine(
                      icon: Icons.open_in_new_outlined,
                      label: '操作連結',
                      value: activity.actionUrl!,
                    ),
                  _ActivityDetailLine(
                    icon: Icons.date_range_outlined,
                    label: '活動日期',
                    value: activity.periodText ?? '未設定',
                  ),
                  _ActivityDetailLine(
                    icon: Icons.schedule_outlined,
                    label: '時間',
                    value: activity.activityTime ?? '依活動公告為準',
                  ),
                  _ActivityDetailLine(
                    icon: Icons.place_outlined,
                    label: '地點',
                    value: activity.location ?? '依活動類型預設',
                  ),
                  _ActivityDetailLine(
                    icon: Icons.apartment_outlined,
                    label: '主辦單位',
                    value: activity.organizer ?? 'VeeVa Member',
                  ),
                  if (activity.note?.isNotEmpty == true)
                    _ActivityDetailLine(
                      icon: Icons.sticky_note_2_outlined,
                      label: '活動內容',
                      value: activity.note!,
                    ),
                  if (activity.noticeItems.isNotEmpty)
                    _ActivityDetailLine(
                      icon: Icons.info_outline,
                      label: '注意事項',
                      value: activity.noticeItems.join('、'),
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
  const _ActivityHeader({
    required this.onCreate,
    required this.showCreateButton,
  });

  final VoidCallback onCreate;
  final bool showCreateButton;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Icon(Icons.campaign_outlined, color: Color(0xFFC66D00)),
        const SizedBox(width: 10),
        const Expanded(
          child: Text(
            '活動管理',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
          ),
        ),
        if (showCreateButton)
          FilledButton.icon(
            onPressed: onCreate,
            icon: const Icon(Icons.add),
            label: const Text('新增活動'),
          ),
      ],
    );
  }
}

class _ActivityPageTabs extends StatelessWidget {
  const _ActivityPageTabs({
    required this.selected,
    required this.activeCount,
    required this.archivedCount,
    required this.onChanged,
  });

  final _ActivityListPage selected;
  final int activeCount;
  final int archivedCount;
  final ValueChanged<_ActivityListPage> onChanged;

  @override
  Widget build(BuildContext context) {
    final isCompact = MediaQuery.sizeOf(context).width < 560;
    final children = [
      _ActivityPageTabButton(
        label: '活動列表',
        count: activeCount,
        icon: Icons.list_alt_outlined,
        selected: selected == _ActivityListPage.active,
        onTap: () => onChanged(_ActivityListPage.active),
      ),
      _ActivityPageTabButton(
        label: '已封存',
        count: archivedCount,
        icon: Icons.archive_outlined,
        selected: selected == _ActivityListPage.archived,
        onTap: () => onChanged(_ActivityListPage.archived),
      ),
    ];

    if (isCompact) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          children[0],
          const SizedBox(height: 8),
          children[1],
        ],
      );
    }

    return Row(
      children: [
        Expanded(child: children[0]),
        const SizedBox(width: 10),
        Expanded(child: children[1]),
      ],
    );
  }
}

class _ActivityPageTabButton extends StatelessWidget {
  const _ActivityPageTabButton({
    required this.label,
    required this.count,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final int count;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      label: label,
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: selected ? null : onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: selected ? const Color(0xFFFFF2DF) : const Color(0xFFFFFAF3),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color:
                  selected ? const Color(0xFFFFC76B) : const Color(0xFFEADFCE),
            ),
          ),
          child: Row(
            children: [
              Icon(
                icon,
                color: selected
                    ? const Color(0xFFC66D00)
                    : const Color(0xFF8A8D8F),
                size: 20,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: selected
                        ? const Color(0xFFC66D00)
                        : const Color(0xFF303236),
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: const Color(0xFFEADFCE)),
                ),
                child: Text(
                  '$count',
                  style: const TextStyle(
                    color: Color(0xFF303236),
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ActivityFilters extends StatelessWidget {
  const _ActivityFilters({
    required this.query,
    required this.statusFilter,
    required this.showStatusFilter,
    required this.onQueryChanged,
    required this.onStatusChanged,
  });

  final String query;
  final String? statusFilter;
  final bool showStatusFilter;
  final ValueChanged<String> onQueryChanged;
  final ValueChanged<String?> onStatusChanged;

  @override
  Widget build(BuildContext context) {
    final isCompact = MediaQuery.sizeOf(context).width < 760;
    final search = TextField(
      onChanged: onQueryChanged,
      decoration: InputDecoration(
        hintText: '搜尋活動名稱、標籤、獎勵、活動內容',
        prefixIcon: const Icon(Icons.search),
        isDense: true,
        filled: true,
        fillColor: const Color(0xFFFFFAF3),
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
        fillColor: const Color(0xFFFFFAF3),
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
          if (status != backend.VeevaContentStatus.archived)
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
          if (showStatusFilter) ...[
            const SizedBox(height: 10),
            statusDropdown,
          ],
        ],
      );
    }

    if (!showStatusFilter) {
      return Row(
        children: [
          Expanded(child: search),
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
    return _FullWidthDataTable(
      minWidth: 1120,
      child: DataTable(
        headingRowColor: WidgetStateProperty.all(const Color(0xFFFFFAF3)),
        horizontalMargin: 16,
        columnSpacing: 18,
        dataRowMinHeight: 72,
        dataRowMaxHeight: 96,
        columns: const [
          DataColumn(label: Text('活動名稱')),
          DataColumn(label: Text('類型')),
          DataColumn(label: Text('狀態')),
          DataColumn(label: Text('獎勵')),
          DataColumn(label: Text('活動日期')),
          DataColumn(label: Text('活動內容')),
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
        color: const Color(0xFFFFFAF3),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFEADFCE)),
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
            label: '活動日期',
            value: activity.periodText ?? '未設定',
          ),
          if (activity.note?.isNotEmpty == true)
            _ActivityDetailLine(
              icon: Icons.sticky_note_2_outlined,
              label: '活動內容',
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
            style: const TextStyle(color: Color(0xFF8A8D8F), fontSize: 12),
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
          color: Color(0xFF303236),
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
        color: const Color(0xFFFFF2DF),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(_activityTypeIcon(type),
              size: 15, color: const Color(0xFFC66D00)),
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
          Icon(icon, size: 18, color: const Color(0xFF8A8D8F)),
          const SizedBox(width: 8),
          SizedBox(
            width: 42,
            child: Text(
              label,
              style: const TextStyle(
                color: Color(0xFF8A8D8F),
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

class _NewsManagement extends StatefulWidget {
  const _NewsManagement({
    required this.news,
    required this.newsEnabled,
    required this.onCreate,
    required this.onEdit,
    required this.onStatusChanged,
    required this.onNewsEnabledChanged,
  });

  final List<backend.VeevaNews> news;
  final bool newsEnabled;
  final VoidCallback onCreate;
  final ValueChanged<backend.VeevaNews> onEdit;
  final Future<void> Function(
    backend.VeevaNews item,
    backend.VeevaContentStatus status,
  ) onStatusChanged;
  final Future<void> Function(bool enabled) onNewsEnabledChanged;

  @override
  State<_NewsManagement> createState() => _NewsManagementState();
}

class _NewsManagementState extends State<_NewsManagement> {
  String query = '';
  backend.VeevaContentStatus? statusFilter;

  @override
  Widget build(BuildContext context) {
    final isCompact = MediaQuery.sizeOf(context).width < 820;
    final visibleNews = widget.news.where(_matchesFilter).toList()
      ..sort((a, b) => b.date.compareTo(a.date));
    final publishedCount = widget.news
        .where((item) => item.status == backend.VeevaContentStatus.published)
        .length;
    final draftCount = widget.news
        .where((item) => item.status == backend.VeevaContentStatus.draft)
        .length;
    final scheduledCount = widget.news
        .where((item) => item.status == backend.VeevaContentStatus.scheduled)
        .length;
    final metrics = [
      _MetricCard(
        label: '已發布',
        value: '$publishedCount',
        icon: Icons.public_outlined,
      ),
      _MetricCard(
        label: '草稿',
        value: '$draftCount',
        icon: Icons.edit_note_outlined,
      ),
      _MetricCard(
        label: '排程中',
        value: '$scheduledCount',
        icon: Icons.schedule_outlined,
      ),
      _MetricCard(
        label: '文章總數',
        value: '${widget.news.length}',
        icon: Icons.article_outlined,
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
        const SizedBox(height: 18),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _NewsHeader(
                  newsEnabled: widget.newsEnabled,
                  onCreate: widget.onCreate,
                  onNewsEnabledChanged: widget.onNewsEnabledChanged,
                ),
                const SizedBox(height: 16),
                _NewsFilters(
                  query: query,
                  statusFilter: statusFilter,
                  onQueryChanged: (value) => setState(() => query = value),
                  onStatusChanged: (value) =>
                      setState(() => statusFilter = value),
                ),
                const SizedBox(height: 16),
                if (visibleNews.isEmpty)
                  const _EmptyListMessage(message: '目前沒有符合條件的最新資訊。')
                else if (isCompact)
                  Column(
                    children: [
                      for (final item in visibleNews)
                        _NewsMobileCard(
                          item: item,
                          onEdit: widget.onEdit,
                          onPreview: _showPreview,
                          onStatusChanged: widget.onStatusChanged,
                        ),
                    ],
                  )
                else
                  _NewsDataTable(
                    news: visibleNews,
                    onEdit: widget.onEdit,
                    onPreview: _showPreview,
                    onStatusChanged: widget.onStatusChanged,
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  bool _matchesFilter(backend.VeevaNews item) {
    final keyword = query.trim().toLowerCase();
    final matchesQuery = keyword.isEmpty ||
        [
          item.title,
          item.summary,
          item.content,
          item.detailContent,
          item.keyPoints.join(' '),
          item.source,
          item.category,
          item.date,
          _contentStatusLabel(item.status),
        ].whereType<String>().any((value) {
          return value.toLowerCase().contains(keyword);
        });
    final matchesStatus = statusFilter == null || item.status == statusFilter;
    return matchesQuery && matchesStatus;
  }

  void _showPreview(backend.VeevaNews item) {
    showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('文章預覽'),
          content: SizedBox(
            width: 560,
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      _NewsStatusChip(status: item.status),
                      const SizedBox(width: 8),
                      Text(
                        item.category ?? item.source,
                        style: const TextStyle(
                          color: Color(0xFF8A8D8F),
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Text(
                    item.title,
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '${item.date} ・ ${item.source}',
                    style: const TextStyle(
                      color: Color(0xFF8A8D8F),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  if (item.imageUrl?.isNotEmpty == true) ...[
                    const SizedBox(height: 14),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.network(
                        item.imageUrl!,
                        height: 180,
                        width: double.infinity,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) {
                          return Container(
                            height: 120,
                            alignment: Alignment.center,
                            color: const Color(0xFFF1F4F3),
                            child: const Text('圖片無法載入'),
                          );
                        },
                      ),
                    ),
                  ],
                  const SizedBox(height: 14),
                  Text(
                    item.summary,
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      height: 1.5,
                    ),
                  ),
                  if (item.keyPoints.isNotEmpty) ...[
                    const SizedBox(height: 14),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFF2DF),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: const Color(0xFFFFF2DF)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            '重點內容',
                            style: TextStyle(
                              color: Color(0xFFFF9812),
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          const SizedBox(height: 8),
                          for (final point in item.keyPoints)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 6),
                              child: Text('• $point'),
                            ),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: 12),
                  Text(
                    _newsBody(item),
                    style: const TextStyle(height: 1.55),
                  ),
                  const SizedBox(height: 12),
                  _ActivityDetailLine(
                    icon: Icons.thumb_up_alt_outlined,
                    label: '有幫助人數',
                    value: '${item.helpfulCount}',
                  ),
                  if (item.externalUrl?.isNotEmpty == true) ...[
                    const SizedBox(height: 14),
                    _ActivityDetailLine(
                      icon: Icons.link_outlined,
                      label: '連結',
                      value: item.externalUrl!,
                    ),
                  ],
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
                widget.onEdit(item);
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

class _NewsHeader extends StatelessWidget {
  const _NewsHeader({
    required this.newsEnabled,
    required this.onCreate,
    required this.onNewsEnabledChanged,
  });

  final bool newsEnabled;
  final VoidCallback onCreate;
  final Future<void> Function(bool enabled) onNewsEnabledChanged;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        const Icon(Icons.newspaper_outlined, color: Color(0xFFC66D00)),
        const Text(
          '最新資訊管理',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
        ),
        ConstrainedBox(
          constraints: const BoxConstraints(minWidth: 230),
          child: SwitchListTile(
            dense: true,
            contentPadding: EdgeInsets.zero,
            value: newsEnabled,
            onChanged: onNewsEnabledChanged,
            title: const Text(
              '前端顯示最新資訊',
              style: TextStyle(fontWeight: FontWeight.w800),
            ),
            subtitle: Text(newsEnabled ? '會員端會顯示最新資訊頁面' : '會員端會隱藏最新資訊頁面'),
            activeColor: const Color(0xFFC66D00),
          ),
        ),
        FilledButton.icon(
          onPressed: onCreate,
          icon: const Icon(Icons.add),
          label: const Text('新增文章'),
        ),
      ],
    );
  }
}

class _NewsFilters extends StatelessWidget {
  const _NewsFilters({
    required this.query,
    required this.statusFilter,
    required this.onQueryChanged,
    required this.onStatusChanged,
  });

  final String query;
  final backend.VeevaContentStatus? statusFilter;
  final ValueChanged<String> onQueryChanged;
  final ValueChanged<backend.VeevaContentStatus?> onStatusChanged;

  @override
  Widget build(BuildContext context) {
    final isCompact = MediaQuery.sizeOf(context).width < 760;
    final search = TextField(
      onChanged: onQueryChanged,
      decoration: InputDecoration(
        hintText: '搜尋文章標題、摘要、分類、來源',
        prefixIcon: const Icon(Icons.search),
        isDense: true,
        filled: true,
        fillColor: const Color(0xFFFFFAF3),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide.none,
        ),
      ),
    );
    final statusDropdown = DropdownButtonFormField<backend.VeevaContentStatus?>(
      value: statusFilter,
      decoration: InputDecoration(
        labelText: '狀態',
        isDense: true,
        filled: true,
        fillColor: const Color(0xFFFFFAF3),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide.none,
        ),
      ),
      items: [
        const DropdownMenuItem<backend.VeevaContentStatus?>(
          value: null,
          child: Text('全部狀態'),
        ),
        for (final status in backend.VeevaContentStatus.values)
          DropdownMenuItem<backend.VeevaContentStatus?>(
            value: status,
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

class _NewsDataTable extends StatelessWidget {
  const _NewsDataTable({
    required this.news,
    required this.onEdit,
    required this.onPreview,
    required this.onStatusChanged,
  });

  final List<backend.VeevaNews> news;
  final ValueChanged<backend.VeevaNews> onEdit;
  final ValueChanged<backend.VeevaNews> onPreview;
  final Future<void> Function(
    backend.VeevaNews item,
    backend.VeevaContentStatus status,
  ) onStatusChanged;

  @override
  Widget build(BuildContext context) {
    return _FullWidthDataTable(
      minWidth: 1060,
      child: DataTable(
        headingRowColor: WidgetStateProperty.all(const Color(0xFFFFFAF3)),
        horizontalMargin: 16,
        columnSpacing: 18,
        dataRowMinHeight: 76,
        dataRowMaxHeight: 104,
        columns: const [
          DataColumn(label: Text('文章')),
          DataColumn(label: Text('狀態')),
          DataColumn(label: Text('發布日期')),
          DataColumn(label: Text('來源')),
          DataColumn(label: Text('分類')),
          DataColumn(label: Text('操作')),
        ],
        rows: [
          for (final item in news)
            DataRow(
              cells: [
                DataCell(_NewsTitleCell(item: item)),
                DataCell(_NewsStatusChip(status: item.status)),
                DataCell(Text(item.date)),
                DataCell(Text(item.source)),
                DataCell(Text(item.category ?? '-')),
                DataCell(
                  _NewsActions(
                    item: item,
                    onEdit: onEdit,
                    onPreview: onPreview,
                    onStatusChanged: onStatusChanged,
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }
}

class _NewsMobileCard extends StatelessWidget {
  const _NewsMobileCard({
    required this.item,
    required this.onEdit,
    required this.onPreview,
    required this.onStatusChanged,
  });

  final backend.VeevaNews item;
  final ValueChanged<backend.VeevaNews> onEdit;
  final ValueChanged<backend.VeevaNews> onPreview;
  final Future<void> Function(
    backend.VeevaNews item,
    backend.VeevaContentStatus status,
  ) onStatusChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFAF3),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFEADFCE)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: _NewsTitleCell(item: item)),
              const SizedBox(width: 8),
              _NewsStatusChip(status: item.status),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            item.summary,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 10),
          _ActivityDetailLine(
            icon: Icons.event_outlined,
            label: '日期',
            value: item.date,
          ),
          _ActivityDetailLine(
            icon: Icons.source_outlined,
            label: '來源',
            value: item.source,
          ),
          _ActivityDetailLine(
            icon: Icons.category_outlined,
            label: '分類',
            value: item.category ?? '-',
          ),
          const SizedBox(height: 10),
          _NewsActions(
            item: item,
            onEdit: onEdit,
            onPreview: onPreview,
            onStatusChanged: onStatusChanged,
          ),
        ],
      ),
    );
  }
}

class _NewsTitleCell extends StatelessWidget {
  const _NewsTitleCell({required this.item});

  final backend.VeevaNews item;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 260,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            item.title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontWeight: FontWeight.w900),
          ),
        ],
      ),
    );
  }
}

class _NewsActions extends StatelessWidget {
  const _NewsActions({
    required this.item,
    required this.onEdit,
    required this.onPreview,
    required this.onStatusChanged,
  });

  final backend.VeevaNews item;
  final ValueChanged<backend.VeevaNews> onEdit;
  final ValueChanged<backend.VeevaNews> onPreview;
  final Future<void> Function(
    backend.VeevaNews item,
    backend.VeevaContentStatus status,
  ) onStatusChanged;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 132,
      height: 36,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _ActivityActionIconButton(
            tooltip: '編輯',
            icon: Icons.edit_outlined,
            onPressed: () => onEdit(item),
          ),
          _ActivityActionIconButton(
            tooltip: '預覽',
            icon: Icons.visibility_outlined,
            onPressed: () => onPreview(item),
          ),
          PopupMenuButton<backend.VeevaContentStatus>(
            tooltip: '切換狀態',
            icon: const Icon(Icons.more_vert, size: 20),
            onSelected: (status) => onStatusChanged(item, status),
            itemBuilder: (context) {
              return [
                for (final status in backend.VeevaContentStatus.values)
                  PopupMenuItem(
                    value: status,
                    enabled: status != item.status,
                    child: Row(
                      children: [
                        Icon(
                          status == item.status
                              ? Icons.check_circle
                              : Icons.radio_button_unchecked,
                          size: 18,
                        ),
                        const SizedBox(width: 8),
                        Text(_contentStatusLabel(status)),
                      ],
                    ),
                  ),
              ];
            },
          ),
        ],
      ),
    );
  }
}

class _NewsStatusChip extends StatelessWidget {
  const _NewsStatusChip({required this.status});

  final backend.VeevaContentStatus status;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: _newsStatusColor(status),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        _contentStatusLabel(status),
        style: const TextStyle(
          color: Color(0xFF303236),
          fontSize: 12,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

String _newsBody(backend.VeevaNews item) {
  final detailContent = item.detailContent?.trim();
  if (detailContent != null && detailContent.isNotEmpty) {
    return detailContent;
  }
  final content = item.content?.trim();
  return content == null || content.isEmpty ? item.summary : content;
}

String _contentStatusLabel(backend.VeevaContentStatus status) {
  return switch (status) {
    backend.VeevaContentStatus.draft => '草稿',
    backend.VeevaContentStatus.scheduled => '排程中',
    backend.VeevaContentStatus.published => '已發布',
    backend.VeevaContentStatus.archived => '已封存',
  };
}

Color _newsStatusColor(backend.VeevaContentStatus status) {
  return switch (status) {
    backend.VeevaContentStatus.draft => const Color(0xFFEFF3F6),
    backend.VeevaContentStatus.scheduled => const Color(0xFFEAF0FF),
    backend.VeevaContentStatus.published => const Color(0xFFFFF2DF),
    backend.VeevaContentStatus.archived => const Color(0xFFFFF4D9),
  };
}

const _activityActiveFilterValue = 'active';

enum _ActivityListPage { active, archived }

String _activityTypeLabel(backend.VeevaActivityType type) {
  return switch (type) {
    backend.VeevaActivityType.survey => '問卷',
    backend.VeevaActivityType.registration => '活動報名',
    backend.VeevaActivityType.referral => '邀請好友',
    backend.VeevaActivityType.task => '任務活動',
    backend.VeevaActivityType.checkin => '簽到活動',
    backend.VeevaActivityType.external => '外部連結',
  };
}

IconData _activityTypeIcon(backend.VeevaActivityType type) {
  return switch (type) {
    backend.VeevaActivityType.survey => Icons.fact_check_outlined,
    backend.VeevaActivityType.registration => Icons.event_available_outlined,
    backend.VeevaActivityType.referral => Icons.group_add_outlined,
    backend.VeevaActivityType.task => Icons.task_alt_outlined,
    backend.VeevaActivityType.checkin => Icons.qr_code_scanner_outlined,
    backend.VeevaActivityType.external => Icons.open_in_new_outlined,
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
    return const Color(0xFFFFF2DF);
  }
  return switch (activity.status) {
    backend.VeevaContentStatus.draft => const Color(0xFFEFF3F6),
    backend.VeevaContentStatus.scheduled => const Color(0xFFEAF0FF),
    backend.VeevaContentStatus.published => const Color(0xFFFFF2DF),
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

List<String> _stringLines(String value) {
  return value
      .split(RegExp(r'\r?\n'))
      .map((line) => line.trim())
      .where((line) => line.isNotEmpty)
      .toList();
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

bool _isAllowedAdminImageContentType(String contentType) {
  return const {
    'image/png',
    'image/jpeg',
    'image/webp',
    'image/gif',
  }.contains(contentType.toLowerCase());
}

String? _adminImageValidationError(PickedAdminImage image) {
  if (!_isAllowedAdminImageContentType(image.contentType)) {
    return '請選擇 PNG、JPG、WebP 或 GIF 圖片。';
  }
  if (image.originalSizeBytes > adminImageSourceMaxBytes) {
    return '原圖過大，目前上限是 ${_formatBytes(adminImageSourceMaxBytes)}，'
        '你選擇的是 ${_formatBytes(image.originalSizeBytes)}。';
  }
  if (image.sizeBytes > adminImageUploadMaxBytes) {
    return '壓縮後圖片仍超過 ${_formatBytes(adminImageUploadMaxBytes)}，'
        '請換一張尺寸較小或內容較單純的圖片。';
  }
  final shareSizeBytes = image.shareBytes?.lengthInBytes ?? 0;
  if (shareSizeBytes > adminImageUploadMaxBytes) {
    return 'LINE 分享圖仍超過 ${_formatBytes(adminImageUploadMaxBytes)}，'
        '請換一張尺寸較小或內容較單純的圖片。';
  }
  return null;
}

String _imageStoragePath({
  required String folder,
  required String fileName,
  required String contentType,
}) {
  final cleanFolder = folder.replaceAll(RegExp(r'/+$'), '');
  final timestamp = DateTime.now().millisecondsSinceEpoch;
  return '$cleanFolder/$timestamp-${_safeStorageFileName(fileName, contentType)}';
}

String _safeStorageFileName(String fileName, String contentType) {
  final fallbackExtension = _imageExtensionForContentType(contentType);
  final baseName = fileName
      .split(RegExp(r'[/\\]'))
      .last
      .toLowerCase()
      .replaceAll(RegExp(r'\.(png|jpe?g|webp|gif)$'), '')
      .replaceAll(RegExp(r'[^a-z0-9._-]+'), '-')
      .replaceAll(RegExp(r'-+'), '-')
      .replaceAll(RegExp(r'^[-.]+|[-.]+$'), '');
  if (baseName.isEmpty) {
    return 'image$fallbackExtension';
  }
  return '$baseName$fallbackExtension';
}

String _imageExtensionForContentType(String contentType) {
  return switch (contentType.toLowerCase()) {
    'image/png' => '.png',
    'image/jpeg' => '.jpg',
    'image/webp' => '.webp',
    'image/gif' => '.gif',
    _ => '.jpg',
  };
}

String _formatBytes(int bytes) {
  if (bytes >= 1024 * 1024) {
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)}MB';
  }
  if (bytes >= 1024) {
    return '${(bytes / 1024).toStringAsFixed(0)}KB';
  }
  return '${bytes}B';
}

String _compressionSummary(PickedAdminImage image) {
  final sizeText =
      '${_formatBytes(image.originalSizeBytes)} → ${_formatBytes(image.sizeBytes)}';
  final dimensionText = image.width != null && image.height != null
      ? '，${image.width}×${image.height}px'
      : '';
  final qualityText =
      image.quality == null ? '' : '，品質 ${(image.quality! * 100).round()}%';
  return '已壓縮成 WebP：$sizeText$dimensionText$qualityText';
}

String _imageFileNameFromUrl(String value) {
  final uri = Uri.tryParse(value.trim());
  final rawFileName = uri?.pathSegments
      .where((segment) => segment.trim().isNotEmpty)
      .lastOrNull;
  final decodedPath = Uri.decodeComponent(rawFileName ?? '');
  final fileName = decodedPath
      .split(RegExp(r'[/\\]'))
      .where((segment) => segment.trim().isNotEmpty)
      .lastOrNull;
  if (fileName == null || fileName.isEmpty) {
    return '已上傳圖片';
  }
  return fileName;
}

String _imagePreviewUrl(String value) {
  final trimmed = value.trim();
  final uri = Uri.tryParse(trimmed);
  if (uri == null || (uri.scheme != 'http' && uri.scheme != 'https')) {
    return trimmed;
  }
  final query = Map<String, String>.from(uri.queryParameters);
  query['veevaPreview'] = 'storage-cors-v1';
  return uri.replace(queryParameters: query).toString();
}

class _NewsEditorDialog extends StatefulWidget {
  const _NewsEditorDialog({
    required this.newsItem,
    required this.newsId,
    required this.isEditing,
    required this.titleController,
    required this.summaryController,
    required this.contentController,
    required this.sourceController,
    required this.categoryController,
    required this.dateController,
    required this.imageController,
    required this.externalUrlController,
    required this.initialStatus,
    required this.coverImageStorageFolder,
    required this.articleImageStorageFolder,
    required this.onUploadImage,
  });

  final backend.VeevaNews? newsItem;
  final String newsId;
  final bool isEditing;
  final TextEditingController titleController;
  final TextEditingController summaryController;
  final TextEditingController contentController;
  final TextEditingController sourceController;
  final TextEditingController categoryController;
  final TextEditingController dateController;
  final TextEditingController imageController;
  final TextEditingController externalUrlController;
  final backend.VeevaContentStatus initialStatus;
  final String coverImageStorageFolder;
  final String articleImageStorageFolder;
  final _AdminImageUploader onUploadImage;

  @override
  State<_NewsEditorDialog> createState() => _NewsEditorDialogState();
}

class _NewsEditorDialogState extends State<_NewsEditorDialog> {
  final FocusNode _contentFocusNode = FocusNode();
  final ArticleRichEditorController _articleEditorController =
      ArticleRichEditorController();

  late backend.VeevaContentStatus _status;
  String? _formError;

  @override
  void initState() {
    super.initState();
    _status = widget.initialStatus;
  }

  @override
  void dispose() {
    _contentFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final horizontalInset = size.width < 720 ? 10.0 : 32.0;
    final verticalInset = size.height < 720 ? 10.0 : 24.0;
    final availableWidth = size.width - horizontalInset * 2;
    final availableHeight = size.height - verticalInset * 2;
    final dialogWidth =
        (availableWidth > 1180 ? 1180.0 : availableWidth.clamp(320.0, 1180.0))
            .toDouble();
    final dialogHeight =
        (availableHeight > 820 ? 820.0 : availableHeight.clamp(420.0, 820.0))
            .toDouble();

    return Dialog(
      insetPadding: EdgeInsets.symmetric(
        horizontal: horizontalInset,
        vertical: verticalInset,
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      clipBehavior: Clip.antiAlias,
      child: SizedBox(
        width: dialogWidth,
        height: dialogHeight,
        child: Column(
          children: [
            _buildHeader(context),
            _buildToolbar(context),
            Expanded(
              child: Container(
                color: const Color(0xFFF4F6F7),
                padding: const EdgeInsets.all(18),
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final isNarrow = constraints.maxWidth < 900;
                    if (isNarrow) {
                      return SingleChildScrollView(
                        child: Column(
                          children: [
                            _buildDocumentEditor(expandContent: false),
                            const SizedBox(height: 14),
                            _buildSettingPanel(),
                          ],
                        ),
                      );
                    }

                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Expanded(
                          child: _buildDocumentEditor(expandContent: true),
                        ),
                        const SizedBox(width: 16),
                        SizedBox(
                          width: 310,
                          child: _buildSettingPanel(),
                        ),
                      ],
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 14, 14, 14),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: Color(0xFFEADFCE))),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: const Color(0xFFFFF2DF),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(
              Icons.article_outlined,
              color: Color(0xFFC66D00),
              size: 21,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  widget.isEditing ? '編輯文章' : '新增文章',
                  style: const TextStyle(
                    color: Color(0xFF303236),
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 2),
                const Text(
                  '文章編輯器',
                  style: TextStyle(
                    color: Color(0xFF8A8D8F),
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('取消'),
          ),
          const SizedBox(width: 8),
          FilledButton.icon(
            onPressed: _submit,
            icon: Icon(widget.isEditing ? Icons.save_outlined : Icons.add),
            label: Text(widget.isEditing ? '儲存' : '建立'),
          ),
          const SizedBox(width: 4),
          IconButton(
            tooltip: '關閉',
            onPressed: () => Navigator.of(context).pop(),
            icon: const Icon(Icons.close),
          ),
        ],
      ),
    );
  }

  Widget _buildToolbar(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
      decoration: const BoxDecoration(
        color: Color(0xFFFFFAF3),
        border: Border(bottom: BorderSide(color: Color(0xFFEADFCE))),
      ),
      child: Wrap(
        spacing: 6,
        runSpacing: 6,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          _NewsEditorToolButton(
            tooltip: '粗體',
            onPressed: _articleEditorController.bold,
            child: const Text(
              'B',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w900,
                height: 1,
              ),
            ),
          ),
          _NewsEditorToolButton(
            tooltip: '斜體',
            icon: Icons.format_italic,
            onPressed: _articleEditorController.italic,
          ),
          _NewsEditorFontSizeButton(
            onSelected: _articleEditorController.fontSize,
          ),
          _NewsEditorToolButton(
            tooltip: '項目清單',
            icon: Icons.format_list_bulleted,
            onPressed: _articleEditorController.bulletedList,
          ),
          _NewsEditorToolButton(
            tooltip: '編號清單',
            icon: Icons.format_list_numbered,
            onPressed: _articleEditorController.numberedList,
          ),
          _NewsEditorToolButton(
            tooltip: '引用',
            icon: Icons.format_quote,
            onPressed: _articleEditorController.quote,
          ),
          _NewsEditorToolButton(
            tooltip: '插入連結',
            icon: Icons.link_outlined,
            onPressed: _articleEditorController.link,
          ),
          _NewsEditorToolButton(
            tooltip: '插入圖片',
            icon: Icons.image_outlined,
            onPressed: _articleEditorController.image,
          ),
          _NewsEditorToolButton(
            tooltip: '分隔線',
            icon: Icons.horizontal_rule,
            onPressed: _articleEditorController.divider,
          ),
        ],
      ),
    );
  }

  Widget _buildDocumentEditor({required bool expandContent}) {
    final contentField = RichArticleEditor(
      controller: widget.contentController,
      richController: _articleEditorController,
      focusNode: _contentFocusNode,
      onUploadImage: _pickAndUploadArticleImage,
      expands: expandContent,
      minHeight: 420,
    );

    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFEADFCE)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x12000000),
            offset: Offset(0, 12),
            blurRadius: 26,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            controller: widget.titleController,
            maxLines: 2,
            decoration: const InputDecoration(
              labelText: '文章標題',
              hintText: '輸入文章標題',
              border: UnderlineInputBorder(),
            ),
            style: const TextStyle(
              color: Color(0xFF303236),
              fontSize: 25,
              fontWeight: FontWeight.w900,
              height: 1.25,
            ),
          ),
          const SizedBox(height: 16),
          if (expandContent) Expanded(child: contentField) else contentField,
        ],
      ),
    );
  }

  Widget _buildSettingPanel() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFEADFCE)),
      ),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              '文章設定',
              style: TextStyle(
                color: Color(0xFF303236),
                fontSize: 16,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 12),
            if (_formError != null) ...[
              _InlineError(message: _formError!),
              const SizedBox(height: 12),
            ],
            TextField(
              controller: widget.summaryController,
              minLines: 2,
              maxLines: 4,
              decoration: const InputDecoration(
                labelText: '列表摘要',
                helperText: '可不填，系統會用文章前段自動產生。',
                alignLabelWithHint: true,
                prefixIcon: Icon(Icons.notes_outlined),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: widget.sourceController,
              decoration: const InputDecoration(
                labelText: '來源',
                prefixIcon: Icon(Icons.source_outlined),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: widget.categoryController,
              decoration: const InputDecoration(
                labelText: '分類',
                prefixIcon: Icon(Icons.category_outlined),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: widget.dateController,
              decoration: const InputDecoration(
                labelText: '發布日期',
                helperText: '例如 2026/06/11 或 2026/06',
                prefixIcon: Icon(Icons.event_outlined),
              ),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<backend.VeevaContentStatus>(
              value: _status,
              decoration: const InputDecoration(
                labelText: '發布狀態',
                prefixIcon: Icon(Icons.flag_outlined),
              ),
              items: [
                for (final item in backend.VeevaContentStatus.values)
                  DropdownMenuItem(
                    value: item,
                    child: Text(_contentStatusLabel(item)),
                  ),
              ],
              onChanged: (value) {
                if (value == null) {
                  return;
                }
                setState(() => _status = value);
              },
            ),
            const SizedBox(height: 12),
            _ImageUploadField(
              controller: widget.imageController,
              label: '封面圖片',
              helperText: '會顯示在前台最新資訊列表與文章頁。',
              storageFolder: widget.coverImageStorageFolder,
              onUpload: widget.onUploadImage,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: widget.externalUrlController,
              keyboardType: TextInputType.url,
              decoration: const InputDecoration(
                labelText: '外部連結',
                prefixIcon: Icon(Icons.link_outlined),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<String?> _pickAndUploadArticleImage() async {
    final image = await pickAdminImage();
    if (image == null) {
      return null;
    }
    if (!_isAllowedAdminImageContentType(image.contentType)) {
      setState(() => _formError = '請選擇 PNG、JPG、WebP 或 GIF 圖片。');
      return null;
    }
    if (image.originalSizeBytes > adminImageSourceMaxBytes) {
      setState(
        () =>
            _formError = '原圖過大，目前上限是 ${_formatBytes(adminImageSourceMaxBytes)}，'
                '你選擇的是 ${_formatBytes(image.originalSizeBytes)}。',
      );
      return null;
    }
    if (image.sizeBytes > adminImageUploadMaxBytes) {
      setState(
        () => _formError = '壓縮後圖片仍超過 ${_formatBytes(adminImageUploadMaxBytes)}，'
            '請換一張尺寸較小或內容較單純的圖片。',
      );
      return null;
    }

    setState(() => _formError = null);
    try {
      final url = await widget.onUploadImage(
        path: _imageStoragePath(
          folder: widget.articleImageStorageFolder,
          fileName: image.name,
          contentType: image.contentType,
        ),
        bytes: image.bytes,
        contentType: image.contentType,
      );
      if (url.trim().isEmpty) {
        throw StateError('empty download url');
      }
      if (mounted) {
        setState(() => _formError = null);
      }
      return url;
    } catch (_) {
      if (mounted) {
        setState(
          () =>
              _formError = '文章圖片上傳失敗，請確認 Firebase Storage bucket 已建立並部署 rules。',
        );
      }
      return null;
    }
  }

  void _submit() {
    final title = widget.titleController.text.trim();
    final content = widget.contentController.text.trim();
    final summary = _optionalText(widget.summaryController.text) ??
        _summaryFromContent(content);
    final date = widget.dateController.text.trim();
    final imageUrl = _optionalText(widget.imageController.text);
    final externalUrl = _optionalText(widget.externalUrlController.text);

    if (title.isEmpty) {
      setState(() => _formError = '請填寫文章標題。');
      return;
    }
    if (content.isEmpty) {
      setState(() => _formError = '請填寫文章內容。');
      return;
    }
    if (date.isEmpty) {
      setState(() => _formError = '請填寫發布日期。');
      return;
    }
    if (imageUrl != null && !_isHttpUrl(imageUrl)) {
      setState(() => _formError = '封面圖片網址需要是 http 或 https 開頭。');
      return;
    }
    if (externalUrl != null && !_isHttpUrl(externalUrl)) {
      setState(() => _formError = '外部連結需要是 http 或 https 開頭。');
      return;
    }

    final news = backend.VeevaNews(
      id: widget.newsId,
      date: date,
      source: _fallbackText(widget.sourceController.text, 'Veeva'),
      title: title,
      summary: summary,
      status: _status,
      category: _optionalText(widget.categoryController.text),
      imageUrl: imageUrl,
      content: content,
      detailContent: content,
      keyPoints: const [],
      externalUrl: externalUrl,
      helpfulCount: widget.newsItem?.helpfulCount ?? 0,
    );
    Navigator.of(context).pop(news);
  }

  String _summaryFromContent(String content) {
    final plainText = content
        .split(RegExp(r'\r?\n'))
        .map((line) {
          return line
              .replaceFirst(RegExp(r'^#{1,6}\s*'), '')
              .replaceFirst(RegExp(r'^[-*•]\s*'), '')
              .replaceFirst(RegExp(r'^\d+\.\s*'), '')
              .replaceFirst(RegExp(r'^>\s*'), '')
              .replaceAll(RegExp(r'!\[[^\]]*\]\([^)]+\)'), '')
              .replaceAllMapped(
                RegExp(r'\[([^\]]+)\]\([^)]+\)'),
                (match) => match.group(1) ?? '',
              )
              .replaceAll(RegExp(r'[*_`#>-]'), '')
              .trim();
        })
        .where((line) => line.isNotEmpty && line != '---')
        .join(' ');
    if (plainText.length <= 82) {
      return plainText;
    }
    return '${plainText.substring(0, 82)}...';
  }
}

class _NewsEditorToolButton extends StatelessWidget {
  const _NewsEditorToolButton({
    required this.tooltip,
    required this.onPressed,
    this.icon,
    this.child,
  });

  final String tooltip;
  final IconData? icon;
  final Widget? child;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 38,
      height: 38,
      child: IconButton(
        tooltip: tooltip,
        onPressed: onPressed,
        icon: child ?? Icon(icon!, size: 20),
        style: IconButton.styleFrom(
          foregroundColor: const Color(0xFF303236),
          backgroundColor: Colors.white,
          side: const BorderSide(color: Color(0xFFEADFCE)),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      ),
    );
  }
}

class _NewsEditorFontSizeButton extends StatelessWidget {
  const _NewsEditorFontSizeButton({required this.onSelected});

  final ValueChanged<int> onSelected;

  static const _sizes = [14, 16, 18, 20, 24, 28, 32];

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<int>(
      tooltip: '字體大小',
      onSelected: onSelected,
      itemBuilder: (context) => [
        for (final size in _sizes)
          PopupMenuItem<int>(
            value: size,
            child: Text('$size px'),
          ),
      ],
      child: Container(
        height: 38,
        padding: const EdgeInsets.symmetric(horizontal: 10),
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: const Color(0xFFEADFCE)),
          borderRadius: BorderRadius.circular(8),
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '字級',
              style: TextStyle(
                color: Color(0xFF303236),
                fontSize: 13,
                fontWeight: FontWeight.w900,
              ),
            ),
            SizedBox(width: 4),
            Icon(
              Icons.arrow_drop_down,
              color: Color(0xFF303236),
              size: 18,
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
                  _RewardDataTable(
                    rewards: visibleRewards,
                    onEdit: widget.onEdit,
                    onPreview: widget.onPreview,
                    onToggleStatus: widget.onToggleStatus,
                    onAdjustStock: widget.onAdjustStock,
                    onExpire: widget.onExpire,
                    onDelete: widget.onDelete,
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
          fillColor: const Color(0xFFFFFAF3),
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
        fillColor: const Color(0xFFFFFAF3),
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
    return _FullWidthDataTable(
      minWidth: 1120,
      child: DataTable(
        columnSpacing: 24,
        horizontalMargin: 16,
        headingRowColor: WidgetStateProperty.all(const Color(0xFFFFFAF3)),
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
      ),
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
        color: const Color(0xFFFFFAF3),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFEADFCE)),
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
        color: const Color(0xFFFFFAF3),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFEADFCE)),
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
        border: Border.all(color: const Color(0xFFEADFCE)),
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
      RewardStatus.active => const Color(0xFFFFF2DF),
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
            Icon(icon, size: 42, color: const Color(0xFFC66D00)),
            const SizedBox(height: 18),
            Text(
              title,
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 10),
            Text(
              description,
              style: const TextStyle(color: Color(0xFF8A8D8F)),
            ),
          ],
        ),
      ),
    );
  }
}
