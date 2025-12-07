import 'package:flutter/material.dart';
import 'data/app_state.dart';
import 'data/dashboard_provider.dart';
import 'ui_app_shell.dart';
import 'theme/app_theme.dart';
import 'shared_header.dart';
import 'shared/widgets.dart' show AnimatedCard, isMobile;
import 'scheduling.dart';

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
        // We don't need to setState here because the next rebuild (e.g. from navigation) will pick it up,
        // or if we want it to change immediately we could, but usually "pop up" implies initial state.
        // If the user wants it to disappear *while* looking at it, we'd need a timer or interaction.
        // For now, "everytime the user login" implies session start.
        // So next time they come to dashboard in this session, it will say "Dashboard".
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
                        '${_dashboardProvider.notificationItems.length}',
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
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          Navigator.pop(context); // Close the notification panel

          switch (item.type) {
            case AttentionType.payment:
              Navigator.of(context).pushReplacementNamed('/payments');
              break;
            case AttentionType.expense:
              Navigator.of(context).pushReplacementNamed('/expenses');
              break;
            case AttentionType.scheduling:
              final searchText =
                  item.searchContext ?? item.relatedId.toString();
              // NEW LOGIC: Pass the Job ID to the Scheduling Screen
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
              Icon(Icons.chevron_right, size: 20, color: Colors.black26),
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
                    // FIX: Add bottom padding so content isn't cut off
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

                        // 1. ACTIONABLE STATS (Robust Layout)
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

  // FIX: New robust layout engine for stats
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

        // MOBILE: Horizontal Scroll (Carousel)
        // This prevents overflow by giving cards infinite horizontal space
        if (isMobileView) {
          return SizedBox(
            height: 170, // Increased height to prevent overflow
            // We use a negative margin on the parent to allow cards to touch the screen edge
            // while keeping the main padding for the rest of the content.
            child: ListView(
              scrollDirection: Axis.horizontal,
              // Add padding inside the list view so the first card aligns with text
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

        // DESKTOP: Standard Row
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
          const Row(
            children: [
              Text(
                'Recent Activity',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
              ),
              Spacer(),
              Icon(Icons.history, color: Colors.grey, size: 20),
            ],
          ),
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
              // 1. Correct Count
              itemCount: _dashboardProvider.activityItems.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (ctx, i) => _activityItemRow(
                // 2. FIX IS HERE: Use activityItems instead of _filteredAttentionItems
                _dashboardProvider.activityItems[i],
              ),
            ),
        ],
      ),
    );
  }

  Widget _activityItemRow(AttentionItem item) {
    // 1. DETERMINE ICON & COLOR
    IconData icon;
    Color iconColor;
    Color bgColor;

    // Logic: Different icons for Payments, Jobs, and Warnings
    if (item.priority == 'High') {
      // Keep Warnings Red
      icon = Icons.warning_amber_rounded;
      iconColor = Colors.red;
      bgColor = Colors.red.withOpacity(0.05);
    } else {
      // Custom Icons for Normal Activity
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
          icon = Icons.calendar_today; // or Icons.assignment
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
          // Keep existing navigation logic
          switch (item.type) {
            case AttentionType.payment:
              Navigator.of(context).pushReplacementNamed('/payments');
              break;
            case AttentionType.expense:
              Navigator.of(context).pushReplacementNamed('/expenses');
              break;
            case AttentionType.scheduling:
              // Use the new navigation we added earlier
              if (item.relatedId != null) {
                // Assuming you imported scheduling.dart
                // If not, standard pushReplacementNamed works too
                Navigator.of(context).pushReplacementNamed('/scheduling');
              } else {
                Navigator.of(context).pushReplacementNamed('/scheduling');
              }
              break;
            case AttentionType.document:
              Navigator.of(context).pushReplacementNamed('/documents');
              break;
          }
        },
        borderRadius: BorderRadius.circular(12), // Softer corners
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white, // Clean white background
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey.shade200),
          ),
          child: Row(
            children: [
              // ICON BOX
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: bgColor,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: iconColor, size: 20),
              ),
              const SizedBox(width: 12),

              // TEXT CONTENT
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

              // TIME OR ARROW (Optional: Just arrow for now)
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

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 70, // Increased width to fit the date
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 1. The Date (e.g., "Oct 24")
              Text(
                job.date,
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey,
                ),
              ),
              const SizedBox(height: 2),
              // 2. The Time (e.g., "9:00 AM")
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
        const SizedBox(width: 8), // Spacing between time/date and details
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

// --- Refactored Reusable Components ---

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
          decoration: AppTheme.cardDecoration, // Removed glow
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min, // Use min size
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
              const SizedBox(height: 24), // Increased spacing
              Flexible(
                // Use Flexible to prevent overflow
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
