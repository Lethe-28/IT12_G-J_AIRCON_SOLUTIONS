import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart' hide TextDirection;
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
      
      String busiestDayDisplay = busiestDay;
      if (busiestDay != 'N/A') {
         busiestDayDisplay = '$busiestDay ($maxDayCount)';
      }

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
            busiestDay: busiestDayDisplay,
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
      // NEW: Pass dropdown to AppBar explicitly on Mobile
      actions: mobile ? [
         Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            margin: const EdgeInsets.only(right: 8),
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
      ] : null,
      body: Container(
        color: AppTheme.background,
        child: Column(
          children: [
            // Header (Desktop Only for Dropdown)
             if (!mobile)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                decoration: const BoxDecoration(
                  color: AppTheme.surface,
                  border: Border(bottom: BorderSide(color: AppTheme.borderColor)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end, 
                  children: [
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
                      // Kpis
                      _buildKpiGrid(_reportData, mobile),
                      SizedBox(height: mobile ? 16 : 32),
                      
                      // Charts (Moved to Top)
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
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                               IntrinsicHeight( // Ensure equal height for row items
                                 child: Row(
                                   crossAxisAlignment: CrossAxisAlignment.stretch,
                                   children: [
                                     Expanded(
                                       flex: 2,
                                       child: _buildServiceChart(),
                                     ),
                                     const SizedBox(width: 24),
                                     Expanded(
                                       flex: 1,
                                       child: _buildTopCustomers(),
                                     ),
                                   ],
                                 ),
                               ),
                               const SizedBox(height: 24),
                               _buildFinancialChart(),
                            ],
                          ),
                         SizedBox(height: mobile ? 16 : 32),
                      ],

                      // Financials
                      Text("Financial Overview", style: AppTheme.heading2),
                      const SizedBox(height: 12),
                      _buildFinancialGrid(_reportData, mobile),
                      SizedBox(height: mobile ? 16 : 32),
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

  Widget _buildServiceChart() {
    return _ChartContainer(
      title: 'Service Trends',
      child: _serviceChartData.isEmpty 
        ? const Center(child: Text("No data"))
        : _SimpleLineChart(
            data: _serviceChartData.map((d) => _ChartPoint(
              label: d.label,
              values: [d.installations.toDouble(), d.maintenance.toDouble(), d.repairs.toDouble()],
              colors: [AppTheme.primary, AppTheme.success, AppTheme.warning],
              tooltips: ['Installations: ${d.installations}', 'Maintenance: ${d.maintenance}', 'Repairs: ${d.repairs}'],
            )).toList(),
            legendItems: [
              _LegendItem('Installation', AppTheme.primary),
              _LegendItem('Maintenance', AppTheme.success),
              _LegendItem('Repair', AppTheme.warning),
            ],
            leftPadding: 30.0, // Reduced padding for single digits
          ),
    );
  }

  Widget _buildFinancialChart() {
    return _ChartContainer(
      title: 'Income vs Expenses',
      child: _financialChartData.isEmpty 
        ? const Center(child: Text("No data"))
        : _SimpleLineChart(
            data: _financialChartData.map((d) => _ChartPoint(
              label: d.label,
              values: [d.income, d.expense],
              colors: [AppTheme.success, AppTheme.error],
              tooltips: ['Income: ${NumberFormat.simpleCurrency(name: 'PHP').format(d.income)}', 'Expense: ${NumberFormat.simpleCurrency(name: 'PHP').format(d.expense)}'],
            )).toList(),
            legendItems: [
              _LegendItem('Income', AppTheme.success),
              _LegendItem('Expenses', AppTheme.error),
            ],
            leftPadding: 50.0, // Wider padding for currency values
          ),
    );
  }

// ... (omitting Top Customers layout as it doesn't change)

  Widget _buildTopCustomers() {
    return _ChartContainer(
      title: 'Top Customers (by Volume)',
      child: _topCustomers.isEmpty
        ? const Center(child: Text("No data"))
        : SingleChildScrollView(
            child: Column(
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
          SizedBox(height: 300, child: child), 
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
      decoration: AppTheme.cardDecoration, 
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

// --- Simple Line Chart ---

class _ChartPoint {
  final String label;
  final List<double> values;
  final List<Color> colors;
  final List<String> tooltips;

  _ChartPoint({required this.label, required this.values, required this.colors, required this.tooltips});
}

class _SimpleLineChart extends StatefulWidget {
  final List<_ChartPoint> data;
  final List<_LegendItem> legendItems;
  final double leftPadding;
  
  const _SimpleLineChart({
    required this.data, 
    required this.legendItems,
    this.leftPadding = 40.0,
  });

  @override
  State<_SimpleLineChart> createState() => _SimpleLineChartState();
}

class _SimpleLineChartState extends State<_SimpleLineChart> {
  int? _selectedIndex;

  @override
  Widget build(BuildContext context) {
    if (widget.data.isEmpty) return const SizedBox();

    double maxVal = 0;
    for (var point in widget.data) {
      for (var val in point.values) {
        if (val > maxVal) maxVal = val;
      }
    }
    if (maxVal == 0) maxVal = 1;

    return Column(
      children: [
        Expanded(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final double leftPadding = widget.leftPadding; 
              final width = constraints.maxWidth - leftPadding;
              final step = width / (widget.data.length > 1 ? widget.data.length - 1 : 1);
              final chartHeight = constraints.maxHeight;

              return Stack(
                clipBehavior: Clip.none,
                children: [
                  GestureDetector(
                    onTapUp: (details) {
                      final renderBox = context.findRenderObject() as RenderBox;
                      final localPos = renderBox.globalToLocal(details.globalPosition);
                      
                      // Find closest index
                      double dx = localPos.dx - leftPadding;
                      int index = (dx / step).round();
                      
                      if (index < 0) index = 0;
                      if (index >= widget.data.length) index = widget.data.length - 1;

                      setState(() {
                        _selectedIndex = index;
                      });
                    },
                    child: CustomPaint(
                      size: Size(constraints.maxWidth, constraints.maxHeight),
                      painter: _LineChartPainter(
                        data: widget.data,
                        maxVal: maxVal,
                        selectedIndex: _selectedIndex,
                        leftPadding: leftPadding,
                      ),
                    ),
                  ),


                  // Floating Window for Details
                  if (_selectedIndex != null)
                   Positioned(
                     left: (leftPadding + (_selectedIndex! * step)) - 75, // Center box on point
                     top: chartHeight / 2 - 50, // Floating somewhat centrally or near point
                     child: Container(
                        width: 150,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppTheme.surface,
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 10, offset: const Offset(0, 4)),
                          ],
                          border: Border.all(color: AppTheme.borderColor),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(widget.data[_selectedIndex!].label, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                            const SizedBox(height: 8),
                             ...List.generate(widget.data[_selectedIndex!].tooltips.length, (i) {
                                return Padding(
                                  padding: const EdgeInsets.only(bottom: 4),
                                  child: Text(widget.data[_selectedIndex!].tooltips[i], style: const TextStyle(fontSize: 12)),
                                );
                             }),
                          ],
                        ),
                     ),
                   ),
                ],
              );
            },
          ),
        ),
         const SizedBox(height: 16),
         // Legend
         Wrap(
           spacing: 16,
           runSpacing: 8,
           alignment: WrapAlignment.center,
           children: widget.legendItems.map((item) => Row(
             mainAxisSize: MainAxisSize.min,
             children: [
               Container(width: 12, height: 12, decoration: BoxDecoration(color: item.color, shape: BoxShape.circle)),
               const SizedBox(width: 8),
               Text(item.label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
             ],
           )).toList(),
         ),
       ],
     );
  }
}

class _LegendItem {
  final String label;
  final Color color;
  _LegendItem(this.label, this.color);
}

class _LineChartPainter extends CustomPainter {
  final List<_ChartPoint> data;
  final double maxVal;
  final int? selectedIndex;
  final double leftPadding;

  _LineChartPainter({required this.data, required this.maxVal, this.selectedIndex, this.leftPadding = 40.0});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..strokeWidth = 3.0
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final dotPaint = Paint()
      ..style = PaintingStyle.fill;

    // Grid and Axis properties
    const int gridLines = 5;
    const double bottomPadding = 24.0; 
    
    final double chartWidth = size.width - leftPadding;
    final double chartHeight = size.height - bottomPadding;
    
    final double stepX = chartWidth / (data.length > 1 ? data.length - 1 : 1);
    
    // Draw Grid and Y-Axis Labels
    final gridPaint = Paint()
      ..color = Colors.grey.withOpacity(0.2)
      ..strokeWidth = 1.0;

    final textPainter = TextPainter(
      textDirection: TextDirection.ltr,
    );

    for (int i = 0; i <= gridLines; i++) {
        final double normalizedValue = i / gridLines;
        final double y = chartHeight - (chartHeight * normalizedValue);
        
        // Draw horizontal grid line
        canvas.drawLine(Offset(leftPadding, y), Offset(size.width, y), gridPaint);
        
        // Draw Y-Axis Label
        final double labelValue = maxVal * normalizedValue;
        String labelText;
        if (maxVal > 1000) {
           labelText = '${(labelValue / 1000).toStringAsFixed(1)}k';
        } else {
           labelText = labelValue.toStringAsFixed(0);
        }
        
        textPainter.text = TextSpan(
          text: labelText,
          style: TextStyle(color: Colors.grey[600], fontSize: 10),
        );
        textPainter.layout();
        textPainter.paint(canvas, Offset(leftPadding - textPainter.width - 8, y - textPainter.height / 2));
    }

    // Determine number of lines (series) based on first point
    int seriesCount = data.first.values.length;

    for (int s = 0; s < seriesCount; s++) {
       paint.color = data.first.colors[s];
       dotPaint.color = data.first.colors[s];

       final path = Path();
       for (int i = 0; i < data.length; i++) {
         final x = leftPadding + (i * stepX);
         final y = chartHeight - ((data[i].values[s] / maxVal) * chartHeight);
         
         if (i == 0) path.moveTo(x, y);
         else path.lineTo(x, y);

         // Draw dots
         canvas.drawCircle(Offset(x, y), 4, dotPaint);

         // Draw X-Axis Label (only specific indices to avoid overlapping)
         bool shouldDrawLabel = true;
         if (data.length > 6) {
            int skip = (data.length / 5).ceil();
            shouldDrawLabel = (i == 0) || (i == data.length - 1) || (i % skip == 0);
         }

         if (s == 0 && shouldDrawLabel) { 
            textPainter.text = TextSpan(
              text: data[i].label,
              style: TextStyle(color: Colors.grey[600], fontSize: 10),
            );
            textPainter.layout();
            textPainter.paint(canvas, Offset(x - textPainter.width / 2, chartHeight + 8));
         }
       }
       canvas.drawPath(path, paint);
    }

    // Highlight selected index
    if (selectedIndex != null) {
      final x = leftPadding + (selectedIndex! * stepX);
      final linePaint = Paint()
        ..color = Colors.black.withOpacity(0.5)
        ..strokeWidth = 1
        ..style = PaintingStyle.stroke;
      
      canvas.drawLine(Offset(x, 0), Offset(x, chartHeight), linePaint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
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