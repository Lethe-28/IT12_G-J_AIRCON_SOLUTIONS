import 'package:flutter/material.dart';
import 'data/app_state.dart';
import 'ui_app_shell.dart';
import 'shared_header.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  // Sample data - in production, this would come from a data service
  final int _pendingJobs = 8;
  final int _unfinishedDocuments = 3;
  final double _totalRevenue = 125000.0;
  final int _todayJobs = 5;
  final int _thisWeekJobs = 18;
  final int _thisMonthJobs = 72;

  final List<_TodayJob> _todayJobOrders = [
    _TodayJob('JO-2025-001', 'ABC Corporation', '9:00 AM', 'Installation', 'In Progress'),
    _TodayJob('JO-2025-002', 'XYZ Retail Store', '11:30 AM', 'Maintenance', 'Pending'),
    _TodayJob('JO-2025-003', 'Global Mall', '2:00 PM', 'Repair', 'Pending'),
    _TodayJob('JO-2025-004', 'Maria Santos', '3:30 PM', 'Installation', 'Scheduled'),
  ];

  final List<_AttentionItem> _attentionItems = [
    _AttentionItem('Payment verification needed', 'JO-2025-002', 'High', Colors.orange),
    _AttentionItem('Document pending review', 'JO-2025-001', 'Medium', Colors.blue),
    _AttentionItem('Expense approval required', 'JO-2025-003', 'Medium', Colors.purple),
  ];

  final List<_ActivityItem> _recentActivities = [
    _ActivityItem('New job order created', 'JO-2025-005', '2 hours ago', Icons.add_circle),
    _ActivityItem('Payment received', 'JO-2025-002', '4 hours ago', Icons.payments),
    _ActivityItem('Job completed', 'JO-2025-001', 'Yesterday', Icons.check_circle),
    _ActivityItem('Expense recorded', 'Fuel expense', 'Yesterday', Icons.receipt),
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
              padding: EdgeInsets.all(_isServiceManager ? 24 : 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        'Overview',
                        style: TextStyle(fontSize: titleFontSize, fontWeight: FontWeight.w700),
                      ),
                      const Spacer(),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text('This month', style: TextStyle(fontSize: _isServiceManager ? 16.0 : 14.0)),
                            const SizedBox(width: 8),
                            const Icon(Icons.keyboard_arrow_up, size: 18, color: Colors.green),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  _overviewCardsRow(),
                  const SizedBox(height: 24),
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final isWideScreen = constraints.maxWidth >= 1024;
                      
                      if (isWideScreen) {
                        // Desktop layout: side by side
                        return Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(child: _todaysJobOrdersCard()),
                            const SizedBox(width: 20),
                            Expanded(
                              child: Column(
                                children: [
                                  _attentionCard(),
                                  const SizedBox(height: 20),
                                  _recentActivityCard(),
                                ],
                              ),
                            ),
                          ],
                        );
                      } else {
                        // Mobile/Tablet layout: stacked vertically
                        return Column(
                          children: [
                            _todaysJobOrdersCard(),
                            const SizedBox(height: 20),
                            _attentionCard(),
                            const SizedBox(height: 20),
                            _recentActivityCard(),
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

  Widget _overviewCardsRow() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isNarrow = constraints.maxWidth < 600;
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
        
        if (isNarrow) {
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

  Widget _overviewCard(String title, String value, IconData icon, Color color, double fontSize) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: color, size: 24),
              ),
              const Spacer(),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            value,
            style: TextStyle(
              fontSize: fontSize + 4,
              fontWeight: FontWeight.w800,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            title,
            style: TextStyle(
              fontSize: fontSize - 2,
              fontWeight: FontWeight.w600,
              color: Colors.black54,
            ),
          ),
        ],
      ),
    );
  }

  BoxDecoration _whiteCardDeco() => BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
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
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  '${_attentionItems.length}',
                  style: const TextStyle(color: Colors.red, fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (_attentionItems.isEmpty)
            const Padding(
              padding: EdgeInsets.all(20),
              child: Center(
                child: Text('No items requiring attention', style: TextStyle(color: Colors.black54)),
              ),
            )
          else
            ..._attentionItems.map((item) => _attentionItemRow(item)),
        ],
      ),
    );
  }

  Widget _attentionItemRow(_AttentionItem item) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: item.color.withOpacity(0.05),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: item.color.withOpacity(0.2)),
      ),
      child: Row(
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: item.color,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.title,
                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                ),
                const SizedBox(height: 4),
                Text(
                  item.reference,
                  style: const TextStyle(fontSize: 12, color: Colors.black54),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: item.color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              item.priority,
              style: TextStyle(fontSize: 11, color: item.color, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  Widget _recentActivityCard() {
    return Container(
      decoration: _whiteCardDeco(),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Recent Activity',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 16),
          if (_recentActivities.isEmpty)
            const Padding(
              padding: EdgeInsets.all(20),
              child: Center(
                child: Text('No recent activity', style: TextStyle(color: Colors.black54)),
              ),
            )
          else
            ..._recentActivities.map((activity) => _activityItemRow(activity)),
        ],
      ),
    );
  }

  Widget _activityItemRow(_ActivityItem activity) {
    // Determine icon background color based on activity type
    Color bgColor = const Color(0xFFEAF2FF);
    Color iconColor = const Color(0xFF2563EB);
    
    if (activity.title.contains('Payment')) {
      bgColor = const Color(0xFFE8FFF3);
      iconColor = Colors.green;
    } else if (activity.title.contains('Expense')) {
      bgColor = const Color(0xFFFFF4E5);
      iconColor = Colors.orange;
    } else if (activity.title.contains('completed') || activity.title.contains('Completed')) {
      bgColor = const Color(0xFFE0F2FE);
      iconColor = Colors.blue;
    }
    
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFFAFAFA),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE8E8E8)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: bgColor,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(activity.icon, size: 20, color: iconColor),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  activity.title,
                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                ),
                const SizedBox(height: 2),
                Text(
                  '${activity.reference} • ${activity.time}',
                  style: const TextStyle(fontSize: 12, color: Colors.black54),
                ),
              ],
            ),
          ),
          // Add visual indicator
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: iconColor,
              shape: BoxShape.circle,
            ),
          ),
        ],
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
                "Today's Job Orders",
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0xFFEAF2FF),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  '${_todayJobs} jobs',
                  style: const TextStyle(
                    color: Color(0xFF2563EB),
                    fontWeight: FontWeight.w600,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (_todayJobOrders.isEmpty)
            const Padding(
              padding: EdgeInsets.all(20),
              child: Center(
                child: Text('No job orders scheduled for today', style: TextStyle(color: Colors.black54)),
              ),
            )
          else
            ..._todayJobOrders.map((job) => _jobOrderRow(job)),
          const SizedBox(height: 12),
          const Divider(),
          const SizedBox(height: 12),
          Row(
            children: [
              _statMiniCard('Today', _todayJobs.toString(), Colors.blue),
              const SizedBox(width: 12),
              _statMiniCard('This Week', _thisWeekJobs.toString(), Colors.green),
              const SizedBox(width: 12),
              _statMiniCard('This Month', _thisMonthJobs.toString(), Colors.purple),
            ],
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
      case 'pending':
        statusColor = Colors.orange;
        break;
      default:
        statusColor = Colors.grey;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        children: [
          Container(
            width: 4,
            height: 40,
            decoration: BoxDecoration(
              color: statusColor,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      job.id,
                      style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: statusColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        job.status,
                        style: TextStyle(fontSize: 10, color: statusColor, fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  job.client,
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    Icon(Icons.access_time, size: 12, color: Colors.black54),
                    const SizedBox(width: 4),
                    Text(
                      '${job.time} • ${job.type}',
                      style: const TextStyle(fontSize: 12, color: Colors.black54),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _statMiniCard(String label, String value, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: color.withOpacity(0.05),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              value,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: color,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                color: Colors.black54,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

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

class _ActivityItem {
  final String title;
  final String reference;
  final String time;
  final IconData icon;

  _ActivityItem(this.title, this.reference, this.time, this.icon);
}
