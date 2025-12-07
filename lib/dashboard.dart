import 'package:flutter/material.dart';
import 'package:it12_project/expenses.dart';
import 'data/app_state.dart';
import 'data/dashboard_provider.dart'; // This imports your data class (Line 4)
import 'ui_app_shell.dart';
import 'theme/app_theme.dart';
import 'shared_header.dart';
import 'shared/widgets.dart' show AnimatedCard, isMobile;
// FIX 1: Import the generic provider package, NOT your local file
import 'package:provider/provider.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final DashboardProvider _dashboardProvider = DashboardProvider();
  bool _isLoading = true;
  String _searchQuery = '';
  String _dateRange = 'Today'; // Today, Weekly, Monthly, Yearly

  bool get _isServiceManager => AppState.currentRole == UserRole.serviceManager;

  @override
  void initState() {
    super.initState();
    _loadData();

    // Mark welcome as shown after the first build
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!AppState.hasShownWelcome) {
        AppState.hasShownWelcome = true;
      }
    });
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    await _dashboardProvider.fetchDashboardData(dateRange: _dateRange);
    if (mounted) setState(() => _isLoading = false);
  }

  Future<void> _refreshData() async {
    await _dashboardProvider.fetchDashboardData(dateRange: _dateRange);
    if (mounted) setState(() {});
  }

  List<TodayJobItem> get _filteredTodayJobs {
    if (_searchQuery.isEmpty) return _dashboardProvider.todayJobs;
    return _dashboardProvider.todayJobs.where((job) {
      return job.client.toLowerCase().contains(_searchQuery) ||
          job.type.toLowerCase().contains(_searchQuery) ||
          job.status.toLowerCase().contains(_searchQuery) ||
          job.id.toLowerCase().contains(_searchQuery);
    }).toList();
  }

  List<AttentionItem> get _filteredAttentionItems {
    if (_searchQuery.isEmpty) return _dashboardProvider.attentionItems;
    return _dashboardProvider.attentionItems.where((item) {
      return item.title.toLowerCase().contains(_searchQuery) ||
          item.reference.toLowerCase().contains(_searchQuery);
    }).toList();
  }

  void _showNotificationsPanel() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        builder: (context, scrollController) => Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: const BoxDecoration(
                  border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0))),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.notifications, color: Color(0xFF2563EB)),
                    const SizedBox(width: 12),
                    const Text(
                      'Notifications',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFEFF6FF),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        '${_dashboardProvider.attentionItems.length}',
                        style: const TextStyle(
                          color: Color(0xFF2563EB),
                          fontWeight: FontWeight.w600,
                          fontSize: 12,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close, size: 20),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: _dashboardProvider.attentionItems.isEmpty
                    ? const Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.notifications_off_outlined,
                              size: 64,
                              color: Colors.black26,
                            ),
                            SizedBox(height: 16),
                            Text(
                              'No notifications',
                              style: TextStyle(
                                fontSize: 16,
                                color: Colors.black54,
                              ),
                            ),
                            SizedBox(height: 8),
                            Text(
                              'You\'re all caught up!',
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.black38,
                              ),
                            ),
                          ],
                        ),
                      )
                    : ListView.separated(
                        controller: scrollController,
                        padding: const EdgeInsets.all(20),
                        itemCount: _dashboardProvider.attentionItems.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 12),
                        itemBuilder: (ctx, i) => _notificationItem(
                          _dashboardProvider.attentionItems[i],
                        ),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _notificationItem(AttentionItem item) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          Navigator.pop(context);
          switch (item.type) {
            case AttentionType.payment:
              Navigator.of(context).pushReplacementNamed('/payments');
              break;
            case AttentionType.expense:
              Navigator.of(context).pushReplacementNamed('/expenses');
              break;
            case AttentionType.scheduling:
              Navigator.of(context).pushReplacementNamed('/scheduling');
              break;
            case AttentionType.document:
              Navigator.of(context).pushReplacementNamed('/documents');
              break;
          }
        },
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: item.color.withOpacity(0.05),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: item.color.withOpacity(0.2)),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: item.color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  Icons.warning_amber_rounded,
                  color: item.color,
                  size: 24,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.title,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      item.reference,
                      style: const TextStyle(
                        fontSize: 12,
                        color: Colors.black54,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: item.color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  item.priority,
                  style: TextStyle(
                    fontSize: 10,
                    color: item.color,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              const Icon(Icons.chevron_right, size: 20, color: Colors.black26),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final titleFontSize = _isServiceManager ? 24.0 : 20.0;

    return AppShell(
      selectedIndex: 0,
      body: Column(
        children: [
          SharedHeader(
            welcomeText: AppState.hasShownWelcome
                ? ''
                : AppState.headerWelcomeText(),
            subtitleText: AppState.headerSubtitle(),
            notificationCount: _dashboardProvider.attentionItems.length,
            onSearchChanged: (value) {
              setState(() => _searchQuery = value.toLowerCase());
            },
            onNotificationTap: _showNotificationsPanel,
          ),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : SingleChildScrollView(
                    padding: EdgeInsets.fromLTRB(
                      _isServiceManager ? 24 : 20,
                      20,
                      _isServiceManager ? 24 : 20,
                      40,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Title Row
                        Row(
                          children: [
                            Text(
                              'Overview',
                              style: TextStyle(
                                fontSize: titleFontSize,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const Spacer(),
                            PopupMenuButton<String>(
                              initialValue: _dateRange,
                              onSelected: (value) {
                                setState(() => _dateRange = value);
                                _loadData();
                              },
                              offset: const Offset(0, 40),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                              itemBuilder: (context) => [
                                const PopupMenuItem(
                                  value: 'Today',
                                  child: Row(
                                    children: [
                                      Icon(Icons.today, size: 18),
                                      SizedBox(width: 12),
                                      Text('Today'),
                                    ],
                                  ),
                                ),
                                const PopupMenuItem(
                                  value: 'Weekly',
                                  child: Row(
                                    children: [
                                      Icon(Icons.date_range, size: 18),
                                      SizedBox(width: 12),
                                      Text('This Week'),
                                    ],
                                  ),
                                ),
                                const PopupMenuItem(
                                  value: 'Monthly',
                                  child: Row(
                                    children: [
                                      Icon(Icons.calendar_month, size: 18),
                                      SizedBox(width: 12),
                                      Text('This Month'),
                                    ],
                                  ),
                                ),
                                const PopupMenuItem(
                                  value: 'Yearly',
                                  child: Row(
                                    children: [
                                      Icon(Icons.calendar_today, size: 18),
                                      SizedBox(width: 12),
                                      Text('This Year'),
                                    ],
                                  ),
                                ),
                              ],
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 6,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: const Color(0xFFE2E8F0),
                                  ),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(
                                      Icons.calendar_today,
                                      size: 14,
                                      color: Colors.black54,
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      _dateRange,
                                      style: TextStyle(
                                        fontSize: _isServiceManager
                                            ? 14.0
                                            : 12.0,
                                        fontWeight: FontWeight.w600,
                                        color: Colors.black54,
                                      ),
                                    ),
                                    const SizedBox(width: 4),
                                    const Icon(
                                      Icons.arrow_drop_down,
                                      size: 18,
                                      color: Colors.black54,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 16),

                        // 1. ACTIONABLE STATS
                        _overviewCardsSection(),

                        const SizedBox(height: 24),

                        // 2. MAIN WORKSPACE
                        LayoutBuilder(
                          builder: (context, constraints) {
                            final isWideScreen = constraints.maxWidth >= 1024;

                            if (isWideScreen) {
                              // Desktop: Side-by-Side
                              return Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Expanded(
                                    flex: 2,
                                    child: AnimatedCard(
                                      delay: const Duration(milliseconds: 350),
                                      child: _todaysJobOrdersCard(),
                                    ),
                                  ),
                                  const SizedBox(width: 24),
                                  Expanded(
                                    flex: 1,
                                    child: AnimatedCard(
                                      delay: const Duration(milliseconds: 400),
                                      child: _attentionCard(),
                                    ),
                                  ),
                                ],
                              );
                            } else {
                              // Mobile: Stacked
                              return Column(
                                children: [
                                  AnimatedCard(
                                    delay: const Duration(milliseconds: 350),
                                    child: _todaysJobOrdersCard(),
                                  ),
                                  const SizedBox(height: 20),
                                  AnimatedCard(
                                    delay: const Duration(milliseconds: 400),
                                    child: _attentionCard(),
                                  ),
                                ],
                              );
                            }
                          },
                        ),
                      ],
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _overviewCardsSection() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isMobileView = isMobile(context);
        final fontSize = _isServiceManager ? 18.0 : 16.0;

        // Define Cards
        final pendingCard = _OverviewCard(
          title: 'Pending Jobs',
          value: _dashboardProvider.pendingJobsCount.toString(),
          icon: Icons.pending_actions,
          color: Colors.orange,
          fontSize: fontSize,
          onTap: () =>
              Navigator.of(context).pushReplacementNamed('/scheduling'),
        );

        final paymentsCard = _OverviewCard(
          title: 'Total Revenue',
          value: '₱${_dashboardProvider.totalRevenue.toStringAsFixed(0)}',
          icon: Icons.payments,
          color: Colors.green,
          fontSize: fontSize,
          // FIX: Updated navigation to expenses with filter
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) =>
                  const ExpensesScreen(initialFilter: 'Revenue / In'),
            ),
          ),
        );

        final expensesCard = _OverviewCard(
          title: 'Total Expenses',
          value: '₱${_dashboardProvider.totalExpenses.toStringAsFixed(0)}',
          icon: Icons.money_off,
          color: Colors.red,
          fontSize: fontSize,
          onTap: () => Navigator.of(context).pushReplacementNamed('/expenses'),
        );

        if (isMobileView) {
          return SizedBox(
            height: 170,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.only(bottom: 4),
              children: [
                SizedBox(
                  width: 160,
                  child: AnimatedCard(
                    delay: const Duration(milliseconds: 200),
                    child: pendingCard,
                  ),
                ),
                const SizedBox(width: 12),
                SizedBox(
                  width: 160,
                  child: AnimatedCard(
                    delay: const Duration(milliseconds: 250),
                    child: paymentsCard,
                  ),
                ),
                const SizedBox(width: 12),
                SizedBox(
                  width: 160,
                  child: AnimatedCard(
                    delay: const Duration(milliseconds: 300),
                    child: expensesCard,
                  ),
                ),
              ],
            ),
          );
        }

        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: AnimatedCard(
                delay: const Duration(milliseconds: 200),
                child: pendingCard,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: AnimatedCard(
                delay: const Duration(milliseconds: 250),
                child: paymentsCard,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: AnimatedCard(
                delay: const Duration(milliseconds: 300),
                child: expensesCard,
              ),
            ),
          ],
        );
      },
    );
  }

  BoxDecoration _whiteCardDeco() => AppTheme.cardDecoration;

  Widget _attentionCard() {
    return Container(
      decoration: _whiteCardDeco(),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text(
                'Attention Required',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
              ),
              const Spacer(),
              if (_filteredAttentionItems.isNotEmpty)
                Container(
                  width: 8,
                  height: 8,
                  decoration: const BoxDecoration(
                    color: Colors.red,
                    shape: BoxShape.circle,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 16),
          if (_filteredAttentionItems.isEmpty)
            const Padding(
              padding: EdgeInsets.all(20),
              child: Center(
                child: Text(
                  'All caught up!',
                  style: TextStyle(color: Colors.black54),
                ),
              ),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _filteredAttentionItems.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (ctx, i) =>
                  _attentionItemRow(_filteredAttentionItems[i]),
            ),
        ],
      ),
    );
  }

  Widget _attentionItemRow(AttentionItem item) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          switch (item.type) {
            case AttentionType.payment:
              Navigator.of(context).pushReplacementNamed('/payments');
              break;
            case AttentionType.expense:
              Navigator.of(context).pushReplacementNamed('/expenses');
              break;
            case AttentionType.scheduling:
              Navigator.of(context).pushReplacementNamed('/scheduling');
              break;
            case AttentionType.document:
              Navigator.of(context).pushReplacementNamed('/documents');
              break;
          }
        },
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: item.color.withOpacity(0.05),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: item.color.withOpacity(0.2)),
          ),
          child: Row(
            children: [
              Icon(Icons.warning_amber_rounded, color: item.color, size: 20),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.title,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                    ),
                    Text(
                      item.reference,
                      style: const TextStyle(
                        fontSize: 11,
                        color: Colors.black54,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, size: 16, color: Colors.black45),
            ],
          ),
        ),
      ),
    );
  }

  Widget _todaysJobOrdersCard() {
    return Container(
      decoration: _whiteCardDeco(),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // FIX 2: Corrected 'const' usage here. The Row is NOT const.
          Row(
            children: [
              Text(
                context.watch<DashboardProvider>().scheduleTitle,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFEAF2FF),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  '${_filteredTodayJobs.length} Active',
                  style: const TextStyle(
                    color: Color(0xFF2563EB),
                    fontWeight: FontWeight.w600,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          if (_filteredTodayJobs.isEmpty)
            Padding(
              padding: const EdgeInsets.all(24),
              child: Center(
                child: Text(
                  _searchQuery.isNotEmpty
                      ? 'No jobs match your search'
                      : 'No jobs scheduled for today',
                  style: const TextStyle(color: Colors.black54),
                ),
              ),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _filteredTodayJobs.length,
              separatorBuilder: (_, __) => const Divider(height: 24),
              itemBuilder: (_, i) => _jobOrderRow(_filteredTodayJobs[i]),
            ),
        ],
      ),
    );
  }

  Widget _jobOrderRow(TodayJobItem job) {
    Color statusColor;
    switch (job.status.toLowerCase()) {
      case 'in progress':
        statusColor = Colors.blue;
        break;
      case 'completed':
        statusColor = Colors.green;
        break;
      default:
        statusColor = Colors.orange;
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 65,
          child: Text(
            job.time,
            style: const TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 13,
              color: Colors.black87,
            ),
          ),
        ),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                job.client,
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                job.type,
                style: const TextStyle(fontSize: 12, color: Colors.black54),
              ),
            ],
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: statusColor.withOpacity(0.1),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Text(
            job.status,
            style: TextStyle(
              fontSize: 10,
              color: statusColor,
              fontWeight: FontWeight.w700,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}

class _OverviewCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color color;
  final double fontSize;
  final VoidCallback onTap;

  const _OverviewCard({
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
    required this.fontSize,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: AppTheme.borderRadius,
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: AppTheme.cardDecoration,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: color.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(icon, color: color, size: 24),
                  ),
                  Icon(
                    Icons.chevron_right,
                    color: AppTheme.textSecondary.withOpacity(0.5),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              Flexible(
                child: Text(
                  value,
                  style: AppTheme.heading1.copyWith(fontSize: 28),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                title,
                style: AppTheme.caption.copyWith(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
