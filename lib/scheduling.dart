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

  // NEW: Billing Status Flags
  final bool isUnbilled;
  final bool isUnpaid;

  // NEW: Operational Flags
  final bool hasNoTechs; // <--- ADD THIS
  final bool hasNoUnits; // <--- ADD THIS

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
    // Initialize new flags
    required this.isUnbilled,
    required this.isUnpaid,
    required this.hasNoTechs, // <--- ADD THIS
    required this.hasNoUnits, // <--- ADD THIS
  });
}

// --- Main Screen ---

class SchedulingScreen extends StatefulWidget {
  // NEW: Accept an optional search query (like a Job ID)
  final String? initialSearch;

  const SchedulingScreen({super.key, this.initialSearch});

  @override
  State<SchedulingScreen> createState() => _SchedulingScreenState();
}

class _SchedulingScreenState extends State<SchedulingScreen> {
  List<JobOrder> _orders = [];
  bool _isLoading = true;

  // Search State
  late TextEditingController _searchController; // Changed to late
  String _searchQuery = '';
  bool _isSearchActive = false; // For mobile toggle

  // Calendar State
  DateTime _focusedDate = DateTime.now();
  DateTime _selectedDate = DateTime.now();

  // Sort State
  bool _sortOldestFirst = true;

  // Filter State for "Action Needed" view
  bool _showActionItems = false;

  @override
  void initState() {
    super.initState();

    // NEW: Initialize search with the passed value (if any)
    String initialText = widget.initialSearch ?? '';
    _searchController = TextEditingController(text: initialText);

    if (initialText.isNotEmpty) {
      _searchQuery = initialText.toLowerCase();
      _isSearchActive = true; // Auto-expand search on mobile
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
            '*, customers(id, first_name, last_name, company_name, city, barangay, customer_type_id), job_types(job_type_name), job_order_line_items(count), payments(count), job_order_technicians(count), job_order_aircons(count)',
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
          final city = customer['city'] ?? '';
          final brgy = customer['barangay'] ?? '';
          location = "$city $brgy".trim();
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

        // Status Logic
        final int itemsCount = row['job_order_line_items'][0]['count'] as int;
        final bool unbilled = itemsCount == 0;
        final int payCount = row['payments'][0]['count'] as int;
        final bool unpaid = itemsCount > 0 && payCount == 0;

        // Check for Missing Ops Info
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

  // --- ACTIONS ---

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

  // Get all jobs that need attention
  List<JobOrder> _getActionableJobs() {
    final list = _orders
        .where(
          (o) => o.isUnbilled || o.isUnpaid || o.hasNoTechs || o.hasNoUnits,
        )
        .toList();

    list.sort((a, b) {
      int comparison = a.startDateTime.compareTo(b.startDateTime);
      return _sortOldestFirst ? comparison : -comparison;
    });

    return list;
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
    final isMobileView = MediaQuery.of(context).size.width < 600;

    // 1. CALCULATE ACTIONABLE JOBS FIRST
    final actionableJobs = _getActionableJobs();
    final actionableJobsCount = actionableJobs.length;

    // --- SEARCH FILTER LOGIC ---
    List<JobOrder> displayedJobs;

    if (_searchQuery.isNotEmpty) {
      // Global Search: Ignore dates/tabs, search EVERYTHING
      displayedJobs = _orders.where((job) {
        return job.clientName.toLowerCase().contains(_searchQuery) ||
            job.displayId.toLowerCase().contains(_searchQuery) ||
            job.location.toLowerCase().contains(_searchQuery) ||
            job.status.toLowerCase().contains(_searchQuery) ||
            // NEW: Allow searching by Database ID (hidden ID)
            job.dbId.toString().contains(_searchQuery);
      }).toList();
    } else {
      // Standard View: Calendar OR Action Items
      final calendarJobs = _getJobsForDay(_selectedDate);
      displayedJobs = _showActionItems ? actionableJobs : calendarJobs;
    }
    // ---------------------------

    return AppShell(
      selectedIndex: 1,
      body: LoadingOverlay(
        isLoading: _isLoading,
        child: Container(
          color: const Color(0xFFF8FAFC),
          child: Column(
            children: [
              // --- 1. SMART HEADER (Search Integrated) ---
              _buildHeader(isMobileView),

              const Divider(height: 1),

              // --- SCROLLABLE CONTENT ---
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // HIDE Calendar/Action Banner IF SEARCHING
                      if (_searchQuery.isEmpty) ...[
                        // 1. ACTION BANNER
                        if (actionableJobsCount > 0)
                          GestureDetector(
                            onTap: () {
                              setState(() {
                                _showActionItems = !_showActionItems;
                              });
                            },
                            child: AnimatedContainer(
                              duration: AppTheme.animationDuration,
                              width: double.infinity,
                              padding: const EdgeInsets.symmetric(
                                vertical: 16,
                                horizontal: 24,
                              ),
                              decoration: BoxDecoration(
                                color: _showActionItems
                                    ? AppTheme.surface
                                    : AppTheme.warning.withOpacity(0.1),
                                border: Border(
                                  bottom: BorderSide(
                                    color: _showActionItems
                                        ? AppTheme.borderColor
                                        : AppTheme.warning.withOpacity(0.3),
                                  ),
                                ),
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    _showActionItems
                                        ? Icons.arrow_back
                                        : Icons.warning_amber_rounded,
                                    color: _showActionItems
                                        ? AppTheme.textPrimary
                                        : AppTheme.warning,
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Text(
                                      _showActionItems
                                          ? "Back to Calendar"
                                          : "$actionableJobsCount Jobs require attention",
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: _showActionItems
                                            ? AppTheme.textPrimary
                                            : AppTheme.warning,
                                        fontSize: 15,
                                      ),
                                    ),
                                  ),
                                  // Optional "View" link if not expanded
                                  if (!_showActionItems)
                                    const Text(
                                      "View All",
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: AppTheme.primary,
                                        decoration: TextDecoration.underline,
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ),

                        // 2. CALENDAR GRID
                        if (!_showActionItems)
                          Container(
                            color: Colors.white,
                            padding: const EdgeInsets.only(bottom: 16),
                            child: _buildCalendarGrid(),
                          ),
                      ],

                      const Divider(height: 1),

                      // 3. JOB LIST
                      Padding(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Dynamic Title
                            Text(
                              _searchQuery.isNotEmpty
                                  ? "Search Results (${displayedJobs.length})"
                                  : (_showActionItems
                                        ? "Pending Actions"
                                        : "Schedule for ${_monthName(_selectedDate.month)} ${_selectedDate.day}"),
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF64748B),
                              ),
                            ),
                            const SizedBox(height: 16),

                            if (displayedJobs.isEmpty)
                              Center(
                                child: Padding(
                                  padding: const EdgeInsets.all(32.0),
                                  child: Column(
                                    children: [
                                      Icon(
                                        _searchQuery.isNotEmpty
                                            ? Icons.search_off
                                            : Icons.event_available,
                                        size: 48,
                                        color: Colors.grey[300],
                                      ),
                                      const SizedBox(height: 12),
                                      Text(
                                        _searchQuery.isNotEmpty
                                            ? "No jobs found for '$_searchQuery'"
                                            : "No jobs listed.",
                                        style: const TextStyle(
                                          color: Colors.grey,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              )
                            else
                              ListView.separated(
                                shrinkWrap: true,
                                physics: const NeverScrollableScrollPhysics(),
                                itemCount: displayedJobs.length,
                                separatorBuilder: (ctx, i) =>
                                    const SizedBox(height: 12),
                                itemBuilder: (ctx, i) => GestureDetector(
                                  onTap: () =>
                                      _showJobDetails(displayedJobs[i]),
                                  child: _JobCard(order: displayedJobs[i]),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(bool isMobile) {
    // SCENARIO 1: Mobile Search Active (Expanded Search Bar)
    if (isMobile && _isSearchActive) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        color: Colors.white,
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: _searchController,
                autofocus: true,
                decoration: InputDecoration(
                  hintText: "Search name, JO#, location...",
                  prefixIcon: const Icon(Icons.search, color: Colors.grey),
                  filled: true,
                  fillColor: Colors.grey[100],
                  contentPadding: const EdgeInsets.symmetric(
                    vertical: 0,
                    horizontal: 16,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            TextButton(
              onPressed: () {
                setState(() {
                  _isSearchActive = false;
                  _searchController.clear();
                });
              },
              child: const Text("Cancel"),
            ),
          ],
        ),
      );
    }

    // SCENARIO 2: Normal Header (Desktop or Mobile Default)
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: isMobile ? 16 : 32,
        vertical: 16,
      ),
      color: Colors.white,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Left: Month Selector or Title
          if (_showActionItems)
            const Text(
              "Pending Actions",
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: Color(0xFF1E293B),
              ),
            )
          else
            Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.chevron_left),
                  onPressed: () => _changeMonth(-1),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
                const SizedBox(width: 8),
                Text(
                  "${_monthName(_focusedDate.month)} ${_focusedDate.year}",
                  style: TextStyle(
                    fontSize: isMobile ? 18 : 20,
                    fontWeight: FontWeight.w800,
                    color: const Color(0xFF1E293B),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: const Icon(Icons.chevron_right),
                  onPressed: () => _changeMonth(1),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ],
            ),

          // Right: Search & Add
          if (!_showActionItems)
            Row(
              children: [
                // Search Widget
                if (!isMobile)
                  Container(
                    width: 220,
                    height: 40,
                    margin: const EdgeInsets.only(right: 12),
                    child: TextField(
                      controller: _searchController,
                      decoration: InputDecoration(
                        hintText: "Search...",
                        prefixIcon: const Icon(
                          Icons.search,
                          size: 20,
                          color: Colors.grey,
                        ),
                        filled: true,
                        fillColor: Colors.grey[100],
                        contentPadding: const EdgeInsets.symmetric(vertical: 0),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                  )
                else
                  IconButton(
                    icon: const Icon(Icons.search),
                    onPressed: () => setState(() => _isSearchActive = true),
                  ),

                const SizedBox(width: 8),

                // Add Button
                ElevatedButton.icon(
                  onPressed: () => _onAddOrEdit(),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2563EB),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  icon: const Icon(Icons.add, size: 18),
                  label: Text(
                    isMobile ? 'Add' : 'Add Job',
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
              ],
            )
          else
            // NEW: COUNTER & SORT (For Pending Actions View)
            Row(
              children: [
                // 1. The Counter
                Text(
                  "${_getActionableJobs().length} Items",
                  style: const TextStyle(
                    color: Colors.grey,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(width: 12),

                // 2. The Sort Button
                OutlinedButton.icon(
                  onPressed: () {
                    setState(() {
                      _sortOldestFirst = !_sortOldestFirst;
                    });
                  },
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    side: BorderSide(color: Colors.grey.shade300),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  icon: Icon(
                    _sortOldestFirst
                        ? Icons.arrow_upward
                        : Icons.arrow_downward,
                    size: 16,
                    color: Colors.black87,
                  ),
                  label: Text(
                    _sortOldestFirst ? "Oldest" : "Newest",
                    style: const TextStyle(color: Colors.black87, fontSize: 13),
                  ),
                ),
              ],
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
                          fontSize: 12,
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
            childAspectRatio: 1.2,
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
            final hasJobs = _getJobsForDay(currentDay).isNotEmpty;

            return GestureDetector(
              onTap: () => setState(() => _selectedDate = currentDay),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                margin: const EdgeInsets.all(6),
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
                  boxShadow: isSelected ? AppTheme.glow(AppTheme.primary) : [],
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
                    const SizedBox(height: 4),
                    if (hasJobs)
                      Container(
                        width: 6,
                        height: 6,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: isSelected ? Colors.white : AppTheme.warning,
                        ),
                      )
                    else
                      const SizedBox(height: 6),
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
  int _currentStep = 0;
  bool _isSubmitting = false;
  final _supabase = Supabase.instance.client;
  final _formKey = GlobalKey<FormState>();
  final _customerDisplayController = TextEditingController();
  List<Map<String, dynamic>> _availableTechnicians = [];
  final List<int> _selectedTechnicianIds = [];

  // Data
  String _jobTypeName = 'Installation';
  int? _jobTypeId;
  bool _isNewClient = false;
  List<Map<String, dynamic>> _existingClients = [];
  List<String> _brandOptions = [];
  List<Map<String, dynamic>> _airconTypes = [];

  int? _selectedClientId;
  List<Map<String, dynamic>> _clientAircons = [];
  final List<int> _selectedAirconIds = [];

  // New Client Data
  final _firstNameController = TextEditingController();
  final _middleNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _companyController = TextEditingController();
  final _jobPositionController = TextEditingController();
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();
  final _unitController = TextEditingController();
  final _streetController = TextEditingController();
  final _villageController = TextEditingController();
  final _barangayController = TextEditingController();
  final _cityController = TextEditingController();
  final _landmarkController = TextEditingController();

  String _selectedBrandName = '';
  int? _selectedAirconTypeId;
  final _unitRemarkController = TextEditingController();

  final _externalRefController = TextEditingController();

  late DateTime _scheduleDate;
  TimeOfDay _scheduleTime = const TimeOfDay(hour: 9, minute: 0);
  final _notesController = TextEditingController();

  // Check for conflicts on specific date/time
  Future<bool> _checkScheduleConflict(
    DateTime proposedDate,
    TimeOfDay proposedTime,
  ) async {
    // 1. Define the range (e.g., check the whole day)
    final startOfDay = DateTime(
      proposedDate.year,
      proposedDate.month,
      proposedDate.day,
    );
    final endOfDay = startOfDay.add(const Duration(hours: 23, minutes: 59));

    // 2. Fetch jobs for that day
    final res = await _supabase
        .from('job_orders')
        .select(
          'id, date_scheduled, client_jo_number, customers(first_name, last_name, company_name)',
        )
        .gte('date_scheduled', startOfDay.toUtc().toIso8601String())
        .lte('date_scheduled', endOfDay.toUtc().toIso8601String())
        .neq('status', 'Completed') // Ignore completed jobs? Up to you.
        .neq('status', 'Cancelled');

    // 3. Analyze for time overlap (e.g., within 2 hours buffer)
    for (var job in res) {
      // Skip self if editing
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

      // CONFLICT THRESHOLD: 120 minutes (2 hours)
      // If another job starts within 2 hours of this one, flag it.
      if (diff < 120) {
        return true; // Conflict found
      }
    }
    return false; // No conflict
  }

  @override
  void initState() {
    super.initState();
    // Initialize Data from existing job or default
    if (widget.existingJob != null) {
      _jobTypeName = widget.existingJob!.jobType;
      _scheduleDate = widget.existingJob!.startDateTime;
      _scheduleTime = TimeOfDay.fromDateTime(widget.existingJob!.startDateTime);
      _notesController.text = widget.existingJob!.notes ?? '';
      _selectedClientId = widget.existingJob!.customerId;
      _externalRefController.text = widget.existingJob!.displayId;

      // In a real edit scenario, we would also fetch the client details if _selectedClientId is set
      // For now, we just set the ID to trigger the dropdown selection
    } else {
      _scheduleDate = widget.initialDate ?? DateTime.now();
    }

    _fetchInitialData();
  }

  Future<void> _fetchInitialData() async {
    // 1. Fetch Master Data
    final customers = await _supabase
        .from('customers')
        .select('id, first_name, last_name, company_name, city, barangay')
        .order('last_name', ascending: true);

    final types = await _supabase.from('job_types').select();
    final brands = await _supabase.from('brands').select().order('brand_name');
    final acTypes = await _supabase.from('aircon_types').select();

    final techs = await _supabase
        .from('technicians')
        .select('id, first_name, last_name')
        .order('first_name');

    // 2. Prepare Variables for Edit Mode
    List<int> existingLinkedAircons = [];
    List<int> existingLinkedTechs = [];
    List<Map<String, dynamic>> loadedClientAircons = [];

    if (widget.existingJob != null) {
      // A. Fetch Linked Aircon IDs
      final linkedAcRes = await _supabase
          .from('job_order_aircons')
          .select('aircon_id')
          .eq('job_order_id', widget.existingJob!.dbId);
      existingLinkedAircons = List<int>.from(
        linkedAcRes.map((e) => e['aircon_id']),
      );

      // B. Fetch Linked Technician IDs
      final linkedTechRes = await _supabase
          .from('job_order_technicians')
          .select('technician_id')
          .eq('job_order_id', widget.existingJob!.dbId);
      existingLinkedTechs = List<int>.from(
        linkedTechRes.map((e) => e['technician_id']),
      );

      // C. FIX: Fetch the Customer's Aircon List MANUALLY here
      // (We do this here to avoid calling _fetchClientAircons which clears selections)
      // 1. Create a local variable (Dart trusts local variables)
      final int? custId = widget.existingJob?.customerId;

      // 2. Check the LOCAL variable
      if (custId != null) {
        final units = await _supabase
            .from('aircons')
            .select('id, remarks, brands(brand_name), aircon_types(type_name)')
            .eq(
              'customer_id',
              custId,
            ); // 3. Use the LOCAL variable here (Error gone!)

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
          // --- CREATE MODE ---
          final installType = types.firstWhere(
            (t) => t['job_type_name'] == 'Installation',
            orElse: () => types.first,
          );
          _jobTypeId = installType['id'];
        } else {
          // --- EDIT MODE ---

          // 1. Set Customer Text
          if (_selectedClientId != null) {
            final cust = _existingClients.firstWhere(
              (c) => c['id'] == _selectedClientId,
              orElse: () => {},
            );
            if (cust.isNotEmpty) {
              _customerDisplayController.text =
                  cust['company_name'] ??
                  '${cust['first_name']} ${cust['last_name']}';
            }
          }

          // 2. Populate Aircon List (from our manual fetch above)
          if (loadedClientAircons.isNotEmpty) {
            _clientAircons = loadedClientAircons;
          }

          // 3. Restore Checkboxes (Now safe from being cleared)
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

  Future<void> _fetchClientAircons(int clientId) async {
    final units = await _supabase
        .from('aircons')
        .select('id, remarks, brands(brand_name), aircon_types(type_name)')
        .eq('customer_id', clientId);

    if (mounted) {
      setState(() {
        _clientAircons = List<Map<String, dynamic>>.from(units);
        _selectedAirconIds.clear();
      });
    }
  }

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
              if (brandCheck != null)
                brandId = brandCheck['id'];
              else {
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

  // --- VALIDATORS ---
  String? _validatePhone(String? value) {
    if (value == null || value.isEmpty) return 'Required';
    final trimmed = value.trim();
    if (!RegExp(r'^(09\d{9}|\d{7,10})$').hasMatch(trimmed)) return 'Invalid #';
    return null;
  }

  String? _validateEmail(String? value) {
    if (value == null || value.isEmpty) return null;
    if (!value.contains('@') || !value.contains('.')) return 'Invalid email';
    return null;
  }

  // --- SUBMIT ---
  // 2. FIXED SUBMIT METHOD
  Future<void> _submit() async {
    // Pre-validation
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
      // Validate required fields explicitly
      if (_firstNameController.text.trim().isEmpty ||
          _lastNameController.text.trim().isEmpty ||
          _phoneController.text.trim().isEmpty ||
          _streetController.text.trim().isEmpty ||
          _barangayController.text.trim().isEmpty ||
          _cityController.text.trim().isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Please fill in all required fields"),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }
    }

    setState(() => _isSubmitting = true);

    try {
      int? finalCustomerId = _selectedClientId;

      // 1. CREATE CUSTOMER (if new)
      if (_isNewClient) {
        print("Creating new customer...");

        final newCustomerData = {
          'first_name': _firstNameController.text.trim(),
          'middle_name': _middleNameController.text.trim().isEmpty
              ? null
              : _middleNameController.text.trim(),
          'last_name': _lastNameController.text.trim(),
          'company_name': _companyController.text.trim().isEmpty
              ? null
              : _companyController.text.trim(),
          'job_position': _jobPositionController.text.trim().isEmpty
              ? null
              : _jobPositionController.text.trim(),
          'contact_number': _phoneController.text.trim(),
          'email': _emailController.text.trim().isEmpty
              ? null
              : _emailController.text.trim(),
          'unit_building_house_no': _unitController.text.trim(),
          'street': _streetController.text.trim(),
          'subdivision_village': _villageController.text.trim(),
          'barangay': _barangayController.text.trim(),
          'city': _cityController.text.trim(),
          'landmark': _landmarkController.text.trim().isEmpty
              ? null
              : _landmarkController.text.trim(),
          'customer_type_id': _companyController.text.trim().isEmpty ? 2 : 1,
        };

        final custRes = await _supabase
            .from('customers')
            .insert(newCustomerData)
            .select('id')
            .single();

        finalCustomerId = custRes['id'] as int;
      }

      if (finalCustomerId == null) {
        throw "Customer selection error. Please try again.";
      }

      // 2. CREATE AIRCON (if new client)
      if (_isNewClient && _selectedBrandName.trim().isNotEmpty) {
        print("Creating aircon unit...");

        final brandName = _selectedBrandName.trim();
        int brandId;

        // Check if brand exists
        final brandCheck = await _supabase
            .from('brands')
            .select('id')
            .ilike('brand_name', brandName)
            .maybeSingle();

        if (brandCheck != null) {
          brandId = brandCheck['id'] as int;
        } else {
          // Create new brand
          final newBrand = await _supabase
              .from('brands')
              .insert({'brand_name': brandName})
              .select('id')
              .single();
          brandId = newBrand['id'] as int;
        }

        // Create aircon unit
        final airconData = {
          'customer_id': finalCustomerId,
          'brand_id': brandId,
          'aircon_type_id': _selectedAirconTypeId ?? 1,
          'remarks': _unitRemarkController.text.trim().isEmpty
              ? 'New Unit'
              : _unitRemarkController.text.trim(),
        };

        final newAircon = await _supabase
            .from('aircons')
            .insert(airconData)
            .select('id')
            .single();

        final airconId = newAircon['id'] as int;
        _selectedAirconIds.add(airconId);
      }

      // 3. CREATE/UPDATE JOB ORDER
      print("Creating/updating job order...");

      // Get correct job type ID
      final typeRes = await _supabase
          .from('job_types')
          .select('id')
          .eq('job_type_name', _jobTypeName)
          .maybeSingle();

      final correctTypeId = typeRes != null
          ? (typeRes['id'] as int)
          : _jobTypeId;

      // Create DateTime
      final scheduleDateTime = DateTime(
        _scheduleDate.year,
        _scheduleDate.month,
        _scheduleDate.day,
        _scheduleTime.hour,
        _scheduleTime.minute,
        0,
      );

      // --- LOGIC FOR REFERENCE NUMBER (CLIENT JO/MSR) ---
      String finalJoNumber = _externalRefController.text.trim();

      if (finalJoNumber.isEmpty) {
        // If user left it blank:
        if (widget.existingJob != null) {
          // On Edit: Keep the old one
          finalJoNumber = widget.existingJob!.displayId;
        } else {
          // On Create: Generate a new internal JO-XXXX
          finalJoNumber =
              'JO-${DateTime.now().millisecondsSinceEpoch.toString().substring(9)}';
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
        // SAVE THE REFERENCE NUMBER
        'client_jo_number': finalJoNumber,
      };

      int newJoId;

      if (widget.existingJob != null) {
        // UPDATE EXISTING JOB
        await _supabase
            .from('job_orders')
            .update(jobData)
            .eq('id', widget.existingJob!.dbId);

        newJoId = widget.existingJob!.dbId;

        // Clear old aircon links before adding new ones
        await _supabase
            .from('job_order_aircons')
            .delete()
            .eq('job_order_id', newJoId);
      } else {
        // CREATE NEW JOB
        // Add fields only for new jobs
        jobData['user_id'] = _supabase.auth.currentUser?.id;

        final joRes = await _supabase
            .from('job_orders')
            .insert(jobData)
            .select('id')
            .single();

        newJoId = joRes['id'] as int;
      }

      // 4. LINK AIRCONS TO JOB ORDER
      if (_selectedAirconIds.isNotEmpty) {
        for (int airconId in _selectedAirconIds) {
          await _supabase.from('job_order_aircons').insert({
            'job_order_id': newJoId,
            'aircon_id': airconId,
          });
        }
      }

      // 5. LINK TECHNICIANS
      await _supabase
          .from('job_order_technicians')
          .delete()
          .eq('job_order_id', newJoId);

      if (_selectedTechnicianIds.isNotEmpty) {
        for (int techId in _selectedTechnicianIds) {
          await _supabase.from('job_order_technicians').insert({
            'job_order_id': newJoId,
            'technician_id': techId,
            'role': 'Technician',
          });
        }
      }
      // LOG IT!
      await ActivityLogger.log(
        type: widget.existingJob != null ? 'Update' : 'Create',
        details: widget.existingJob != null
            ? 'Updated Job $finalJoNumber'
            : 'Created Job $finalJoNumber for $_customerDisplayController.text',
      );

      // SUCCESS!
      if (mounted) {
        Navigator.pop(context, true);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              widget.existingJob != null
                  ? "Job Updated Successfully!"
                  : "Job Order Created Successfully!",
            ),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e, stackTrace) {
      print("ERROR in _submit: $e");
      print("Stack trace: $stackTrace");

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Error: ${e.toString()}"),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    // FIX: Using LayoutBuilder for dynamic sizing
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
            height: constraints.maxHeight * 0.85,
            color: Colors.white,
            child: Column(
              children: [
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
                              ? "Service Type"
                              : _currentStep == 1
                              ? "Customer & Asset"
                              : "Schedule",
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

                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: _buildCurrentStep(),
                  ),
                ),

                Padding(
                  padding: const EdgeInsets.all(24),
                  child: SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      onPressed: _isSubmitting
                          ? null
                          : () {
                              // Step 1 -> Step 2: Just advance
                              if (_currentStep == 0) {
                                setState(() => _currentStep++);
                              }
                              // Step 2 -> Step 3: Validate form if new client
                              else if (_currentStep == 1) {
                                if (_isNewClient) {
                                  // Validate the form NOW while it is still on screen
                                  if (_formKey.currentState!.validate()) {
                                    setState(() => _currentStep++);
                                  } else {
                                    // Show error if validation fails
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text(
                                          "Please fix errors in red",
                                        ),
                                        backgroundColor: Colors.red,
                                      ),
                                    );
                                  }
                                } else {
                                  // Existing client - just check if selected
                                  if (_selectedClientId == null) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text(
                                          "Please select a customer",
                                        ),
                                        backgroundColor: Colors.red,
                                      ),
                                    );
                                  } else {
                                    setState(() => _currentStep++);
                                  }
                                }
                              }
                              // Step 3: Submit
                              else if (_currentStep == 2) {
                                _submit();
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
    if (_currentStep == 0) return _stepOne();
    if (_currentStep == 1) return _stepTwo();
    return _stepThree();
  }

  Widget _stepOne() {
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

  Widget _stepTwo() {
    final isEditing = widget.existingJob != null;

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. HIDE TOGGLE IF EDITING
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
                      label: "Existing",
                      isSelected: !_isNewClient,
                      onTap: () => setState(() => _isNewClient = false),
                    ),
                  ),
                  Expanded(
                    child: _ToggleOption(
                      label: "New Client",
                      isSelected: _isNewClient,
                      onTap: () => setState(() => _isNewClient = true),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
          ],

          if (!_isNewClient) ...[
            const Text(
              "Customer",
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),

            // 2. SHOW LOCKED FIELD IF EDITING, ELSE SHOW SEARCH
            if (isEditing)
              TextField(
                controller: _customerDisplayController,
                readOnly: true,
                decoration: const InputDecoration(
                  labelText: "Selected Customer",
                  prefixIcon: Icon(Icons.lock, color: Colors.grey),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.all(Radius.circular(12)),
                  ),
                  filled: true,
                  fillColor: Color(
                    0xFFF1F5F9,
                  ), // Light grey to indicate disabled
                ),
              )
            else
              Autocomplete<Map<String, dynamic>>(
                optionsBuilder: (TextEditingValue textEditingValue) {
                  if (textEditingValue.text == '')
                    return const Iterable<Map<String, dynamic>>.empty();
                  return _existingClients.where((Map<String, dynamic> option) {
                    final name =
                        option['company_name'] ??
                        '${option['first_name']} ${option['last_name']}';
                    return name.toLowerCase().contains(
                      textEditingValue.text.toLowerCase(),
                    );
                  });
                },
                displayStringForOption: (Map<String, dynamic> option) =>
                    option['company_name'] ??
                    '${option['first_name']} ${option['last_name']}',
                onSelected: (Map<String, dynamic> selection) {
                  setState(() {
                    _selectedClientId = selection['id'];
                    _fetchClientAircons(_selectedClientId!);
                  });
                },
                fieldViewBuilder:
                    (context, controller, focusNode, onFieldSubmitted) {
                      return TextField(
                        controller: controller,
                        focusNode: focusNode,
                        decoration: const InputDecoration(
                          hintText: "Type client name...",
                          prefixIcon: Icon(Icons.search),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.all(Radius.circular(12)),
                          ),
                          filled: true,
                          fillColor: Colors.white,
                        ),
                      );
                    },
              ),

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
              const SizedBox(height: 8),
              if (_clientAircons.isNotEmpty)
                ..._clientAircons.map((unit) {
                  final brand = unit['brands'] != null
                      ? unit['brands']['brand_name']
                      : 'Unknown';
                  final type = unit['aircon_types'] != null
                      ? unit['aircon_types']['type_name']
                      : 'Unit';

                  final isChecked = _selectedAirconIds.contains(unit['id']);

                  return CheckboxListTile(
                    title: Text("$brand $type"),
                    subtitle: Text(unit['remarks'] ?? ''),
                    value: isChecked,
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
                  padding: EdgeInsets.only(top: 10),
                  child: Text(
                    "No registered units found.",
                    style: TextStyle(
                      color: Colors.grey,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ),
            ],
          ] else ...[
            // FULL NEW CLIENT FORM
            Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    "Client Info",
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.blue,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: _SimpleInput(
                          controller: _firstNameController,
                          hint: "First Name",
                          icon: Icons.person,
                          isRequired: true,
                          textCapitalization: TextCapitalization.words,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _SimpleInput(
                          controller: _middleNameController,
                          hint: "Middle (Opt)",
                          textCapitalization: TextCapitalization.words,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  _SimpleInput(
                    controller: _lastNameController,
                    hint: "Last Name",
                    isRequired: true,
                    textCapitalization: TextCapitalization.words,
                  ),
                  const SizedBox(height: 12),
                  _SimpleInput(
                    controller: _companyController,
                    hint: "Company Name (Optional)",
                    icon: Icons.business,
                    textCapitalization: TextCapitalization.words,
                  ),
                  const SizedBox(height: 12),
                  _SimpleInput(
                    controller: _jobPositionController,
                    hint: "Job Position (e.g. Manager)",
                    icon: Icons.badge,
                    textCapitalization: TextCapitalization.words,
                  ),
                  const SizedBox(height: 12),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: _SimpleInput(
                          controller: _phoneController,
                          hint: "Mobile/Landline",
                          icon: Icons.phone,
                          isRequired: true,
                          keyboardType: TextInputType.phone,
                          validator: _validatePhone,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _SimpleInput(
                          controller: _emailController,
                          hint: "Email Address",
                          icon: Icons.email,
                          keyboardType: TextInputType.emailAddress,
                          validator: _validateEmail,
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 24),
                  const Text(
                    "Detailed Address",
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.blue,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: _SimpleInput(
                          controller: _unitController,
                          hint: "Unit/House #",
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _SimpleInput(
                          controller: _streetController,
                          hint: "Street Name",
                          isRequired: true,
                          textCapitalization: TextCapitalization.words,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  _SimpleInput(
                    controller: _villageController,
                    hint: "Subdivision / Village",
                    textCapitalization: TextCapitalization.words,
                  ),
                  const SizedBox(height: 12),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: _SimpleInput(
                          controller: _barangayController,
                          hint: "Barangay",
                          isRequired: true,
                          textCapitalization: TextCapitalization.words,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _SimpleInput(
                          controller: _cityController,
                          hint: "City",
                          icon: Icons.location_city,
                          isRequired: true,
                          textCapitalization: TextCapitalization.words,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  _SimpleInput(
                    controller: _landmarkController,
                    hint: "Landmark (Near...)",
                    icon: Icons.flag,
                    textCapitalization: TextCapitalization.sentences,
                  ),

                  const SizedBox(height: 24),
                  const Text(
                    "First Aircon Unit (Optional)",
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.grey,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: LayoutBuilder(
                          builder: (context, constraints) {
                            return Autocomplete<String>(
                              optionsBuilder:
                                  (TextEditingValue textEditingValue) {
                                    if (textEditingValue.text == '')
                                      return const Iterable<String>.empty();
                                    return _brandOptions.where((String option) {
                                      return option.toLowerCase().contains(
                                        textEditingValue.text.toLowerCase(),
                                      );
                                    });
                                  },
                              onSelected: (String selection) {
                                _selectedBrandName = selection;
                              },
                              fieldViewBuilder:
                                  (
                                    context,
                                    textEditingController,
                                    focusNode,
                                    onFieldSubmitted,
                                  ) {
                                    textEditingController.addListener(() {
                                      _selectedBrandName =
                                          textEditingController.text;
                                    });
                                    return TextFormField(
                                      controller: textEditingController,
                                      focusNode: focusNode,
                                      decoration: const InputDecoration(
                                        label: Text("Brand (Search/Add)"),
                                        border: OutlineInputBorder(
                                          borderRadius: BorderRadius.all(
                                            Radius.circular(12),
                                          ),
                                        ),
                                        filled: true,
                                        fillColor: Colors.white,
                                        contentPadding: EdgeInsets.symmetric(
                                          horizontal: 16,
                                          vertical: 14,
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
                          decoration: const InputDecoration(
                            hintText: "Type",
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.all(
                                Radius.circular(12),
                              ),
                            ),
                            filled: true,
                            fillColor: Colors.white,
                            contentPadding: EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 14,
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
                  _SimpleInput(
                    controller: _unitRemarkController,
                    hint: "Location (e.g. Lobby)",
                    textCapitalization: TextCapitalization.words,
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _stepThree() {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // NEW: External Reference Field
          const Text(
            "Reference No.",
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _externalRefController,
            decoration: const InputDecoration(
              labelText: "Client JO / MSR # (Optional)",
              hintText: "Leave blank to auto-generate (JO-XXXX)",
              border: OutlineInputBorder(),
              filled: true,
              fillColor: Colors.white,
              prefixIcon: Icon(Icons.tag),
            ),
          ),
          const SizedBox(height: 24),

          const Text(
            "Date & Time",
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
          const SizedBox(height: 16),

          // Date Picker
          ListTile(
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
                // OPEN: Allow selection of past dates (back to 2020) for record keeping
                firstDate: DateTime(2020),
                lastDate: DateTime(2030),
              );
              if (d != null) setState(() => _scheduleDate = d);
            },
          ),
          const SizedBox(height: 12),

          // Time Picker with Conflict Warning
          ListTile(
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
                // 1. Check for conflict
                final hasConflict = await _checkScheduleConflict(
                  _scheduleDate,
                  t,
                );

                if (hasConflict) {
                  if (!mounted) return;
                  // 2. Show Warning
                  final proceed = await showDialog<bool>(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      title: const Row(
                        children: [
                          Icon(
                            Icons.warning_amber_rounded,
                            color: Colors.orange,
                          ),
                          SizedBox(width: 8),
                          Text("Double Booking Warning"),
                        ],
                      ),
                      content: Text(
                        "Another job is already scheduled near ${t.format(context)}.\n\nDo you want to proceed anyway?",
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(ctx, false),
                          child: const Text("Choose Different Time"),
                        ),
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.orange,
                          ),
                          onPressed: () => Navigator.pop(ctx, true),
                          child: const Text("Keep This Time"),
                        ),
                      ],
                    ),
                  );

                  // If user cancelled or clicked outside, stop here
                  if (proceed != true) return;
                }

                // 3. Update State
                setState(() => _scheduleTime = t);
              }
            },
          ),

          const SizedBox(height: 24),
          const Text(
            "Assign Team (Optional)",
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
          const SizedBox(height: 8),

          // Technician Selection Area
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey.shade300),
              borderRadius: BorderRadius.circular(12),
            ),
            child: _availableTechnicians.isEmpty
                ? const Text("No technicians found in database.")
                : Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: _availableTechnicians.map((tech) {
                      final id = tech['id'] as int;
                      final name =
                          "${tech['first_name']} ${tech['last_name'][0]}.";
                      final isSelected = _selectedTechnicianIds.contains(id);

                      return FilterChip(
                        label: Text(name),
                        selected: isSelected,
                        onSelected: (bool selected) {
                          setState(() {
                            if (selected) {
                              _selectedTechnicianIds.add(id);
                            } else {
                              _selectedTechnicianIds.remove(id);
                            }
                          });
                        },
                        selectedColor: Colors.blue.withOpacity(0.2),
                        checkmarkColor: Colors.blue,
                        labelStyle: TextStyle(
                          color: isSelected ? Colors.blue[900] : Colors.black87,
                          fontWeight: isSelected
                              ? FontWeight.bold
                              : FontWeight.normal,
                        ),
                      );
                    }).toList(),
                  ),
          ),

          const SizedBox(height: 24),
          const Text(
            "Notes",
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _notesController,
            maxLines: 3,
            decoration: InputDecoration(
              hintText: "Additional instructions...",
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
