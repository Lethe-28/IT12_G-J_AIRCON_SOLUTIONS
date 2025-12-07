import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/notification_service.dart';

/// Centralized data provider for dashboard statistics and real-time data
class DashboardProvider extends ChangeNotifier {
  static final DashboardProvider _instance = DashboardProvider._internal();
  factory DashboardProvider() => _instance;
  DashboardProvider._internal();

  // Cache for performance
  int _pendingJobsCount = 0;
  int _pendingDocsCount = 0;
  double _totalRevenue = 0.0;
  double _totalExpenses = 0.0;
  List<TodayJobItem> _todayJobs = [];
  List<AttentionItem> _attentionItems = [];
  DateTime? _lastFetch;

  // Getters
  int get pendingJobsCount => _pendingJobsCount;
  int get pendingDocsCount => _pendingDocsCount;
  double get totalRevenue => _totalRevenue;
  double get totalExpenses => _totalExpenses;
  List<TodayJobItem> get todayJobs => _todayJobs;
  List<AttentionItem> get attentionItems => _attentionItems;

  /// Fetch all dashboard data
  Future<void> fetchDashboardData({String dateRange = 'Today'}) async {
    try {
      await Future.wait([
        _fetchPendingJobs(),
        _fetchTodayJobs(dateRange),
        _fetchTotalRevenue(dateRange),
        _fetchTotalExpenses(dateRange),
        _fetchAttentionItems(),
      ]);
      _lastFetch = DateTime.now();
      notifyListeners();
    } catch (e) {
      debugPrint('Error fetching dashboard data: $e');
    }
  }

  /// Refresh if data is stale (older than 30 seconds)
  Future<void> refreshIfNeeded() async {
    if (_lastFetch == null ||
        DateTime.now().difference(_lastFetch!) > const Duration(seconds: 30)) {
      await fetchDashboardData();
    }
  }

  Future<void> _fetchPendingJobs() async {
    try {
      final supabase = Supabase.instance.client;
      final response = await supabase.from('job_orders').select('id').inFilter(
        'status',
        ['Pending', 'Scheduled', 'In Progress'],
      );

      _pendingJobsCount = response.length;
    } catch (e) {
      debugPrint('Error fetching pending jobs: $e');
      _pendingJobsCount = 0;
    }
  }

  Future<void> _fetchTodayJobs(String dateRange) async {
    try {
      final supabase = Supabase.instance.client;
      final now = DateTime.now();
      DateTime startDate;
      DateTime endDate;

      switch (dateRange) {
        case 'Weekly':
          startDate = now.subtract(Duration(days: now.weekday - 1));
          startDate = DateTime(startDate.year, startDate.month, startDate.day);
          endDate = DateTime(now.year, now.month, now.day, 23, 59, 59);
          break;
        case 'Monthly':
          startDate = DateTime(now.year, now.month, 1);
          endDate = DateTime(now.year, now.month, now.day, 23, 59, 59);
          break;
        case 'Yearly':
          startDate = DateTime(now.year, 1, 1);
          endDate = DateTime(now.year, now.month, now.day, 23, 59, 59);
          break;
        default: // Today
          startDate = DateTime(now.year, now.month, now.day);
          endDate = DateTime(now.year, now.month, now.day, 23, 59, 59);
      }

      final response = await supabase
          .from('job_orders')
          .select(
            '*, customers(first_name, last_name, company_name), job_types(job_type_name)',
          )
          .gte(
            'date_scheduled',
            startDate.toUtc().toIso8601String(),
          ) // Ensure query uses UTC
          .lte('date_scheduled', endDate.toUtc().toIso8601String())
          .order('date_scheduled', ascending: true);

      _todayJobs = response.map<TodayJobItem>((row) {
        final customer = row['customers'];
        String clientName = 'Unknown';
        if (customer != null) {
          if (customer['company_name'] != null &&
              customer['company_name'].toString().isNotEmpty) {
            clientName = customer['company_name'];
          } else {
            clientName = '${customer['first_name']} ${customer['last_name']}';
          }
        }

        // FIX: Convert to Local Time before formatting
        DateTime scheduled = DateTime.parse(row['date_scheduled']).toLocal();

        // --- ADD THIS DATE FORMATTING LOGIC ---
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
        // --------------------------------------

        String time =
            '${scheduled.hour == 0 ? 12 : (scheduled.hour > 12 ? scheduled.hour - 12 : scheduled.hour)}:${scheduled.minute.toString().padLeft(2, '0')}';
        if (scheduled.hour < 12) {
          time += ' AM';
        } else {
          time += ' PM';
        }

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
      debugPrint('Error fetching today jobs: $e');
      _todayJobs = [];
    }
  }

  Future<void> _fetchTotalRevenue(String dateRange) async {
    try {
      final supabase = Supabase.instance.client;
      final now = DateTime.now();
      DateTime? startDate;

      switch (dateRange) {
        case 'Weekly':
          startDate = now.subtract(Duration(days: now.weekday - 1));
          startDate = DateTime(startDate.year, startDate.month, startDate.day);
          break;
        case 'Monthly':
          startDate = DateTime(now.year, now.month, 1);
          break;
        case 'Yearly':
          startDate = DateTime(now.year, 1, 1);
          break;
        case 'Today':
          startDate = DateTime(now.year, now.month, now.day);
          break;
        default:
          startDate = null; // All time
      }

      var query = supabase
          .from('payments')
          .select('amount')
          .eq('status', 'Verified');

      if (startDate != null) {
        query = query.gte('payment_date', startDate.toIso8601String());
      }

      final response = await query;

      _totalRevenue = response.fold<double>(
        0,
        (sum, row) => sum + (row['amount'] ?? 0.0),
      );
    } catch (e) {
      debugPrint('Error fetching total revenue: $e');
      _totalRevenue = 0.0;
    }
  }

  Future<void> _fetchTotalExpenses(String dateRange) async {
    try {
      final supabase = Supabase.instance.client;
      final now = DateTime.now();
      DateTime? startDate;

      switch (dateRange) {
        case 'Weekly':
          startDate = now.subtract(Duration(days: now.weekday - 1));
          startDate = DateTime(startDate.year, startDate.month, startDate.day);
          break;
        case 'Monthly':
          startDate = DateTime(now.year, now.month, 1);
          break;
        case 'Yearly':
          startDate = DateTime(now.year, 1, 1);
          break;
        case 'Today':
          startDate = DateTime(now.year, now.month, now.day);
          break;
        default:
          startDate = null; // All time
      }

      var query = supabase.from('expenses').select('amount');

      if (startDate != null) {
        query = query.gte('date', startDate.toIso8601String());
      }

      final response = await query;

      _totalExpenses = response.fold<double>(
        0,
        (sum, row) => sum + (row['amount'] ?? 0.0),
      );
    } catch (e) {
      debugPrint('Error fetching total expenses: $e');
      _totalExpenses = 0.0;
    }
  }

  Future<void> _fetchAttentionItems() async {
    _attentionItems = [];
    final supabase = Supabase.instance.client;
    final now = DateTime.now();

    // Time helpers
    final startOfDay = DateTime(
      now.year,
      now.month,
      now.day,
    ).toUtc().toIso8601String();
    final threeDaysFromNow = now
        .add(const Duration(days: 3))
        .toUtc()
        .toIso8601String();

    try {
      // --- 1. HIGH PRIORITY ISSUES ---

      // A. Pending Payment Verifications
      try {
        final pendingPayments = await supabase
            .from('payments')
            .select('reference_number, job_order_id')
            .eq('status', 'Pending')
            .limit(5);

        for (var payment in pendingPayments) {
          _attentionItems.add(
            AttentionItem(
              title: 'Payment verification needed',
              reference:
                  payment['reference_number'] ??
                  'REF-${payment['job_order_id']}',
              priority: 'High',
              color: Colors.orange,
              type: AttentionType.payment,
              relatedId: payment['job_order_id'],
            ),
          );
        }
      } catch (e) {
        debugPrint("Error fetching pending payments: $e");
      }

      // B. Overdue Job Orders (Past Date)
      try {
        final overdueJobs = await supabase
            .from('job_orders')
            .select('id, client_jo_number, date_scheduled')
            .neq('status', 'Completed')
            .neq('status', 'Cancelled')
            .lt('date_scheduled', now.toUtc().toIso8601String())
            .order('date_scheduled', ascending: true);

        for (var job in overdueJobs) {
          _attentionItems.add(
            AttentionItem(
              title: 'Job order overdue',
              reference: job['client_jo_number'] ?? 'JO-${job['id']}',
              priority: 'High',
              color: Colors.red,
              type: AttentionType.scheduling,
              relatedId: job['id'],
            ),
          );
        }
      } catch (e) {
        debugPrint("Error fetching overdue jobs: $e");
      }

      // --- 2. MEDIUM PRIORITY (Pre-emptive Warnings) ---

      // C. Upcoming Jobs Missing Info (Next 3 Days)
      try {
        final upcomingJobs = await supabase
            .from('job_orders')
            .select(
              'id, client_jo_number, date_scheduled, job_order_technicians(count), job_order_aircons(count)',
            )
            .neq('status', 'Completed')
            .neq('status', 'Cancelled')
            .gt('date_scheduled', now.toUtc().toIso8601String()) // Future
            .lt('date_scheduled', threeDaysFromNow) // But soon
            .order('date_scheduled', ascending: true);

        for (var job in upcomingJobs) {
          final techCount = job['job_order_technicians'][0]['count'] as int;
          final unitCount = job['job_order_aircons'][0]['count'] as int;

          if (techCount == 0 || unitCount == 0) {
            final date = DateTime.parse(job['date_scheduled']).toLocal();
            final dateStr =
                "${date.month}/${date.day} ${date.hour}:${date.minute.toString().padLeft(2, '0')}";

            String issue = "";
            if (techCount == 0 && unitCount == 0)
              issue = "No Tech or Unit assigned";
            else if (techCount == 0)
              issue = "No Tech assigned";
            else
              issue = "No Unit identified";

            _attentionItems.add(
              AttentionItem(
                title: 'Upcoming Job Incomplete',
                reference: '${job['client_jo_number']} ($dateStr) - $issue',
                priority: 'Medium', // Warning level
                color: Colors.amber.shade700,
                type: AttentionType.scheduling,
                relatedId: job['id'],
              ),
            );
          }
        }
      } catch (e) {
        debugPrint("Error fetching upcoming warnings: $e");
      }

      // --- 3. ACTIVITY LOG (Info Level) ---

      // D. Jobs Created Today
      try {
        final newJobs = await supabase
            .from('job_orders')
            .select(
              'id, client_jo_number, customers(first_name, last_name, company_name)',
            )
            .gte('date_created', startOfDay)
            .order('date_created', ascending: false);

        for (var job in newJobs) {
          final customer = job['customers'];
          String name = 'Unknown';
          if (customer != null) {
            name =
                customer['company_name'] ??
                "${customer['first_name']} ${customer['last_name']}";
          }

          _attentionItems.add(
            AttentionItem(
              title: 'New Job Created',
              reference: '$name (JO-${job['id']})',
              priority: 'Info',
              color: Colors.blue,
              type: AttentionType.scheduling,
              relatedId: job['id'],
            ),
          );
        }
      } catch (e) {
        debugPrint("Error fetching new jobs: $e");
      }

      // E. Payments Received Today
      try {
        final newPayments = await supabase
            .from('payments')
            .select('amount, payment_method, job_order_id')
            .gte('payment_date', startOfDay)
            .eq('status', 'Verified')
            .order('payment_date', ascending: false);

        for (var p in newPayments) {
          final amount = (p['amount'] as num).toDouble();
          _attentionItems.add(
            AttentionItem(
              title: 'Payment Received',
              reference:
                  '₱${amount.toStringAsFixed(0)} via ${p['payment_method']}',
              priority: 'Info',
              color: Colors.teal,
              type: AttentionType.payment,
              relatedId: p['job_order_id'],
            ),
          );
        }
      } catch (e) {
        debugPrint("Error fetching new payments: $e");
      }

      // --- 4. SORTING ---
      _attentionItems.sort((a, b) {
        int getScore(String p) {
          switch (p) {
            case 'High':
              return 0;
            case 'Medium':
              return 1; // Warnings sit here
            case 'Low':
              return 2;
            case 'Info':
              return 3;
            default:
              return 4;
          }
        }

        return getScore(a.priority).compareTo(getScore(b.priority));
      });

      if (_attentionItems.length > 20) {
        _attentionItems = _attentionItems.sublist(0, 20);
      }

      // Notify for High OR Medium items
      final importantCount = _attentionItems
          .where((item) => item.priority == 'High' || item.priority == 'Medium')
          .length;

      if (importantCount > 0) {
        NotificationService().showNotification(
          id: 1,
          title: 'Action Required',
          body: 'You have $importantCount items pending attention.',
        );
      }

      notifyListeners();
    } catch (e) {
      debugPrint('Critical error in notifications: $e');
    }
  }

  /// Get pending documents count (from local state since documents aren't in DB yet)
  void updatePendingDocsCount(int count) {
    _pendingDocsCount = count;
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

  AttentionItem({
    required this.title,
    required this.reference,
    required this.priority,
    required this.color,
    required this.type,
    this.relatedId,
  });
}
