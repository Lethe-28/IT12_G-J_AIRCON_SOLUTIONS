import 'package:flutter/material.dart';
import 'data/app_state.dart';
import 'ui_app_shell.dart';
import 'shared_header.dart';
import 'shared/widgets.dart' show isMobile, isTablet;

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  // Sample data
  final int _pendingJobs = 8;
  final int _unfinishedDocuments = 3;
  final double _totalRevenue = 125000.0;
  final int _todayJobs = 5;

  final List<_TodayJob> _todayJobOrders = [
    _TodayJob(
      'JO-2025-001',
      'ABC Corporation',
      '9:00 AM',
      'Installation',
      'In Progress',
    ),
    _TodayJob(
      'JO-2025-002',
      'XYZ Retail Store',
      '11:30 AM',
      'Maintenance',
      'Pending',
    ),
    _TodayJob('JO-2025-003', 'Global Mall', '2:00 PM', 'Repair', 'Pending'),
    _TodayJob(
      'JO-2025-004',
      'Maria Santos',
      '3:30 PM',
      'Installation',
      'Scheduled',
    ),
  ];

  final List<_AttentionItem> _attentionItems = [
    _AttentionItem(
      'Payment verification needed',
      'JO-2025-002',
      'High',
      Colors.orange,
    ),
    _AttentionItem(
      'Document pending review',
      'JO-2025-001',
      'Medium',
      Colors.blue,
    ),
    _AttentionItem(
      'Expense approval required',
      'JO-2025-003',
      'Medium',
      Colors.purple,
    ),
  ];

  bool get _isServiceManager => AppState.currentRole == UserRole.serviceManager;

  @override
  Widget build(BuildContext context) {
    final titleFontSize = _isServiceManager ? 24.0 : 20.0;

    return AppShell(
      selectedIndex: 0,
      body: Column(
        children: [
          SharedHeader(
            welcomeText: AppState.headerWelcomeText(),
            subtitleText: AppState.headerSubtitle(),
            notificationCount: _attentionItems.length,
          ),
          Expanded(
            child: SingleChildScrollView(
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
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
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
                              'Today',
                              style: TextStyle(
                                fontSize: _isServiceManager ? 14.0 : 12.0,
                                fontWeight: FontWeight.w600,
                                color: Colors.black54,
                              ),
                            ),
                          ],
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
                            Expanded(flex: 2, child: _todaysJobOrdersCard()),
                            const SizedBox(width: 24),
                            Expanded(flex: 1, child: _attentionCard()),
                          ],
                        );
                      } else {
                        // Mobile: Stacked
                        return Column(
                          children: [
                            _todaysJobOrdersCard(),
                            const SizedBox(height: 20),
                            _attentionCard(),
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
          value: _pendingJobs.toString(),
          icon: Icons.pending_actions,
          color: Colors.orange,
          fontSize: fontSize,
          onTap: () =>
              Navigator.of(context).pushReplacementNamed('/scheduling'),
        );

        final paymentsCard = _OverviewCard(
          title: 'Total Revenue',
          value: '₱${_totalRevenue.toStringAsFixed(0)}',
          icon: Icons.payments,
          color: Colors.green,
          fontSize: fontSize,
          onTap: () => Navigator.of(context).pushReplacementNamed('/payments'),
        );

        final documentsCard = _OverviewCard(
          title: 'Pending Docs',
          value: _unfinishedDocuments.toString(),
          icon: Icons.description,
          color: Colors.blue,
          fontSize: fontSize,
          onTap: () => Navigator.of(context).pushReplacementNamed('/documents'),
        );

        // MOBILE: Horizontal Scroll (Carousel)
        // This prevents overflow by giving cards infinite horizontal space
        if (isMobileView) {
          return SizedBox(
            height: 130, // Give enough height so it doesn't overflow vertically
            // We use a negative margin on the parent to allow cards to touch the screen edge
            // while keeping the main padding for the rest of the content.
            child: ListView(
              scrollDirection: Axis.horizontal,
              // Add padding inside the list view so the first card aligns with text
              padding: const EdgeInsets.only(bottom: 4),
              children: [
                SizedBox(width: 160, child: pendingCard),
                const SizedBox(width: 12),
                SizedBox(width: 180, child: paymentsCard),
                const SizedBox(width: 12),
                SizedBox(width: 160, child: documentsCard),
              ],
            ),
          );
        }

        // DESKTOP: Standard Row
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: pendingCard),
            const SizedBox(width: 16),
            Expanded(child: paymentsCard),
            const SizedBox(width: 16),
            Expanded(child: documentsCard),
          ],
        );
      },
    );
  }

  BoxDecoration _whiteCardDeco() => BoxDecoration(
    color: Colors.white,
    borderRadius: BorderRadius.circular(12),
    border: Border.all(color: const Color(0xFFE2E8F0)),
    boxShadow: [
      BoxShadow(
        color: Colors.black.withOpacity(0.02),
        blurRadius: 4,
        offset: const Offset(0, 2),
      ),
    ],
  );

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
              if (_attentionItems.isNotEmpty)
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
          if (_attentionItems.isEmpty)
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
              itemCount: _attentionItems.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (ctx, i) => _attentionItemRow(_attentionItems[i]),
            ),
        ],
      ),
    );
  }

  Widget _attentionItemRow(_AttentionItem item) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {},
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
          Row(
            children: [
              const Text(
                "Today's Schedule",
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
                  '${_todayJobs} Active',
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
          if (_todayJobOrders.isEmpty)
            const Padding(
              padding: EdgeInsets.all(24),
              child: Center(
                child: Text(
                  'No jobs scheduled for today',
                  style: TextStyle(color: Colors.black54),
                ),
              ),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _todayJobOrders.length,
              separatorBuilder: (_, __) => const Divider(height: 24),
              itemBuilder: (_, i) => _jobOrderRow(_todayJobOrders[i]),
            ),
        ],
      ),
    );
  }

  Widget _jobOrderRow(_TodayJob job) {
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
      color: Colors.white,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          // FIX: Removed explicit height constraint to prevent overflow
          // FIX: Added constraints to prevent "RenderBox not laid out" error on Desktop
          constraints: const BoxConstraints(minHeight: 100),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: color.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(icon, color: color, size: 18),
                  ),
                  const Spacer(),
                  const Icon(
                    Icons.arrow_forward,
                    size: 14,
                    color: Colors.black26,
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                value,
                style: TextStyle(
                  fontSize: fontSize + 2,
                  fontWeight: FontWeight.w800,
                  color: Colors.black87,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 2),
              Text(
                title,
                style: TextStyle(
                  fontSize: fontSize - 4,
                  fontWeight: FontWeight.w600,
                  color: Colors.black54,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// --- Data Models ---

class _TodayJob {
  final String id;
  final String client;
  final String time;
  final String type;
  final String status;

  _TodayJob(this.id, this.client, this.time, this.type, this.status);
}

class _AttentionItem {
  final String title;
  final String reference;
  final String priority;
  final Color color;

  _AttentionItem(this.title, this.reference, this.priority, this.color);
}
