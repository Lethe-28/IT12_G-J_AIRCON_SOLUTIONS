import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import 'ui_app_shell.dart';
import 'theme/app_theme.dart';
import 'shared/widgets.dart' show AnimatedCard, HoverCard, AnimatedButton, isMobile;

// --- Main Screen ---

class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key});

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

enum _ReportRange { today, weekly, monthly, last6Months, yearly }

class _ReportsScreenState extends State<ReportsScreen> {
  _ReportRange _selectedRange = _ReportRange.monthly;
  
  bool _isLoading = false;
  _ReportData _reportData = _ReportData.empty();
  List<_ChartDataPoint> _serviceChartData = [];
  List<_FinancialChartPoint> _financialChartData = [];
  List<_TopCustomer> _topCustomers = [];

  @override
  void initState() {
    super.initState();
    _fetchReportData();
  }

  Future<void> _fetchReportData() async {
    if (!mounted) return;
    setState(() => _isLoading = true);

    try {
      final supabase = Supabase.instance.client;
      final now = DateTime.now();
      DateTime startDate;
      DateTime endDate = DateTime(now.year, now.month, now.day, 23, 59, 59);

      switch (_selectedRange) {
        case _ReportRange.today:
          startDate = DateTime(now.year, now.month, now.day);
          break;
        case _ReportRange.weekly:
          startDate = now.subtract(Duration(days: now.weekday - 1));
          startDate = DateTime(startDate.year, startDate.month, startDate.day);
          break;
        case _ReportRange.monthly:
          startDate = DateTime(now.year, now.month, 1);
          break;
        case _ReportRange.last6Months:
          startDate = DateTime(now.year, now.month - 5, 1);
          break;
        case _ReportRange.yearly:
          startDate = DateTime(now.year, 1, 1);
          break;
      }

      final startStr = startDate.toIso8601String();
      final endStr = endDate.toIso8601String();

      // 1. Fetch Job Orders
      final jobsResponse = await supabase
          .from('job_orders')
          .select('id, status, date_scheduled, customer_id, customers(company_name, first_name, last_name), job_types(job_type_name)')
          .gte('date_scheduled', startStr)
          .lte('date_scheduled', endStr);

      // 2. Fetch Payments
      final paymentsResponse = await supabase
          .from('payments')
          .select('amount, payment_date')
          .eq('status', 'Verified')
          .gte('payment_date', startStr)
          .lte('payment_date', endStr);

      // 3. Fetch Expenses
      final expensesResponse = await supabase
          .from('expenses')
          .select('amount, date')
          .gte('date', startStr)
          .lte('date', endStr);

      // --- Process Data ---

      int totalJobs = jobsResponse.length;
      int installations = 0;
      int maintenance = 0;
      int repairs = 0;
      int completedJobs = 0;

      Map<String, _ChartDataPoint> serviceMap = {};
      Map<String, _FinancialChartPoint> financialMap = {};
      Map<int, _TopCustomer> customerAggMap = {};
      
      // For Business Insights
      Map<String, int> jobTypeCounts = {};
      Map<String, int> dayCounts = {};

      String getKey(DateTime date) {
        if (_selectedRange == _ReportRange.today || _selectedRange == _ReportRange.weekly) {
          return DateFormat('EEE').format(date);
        } else if (_selectedRange == _ReportRange.monthly) {
          return DateFormat('dd').format(date);
        } else {
          return DateFormat('MMM').format(date);
        }
      }

      for (var job in jobsResponse) {
        final typeName = (job['job_types']?['job_type_name'] ?? 'Unknown').toString();
        final typeKey = typeName.toLowerCase();
        final status = (job['status'] ?? '').toString().toLowerCase();
        final date = DateTime.parse(job['date_scheduled']);

        if (status == 'completed') completedJobs++;
        
        // Categorize
        if (typeKey.contains('install')) installations++;
        else if (typeKey.contains('maintenance') || typeKey.contains('clean')) maintenance++;
        else if (typeKey.contains('repair')) repairs++;

        // Top Service Logic
        jobTypeCounts[typeName] = (jobTypeCounts[typeName] ?? 0) + 1;

        // Busiest Day Logic
        final dayName = DateFormat('EEEE').format(date);
        dayCounts[dayName] = (dayCounts[dayName] ?? 0) + 1;

        final key = getKey(date);

        if (!serviceMap.containsKey(key)) {
          serviceMap[key] = _ChartDataPoint(label: key, installations: 0, maintenance: 0, repairs: 0);
        }
        if (typeKey.contains('install')) serviceMap[key]!.installations++;
        else if (typeKey.contains('maintenance') || typeKey.contains('clean')) serviceMap[key]!.maintenance++;
        else if (typeKey.contains('repair')) serviceMap[key]!.repairs++;

        // Top Customers
        if (job['customer_id'] != null && job['customers'] != null) {
          final cid = job['customer_id'] as int;
          final cData = job['customers'];
          final name = cData['company_name'] ?? '${cData['first_name']} ${cData['last_name']}';
          
          if (!customerAggMap.containsKey(cid)) {
            customerAggMap[cid] = _TopCustomer(name: name, jobCount: 0);
          }
          customerAggMap[cid]!.jobCount++;
        }
      }

      // Determine Top Service
      String topService = 'N/A';
      int maxServiceCount = 0;
      jobTypeCounts.forEach((key, value) {
        if (value > maxServiceCount) {
          maxServiceCount = value;
          topService = key;
        }
      });

      // Determine Busiest Day
      String busiestDay = 'N/A';
      int maxDayCount = 0;
      dayCounts.forEach((key, value) {
        if (value > maxDayCount) {
          maxDayCount = value;
          busiestDay = key;
        }
      });

      double totalPayments = 0;
      for (var p in paymentsResponse) {
        final amount = (p['amount'] as num).toDouble();
        totalPayments += amount;
        final date = DateTime.parse(p['payment_date']);
        final key = getKey(date);

        if (!financialMap.containsKey(key)) {
          financialMap[key] = _FinancialChartPoint(label: key, income: 0, expense: 0);
        }
        financialMap[key]!.income += amount;
      }

      double totalExpenses = 0;
      for (var e in expensesResponse) {
        final amount = (e['amount'] as num).toDouble();
        totalExpenses += amount;
        final date = DateTime.parse(e['date']);
        final key = getKey(date);

        if (!financialMap.containsKey(key)) {
          financialMap[key] = _FinancialChartPoint(label: key, income: 0, expense: 0);
        }
        financialMap[key]!.expense += amount;
      }

      _serviceChartData = serviceMap.values.toList();
      _financialChartData = financialMap.values.toList();
      
      _topCustomers = customerAggMap.values.toList()
        ..sort((a, b) => b.jobCount.compareTo(a.jobCount));
      if (_topCustomers.length > 5) _topCustomers = _topCustomers.sublist(0, 5);

      if (mounted) {
        setState(() {
          _reportData = _ReportData(
            totalJobs: totalJobs,
            installations: installations,
            maintenance: maintenance,
            repairs: repairs,
            completedJobs: completedJobs,
            totalPayments: totalPayments,
            totalExpenses: totalExpenses,
            topService: topService,
            busiestDay: busiestDay,
          );
          _isLoading = false;
        });
      }

    } catch (e) {
      debugPrint('Error fetching report data: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool mobile = isMobile(context);
    
    return AppShell(
      selectedIndex: 4,
      body: Container(
        color: AppTheme.background,
        child: Column(
          children: [
            // Header
            Container(
              padding: EdgeInsets.symmetric(horizontal: mobile ? 16 : 24, vertical: 16),
              decoration: const BoxDecoration(
                color: AppTheme.surface,
                border: Border(bottom: BorderSide(color: AppTheme.borderColor)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end, // Align to right
                children: [
                  // Dropdown Filter
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppTheme.background,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AppTheme.borderColor),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<_ReportRange>(
                        value: _selectedRange,
                        isDense: true,
                        icon: const Icon(Icons.keyboard_arrow_down, color: AppTheme.textSecondary),
                        style: AppTheme.body.copyWith(fontWeight: FontWeight.w600),
                        items: const [
                          DropdownMenuItem(value: _ReportRange.today, child: Text("Today")),
                          DropdownMenuItem(value: _ReportRange.weekly, child: Text("Weekly")),
                          DropdownMenuItem(value: _ReportRange.monthly, child: Text("Monthly")),
                          DropdownMenuItem(value: _ReportRange.last6Months, child: Text("Last 6 Months")),
                          DropdownMenuItem(value: _ReportRange.yearly, child: Text("Yearly")),
                        ],
                        onChanged: (val) {
                          if (val != null) _updateRange(val);
                        },
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Content
            Expanded(
              child: _isLoading 
                ? const Center(child: CircularProgressIndicator())
                : SingleChildScrollView(
                  padding: EdgeInsets.all(mobile ? 16 : 32),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // KPI Grid
                      _buildKpiGrid(_reportData, mobile),
                      SizedBox(height: mobile ? 16 : 32),
                      
                      // Financials
                      Text("Financial Overview", style: AppTheme.heading2),
                      const SizedBox(height: 12),
                      _buildFinancialGrid(_reportData, mobile),
                      SizedBox(height: mobile ? 16 : 32),

                      // Business Insights
                      Text("Business Insights", style: AppTheme.heading2),
                      const SizedBox(height: 12),
                      _buildBusinessInsights(mobile),
                      SizedBox(height: mobile ? 16 : 32),

                      // Charts (Hidden for Today)
                      if (_selectedRange != _ReportRange.today) ...[
                        Text("Performance Analytics", style: AppTheme.heading2),
                        const SizedBox(height: 12),
                        if (mobile) ...[
                           _buildServiceChart(),
                           const SizedBox(height: 16),
                           _buildFinancialChart(),
                           const SizedBox(height: 16),
                           _buildTopCustomers(),
                        ] else 
                          Wrap(
                            spacing: 24,
                            runSpacing: 24,
                            children: [
                              SizedBox(width: 500, child: _buildServiceChart()),
                              SizedBox(width: 500, child: _buildFinancialChart()),
                              SizedBox(width: 500, child: _buildTopCustomers()),
                            ],
                          ),
                      ],
                    ],
                  ),
                ),
            ),
          ],
        ),
      ),
    );
  }

  void _updateRange(_ReportRange range) {
    setState(() {
      _selectedRange = range;
    });
    _fetchReportData();
  }

  Widget _buildKpiGrid(_ReportData report, bool mobile) {
    return LayoutBuilder(
      builder: (context, constraints) {
        int crossAxisCount = 4;
        if (constraints.maxWidth < 1200) crossAxisCount = 2;
        if (mobile) crossAxisCount = 2; 
        
        final gap = mobile ? 12.0 : 24.0;
        final totalGap = gap * (crossAxisCount - 1);
        final width = (constraints.maxWidth - totalGap) / crossAxisCount;

        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: [
            _KpiCard(
              title: 'Total Jobs',
              value: report.totalJobs.toString(),
              icon: Icons.work_outline,
              color: AppTheme.primary,
              width: width,
            ),
            _KpiCard(
              title: 'Installations',
              value: report.installations.toString(),
              icon: Icons.construction,
              color: AppTheme.success,
              width: width,
            ),
            _KpiCard(
              title: 'Maintenance',
              value: report.maintenance.toString(),
              icon: Icons.cleaning_services,
              color: Colors.teal,
              width: width,
            ),
            _KpiCard(
              title: 'Repairs',
              value: report.repairs.toString(),
              icon: Icons.build_circle_outlined,
              color: AppTheme.warning,
              width: width,
            ),
          ],
        );
      },
    );
  }

  Widget _buildFinancialGrid(_ReportData report, bool mobile) {
    return LayoutBuilder(
      builder: (context, constraints) {
        int crossAxisCount = 3;
        if (constraints.maxWidth < 900) crossAxisCount = 1;
        if (mobile) crossAxisCount = 1;
        
        final gap = mobile ? 12.0 : 24.0;
        final width = crossAxisCount == 1 ? constraints.maxWidth : (constraints.maxWidth - (gap * 2)) / 3;

        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: [
            _FinancialCard(
              label: 'Total Revenue',
              amount: report.totalPaymentsFormatted,
              subtext: 'Verified Payments',
              width: width,
              color: AppTheme.success,
              icon: Icons.arrow_upward,
            ),
            _FinancialCard(
              label: 'Total Expenses',
              amount: report.totalExpensesFormatted,
              subtext: 'Recorded Expenses',
              width: width,
              color: AppTheme.error,
              icon: Icons.arrow_downward,
            ),
            _FinancialCard(
              label: 'Net Income',
              amount: report.netCashFormatted,
              subtext: 'Revenue - Expenses',
              width: width,
              color: AppTheme.primary,
              icon: Icons.account_balance_wallet,
            ),
          ],
        );
      },
    );
  }

  Widget _buildBusinessInsights(bool mobile) {
    return LayoutBuilder(
      builder: (context, constraints) {
        int crossAxisCount = 4;
        if (constraints.maxWidth < 1200) crossAxisCount = 2;
        if (mobile) crossAxisCount = 2;

        final gap = mobile ? 12.0 : 24.0;
        final totalGap = gap * (crossAxisCount - 1);
        final width = (constraints.maxWidth - totalGap) / crossAxisCount;

        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: [
             _InsightCard(
               title: 'Avg. Job Value',
               value: _reportData.avgJobValue,
               icon: Icons.attach_money,
               color: Colors.indigo,
               width: width,
             ),
             _InsightCard(
               title: 'Completion Rate',
               value: _reportData.completionRate,
               icon: Icons.check_circle_outline,
               color: Colors.green,
               width: width,
             ),
             _InsightCard(
               title: 'Top Service',
               value: _reportData.topService,
               icon: Icons.star_outline,
               color: Colors.orange,
               width: width,
             ),
             _InsightCard(
               title: 'Busiest Day',
               value: _reportData.busiestDay,
               icon: Icons.calendar_today,
               color: Colors.purple,
               width: width,
             ),
          ],
        );
      },
    );
  }

  Widget _buildServiceChart() {
    return _ChartContainer(
      title: 'Service Trends',
      child: _serviceChartData.isEmpty 
        ? const Center(child: Text("No data"))
        : _BusinessBarChart(
            data: _serviceChartData.map((d) => _BarGroup(
              label: d.label,
              values: [
                _BarValue(d.installations.toDouble(), AppTheme.primary),
                _BarValue(d.maintenance.toDouble(), AppTheme.success),
                _BarValue(d.repairs.toDouble(), AppTheme.warning),
              ]
            )).toList(),
          ),
    );
  }

  Widget _buildFinancialChart() {
    return _ChartContainer(
      title: 'Income vs Expenses',
      child: _financialChartData.isEmpty 
        ? const Center(child: Text("No data"))
        : _BusinessBarChart(
            data: _financialChartData.map((d) => _BarGroup(
              label: d.label,
              values: [
                _BarValue(d.income, AppTheme.success),
                _BarValue(d.expense, AppTheme.error),
              ]
            )).toList(),
          ),
    );
  }

  Widget _buildTopCustomers() {
    return _ChartContainer(
      title: 'Top Customers (by Volume)',
      child: _topCustomers.isEmpty
        ? const Center(child: Text("No data"))
        : Column(
            children: _topCustomers.map((c) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 16,
                    backgroundColor: AppTheme.primary.withOpacity(0.1),
                    child: Text(c.name[0].toUpperCase(), style: const TextStyle(fontSize: 12, color: AppTheme.primary, fontWeight: FontWeight.bold)),
                  ),
                  const SizedBox(width: 12),
                  Expanded(child: Text(c.name, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13))),
                  Text('${c.jobCount} Jobs', style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
                ],
              ),
            )).toList(),
          ),
    );
  }
}

// --- Reusable Widgets ---

class _ChartContainer extends StatelessWidget {
  final String title;
  final Widget child;
  const _ChartContainer({required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: AppTheme.cardDecoration,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: AppTheme.heading3),
          const SizedBox(height: 24),
          SizedBox(height: 250, child: child), 
        ],
      ),
    );
  }
}

class _KpiCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color color;
  final double width;

  const _KpiCard({
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
    required this.width,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      padding: const EdgeInsets.all(16),
      decoration: AppTheme.cardDecoration.copyWith(
        boxShadow: AppTheme.glow(color), // Add glow based on card color
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
                child: Icon(icon, size: 20, color: color),
              ),
            ],
          ),
          const SizedBox(height: 16),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(value, style: AppTheme.heading1),
          ),
          const SizedBox(height: 4),
          Text(title, style: AppTheme.caption),
        ],
      ),
    );
  }
}

class _FinancialCard extends StatelessWidget {
  final String label;
  final String amount;
  final String subtext;
  final double width;
  final Color color;
  final IconData icon;

  const _FinancialCard({
    required this.label,
    required this.amount,
    required this.subtext,
    required this.width,
    required this.color,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      padding: const EdgeInsets.all(20),
      decoration: AppTheme.cardDecoration,
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: AppTheme.caption.copyWith(fontWeight: FontWeight.w600)),
                const SizedBox(height: 4),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(amount, style: AppTheme.heading2),
                ),
                const SizedBox(height: 2),
                Text(subtext, style: TextStyle(fontSize: 11, color: color.withOpacity(0.8), fontWeight: FontWeight.w500)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _InsightCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color color;
  final double width;

  const _InsightCard({
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
    required this.width,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.1)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 28),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(value, style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: color)),
                ),
                Text(title, style: TextStyle(fontSize: 12, color: color.withOpacity(0.8), fontWeight: FontWeight.w600)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// --- Improved Business Chart ---

class _BusinessBarChart extends StatelessWidget {
  final List<_BarGroup> data;
  const _BusinessBarChart({required this.data});

  @override
  Widget build(BuildContext context) {
    if (data.isEmpty) return const SizedBox();

    double maxVal = 0;
    for (var group in data) {
      for (var val in group.values) {
        if (val.value > maxVal) maxVal = val.value;
      }
    }
    if (maxVal == 0) maxVal = 1;

    // Grid lines count
    const int gridLines = 5;

    return LayoutBuilder(
      builder: (context, constraints) {
        final double height = constraints.maxHeight;
        // Use a fixed height for labels to ensure they don't overflow
        const double labelHeight = 24.0;
        
        return Column(
          children: [
            // Chart Area
            Expanded(
              child: Stack(
                children: [
                  // Grid Lines & Y-Axis Labels
                  Column(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: List.generate(gridLines + 1, (index) {
                      final double value = maxVal - (maxVal * (index / gridLines));
                      return Row(
                        children: [
                          SizedBox(
                            width: 40,
                            child: Text(
                              value >= 1000 ? '${(value/1000).toStringAsFixed(1)}k' : value.toStringAsFixed(0),
                              style: const TextStyle(fontSize: 10, color: AppTheme.textSecondary),
                              textAlign: TextAlign.right,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(child: Container(height: 1, color: AppTheme.borderColor.withOpacity(0.5))),
                        ],
                      );
                    }),
                  ),
                  
                  // Bars
                  Padding(
                    padding: const EdgeInsets.only(left: 48, top: 8), // Align with grid
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: data.map((group) {
                        return Expanded(
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: group.values.map((val) {
                              // Calculate height relative to the chart area
                              // Ensure we don't divide by zero or get negative
                              final double relativeHeight = (val.value / maxVal);
                              return Flexible(
                                child: FractionallySizedBox(
                                  heightFactor: relativeHeight == 0 ? 0.01 : relativeHeight, 
                                  child: Container(
                                    width: 16, // Wider bars
                                    margin: const EdgeInsets.symmetric(horizontal: 2),
                                    decoration: BoxDecoration(
                                      color: val.color,
                                      borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
                                    ),
                                  ),
                                ),
                              );
                            }).toList(),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ],
              ),
            ),
            
            // Labels Area
            SizedBox(
              height: labelHeight,
              child: Padding(
                padding: const EdgeInsets.only(left: 48),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: data.map((group) {
                    return Expanded(
                      child: Center(
                        child: Text(
                          group.label,
                          style: const TextStyle(fontSize: 10, color: AppTheme.textSecondary, fontWeight: FontWeight.w500),
                          textAlign: TextAlign.center,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _BarGroup {
  final String label;
  final List<_BarValue> values;
  _BarGroup({required this.label, required this.values});
}

class _BarValue {
  final double value;
  final Color color;
  _BarValue(this.value, this.color);
}

// --- Data Models ---

class _ReportData {
  final int totalJobs;
  final int installations;
  final int maintenance;
  final int repairs;
  final int completedJobs;
  final double totalPayments;
  final double totalExpenses;
  final String topService;
  final String busiestDay;

  const _ReportData({
    required this.totalJobs,
    required this.installations,
    required this.maintenance,
    required this.repairs,
    required this.completedJobs,
    required this.totalPayments,
    required this.totalExpenses,
    required this.topService,
    required this.busiestDay,
  });

  factory _ReportData.empty() {
    return const _ReportData(
      totalJobs: 0,
      installations: 0,
      maintenance: 0,
      repairs: 0,
      completedJobs: 0,
      totalPayments: 0,
      totalExpenses: 0,
      topService: 'N/A',
      busiestDay: 'N/A',
    );
  }

  double get netCash => totalPayments - totalExpenses;
  String get totalPaymentsFormatted => '₱${totalPayments.toStringAsFixed(2)}';
  String get totalExpensesFormatted => '₱${totalExpenses.toStringAsFixed(2)}';
  String get netCashFormatted => '₱${netCash.toStringAsFixed(2)}';
  
  String get avgJobValue {
    if (totalJobs == 0) return '₱0.00';
    return '₱${(totalPayments / totalJobs).toStringAsFixed(2)}';
  }

  String get completionRate {
    if (totalJobs == 0) return '0%';
    return '${((completedJobs / totalJobs) * 100).toStringAsFixed(0)}%';
  }
}

class _ChartDataPoint {
  final String label;
  int installations;
  int maintenance;
  int repairs;

  _ChartDataPoint({
    required this.label,
    required this.installations,
    required this.maintenance,
    required this.repairs,
  });
}

class _FinancialChartPoint {
  final String label;
  double income;
  double expense;

  _FinancialChartPoint({required this.label, required this.income, required this.expense});
}

class _CustomerChartPoint {
  final String label;
  final int count;

  _CustomerChartPoint({required this.label, required this.count});
}

class _TopCustomer {
  final String name;
  int jobCount;
  _TopCustomer({required this.name, required this.jobCount});
}