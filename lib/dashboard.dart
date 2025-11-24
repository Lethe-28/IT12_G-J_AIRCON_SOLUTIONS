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
  // Sample Data (Simulating the Database)
  final int _pendingJobs = 8;
  final int _unfinishedDocuments = 3;
  final double _totalRevenue = 125000.0;
  final int _todayJobsCount = 5;

  final List<_TodayJob> _todayJobOrders = [
    _TodayJob(
      'JO-2025-001',
      'ABC Corporation',
      '9:00 AM',
      'Installation',
      'In Progress',
      'Makati',
    ),
    _TodayJob(
      'JO-2025-002',
      'XYZ Retail Store',
      '11:30 AM',
      'Maintenance',
      'Pending',
      'Quezon City',
    ),
    _TodayJob(
      'JO-2025-003',
      'Global Mall',
      '2:00 PM',
      'Repair',
      'Pending',
      'Pasig',
    ),
    _TodayJob(
      'JO-2025-004',
      'Maria Santos',
      '3:30 PM',
      'Installation',
      'Scheduled',
      'Mandaluyong',
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
    return AppShell(
      selectedIndex: 0,
      body: Column(
        children: [
          // 1. Shared Header (Kept for consistency)
          SharedHeader(
            welcomeText: AppState.headerWelcomeText(),
            subtitleText: _isServiceManager
                ? 'Here is your schedule for today.'
                : 'Overview of company performance.',
            notificationCount: _attentionItems.length,
          ),

          // 2. Main Content Area
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final isMobile = constraints.maxWidth < 900;

                  // --- MOBILE LAYOUT (Vertical Stack) ---
                  if (isMobile) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _SummaryStatsRow(
                          pending: _pendingJobs,
                          revenue: _totalRevenue,
                          docs: _unfinishedDocuments,
                          isMobile: true,
                        ),
                        const SizedBox(height: 20),
                        // Mobile Priority: Schedule first!
                        _TodaysJobsCard(
                          jobs: _todayJobOrders,
                          count: _todayJobsCount,
                        ),
                        const SizedBox(height: 20),
                        _AttentionCard(items: _attentionItems),
                      ],
                    );
                  }

                  // --- DESKTOP LAYOUT (Grid / Side-by-Side) ---
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _SummaryStatsRow(
                        pending: _pendingJobs,
                        revenue: _totalRevenue,
                        docs: _unfinishedDocuments,
                        isMobile: false,
                      ),
                      const SizedBox(height: 24),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Left Col: Schedule (Flex 2)
                          Expanded(
                            flex: 2,
                            child: _TodaysJobsCard(
                              jobs: _todayJobOrders,
                              count: _todayJobsCount,
                            ),
                          ),
                          const SizedBox(width: 20),
                          // Right Col: Attention Items (Flex 1)
                          Expanded(
                            flex: 1,
                            child: _AttentionCard(items: _attentionItems),
                          ),
                        ],
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _overviewCardsRow() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isMobileView = isMobile(context);
        final isTabletView = isTablet(context);
        final fontSize = _isServiceManager ? 18.0 : 16.0;

        final pendingCard = _overviewCard(
          'Pending Jobs',
          _pendingJobs.toString(),
          Icons.pending_actions,
          Colors.orange,
          fontSize,
        );
        final paymentsCard = _overviewCard(
          'Total Payments',
          '₱${_totalRevenue.toStringAsFixed(0)}',
          Icons.payments,
          Colors.green,
          fontSize,
        );
        final documentsCard = _overviewCard(
          'Documents',
          _unfinishedDocuments.toString(),
          Icons.description,
          Colors.blue,
          fontSize,
        );

        if (isMobileView) {
          return Column(
            children: [
              pendingCard,
              const SizedBox(height: 12),
              paymentsCard,
              const SizedBox(height: 12),
              documentsCard,
            ],
          );
        }

        if (isTabletView) {
          return Column(
            children: [
              Row(
                children: [
                  Expanded(child: pendingCard),
                  const SizedBox(width: 12),
                  Expanded(child: paymentsCard),
                ],
              ),
              const SizedBox(height: 12),
              documentsCard,
            ],
          );
        }

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

  Widget _overviewCard(
    String title,
    String value,
    IconData icon,
    Color color,
    double fontSize,
  ) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
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
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(width: 16),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                value,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                ),
              ),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 12,
                  color: Colors.black54,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _TodaysJobsCard extends StatelessWidget {
  final List<_TodayJob> jobs;
  final int count;

  const _TodaysJobsCard({required this.jobs, required this.count});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text(
                "Today's Jobs",
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFEAF2FF),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '$count Active',
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
          if (jobs.isEmpty)
            const Center(
              child: Text(
                'No jobs scheduled for today.',
                style: TextStyle(color: Colors.black45),
              ),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: jobs.length,
              separatorBuilder: (_, __) => const Divider(height: 24),
              itemBuilder: (context, index) {
                final job = jobs[index];
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Time Column
                    SizedBox(
                      width: 70,
                      child: Text(
                        job.time,
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          color: Colors.black54,
                        ),
                      ),
                    ),
                    // Job Details
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            job.client,
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 15,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Icon(
                                Icons.location_on_outlined,
                                size: 14,
                                color: Colors.grey[600],
                              ),
                              const SizedBox(width: 4),
                              Text(
                                job.location,
                                style: TextStyle(
                                  fontSize: 13,
                                  color: Colors.grey[600],
                                ),
                              ),
                              const SizedBox(width: 12),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.grey[100],
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  job.type,
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: Colors.grey[700],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    // Status Badge
                    _StatusBadge(status: job.status),
                  ],
                );
              },
            ),
        ],
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final String status;
  const _StatusBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    Color color;
    Color bg;

    switch (status.toLowerCase()) {
      case 'in progress':
        color = Colors.blue;
        bg = Colors.blue.withOpacity(0.1);
        break;
      case 'completed':
        color = Colors.green;
        bg = Colors.green.withOpacity(0.1);
        break;
      default:
        color = Colors.orange;
        bg = Colors.orange.withOpacity(0.1);
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        status,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: color,
        ),
      ),
    );
  }
}

class _AttentionCard extends StatelessWidget {
  final List<_AttentionItem> items;

  const _AttentionCard({required this.items});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text(
                'Attention Needed',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
              ),
              const Spacer(),
              if (items.isNotEmpty)
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
          if (items.isEmpty)
            const Text(
              'All caught up!',
              style: TextStyle(color: Colors.black54),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: items.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final item = items[index];
                return Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: item.color.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: item.color.withOpacity(0.1)),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.warning_amber_rounded,
                        color: item.color,
                        size: 20,
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
                    ],
                  ),
                );
              },
            ),
        ],
      ),
    );
  }
}

// Data Models
class _TodayJob {
  final String id;
  final String client;
  final String time;
  final String type;
  final String status;
  final String location;

  _TodayJob(
    this.id,
    this.client,
    this.time,
    this.type,
    this.status,
    this.location,
  );
}

class _AttentionItem {
  final String title;
  final String reference;
  final String priority;
  final Color color;

  _AttentionItem(this.title, this.reference, this.priority, this.color);
}
