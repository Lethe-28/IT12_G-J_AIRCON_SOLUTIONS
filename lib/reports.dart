import 'package:flutter/material.dart';
import 'ui_app_shell.dart';

class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key});

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

enum _ReportRange { thisMonth, last30Days, allTime }

class _ReportsScreenState extends State<ReportsScreen> {
  _ReportRange _selectedRange = _ReportRange.thisMonth;

  @override
  Widget build(BuildContext context) {
    final report = _ReportData.forRange(_selectedRange);
    return AppShell(
      selectedIndex: 4,
      body: Column(
        children: [
          
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      const Text('Reports & Analytics',
                          style: TextStyle(fontSize: 24, fontWeight: FontWeight.w700)),
                      ElevatedButton.icon(
                        onPressed: () {},
                        icon: const Icon(Icons.file_download_outlined),
                        label: const Text('Export All Reports'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Wrap(
                    spacing: 8,
                    runSpacing: 4,
                    children: [
                      _rangeChip('This month', _ReportRange.thisMonth),
                      _rangeChip('Last 30 days', _ReportRange.last30Days),
                      _rangeChip('All time', _ReportRange.allTime),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      _tab('Service Summary', true),
                      const SizedBox(width: 10),
                      _tab('Expense Report', false),
                      const SizedBox(width: 10),
                      _tab('Technician Productivity', false),
                    ],
                  ),
                  const SizedBox(height: 16),
                  _serviceStatsSection(report),
                  const SizedBox(height: 18),
                  const SizedBox(height: 4),
                  const Text('Financial Overview',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 12),
                  _financialSection(report),
                  const SizedBox(height: 24),
                  _barChartCard(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _serviceStatsSection(_ReportData report) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isSmall = constraints.maxWidth < 600;
        final isMedium = constraints.maxWidth < 1000;
        
        int crossAxisCount = 4;
        if (isSmall) crossAxisCount = 2;
        else if (isMedium) crossAxisCount = 2;

        final cards = [
          _miniStat('Total Jobs', report.totalJobs.toString(), '+ 12%', Colors.blue),
          _miniStat('Installations', report.installations.toString(), '+ 8%', Colors.green),
          _miniStat('Maintenance', report.maintenance.toString(), '+ 15%', Colors.teal),
          _miniStat('Repairs', report.repairs.toString(), '− 5%', Colors.orange),
        ];

        return GridView.count(
          crossAxisCount: crossAxisCount,
          mainAxisSpacing: 8,
          crossAxisSpacing: 8,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          childAspectRatio: 1.0,
          children: cards,
        );
      },
    );
  }

  Widget _financialSection(_ReportData report) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isSmall = constraints.maxWidth < 600;
        final isMedium = constraints.maxWidth < 1000;
        
        int crossAxisCount = 3;
        if (isSmall) crossAxisCount = 1;
        else if (isMedium) crossAxisCount = 2;

        final cards = [
          _miniStat('Total Payments', report.totalPaymentsFormatted, 'Cash-in', Colors.green),
          _miniStat('Total Expenses', report.totalExpensesFormatted, 'Cash-out', Colors.red),
          _miniStat('Net Cash', report.netCashFormatted, 'Difference', Colors.indigo),
        ];

        return GridView.count(
          crossAxisCount: crossAxisCount,
          mainAxisSpacing: 8,
          crossAxisSpacing: 8,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          childAspectRatio: 1.0,
          children: cards,
        );
      },
    );
  }

  Widget _rangeChip(String label, _ReportRange range) {
    final selected = _selectedRange == range;
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) {
        setState(() => _selectedRange = range);
      },
    );
  }

  Widget _tab(String label, bool selected) {
    return Container(
      decoration: BoxDecoration(
        color: selected ? const Color(0xFFEAF2FF) : Colors.white,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Text(label,
          style: TextStyle(
              color: selected ? const Color(0xFF2563EB) : Colors.black87,
              fontWeight: FontWeight.w600)),
    );
  }

  Widget _miniStat(String title, String value, String note, Color color) {
    return Container(
      decoration: _cardDeco(),
      padding: const EdgeInsets.all(10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Container(
            decoration: BoxDecoration(color: color.withOpacity(.1), borderRadius: BorderRadius.circular(8)),
            padding: const EdgeInsets.all(6),
            child: Icon(Icons.trending_up, color: color, size: 16),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 11)),
              const SizedBox(height: 2),
              Text(value, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800)),
              const SizedBox(height: 1),
              Text(note, style: const TextStyle(color: Colors.black54, fontSize: 9)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _barChartCard() {
    final months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun'];
    final installs = [12.0, 16.0, 18.0, 20.0, 22.0, 25.0];
    final maintenance = [17.0, 22.0, 19.0, 25.0, 30.0, 33.0];
    final repairs = [8.0, 12.0, 10.0, 15.0, 18.0, 20.0];
    return Container(
      decoration: _cardDeco(),
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text('Service Summary (Last 6 Months)',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
              const Spacer(),
              OutlinedButton(onPressed: () {}, child: const Text('6M', style: TextStyle(fontSize: 12))),
              const SizedBox(width: 6),
              OutlinedButton(onPressed: () {}, child: const Text('1Y', style: TextStyle(fontSize: 12))),
              const SizedBox(width: 6),
              ElevatedButton.icon(
                onPressed: () {},
                icon: const Icon(Icons.picture_as_pdf_outlined, size: 16),
                label: const Text('PDF', style: TextStyle(fontSize: 12)),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 220,
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: SizedBox(
                width: months.length * 45.0,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: List.generate(months.length, (i) {
                    return SizedBox(
                      width: 45,
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          _barGroup(installs[i], maintenance[i], repairs[i]),
                          const SizedBox(height: 4),
                          Text(months[i], style: const TextStyle(fontSize: 11)),
                        ],
                      ),
                    );
                  }),
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: const [
                  _Legend(color: Colors.blue, text: 'Installations'),
                  SizedBox(width: 12),
                  _Legend(color: Colors.green, text: 'Maintenance'),
                  SizedBox(width: 12),
                  _Legend(color: Colors.orange, text: 'Repairs'),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _barGroup(double a, double b, double c) {
    double scale = 8; // simple scale to fit height
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        _bar(a * scale, Colors.blue),
        const SizedBox(width: 4),
        _bar(b * scale, Colors.green),
        const SizedBox(width: 4),
        _bar(c * scale, Colors.orange),
      ],
    );
  }

  Widget _bar(double height, Color color) {
    return Expanded(
      child: Container(
        height: height,
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(6),
        ),
      ),
    );
  }

  BoxDecoration _cardDeco() => BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      );
}

class _ReportData {
  final int totalJobs;
  final int installations;
  final int maintenance;
  final int repairs;
  final double totalPayments;
  final double totalExpenses;

  const _ReportData({
    required this.totalJobs,
    required this.installations,
    required this.maintenance,
    required this.repairs,
    required this.totalPayments,
    required this.totalExpenses,
  });

  double get netCash => totalPayments - totalExpenses;

  String get totalPaymentsFormatted => _formatCurrency(totalPayments);
  String get totalExpensesFormatted => _formatCurrency(totalExpenses);
  String get netCashFormatted => _formatCurrency(netCash);

  static String _formatCurrency(double value) => '₱${value.toStringAsFixed(2)}';

  static _ReportData sample() {
    // Sample job stats (can be wired to real data later)
    const totalJobs = 285;
    const installations = 112;
    const maintenance = 143;
    const repairs = 83;

    // Sample financials based on seeded demo data from payments and expenses
    const paymentAmounts = [18500.0, 3500.0];
    const expenseAmounts = [450.0, 2500.0, 380.0];

    final totalPayments =
        paymentAmounts.fold<double>(0, (sum, v) => sum + v);
    final totalExpenses =
        expenseAmounts.fold<double>(0, (sum, v) => sum + v);

    return _ReportData(
      totalJobs: totalJobs,
      installations: installations,
      maintenance: maintenance,
      repairs: repairs,
      totalPayments: totalPayments,
      totalExpenses: totalExpenses,
    );
  }

  static _ReportData forRange(_ReportRange range) {
    final base = sample();
    switch (range) {
      case _ReportRange.thisMonth:
        // Use the base sample as "this month".
        return base;
      case _ReportRange.last30Days:
        // Slightly smaller numbers to simulate a shorter period.
        return _ReportData(
          totalJobs: (base.totalJobs * 0.7).round(),
          installations: (base.installations * 0.7).round(),
          maintenance: (base.maintenance * 0.7).round(),
          repairs: (base.repairs * 0.7).round(),
          totalPayments: base.totalPayments * 0.75,
          totalExpenses: base.totalExpenses * 0.75,
        );
      case _ReportRange.allTime:
        // Slightly larger numbers to represent a longer history.
        return _ReportData(
          totalJobs: (base.totalJobs * 1.4).round(),
          installations: (base.installations * 1.4).round(),
          maintenance: (base.maintenance * 1.4).round(),
          repairs: (base.repairs * 1.4).round(),
          totalPayments: base.totalPayments * 1.6,
          totalExpenses: base.totalExpenses * 1.6,
        );
    }
  }
}

class _Legend extends StatelessWidget {
  final Color color;
  final String text;
  const _Legend({required this.color, required this.text});
  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(width: 12, height: 12, color: color),
        const SizedBox(width: 6),
        Text(text, style: const TextStyle(color: Colors.black54)),
      ],
    );
  }
}


