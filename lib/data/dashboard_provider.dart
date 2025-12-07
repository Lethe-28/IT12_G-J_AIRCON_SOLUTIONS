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

    // Get ISO string for today at 00:00:00
    final startOfDay = DateTime(
      now.year,
      now.month,
      now.day,
    ).toUtc().toIso8601String();

    try {
      // --- 1. ACTION ITEMS (High Priority) ---

      // A. Pending Payment Verifications
      // Schema Check: 'payments' table has 'status' column. OK.
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

      // [REMOVED] Pending Expenses check (Table has no 'status' column)

      // B. Overdue Job Orders
      // Schema Check: 'job_orders' table has 'date_scheduled' and 'status'. OK.
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

      // --- 2. ACTIVITY LOG (Info Level - Today's Updates) ---

      // C. Jobs Created Today
      // Schema Check: 'job_orders' table has 'date_created'. OK.
      try {
        final newJobs = await supabase
            .from('job_orders')
            .select(
              'id, client_jo_number, customers(first_name, last_name, company_name)',
            )
            .gte(
              'date_created',
              startOfDay,
            ) // Using correct column from your schema
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

      // D. Payments Received Today
      // Schema Check: 'payments' table has 'payment_date'. OK.
      try {
        final newPayments = await supabase
            .from('payments')
            .select('amount, payment_method, job_order_id')
            .gte(
              'payment_date',
              startOfDay,
            ) // Using correct column from your schema
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

      // --- 3. SORTING ---
      _attentionItems.sort((a, b) {
        int getScore(String p) {
          switch (p) {
            case 'High':
              return 0;
            case 'Medium':
              return 1;
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

      // Limit list size
      if (_attentionItems.length > 20) {
        _attentionItems = _attentionItems.sublist(0, 20);
      }

      // Notify user only for HIGH priority items
      final highPriorityCount = _attentionItems
          .where((item) => item.priority == 'High')
          .length;

      if (highPriorityCount > 0) {
        NotificationService().showNotification(
          id: 1,
          title: 'Action Required',
          body:
              'You have $highPriorityCount high priority items pending attention.',
        );
      }

      notifyListeners(); // Ensure UI updates
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
