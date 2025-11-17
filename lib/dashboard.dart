import 'package:flutter/material.dart';
import 'ui_app_shell.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return AppShell(
      selectedIndex: 0,
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Text(
                  'Admin Dashboard',
                  style: TextStyle(fontSize: 26, fontWeight: FontWeight.w800),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(999),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x11000000),
                        blurRadius: 8,
                        offset: Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Row(
                    children: const [
                      Icon(Icons.notifications_none, color: Colors.black87),
                      SizedBox(width: 6),
                      CircleAvatar(
                        radius: 10,
                        backgroundColor: Colors.red,
                        child: Text(
                          '3',
                          style: TextStyle(color: Colors.white, fontSize: 12),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            _summaryCardsRow(),
            const SizedBox(height: 24),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: _requiresAttentionCard()),
                const SizedBox(width: 20),
                Expanded(child: _recentActivityCard()),
              ],
            ),
            const SizedBox(height: 24),
            _todaysJobOrdersCard(),
          ],
        ),
      ),
    );
  }

  Widget _summaryCardsRow() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isNarrow = constraints.maxWidth < 800;
        final children = [
          _summaryCard(
            title: 'Pending Jobs',
            value: '12',
            color: const Color(0xFF2563EB),
          ),
          _summaryCard(
            title: 'Completed Today',
            value: '8',
            color: const Color(0xFF16A34A),
          ),
          _summaryCard(
            title: 'Pending Payments',
            value: '45,230',
            color: const Color(0xFFF97316),
          ),
          _summaryCard(
            title: 'Documents Due',
            value: '5',
            color: const Color(0xFFA855F7),
          ),
        ];
        if (isNarrow) {
          return Column(
            children: [
              Row(children: [Expanded(child: children[0]), const SizedBox(width: 12), Expanded(child: children[1])]),
              const SizedBox(height: 12),
              Row(children: [Expanded(child: children[2]), const SizedBox(width: 12), Expanded(child: children[3])]),
            ],
          );
        }
        return Row(
          children: [
            Expanded(child: children[0]),
            const SizedBox(width: 16),
            Expanded(child: children[1]),
            const SizedBox(width: 16),
            Expanded(child: children[2]),
            const SizedBox(width: 16),
            Expanded(child: children[3]),
          ],
        );
      },
    );
  }

  Widget _summaryCard({required String title, required String value, required Color color}) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(color: Colors.black87, fontSize: 14, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 10),
          Text(
            value,
            style: const TextStyle(color: Colors.black, fontSize: 26, fontWeight: FontWeight.w800),
          ),
        ],
      ),
    );
  }

  BoxDecoration _whiteCardDeco() => BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: const [
          BoxShadow(color: Color(0x11000000), blurRadius: 16, offset: Offset(0, 10)),
        ],
      );

  Widget _requiresAttentionCard() {
    final items = [
      'Missing receipt - Job #1234',
      'Payment overdue - ABC Corp',
      'Complete SOA for XYZ Building',
    ];
    return Container(
      decoration: _whiteCardDeco(),
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: const [
              Icon(Icons.notifications_active_outlined, color: Colors.orange),
              SizedBox(width: 8),
              Text(
                'Requires Attention',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ...items.map((text) {
            return Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      text,
                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                    ),
                  ),
                  const Icon(Icons.chevron_right, color: Colors.black38),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _recentActivityCard() {
    final items = [
      'Job #1245 completed by SM1',
      'Payment received - 5,200',
      'New job order from Home Owner',
    ];
    return Container(
      decoration: _whiteCardDeco(),
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: const [
              Icon(Icons.access_time, color: Colors.blue),
              SizedBox(width: 8),
              Text(
                'Recent Activity',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ...items.map((text) {
            return Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: const Color(0xFFF9FAFB),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: const BoxDecoration(
                      color: Colors.black87,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      text,
                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _todaysJobOrdersCard() {
    final rows = [
      ('#1234', 'ABC Corp', 'B2B', '10:00 AM', 'In Progress', 'Pending'),
      ('#1235', 'John Doe', 'B2C', '2:00 PM', 'Scheduled', 'Paid'),
      ('#1236', 'XYZ Building', 'B2B', '4:30 PM', 'Scheduled', 'Pending'),
    ];
    return Container(
      decoration: _whiteCardDeco(),
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(18),
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
              TextButton(onPressed: () {}, child: const Text('View All')),
            ],
          ),
          const SizedBox(height: 10),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: ConstrainedBox(
              constraints: const BoxConstraints(minWidth: 700),
              child: DataTable(
                headingRowHeight: 40,
                dataRowHeight: 44,
                columns: const [
                  DataColumn(label: Text('Job ID')),
                  DataColumn(label: Text('Customer')),
                  DataColumn(label: Text('Type')),
                  DataColumn(label: Text('Schedule')),
                  DataColumn(label: Text('Status')),
                  DataColumn(label: Text('Payment')),
                ],
                rows: rows.map((r) => _jobRow(r)).toList(),
              ),
            ),
          ),
        ],
      ),
    );
  }

  DataRow _jobRow((String, String, String, String, String, String) r) {
    final id = r.$1;
    final customer = r.$2;
    final type = r.$3;
    final schedule = r.$4;
    final status = r.$5;
    final payment = r.$6;
    return DataRow(cells: [
      DataCell(
        Text(
          id,
          style: const TextStyle(color: Colors.black, fontWeight: FontWeight.w600),
        ),
      ),
      DataCell(Text(customer)),
      DataCell(_pill(type, const Color(0xFFF3F4F6), Colors.black87)),
      DataCell(Text(schedule)),
      DataCell(_pill(
        status,
        const Color(0xFFF3F4F6),
        Colors.black87,
      )),
      DataCell(_pill(
        payment,
        const Color(0xFFF9FAFB),
        Colors.black87,
      )),
    ]);
  }

  Widget _pill(String text, Color bg, Color fg) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        text,
        style: TextStyle(color: fg, fontSize: 12, fontWeight: FontWeight.w600),
      ),
    );
  }
}
