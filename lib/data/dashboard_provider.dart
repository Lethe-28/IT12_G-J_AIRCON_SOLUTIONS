import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

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

    try {
      final supabase = Supabase.instance.client;

      // Fetch active jobs with their billing/payment counts
      final response = await supabase
          .from('job_orders')
          .select(
            'id, client_jo_number, date_scheduled, job_order_line_items(count), payments(count)',
          )
          .neq('status', 'Completed')
          .neq('status', 'Cancelled')
          .order('date_scheduled', ascending: true);

      for (var row in response) {
        final joNum = row['client_jo_number'] ?? 'JO-${row['id']}';
        final date = DateTime.parse(row['date_scheduled']).toLocal();

        // Counts
        final int itemsCount = row['job_order_line_items'][0]['count'] as int;
        final int payCount = row['payments'][0]['count'] as int;

        // 1. Check Unbilled (No items) - Wait 24 hours after creation before flagging to avoid noise
        // (Simple check: if line items is 0)
        if (itemsCount == 0) {
          _attentionItems.add(
            AttentionItem(
              title: 'Job needs billing details',
              reference: joNum,
              priority: 'High',
              color: Colors.red,
              type: AttentionType.scheduling, // Redirect to scheduling
              relatedId: row['id'],
            ),
          );
        }
        // 2. Check Unpaid (Has items, but 0 payments)
        else if (itemsCount > 0 && payCount == 0) {
          _attentionItems.add(
            AttentionItem(
              title: 'Payment collection pending',
              reference: joNum,
              priority: 'Medium',
              color: Colors.orange,
              type: AttentionType.scheduling,
              relatedId: row['id'],
            ),
          );
        }
      }

      // Limit to top 5 to prevent clutter
      if (_attentionItems.length > 5) {
        _attentionItems = _attentionItems.sublist(0, 5);
      }
    } catch (e) {
      debugPrint('Error fetching attention items: $e');
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
  final String type;
  final String status;

  TodayJobItem({
    required this.id,
    required this.client,
    required this.time,
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
