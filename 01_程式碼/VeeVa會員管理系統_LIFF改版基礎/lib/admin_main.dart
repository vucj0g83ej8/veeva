import 'package:flutter/material.dart';

void main() {
  runApp(const VeevaAdminApp());
}

class VeevaAdminApp extends StatelessWidget {
  const VeevaAdminApp({super.key});

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
      home: AdminDashboardShell(initialTab: _initialAdminTabFromUri()),
    );
  }

  AdminTab _initialAdminTabFromUri() {
    return switch (Uri.base.queryParameters['adminTab']) {
      'members' || 'pending' || 'approved' => AdminTab.members,
      'activities' => AdminTab.activities,
      'news' => AdminTab.news,
      'rewards' => AdminTab.rewards,
      'settings' => AdminTab.settings,
      _ => AdminTab.dashboard,
    };
  }
}

enum AdminTab { dashboard, members, activities, news, rewards, settings }

enum ReviewStatus { pending, approved, rejected }

enum RewardStatus { active, paused, expired }

class AdminReviewItem {
  AdminReviewItem({
    required this.name,
    required this.hospital,
    required this.department,
    required this.completedAt,
    required this.status,
  });

  final String name;
  final String hospital;
  final String department;
  final String completedAt;
  ReviewStatus status;
}

class AdminRewardItem {
  AdminRewardItem({
    required this.name,
    required this.category,
    required this.stock,
    required this.issued,
    required this.redeemed,
    required this.expiresAt,
    required this.status,
  });

  final String name;
  final String category;
  int stock;
  int issued;
  int redeemed;
  final String expiresAt;
  RewardStatus status;
}

class AdminDashboardShell extends StatefulWidget {
  const AdminDashboardShell({
    super.key,
    this.initialTab = AdminTab.dashboard,
  });

  final AdminTab initialTab;

  @override
  State<AdminDashboardShell> createState() => _AdminDashboardShellState();
}

class _AdminDashboardShellState extends State<AdminDashboardShell> {
  late AdminTab tab = widget.initialTab;
  final reviews = <AdminReviewItem>[
    AdminReviewItem(
      name: '張雅雯',
      hospital: '北醫附醫',
      department: '胸腔內科',
      completedAt: '2026/05/08 09:12',
      status: ReviewStatus.pending,
    ),
    AdminReviewItem(
      name: '吳志誠',
      hospital: '高醫',
      department: '腎臟科',
      completedAt: '2026/05/08 10:04',
      status: ReviewStatus.pending,
    ),
    AdminReviewItem(
      name: '李佩珊',
      hospital: '亞東醫院',
      department: '小兒科',
      completedAt: '2026/05/08 11:27',
      status: ReviewStatus.pending,
    ),
    AdminReviewItem(
      name: '王小明',
      hospital: '台大醫院',
      department: '心臟內科',
      completedAt: '2026/05/07 15:42',
      status: ReviewStatus.approved,
    ),
    AdminReviewItem(
      name: '陳怡君',
      hospital: '榮總',
      department: '家醫科',
      completedAt: '2026/05/07 17:21',
      status: ReviewStatus.approved,
    ),
  ];
  final rewards = <AdminRewardItem>[
    AdminRewardItem(
      name: '星巴克中杯美式',
      category: '飲品',
      stock: 120,
      issued: 58,
      redeemed: 36,
      expiresAt: '2026/06/30',
      status: RewardStatus.active,
    ),
    AdminRewardItem(
      name: '便利商店 100 元購物金',
      category: '禮券',
      stock: 80,
      issued: 42,
      redeemed: 21,
      expiresAt: '2026/07/15',
      status: RewardStatus.active,
    ),
    AdminRewardItem(
      name: '健康講座報名折扣',
      category: '活動',
      stock: 45,
      issued: 18,
      redeemed: 8,
      expiresAt: '2026/08/01',
      status: RewardStatus.paused,
    ),
    AdminRewardItem(
      name: '品牌保溫杯',
      category: '實體贈品',
      stock: 0,
      issued: 30,
      redeemed: 30,
      expiresAt: '2026/05/31',
      status: RewardStatus.paused,
    ),
    AdminRewardItem(
      name: '咖啡券舊活動批次',
      category: '飲品',
      stock: 12,
      issued: 210,
      redeemed: 188,
      expiresAt: '2026/04/30',
      status: RewardStatus.expired,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final isCompact = MediaQuery.sizeOf(context).width < 900;
    final content = Column(
      children: [
        if (!isCompact) _AdminTopBar(title: _titleFor(tab)),
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
          title: Text(_titleFor(tab)),
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
      AdminTab.settings => '系統設定',
    };
  }

  Widget _buildContent() {
    return switch (tab) {
      AdminTab.dashboard => _DashboardContent(reviews: reviews),
      AdminTab.members => _MemberManagement(
          reviews: reviews,
          onApprove: (item) =>
              setState(() => item.status = ReviewStatus.approved),
        ),
      AdminTab.activities => const _ActivityManagement(),
      AdminTab.news => const _NewsManagement(),
      AdminTab.rewards => _RewardsManagement(
          rewards: rewards,
          onCreate: _showCreateRewardDialog,
          onToggleStatus: (reward) {
            setState(() {
              reward.status = reward.status == RewardStatus.active
                  ? RewardStatus.paused
                  : RewardStatus.active;
            });
          },
          onAddStock: (reward) => setState(() => reward.stock += 20),
        ),
      AdminTab.settings => const _PlaceholderPanel(
          icon: Icons.settings_outlined,
          title: '系統設定',
          description: '設定活動期間、獎勵規則、通知模板與管理員權限。',
        ),
    };
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
              onPressed: () {
                final stock = int.tryParse(stockController.text.trim()) ?? 0;
                final name = nameController.text.trim();
                if (name.isEmpty || stock <= 0) return;

                setState(() {
                  rewards.insert(
                    0,
                    AdminRewardItem(
                      name: name,
                      category: categoryController.text.trim().isEmpty
                          ? '其他'
                          : categoryController.text.trim(),
                      stock: stock,
                      issued: 0,
                      redeemed: 0,
                      expiresAt: expiryController.text.trim().isEmpty
                          ? '未設定'
                          : expiryController.text.trim(),
                      status: RewardStatus.active,
                    ),
                  );
                });
                Navigator.of(dialogContext).pop();
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

class _AdminTopBar extends StatelessWidget {
  const _AdminTopBar({required this.title});

  final String title;

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
          Text(
            title,
            style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900),
          ),
          const Spacer(),
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
    this.onApprove,
  });

  final List<AdminReviewItem> rows;
  final ValueChanged<AdminReviewItem>? onApprove;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final isCompact = MediaQuery.sizeOf(context).width < 700;

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
      label: Text(approved ? '已通過' : '待審核'),
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
    required this.reviews,
    required this.onApprove,
  });

  final List<AdminReviewItem> reviews;
  final ValueChanged<AdminReviewItem> onApprove;

  @override
  State<_MemberManagement> createState() => _MemberManagementState();
}

class _MemberManagementState extends State<_MemberManagement> {
  ReviewStatus selectedStatus = ReviewStatus.pending;

  @override
  Widget build(BuildContext context) {
    final pending = widget.reviews
        .where((item) => item.status == ReviewStatus.pending)
        .length;
    final approved = widget.reviews
        .where((item) => item.status == ReviewStatus.approved)
        .length;
    final rows =
        widget.reviews.where((item) => item.status == selectedStatus).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: _MetricCard(
                label: '待審核會員',
                value: '$pending',
                icon: Icons.pending_actions_outlined,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _MetricCard(
                label: '已審核會員',
                value: '$approved',
                icon: Icons.verified_user_outlined,
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
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        selectedStatus == ReviewStatus.pending
                            ? '待審核名單'
                            : '已審核名單',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                    Text(
                      '共 ${rows.length} 筆',
                      style: const TextStyle(color: Color(0xFF6B7671)),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                _MemberStatusTabs(
                  selectedStatus: selectedStatus,
                  pendingCount: pending,
                  approvedCount: approved,
                  onChanged: (status) =>
                      setState(() => selectedStatus = status),
                ),
                const SizedBox(height: 16),
                _ReviewListBody(
                  rows: rows,
                  compact: false,
                  onApprove: selectedStatus == ReviewStatus.pending
                      ? widget.onApprove
                      : null,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _MemberStatusTabs extends StatelessWidget {
  const _MemberStatusTabs({
    required this.selectedStatus,
    required this.pendingCount,
    required this.approvedCount,
    required this.onChanged,
  });

  final ReviewStatus selectedStatus;
  final int pendingCount;
  final int approvedCount;
  final ValueChanged<ReviewStatus> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: Color(0xFFE4E8EA))),
      ),
      child: Row(
        children: [
          _MemberStatusTab(
            label: '待審核',
            count: pendingCount,
            selected: selectedStatus == ReviewStatus.pending,
            onTap: () => onChanged(ReviewStatus.pending),
          ),
          _MemberStatusTab(
            label: '已審核',
            count: approvedCount,
            selected: selectedStatus == ReviewStatus.approved,
            onTap: () => onChanged(ReviewStatus.approved),
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
  const _ActivityManagement();

  @override
  Widget build(BuildContext context) {
    const activities = [
      ('填問卷，拿咖啡券', '進行中', '2026/05/01 - 2026/06/30', '完成問卷後發放兌換券'),
      ('研討會報名提醒', '排程中', '2026/06/15 - 2026/07/15', '醫學會活動報名通知'),
      ('院所限定任務', '草稿', '未設定', '指定院所會員任務'),
    ];

    return _ManagementTable(
      icon: Icons.campaign_outlined,
      title: '活動管理',
      actionLabel: '新增活動',
      columns: const ['活動名稱', '狀態', '活動期間', '備註'],
      rows: [
        for (final activity in activities)
          [activity.$1, activity.$2, activity.$3, activity.$4],
      ],
    );
  }
}

class _NewsManagement extends StatelessWidget {
  const _NewsManagement();

  @override
  Widget build(BuildContext context) {
    const news = [
      ('WHO 發布醫療產品警示', '已發布', '2026/05/08', '國際醫療安全'),
      ('FDA 推動即時臨床試驗追蹤試點', '已發布', '2026/05/06', '臨床研究'),
      ('FDA 核准遺傳性聽損基因治療', '草稿', '2026/05/02', '新藥與治療'),
      ('美國急性呼吸道疾病就醫活動維持低水準', '已發布', '2026/04/30', '公共衛生'),
    ];

    return _ManagementTable(
      icon: Icons.newspaper_outlined,
      title: '最新資訊管理',
      actionLabel: '新增資訊',
      columns: const ['標題', '狀態', '發布日期', '分類'],
      rows: [
        for (final item in news) [item.$1, item.$2, item.$3, item.$4],
      ],
    );
  }
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
