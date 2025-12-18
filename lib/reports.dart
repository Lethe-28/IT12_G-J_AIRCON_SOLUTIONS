import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart' hide TextDirection;
import 'ui_app_shell.dart';
import 'theme/app_theme.dart';
import 'shared/widgets.dart'
    show AnimatedCard, HoverCard, AnimatedButton, isMobile;

// --- Main Screen ---

class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key});

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

enum _ReportRange { today, weekly, monthly, last6Months, yearly }

class _TimeBucket {
  final String label;
  final DateTime start;
  final DateTime end;

  const _TimeBucket({
    required this.label,
    required this.start,
    required this.end,
  });

  bool contains(DateTime date) => !date.isBefore(start) && date.isBefore(end);
}

class _PeriodDetail {
  final String period;
  final double value;
  final int? count;

  _PeriodDetail({required this.period, required this.value, this.count});
}

class _ServiceDetail {
  final String name;
  final int count;

  _ServiceDetail({required this.name, required this.count});
}

class _ReportsScreenState extends State<ReportsScreen> {
  _ReportRange _selectedRange = _ReportRange.today;

  bool _isLoading = false;
  _ReportData _reportData = _ReportData.empty();
  List<_ChartDataPoint> _serviceChartData = [];
  List<_FinancialChartPoint> _financialChartData = [];
  List<_TopCustomer> _topCustomers = [];
  List<_PeriodDetail> _jobValueDetails = [];
  List<_PeriodDetail> _completionRateDetails = [];
  List<_ServiceDetail> _serviceDetails = [];
  Map<String, int> _dayCountsMap = {};

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

      // Calculate Previous Period
      DateTime prevStartDate;
      DateTime prevEndDate;

      switch (_selectedRange) {
        case _ReportRange.today:
          prevStartDate = startDate.subtract(const Duration(days: 1));
          prevEndDate = startDate.subtract(const Duration(milliseconds: 1));
          break;
        case _ReportRange.weekly:
          prevStartDate = startDate.subtract(const Duration(days: 7));
          prevEndDate = startDate.subtract(const Duration(milliseconds: 1));
          break;
        case _ReportRange.monthly:
          prevStartDate = DateTime(startDate.year, startDate.month - 1, 1);
          prevEndDate = startDate.subtract(const Duration(milliseconds: 1));
          break;
        case _ReportRange.last6Months:
          prevStartDate = DateTime(startDate.year, startDate.month - 6, 1);
          prevEndDate = startDate.subtract(const Duration(milliseconds: 1));
          break;
        case _ReportRange.yearly:
          prevStartDate = DateTime(startDate.year - 1, 1, 1);
          prevEndDate = startDate.subtract(const Duration(milliseconds: 1));
          break;
      }

      final buckets = _buildBuckets(startDate, endDate, now);

      final startStr = startDate.toUtc().toIso8601String();
      final endStr = endDate.toUtc().toIso8601String();
      final prevStartStr = prevStartDate.toUtc().toIso8601String();
      final prevEndStr = prevEndDate.toUtc().toIso8601String();

      // For DATE columns (expenses, payments), we need YYYY-MM-DD
      final startDateOnly = startDate.toString().split(' ')[0];
      final endDateOnly = endDate.toString().split(' ')[0];
      final prevStartDateOnly = prevStartDate.toString().split(' ')[0];
      final prevEndDateOnly = prevEndDate.toString().split(' ')[0];

      // 1. Fetch Job Orders with payments
      final jobsResponse = await supabase
          .from('job_orders')
          .select(
            'id, status, date_scheduled, customer_id, customers(company_name, first_name, last_name), job_types(job_type_name), payments(amount, status)',
          )
          .gte('date_scheduled', startStr)
          .lte('date_scheduled', endStr);

      // Fetch Previous Job Orders for comparison
      final prevJobsResponse = await supabase
          .from('job_orders')
          .select('id, job_types(job_type_name)')
          .gte('date_scheduled', prevStartStr)
          .lte('date_scheduled', prevEndStr);

      // 2. Fetch Payments
      final paymentsResponse = await supabase
          .from('payments')
          .select('amount, payment_date')
          .eq('status', 'Verified')
          .gte('payment_date', startDateOnly)
          .lte('payment_date', endDateOnly);

      // 3. Fetch Expenses (and Income Records)
      final expensesResponse = await supabase
          .from('expenses')
          .select('amount, date, is_income, expense_type')
          .gte('date', startDateOnly)
          .lte('date', endDateOnly);

      // --- Process Previous Data ---
      int prevTotalJobs = prevJobsResponse.length;
      int prevInstallations = 0;
      int prevMaintenance = 0;
      int prevRepairs = 0;

      for (var job in prevJobsResponse) {
        final typeName = (job['job_types']?['job_type_name'] ?? 'Unknown')
            .toString()
            .toLowerCase();
        if (typeName.contains('install'))
          prevInstallations++;
        else if (typeName.contains('maintenance') || typeName.contains('clean'))
          prevMaintenance++;
        else if (typeName.contains('repair'))
          prevRepairs++;
      }

      // --- Process Current Data ---
      int totalJobs = jobsResponse.length;
      int installations = 0;
      int maintenance = 0;
      int repairs = 0;
      int completedJobs = 0;

      Map<String, _ChartDataPoint> serviceMap = {
        for (final bucket in buckets)
          bucket.label: _ChartDataPoint(
            label: bucket.label,
            installations: 0,
            maintenance: 0,
            repairs: 0,
          ),
      };
      Map<String, _FinancialChartPoint> financialMap = {
        for (final bucket in buckets)
          bucket.label: _FinancialChartPoint(
            label: bucket.label,
            income: 0,
            expense: 0,
          ),
      };
      Map<int, _TopCustomer> customerAggMap = {};

      Map<String, int> jobTypeCounts = {};
      Map<String, List<double>> jobValuesByPeriod = {};
      Map<String, int> completedJobsByPeriod = {};
      Map<String, int> totalJobsByPeriod = {};
      Map<String, int> metricCounts = {}; // For busiest day/week/month logic

      // Initialize period maps
      for (final bucket in buckets) {
        jobValuesByPeriod[bucket.label] = [];
        completedJobsByPeriod[bucket.label] = 0;
        totalJobsByPeriod[bucket.label] = 0;
      }

      for (var job in jobsResponse) {
        final typeName = (job['job_types']?['job_type_name'] ?? 'Unknown')
            .toString();
        final typeKey = typeName.toLowerCase();
        final status = (job['status'] ?? '').toString().toLowerCase();
        final date = DateTime.parse(job['date_scheduled']).toLocal();

        if (status == 'completed') completedJobs++;

        // Categorize
        if (typeKey.contains('install'))
          installations++;
        else if (typeKey.contains('maintenance') || typeKey.contains('clean'))
          maintenance++;
        else if (typeKey.contains('repair'))
          repairs++;

        // Top Service Logic
        jobTypeCounts[typeName] = (jobTypeCounts[typeName] ?? 0) + 1;

        // Busiest Metric Logic (Context-aware)
        String key = '';
        switch (_selectedRange) {
          case _ReportRange.today:
            final hour = date.hour;
            if (hour >= 5 && hour < 12)
              key = 'Morning';
            else if (hour >= 12 && hour < 17)
              key = 'Afternoon';
            else if (hour >= 17 && hour < 21)
              key = 'Evening';
            else
              key = 'Night';
            break;
          case _ReportRange.weekly:
            key = DateFormat('EEEE').format(date);
            break;
          case _ReportRange.monthly:
            final firstDay = DateTime(date.year, date.month, 1);
            final weekNum = ((date.day + firstDay.weekday - 2) / 7).floor() + 1;
            key = 'Week $weekNum';
            break;
          case _ReportRange.last6Months:
          case _ReportRange.yearly:
            key = DateFormat('MMMM').format(date);
            break;
        }
        if (key.isNotEmpty) {
          metricCounts[key] = (metricCounts[key] ?? 0) + 1;
        }

        // Period-based stats (for charts and modals)
        final bucketLabel = _bucketLabelFor(date, buckets);
        if (bucketLabel != null) {
          if (typeKey.contains('install'))
            serviceMap[bucketLabel]!.installations++;
          else if (typeKey.contains('maintenance') || typeKey.contains('clean'))
            serviceMap[bucketLabel]!.maintenance++;
          else if (typeKey.contains('repair'))
            serviceMap[bucketLabel]!.repairs++;

          totalJobsByPeriod[bucketLabel] =
              (totalJobsByPeriod[bucketLabel] ?? 0) + 1;

          double jobValue = 0;
          if (job['payments'] != null && (job['payments'] as List).isNotEmpty) {
            for (var payment in (job['payments'] as List)) {
              if ((payment['status'] ?? '').toString().toLowerCase() ==
                  'verified') {
                jobValue += ((payment['amount'] as num?) ?? 0).toDouble();
              }
            }
          }
          jobValuesByPeriod[bucketLabel]!.add(jobValue);

          if (status == 'completed') {
            completedJobsByPeriod[bucketLabel] =
                (completedJobsByPeriod[bucketLabel] ?? 0) + 1;
          }
        }

        // Top Customers Logic
        if (job['customer_id'] != null && job['customers'] != null) {
          final cid = job['customer_id'] as int;
          final cData = job['customers'];
          final name =
              cData['company_name'] ??
              '${cData['first_name']} ${cData['last_name']}';

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

      // Determine Busiest Metric
      String busiestLabel = 'N/A';
      int maxMetricCount = 0;
      metricCounts.forEach((key, value) {
        if (value > maxMetricCount) {
          maxMetricCount = value;
          busiestLabel = key;
        }
      });

      String busiestDisplay = busiestLabel == 'N/A'
          ? 'N/A'
          : '$busiestLabel ($maxMetricCount)';
      String busiestTitle = '';
      switch (_selectedRange) {
        case _ReportRange.today:
          busiestTitle = 'Busiest Time';
          break;
        case _ReportRange.weekly:
          busiestTitle = 'Busiest Day';
          break;
        case _ReportRange.monthly:
          busiestTitle = 'Busiest Week';
          break;
        default:
          busiestTitle = 'Busiest Month';
          break;
      }

      double totalPayments = 0;
      for (var p in paymentsResponse) {
        final amount = (p['amount'] as num).toDouble();
        totalPayments += amount;
        final date = DateTime.parse(p['payment_date']).toLocal();
        final bucketLabel = _bucketLabelFor(date, buckets);
        if (bucketLabel != null) {
          financialMap[bucketLabel]!.income += amount;
        }
      }

      double totalExpenses = 0;
      for (var e in expensesResponse) {
        final amount = (e['amount'] as num).toDouble();
        final isIncome = e['is_income'] == true;
        final expenseType = e['expense_type'];
        final date = DateTime.parse(e['date']).toLocal();
        final bucketLabel = _bucketLabelFor(date, buckets);

        if (isIncome) {
          // --- STRICT REVENUE LOGIC ---
          // Only count actual business earnings (Scrap, Refunds, etc.)
          // EXCLUDE: 'Added Funds' (Owner's Money), 'Capital' (Investment), 'Personal'
          const excludedIncomeTypes = ['Added Funds', 'Capital', 'Personal'];

          if (!excludedIncomeTypes.contains(expenseType)) {
            totalPayments += amount;
            if (bucketLabel != null) {
              financialMap[bucketLabel]!.income += amount;
            }
          }
        } else {
          // --- STRICT EXPENSE LOGIC ---
          // Only count Business/Operational Expenses
          // EXCLUDE: 'Personal' (Owner Withdrawals)
          if (expenseType != 'Personal') {
            totalExpenses += amount;
            if (bucketLabel != null) {
              financialMap[bucketLabel]!.expense += amount;
            }
          }
        }
      }

      _serviceChartData = buckets.map((b) => serviceMap[b.label]!).toList();
      _financialChartData = buckets.map((b) => financialMap[b.label]!).toList();

      _topCustomers = customerAggMap.values.toList()
        ..sort((a, b) => b.jobCount.compareTo(a.jobCount));
      if (_topCustomers.length > 5) _topCustomers = _topCustomers.sublist(0, 5);

      // Build detailed breakdown lists
      _jobValueDetails = [];
      _completionRateDetails = [];
      for (final bucket in buckets) {
        final label = bucket.label;
        double avgValue = 0;
        if (jobValuesByPeriod[label]!.isNotEmpty) {
          avgValue =
              jobValuesByPeriod[label]!.reduce((a, b) => a + b) /
              jobValuesByPeriod[label]!.length;
        }
        _jobValueDetails.add(
          _PeriodDetail(
            period: label,
            value: avgValue,
            count: totalJobsByPeriod[label],
          ),
        );

        double completionRate = 0;
        if ((totalJobsByPeriod[label] ?? 0) > 0) {
          completionRate =
              ((completedJobsByPeriod[label] ?? 0) /
                  (totalJobsByPeriod[label]!)) *
              100;
        }
        _completionRateDetails.add(
          _PeriodDetail(
            period: label,
            value: completionRate,
            count: completedJobsByPeriod[label],
          ),
        );
      }

      _jobValueDetails.sort((a, b) => b.value.compareTo(a.value));
      _completionRateDetails.sort((a, b) => b.value.compareTo(a.value));

      _serviceDetails =
          jobTypeCounts.entries
              .map((e) => _ServiceDetail(name: e.key, count: e.value))
              .toList()
            ..sort((a, b) => b.count.compareTo(a.count));

      _dayCountsMap =
          metricCounts; // Note: using metricCounts as fallback for day details if needed

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
            busiestDay: busiestDisplay,
            busiestTitle: busiestTitle,
            prevTotalJobs: prevTotalJobs,
            prevInstallations: prevInstallations,
            prevMaintenance: prevMaintenance,
            prevRepairs: prevRepairs,
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
      actions: mobile
          ? [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 4,
                ),
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
                    icon: const Icon(
                      Icons.keyboard_arrow_down,
                      color: AppTheme.textSecondary,
                    ),
                    style: AppTheme.body.copyWith(fontWeight: FontWeight.w600),
                    items: const [
                      DropdownMenuItem(
                        value: _ReportRange.today,
                        child: Text("Today"),
                      ),
                      DropdownMenuItem(
                        value: _ReportRange.weekly,
                        child: Text("Weekly"),
                      ),
                      DropdownMenuItem(
                        value: _ReportRange.monthly,
                        child: Text("Monthly"),
                      ),
                      DropdownMenuItem(
                        value: _ReportRange.last6Months,
                        child: Text("Last 6 Months"),
                      ),
                      DropdownMenuItem(
                        value: _ReportRange.yearly,
                        child: Text("Yearly"),
                      ),
                    ],
                    onChanged: (val) {
                      if (val != null) _updateRange(val);
                    },
                  ),
                ),
              ),
            ]
          : null,
      body: Container(
        color: AppTheme.background,
        child: Column(
          children: [
            // Header (Desktop Only for Dropdown)
            if (!mobile)
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 19,
                ),
                decoration: const BoxDecoration(
                  color: AppTheme.surface,
                  border: Border(
                    bottom: BorderSide(color: AppTheme.borderColor),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: AppTheme.background,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: AppTheme.borderColor),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<_ReportRange>(
                          value: _selectedRange,
                          isDense: true,
                          icon: const Icon(
                            Icons.keyboard_arrow_down,
                            color: AppTheme.textSecondary,
                          ),
                          style: AppTheme.body.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                          items: const [
                            DropdownMenuItem(
                              value: _ReportRange.today,
                              child: Text("Today"),
                            ),
                            DropdownMenuItem(
                              value: _ReportRange.weekly,
                              child: Text("Weekly"),
                            ),
                            DropdownMenuItem(
                              value: _ReportRange.monthly,
                              child: Text("Monthly"),
                            ),
                            DropdownMenuItem(
                              value: _ReportRange.last6Months,
                              child: Text("Last 6 Months"),
                            ),
                            DropdownMenuItem(
                              value: _ReportRange.yearly,
                              child: Text("Yearly"),
                            ),
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

                          // Business Insights
                          Text("Business Insights", style: AppTheme.heading2),
                          const SizedBox(height: 12),
                          _buildBusinessInsights(_reportData, mobile),
                          SizedBox(height: mobile ? 16 : 32),

                          // Charts (Moved to Top)
                          if (_selectedRange != _ReportRange.today) ...[
                            Text(
                              "Performance Analytics",
                              style: AppTheme.heading2,
                            ),
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
                                  IntrinsicHeight(
                                    // Ensure equal height for row items
                                    child: Row(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.stretch,
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

  List<_TimeBucket> _buildBuckets(
    DateTime startDate,
    DateTime endDate,
    DateTime now,
  ) {
    switch (_selectedRange) {
      case _ReportRange.today:
        // Today in 3-hour blocks for more detail
        final start = DateTime(now.year, now.month, now.day);
        return List.generate(8, (i) {
          final blockStart = start.add(Duration(hours: i * 3));
          final blockEnd = start.add(Duration(hours: (i + 1) * 3));
          return _TimeBucket(
            label: DateFormat('h a').format(blockStart),
            start: blockStart,
            end: blockEnd,
          );
        });
      case _ReportRange.weekly:
        final monday = DateTime(startDate.year, startDate.month, startDate.day);
        return List.generate(7, (i) {
          final dayStart = monday.add(Duration(days: i));
          final dayEnd = dayStart.add(const Duration(days: 1));
          return _TimeBucket(
            label: DateFormat('EEE').format(dayStart),
            start: dayStart,
            end: dayEnd,
          );
        });
      case _ReportRange.monthly:
        final buckets = <_TimeBucket>[];
        DateTime cursor = DateTime(
          startDate.year,
          startDate.month,
          startDate.day,
        );
        final monthEnd = DateTime(startDate.year, startDate.month + 1, 1);
        int week = 1;
        while (cursor.isBefore(monthEnd)) {
          final next = cursor.add(const Duration(days: 7));
          final bucketEnd = next.isAfter(monthEnd) ? monthEnd : next;
          buckets.add(
            _TimeBucket(label: 'Week $week', start: cursor, end: bucketEnd),
          );
          cursor = bucketEnd;
          week++;
        }
        return buckets;
      case _ReportRange.last6Months:
        final buckets = <_TimeBucket>[];
        for (int i = 0; i < 6; i++) {
          final monthStart = DateTime(startDate.year, startDate.month + i, 1);
          final monthEnd = DateTime(monthStart.year, monthStart.month + 1, 1);
          buckets.add(
            _TimeBucket(
              label: DateFormat('MMM').format(monthStart),
              start: monthStart,
              end: monthEnd,
            ),
          );
        }
        return buckets;
      case _ReportRange.yearly:
        final buckets = <_TimeBucket>[];
        for (int m = 1; m <= 12; m++) {
          final monthStart = DateTime(startDate.year, m, 1);
          final monthEnd = DateTime(startDate.year, m + 1, 1);
          buckets.add(
            _TimeBucket(
              label: DateFormat('MMM').format(monthStart),
              start: monthStart,
              end: monthEnd,
            ),
          );
        }
        return buckets;
    }
  }

  String? _bucketLabelFor(DateTime date, List<_TimeBucket> buckets) {
    for (final bucket in buckets) {
      if (bucket.contains(date)) return bucket.label;
    }
    return null;
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
              comparison: report.getComparisonText(
                report.totalJobs,
                report.prevTotalJobs,
                _selectedRange,
              ),
            ),
            _KpiCard(
              title: 'Installations',
              value: report.installations.toString(),
              icon: Icons.construction,
              color: AppTheme.success,
              width: width,
              comparison: report.getComparisonText(
                report.installations,
                report.prevInstallations,
                _selectedRange,
              ),
            ),
            _KpiCard(
              title: 'Maintenance',
              value: report.maintenance.toString(),
              icon: Icons.cleaning_services,
              color: Colors.teal,
              width: width,
              comparison: report.getComparisonText(
                report.maintenance,
                report.prevMaintenance,
                _selectedRange,
              ),
            ),
            _KpiCard(
              title: 'Repairs',
              value: report.repairs.toString(),
              icon: Icons.build_circle_outlined,
              color: AppTheme.warning,
              width: width,
              comparison: report.getComparisonText(
                report.repairs,
                report.prevRepairs,
                _selectedRange,
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildBusinessInsights(_ReportData data, bool mobile) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final double cardWidth = mobile
            ? double.infinity
            : (constraints.maxWidth - 48) / 4;

        return Wrap(
          spacing: 16,
          runSpacing: 16,
          children: [
            _InsightCardClickable(
              title: "Avg Job Value",
              value: data.avgJobValue,
              icon: Icons.payments_outlined,
              color: const Color(0xFF0EA5E9),
              backgroundColor: const Color(0xFFF0F9FF),
              width: cardWidth,
              onTap: () => _showDetailModal(
                "Average Job Value",
                _jobValueDetails,
                " (Avg)",
              ),
            ),
            _InsightCardClickable(
              title: "Completion Rate",
              value: data.completionRate,
              icon: Icons.assignment_turned_in_outlined,
              color: const Color(0xFF10B981),
              backgroundColor: const Color(0xFFF0FDF4),
              width: cardWidth,
              onTap: () => _showDetailModal(
                "Completion Rate",
                _completionRateDetails,
                "%",
              ),
            ),
            _InsightCardClickable(
              title: "Top Service",
              value: data.topService,
              icon: Icons.star_outline,
              color: const Color(0xFFF59E0B),
              backgroundColor: const Color(0xFFFFFBEB),
              width: cardWidth,
              onTap: () => _showDetailModal(
                "Top Service Breakdown",
                _serviceDetails
                    .map(
                      (e) => _PeriodDetail(
                        period: e.name,
                        value: e.count.toDouble(),
                      ),
                    )
                    .toList(),
                " Jobs",
              ),
            ),
            _InsightCard(
              title: data.busiestTitle,
              value: data.busiestDay,
              icon: Icons.calendar_today_outlined,
              color: const Color(0xFF8B5CF6),
              backgroundColor: const Color(0xFFF5F3FF),
              width: cardWidth,
            ),
          ],
        );
      },
    );
  }

  void _showDetailModal(
    String title,
    List<_PeriodDetail> details,
    String suffix,
  ) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title, style: AppTheme.heading2),
        content: SizedBox(
          width: 400,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: details
                  .map(
                    (d) => Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Row(
                        children: [
                          Text(
                            d.period,
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                          const Spacer(),
                          Text(
                            d.value % 1 == 0
                                ? d.value.toInt().toString()
                                : d.value.toStringAsFixed(1),
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              color: AppTheme.primary,
                            ),
                          ),
                          Text(
                            suffix,
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppTheme.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                  .toList(),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Close"),
          ),
        ],
      ),
    );
  }

  Widget _buildFinancialGrid(_ReportData data, bool mobile) {
    return LayoutBuilder(
      builder: (context, constraints) {
        int crossAxisCount = 3;
        if (constraints.maxWidth < 900 || mobile) crossAxisCount = 1;

        final gap = mobile ? 12.0 : 24.0;
        final totalGap = gap * (crossAxisCount - 1);
        final width = (constraints.maxWidth - totalGap) / crossAxisCount;

        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: [
            _FinancialCard(
              label: "Cash-in",
              amount: data.totalPaymentsFormatted,
              subtext: "Payments Received",
              width: width,
              color: Colors.green,
              icon: Icons.arrow_upward,
            ),
            _FinancialCard(
              label: "Cash-out",
              amount: data.totalExpensesFormatted,
              subtext: "Business Expenses",
              width: width,
              color: Colors.red,
              icon: Icons.arrow_downward,
            ),
            _FinancialCard(
              label: "Net Cash",
              amount: data.netCashFormatted,
              subtext: "Cash-in - Cash-out",
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
              data: _serviceChartData
                  .map(
                    (d) => _ChartPoint(
                      label: d.label,
                      values: [
                        d.installations.toDouble(),
                        d.maintenance.toDouble(),
                        d.repairs.toDouble(),
                      ],
                      colors: [
                        AppTheme.primary,
                        AppTheme.success,
                        AppTheme.warning,
                      ],
                      tooltips: [
                        'Installations: ${d.installations}',
                        'Maintenance: ${d.maintenance}',
                        'Repairs: ${d.repairs}',
                      ],
                    ),
                  )
                  .toList(),
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
      title: 'Cash-in vs Cash-out',
      child: _financialChartData.isEmpty
          ? const Center(child: Text("No data"))
          : _SimpleLineChart(
              data: _financialChartData
                  .map(
                    (d) => _ChartPoint(
                      label: d.label,
                      values: [d.income, d.expense],
                      colors: [Colors.green, Colors.red],
                      tooltips: [
                        'Cash-in: ${NumberFormat.simpleCurrency(name: 'PHP').format(d.income)}',
                        'Cash-out: ${NumberFormat.simpleCurrency(name: 'PHP').format(d.expense)}',
                      ],
                    ),
                  )
                  .toList(),
              legendItems: [
                _LegendItem('Cash-in', Colors.green),
                _LegendItem('Cash-out', Colors.red),
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
                children: _topCustomers
                    .map(
                      (c) => Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: Row(
                          children: [
                            CircleAvatar(
                              radius: 16,
                              backgroundColor: AppTheme.primary.withOpacity(
                                0.1,
                              ),
                              child: Text(
                                c.name[0].toUpperCase(),
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: AppTheme.primary,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                c.name,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 13,
                                ),
                              ),
                            ),
                            Text(
                              '${c.jobCount} Jobs',
                              style: const TextStyle(
                                color: AppTheme.textSecondary,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                    .toList(),
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
  final String? comparison;

  const _KpiCard({
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
    required this.width,
    this.comparison,
  });

  @override
  Widget build(BuildContext context) {
    final bool isNegative = comparison?.contains('-') ?? false;
    final bool isNoData =
        comparison?.toLowerCase().contains('no prev') ?? false;

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
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, size: 20, color: color),
              ),
              if (comparison != null)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: isNoData
                        ? Colors.grey.withOpacity(0.1)
                        : (isNegative
                              ? Colors.red.withOpacity(0.1)
                              : Colors.green.withOpacity(0.1)),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    comparison!,
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: isNoData
                          ? Colors.grey
                          : (isNegative ? Colors.red : Colors.green),
                    ),
                  ),
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

class _InsightCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color color;
  final Color backgroundColor;
  final double width;

  const _InsightCard({
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
    required this.backgroundColor,
    required this.width,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 32),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 12,
                    color: color.withOpacity(0.8),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _InsightCardClickable extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color color;
  final Color backgroundColor;
  final double width;
  final VoidCallback onTap;

  const _InsightCardClickable({
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
    required this.backgroundColor,
    required this.width,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: width,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        decoration: BoxDecoration(
          color: backgroundColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withOpacity(0.3), width: 1.5),
        ),
        child: Row(
          children: [
            Icon(icon, color: color, size: 32),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    value,
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: color,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 12,
                      color: color.withOpacity(0.8),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.info_outline, color: color.withOpacity(0.5), size: 18),
          ],
        ),
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
                Text(
                  label,
                  style: AppTheme.caption.copyWith(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 4),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(amount, style: AppTheme.heading2),
                ),
                const SizedBox(height: 2),
                Text(
                  subtext,
                  style: TextStyle(
                    fontSize: 11,
                    color: color.withOpacity(0.8),
                    fontWeight: FontWeight.w500,
                  ),
                ),
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

  _ChartPoint({
    required this.label,
    required this.values,
    required this.colors,
    required this.tooltips,
  });
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
              final step =
                  width / (widget.data.length > 1 ? widget.data.length - 1 : 1);
              final chartHeight = constraints.maxHeight;

              return Stack(
                clipBehavior: Clip.none,
                children: [
                  GestureDetector(
                    onTapUp: (details) {
                      final renderBox = context.findRenderObject() as RenderBox;
                      final localPos = renderBox.globalToLocal(
                        details.globalPosition,
                      );

                      // Find closest index
                      double dx = localPos.dx - leftPadding;
                      int index = (dx / step).round();

                      if (index < 0) index = 0;
                      if (index >= widget.data.length)
                        index = widget.data.length - 1;

                      // Show Modal instead of floating window
                      showDialog(
                        context: context,
                        builder: (context) => AlertDialog(
                          title: Text(
                            'Details for ${widget.data[index].label}',
                            style: AppTheme.heading2,
                          ),
                          content: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: widget.data[index].tooltips
                                .map(
                                  (t) => Padding(
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 4,
                                    ),
                                    child: Row(
                                      children: [
                                        Container(
                                          width: 10,
                                          height: 10,
                                          decoration: BoxDecoration(
                                            color:
                                                widget.data[index].colors[widget
                                                    .data[index]
                                                    .tooltips
                                                    .indexOf(t)],
                                            shape: BoxShape.circle,
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: Text(
                                            t,
                                            style: const TextStyle(
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                )
                                .toList(),
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(context),
                              child: const Text("Close"),
                            ),
                          ],
                        ),
                      );
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
          children: widget.legendItems
              .map(
                (item) => Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 12,
                      height: 12,
                      decoration: BoxDecoration(
                        color: item.color,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      item.label,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              )
              .toList(),
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

  _LineChartPainter({
    required this.data,
    required this.maxVal,
    this.selectedIndex,
    this.leftPadding = 40.0,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..strokeWidth = 3.0
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final dotPaint = Paint()..style = PaintingStyle.fill;

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

    final textPainter = TextPainter(textDirection: TextDirection.ltr);

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
      } else if (maxVal < 10 && maxVal > 0) {
        labelText = labelValue.toStringAsFixed(1);
      } else {
        labelText = labelValue.toStringAsFixed(0);
      }

      textPainter.text = TextSpan(
        text: labelText,
        style: TextStyle(color: Colors.grey[600], fontSize: 10),
      );
      textPainter.layout();
      textPainter.paint(
        canvas,
        Offset(leftPadding - textPainter.width - 8, y - textPainter.height / 2),
      );
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

        if (i == 0)
          path.moveTo(x, y);
        else
          path.lineTo(x, y);

        // Draw dots
        canvas.drawCircle(Offset(x, y), 4, dotPaint);

        // Draw X-Axis Label (only specific indices to avoid overlapping)
        bool shouldDrawLabel = true;
        if (data.length > 10) {
          int skip = (data.length / 6).ceil();
          shouldDrawLabel =
              (i == 0) || (i == data.length - 1) || (i % skip == 0);
        }

        if (s == 0 && shouldDrawLabel) {
          textPainter.text = TextSpan(
            text: data[i].label,
            style: TextStyle(color: Colors.grey[600], fontSize: 10),
          );
          textPainter.layout();
          textPainter.paint(
            canvas,
            Offset(x - textPainter.width / 2, chartHeight + 8),
          );
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
  final String busiestTitle;

  // Previous Period Data
  final int prevTotalJobs;
  final int prevInstallations;
  final int prevMaintenance;
  final int prevRepairs;

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
    this.busiestTitle = 'Busiest Day',
    this.prevTotalJobs = 0,
    this.prevInstallations = 0,
    this.prevMaintenance = 0,
    this.prevRepairs = 0,
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
      busiestTitle: 'Busiest Day',
      prevTotalJobs: 0,
      prevInstallations: 0,
      prevMaintenance: 0,
      prevRepairs: 0,
    );
  }

  String getComparisonText(int current, int prev, _ReportRange range) {
    if (prev == 0) return 'No prev. data';
    final diff = current - prev;
    final prefix = diff >= 0 ? '+' : '';
    String label = '';
    switch (range) {
      case _ReportRange.today:
        label = 'yesterday';
        break;
      case _ReportRange.weekly:
        label = 'last week';
        break;
      case _ReportRange.monthly:
        label = 'last month';
        break;
      case _ReportRange.last6Months:
        label = 'prev. 6 months';
        break;
      case _ReportRange.yearly:
        label = 'last year';
        break;
    }
    return '$prefix$diff from $label';
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

  _FinancialChartPoint({
    required this.label,
    required this.income,
    required this.expense,
  });
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
