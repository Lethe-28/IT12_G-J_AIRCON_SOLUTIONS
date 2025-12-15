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

  // inside _SchedulingScreenState class
  bool _showActionItems = false; // Toggle between Calendar and Action List
  bool _sortOldestFirst = true; // For the Action List sorting

  // inside _SchedulingScreenState class

  // Get all jobs that need attention
  List<JobOrder> _getActionableJobs() {
    final list = _orders
        .where(
          (o) =>
              // 1. Wrap all the "OR" flags in parentheses
              (o.isUnbilled || o.isUnpaid || o.hasNoTechs || o.hasNoUnits) &&
              // 2. The AND now applies to the entire group above
              o.status != 'Cancelled',
        )
        .toList();

    list.sort((a, b) {
      int comparison = a.startDateTime.compareTo(b.startDateTime);
      return _sortOldestFirst ? comparison : -comparison;
    });

    return list;
  }

  // inside _SchedulingScreenState class

  // The Yellow/Back Banner
  Widget _buildActionBanner(int count) {
    if (count == 0 && !_showActionItems) return const SizedBox.shrink();

    return GestureDetector(
      onTap: () {
        setState(() {
          _showActionItems = !_showActionItems;
        });
      },
      child: AnimatedContainer(
        duration: AppTheme.animationDuration,
        width: double.infinity,
        padding: const EdgeInsets.symmetric(
          vertical: 12, // Slightly tighter vertical padding
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
              _showActionItems ? Icons.arrow_back : Icons.warning_amber_rounded,
              color: _showActionItems ? AppTheme.textPrimary : AppTheme.warning,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                _showActionItems
                    ? "Back to Calendar"
                    : "$count Jobs require attention",
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: _showActionItems
                      ? AppTheme.textPrimary
                      : AppTheme.warning,
                  fontSize: 15,
                ),
              ),
            ),
            // "View All" link if collapsed
            if (!_showActionItems)
              const Text(
                "View All",
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: AppTheme.primary,
                  decoration: TextDecoration.underline,
                ),
              )
            // Sorting Controls if Expanded
            else
              Row(
                children: [
                  Text(
                    "$count Items",
                    style: const TextStyle(color: Colors.grey, fontSize: 12),
                  ),
                  const SizedBox(width: 12),
                  OutlinedButton.icon(
                    onPressed: () =>
                        setState(() => _sortOldestFirst = !_sortOldestFirst),
                    icon: Icon(
                      _sortOldestFirst
                          ? Icons.arrow_upward
                          : Icons.arrow_downward,
                      size: 14,
                    ),
                    label: Text(
                      _sortOldestFirst ? "Oldest" : "Newest",
                      style: const TextStyle(fontSize: 12),
                    ),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      minimumSize: const Size(0, 32),
                    ),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  // The Full Page List of Action Items
  Widget _buildActionItemsList(List<JobOrder> actionableJobs) {
    if (actionableJobs.isEmpty) {
      return const Center(child: Text("Great job! No pending actions."));
    }

    return ListView.separated(
      padding: const EdgeInsets.all(20),
      itemCount: actionableJobs.length,
      separatorBuilder: (ctx, i) => const SizedBox(height: 12),
      itemBuilder: (ctx, i) => _JobCard(
        order: actionableJobs[i],
        onTap: () => _showJobDetails(actionableJobs[i]),
      ),
    );
  }

  DateTime _focusedDate = DateTime.now();
  DateTime _selectedDate = DateTime.now();

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
    final isMobile = MediaQuery.of(context).size.width < 900;

    // 1. Calculate Actions (Yellow Banner Data)
    final actionableJobs = _getActionableJobs();
    final actionableCount = actionableJobs.length;

    // 2. Decide what content to show in the Expanded area
    Widget content;

    if (_searchQuery.isNotEmpty) {
      // MODE A: SEARCH (Overrides everything)
      final searchResults = _orders.where((job) {
        // 1. Create searchable "tags" for the flags
        final String tags = [
          if (job.isUnbilled) "unbilled",
          if (job.isUnpaid) "unpaid",
          if (job.hasNoTechs) "no tech", // matches "no tech" search
          if (job.hasNoUnits) "no unit", // matches "no unit" search
        ].join(" ");

        // 2. Check all text fields (Names, IDs, Locations, Status, AND Job Type)
        return job.clientName.toLowerCase().contains(_searchQuery) ||
            job.displayId.toLowerCase().contains(_searchQuery) ||
            job.location.toLowerCase().contains(_searchQuery) ||
            job.status.toLowerCase().contains(_searchQuery) ||
            job.jobType.toLowerCase().contains(
              _searchQuery,
            ) || // <--- NEW: Search by "Repair", "Installation", etc.
            tags.contains(_searchQuery); // <--- NEW: Search by tags
      }).toList();

      content = ListView.separated(
        padding: const EdgeInsets.all(20),
        itemCount: searchResults.length,
        separatorBuilder: (ctx, i) => const SizedBox(height: 12),
        itemBuilder: (ctx, i) => _JobCard(
          order: searchResults[i],
          onTap: () => _showJobDetails(searchResults[i]),
        ),
      );
    } else if (_showActionItems) {
      // MODE B: ACTION LIST (The "Separate Page" for warnings)
      content = _buildActionItemsList(actionableJobs);
    } else {
      // MODE C: CALENDAR (Your existing split view)
      final calendarJobs = _getJobsForDay(_selectedDate);
      content = isMobile
          ? _buildMobileLayout(calendarJobs)
          : _buildDesktopLayout(calendarJobs);
    }

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

              // THE WARNING BANNER
              // We place it here so it pushes the calendar down.
              // It hides automatically if searching or count is 0.
              if (_searchQuery.isEmpty) _buildActionBanner(actionableCount),

              // MAIN CONTENT (Swaps between Calendar and List)
              Expanded(child: content),
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
            // Wrapped in SingleChildScrollView to fix the yellow overflow tape
            child: SingleChildScrollView(child: _buildCalendarGrid()),
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
                      // // Add Button for specific day
                      // IconButton(
                      //   onPressed: () => _onAddOrEdit(),
                      //   icon: const Icon(
                      //     Icons.add_circle,
                      //     color: AppTheme.primary,
                      //     size: 32,
                      //   ),
                      //   tooltip: "Add Schedule for this day",
                      // ),
                    ],
                  ),
                ),
                const Divider(height: 1),
                Expanded(
                  child: jobsForDay.isEmpty
                      ? _buildEmptyStatePrompt()
                      : ListView.separated(
                          padding: const EdgeInsets.all(16),
                          itemCount: jobsForDay.length,
                          separatorBuilder: (ctx, i) =>
                              const SizedBox(height: 12),
                          // FIX: Pass onTap directly to _JobCard
                          itemBuilder: (ctx, i) => _JobCard(
                            order: jobsForDay[i],
                            onTap: () => _showJobDetails(jobsForDay[i]),
                          ),
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
                    itemCount: jobsForDay
                        .length, // Or displayJobs.length depending on your variable
                    separatorBuilder: (ctx, i) => const SizedBox(height: 12),
                    // FIX: Remove GestureDetector and pass onTap directly to _JobCard
                    itemBuilder: (ctx, i) => _JobCard(
                      order: jobsForDay[i],
                      onTap: () => _showJobDetails(jobsForDay[i]),
                    ),
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
    // 1. MOBILE SEARCH VIEW (When user clicks search icon)
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

    // 2. STANDARD HEADER (Default View)
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: isMobile ? 16 : 32,
        vertical: 16,
      ),
      color: Colors.white,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Left: Month Navigation
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

          // Right: Search Bar & Add Button
          Row(
            children: [
              // Search Input
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

              // Add Job Button
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
            final isResolved =
                hasJobs &&
                jobs.every(
                  (j) => j.status == 'Completed' || j.status == 'Cancelled',
                );

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
                          color: isResolved ? Colors.green : AppTheme.warning,
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

  // NEW: Cancel Logic with Reason
  Future<void> _cancelJob() async {
    // 1. Prompt for Reason
    final reasonController = TextEditingController();
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Cancel Job"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text("Please provide a reason for cancellation:"),
            const SizedBox(height: 12),
            TextField(
              controller: reasonController,
              decoration: const InputDecoration(
                labelText: "Reason",
                hintText: "e.g., Client cancelled, Weather issue",
                border: OutlineInputBorder(),
              ),
              maxLines: 2,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text("Keep Job"),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () {
              if (reasonController.text.trim().isEmpty) {
                // Force user to enter something
                ScaffoldMessenger.of(ctx).showSnackBar(
                  const SnackBar(content: Text("Reason is required.")),
                );
                return;
              }
              Navigator.pop(ctx, true);
            },
            child: const Text("Confirm Cancel"),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        // Append reason to existing notes
        final oldNotes = widget.job.notes ?? "";
        final newNotes = "$oldNotes\n[CANCELLED]: ${reasonController.text}"
            .trim();

        await _supabase
            .from('job_orders')
            .update({'status': 'Cancelled', 'notes': newNotes})
            .eq('id', widget.job.dbId);

        // LOG IT!
        await ActivityLogger.log(
          type: 'Cancel',
          details:
              'Cancelled Job ${widget.job.displayId}. Reason: ${reasonController.text}',
        );

        if (mounted) {
          Navigator.pop(context); // Close the details dialog
          widget.onJobUpdated(); // Refresh the main screen
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Job Cancelled and Reason Logged.")),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text("Error: $e")));
        }
      }
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
        // 4: Aircons (UPDATED QUERY)
        _supabase
            .from('job_order_aircons')
            .select(
              // FIX: Added horse_power and is_inverter to the select
              'aircons(remarks, horse_power, is_inverter, brands(brand_name), aircon_types(type_name))',
            )
            .eq('job_order_id', jobId),
      ]);

      // ... (Rest of variable parsing remains same) ...
      final items = List<Map<String, dynamic>>.from(results[0] as List);
      final payments = List<Map<String, dynamic>>.from(results[1] as List);
      final catalog = List<Map<String, dynamic>>.from(results[2] as List);
      final techRes = List<Map<String, dynamic>>.from(results[3] as List);
      final acRes = List<Map<String, dynamic>>.from(results[4] as List);

      // ... (Calculations remain same) ...
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

      // --- UPDATED UNIT FORMATTING LOGIC ---
      final List<String> loadedUnits = [];
      for (var row in acRes) {
        final a = row['aircons'];
        if (a != null) {
          final brand = a['brands']?['brand_name'] ?? 'Unknown Brand';
          final type = a['aircon_types']?['type_name'] ?? 'Unit';
          final remark = a['remarks'] ?? '';

          // 1. Build Tech Specs
          final hp =
              a['horse_power'] != null && a['horse_power'].toString().isNotEmpty
              ? "${a['horse_power']} HP"
              : "";
          final inverter = (a['is_inverter'] == true) ? "Inverter" : "";

          final specs = [hp, inverter].where((s) => s.isNotEmpty).join(' • ');

          // 2. Combine into one clean line
          // Format: "Samsung Split Type • 1.5 HP • Inverter (Master Bedroom)"
          String fullText = "$brand $type";
          if (specs.isNotEmpty) fullText += " • $specs";
          if (remark.isNotEmpty) fullText += " ($remark)";

          loadedUnits.add(fullText);
        }
      }
      // -------------------------------------

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
      // ... (Error handling remains same) ...
      debugPrint('Error loading details: $e');
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text("Error loading details: $e")));
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
                      // Status Changer Row
                      Row(
                        children: [
                          Text(
                            "${widget.job.jobType} • ${widget.job.displayId}",
                            style: const TextStyle(color: Colors.grey),
                          ),
                          const SizedBox(width: 12),

                          // 1. COMPLETED BADGE (Existing)
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
                          // 2. NEW: CANCELLED BADGE (Fixes the bypass)
                          else if (_currentStatus == 'Cancelled')
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.grey.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: const Row(
                                children: [
                                  Icon(
                                    Icons.block,
                                    size: 12,
                                    color: Colors.grey,
                                  ), // Block icon for Cancelled
                                  SizedBox(width: 4),
                                  Text(
                                    "CANCELLED",
                                    style: TextStyle(
                                      color: Colors.grey,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 11,
                                    ),
                                  ),
                                ],
                              ),
                            )
                          // 3. DROPDOWN (For Active States Only)
                          else
                            DropdownButton<String>(
                              // Logic: Only allow active states.
                              value:
                                  [
                                    'Pending',
                                    'In Progress',
                                    'On Hold',
                                  ].contains(_currentStatus)
                                  ? _currentStatus
                                  : 'Pending',

                              // FIX: Removed 'Cancelled' from this list
                              items: ['Pending', 'In Progress', 'On Hold']
                                  .map(
                                    (s) => DropdownMenuItem(
                                      value: s,
                                      child: Text(s),
                                    ),
                                  )
                                  .toList(),

                              onChanged: (v) =>
                                  v != null ? _updateStatus(v) : null,

                              // Styling
                              underline: Container(),
                              icon: const Icon(
                                Icons.arrow_drop_down,
                                color: Colors.blue,
                              ),
                              style: const TextStyle(
                                color: Colors.blue,
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
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
        // --- START OF LOGIC CHANGE ---

        // 1. COMPLETED VIEW (Green Lock)
        if (widget.job.status == 'Completed')
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
          )
        // 2. NEW: CANCELLED VIEW (Grey Lock + Admin Delete Option)
        else if (widget.job.status == 'Cancelled')
          Column(
            children: [
              const SizedBox(
                width: double.infinity,
                child: Card(
                  color: Color(0xFFF3F4F6), // Grey
                  elevation: 0,
                  child: Padding(
                    padding: EdgeInsets.all(16.0),
                    child: Center(
                      child: Column(
                        children: [
                          Icon(Icons.cancel, color: Colors.grey, size: 32),
                          SizedBox(height: 8),
                          Text(
                            "This job is cancelled.",
                            style: TextStyle(
                              color: Colors.grey,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            "Check notes for reason.",
                            style: TextStyle(fontSize: 12, color: Colors.grey),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),

              // Only show DELETE if user is Admin (Prevent accidental deletion of history)
              if (AppState.currentRole == UserRole.admin)
                SizedBox(
                  width: double.infinity,
                  child: TextButton.icon(
                    onPressed: _deleteJob, // Uses existing delete logic
                    icon: const Icon(Icons.delete_forever, size: 18),
                    label: const Text("Permanently Delete Record (Admin)"),
                    style: TextButton.styleFrom(
                      foregroundColor: Colors.red[300],
                    ),
                  ),
                ),
            ],
          )
        // 3. ACTIVE VIEW (Action Buttons)
        else
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              _ActionButton(
                icon: Icons.edit,
                label: "Edit Details",
                color: Colors.teal,
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

              // NEW CANCEL BUTTON HERE
              _ActionButton(
                icon: Icons.cancel_presentation,
                label: "Cancel Job",
                color: Colors.blueGrey,
                onTap: _cancelJob,
              ),

              if (AppState.currentRole == UserRole.admin)
                _ActionButton(
                  icon: Icons.delete,
                  label: "Delete Job",
                  color: Colors.red,
                  onTap: _deleteJob,
                ),
              _ActionButton(
                icon: Icons.check_circle,
                label: "Complete Job",
                color: Colors.blue,
                onTap: _completeJob,
              ),
            ],
          ),

        // --- END OF LOGIC CHANGE ---
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
  final JobOrder? existingJob;

  const _JobOrderDialog({super.key, this.initialDate, this.existingJob});
  @override
  State<_JobOrderDialog> createState() => _JobOrderDialogState();
}

class _JobOrderDialogState extends State<_JobOrderDialog> {
  // Steps: 0=CustomerType, 1=ServiceType, 2=Client&Asset, 3=Schedule
  int _currentStep = 0;
  bool _isSubmitting = false;
  final _supabase = Supabase.instance.client;
  final _formKey = GlobalKey<FormState>();

  // --- Data & Controllers ---
  String _customerType = 'Residential';
  String _jobTypeName = 'Installation';
  int? _jobTypeId;
  bool _isNewClient = true;

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

  // --- ONE BAR INPUTS ---
  final _fullNameController = TextEditingController();
  final _addressController =
      TextEditingController(); // Maps to address_complete
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();

  // Unit Details
  final _customerDisplayController = TextEditingController();
  String _selectedBrandName = '';
  int? _selectedAirconTypeId;
  final _unitRemarkController = TextEditingController();

  // NEW AIRCON FIELDS
  final _hpController = TextEditingController();
  bool _isInverter = false;

  // Job Details
  final _externalRefController = TextEditingController();
  late DateTime _scheduleDate;
  TimeOfDay _scheduleTime = const TimeOfDay(hour: 9, minute: 0);
  final _notesController = TextEditingController();

  // --- VALIDATORS (Restored) ---
  String? _validatePhone(String? value) {
    if (value == null || value.trim().isEmpty) return 'Required';
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

  // --- INIT ---
  @override
  void initState() {
    super.initState();
    if (widget.existingJob != null) {
      // EDIT MODE
      // UPDATED: Start at Step 1 (Service Type) instead of Step 0 or 2.
      _currentStep = 1;

      _jobTypeName = widget.existingJob!.jobType;
      _scheduleDate = widget.existingJob!.startDateTime;
      _scheduleTime = TimeOfDay.fromDateTime(widget.existingJob!.startDateTime);
      _notesController.text = widget.existingJob!.notes ?? '';
      _selectedClientId = widget.existingJob!.customerId;
      _externalRefController.text = widget.existingJob!.displayId;
      _isNewClient = false;
      _customerType = widget.existingJob!.isCorporate
          ? 'Commercial'
          : 'Residential';
    } else {
      _scheduleDate = widget.initialDate ?? DateTime.now();
    }
    _fetchInitialData();
  }

  Future<void> _fetchInitialData() async {
    // 1. Fetch Standard Dropdown Options
    final customers = await _supabase
        .from('customers')
        .select(
          'id, first_name, last_name, company_name, city, barangay, address_complete, customer_type_id',
        )
        .order('last_name', ascending: true);

    final types = await _supabase.from('job_types').select();
    final brands = await _supabase.from('brands').select().order('brand_name');
    final acTypes = await _supabase.from('aircon_types').select();
    final techs = await _supabase
        .from('technicians')
        .select()
        .order('first_name');

    // 2. PRE-LOAD EXISTING JOB DATA (The Fix)
    if (widget.existingJob != null && _selectedClientId != null) {
      // A. Load the client's aircon list so the checkboxes appear
      final clientUnits = await _supabase
          .from('aircons')
          .select(
            'id, remarks, horse_power, is_inverter, brands(brand_name), aircon_types(type_name)',
          )
          .eq('customer_id', _selectedClientId!)
          .eq('is_active', true);

      _clientAircons = List<Map<String, dynamic>>.from(clientUnits);

      // B. Load which specific Aircons are assigned to THIS job
      final assignedAircons = await _supabase
          .from('job_order_aircons')
          .select('aircon_id')
          .eq('job_order_id', widget.existingJob!.dbId);

      _selectedAirconIds.clear();
      for (var row in assignedAircons) {
        _selectedAirconIds.add(row['aircon_id'] as int);
      }

      // C. Load which Technicians are assigned
      final assignedTechs = await _supabase
          .from('job_order_technicians')
          .select('technician_id')
          .eq('job_order_id', widget.existingJob!.dbId);

      _selectedTechnicianIds.clear();
      for (var row in assignedTechs) {
        _selectedTechnicianIds.add(row['technician_id'] as int);
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
        .eq('customer_id', clientId)
        .eq('is_active', true); // UPDATED: Show only active units

    if (mounted) {
      setState(() {
        _clientAircons = List<Map<String, dynamic>>.from(units);
        _selectedAirconIds.clear();
      });
    }
  }

  // --- UNIT MANAGEMENT (Edit/Delete) ---

  // REPLACES _deleteUnit
  Future<void> _handleRemoveUnit(int unitId) async {
    // 1. CHECK USAGE: Has this unit ever been used in a job?
    final usageCount = await _supabase
        .from('job_order_aircons')
        .count(CountOption.exact)
        .eq('aircon_id', unitId);

    // 2. DECIDE ACTION
    final bool isUsed = usageCount != null && usageCount > 0;

    // 3. PREPARE DIALOG CONTENT
    final title = isUsed ? "Archive Unit?" : "Delete Unit?";
    final message = isUsed
        ? "This unit is linked to $usageCount past jobs. To preserve history, it will be deactivated (hidden) rather than deleted."
        : "This unit has no history. It will be permanently deleted.";
    final confirmBtn = isUsed ? "Archive" : "Delete Forever";

    // 4. ASK CONFIRMATION
    final confirm = await showConfirmDialog(
      context: context,
      title: title,
      message: message,
      confirmLabel: confirmBtn,
      isDestructive: true,
    );

    if (confirm == true) {
      try {
        if (isUsed) {
          // SCENARIO A: Soft Delete (Set is_active = false)
          await _supabase
              .from('aircons')
              .update({'is_active': false}) // UPDATED to match your DB
              .eq('id', unitId);

          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text("Unit deactivated and hidden.")),
            );
          }
        } else {
          // SCENARIO B: Hard Delete (Clean up typo)
          await _supabase.from('aircons').delete().eq('id', unitId);

          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text("Unit permanently deleted.")),
            );
          }
        }

        // Refresh the list immediately
        if (_selectedClientId != null) _fetchClientAircons(_selectedClientId!);
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text("Error removing unit: $e")));
        }
      }
    }
  }

  void _editUnitDialog(Map<String, dynamic> unit) {
    // Pre-fill controllers
    final hpCtrl = TextEditingController(
      text: unit['horse_power']?.toString() ?? '',
    );
    final remarkCtrl = TextEditingController(text: unit['remarks'] ?? '');
    String brandName = unit['brands']?['brand_name'] ?? '';
    int? typeId = unit['aircon_types'] != null
        ? (unit['aircon_types']['id'] as int?)
        : null; // Note: You might need to adjust based on your join structure, easier to just rely on the ID if you have it, or fetch it.
    // Ideally your fetchClientAircons should select aircon_type_id directly to make this easier:
    // Update fetchClientAircons select to include 'aircon_type_id'
    // For now assuming we can map it or just letting user re-select if null.

    // Quick fix: Let's assume the user re-selects type if the join is complex,
    // or try to match the name.
    // Better: Ensure _fetchClientAircons selects 'aircon_type_id'

    bool inverterVal = unit['is_inverter'] ?? false;

    // We need to fetch the type ID from the name if not present,
    // but let's try to grab it from the _airconTypes list if possible
    if (typeId == null && unit['aircon_types'] != null) {
      final typeName = unit['aircon_types']['type_name'];
      final match = _airconTypes.firstWhere(
        (t) => t['type_name'] == typeName,
        orElse: () => {},
      );
      if (match.isNotEmpty) typeId = match['id'];
    }

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Edit Unit Details"),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Autocomplete<String>(
                initialValue: TextEditingValue(text: brandName),
                optionsBuilder: (v) => v.text == ''
                    ? const Iterable<String>.empty()
                    : _brandOptions.where(
                        (o) => o.toLowerCase().contains(v.text.toLowerCase()),
                      ),
                onSelected: (s) => brandName = s,
                fieldViewBuilder: (ctx, c, f, o) {
                  c.addListener(() => brandName = c.text);
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
                value: typeId,
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
                onChanged: (v) => typeId = v,
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: hpCtrl,
                      decoration: const InputDecoration(
                        labelText: "HP",
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: StatefulBuilder(
                      builder: (context, setCheck) => CheckboxListTile(
                        title: const Text("Inverter"),
                        value: inverterVal,
                        onChanged: (v) =>
                            setCheck(() => inverterVal = v ?? false),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              TextField(
                controller: remarkCtrl,
                decoration: const InputDecoration(
                  labelText: "Location/Remarks",
                  border: OutlineInputBorder(),
                ),
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
              // SAVE LOGIC
              int brandId;
              final bCheck = await _supabase
                  .from('brands')
                  .select('id')
                  .ilike('brand_name', brandName.trim())
                  .maybeSingle();
              if (bCheck != null) {
                brandId = bCheck['id'];
              } else {
                final newB = await _supabase
                    .from('brands')
                    .insert({'brand_name': brandName.trim()})
                    .select('id')
                    .single();
                brandId = newB['id'];
              }

              await _supabase
                  .from('aircons')
                  .update({
                    'brand_id': brandId,
                    'aircon_type_id': typeId ?? 1,
                    'remarks': remarkCtrl.text,
                    'horse_power': hpCtrl.text,
                    'is_inverter': inverterVal,
                  })
                  .eq('id', unit['id']);

              if (mounted) {
                Navigator.pop(context);
                _fetchClientAircons(_selectedClientId!); // Refresh list
              }
            },
            child: const Text("Update Unit"),
          ),
        ],
      ),
    );
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

  // --- SUBMIT LOGIC (One Bar Parse) ---
  // --- SUBMIT LOGIC (With Duplicate Check) ---
  Future<void> _submit() async {
    final hasConflict = await _checkScheduleConflict(
      _scheduleDate,
      _scheduleTime,
    );

    if (hasConflict) {
      if (!mounted) return;

      // Show Warning Dialog
      final proceed = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.warning_amber_rounded, color: Colors.orange),
              SizedBox(width: 8),
              Text("Double Booking Warning"),
            ],
          ),
          content: Text(
            "Another job is already scheduled near ${_scheduleTime.format(context)} on this date.\n\nAre you sure you want to proceed?",
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false), // Cancel
              child: const Text("Cancel"),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
              onPressed: () => Navigator.pop(ctx, true), // Proceed
              child: const Text("Proceed Anyway"),
            ),
          ],
        ),
      );

      // If user clicked Cancel or clicked outside, STOP the submission.
      if (proceed != true) return;
    }
    // -------------------------------------

    setState(() => _isSubmitting = true);
    setState(() => _isSubmitting = true);

    try {
      int? finalCustomerId = _selectedClientId;

      // 1. CREATE CUSTOMER (Parsing "One Bar" Name)
      if (_isNewClient) {
        String firstName = '-';
        String lastName = '-';
        String? companyName;

        final fullName = _fullNameController.text.trim();

        // A. Parse Name
        if (_customerType == 'Commercial') {
          companyName = fullName;
          firstName = "Contact";
          lastName = "Person";
        } else {
          List<String> parts = fullName.split(' ');
          if (parts.isNotEmpty) {
            firstName = parts.first;
            if (parts.length > 1) {
              lastName = parts.sublist(1).join(' ');
            } else {
              lastName = '';
            }
          }
        }

        final newCustomerData = {
          'first_name': firstName,
          'last_name': lastName,
          'company_name': companyName,
          'address_complete': _addressController.text.trim(),
          'contact_number': _phoneController.text.trim(),
          'email': _emailController.text.trim().isEmpty
              ? null
              : _emailController.text.trim(),
          'customer_type_id': _customerType == 'Commercial' ? 1 : 2,
        };

        final custRes = await _supabase
            .from('customers')
            .insert(newCustomerData)
            .select('id')
            .single();
        finalCustomerId = custRes['id'] as int;
      }

      // 2. CREATE AIRCON (Only if Brand is provided)
      // Logic: If user leaves Brand empty, we skip aircon creation (Optional)
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
          'horse_power': _hpController.text.trim(),
          'is_inverter': _isInverter,
        };

        final newAircon = await _supabase
            .from('aircons')
            .insert(airconData)
            .select('id')
            .single();
        _selectedAirconIds.add(newAircon['id']);
      }

      // 3. CREATE JOB ORDER (Rest of the logic remains exactly the same)
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

      // --- NEW ID GENERATION LOGIC ---
      String finalJoNumber = _externalRefController.text.trim();

      if (finalJoNumber.isEmpty) {
        // 1. Generate Base Date String: MMMddyy (e.g., DEC0125)
        const months = [
          'JAN',
          'FEB',
          'MAR',
          'APR',
          'MAY',
          'JUN',
          'JUL',
          'AUG',
          'SEP',
          'OCT',
          'NOV',
          'DEC',
        ];
        final monthStr = months[_scheduleDate.month - 1];
        final dayStr = _scheduleDate.day.toString().padLeft(2, '0');
        final yearStr = _scheduleDate.year.toString().substring(
          2,
        ); // Get last 2 digits

        String basePattern = "$monthStr$dayStr$yearStr";

        // 2. Add Prefix based on Customer Type
        // "Residential" gets "GJ-", "Commercial" gets nothing.
        if (_customerType == 'Residential') {
          basePattern = "GJ-$basePattern";
        }

        // 3. Check Database for Duplicates (Sequence A, B, C...)
        // We look for any existing JO that starts with this pattern
        final existingJos = await _supabase
            .from('job_orders')
            .select('client_jo_number')
            .ilike('client_jo_number', '$basePattern%'); // Query: "GJ-DEC0125%"

        final existingList = List<String>.from(
          existingJos.map((e) => e['client_jo_number'] as String),
        );

        if (!existingList.contains(basePattern)) {
          // Case 1: First one (e.g. GJ-DEC0125)
          finalJoNumber = basePattern;
        } else {
          // Case 2: Duplicate exists, find next letter (e.g. GJ-DEC0125A)
          String suffix = "A";
          bool found = false;

          // Loop A-Z to find a free spot
          for (int i = 0; i < 26; i++) {
            String candidate = "$basePattern$suffix";
            if (!existingList.contains(candidate)) {
              finalJoNumber = candidate;
              found = true;
              break;
            }
            // Increment char (A -> B -> C)
            int nextCode = suffix.codeUnitAt(0) + 1;
            suffix = String.fromCharCode(nextCode);
          }

          // Fallback if we somehow run out of letters (rare)
          if (!found) {
            finalJoNumber = "$basePattern-${DateTime.now().millisecond}";
          }
        }
      }
      // -------------------------------

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

      // 4. LINK ASSETS & TECHS
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
    // Dynamic sizing for desktop/mobile
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
            height: constraints.maxHeight * 0.90,
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
                      if (_currentStep > (widget.existingJob != null ? 1 : 0))
                        IconButton(
                          icon: const Icon(Icons.arrow_back),
                          onPressed: () => setState(() => _currentStep--),
                        ),
                      Expanded(
                        child: Text(
                          _getStepTitle(),
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

                // --- CONTENT AREA ---
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
                      onPressed: _isSubmitting ? null : _handleNextButton,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF2563EB),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: _isSubmitting
                          ? const CircularProgressIndicator(color: Colors.white)
                          : Text(
                              _currentStep == 3
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

  String _getStepTitle() {
    switch (_currentStep) {
      case 0:
        return "Customer Type";
      case 1:
        return "Service Type";
      case 2:
        return "Client Info & Asset";
      case 3:
        return "Schedule & Techs";
      default:
        return "";
    }
  }

  Future<void> _handleNextButton() async {
    // 1. Validation Logic for Step 2 (Client Info)
    if (_currentStep == 2) {
      if (_isNewClient) {
        // A. Form Validation
        if (!_formKey.currentState!.validate()) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text("Please fill in required fields (*)."),
              backgroundColor: Colors.red,
            ),
          );
          return;
        }

        // B. ASYNC DUPLICATE CHECK
        // We pause here to check the DB before allowing the user to proceed.
        final fullName = _fullNameController.text.trim();
        String? companyName;
        String firstName = '';
        String lastName = '';

        if (_customerType == 'Commercial') {
          companyName = fullName;
        } else {
          List<String> parts = fullName.split(' ');
          if (parts.isNotEmpty) {
            firstName = parts.first;
            if (parts.length > 1) {
              lastName = parts.sublist(1).join(' ');
            } else {
              lastName = '';
            }
          }
        }

        Map<String, dynamic>? duplicate;
        if (_customerType == 'Commercial') {
          duplicate = await _supabase
              .from('customers')
              .select('id, company_name')
              .ilike('company_name', companyName!)
              .maybeSingle();
        } else {
          duplicate = await _supabase
              .from('customers')
              .select('id, first_name, last_name')
              .ilike('first_name', firstName)
              .ilike('last_name', lastName)
              .maybeSingle();
        }

        // If duplicate found, STOP and show dialog
        if (duplicate != null) {
          if (!mounted) return;
          await showDialog(
            context: context,
            builder: (ctx) => AlertDialog(
              title: const Row(
                children: [
                  Icon(Icons.warning_amber, color: Colors.orange),
                  SizedBox(width: 8),
                  Text("Duplicate Found"),
                ],
              ),
              content: Text("The customer '$fullName' already exists."),
              actions: [
                TextButton(
                  onPressed: () =>
                      Navigator.pop(ctx), // Just close, let them edit
                  child: const Text("Edit Details"),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.blue),
                  onPressed: () {
                    // --- LOGIC: SWITCH TO EXISTING CLIENT ---
                    Navigator.pop(ctx); // Close warning
                    setState(() {
                      _isNewClient = false; // Switch mode
                      _selectedClientId =
                          duplicate!['id']; // Select the duplicate
                      // Update the search bar text so it looks selected
                      if (_customerType == 'Commercial') {
                        _customerDisplayController.text =
                            duplicate['company_name'];
                      } else {
                        _customerDisplayController.text =
                            "${duplicate['first_name']} ${duplicate['last_name']}";
                      }
                    });
                    // Fetch their aircons immediately
                    _fetchClientAircons(_selectedClientId!);
                  },
                  child: const Text("Use Existing"),
                ),
              ],
            ),
          );
          return; // Stop navigation
        }
      } else {
        // Existing Client Mode Check
        if (_selectedClientId == null) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text("Please select a customer."),
              backgroundColor: Colors.red,
            ),
          );
          return;
        }
      }
    }

    // 2. Navigation Logic (Only happens if checks pass)
    if (_currentStep < 3) {
      setState(() => _currentStep++);
    } else {
      _submit();
    }
  }

  Widget _buildCurrentStep() {
    if (_currentStep == 0) return _stepCustomerType();
    if (_currentStep == 1) return _stepServiceType();
    if (_currentStep == 2) return _stepClientAndAsset();
    return _stepSchedule();
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

  // --- STEP 2: CLIENT & ASSET (Fixed Visuals) ---
  Widget _stepClientAndAsset() {
    final isEditing = widget.existingJob != null;

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. CUSTOMER SELECTION
          if (!isEditing) ...[
            // SHOW TOGGLE ONLY IF NEW JOB
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
                      label: "New Entry",
                      isSelected: _isNewClient,
                      onTap: () => setState(() => _isNewClient = true),
                    ),
                  ),
                  Expanded(
                    child: _ToggleOption(
                      label: "Existing Client",
                      isSelected: !_isNewClient,
                      onTap: () => setState(() => _isNewClient = false),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
          ],

          if (!_isNewClient || isEditing) ...[
            // --- EXISTING CLIENT SEARCH (LOCKED IF EDITING) ---
            const Text(
              "Customer",
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            if (isEditing)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 14,
                ),
                decoration: BoxDecoration(
                  color: Colors.grey[50], // Light grey background
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey.shade300),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.person, color: Colors.blueGrey),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            "CUSTOMER (LOCKED)",
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: Colors.grey,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            // Display the actual name from the job object
                            widget.existingJob?.clientName ?? "Unknown Client",
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.black87,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Icon(Icons.lock_outline, color: Colors.grey),
                  ],
                ),
              )
            else
              Autocomplete<Map<String, dynamic>>(
                optionsBuilder: (v) {
                  // Determine which ID we are looking for based on Step 0 selection
                  final targetTypeId = _customerType == 'Commercial' ? 1 : 2;

                  if (v.text.isEmpty)
                    return const Iterable<Map<String, dynamic>>.empty();
                  return _existingClients.where((c) {
                    // 1. Check if name matches search text
                    final name =
                        c['company_name'] ??
                        '${c['first_name']} ${c['last_name']}';
                    final matchesName = name.toLowerCase().contains(
                      v.text.toLowerCase(),
                    );

                    // 2. Check if Type matches the selected Customer Type
                    final typeId = c['customer_type_id'];
                    final matchesType = typeId == targetTypeId;

                    // Return TRUE only if BOTH match
                    return matchesName && matchesType;
                  });
                },
                displayStringForOption: (c) =>
                    c['company_name'] ?? '${c['first_name']} ${c['last_name']}',
                onSelected: (selection) {
                  if (isEditing) return; // Prevent changing if locked
                  setState(() {
                    _selectedClientId = selection['id'];
                    _fetchClientAircons(_selectedClientId!);
                  });
                },
                fieldViewBuilder: (ctx, ctrl, focus, onSub) {
                  return TextField(
                    controller: isEditing ? _customerDisplayController : ctrl,
                    focusNode: focus,
                    readOnly: isEditing, // LOCK IT
                    decoration: InputDecoration(
                      hintText: isEditing ? "" : "Search name...",
                      prefixIcon: const Icon(Icons.search),
                      // VISUAL LOCK INDICATOR
                      suffixIcon: isEditing
                          ? const Icon(Icons.lock, color: Colors.grey, size: 16)
                          : null,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      filled: true,
                      // GREY OUT IF LOCKED
                      fillColor: isEditing ? Colors.grey[200] : Colors.white,
                    ),
                  );
                },
              ),
            if (_selectedClientId != null) ...[
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    "Select Units",
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  // UPDATED: Allow Admin OR Manager to ADD
                  if (AppState.currentRole == UserRole.admin ||
                      AppState.currentRole == UserRole.serviceManager)
                    TextButton.icon(
                      onPressed: _addNewUnitDialog,
                      icon: const Icon(Icons.add, size: 16),
                      label: const Text("New Unit"),
                      style: TextButton.styleFrom(
                        visualDensity: VisualDensity.compact,
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 8),
              if (_clientAircons.isNotEmpty)
                Container(
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey.shade300),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    children: _clientAircons.map((unit) {
                      final brand = unit['brands']?['brand_name'] ?? 'Generic';
                      final type = unit['aircon_types']?['type_name'] ?? 'Unit';
                      final remarks = unit['remarks'] ?? '';
                      final isSelected = _selectedAirconIds.contains(
                        unit['id'],
                      );

                      // --- NEW: Format Tech Details ---
                      final hp = unit['horse_power'] != null
                          ? "${unit['horse_power']} HP"
                          : "";
                      final inverter = (unit['is_inverter'] == true)
                          ? "Inverter"
                          : "Non-Inverter";
                      // result: "1.5 HP • Inverter"
                      final techSpecs = [
                        hp,
                        inverter,
                      ].where((s) => s.isNotEmpty).join(' • ');
                      // --------------------------------

                      return Column(
                        children: [
                          ListTile(
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 4,
                            ),
                            // Checkbox on Left
                            leading: Checkbox(
                              value: isSelected,
                              onChanged: (v) {
                                setState(() {
                                  if (v == true)
                                    _selectedAirconIds.add(unit['id']);
                                  else
                                    _selectedAirconIds.remove(unit['id']);
                                });
                              },
                            ),
                            // Unit Info
                            title: Text(
                              "$brand $type",
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 14,
                              ),
                            ),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Tech Specs (Blue-Grey for visibility)
                                if (techSpecs.isNotEmpty)
                                  Padding(
                                    padding: const EdgeInsets.only(top: 2),
                                    child: Text(
                                      techSpecs,
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.blueGrey[700],
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ),
                                // Location/Remarks (Lighter Grey)
                                if (remarks.isNotEmpty)
                                  Text(
                                    remarks,
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey,
                                    ),
                                  ),
                              ],
                            ),
                            isThreeLine:
                                true, // Allows for taller rows with multiple lines of text
                            // UPDATED LOGIC:
                            // 1. Managers AND Admins can EDIT (Fix typos).
                            // 2. DELETE is removed (Moved to Data Management).
                            // UPDATED: Check for 'serviceManager'
                            trailing:
                                (AppState.currentRole == UserRole.admin ||
                                    AppState.currentRole ==
                                        UserRole.serviceManager)
                                ? Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      // EDIT
                                      IconButton(
                                        icon: const Icon(
                                          Icons.edit,
                                          size: 18,
                                          color: Colors.blue,
                                        ),
                                        onPressed: () => _editUnitDialog(unit),
                                        tooltip: "Edit Unit",
                                      ),
                                      // SMART REMOVE
                                      IconButton(
                                        icon: const Icon(
                                          Icons.delete_outline,
                                          size: 18,
                                          color: Colors.red,
                                        ),
                                        // Call the new smart handler
                                        onPressed: () =>
                                            _handleRemoveUnit(unit['id']),
                                        tooltip: "Remove Unit",
                                      ),
                                    ],
                                  )
                                : null,
                          ),
                          if (unit != _clientAircons.last)
                            const Divider(height: 1, indent: 16, endIndent: 16),
                        ],
                      );
                    }).toList(),
                  ),
                )
              else
                Center(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      children: [
                        const Text(
                          "No units found for this client.",
                          style: TextStyle(color: Colors.grey),
                        ),
                        const SizedBox(height: 8),
                        OutlinedButton.icon(
                          onPressed: _addNewUnitDialog,
                          icon: const Icon(Icons.add),
                          label: const Text("Add First Unit"),
                        ),
                      ],
                    ),
                  ),
                ),

              // Extra "Add Unit" Button at bottom for convenience
              if (_clientAircons.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: _addNewUnitDialog,
                      icon: const Icon(Icons.add),
                      label: const Text("Add Another Unit"),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.grey[700],
                        side: BorderSide(color: Colors.grey.shade300),
                      ),
                    ),
                  ),
                ),
            ],
          ] else ...[
            // --- NEW CLIENT FORM (Fixed Brand Color + Asterisks) ---
            Form(
              key: _formKey,
              child: Column(
                children: [
                  _SimpleInput(
                    controller: _fullNameController,
                    hint: _customerType == 'Residential'
                        ? "Full Name (e.g. Juan Cruz)"
                        : "Company Name / Contact Person",
                    icon: Icons.person_outline,
                    isRequired: true, // Red Asterisk
                  ),
                  const SizedBox(height: 12),
                  _SimpleInput(
                    controller: _addressController,
                    hint: "Complete Address (Unit, Street, Brgy, City)",
                    icon: Icons.location_on_outlined,
                    isRequired: true, // Red Asterisk
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: _SimpleInput(
                          controller: _phoneController,
                          hint: "Phone",
                          icon: Icons.phone,
                          isRequired: true,
                          validator: _validatePhone,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _SimpleInput(
                          controller: _emailController,
                          hint: "Email (Opt)",
                          icon: Icons.email_outlined,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),

                  // --- NEW AIRCON DETAILS ---
                  const Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      "First Unit Details (Optional)",
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.grey,
                      ), // Changed color to grey to de-emphasize
                    ),
                  ),
                  const SizedBox(height: 12),
                  // Brand & Type Row
                  Row(
                    children: [
                      // --- BRAND INPUT (Fixed Color) ---
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
                                    hintText: "Search...",
                                    // FIX: Force white background to match other fields
                                    filled: true,
                                    fillColor: Colors.white,
                                    labelStyle: TextStyle(
                                      color: Colors.grey[600],
                                    ), // Consistent grey label
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    contentPadding: const EdgeInsets.symmetric(
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

                      // --- TYPE DROPDOWN (Fixed Default) ---
                      Expanded(
                        child: DropdownButtonFormField<int>(
                          value:
                              _selectedAirconTypeId, // This is now NULL initially
                          hint: const Text(
                            "Select Type",
                          ), // Shows this when null
                          decoration: InputDecoration(
                            labelText: "Type",
                            labelStyle: TextStyle(color: Colors.grey[600]),
                            filled: true,
                            fillColor: Colors.white,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            contentPadding: const EdgeInsets.symmetric(
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
                  // NEW HP & INVERTER
                  Row(
                    children: [
                      Expanded(
                        child: _SimpleInput(
                          controller: _hpController,
                          hint: "HP (e.g. 1.5)",
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          decoration: BoxDecoration(
                            border: Border.all(
                              color: Colors.grey.shade400,
                            ), // Slightly darker border to match inputs
                            borderRadius: BorderRadius.circular(12),
                            color: Colors.white, // Ensure white background
                          ),
                          child: CheckboxListTile(
                            contentPadding: EdgeInsets.zero,
                            title: const Text(
                              "Inverter?",
                              style: TextStyle(fontSize: 14),
                            ),
                            value: _isInverter,
                            onChanged: (v) =>
                                setState(() => _isInverter = v ?? false),
                            controlAffinity: ListTileControlAffinity
                                .trailing, // Checkbox on right
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  _SimpleInput(
                    controller: _unitRemarkController,
                    hint: "Location (e.g. Master Bedroom)",
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  // --- STEP 3: SCHEDULE & TECHS ---
  Widget _stepSchedule() {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "Schedule",
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
          const SizedBox(height: 12),

          _SimpleInput(
            controller: _externalRefController,
            hint: "Ref No. (Optional)",
            icon: Icons.tag,
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
              // ... inside the Row ...
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
                      // --- RESTORED: CONFLICT CHECK ---
                      // 1. Check database for overlapping jobs
                      final hasConflict = await _checkScheduleConflict(
                        _scheduleDate,
                        t,
                      );

                      if (hasConflict) {
                        if (!mounted) return;
                        // 2. Show Warning Dialog
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

                        // If user clicked "Choose Different Time" or dismissed, stop here.
                        if (proceed != true) return;
                      }
                      // -------------------------------

                      // 3. Set Time (Only if no conflict or user overrode it)
                      setState(() => _scheduleTime = t);
                    }
                  },
                ),
              ),
            ],
          ),

          const SizedBox(height: 24),
          const Text(
            "Assign Team",
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

// --- HELPER: Simple Input with Red Asterisk Logic ---
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
        if (isRequired && (value == null || value.trim().isEmpty)) {
          return '$hint is required';
        }
        if (validator != null) return validator!(value);
        return null;
      },
      decoration: InputDecoration(
        // The RichText Label creates the Red Asterisk effect
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
  final VoidCallback onTap; // Don't forget this if you added it earlier

  const _JobCard({required this.order, required this.onTap});

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

    // --- NEW: Color Logic ---
    Color statusColor;
    Color bgColor;

    switch (order.status) {
      case 'Completed':
        statusColor = Colors.blue; // Requested: Blue
        bgColor = Colors.blue[50]!;
        break;
      case 'Cancelled':
        statusColor = Colors.grey; // Requested: Grey
        bgColor = Colors.grey[200]!;
        break;
      case 'In Progress':
        statusColor = Colors.green; // Requested: Green
        bgColor = Colors.green[50]!;
        break;
      case 'On Hold':
        statusColor = Colors.orange; // Requested: Orange
        bgColor = Colors.orange[50]!;
        break;
      default: // Pending
        statusColor =
            Colors.amber[900]!; // Requested: Yellow (Amber for readability)
        bgColor = Colors.amber[100]!;
    }
    // -------------------------

    // 2. Visuals
    final bool isCorp = order.isCorporate;
    final Color typeColor = isCorp ? AppTheme.primary : Colors.teal;
    final bool isCancelled = order.status == 'Cancelled';

    return GestureDetector(
      // Ensure this wrapper is here for clicking
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: AppTheme.surface,
          borderRadius: AppTheme.borderRadius,
          // Remove shadow if cancelled for visual distinction
          boxShadow: isCancelled ? [] : AppTheme.shadow,
          border: Border.all(color: AppTheme.borderColor),
        ),
        child: ClipRRect(
          borderRadius: AppTheme.borderRadius,
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppTheme.surface,
              // Use grey border if cancelled, else type color
              border: Border(
                left: BorderSide(
                  color: isCancelled ? Colors.grey : typeColor,
                  width: 4,
                ),
              ),
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
                          // 1. Client Name
                          Flexible(
                            child: Text(
                              order.clientName,
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                // Strike-through if cancelled
                                decoration: isCancelled
                                    ? TextDecoration.lineThrough
                                    : null,
                                color: isCancelled
                                    ? Colors.grey
                                    : Colors.black87,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          // 2. The ID
                          const SizedBox(width: 8),
                          Text(
                            order.displayId,
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

                    // 3. Status Badge (UPDATED TO USE NEW COLORS)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: bgColor, // Use the dynamic background color
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        order.status,
                        style: TextStyle(
                          fontSize: 10,
                          color: statusColor, // Use the dynamic text color
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 4),

                // ROW 2: Job Type
                Text(
                  order.jobType,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: isCancelled ? Colors.grey : typeColor,
                  ),
                ),

                // ROW 3: Action Tags
                if (!isCancelled &&
                    (order.isUnbilled ||
                        order.isUnpaid ||
                        order.hasNoTechs ||
                        order.hasNoUnits))
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Wrap(
                      spacing: 8,
                      runSpacing: 4,
                      children: [
                        if (order.isUnbilled)
                          const _StatusTag(
                            label: "Unbilled",
                            color: Colors.red,
                          ),

                        if (order.isUnpaid)
                          const _StatusTag(
                            label: "Unpaid",
                            color: Colors.orange,
                          ),

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
