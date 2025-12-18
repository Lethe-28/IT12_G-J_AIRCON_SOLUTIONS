import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/notification_service.dart';

class DashboardProvider extends ChangeNotifier {
  static final DashboardProvider _instance = DashboardProvider._internal();
  factory DashboardProvider() => _instance;
  DashboardProvider._internal();

  // Cache variables
  int _pendingJobsCount = 0;
  int _pendingDocsCount = 0;
  double _totalRevenue = 0.0;
  double _totalExpenses = 0.0;
  List<TodayJobItem> _todayJobs = []; // This list powers the "Schedule" list

  List<AttentionItem> _notificationItems = [];
  List<AttentionItem> _activityItems = [];

  DateTime? _lastFetch;

  // Getters
  int get pendingJobsCount => _pendingJobsCount;
  int get pendingDocsCount => _pendingDocsCount;
  double get totalRevenue => _totalRevenue;
  double get totalExpenses => _totalExpenses;
  List<TodayJobItem> get todayJobs => _todayJobs;
  List<AttentionItem> get notificationItems => _notificationItems;
  List<AttentionItem> get activityItems => _activityItems;
  List<AttentionItem> get attentionItems =>
      _notificationItems; // Legacy support

  // --- MAIN FETCH METHOD ---
  Future<void> fetchDashboardData({String dateRange = 'Monthly'}) async {
    try {
      await Future.wait([
        _fetchPendingJobs(dateRange), // Now Dynamic!
        _fetchScheduledJobs(dateRange), // Renamed from _fetchTodayJobs
        _fetchTotalRevenue(dateRange),
        _fetchTotalExpenses(dateRange),
        _fetchNotifications(),
        _fetchActivityLogs(),
      ]);
      _lastFetch = DateTime.now();
      notifyListeners();
    } catch (e) {
      debugPrint('Error fetching dashboard data: $e');
    }
  }

  // --- HELPER: Date Ranges ---
  // Returns [startDate, endDate] as Strings (YYYY-MM-DD)
  List<String> _getDateRange(String range) {
    final now = DateTime.now();
    DateTime start;
    DateTime end;

    switch (range) {
      case 'Weekly':
        // Start of week (Monday)
        start = now.subtract(Duration(days: now.weekday - 1));
        end = start.add(const Duration(days: 6));
        break;
      case 'Monthly':
        start = DateTime(now.year, now.month, 1);
        end = DateTime(now.year, now.month + 1, 0); // Last day of month
        break;
      case 'Yearly':
        start = DateTime(now.year, 1, 1);
        end = DateTime(now.year, 12, 31);
        break;
      case 'Today':
      default:
        start = now;
        end = now;
        break;
    }

    // Format YYYY-MM-DD
    String fmt(DateTime d) =>
        "${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}";

    return [fmt(start), fmt(end)];
  }

  // --- 1. DYNAMIC PENDING JOBS ---
  Future<void> _fetchPendingJobs(String dateRange) async {
    try {
      final supabase = Supabase.instance.client;
      final range = _getDateRange(dateRange); // [start, end]

      // Logic: Count jobs that are NOT completed/cancelled AND scheduled in this range
      final response = await supabase
          .from('job_orders')
          .select('id')
          .inFilter('status', [
            'Pending',
            'Scheduled',
            'In Progress',
          ]) // Active statuses
          .gte('date_scheduled', "${range[0]}T00:00:00") // Start of range
          .lte('date_scheduled', "${range[1]}T23:59:59"); // End of range

      _pendingJobsCount = response.length;
    } catch (e) {
      debugPrint('Error fetching pending jobs: $e');
      _pendingJobsCount = 0;
    }
  }

  // --- 2. DYNAMIC SCHEDULE LIST ---
  Future<void> _fetchScheduledJobs(String dateRange) async {
    try {
      final supabase = Supabase.instance.client;
      final range = _getDateRange(dateRange);

      final response = await supabase
          .from('job_orders')
          .select(
            '*, customers(first_name, last_name, company_name), job_types(job_type_name)',
          )
          .gte('date_scheduled', "${range[0]}T00:00:00")
          .lte('date_scheduled', "${range[1]}T23:59:59")
          .order('date_scheduled', ascending: true);

      _todayJobs = response.map<TodayJobItem>((row) {
        final customer = row['customers'];
        String clientName = 'Unknown';
        if (customer != null) {
          clientName =
              customer['company_name'] ??
              '${customer['first_name']} ${customer['last_name']}';
        }

        DateTime scheduled = DateTime.parse(row['date_scheduled']).toLocal();
        const months = [
          "Jan",
          "Feb",
          "Mar",
          "Apr",
          "May",
          "Jun",
          "Jul",
          "Aug",
          "Sep",
          "Oct",
          "Nov",
          "Dec",
        ];
        String dateStr = "${months[scheduled.month - 1]} ${scheduled.day}";

        String time =
            '${scheduled.hour == 0 ? 12 : (scheduled.hour > 12 ? scheduled.hour - 12 : scheduled.hour)}:${scheduled.minute.toString().padLeft(2, '0')}';
        time += (scheduled.hour < 12) ? ' AM' : ' PM';

        return TodayJobItem(
          id: row['client_jo_number'] ?? 'JO-${row['id']}',
          client: clientName,
          time: time,
          date: dateStr,
          type: row['job_types']?['job_type_name'] ?? 'Service',
          status: row['status'] ?? 'Pending',
        );
      }).toList();
    } catch (e) {
      debugPrint('Error fetching scheduled jobs: $e');
      _todayJobs = [];
    }
  }

  // --- 3. REVENUE (Strict Logic) ---
  Future<void> _fetchTotalRevenue(String dateRange) async {
    try {
      final supabase = Supabase.instance.client;
      final range = _getDateRange(dateRange);

      // A. Job Payments (Verified)
      final payments = await supabase
          .from('payments')
          .select('amount')
          .eq('status', 'Verified')
          .gte('payment_date', range[0])
          .lte('payment_date', range[1]);

      double total = payments.fold(
        0.0,
        (sum, row) => sum + (row['amount'] ?? 0.0),
      );

      // B. Manual Revenue (Other Income)
      // FIX: Changed 'category' to 'expense_type' to match your DB schema
      final otherIncome = await supabase
          .from('expenses')
          .select('amount')
          .eq('is_income', true)
          // Exclude Owner Money using the correct column name
          .neq('expense_type', 'Added Funds')
          .neq('expense_type', 'Capital')
          .neq('expense_type', 'Personal')
          .gte('date', range[0])
          .lte('date', range[1]);

      total += otherIncome.fold(
        0.0,
        (sum, row) => sum + (row['amount'] ?? 0.0),
      );

      _totalRevenue = total;
    } catch (e) {
      debugPrint('Error fetching revenue: $e');
      _totalRevenue = 0.0;
    }
  }

  // --- 4. EXPENSES (Strict Logic) ---
  Future<void> _fetchTotalExpenses(String dateRange) async {
    try {
      final supabase = Supabase.instance.client;
      final range = _getDateRange(dateRange);

      // Operational Expenses Only (Money Out)
      // FIX: Changed 'category' to 'expense_type' to match your DB schema
      final expenses = await supabase
          .from('expenses')
          .select('amount')
          .neq('is_income', true)
          .neq('expense_type', 'Personal') // Exclude Owner Draw
          .gte('date', range[0])
          .lte('date', range[1]);

      _totalExpenses = expenses.fold(
        0.0,
        (sum, row) => sum + (row['amount'] ?? 0.0),
      );
    } catch (e) {
      debugPrint('Error fetching expenses: $e');
      _totalExpenses = 0.0;
    }
  }

  // --- 1. FETCH NOTIFICATIONS (Action Items / Warnings) ---
  Future<void> _fetchNotifications() async {
    _notificationItems = [];
    final supabase = Supabase.instance.client;
    final now = DateTime.now();
    final threeDaysFromNow = now
        .add(const Duration(days: 3))
        .toUtc()
        .toIso8601String();

    try {
      // A. Pending Payments
      final pendingPayments = await supabase
          .from('payments')
          .select(
            'reference_number, job_order_id, job_orders(client_jo_number)',
          )
          .eq('status', 'Pending')
          .limit(5);

      for (var payment in pendingPayments) {
        final joNum =
            payment['job_orders']?['client_jo_number'] ??
            'JO-${payment['job_order_id']}';
        _notificationItems.add(
          AttentionItem(
            title: 'Payment verification needed',
            reference:
                payment['reference_number'] ?? 'REF-${payment['job_order_id']}',
            priority: 'High',
            color: Colors.orange,
            type: AttentionType.payment,
            relatedId: payment['job_order_id'],
            searchContext: joNum,
          ),
        );
      }

      // B. Overdue Jobs
      final overdueJobs = await supabase
          .from('job_orders')
          .select(
            'id, client_jo_number, date_scheduled, customers(company_name, first_name, last_name), job_types(job_type_name)',
          )
          .neq('status', 'Completed')
          .neq('status', 'Cancelled')
          .lt('date_scheduled', now.toUtc().toIso8601String())
          .order('date_scheduled', ascending: true);

      for (var job in overdueJobs) {
        final customer = job['customers'];
        final customerName =
            customer?['company_name'] ??
            '${customer?['first_name'] ?? ''} ${customer?['last_name'] ?? ''}'
                .trim();
        final serviceType = job['job_types']?['job_type_name'] ?? 'N/A';
        final dateScheduled = DateTime.parse(job['date_scheduled']).toLocal();
        final dateStr =
            '${dateScheduled.month}/${dateScheduled.day}/${dateScheduled.year}';

        _notificationItems.add(
          AttentionItem(
            title: 'Job order overdue',
            reference: job['client_jo_number'] ?? 'JO-${job['id']}',
            priority: 'High',
            color: Colors.red,
            type: AttentionType.scheduling,
            relatedId: job['id'],
            searchContext: job['client_jo_number'],
            customerName: customerName,
            serviceType: serviceType,
            date: dateStr,
          ),
        );
      }

      // C. Upcoming Incomplete Jobs (Pre-emptive)
      final upcomingJobs = await supabase
          .from('job_orders')
          .select(
            'id, client_jo_number, date_scheduled, job_order_technicians(count), job_order_aircons(count), customers(company_name, first_name, last_name), job_types(job_type_name)',
          )
          .neq('status', 'Completed')
          .neq('status', 'Cancelled')
          .gt('date_scheduled', now.toUtc().toIso8601String())
          .lt('date_scheduled', threeDaysFromNow);

      for (var job in upcomingJobs) {
        final techCount = job['job_order_technicians'][0]['count'] as int;
        final unitCount = job['job_order_aircons'][0]['count'] as int;

        if (techCount == 0 || unitCount == 0) {
          final date = DateTime.parse(job['date_scheduled']).toLocal();
          final dateStr = "${date.month}/${date.day}/${date.year}";
          final customer = job['customers'];
          final customerName =
              customer?['company_name'] ??
              '${customer?['first_name'] ?? ''} ${customer?['last_name'] ?? ''}'
                  .trim();
          final serviceType = job['job_types']?['job_type_name'] ?? 'N/A';

          _notificationItems.add(
            AttentionItem(
              title: 'Upcoming Job Incomplete',
              reference: job['client_jo_number'],
              priority: 'Medium',
              color: Colors.amber.shade700,
              type: AttentionType.scheduling,
              relatedId: job['id'],
              searchContext: job['client_jo_number'],
              customerName: customerName,
              serviceType: serviceType,
              date: dateStr,
            ),
          );
        }
      }

      // Notify only if High Priority exists
      if (_notificationItems.any((i) => i.priority == 'High')) {
        final highPriorityItems = _notificationItems
            .where((i) => i.priority == 'High')
            .toList();
        final buffer = StringBuffer();

        // Take up to 3 high priority items to list details
        final itemsToShow = highPriorityItems.take(3).toList();
        for (var item in itemsToShow) {
          buffer.writeln('• ${item.title}: ${item.reference}');
        }

        final remaining = highPriorityItems.length - itemsToShow.length;
        if (remaining > 0) {
          buffer.writeln('... and $remaining more items.');
        }

        NotificationService().showNotification(
          id: 1,
          title: 'Action Required (${highPriorityItems.length})',
          body: buffer.toString().trim(),
        );
      }
    } catch (e) {
      debugPrint("Error fetching notifications: $e");
    }
  }

  // --- 2. FETCH ACTIVITY LOGS (The "History" List) ---
  Future<void> _fetchActivityLogs() async {
    _activityItems = [];
    final supabase = Supabase.instance.client;

    try {
      final logs = await supabase
          .from('activity_logs')
          .select('*')
          .order('created_at', ascending: false)
          .limit(20);

      for (var log in logs) {
        final date = DateTime.parse(log['created_at']).toLocal();
        final now = DateTime.now();
        String timeLabel =
            (date.year == now.year &&
                date.month == now.month &&
                date.day == now.day)
            ? "Today ${date.hour}:${date.minute.toString().padLeft(2, '0')}"
            : "${date.month}/${date.day} ${date.hour}:${date.minute.toString().padLeft(2, '0')}";

        String priority = 'Info';
        Color color = Colors.grey;
        AttentionType type = AttentionType.document;

        switch (log['action_type']) {
          case 'Create':
            color = Colors.blue;
            type = AttentionType.scheduling;
            break;
          case 'Delete':
            color = Colors.red;
            break;
          case 'Update':
            color = Colors.orange;
            break;
          case 'Payment':
            color = Colors.green;
            type = AttentionType.payment;
            break;
          // --- ADD THIS CASE ---
          case 'Expense':
            color = Colors.deepOrange; // Money Out
            type = AttentionType.expense;
            break;
          // ---------------------
        }

        _activityItems.add(
          AttentionItem(
            title: log['details'],
            reference: "${log['user_name']} • $timeLabel",
            priority: priority,
            color: color,
            type: type,
          ),
        );
      }
    } catch (e) {
      debugPrint("Error fetching activity log: $e");
    }
  }

  /// Get pending documents count (from local state since documents aren't in DB yet)
  void updatePendingDocsCount(int count) {
    _pendingDocsCount = count;
    notifyListeners();
  }

  /// Clear a single notification
  void clearNotification(AttentionItem item) {
    _notificationItems.remove(item);
    notifyListeners();
  }

  /// Clear all notifications
  void clearAllNotifications() {
    _notificationItems.clear();
    notifyListeners();
  }
}

// Data models
class TodayJobItem {
  final String id;
  final String client;
  final String time;
  final String date;
  final String type;
  final String status;

  TodayJobItem({
    required this.id,
    required this.client,
    required this.time,
    required this.date,
    required this.type,
    required this.status,
  });
}

enum AttentionType { payment, expense, scheduling, document }

class AttentionItem {
  final String title;
  final String reference;
  final String priority;
  final Color color;
  final AttentionType type;
  final int? relatedId;
  final String? searchContext; // Added searchContext for passing JO#
  final String? customerName;
  final String? serviceType;
  final String? date;

  AttentionItem({
    required this.title,
    required this.reference,
    required this.priority,
    required this.color,
    required this.type,
    this.relatedId,
    this.searchContext,
    this.customerName,
    this.serviceType,
    this.date,
  });
}
