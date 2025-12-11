import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'ui_app_shell.dart';
import 'data/app_state.dart';
import 'theme/app_theme.dart';
import '../services/activity_service.dart';
import 'shared/widgets.dart'
    show
        AnimatedCard,
        HoverCard,
        AnimatedButton,
        LoadingOverlay,
        LoadingButton,
        EmptyState,
        FilterChipGroup,
        SortableColumnHeader,
        showConfirmDialog,
        showUndoSnackBar,
        AppDesignTokens;

// --- Data Classes ---
class JobOrder {
  final int dbId;
  final String displayId;
  String clientName;
  String jobType;
  DateTime startDateTime;
  DateTime? scheduledEndDate;
  DateTime? actualCompletionDate;
  String location;
  String status;
  String? notes;
  final int? customerId;
  final bool isCorporate;
  final bool isUnbilled;
  final bool isUnpaid;
  final bool hasNoTechs;
  final bool hasNoUnits;

  JobOrder({
    required this.dbId,
    required this.displayId,
    required this.clientName,
    required this.jobType,
    required this.startDateTime,
    this.scheduledEndDate,
    this.actualCompletionDate,
    required this.location,
    required this.status,
    this.notes,
    this.customerId,
    required this.isCorporate,
    required this.isUnbilled,
    required this.isUnpaid,
    required this.hasNoTechs,
    required this.hasNoUnits,
  });
}

// --- Main Screen ---

class SchedulingScreen extends StatefulWidget {
  final String? initialSearch;
  final int? autoOpenId;
  final bool showPendingActions;

  const SchedulingScreen({
    super.key,
    this.initialSearch,
    this.autoOpenId,
    this.showPendingActions = false,
  });

  @override
  State<SchedulingScreen> createState() => _SchedulingScreenState();
}

class _SchedulingScreenState extends State<SchedulingScreen> {
  List<JobOrder> _orders = [];
  bool _isLoading = true;

  late TextEditingController _searchController;
  String _searchQuery = '';
  bool _isSearchActive = false;

  DateTime _focusedDate = DateTime.now();
  DateTime _selectedDate = DateTime.now();
  bool _sortOldestFirst = true;
  late bool _showActionItems;

  @override
  void initState() {
    super.initState();
    _showActionItems = widget.showPendingActions;
    String initialText = widget.initialSearch ?? '';
    _searchController = TextEditingController(text: initialText);

    if (initialText.isNotEmpty) {
      _searchQuery = initialText.toLowerCase();
      _isSearchActive = true;
    }

    _searchController.addListener(() {
      setState(() {
        _searchQuery = _searchController.text.toLowerCase();
      });
    });

    _fetchJobOrders();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _fetchJobOrders() async {
    setState(() => _isLoading = true);
    final supabase = Supabase.instance.client;

    try {
      final response = await supabase
          .from('job_orders')
          .select(
            '*, customers(id, first_name, last_name, company_name, city, barangay, address_complete, customer_type_id), job_types(job_type_name), job_order_line_items(count), payments(count), job_order_technicians(count), job_order_aircons(count)',
          )
          .order('date_scheduled', ascending: false);

      final List<JobOrder> loaded = [];

      for (var row in response) {
        final customer = row['customers'];
        String clientName = 'Unknown';
        String location = 'Unknown';
        int? custId;
        bool isCorp = false;

        if (customer != null) {
          custId = customer['id'];
          isCorp = customer['customer_type_id'] == 1;
          if (customer['company_name'] != null &&
              customer['company_name'].toString().isNotEmpty) {
            clientName = customer['company_name'];
          } else {
            clientName = '${customer['first_name']} ${customer['last_name']}';
          }
          // Use new address_complete if available, fallback to city/brgy
          if (customer['address_complete'] != null &&
              customer['address_complete'].toString().isNotEmpty) {
            location = customer['address_complete'];
          } else {
            final city = customer['city'] ?? '';
            final brgy = customer['barangay'] ?? '';
            location = "$city $brgy".trim();
          }
          if (location.isEmpty) location = "View Details";
        }

        DateTime start = DateTime.now();
        if (row['date_scheduled'] != null) {
          start = DateTime.parse(row['date_scheduled']).toLocal();
        }

        DateTime? schedEnd;
        if (row['date_scheduled_end'] != null) {
          schedEnd = DateTime.parse(row['date_scheduled_end']).toLocal();
        }

        DateTime? actualEnd;
        if (row['date_completed'] != null) {
          actualEnd = DateTime.parse(row['date_completed']).toLocal();
        }

        final int itemsCount = row['job_order_line_items'][0]['count'] as int;
        final bool unbilled = itemsCount == 0;
        final int payCount = row['payments'][0]['count'] as int;
        final bool unpaid = itemsCount > 0 && payCount == 0;
        final int techCount = row['job_order_technicians'][0]['count'] as int;
        final int unitCount = row['job_order_aircons'][0]['count'] as int;

        loaded.add(
          JobOrder(
            dbId: row['id'],
            displayId: row['client_jo_number'] ?? 'JO-${row['id']}',
            clientName: clientName,
            jobType: row['job_types']?['job_type_name'] ?? 'Service',
            startDateTime: start,
            scheduledEndDate: schedEnd,
            actualCompletionDate: actualEnd,
            location: location,
            status: row['status'] ?? 'Pending',
            notes: row['notes'],
            customerId: custId,
            isCorporate: isCorp,
            isUnbilled: unbilled,
            isUnpaid: unpaid,
            hasNoTechs: techCount == 0,
            hasNoUnits: unitCount == 0,
          ),
        );
      }

      if (mounted) setState(() => _orders = loaded);
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error loading jobs: $e')));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _onAddOrEdit({JobOrder? existingJob}) async {
    final result = await showDialog(
      context: context,
      builder: (context) =>
          _JobOrderDialog(initialDate: _selectedDate, existingJob: existingJob),
    );

    if (result == true) {
      _fetchJobOrders();
    }
  }

  void _showJobDetails(JobOrder job) {
    showDialog(
      context: context,
      builder: (context) => _JobBillingManager(
        job: job,
        onJobUpdated: _fetchJobOrders,
        onEditRequest: () {
          Navigator.pop(context);
          _onAddOrEdit(existingJob: job);
        },
      ),
    );
  }

  // --- Calendar Logic ---

  List<JobOrder> _getJobsForDay(DateTime day) {
    return _orders.where((o) {
      final start = DateTime(
        o.startDateTime.year,
        o.startDateTime.month,
        o.startDateTime.day,
      );
      final check = DateTime(day.year, day.month, day.day);

      if (o.scheduledEndDate != null) {
        final end = DateTime(
          o.scheduledEndDate!.year,
          o.scheduledEndDate!.month,
          o.scheduledEndDate!.day,
        );
        return (check.isAfter(start) || check.isAtSameMomentAs(start)) &&
            (check.isBefore(end) || check.isAtSameMomentAs(end));
      }
      return DateUtils.isSameDay(start, check);
    }).toList();
  }

  void _changeMonth(int increment) {
    setState(() {
      _focusedDate = DateTime(
        _focusedDate.year,
        _focusedDate.month + increment,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final isMobile =
        MediaQuery.of(context).size.width <
        900; // Adjusted breakpoint for Split View
    final calendarJobs = _getJobsForDay(_selectedDate);

    return AppShell(
      selectedIndex: 1,
      body: LoadingOverlay(
        isLoading: _isLoading,
        child: Container(
          color: const Color(0xFFF8FAFC),
          child: Column(
            children: [
              _buildHeader(isMobile),
              const Divider(height: 1),
              Expanded(
                child: isMobile
                    ? _buildMobileLayout(calendarJobs)
                    : _buildDesktopLayout(calendarJobs), // NEW: Split Layout
              ),
            ],
          ),
        ),
      ),
    );
  }

  // --- DESKTOP SPLIT LAYOUT  ---
  Widget _buildDesktopLayout(List<JobOrder> jobsForDay) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // LEFT: Calendar Grid (Flex 2)
        Expanded(
          flex: 2,
          child: Container(
            color: Colors.white,
            padding: const EdgeInsets.all(24),
            child: _buildCalendarGrid(),
          ),
        ),
        const VerticalDivider(width: 1),
        // RIGHT: Details List (Flex 1)
        Expanded(
          flex: 1,
          child: Container(
            color: const Color(0xFFF8FAFC),
            child: Column(
              children: [
                // Right Header
                Container(
                  padding: const EdgeInsets.all(20),
                  color: Colors.white,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "${_monthName(_selectedDate.month)} ${_selectedDate.day}",
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            "${jobsForDay.length} Scheduled",
                            style: const TextStyle(color: Colors.grey),
                          ),
                        ],
                      ),
                      // Add Button for specific day [cite: 87]
                      IconButton(
                        onPressed: () => _onAddOrEdit(),
                        icon: const Icon(
                          Icons.add_circle,
                          color: AppTheme.primary,
                          size: 32,
                        ),
                        tooltip: "Add Schedule for this day",
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1),
                Expanded(
                  child: jobsForDay.isEmpty
                      ? _buildEmptyStatePrompt() //
                      : ListView.separated(
                          padding: const EdgeInsets.all(16),
                          itemCount: jobsForDay.length,
                          separatorBuilder: (ctx, i) =>
                              const SizedBox(height: 12),
                          itemBuilder: (ctx, i) => _JobCard(
                            order: jobsForDay[i],
                          ), // Use existing card
                        ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // --- MOBILE LAYOUT (Classic Scroll) ---
  Widget _buildMobileLayout(List<JobOrder> jobsForDay) {
    return SingleChildScrollView(
      child: Column(
        children: [
          Container(
            color: Colors.white,
            padding: const EdgeInsets.only(bottom: 16),
            child: _buildCalendarGrid(),
          ),
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Schedule for ${_monthName(_selectedDate.month)} ${_selectedDate.day}",
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF64748B),
                  ),
                ),
                const SizedBox(height: 16),
                if (jobsForDay.isEmpty)
                  _buildEmptyStatePrompt()
                else
                  ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: jobsForDay.length,
                    separatorBuilder: (ctx, i) => const SizedBox(height: 12),
                    itemBuilder: (ctx, i) => _JobCard(order: jobsForDay[i]),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  //  Prompt to add schedule on empty days
  Widget _buildEmptyStatePrompt() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.event_available, size: 48, color: Colors.grey[300]),
            const SizedBox(height: 12),
            const Text(
              "No schedules yet.",
              style: TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: () => _onAddOrEdit(),
              icon: const Icon(Icons.add),
              label: const Text("Set Schedule"),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(bool isMobile) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: isMobile ? 16 : 32,
        vertical: 16,
      ),
      color: Colors.white,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              IconButton(
                icon: const Icon(Icons.chevron_left),
                onPressed: () => _changeMonth(-1),
              ),
              Text(
                "${_monthName(_focusedDate.month)} ${_focusedDate.year}",
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF1E293B),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.chevron_right),
                onPressed: () => _changeMonth(1),
              ),
            ],
          ),
          ElevatedButton.icon(
            onPressed: () => _onAddOrEdit(),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF2563EB),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            icon: const Icon(Icons.add, size: 18),
            label: const Text(
              'Add Job',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCalendarGrid() {
    final daysInMonth = DateUtils.getDaysInMonth(
      _focusedDate.year,
      _focusedDate.month,
    );
    final firstDayOfMonth = DateTime(_focusedDate.year, _focusedDate.month, 1);
    final int firstWeekday = firstDayOfMonth.weekday % 7;

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"]
                .map(
                  (day) => Expanded(
                    child: Center(
                      child: Text(
                        day,
                        style: const TextStyle(
                          color: Colors.grey,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                )
                .toList(),
          ),
        ),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: daysInMonth + firstWeekday,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 7,
            childAspectRatio: 1.0, // Square cells look better on Desktop
          ),
          itemBuilder: (context, index) {
            if (index < firstWeekday) return const SizedBox();
            final dayInt = index - firstWeekday + 1;
            final currentDay = DateTime(
              _focusedDate.year,
              _focusedDate.month,
              dayInt,
            );
            final isSelected = DateUtils.isSameDay(currentDay, _selectedDate);
            final isToday = DateUtils.isSameDay(currentDay, DateTime.now());

            final jobs = _getJobsForDay(currentDay);
            final hasJobs = jobs.isNotEmpty;
            // [cite: 129] Logic to change color if ALL jobs are completed
            final allCompleted =
                hasJobs && jobs.every((j) => j.status == 'Completed');

            return GestureDetector(
              onTap: () => setState(() => _selectedDate = currentDay),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                margin: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: isSelected
                      ? AppTheme.primary
                      : (isToday
                            ? AppTheme.primary.withOpacity(0.1)
                            : Colors.transparent),
                  borderRadius: BorderRadius.circular(12),
                  border: isToday && !isSelected
                      ? Border.all(color: AppTheme.primary)
                      : null,
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      "$dayInt",
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: isSelected ? Colors.white : AppTheme.textPrimary,
                      ),
                    ),
                    if (hasJobs) ...[
                      const SizedBox(height: 4),
                      // Dot Color: Green if all done, Orange if pending
                      Container(
                        width: 6,
                        height: 6,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: isSelected
                              ? Colors.white
                              : (allCompleted
                                    ? Colors.green
                                    : AppTheme.warning),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            );
          },
        ),
      ],
    );
  }

  String _monthName(int month) {
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
    return months[month - 1];
  }
}

// --- JOB MANAGEMENT & BILLING HUB ---

class _JobBillingManager extends StatefulWidget {
  final JobOrder job;
  final VoidCallback onJobUpdated;
  final VoidCallback onEditRequest;

  const _JobBillingManager({
    required this.job,
    required this.onJobUpdated,
    required this.onEditRequest,
  });

  @override
  State<_JobBillingManager> createState() => _JobBillingManagerState();
}

class _JobBillingManagerState extends State<_JobBillingManager>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _isLoading = true;
  final _supabase = Supabase.instance.client;
  late String _currentStatus;

  List<Map<String, dynamic>> _lineItems = [];
  List<Map<String, dynamic>> _serviceCatalog = [];
  List<String> _assignedTechNames = [];
  List<String> _assignedUnitDetails = [];
  double _totalAmount = 0.0;
  double _totalPaid = 0.0;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _currentStatus = widget.job.status;
    _fetchBillingData();
  }

  // 1. Live Status Update (For the Header Dropdown)
  Future<void> _updateStatus(String newStatus) async {
    try {
      await _supabase
          .from('job_orders')
          .update({'status': newStatus})
          .eq('id', widget.job.dbId);

      setState(() => _currentStatus = newStatus);
      widget.onJobUpdated(); // Refresh parent list

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Status updated to $newStatus")));
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Error: $e")));
    }
  }

  // 2. Manual Close Logic (With "Unpaid" Warning)
  Future<void> _completeJob() async {
    // Validation: Warn if Unbilled or Unpaid
    if (widget.job.isUnbilled || widget.job.isUnpaid) {
      final confirm = await showConfirmDialog(
        context: context,
        title: "Job Incomplete?",
        message:
            "This job has pending billing or payments. Are you sure you want to close it?",
        confirmLabel: "Close Anyway",
        isDestructive: true,
      );
      if (confirm != true) return;
    } else {
      // Standard Confirmation
      final confirm = await showConfirmDialog(
        context: context,
        title: "Complete Job",
        message: "This will mark the job as finished and lock it from editing.",
        confirmLabel: "Complete Job",
      );
      if (confirm != true) return;
    }

    try {
      await _supabase
          .from('job_orders')
          .update({
            'status': 'Completed',
            'date_completed': DateTime.now().toUtc().toIso8601String(),
          })
          .eq('id', widget.job.dbId);

      if (mounted) {
        Navigator.pop(context); // Close dialog
        widget.onJobUpdated();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Job Completed Successfully!")),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Error: $e")));
    }
  }

  // 3. Admin Re-open Logic
  Future<void> _reopenJob() async {
    final confirm = await showConfirmDialog(
      context: context,
      title: "Re-open Job?",
      message: "This will unlock the job and move it back to 'Pending'.",
      confirmLabel: "Re-open",
    );

    if (confirm == true) {
      try {
        await _supabase
            .from('job_orders')
            .update({'status': 'Pending', 'date_completed': null})
            .eq('id', widget.job.dbId);

        if (mounted) {
          Navigator.pop(context);
          widget.onJobUpdated();
        }
      } catch (e) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text("Error: $e")));
      }
    }
  }

  Future<void> _fetchBillingData() async {
    setState(() => _isLoading = true);

    try {
      final jobId = widget.job.dbId;

      final results = await Future.wait([
        // 0: Line Items
        _supabase
            .from('job_order_line_items')
            .select('id, quantity, actual_price, service_items(item_name)')
            .eq('job_order_id', jobId),
        // 1: Payments
        _supabase.from('payments').select('amount').eq('job_order_id', jobId),
        // 2: Service Catalog
        _supabase.from('service_items').select().order('item_name'),
        // 3: Techs
        _supabase
            .from('job_order_technicians')
            .select('technicians(first_name, last_name)')
            .eq('job_order_id', jobId),
        // 4: Aircons
        _supabase
            .from('job_order_aircons')
            .select(
              'aircons(remarks, brands(brand_name), aircon_types(type_name))',
            )
            .eq('job_order_id', jobId),
      ]);

      final items = List<Map<String, dynamic>>.from(results[0] as List);
      final payments = List<Map<String, dynamic>>.from(results[1] as List);
      final catalog = List<Map<String, dynamic>>.from(results[2] as List);
      final techRes = List<Map<String, dynamic>>.from(results[3] as List);
      final acRes = List<Map<String, dynamic>>.from(results[4] as List);

      double total = 0;
      for (var i in items) total += (i['actual_price'] * i['quantity']);

      double paid = 0;
      for (var p in payments) paid += p['amount'];

      final List<String> loadedTechs = [];
      for (var row in techRes) {
        if (row['technicians'] != null) {
          final t = row['technicians'];
          loadedTechs.add("${t['first_name']} ${t['last_name']}");
        }
      }

      final List<String> loadedUnits = [];
      for (var row in acRes) {
        final a = row['aircons'];
        if (a != null) {
          final brand = a['brands']?['brand_name'] ?? 'Unknown Brand';
          final type = a['aircon_types']?['type_name'] ?? 'Unit';
          final remark = a['remarks'] ?? '';
          loadedUnits.add(
            "$brand $type${remark.isNotEmpty ? ' ($remark)' : ''}",
          );
        }
      }

      if (mounted) {
        setState(() {
          _lineItems = items;
          _serviceCatalog = catalog;
          _assignedTechNames = loadedTechs;
          _assignedUnitDetails = loadedUnits;
          _totalAmount = total;
          _totalPaid = paid;
        });
      }
    } catch (e) {
      debugPrint('Error loading details: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Network Error: Could not load full details."),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _deleteJob() async {
    final confirm = await showConfirmDialog(
      context: context,
      title: "Delete Job?",
      message: "This will remove the job and all billing records.",
      confirmLabel: "Delete Forever",
      isDestructive: true,
    );

    if (confirm == true) {
      try {
        await _supabase.from('job_orders').delete().eq('id', widget.job.dbId);

        // LOG IT!
        await ActivityLogger.log(
          type: 'Delete',
          details: 'Deleted Job ${widget.job.displayId}',
        );

        if (mounted) {
          Navigator.pop(context);
          widget.onJobUpdated();
        }
      } catch (e) {
        if (mounted)
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text("Delete Error: $e")));
      }
    }
  }

  void _onReschedule() async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final isPast = widget.job.startDateTime.isBefore(today);
    final pickerInitialDate = isPast ? today : widget.job.startDateTime;

    final d = await showDatePicker(
      context: context,
      initialDate: pickerInitialDate,
      firstDate: today,
      lastDate: DateTime(2030),
    );

    if (d != null) {
      final t = await showTimePicker(
        context: context,
        initialTime: TimeOfDay.fromDateTime(widget.job.startDateTime),
      );
      if (t != null) {
        final newDate = DateTime(d.year, d.month, d.day, t.hour, t.minute);
        await _supabase
            .from('job_orders')
            .update({
              'date_scheduled': newDate.toUtc().toIso8601String(),
              'date_scheduled_end': null,
            })
            .eq('id', widget.job.dbId);

        widget.onJobUpdated();
        if (mounted) Navigator.pop(context);
      }
    }
  }

  void _onExtend() async {
    final d = await showDatePicker(
      context: context,
      initialDate: widget.job.scheduledEndDate ?? widget.job.startDateTime,
      firstDate: widget.job.startDateTime,
      lastDate: DateTime(2030),
      helpText: "Select End Date",
    );
    if (d != null) {
      await _supabase
          .from('job_orders')
          .update({'date_scheduled_end': d.toUtc().toIso8601String()})
          .eq('id', widget.job.dbId);
      widget.onJobUpdated();
      if (mounted) Navigator.pop(context);
    }
  }

  // NEW: Add Expense Dialog locked to this Job
  void _addJobExpenseDialog() {
    final nameController = TextEditingController();
    final amountController = TextEditingController();
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Add Operational Expense"),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                "Recording expense for ${widget.job.displayId}",
                style: const TextStyle(fontSize: 12, color: Colors.grey),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: nameController,
                decoration: const InputDecoration(
                  labelText: "Expense Name (e.g. Fuel, Parts)",
                  border: OutlineInputBorder(),
                ),
                validator: (v) => v!.isEmpty ? "Required" : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: amountController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: "Amount (₱)",
                  border: OutlineInputBorder(),
                ),
                validator: (v) => v!.isEmpty ? "Required" : null,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            onPressed: () async {
              if (!formKey.currentState!.validate()) return;

              try {
                await _supabase.from('expenses').insert({
                  'expense_name': nameController.text.trim(),
                  'amount': double.parse(amountController.text),
                  'date': DateTime.now().toString().split(' ')[0],
                  'expense_type': 'Operational',
                  'is_income': false,
                  'job_order_id': widget.job.dbId, // Auto-link to this job
                  'user_id': _supabase.auth.currentUser?.id,
                });

                if (mounted) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text("Expense Recorded!")),
                  );
                }
              } catch (e) {
                ScaffoldMessenger.of(
                  context,
                ).showSnackBar(SnackBar(content: Text("Error: $e")));
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              foregroundColor: Colors.white,
            ),
            child: const Text("Save Expense"),
          ),
        ],
      ),
    );
  }

  void _addItemDialog() {
    int? selectedItemId;
    final priceController = TextEditingController();
    final qtyController = TextEditingController(text: '1');
    final nameController = TextEditingController();
    bool isCustom = false;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            title: const Text("Add Service/Item"),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: ChoiceChip(
                        label: const Text("From Catalog"),
                        selected: !isCustom,
                        onSelected: (v) => setDialogState(() => isCustom = !v),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: ChoiceChip(
                        label: const Text("Custom Item"),
                        selected: isCustom,
                        onSelected: (v) => setDialogState(() {
                          isCustom = v;
                          selectedItemId = null;
                          priceController.clear();
                        }),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                if (!isCustom)
                  DropdownButtonFormField<int>(
                    value: selectedItemId,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: "Select Item",
                      border: OutlineInputBorder(),
                    ),
                    items: _serviceCatalog
                        .map(
                          (item) => DropdownMenuItem(
                            value: item['id'] as int,
                            child: Text(
                              "${item['item_name']} (₱${item['price']})",
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        )
                        .toList(),
                    onChanged: (val) {
                      setDialogState(() {
                        selectedItemId = val;
                        final item = _serviceCatalog.firstWhere(
                          (i) => i['id'] == val,
                        );
                        priceController.text = item['price'].toString();
                      });
                    },
                  )
                else
                  TextFormField(
                    controller: nameController,
                    decoration: const InputDecoration(
                      labelText: "Item Name",
                      border: OutlineInputBorder(),
                    ),
                  ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: priceController,
                        decoration: const InputDecoration(
                          labelText: "Price (₱)",
                          border: OutlineInputBorder(),
                        ),
                        keyboardType: TextInputType.number,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextFormField(
                        controller: qtyController,
                        decoration: const InputDecoration(
                          labelText: "Qty",
                          border: OutlineInputBorder(),
                        ),
                        keyboardType: TextInputType.number,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text("Cancel"),
              ),
              ElevatedButton(
                onPressed: () async {
                  await _saveLineItem(
                    isCustom: isCustom,
                    itemId: selectedItemId,
                    customName: nameController.text,
                    price: double.tryParse(priceController.text) ?? 0,
                    qty: double.tryParse(qtyController.text) ?? 1,
                  );
                  if (mounted) Navigator.pop(context);
                },
                child: const Text("Add to Bill"),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _saveLineItem({
    required bool isCustom,
    int? itemId,
    String? customName,
    required double price,
    required double qty,
  }) async {
    try {
      int finalItemId;
      if (isCustom) {
        final res = await _supabase
            .from('service_items')
            .insert({
              'item_name': customName ?? 'Custom Service',
              'item_type': 'Custom',
              'price': price,
            })
            .select('id')
            .single();
        finalItemId = res['id'];
      } else {
        if (itemId == null) return;
        finalItemId = itemId;
      }
      await _supabase.from('job_order_line_items').insert({
        'job_order_id': widget.job.dbId,
        'service_item_id': finalItemId,
        'quantity': qty,
        'actual_price': price,
      });
      widget.onJobUpdated();
      _fetchBillingData();
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text("Error: $e")));
    }
  }

  void _recordPaymentDialog() {
    final amountController = TextEditingController(
      text: (_totalAmount - _totalPaid).toString(),
    );
    String method = 'Cash';
    final _paymentFormKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Record Payment"),
        content: Form(
          key: _paymentFormKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text("Record cash-in from client."),
              const SizedBox(height: 16),
              TextFormField(
                controller: amountController,
                decoration: const InputDecoration(
                  labelText: "Amount Received",
                  prefixText: "₱ ",
                  border: OutlineInputBorder(),
                ),
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) return 'Required';
                  if (double.tryParse(value) == null) return 'Invalid amount';
                  if (double.parse(value) <= 0) return 'Must be > 0';
                  return null;
                },
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: method,
                decoration: const InputDecoration(
                  labelText: "Payment Method",
                  border: OutlineInputBorder(),
                ),
                items: ['Cash', 'GCash', 'Bank Transfer', 'Cheque']
                    .map((m) => DropdownMenuItem(value: m, child: Text(m)))
                    .toList(),
                onChanged: (v) => method = v!,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
            ),
            onPressed: () async {
              if (!_paymentFormKey.currentState!.validate()) return;

              await _supabase.from('payments').insert({
                'job_order_id': widget.job.dbId,
                'amount': double.parse(amountController.text),
                'payment_method': method,
                'payment_date': DateTime.now().toIso8601String(),
                'status': 'Verified',
              });

              // LOG IT!
              await ActivityLogger.log(
                type: 'Payment',
                details:
                    'Received ₱${amountController.text} for ${widget.job.displayId}',
              );

              if (mounted) {
                Navigator.pop(context);
                widget.onJobUpdated();
                _fetchBillingData();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text("Payment Recorded!")),
                );
              }
            },
            child: const Text("Confirm Payment"),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          child: Container(
            width: 500,
            height: constraints.maxHeight * 0.8,
            color: Colors.white,
            child: Column(
              children: [
                // Header
                Container(
                  padding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Status Changer Row
                      Row(
                        children: [
                          Text(
                            "${widget.job.jobType} • ${widget.job.displayId}",
                            style: const TextStyle(color: Colors.grey),
                          ),
                          const SizedBox(width: 12),

                          // LOGIC: If 'Completed', show locked badge. Else show Dropdown.
                          if (_currentStatus == 'Completed')
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.green.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: const Row(
                                children: [
                                  Icon(
                                    Icons.lock,
                                    size: 12,
                                    color: Colors.green,
                                  ),
                                  SizedBox(width: 4),
                                  Text(
                                    "COMPLETED",
                                    style: TextStyle(
                                      color: Colors.green,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 11,
                                    ),
                                  ),
                                ],
                              ),
                            )
                          else
                            DropdownButton<String>(
                              // Ensure current status is valid, else fallback to Pending
                              value:
                                  [
                                    'Pending',
                                    'In Progress',
                                    'On Hold',
                                  ].contains(_currentStatus)
                                  ? _currentStatus
                                  : 'Pending',
                              underline: Container(
                                height: 1,
                                color: Colors.blue,
                              ),
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: Colors.blue,
                              ),
                              icon: const Icon(
                                Icons.arrow_drop_down,
                                color: Colors.blue,
                                size: 18,
                              ),
                              onChanged: (newValue) {
                                if (newValue != null) _updateStatus(newValue);
                              },
                              items: ['Pending', 'In Progress', 'On Hold'].map((
                                String status,
                              ) {
                                return DropdownMenuItem<String>(
                                  value: status,
                                  child: Text(status),
                                );
                              }).toList(),
                            ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      TabBar(
                        controller: _tabController,
                        labelColor: Colors.blue,
                        unselectedLabelColor: Colors.grey,
                        indicatorColor: Colors.blue,
                        tabs: const [
                          Tab(text: "Details & Actions"),
                          Tab(text: "Billing & Payment"),
                        ],
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1),
                Expanded(
                  child: _isLoading
                      ? const Center(child: CircularProgressIndicator())
                      : TabBarView(
                          controller: _tabController,
                          children: [_buildDetailsTab(), _buildBillingTab()],
                        ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildDetailsTab() {
    String scheduleText;
    final start = widget.job.startDateTime.toLocal();
    final timeStr = TimeOfDay.fromDateTime(start).format(context);
    final startDateStr = start.toString().split(' ')[0];

    if (widget.job.scheduledEndDate != null) {
      final end = widget.job.scheduledEndDate!.toLocal();
      final endDateStr = end.toString().split(' ')[0];
      scheduleText = "$startDateStr - $endDateStr";
    } else {
      scheduleText = "$startDateStr at $timeStr";
    }

    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        _infoSection("Schedule", [
          _infoRow(Icons.calendar_today, scheduleText),
          _infoRow(Icons.location_on, widget.job.location),
        ]),
        const SizedBox(height: 24),
        _infoSection("Assigned Team", [
          _infoRow(
            Icons.people,
            _assignedTechNames.isNotEmpty
                ? _assignedTechNames.join('\n')
                : "No technicians assigned",
          ),
        ]),
        const SizedBox(height: 24),
        _infoSection("Assets / Units", [
          _infoRow(
            Icons.ac_unit,
            _assignedUnitDetails.isNotEmpty
                ? _assignedUnitDetails.join('\n')
                : "No specific units linked",
          ),
        ]),
        const SizedBox(height: 24),
        _infoSection("Notes", [
          _infoRow(
            Icons.note,
            widget.job.notes != null && widget.job.notes!.isNotEmpty
                ? widget.job.notes!
                : "No additional notes",
          ),
        ]),
        const SizedBox(height: 24),
        const Text(
          "Quick Actions",
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
        ),
        const SizedBox(height: 12),
        // DYNAMIC ACTIONS BASED ON STATUS
        if (widget.job.status == 'Completed')
          // LOCKED VIEW
          Column(
            children: [
              const SizedBox(
                width: double.infinity,
                child: Card(
                  color: Color(0xFFF0FDF4), // Light Green
                  elevation: 0,
                  child: Padding(
                    padding: EdgeInsets.all(16.0),
                    child: Center(
                      child: Text(
                        "This job is completed and locked.",
                        style: TextStyle(
                          color: Colors.green,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              // Re-open Button (Admin Only)
              if (AppState.currentRole == UserRole.admin)
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: _reopenJob,
                    icon: const Icon(Icons.lock_open),
                    label: const Text("Re-open Job (Admin Only)"),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.orange[800],
                      side: BorderSide(color: Colors.orange[800]!),
                    ),
                  ),
                ),
            ],
          ),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            _ActionButton(
              icon: Icons.edit,
              label: "Edit Details",
              color: Colors.blue,
              onTap: widget.onEditRequest,
            ),
            _ActionButton(
              icon: Icons.calendar_month,
              label: "Reschedule",
              color: Colors.orange,
              onTap: _onReschedule,
            ),
            _ActionButton(
              icon: Icons.update,
              label: "Extend Job",
              color: Colors.purple,
              onTap: _onExtend,
            ),
            _ActionButton(
              icon: Icons.delete,
              label: "Delete Job",
              color: Colors.red,
              onTap: _deleteJob,
            ),
            // COMPLETE BUTTON (New)
            _ActionButton(
              icon: Icons.check_circle,
              label: "Complete Job",
              color: Colors.green,
              onTap: _completeJob,
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildBillingTab() {
    final balance = _totalAmount - _totalPaid;
    final isPaid = balance <= 0 && _totalAmount > 0;
    final isNarrow = MediaQuery.of(context).size.width < 450;

    return Column(
      children: [
        Expanded(
          child: _lineItems.isEmpty
              ? LayoutBuilder(
                  builder: (context, constraints) {
                    return SingleChildScrollView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      child: ConstrainedBox(
                        constraints: BoxConstraints(
                          minHeight: constraints.maxHeight,
                        ),
                        child: Center(
                          child: Padding(
                            padding: const EdgeInsets.all(20.0),
                            child: EmptyState(
                              icon: Icons.receipt_long,
                              title: "No Items Yet",
                              message:
                                  "Add services or parts to create the bill.",
                              actionLabel: "Add Item",
                              onAction: _addItemDialog,
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                )
              : ListView.separated(
                  padding: const EdgeInsets.all(24),
                  itemCount: _lineItems.length,
                  separatorBuilder: (ctx, i) => const Divider(),
                  itemBuilder: (ctx, i) {
                    final item = _lineItems[i];
                    final name = item['service_items']['item_name'];
                    final price = item['actual_price'];
                    final qty = item['quantity'];
                    return Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                name,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              Text(
                                "$qty x ₱$price",
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Text(
                          "₱${(price * qty).toStringAsFixed(2)}",
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ],
                    );
                  },
                ),
        ),
        Container(
          padding: EdgeInsets.all(isNarrow ? 16 : 24),
          decoration: BoxDecoration(
            color: Colors.grey[50],
            border: const Border(top: BorderSide(color: Color(0xFFE2E8F0))),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _totalRow("Total Bill", _totalAmount),
              _totalRow("Paid", _totalPaid, color: Colors.green),
              Divider(height: isNarrow ? 16 : 24),
              _totalRow(
                "Balance Due",
                balance,
                isBold: true,
                color: balance > 0 ? Colors.red : Colors.grey,
              ),
              SizedBox(height: isNarrow ? 16 : 20),

              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _addItemDialog,
                      icon: const Icon(Icons.add_circle_outline),
                      label: const Text("Add Bill Item"),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: isPaid ? null : _recordPaymentDialog,
                      icon: const Icon(Icons.payment),
                      label: Text(isPaid ? "Paid" : "Record Payment"),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // NEW: Quick Expense Button
              SizedBox(
                width: double.infinity,
                child: TextButton.icon(
                  onPressed: _addJobExpenseDialog,
                  icon: const Icon(Icons.money_off, size: 18),
                  label: const Text("Record Operational Expense"),
                  style: TextButton.styleFrom(
                    foregroundColor: Colors.red[700],
                    backgroundColor: Colors.red[50],
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _totalRow(
    String label,
    double value, {
    bool isBold = false,
    Color? color,
  }) {
    // Default Display Values
    String displayLabel = label;
    String displayValue = "₱${value.toStringAsFixed(2)}";
    Color? finalColor = color;

    // SMART LOGIC: Handle Credit (Negative Balance)
    if (label == "Balance Due") {
      if (value < 0) {
        // Scenario: Client paid more than the current bill (Deposit/Wallet)
        displayLabel = "Credit / Advance";
        // Accounting style: (₱500.00) indicates negative/credit
        displayValue = "(₱${value.abs().toStringAsFixed(2)})";
        finalColor = Colors.blue; // Friendly color
      } else if (value > 0) {
        // Scenario: Client owes money
        finalColor = Colors.red;
      } else {
        // Scenario: Fully Paid
        finalColor = Colors.grey;
      }
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            displayLabel,
            style: TextStyle(
              fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
              fontSize: isBold ? 16 : 14,
            ),
          ),
          Text(
            displayValue,
            style: TextStyle(
              fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
              fontSize: isBold ? 18 : 14,
              color: finalColor,
            ),
          ),
        ],
      ),
    );
  }

  Widget _infoSection(String title, List<Widget> children) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            color: Colors.grey,
            fontWeight: FontWeight.bold,
            fontSize: 12,
          ),
        ),
        const SizedBox(height: 8),
        ...children,
      ],
    );
  }

  Widget _infoRow(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Icon(icon, size: 16, color: Colors.grey),
          const SizedBox(width: 8),
          Expanded(child: Text(text)),
        ],
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;
  const _ActionButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });
  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        width: 100,
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.w600,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// --- VISUAL WIZARD DIALOG ---

class _JobOrderDialog extends StatefulWidget {
  final DateTime? initialDate;
  final JobOrder? existingJob; // ADDED: Enable editing

  const _JobOrderDialog({this.initialDate, this.existingJob});
  @override
  State<_JobOrderDialog> createState() => _JobOrderDialogState();
}

class _JobOrderDialogState extends State<_JobOrderDialog> {
  // Steps: 0=CustomerType, 1=ServiceType, 2=Details
  int _currentStep = 0;
  bool _isSubmitting = false;
  final _supabase = Supabase.instance.client;
  final _formKey = GlobalKey<FormState>();

  // --- Controllers & Variables ---

  // Data State
  String _customerType = 'Residential'; // Default
  String _jobTypeName = 'Installation';
  int? _jobTypeId;
  bool _isNewClient = true; // Default to New for quicker entry flow

  // Search/Dropdown Options
  List<Map<String, dynamic>> _existingClients = [];
  List<String> _brandOptions = [];
  List<Map<String, dynamic>> _airconTypes = [];
  List<Map<String, dynamic>> _availableTechnicians = [];

  // Selection State
  int? _selectedClientId;
  List<Map<String, dynamic>> _clientAircons = [];
  final List<int> _selectedAirconIds = [];
  final List<int> _selectedTechnicianIds = [];

  // --- "One Bar" Inputs (New) ---
  final _fullNameController = TextEditingController();
  final _addressController = TextEditingController();

  // Contact Info
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();

  // Unit Details
  final _customerDisplayController =
      TextEditingController(); // For search display
  String _selectedBrandName = '';
  int? _selectedAirconTypeId;
  final _unitRemarkController = TextEditingController();
  // New Aircon Fields
  final _hpController = TextEditingController();
  bool _isInverter = false;

  // Job Details
  final _externalRefController = TextEditingController();
  late DateTime _scheduleDate;
  TimeOfDay _scheduleTime = const TimeOfDay(hour: 9, minute: 0);
  final _notesController = TextEditingController();

  // --- VALIDATORS ---
  String? _validatePhone(String? value) {
    if (value == null || value.isEmpty) return 'Required';
    final trimmed = value.trim();
    // Regex: Matches 09xxxxxxxxx OR 7-12 digit landlines
    if (!RegExp(r'^(09\d{9}|\d{7,12})$').hasMatch(trimmed)) return 'Invalid #';
    return null;
  }

  String? _validateEmail(String? value) {
    if (value == null || value.trim().isEmpty) return null; // Email is optional
    if (!value.contains('@') || !value.contains('.')) return 'Invalid email';
    return null;
  }

  // --- Conflict Checker (Kept Existing) ---
  Future<bool> _checkScheduleConflict(
    DateTime proposedDate,
    TimeOfDay proposedTime,
  ) async {
    final startOfDay = DateTime(
      proposedDate.year,
      proposedDate.month,
      proposedDate.day,
    );
    final endOfDay = startOfDay.add(const Duration(hours: 23, minutes: 59));

    final res = await _supabase
        .from('job_orders')
        .select(
          'id, date_scheduled, client_jo_number, customers(first_name, last_name, company_name)',
        )
        .gte('date_scheduled', startOfDay.toUtc().toIso8601String())
        .lte('date_scheduled', endOfDay.toUtc().toIso8601String())
        .neq('status', 'Completed')
        .neq('status', 'Cancelled');

    for (var job in res) {
      if (widget.existingJob != null && job['id'] == widget.existingJob!.dbId)
        continue;

      final jobDate = DateTime.parse(job['date_scheduled']).toLocal();
      final diff = jobDate
          .difference(
            DateTime(
              proposedDate.year,
              proposedDate.month,
              proposedDate.day,
              proposedTime.hour,
              proposedTime.minute,
            ),
          )
          .inMinutes
          .abs();

      if (diff < 120) {
        return true;
      }
    }
    return false;
  }

  @override
  void initState() {
    super.initState();
    if (widget.existingJob != null) {
      // If editing, we skip the "Type" steps and go straight to details
      _currentStep = 2;
      _jobTypeName = widget.existingJob!.jobType;
      _scheduleDate = widget.existingJob!.startDateTime;
      _scheduleTime = TimeOfDay.fromDateTime(widget.existingJob!.startDateTime);
      _notesController.text = widget.existingJob!.notes ?? '';
      _selectedClientId = widget.existingJob!.customerId;
      _externalRefController.text = widget.existingJob!.displayId;
      _isNewClient = false;

      // Determine Customer Type based on data
      _customerType = widget.existingJob!.isCorporate
          ? 'Commercial'
          : 'Residential';
    } else {
      _scheduleDate = widget.initialDate ?? DateTime.now();
    }

    _fetchInitialData();
  }

  Future<void> _fetchInitialData() async {
    // 1. Fetch Master Data
    // Added address_complete to selection
    final customers = await _supabase
        .from('customers')
        .select(
          'id, first_name, last_name, company_name, city, barangay, address_complete',
        )
        .order('last_name', ascending: true);

    final types = await _supabase.from('job_types').select();
    final brands = await _supabase.from('brands').select().order('brand_name');
    final acTypes = await _supabase.from('aircon_types').select();
    final techs = await _supabase
        .from('technicians')
        .select()
        .order('first_name');

    // 2. Prepare Variables for Edit Mode
    List<int> existingLinkedAircons = [];
    List<int> existingLinkedTechs = [];
    List<Map<String, dynamic>> loadedClientAircons = [];

    if (widget.existingJob != null) {
      final linkedAcRes = await _supabase
          .from('job_order_aircons')
          .select('aircon_id')
          .eq('job_order_id', widget.existingJob!.dbId);
      existingLinkedAircons = List<int>.from(
        linkedAcRes.map((e) => e['aircon_id']),
      );

      final linkedTechRes = await _supabase
          .from('job_order_technicians')
          .select('technician_id')
          .eq('job_order_id', widget.existingJob!.dbId);
      existingLinkedTechs = List<int>.from(
        linkedTechRes.map((e) => e['technician_id']),
      );

      final int? custId = widget.existingJob?.customerId;
      if (custId != null) {
        // Fetch specific aircon columns including new HP/Inverter
        final units = await _supabase
            .from('aircons')
            .select(
              'id, remarks, horse_power, is_inverter, brands(brand_name), aircon_types(type_name)',
            )
            .eq('customer_id', custId);
        loadedClientAircons = List<Map<String, dynamic>>.from(units);
      }
    }

    if (mounted) {
      setState(() {
        _existingClients = List<Map<String, dynamic>>.from(customers);
        _brandOptions = List<String>.from(brands.map((b) => b['brand_name']));
        _airconTypes = List<Map<String, dynamic>>.from(acTypes);
        _availableTechnicians = List<Map<String, dynamic>>.from(techs);

        if (widget.existingJob == null) {
          final installType = types.firstWhere(
            (t) => t['job_type_name'] == 'Installation',
            orElse: () => types.first,
          );
          _jobTypeId = installType['id'];
        } else {
          // --- EDIT MODE RESTORATION ---
          if (_selectedClientId != null) {
            final cust = _existingClients.firstWhere(
              (c) => c['id'] == _selectedClientId,
              orElse: () => {},
            );
            if (cust.isNotEmpty) {
              // Pre-fill One Bar inputs for display
              if (cust['company_name'] != null &&
                  cust['company_name'].toString().isNotEmpty) {
                _fullNameController.text = cust['company_name'];
                _customerDisplayController.text = cust['company_name'];
              } else {
                _fullNameController.text =
                    '${cust['first_name']} ${cust['last_name']}';
                _customerDisplayController.text =
                    '${cust['first_name']} ${cust['last_name']}';
              }

              // Restore Address
              if (cust['address_complete'] != null) {
                _addressController.text = cust['address_complete'];
              } else {
                // Fallback for old data
                _addressController.text =
                    "${cust['unit_building_house_no'] ?? ''} ${cust['street'] ?? ''} ${cust['barangay'] ?? ''} ${cust['city'] ?? ''}"
                        .trim();
              }
            }
          }

          if (loadedClientAircons.isNotEmpty) {
            _clientAircons = loadedClientAircons;
          }

          _selectedAirconIds.clear();
          _selectedAirconIds.addAll(existingLinkedAircons);
          _selectedTechnicianIds.clear();
          _selectedTechnicianIds.addAll(existingLinkedTechs);
        }

        if (_airconTypes.isNotEmpty) {
          _selectedAirconTypeId = _airconTypes.first['id'];
        }
      });
    }
  }

  // --- Actions ---

  Future<void> _fetchClientAircons(int clientId) async {
    final units = await _supabase
        .from('aircons')
        .select(
          'id, remarks, horse_power, is_inverter, brands(brand_name), aircon_types(type_name)',
        )
        .eq('customer_id', clientId);

    if (mounted) {
      setState(() {
        _clientAircons = List<Map<String, dynamic>>.from(units);
        _selectedAirconIds.clear();
      });
    }
  }

  // Used for adding EXTRA units to existing clients
  void _addNewUnitDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Add New Unit"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Autocomplete<String>(
              optionsBuilder: (v) => v.text == ''
                  ? const Iterable<String>.empty()
                  : _brandOptions.where(
                      (o) => o.toLowerCase().contains(v.text.toLowerCase()),
                    ),
              onSelected: (s) => _selectedBrandName = s,
              fieldViewBuilder: (ctx, c, f, o) {
                c.addListener(() => _selectedBrandName = c.text);
                return TextField(
                  controller: c,
                  focusNode: f,
                  decoration: const InputDecoration(
                    labelText: "Brand",
                    border: OutlineInputBorder(),
                  ),
                );
              },
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<int>(
              value: _selectedAirconTypeId,
              decoration: const InputDecoration(
                labelText: "Type",
                border: OutlineInputBorder(),
              ),
              items: _airconTypes
                  .map(
                    (t) => DropdownMenuItem(
                      value: t['id'] as int,
                      child: Text(t['type_name']),
                    ),
                  )
                  .toList(),
              onChanged: (v) => _selectedAirconTypeId = v,
            ),
            const SizedBox(height: 12),
            // NEW FIELDS IN POPUP
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _hpController,
                    decoration: const InputDecoration(
                      labelText: "HP",
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: StatefulBuilder(
                    builder: (context, setState) {
                      return CheckboxListTile(
                        title: const Text("Inverter"),
                        value: _isInverter,
                        onChanged: (v) =>
                            setState(() => _isInverter = v ?? false),
                      );
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _unitRemarkController,
              decoration: const InputDecoration(
                labelText: "Location/Remarks",
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            onPressed: () async {
              if (_selectedClientId == null) return;
              final brandName = _selectedBrandName.trim();
              if (brandName.isEmpty) return;

              int brandId;
              final brandCheck = await _supabase
                  .from('brands')
                  .select('id')
                  .ilike('brand_name', brandName)
                  .maybeSingle();
              if (brandCheck != null) {
                brandId = brandCheck['id'];
              } else {
                final newBrand = await _supabase
                    .from('brands')
                    .insert({'brand_name': brandName})
                    .select('id')
                    .single();
                brandId = newBrand['id'];
              }

              await _supabase.from('aircons').insert({
                'customer_id': _selectedClientId,
                'brand_id': brandId,
                'aircon_type_id': _selectedAirconTypeId ?? 1,
                'remarks': _unitRemarkController.text,
                // Insert New Fields
                'horse_power': _hpController.text,
                'is_inverter': _isInverter,
              });

              if (mounted) {
                Navigator.pop(context);
                _fetchClientAircons(_selectedClientId!);
              }
            },
            child: const Text("Save Unit"),
          ),
        ],
      ),
    );
  }

  // --- SUBMISSION LOGIC (Smart Parse) ---
  Future<void> _submit() async {
    // 1. Validation
    if (!_isNewClient && _selectedClientId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Please select a customer"),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }
    if (_isNewClient) {
      if (_fullNameController.text.trim().isEmpty ||
          _addressController.text.trim().isEmpty ||
          _phoneController.text.trim().isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Name, Address, and Phone are required"),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }
    }

    setState(() => _isSubmitting = true);

    try {
      int? finalCustomerId = _selectedClientId;

      // 2. CREATE CUSTOMER (Parsing One Bar inputs)
      if (_isNewClient) {
        String firstName = '-';
        String lastName = '-';
        String? companyName;

        final fullName = _fullNameController.text.trim();

        if (_customerType == 'Commercial') {
          companyName = fullName;
          firstName =
              "Contact"; // Default placeholders for DB structure constraints
          lastName = "Person";
        } else {
          // Naive Name Splitter for Residential
          List<String> parts = fullName.split(' ');
          if (parts.isNotEmpty) {
            firstName = parts.first;
            if (parts.length > 1) {
              lastName = parts.sublist(1).join(' ');
            } else {
              lastName = '.'; // Placeholder if single name
            }
          }
        }

        final newCustomerData = {
          'first_name': firstName,
          'last_name': lastName,
          'company_name': companyName,
          'address_complete': _addressController.text
              .trim(), // Saving One Bar Address
          'contact_number': _phoneController.text.trim(),
          'email': _emailController.text.trim().isEmpty
              ? null
              : _emailController.text.trim(),
          'customer_type_id': _customerType == 'Commercial' ? 1 : 2,
          // Legacy fields can be left null or derived if needed
          'city': '',
          'barangay': '',
        };

        final custRes = await _supabase
            .from('customers')
            .insert(newCustomerData)
            .select('id')
            .single();
        finalCustomerId = custRes['id'] as int;
      }

      // 3. CREATE AIRCON (If New Client & Info Provided)
      // Check if user entered brand info
      if (_isNewClient && _selectedBrandName.trim().isNotEmpty) {
        final brandName = _selectedBrandName.trim();
        int brandId;
        final brandCheck = await _supabase
            .from('brands')
            .select('id')
            .ilike('brand_name', brandName)
            .maybeSingle();

        if (brandCheck != null) {
          brandId = brandCheck['id'];
        } else {
          final newBrand = await _supabase
              .from('brands')
              .insert({'brand_name': brandName})
              .select('id')
              .single();
          brandId = newBrand['id'];
        }

        final airconData = {
          'customer_id': finalCustomerId,
          'brand_id': brandId,
          'aircon_type_id': _selectedAirconTypeId ?? 1,
          'remarks': _unitRemarkController.text.trim().isEmpty
              ? 'Main Unit'
              : _unitRemarkController.text.trim(),
          'horse_power': _hpController.text.trim(), // New
          'is_inverter': _isInverter, // New
        };

        final newAircon = await _supabase
            .from('aircons')
            .insert(airconData)
            .select('id')
            .single();
        _selectedAirconIds.add(newAircon['id']);
      }

      // 4. CREATE JOB ORDER
      final typeRes = await _supabase
          .from('job_types')
          .select('id')
          .eq('job_type_name', _jobTypeName)
          .maybeSingle();
      final correctTypeId = typeRes != null
          ? (typeRes['id'] as int)
          : _jobTypeId;

      final scheduleDateTime = DateTime(
        _scheduleDate.year,
        _scheduleDate.month,
        _scheduleDate.day,
        _scheduleTime.hour,
        _scheduleTime.minute,
      );

      // Reference Number Logic
      String finalJoNumber = _externalRefController.text.trim();
      if (finalJoNumber.isEmpty) {
        if (widget.existingJob != null) {
          finalJoNumber = widget.existingJob!.displayId;
        } else {
          // Format: JO-TIMESTAMP (Last 5 digits)
          finalJoNumber =
              'JO-${DateTime.now().millisecondsSinceEpoch.toString().substring(8)}';
        }
      }

      final jobData = {
        'customer_id': finalCustomerId,
        'job_type_id': correctTypeId,
        'date_scheduled': scheduleDateTime.toUtc().toIso8601String(),
        'status': widget.existingJob?.status ?? 'Pending',
        'notes': _notesController.text.isNotEmpty
            ? _notesController.text
            : null,
        'client_jo_number': finalJoNumber,
      };

      int newJoId;

      if (widget.existingJob != null) {
        await _supabase
            .from('job_orders')
            .update(jobData)
            .eq('id', widget.existingJob!.dbId);
        newJoId = widget.existingJob!.dbId;
        // Clean slate for links
        await _supabase
            .from('job_order_aircons')
            .delete()
            .eq('job_order_id', newJoId);
        await _supabase
            .from('job_order_technicians')
            .delete()
            .eq('job_order_id', newJoId);
      } else {
        jobData['user_id'] = _supabase.auth.currentUser?.id;
        final joRes = await _supabase
            .from('job_orders')
            .insert(jobData)
            .select('id')
            .single();
        newJoId = joRes['id'] as int;
      }

      // 5. LINK ASSETS & TECHS
      for (int airconId in _selectedAirconIds) {
        await _supabase.from('job_order_aircons').insert({
          'job_order_id': newJoId,
          'aircon_id': airconId,
        });
      }
      for (int techId in _selectedTechnicianIds) {
        await _supabase.from('job_order_technicians').insert({
          'job_order_id': newJoId,
          'technician_id': techId,
          'role': 'Technician',
        });
      }

      // 6. LOG & CLOSE
      await ActivityLogger.log(
        type: widget.existingJob != null ? 'Update' : 'Create',
        details: widget.existingJob != null
            ? 'Updated Job $finalJoNumber'
            : 'Created Job $finalJoNumber',
      );

      if (mounted) {
        Navigator.pop(context, true);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Success!"),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error: $e"), backgroundColor: Colors.red),
        );
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return Dialog(
          insetPadding: constraints.maxWidth < 600
              ? EdgeInsets.zero
              : const EdgeInsets.all(40),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          child: Container(
            width: constraints.maxWidth < 600 ? double.infinity : 600,
            height:
                constraints.maxHeight * 0.90, // Slightly taller for new fields
            color: Colors.white,
            child: Column(
              children: [
                // --- STEP HEADER ---
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: const BoxDecoration(
                    border: Border(
                      bottom: BorderSide(color: Color(0xFFE2E8F0)),
                    ),
                  ),
                  child: Row(
                    children: [
                      if (_currentStep > 0)
                        IconButton(
                          icon: const Icon(Icons.arrow_back),
                          onPressed: () => setState(() => _currentStep--),
                        ),
                      Expanded(
                        child: Text(
                          _currentStep == 0
                              ? "Customer Type"
                              : _currentStep == 1
                              ? "Service Type"
                              : "Job Details",
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                ),

                // --- CONTENT ---
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: _buildCurrentStep(),
                  ),
                ),

                // --- FOOTER BUTTON ---
                Padding(
                  padding: const EdgeInsets.all(24),
                  child: SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      onPressed: _isSubmitting
                          ? null
                          : () {
                              if (_currentStep == 0) {
                                setState(() => _currentStep++);
                              } else if (_currentStep == 1) {
                                // Skip validation if simply choosing Service Type
                                setState(() => _currentStep++);
                              } else {
                                // Final Step: Submit
                                if (_isNewClient &&
                                    !_formKey.currentState!.validate()) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text("Please check fields"),
                                      backgroundColor: Colors.red,
                                    ),
                                  );
                                } else {
                                  _submit();
                                }
                              }
                            },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF2563EB),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: _isSubmitting
                          ? const CircularProgressIndicator(color: Colors.white)
                          : Text(
                              _currentStep == 2
                                  ? (widget.existingJob != null
                                        ? 'Update Job'
                                        : 'Create Job')
                                  : 'Next Step',
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildCurrentStep() {
    if (_currentStep == 0) return _stepCustomerType();
    if (_currentStep == 1) return _stepServiceType();
    return _stepDetails();
  }

  // --- STEP 0: CUSTOMER TYPE ---
  Widget _stepCustomerType() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _BigVisualOption(
          icon: Icons.home_rounded,
          title: "Residential",
          color: Colors.blue,
          isSelected: _customerType == 'Residential',
          onTap: () => setState(() => _customerType = 'Residential'),
        ),
        const SizedBox(height: 16),
        _BigVisualOption(
          icon: Icons.business_rounded,
          title: "Commercial",
          color: Colors.orange,
          isSelected: _customerType == 'Commercial',
          onTap: () => setState(() => _customerType = 'Commercial'),
        ),
      ],
    );
  }

  // --- STEP 1: SERVICE TYPE ---
  Widget _stepServiceType() {
    return SingleChildScrollView(
      child: Column(
        children: [
          _BigVisualOption(
            icon: Icons.build_circle_outlined,
            title: "Installation",
            color: Colors.blue,
            isSelected: _jobTypeName == 'Installation',
            onTap: () => setState(() => _jobTypeName = 'Installation'),
          ),
          const SizedBox(height: 12),
          _BigVisualOption(
            icon: Icons.cleaning_services_outlined,
            title: "Maintenance",
            color: Colors.green,
            isSelected: _jobTypeName == 'Maintenance',
            onTap: () => setState(() => _jobTypeName = 'Maintenance'),
          ),
          const SizedBox(height: 12),
          _BigVisualOption(
            icon: Icons.handyman_outlined,
            title: "Repair",
            color: Colors.orange,
            isSelected: _jobTypeName == 'Repair',
            onTap: () => setState(() => _jobTypeName = 'Repair'),
          ),
          const SizedBox(height: 12),
          _BigVisualOption(
            icon: Icons.remove_circle_outline,
            title: "De-installation",
            color: Colors.red,
            isSelected: _jobTypeName == 'De-installation',
            onTap: () => setState(() => _jobTypeName = 'De-installation'),
          ),
        ],
      ),
    );
  }

  // --- STEP 2: DETAILS (Consolidated) ---
  Widget _stepDetails() {
    final isEditing = widget.existingJob != null;

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. Existing vs New Toggle (Only show if not editing)
          if (!isEditing) ...[
            Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: _ToggleOption(
                      label: "Existing Client",
                      isSelected: !_isNewClient,
                      onTap: () => setState(() => _isNewClient = false),
                    ),
                  ),
                  Expanded(
                    child: _ToggleOption(
                      label: "New Entry",
                      isSelected: _isNewClient,
                      onTap: () => setState(() => _isNewClient = true),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
          ],

          // 2. CLIENT SELECTION / ENTRY
          if (!_isNewClient) ...[
            const Text(
              "Select Customer",
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            // Existing Client Search
            Autocomplete<Map<String, dynamic>>(
              optionsBuilder: (v) {
                if (v.text.isEmpty)
                  return const Iterable<Map<String, dynamic>>.empty();
                return _existingClients.where((c) {
                  final name =
                      c['company_name'] ??
                      '${c['first_name']} ${c['last_name']}';
                  return name.toLowerCase().contains(v.text.toLowerCase());
                });
              },
              displayStringForOption: (c) =>
                  c['company_name'] ?? '${c['first_name']} ${c['last_name']}',
              onSelected: (selection) {
                setState(() {
                  _selectedClientId = selection['id'];
                  _fetchClientAircons(_selectedClientId!);
                });
              },
              fieldViewBuilder: (ctx, ctrl, focus, onSub) {
                // If editing, use the display controller which is locked
                return TextField(
                  controller: isEditing ? _customerDisplayController : ctrl,
                  focusNode: focus,
                  readOnly: isEditing,
                  decoration: InputDecoration(
                    hintText: "Search name...",
                    prefixIcon: isEditing
                        ? const Icon(Icons.lock)
                        : const Icon(Icons.search),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    filled: true,
                    fillColor: isEditing ? Colors.grey[100] : Colors.white,
                  ),
                );
              },
            ),

            // Unit Selection for Existing
            if (_selectedClientId != null) ...[
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    "Select Units",
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  TextButton.icon(
                    onPressed: _addNewUnitDialog,
                    icon: const Icon(Icons.add, size: 16),
                    label: const Text("Add Unit"),
                  ),
                ],
              ),
              if (_clientAircons.isNotEmpty)
                ..._clientAircons.map((unit) {
                  final brand = unit['brands']?['brand_name'] ?? 'Generic';
                  final type = unit['aircon_types']?['type_name'] ?? 'Unit';
                  final hp = unit['horse_power'] != null
                      ? "${unit['horse_power']}HP"
                      : "";
                  final inv = unit['is_inverter'] == true ? "Inverter" : "";

                  return CheckboxListTile(
                    title: Text("$brand $type $hp $inv".trim()),
                    subtitle: Text(unit['remarks'] ?? ''),
                    value: _selectedAirconIds.contains(unit['id']),
                    onChanged: (v) {
                      setState(() {
                        if (v == true)
                          _selectedAirconIds.add(unit['id']);
                        else
                          _selectedAirconIds.remove(unit['id']);
                      });
                    },
                  );
                })
              else
                const Padding(
                  padding: EdgeInsets.all(8.0),
                  child: Text(
                    "No units found.",
                    style: TextStyle(color: Colors.grey),
                  ),
                ),
            ],
          ] else ...[
            // NEW CLIENT FORM ("One Bar" inputs)
            Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    "Client Information",
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.blue,
                    ),
                  ),
                  const SizedBox(height: 12),

                  // ONE BAR NAME
                  TextFormField(
                    controller: _fullNameController,
                    decoration: InputDecoration(
                      labelText: _customerType == 'Residential'
                          ? "Full Name"
                          : "Company Name / Contact Person",
                      hintText: "e.g. Juan Dela Cruz",
                      prefixIcon: const Icon(Icons.person_outline),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    validator: (v) => v!.isEmpty ? "Required" : null,
                  ),
                  const SizedBox(height: 12),

                  // ONE BAR ADDRESS
                  TextFormField(
                    controller: _addressController,
                    maxLines: 2,
                    decoration: InputDecoration(
                      labelText: "Complete Address",
                      hintText: "Unit, Street, Barangay, City, Landmark...",
                      prefixIcon: const Icon(Icons.location_on_outlined),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    validator: (v) => v!.isEmpty ? "Required" : null,
                  ),
                  const SizedBox(height: 12),

                  // CONTACT
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _phoneController,
                          keyboardType: TextInputType.phone,
                          decoration: InputDecoration(
                            labelText: "Phone Number",
                            prefixIcon: const Icon(Icons.phone),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          validator: _validatePhone,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextFormField(
                          controller: _emailController,
                          keyboardType: TextInputType.emailAddress,
                          decoration: InputDecoration(
                            labelText: "Email (Optional)",
                            prefixIcon: const Icon(Icons.email_outlined),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 24),
                  const Text(
                    "First Unit Details",
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.blue,
                    ),
                  ),
                  const SizedBox(height: 12),

                  // BRAND & TYPE ROW
                  Row(
                    children: [
                      Expanded(
                        child: LayoutBuilder(
                          builder: (ctx, constr) {
                            return Autocomplete<String>(
                              optionsBuilder: (v) => v.text == ''
                                  ? const Iterable<String>.empty()
                                  : _brandOptions.where(
                                      (o) => o.toLowerCase().contains(
                                        v.text.toLowerCase(),
                                      ),
                                    ),
                              onSelected: (s) => _selectedBrandName = s,
                              fieldViewBuilder: (ctx, c, f, o) {
                                c.addListener(
                                  () => _selectedBrandName = c.text,
                                );
                                return TextFormField(
                                  controller: c,
                                  focusNode: f,
                                  decoration: InputDecoration(
                                    labelText: "Brand",
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                  ),
                                );
                              },
                            );
                          },
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: DropdownButtonFormField<int>(
                          value: _selectedAirconTypeId,
                          decoration: InputDecoration(
                            labelText: "Type",
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          items: _airconTypes
                              .map(
                                (t) => DropdownMenuItem(
                                  value: t['id'] as int,
                                  child: Text(t['type_name']),
                                ),
                              )
                              .toList(),
                          onChanged: (v) =>
                              setState(() => _selectedAirconTypeId = v),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // HP & INVERTER ROW (NEW)
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _hpController,
                          decoration: InputDecoration(
                            labelText: "Horsepower",
                            hintText: "e.g. 1.5 HP",
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.grey),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: CheckboxListTile(
                            contentPadding: EdgeInsets.zero,
                            title: const Text("Inverter?"),
                            value: _isInverter,
                            onChanged: (v) =>
                                setState(() => _isInverter = v ?? false),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  TextFormField(
                    controller: _unitRemarkController,
                    decoration: InputDecoration(
                      labelText: "Location / Notes",
                      hintText: "e.g. Master Bedroom",
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],

          const SizedBox(height: 24),
          const Divider(),
          const SizedBox(height: 24),

          // 3. SCHEDULE & REF
          const Text(
            "Schedule & Reference",
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
          const SizedBox(height: 12),

          TextField(
            controller: _externalRefController,
            decoration: InputDecoration(
              labelText: "Reference No. (Optional)",
              hintText: "Auto-generates if blank",
              prefixIcon: const Icon(Icons.tag),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
          const SizedBox(height: 12),

          Row(
            children: [
              Expanded(
                child: ListTile(
                  tileColor: Colors.grey[50],
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: BorderSide(color: Colors.grey.shade300),
                  ),
                  leading: const Icon(Icons.calendar_month, color: Colors.blue),
                  title: Text("${_scheduleDate.toLocal()}".split(' ')[0]),
                  onTap: () async {
                    final d = await showDatePicker(
                      context: context,
                      initialDate: _scheduleDate,
                      firstDate: DateTime(2020),
                      lastDate: DateTime(2030),
                    );
                    if (d != null) setState(() => _scheduleDate = d);
                  },
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ListTile(
                  tileColor: Colors.grey[50],
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: BorderSide(color: Colors.grey.shade300),
                  ),
                  leading: const Icon(Icons.access_time, color: Colors.orange),
                  title: Text(_scheduleTime.format(context)),
                  onTap: () async {
                    final t = await showTimePicker(
                      context: context,
                      initialTime: _scheduleTime,
                    );
                    if (t != null) {
                      // Simple conflict check logic here if needed
                      setState(() => _scheduleTime = t);
                    }
                  },
                ),
              ),
            ],
          ),

          const SizedBox(height: 24),
          const Text(
            "Technicians",
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
          const SizedBox(height: 8),

          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _availableTechnicians.map((tech) {
              final id = tech['id'] as int;
              final name = "${tech['first_name']} ${tech['last_name'][0]}.";
              final isSelected = _selectedTechnicianIds.contains(id);
              return FilterChip(
                label: Text(name),
                selected: isSelected,
                onSelected: (bool selected) {
                  setState(() {
                    if (selected)
                      _selectedTechnicianIds.add(id);
                    else
                      _selectedTechnicianIds.remove(id);
                  });
                },
              );
            }).toList(),
          ),

          const SizedBox(height: 24),
          const Text(
            "Notes",
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _notesController,
            maxLines: 2,
            decoration: InputDecoration(
              hintText: "Gate pass needed, dogs, etc...",
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              filled: true,
              fillColor: Colors.grey[50],
            ),
          ),
        ],
      ),
    );
  }
}

// --- VISUAL HELPERS ---

class _BigVisualOption extends StatelessWidget {
  final IconData icon;
  final String title;
  final Color color;
  final bool isSelected;
  final VoidCallback onTap;

  const _BigVisualOption({
    required this.icon,
    required this.title,
    required this.color,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected ? color.withOpacity(0.1) : Colors.white,
          border: Border.all(
            color: isSelected ? color : Colors.grey.shade200,
            width: 2,
          ),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            Icon(icon, color: isSelected ? color : Colors.grey, size: 28),
            const SizedBox(width: 16),
            Text(
              title,
              style: TextStyle(
                fontSize: 16,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              ),
            ),
            const Spacer(),
            if (isSelected) Icon(Icons.check_circle, color: color),
          ],
        ),
      ),
    );
  }
}

class _ToggleOption extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;
  const _ToggleOption({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 2,
                  ),
                ]
              : null,
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            color: isSelected ? Colors.blue : Colors.grey,
          ),
        ),
      ),
    );
  }
}

// UPDATED: Now uses TextFormField for Validation
class _SimpleInput extends StatelessWidget {
  final TextEditingController controller;
  final IconData? icon;
  final String hint;
  final bool isRequired;
  final String? Function(String?)? validator;
  final TextInputType? keyboardType;
  final TextCapitalization textCapitalization;

  const _SimpleInput({
    required this.controller,
    this.icon,
    required this.hint,
    this.isRequired = false,
    this.validator,
    this.keyboardType,
    this.textCapitalization = TextCapitalization.none,
  });

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      textCapitalization: textCapitalization,
      validator: (value) {
        if (isRequired && (value == null || value.isEmpty)) {
          return '$hint is required';
        }
        if (validator != null) {
          return validator!(value);
        }
        return null;
      },
      decoration: InputDecoration(
        label: RichText(
          text: TextSpan(
            text: hint,
            style: TextStyle(color: Colors.grey[600], fontSize: 14),
            children: [
              if (isRequired)
                const TextSpan(
                  text: ' *',
                  style: TextStyle(color: Colors.red),
                ),
            ],
          ),
        ),
        prefixIcon: icon != null ? Icon(icon, size: 20) : null,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
        filled: true,
        fillColor: Colors.white,
      ),
    );
  }
}

class _JobCard extends StatelessWidget {
  final JobOrder order;
  const _JobCard({required this.order});

  @override
  Widget build(BuildContext context) {
    // 1. Format Date
    String dateText = "${order.startDateTime.month}/${order.startDateTime.day}";
    String timeText = TimeOfDay.fromDateTime(
      order.startDateTime,
    ).format(context);

    if (order.scheduledEndDate != null) {
      dateText +=
          " - ${order.scheduledEndDate!.month}/${order.scheduledEndDate!.day}";
    } else {
      dateText += " at $timeText";
    }

    // 2. Visuals
    final bool isCorp = order.isCorporate;
    final Color typeColor = isCorp ? AppTheme.primary : Colors.teal;

    return Container(
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: AppTheme.borderRadius,
        boxShadow: AppTheme.shadow,
        border: Border.all(color: AppTheme.borderColor),
      ),
      child: ClipRRect(
        borderRadius: AppTheme.borderRadius,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppTheme.surface,
            border: Border(left: BorderSide(color: typeColor, width: 4)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ROW 1: Client Name, JO#, and Status
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Row(
                      children: [
                        // 1. Client Name (Flexible to handle long names)
                        Flexible(
                          child: Text(
                            order.clientName,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.black87,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        // 2. The ID (Subtitle Style)
                        const SizedBox(width: 8),
                        Text(
                          order.displayId, // e.g., "JO-1024"
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.grey[600],
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),

                  // 3. Status Badge
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: AppTheme.warning.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      order.status,
                      style: const TextStyle(
                        fontSize: 10,
                        color: Colors.deepOrange,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 4),

              // ROW 2: Job Type (Subtitle)
              Text(
                order.jobType,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: typeColor,
                ),
              ),

              // ROW 3: Action Tags (Unbilled/Unpaid/Ops Issues)
              if (order.isUnbilled ||
                  order.isUnpaid ||
                  order.hasNoTechs ||
                  order.hasNoUnits)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 4,
                    children: [
                      if (order.isUnbilled)
                        const _StatusTag(label: "Unbilled", color: Colors.red),

                      if (order.isUnpaid)
                        const _StatusTag(label: "Unpaid", color: Colors.orange),

                      if (order.hasNoTechs)
                        const _StatusTag(
                          label: "No Tech",
                          color: Colors.purple,
                        ),

                      if (order.hasNoUnits)
                        const _StatusTag(
                          label: "No Unit",
                          color: Colors.blueGrey,
                        ),
                    ],
                  ),
                ),

              const SizedBox(height: 8),
              const Divider(height: 1),
              const SizedBox(height: 8),

              // ROW 4: Location & Date
              Row(
                children: [
                  const Icon(Icons.location_on, size: 14, color: Colors.grey),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      order.location,
                      style: AppTheme.caption,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  const Icon(
                    Icons.calendar_today,
                    size: 14,
                    color: Colors.grey,
                  ),
                  const SizedBox(width: 4),
                  Text(dateText, style: AppTheme.caption),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatusTag extends StatelessWidget {
  final String label;
  final Color color;
  const _StatusTag({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 10,
          color: color,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}
