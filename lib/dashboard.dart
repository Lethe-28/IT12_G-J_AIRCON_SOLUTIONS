import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'data/app_state.dart';
import 'data/dashboard_provider.dart';
import 'ui_app_shell.dart';
import 'theme/app_theme.dart';
import 'shared_header.dart';
import 'shared/widgets.dart' show AnimatedCard, isMobile;
import 'scheduling.dart';
import 'data/activity_history.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  // --- CHANGED: Static flag ensures this persists across navigation ---
  // This stays true until the app is completely restarted.
  static bool hasShownSessionNotifications = false;

  // --- ADD THIS METHOD ---
  static void resetSession() {
    hasShownSessionNotifications = false;
  }

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final DashboardProvider _dashboardProvider = DashboardProvider();
  bool _isLoading = true;
  String _searchQuery = '';
  String _dateRange = 'All';
  RealtimeChannel? _subscription;

  bool get _isServiceManager => AppState.currentRole == UserRole.serviceManager;

  @override
  void initState() {
    super.initState();
    _loadData();
    _setupRealtimeSubscription();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!AppState.hasShownWelcome) {
        AppState.hasShownWelcome = true;
      }
    });
  }

  @override
  void dispose() {
    _subscription?.unsubscribe();
    super.dispose();
  }

  void _setupRealtimeSubscription() {
    final supabase = Supabase.instance.client;
    _subscription = supabase
        .channel('dashboard_updates')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'job_orders',
          callback: (payload) => _loadData(),
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'expenses',
          callback: (payload) => _loadData(),
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'payments',
          callback: (payload) => _loadData(),
        )
        .subscribe();
  }

  Future<void> _loadData() async {
    // Only show loader on first load
    if (_dashboardProvider.todayJobs.isEmpty && _isLoading) {
      // keep isLoading true
    }

    await _dashboardProvider.fetchDashboardData(dateRange: _dateRange);

    if (mounted) {
      setState(() => _isLoading = false);

      // --- UPDATED LOGIC: USE STATIC FLAG ---
      // We check DashboardScreen.hasShownSessionNotifications instead of a local variable.
      if (!DashboardScreen.hasShownSessionNotifications &&
          _dashboardProvider.notificationItems.isNotEmpty) {
        // Mark it as shown immediately so it doesn't trigger again
        DashboardScreen.hasShownSessionNotifications = true;

        // Slight delay for smooth UI entrance
        Future.delayed(const Duration(milliseconds: 800), () {
          if (mounted) {
            _showNotificationsPanel();

            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('You have pending items that require attention.'),
                behavior: SnackBarBehavior.floating,
                duration: Duration(seconds: 3),
                backgroundColor: Colors.blue,
              ),
            );
          }
        });
      }
    }
  }

  // ... (Rest of the file remains exactly the same as previous version) ...

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
                        '${_dashboardProvider.notificationItems.length}',
                        style: const TextStyle(
                          color: Color(0xFF2563EB),
                          fontWeight: FontWeight.w600,
                          fontSize: 12,
                        ),
                      ),
                    ),
                    if (_dashboardProvider.notificationItems.isNotEmpty) ...[
                      const SizedBox(width: 8),
                      TextButton.icon(
                        onPressed: () {
                          setState(() {
                            _dashboardProvider.clearAllNotifications();
                          });
                        },
                        icon: const Icon(Icons.clear_all, size: 16),
                        label: const Text(
                          'Clear All',
                          style: TextStyle(fontSize: 12),
                        ),
                        style: TextButton.styleFrom(
                          foregroundColor: Colors.red,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                        ),
                      ),
                    ],
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
                child: _dashboardProvider.notificationItems.isEmpty
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
                        itemCount: _dashboardProvider.notificationItems.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 12),
                        itemBuilder: (ctx, i) => _notificationItem(
                          _dashboardProvider.notificationItems[i],
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
    return Dismissible(
      key: Key('notification_${item.reference}_${item.relatedId}'),
      direction: DismissDirection.endToStart,
      background: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.only(right: 20),
        alignment: Alignment.centerRight,
        decoration: BoxDecoration(
          color: Colors.red,
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Icon(Icons.delete_outline, color: Colors.white, size: 24),
      ),
      onDismissed: (direction) {
        setState(() {
          _dashboardProvider.clearNotification(item);
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Notification cleared'),
            duration: const Duration(seconds: 2),
            behavior: SnackBarBehavior.floating,
          ),
        );
      },
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            Navigator.pop(context);

            switch (item.type) {
              case AttentionType.payment:
                Navigator.of(context).pushReplacementNamed('/expenses');
                break;
              case AttentionType.expense:
                Navigator.of(context).pushReplacementNamed('/expenses');
                break;
              case AttentionType.scheduling:
                final searchText =
                    item.searchContext ?? item.relatedId.toString();
                if (item.relatedId != null) {
                  Navigator.of(context).pushReplacement(
                    MaterialPageRoute(
                      builder: (context) =>
                          SchedulingScreen(initialSearch: searchText),
                    ),
                  );
                } else {
                  Navigator.of(context).pushReplacementNamed('/scheduling');
                }
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
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: item.color.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    item.priority == 'Info'
                        ? Icons.info_outline_rounded
                        : Icons.warning_amber_rounded,
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
                          color: Colors.black87,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      if (item.customerName != null) ...[
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            const Icon(
                              Icons.person_outline,
                              size: 14,
                              color: Colors.black54,
                            ),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                item.customerName!,
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: Colors.black54,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ],
                      if (item.serviceType != null) ...[
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            const Icon(
                              Icons.build_outlined,
                              size: 14,
                              color: Colors.black54,
                            ),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                item.serviceType!,
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: Colors.black54,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ],
                      if (item.date != null) ...[
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            const Icon(
                              Icons.calendar_today_outlined,
                              size: 14,
                              color: Colors.black54,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              item.date!,
                              style: const TextStyle(
                                fontSize: 11,
                                color: Colors.black54,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
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
                    const SizedBox(height: 4),
                    Icon(Icons.chevron_right, size: 20, color: Colors.black26),
                  ],
                ),
              ],
            ),
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
            customTitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Here's what's happening",
                  style: TextStyle(
                    fontSize: titleFontSize * 0.65,
                    color: Colors.black45,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.8,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  "In your business today",
                  style: TextStyle(
                    fontSize: titleFontSize * 1.1,
                    fontWeight: FontWeight.w800,
                    color: const Color(0xFF0F172A),
                  ),
                ),
              ],
            ),
            notificationCount: _dashboardProvider.notificationItems.length,
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
                        // Title Row with WORKING Filter
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Overview',
                              style: TextStyle(
                                fontSize: titleFontSize,
                                fontWeight: FontWeight.w700,
                              ),
                            ),

                            // --- DYNAMIC DATE FILTER ---
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: const Color(0xFFE2E8F0),
                                ),
                              ),
                              child: DropdownButtonHideUnderline(
                                child: DropdownButton<String>(
                                  value: _dateRange,
                                  icon: const Icon(
                                    Icons.keyboard_arrow_down,
                                    size: 16,
                                    color: Colors.black54,
                                  ),
                                  style: TextStyle(
                                    fontSize: titleFontSize * 0.7,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.black54,
                                    fontFamily: 'Inter', // Or your app font
                                  ),
                                  items:
                                      [
                                        'Today',
                                        'Weekly',
                                        'Monthly',
                                        'Yearly',
                                        'All',
                                      ].map((String value) {
                                        return DropdownMenuItem<String>(
                                          value: value,
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Icon(
                                                // Dynamic Icon based on selection
                                                value == 'Today'
                                                    ? Icons.today
                                                    : value == 'Weekly'
                                                    ? Icons.date_range
                                                    : Icons.calendar_month,
                                                size: 14,
                                                color: Colors.black54,
                                              ),
                                              const SizedBox(width: 8),
                                              Text(value),
                                            ],
                                          ),
                                        );
                                      }).toList(),
                                  onChanged: (newValue) {
                                    if (newValue != null) {
                                      setState(() {
                                        _dateRange = newValue;
                                        _isLoading =
                                            true; // Show loading indicator
                                      });
                                      _loadData(); // Re-fetch everything
                                    }
                                  },
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

  // ... (The rest of your widgets: _overviewCardsSection, _todaysJobOrdersCard, etc. copy them from previous file or keep as is) ...

  Widget _overviewCardsSection() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isMobileView = isMobile(context);
        final fontSize = _isServiceManager ? 18.0 : 16.0;

        final pendingCard = _OverviewCard(
          title: 'Pending Jobs',
          value: _dashboardProvider.pendingJobsCount.toString(),
          icon: Icons.pending_actions,
          color: Colors.orange,
          fontSize: fontSize,
          onTap: () => Navigator.of(context).pushReplacement(
            MaterialPageRoute(
              builder: (context) =>
                  const SchedulingScreen(showPendingActions: true),
            ),
          ),
        );

        final paymentsCard = _OverviewCard(
          title: 'Revenue',
          value: '₱${_dashboardProvider.totalRevenue.toStringAsFixed(0)}',
          icon: Icons.payments,
          color: Colors.green,
          fontSize: fontSize,
          onTap: () => Navigator.of(context).pushReplacementNamed('/expenses'),
        );

        final expensesCard = _OverviewCard(
          title: 'Expenses',
          value: '₱${_dashboardProvider.totalExpenses.toStringAsFixed(0)}',
          icon: Icons.money_off,
          color: Colors.red,
          fontSize: fontSize,
          onTap: () => Navigator.of(context).pushReplacementNamed('/expenses'),
        );

        if (isMobileView) {
          return Column(
            children: [
              AnimatedCard(
                delay: const Duration(milliseconds: 200),
                child: _OverviewBarCard(
                  title: 'Pending Jobs',
                  value: _dashboardProvider.pendingJobsCount.toString(),
                  icon: Icons.pending_actions,
                  color: Colors.orange,
                  onTap: () => Navigator.of(context).pushReplacement(
                    MaterialPageRoute(
                      builder: (context) =>
                          const SchedulingScreen(showPendingActions: true),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              AnimatedCard(
                delay: const Duration(milliseconds: 250),
                child: _OverviewBarCard(
                  title: 'Revenue',
                  value:
                      '₱${_dashboardProvider.totalRevenue.toStringAsFixed(0)}',
                  icon: Icons.payments,
                  color: Colors.green,
                  onTap: () =>
                      Navigator.of(context).pushReplacementNamed('/expenses'),
                ),
              ),
              const SizedBox(height: 12),
              AnimatedCard(
                delay: const Duration(milliseconds: 300),
                child: _OverviewBarCard(
                  title: 'Expenses',
                  value:
                      '₱${_dashboardProvider.totalExpenses.toStringAsFixed(0)}',
                  icon: Icons.money_off,
                  color: Colors.red,
                  onTap: () =>
                      Navigator.of(context).pushReplacementNamed('/expenses'),
                ),
              ),
            ],
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
          // --- UPDATED HEADER ROW ---
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Recent Activity',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
              ),
              // Replaced Icon with Text Button
              TextButton(
                onPressed: () {
                  Navigator.of(context).pushReplacement(
                    MaterialPageRoute(
                      builder: (_) => const ActivityHistoryScreen(),
                    ),
                  );
                },
                style: TextButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                  padding: EdgeInsets.zero,
                ),
                child: const Text("View All", style: TextStyle(fontSize: 13)),
              ),
            ],
          ),
          // --------------------------
          const SizedBox(height: 16),
          if (_dashboardProvider.activityItems.isEmpty)
            const Padding(
              padding: EdgeInsets.all(20),
              child: Center(
                child: Text(
                  'No recent activity',
                  style: TextStyle(color: Colors.black54),
                ),
              ),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _dashboardProvider.activityItems.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (ctx, i) =>
                  _activityItemRow(_dashboardProvider.activityItems[i]),
            ),
        ],
      ),
    );
  }

  Widget _activityItemRow(AttentionItem item) {
    IconData icon;
    Color iconColor;
    Color bgColor;

    if (item.priority == 'High') {
      icon = Icons.warning_amber_rounded;
      iconColor = Colors.red;
      bgColor = Colors.red.withOpacity(0.05);
    } else {
      switch (item.type) {
        case AttentionType.payment:
          icon = Icons.payments_outlined;
          iconColor = Colors.green;
          bgColor = Colors.green.withOpacity(0.05);
          break;
        case AttentionType.expense:
          icon = Icons.receipt_long;
          iconColor = Colors.orange;
          bgColor = Colors.orange.withOpacity(0.05);
          break;
        case AttentionType.scheduling:
          icon = Icons.calendar_today;
          iconColor = Colors.blue;
          bgColor = Colors.blue.withOpacity(0.05);
          break;
        default:
          icon = Icons.info_outline;
          iconColor = Colors.grey;
          bgColor = Colors.grey.withOpacity(0.05);
      }
    }

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          switch (item.type) {
            case AttentionType.payment:
              Navigator.of(context).pushReplacementNamed('/expenses');
              break;
            case AttentionType.expense:
              Navigator.of(context).pushReplacementNamed('/expenses');
              break;
            case AttentionType.scheduling:
              Navigator.of(context).pushReplacementNamed('/scheduling');
              break;
            case AttentionType.document:
              Navigator.of(context).pushReplacementNamed('/scheduling');
              break;
          }
        },
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey.shade200),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: bgColor,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: iconColor, size: 20),
              ),
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
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      item.reference,
                      style: const TextStyle(
                        fontSize: 11,
                        color: Colors.black54,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, size: 16, color: Colors.black26),
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
          Row(
            children: [
              const Text(
                "Schedule",
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
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

    // WRAP IN MATERIAL + INKWELL FOR CLICKABILITY
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          // NAVIGATE TO SCHEDULING & SEARCH FOR THIS JOB ID
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(
              builder: (context) => SchedulingScreen(initialSearch: job.id),
            ),
          );
        },
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            vertical: 8,
            horizontal: 4,
          ), // Added padding for touch target
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 1. Time Column
              SizedBox(
                width: 70,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      job.date,
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      job.time,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                        color: Colors.black87,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),

              // 2. Client & Type
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      job.client,
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                        color: Colors
                            .blueAccent, // Made blue to indicate it's clickable
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      "${job.id} • ${job.type}", // Added ID here for clarity
                      style: const TextStyle(
                        fontSize: 12,
                        color: Colors.black54,
                      ),
                    ),
                  ],
                ),
              ),

              // 3. Status Badge
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

              // 4. Arrow Hint
              const SizedBox(width: 8),
              Icon(
                Icons.chevron_right,
                size: 16,
                color: Colors.grey.withOpacity(0.5),
              ),
            ],
          ),
        ),
      ),
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
                  style: AppTheme.heading1.copyWith(fontSize: fontSize),
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

class _OverviewBarCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _OverviewBarCard({
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
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
          padding: const EdgeInsets.all(16),
          decoration: AppTheme.cardDecoration,
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: color, size: 28),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      value,
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Colors.black54,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right,
                color: AppTheme.textSecondary.withOpacity(0.5),
                size: 20,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
