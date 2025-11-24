import 'package:flutter/material.dart';
import 'ui_app_shell.dart';
import 'shared/widgets.dart' show isMobile;

// --- Design Constants ---
const Color kPrimaryColor = Color(0xFF2563EB);
const Color kTextPrimary = Color(0xFF1E293B);
const Color kTextSecondary = Color(0xFF64748B);
const Color kBorderColor = Color(0xFFE2E8F0);
const Color kSuccessColor = Color(0xFF10B981);
const Color kWarningColor = Color(0xFFF59E0B);
const Color kDangerColor = Color(0xFFEF4444);

// --- Main Screen ---

class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key});

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

enum _ReportRange { thisMonth, last30Days, allTime }
enum _ReportType { serviceSummary, expenseReport, technicianProductivity }

class _ReportsScreenState extends State<ReportsScreen> {
  _ReportRange _selectedRange = _ReportRange.thisMonth;
  _ReportType _selectedType = _ReportType.serviceSummary;

  @override
  Widget build(BuildContext context) {
    final report = _ReportData.forRange(_selectedRange);
    
    return AppShell(
      selectedIndex: 4,
      body: Container(
        color: const Color(0xFFF8FAFC),
        child: Column(
          children: [
            // Header & Controls - Responsive
            Container(
              padding: EdgeInsets.all(isMobile(context) ? 16 : 24),
              color: Colors.white,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (isMobile(context)) ...[
                    const Text('Reports & Analytics', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: kTextPrimary)),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: () {},
                        icon: const Icon(Icons.download, size: 16),
                        label: const Text('Export All Reports'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: kTextSecondary,
                          side: const BorderSide(color: kBorderColor),
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        ),
                      ),
                    ),
                  ] else ...[
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Reports & Analytics', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w700, color: kTextPrimary)),
                        OutlinedButton.icon(
                          onPressed: () {},
                          icon: const Icon(Icons.download, size: 16),
                          label: const Text('Export All Reports'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: kTextSecondary,
                            side: const BorderSide(color: kBorderColor),
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          ),
                        ),
                      ],
                    ),
                  ],
                  const SizedBox(height: 24),
                  // Filters Row - Always scrollable
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        // Range Selector
                        Container(
                          decoration: BoxDecoration(
                            color: const Color(0xFFF1F5F9),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          padding: const EdgeInsets.all(4),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              _RangeTab('This month', _ReportRange.thisMonth == _selectedRange, () => setState(() => _selectedRange = _ReportRange.thisMonth)),
                              _RangeTab('Last 30 days', _ReportRange.last30Days == _selectedRange, () => setState(() => _selectedRange = _ReportRange.last30Days)),
                              _RangeTab('All time', _ReportRange.allTime == _selectedRange, () => setState(() => _selectedRange = _ReportRange.allTime)),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        // Type Tabs - Scrollable
                        _TypeTab('Service Summary', _ReportType.serviceSummary == _selectedType, () => setState(() => _selectedType = _ReportType.serviceSummary)),
                        const SizedBox(width: 8),
                        _TypeTab('Expense Report', _ReportType.expenseReport == _selectedType, () => setState(() => _selectedType = _ReportType.expenseReport)),
                        const SizedBox(width: 8),
                        _TypeTab('Technician Productivity', _ReportType.technicianProductivity == _selectedType, () => setState(() => _selectedType = _ReportType.technicianProductivity)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 1, color: kBorderColor),

            // Main Content - Responsive padding
            Expanded(
              child: SingleChildScrollView(
                padding: EdgeInsets.all(isMobile(context) ? 16 : 32),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // KPI Grid
                    _buildKpiGrid(report),
                    SizedBox(height: isMobile(context) ? 16 : 32),
                    
                    // Financial Section
                    Text("Financial Overview", style: TextStyle(fontSize: isMobile(context) ? 16 : 18, fontWeight: FontWeight.w600, color: kTextPrimary)),
                    const SizedBox(height: 16),
                    _buildFinancialGrid(report),
                    SizedBox(height: isMobile(context) ? 16 : 32),

                    // Charts Section
                    _buildChartSection(),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildKpiGrid(_ReportData report) {
    return LayoutBuilder(
      builder: (context, constraints) {
        // Responsive Logic
        int crossAxisCount = 4;
        if (constraints.maxWidth < 1200) crossAxisCount = 2;
        if (constraints.maxWidth < 600) crossAxisCount = 1;
        
        final gap = 24.0;
        final totalGap = gap * (crossAxisCount - 1);
        final width = (constraints.maxWidth - totalGap) / crossAxisCount;

        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: [
            _KpiCard(
              title: 'Total Jobs',
              value: report.totalJobs.toString(),
              trend: '+12%',
              icon: Icons.work_outline,
              color: kPrimaryColor,
              width: width,
            ),
            _KpiCard(
              title: 'Installations',
              value: report.installations.toString(),
              trend: '+8%',
              icon: Icons.construction,
              color: kSuccessColor,
              width: width,
            ),
            _KpiCard(
              title: 'Maintenance',
              value: report.maintenance.toString(),
              trend: '+15%',
              icon: Icons.cleaning_services,
              color: Colors.teal,
              width: width,
            ),
            _KpiCard(
              title: 'Repairs',
              value: report.repairs.toString(),
              trend: '-5%',
              icon: Icons.build_circle_outlined,
              color: kWarningColor,
              width: width,
            ),
          ],
        );
      },
    );
  }

  Widget _buildFinancialGrid(_ReportData report) {
    return LayoutBuilder(
      builder: (context, constraints) {
        int crossAxisCount = 3;
        if (constraints.maxWidth < 900) crossAxisCount = 1;
        
        final gap = 24.0;
        final width = crossAxisCount == 1 ? constraints.maxWidth : (constraints.maxWidth - (gap * 2)) / 3;

        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: [
            _FinancialCard(
              label: 'Total Payments',
              amount: report.totalPaymentsFormatted,
              subtext: 'Cash-in',
              width: width,
            ),
            _FinancialCard(
              label: 'Total Expenses',
              amount: report.totalExpensesFormatted,
              subtext: 'Cash-out',
              isExpense: true,
              width: width,
            ),
            _FinancialCard(
              label: 'Net Cash',
              amount: report.netCashFormatted,
              subtext: 'Difference',
              width: width,
            ),
          ],
        );
      },
    );
  }

  Widget _buildChartSection() {
    // Mock Data for Chart
    final months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun'];
    final installs = [12.0, 16.0, 18.0, 20.0, 22.0, 25.0];
    final maintenance = [17.0, 22.0, 19.0, 25.0, 30.0, 33.0];
    final repairs = [8.0, 12.0, 10.0, 15.0, 18.0, 20.0];

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: kBorderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          LayoutBuilder(
            builder: (context, constraints) {
              final isNarrow = constraints.maxWidth < 500;
              if (isNarrow) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text("Service Summary (Last 6 Months)", style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: kTextPrimary)),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _ChartFilterBtn('6M', true),
                        _ChartFilterBtn('1Y', false),
                        OutlinedButton.icon(
                          onPressed: (){}, 
                          icon: const Icon(Icons.picture_as_pdf, size: 14),
                          label: const Text('PDF', style: TextStyle(fontSize: 12)),
                          style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8)),
                        ),
                      ],
                    ),
                  ],
                );
              }
              return Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text("Service Summary (Last 6 Months)", style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: kTextPrimary)),
                  Flexible(
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _ChartFilterBtn('6M', true),
                          const SizedBox(width: 8),
                          _ChartFilterBtn('1Y', false),
                          const SizedBox(width: 8),
                          OutlinedButton.icon(
                            onPressed: (){}, 
                            icon: const Icon(Icons.picture_as_pdf, size: 14),
                            label: const Text('PDF', style: TextStyle(fontSize: 12)),
                            style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8)),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 32),
          // Chart Visualization
          SizedBox(
            height: 250,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: List.generate(months.length, (i) {
                return Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        _Bar(height: installs[i] * 4, color: kPrimaryColor),
                        const SizedBox(width: 4),
                        _Bar(height: maintenance[i] * 4, color: kSuccessColor),
                        const SizedBox(width: 4),
                        _Bar(height: repairs[i] * 4, color: kWarningColor),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(months[i], style: const TextStyle(fontSize: 12, color: kTextSecondary)),
                  ],
                );
              }),
            ),
          ),
          const SizedBox(height: 24),
          // Legend - Responsive
          LayoutBuilder(
            builder: (context, constraints) {
              if (constraints.maxWidth < 400) {
                return Column(
                  children: const [
                    _ChartLegend(color: kPrimaryColor, label: 'Installations'),
                    SizedBox(height: 8),
                    _ChartLegend(color: kSuccessColor, label: 'Maintenance'),
                    SizedBox(height: 8),
                    _ChartLegend(color: kWarningColor, label: 'Repairs'),
                  ],
                );
              }
              return Wrap(
                alignment: WrapAlignment.center,
                spacing: 24,
                children: const [
                  _ChartLegend(color: kPrimaryColor, label: 'Installations'),
                  _ChartLegend(color: kSuccessColor, label: 'Maintenance'),
                  _ChartLegend(color: kWarningColor, label: 'Repairs'),
                ],
              );
            },
          )
        ],
      ),
    );
  }
}

// --- Widgets ---

class _RangeTab extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _RangeTab(this.label, this.isSelected, this.onTap);

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(6),
          boxShadow: isSelected ? [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 4)] : null,
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
            color: isSelected ? kTextPrimary : kTextSecondary,
          ),
        ),
      ),
    );
  }
}

class _TypeTab extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _TypeTab(this.label, this.isSelected, this.onTap);

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFFEFF6FF) : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: isSelected ? kPrimaryColor.withOpacity(0.2) : kBorderColor),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: isSelected ? kPrimaryColor : kTextSecondary,
          ),
        ),
      ),
    );
  }
}

class _KpiCard extends StatelessWidget {
  final String title;
  final String value;
  final String trend;
  final IconData icon;
  final Color color;
  final double width;

  const _KpiCard({
    required this.title,
    required this.value,
    required this.trend,
    required this.icon,
    required this.color,
    required this.width,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: kBorderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
            child: Icon(icon, size: 20, color: color),
          ),
          const Spacer(),
          Text(title, style: const TextStyle(fontSize: 13, color: kTextSecondary, fontWeight: FontWeight.w500)),
          const SizedBox(height: 4),
          Text(value, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w700, color: kTextPrimary)),
          const SizedBox(height: 4),
          Text(trend, style: const TextStyle(fontSize: 11, color: kTextSecondary)), // Simplified trend for clean look
        ],
      ),
      height: 160, // Fixed height for uniformity
    );
  }
}

class _FinancialCard extends StatelessWidget {
  final String label;
  final String amount;
  final String subtext;
  final double width;
  final bool isExpense;

  const _FinancialCard({
    required this.label,
    required this.amount,
    required this.subtext,
    required this.width,
    this.isExpense = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: kBorderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: kTextPrimary)),
          const SizedBox(height: 8),
          Text(amount, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: kTextPrimary)),
          const SizedBox(height: 4),
          Text(subtext, style: const TextStyle(fontSize: 12, color: kTextSecondary)),
        ],
      ),
    );
  }
}

class _ChartFilterBtn extends StatelessWidget {
  final String label;
  final bool selected;
  const _ChartFilterBtn(this.label, this.selected);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: selected ? Colors.white : Colors.transparent,
        border: Border.all(color: selected ? kTextSecondary : kBorderColor),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(label, style: TextStyle(fontSize: 12, fontWeight: selected ? FontWeight.w600 : FontWeight.w400)),
    );
  }
}

class _Bar extends StatelessWidget {
  final double height;
  final Color color;
  const _Bar({required this.height, required this.color});
  
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 12,
      height: height,
      decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(4)),
    );
  }
}

class _ChartLegend extends StatelessWidget {
  final Color color;
  final String label;
  const _ChartLegend({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(width: 12, height: 12, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(2))),
        const SizedBox(width: 8),
        Text(label, style: const TextStyle(fontSize: 12, color: kTextSecondary)),
      ],
    );
  }
}

// --- Helper Data ---

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
  String get totalPaymentsFormatted => '₱${totalPayments.toStringAsFixed(2)}';
  String get totalExpensesFormatted => '₱${totalExpenses.toStringAsFixed(2)}';
  String get netCashFormatted => '₱${netCash.toStringAsFixed(2)}';

  static _ReportData forRange(_ReportRange range) {
    // Mock Logic for demo
    double multiplier = 1.0;
    if (range == _ReportRange.last30Days) multiplier = 0.8;
    if (range == _ReportRange.allTime) multiplier = 12.5;

    return _ReportData(
      totalJobs: (285 * multiplier).round(),
      installations: (112 * multiplier).round(),
      maintenance: (143 * multiplier).round(),
      repairs: (83 * multiplier).round(),
      totalPayments: 22000.0 * multiplier,
      totalExpenses: 3330.0 * multiplier,
    );
  }
}