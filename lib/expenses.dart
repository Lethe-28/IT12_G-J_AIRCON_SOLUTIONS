import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'ui_app_shell.dart';
import '../services/activity_service.dart';
import 'shared/widgets.dart' show LoadingOverlay, EmptyState;

// --- MODEL: Unified Transaction ---
class Transaction {
  final String id;
  final DateTime date;
  final String description;
  final double amount;
  final String type; // 'IN' or 'OUT'
  final String
  category; // 'Operational', 'Personal', 'Job Revenue', 'General Income'
  final String? relatedJob;
  final int? sourceJobId; // For editing

  Transaction({
    required this.id,
    required this.date,
    required this.description,
    required this.amount,
    required this.type,
    required this.category,
    this.relatedJob,
    this.sourceJobId,
  });
}

class ExpensesScreen extends StatefulWidget {
  const ExpensesScreen({super.key});

  @override
  State<ExpensesScreen> createState() => _ExpensesScreenState();
}

class _ExpensesScreenState extends State<ExpensesScreen> {
  bool _isLoading = true;
  final _supabase = Supabase.instance.client;

  List<Transaction> _monthTransactions = []; // Only for the selected month
  List<Transaction> _filteredTransactions = [];
  final _searchController = TextEditingController();

  // --- NEW CASH FLOW METRICS ---
  double _beginningCash = 0; // The "Buffer" from all previous months
  double _monthIn = 0; // Income this month
  double _monthOut = 0; // Expenses (OpEx + Personal) this month

  // FILTER STATE
  String _selectedFilter = 'All'; // All, Operational, Personal, Revenue/In
  // Removed range selector, default to daily
  DateTime _selectedMonth = DateTime.now(); // Defaults to current month

  double _displayIn = 0;
  double _displayOut = 0;

  DateTime _selectedDate = DateTime.now();

  // PAGINATION STATE
  int _itemsPerPage = 10;
  int _currentPage = 1;

  @override
  void initState() {
    super.initState();
    // Normalize date to the 1st of the month (e.g., Dec 1, 2025)
    final now = DateTime.now();
    _selectedMonth = DateTime(now.year, now.month, 1);

    _fetchMonthlyData(); // Call the new fetcher
    _searchController.addListener(_onFilterChanged);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _onFilterChanged() {
    final query = _searchController.text.toLowerCase();

    setState(() {
      _filteredTransactions = _monthTransactions.where((txn) {
        // 1. Text Search
        final matchesQuery =
            txn.description.toLowerCase().contains(query) ||
            (txn.relatedJob?.toLowerCase().contains(query) ?? false) ||
            txn.category.toLowerCase().contains(query);

        if (!matchesQuery) return false;

        // 2. SIMPLIFIED FILTERS
        if (_selectedFilter == 'All') return true;

        // REVENUE FILTER:
        // Shows: Automated Job Revenue + Manual 'Other Income'
        // Hides: Owner's 'Added Funds'
        if (_selectedFilter == 'Revenue') {
          return (txn.category == 'Job Revenue' ||
                  txn.category == 'Other Income') &&
              txn.type == 'IN';
        }

        // ADDED FUNDS FILTER:
        // Shows: Owner's deposits (Added Funds, Capital, Personal In)
        if (_selectedFilter == 'Added Funds') {
          return (txn.category == 'Added Funds' ||
                  txn.category == 'Capital' ||
                  txn.category == 'Personal') &&
              txn.type == 'IN';
        }

        // OPERATIONAL FILTER:
        // Shows: Business Expenses (Operational, Petty Cash, Capital Out)
        if (_selectedFilter == 'Operational') {
          return (txn.category == 'Operational' ||
                  txn.category == 'Petty Cash' ||
                  txn.category == 'Capital') &&
              txn.type == 'OUT';
        }

        // PERSONAL FILTER:
        // Shows: Owner Withdrawals
        if (_selectedFilter == 'Personal') {
          return txn.category == 'Personal' && txn.type == 'OUT';
        }

        return true;
      }).toList();
      // Reset to page 1
      _currentPage = 1;

      // 3. Recalculate Totals based on Filter
      double tempIn = 0;
      double tempOut = 0;

      for (var txn in _filteredTransactions) {
        if (txn.type == 'IN') {
          // Logic: If filter is "Personal", only count Personal In.
          // Otherwise, "Revenue" counts Business In.
          if (txn.category == 'Personal') {
            if (_selectedFilter == 'Personal') tempIn += txn.amount;
          } else {
            tempIn += txn.amount;
          }
        } else {
          tempOut += txn.amount;
        }
      }

      _displayIn = tempIn;
      _displayOut = tempOut;
    });
  }

  Future<void> _fetchMonthlyData() async {
    setState(() => _isLoading = true);

    try {
      // 1. DEFINE CURRENT MONTH RANGE
      // Ensure we are strictly checking 1st day of month to 1st day of next month
      final startOfMonth = _selectedMonth; // e.g., Dec 1
      final endOfMonth = DateTime(
        startOfMonth.year,
        startOfMonth.month + 1,
        1,
      ); // e.g., Jan 1

      final startStr = startOfMonth.toIso8601String();
      final endStr = endOfMonth.toIso8601String();

      // ====================================================
      // PART A: CALCULATE BEGINNING CASH (THE BUFFER)
      // Sum of ALL transactions BEFORE this month
      // ====================================================

      // A1. Past Payments (Money In)
      final pastPayments = await _supabase
          .from('payments')
          .select('amount')
          .lt(
            'payment_date',
            startStr,
          ); // <--- NOTICE '.lt' (Less Than Start Date)

      // A2. Past Expenses (Money In or Out)
      final pastExpenses = await _supabase
          .from('expenses')
          .select('amount, is_income')
          .lt('date', startStr); // <--- NOTICE '.lt'

      double pastIn = 0;
      double pastOut = 0;

      // Sum Past Payments
      for (var p in pastPayments) {
        pastIn += (p['amount'] as num).toDouble();
      }

      // Sum Past Expenses
      for (var e in pastExpenses) {
        final amt = (e['amount'] as num).toDouble();
        if (e['is_income'] == true) {
          pastIn += amt;
        } else {
          pastOut += amt;
        }
      }

      // SET THE BUFFER STATE
      _beginningCash = pastIn - pastOut;

      // ====================================================
      // PART B: FETCH TRANSACTIONS FOR *THIS* MONTH
      // ====================================================

      // B1. Current Payments
      final monthPayments = await _supabase
          .from('payments')
          .select(
            'id, amount, payment_date, payment_method, job_orders(client_jo_number, customers(company_name, first_name, last_name))',
          )
          .gte('payment_date', startStr)
          .lt('payment_date', endStr);

      // B2. Current Expenses
      final monthExpenses = await _supabase
          .from('expenses')
          .select(
            'id, amount, date, expense_name, expense_type, is_income, job_order_id, job_orders(client_jo_number)',
          )
          .gte('date', startStr)
          .lt('date', endStr);

      final List<Transaction> loaded = [];
      double tempMonthIn = 0;
      double tempMonthOut = 0;

      // Process Payments
      for (var p in monthPayments) {
        final amt = (p['amount'] as num).toDouble();
        tempMonthIn += amt;

        // Description Logic
        String desc = "Payment via ${p['payment_method']}";
        String? joNum;
        if (p['job_orders'] != null) {
          joNum = p['job_orders']['client_jo_number'];
          final cust = p['job_orders']['customers'];
          if (cust != null) {
            final name =
                cust['company_name'] ??
                "${cust['first_name']} ${cust['last_name']}";
            desc = "Payment from $name";
          }
        }

        loaded.add(
          Transaction(
            id: "P-${p['id']}",
            date: DateTime.parse(p['payment_date']).toLocal(),
            description: desc,
            amount: amt,
            type: 'IN',
            category: 'Job Revenue',
            relatedJob: joNum,
          ),
        );
      }

      // Process Expenses
      for (var e in monthExpenses) {
        final amt = (e['amount'] as num).toDouble();
        final isIncome = e['is_income'] == true;

        if (isIncome) {
          tempMonthIn += amt;
        } else {
          tempMonthOut += amt;
        }

        String? joNum;
        if (e['job_orders'] != null) {
          joNum = e['job_orders']['client_jo_number'];
        }

        loaded.add(
          Transaction(
            id: "E-${e['id']}",
            date: DateTime.parse(e['date']).toLocal(),
            description: e['expense_name'] ?? 'Unnamed',
            amount: amt,
            type: isIncome ? 'IN' : 'OUT',
            category:
                e['expense_type'] ??
                (isIncome ? 'General Income' : 'Operational'),
            relatedJob: joNum,
            sourceJobId: e['job_order_id'],
          ),
        );
      }

      // Sort Newest First
      loaded.sort((a, b) => b.date.compareTo(a.date));

      if (mounted) {
        setState(() {
          _monthTransactions = loaded;
          // Update the Monthly Totals
          _monthIn = tempMonthIn;
          _monthOut = tempMonthOut;
        });
        _onFilterChanged(); // Update the displayed list
      }
    } catch (e) {
      debugPrint("Error loading monthly data: $e");
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error: $e"), backgroundColor: Colors.red),
        );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _changeDate(int offset) {
    setState(() {
      _selectedDate = _selectedDate.add(Duration(days: offset));
    });
    _fetchMonthlyData();
  }

  DateTimeRange _computeRange() {
    // Fixed: Always Daily
    final start = DateTime(
      _selectedDate.year,
      _selectedDate.month,
      _selectedDate.day,
    );
    final end = start.add(const Duration(days: 1));
    return DateTimeRange(start: start, end: end);
  }

  // Pagination Helpers
  List<Transaction> _getPaginatedItems() {
    if (_filteredTransactions.isEmpty) return [];
    final startIndex = (_currentPage - 1) * _itemsPerPage;
    final endIndex = startIndex + _itemsPerPage;
    if (startIndex >= _filteredTransactions.length) return [];
    return _filteredTransactions.sublist(
      startIndex,
      endIndex > _filteredTransactions.length
          ? _filteredTransactions.length
          : endIndex,
    );
  }

  int _getTotalPages() {
    if (_filteredTransactions.isEmpty) return 1;
    return (_filteredTransactions.length / _itemsPerPage).ceil();
  }

  // --- HELPER: Change Month Logic ---
  void _changeMonth(int offset) {
    setState(() {
      _selectedMonth = DateTime(
        _selectedMonth.year,
        _selectedMonth.month + offset,
        1,
      );
    });
    _fetchMonthlyData(); // Refresh data for the new month
  }

  @override
  Widget build(BuildContext context) {
    // 1. Calculate Ending Cash (Net)
    // Formula: (Beginning Buffer + Cash In) - Cash Out
    final endingCash = (_beginningCash + _monthIn) - _monthOut;

    // 2. Format Month Name (e.g., "December")
    final monthName = [
      "January",
      "February",
      "March",
      "April",
      "May",
      "June",
      "July",
      "August",
      "September",
      "October",
      "November",
      "December",
    ][_selectedMonth.month - 1];

    return AppShell(
      selectedIndex: 2,
      body: LoadingOverlay(
        isLoading: _isLoading,
        child: Column(
          children: [
            // --- HEADER SECTION (Cash Flow Dashboard) ---
            Container(
              padding: const EdgeInsets.all(24),
              decoration: const BoxDecoration(
                color: Colors.white,
                border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0))),
              ),
              child: Column(
                children: [
                  // A. MONTH SELECTOR & ADD BUTTON
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // Month Navigator
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.grey.shade300),
                        ),
                        child: Row(
                          children: [
                            IconButton(
                              icon: const Icon(Icons.chevron_left, size: 20),
                              onPressed: () => _changeMonth(-1),
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                            ),
                            const SizedBox(width: 12),
                            Text(
                              "$monthName ${_selectedMonth.year}",
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                                color: Colors.black87,
                              ),
                            ),
                            const SizedBox(width: 12),
                            IconButton(
                              icon: const Icon(Icons.chevron_right, size: 20),
                              onPressed: () => _changeMonth(1),
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                            ),
                          ],
                        ),
                      ),

                      // Add Button
                      ElevatedButton.icon(
                        onPressed: () async {
                          await showDialog(
                            context: context,
                            builder: (_) => const _AddTransactionDialog(),
                          );
                          _fetchMonthlyData();
                        },
                        icon: const Icon(Icons.add, size: 18),
                        label: const Text("Add Record"),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blueAccent,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 12,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),

                  // B. FINANCIAL SUMMARY CARDS (Scrollable)
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        // 1. Beginning Cash (Buffer)
                        _SummaryCard(
                          label: "Beginning Cash",
                          amount: _beginningCash,
                          color: Colors.blueGrey,
                          icon: Icons.account_balance_wallet,
                          tooltip: "Cash carried over from previous months",
                        ),
                        const SizedBox(width: 12),

                        // 2. Cash In (Revenue)
                        _SummaryCard(
                          label: "Cash In",
                          amount: _monthIn,
                          color: Colors.green,
                          icon: Icons.arrow_downward,
                        ),
                        const SizedBox(width: 12),

                        // 3. Cash Out (Expenses + Personal)
                        _SummaryCard(
                          label: "Cash Out",
                          amount: _monthOut,
                          color: Colors.red,
                          icon: Icons.arrow_upward,
                        ),
                        const SizedBox(width: 12),

                        // 4. Ending Cash (Net Position)
                        _SummaryCard(
                          label: "Ending Cash",
                          amount: endingCash,
                          color: endingCash >= 0 ? Colors.blue : Colors.orange,
                          icon: Icons.savings,
                          isBold: true,
                          tooltip: "Actual cash on hand right now",
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // C. SEARCH & FILTER ROW
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _searchController,
                          decoration: InputDecoration(
                            hintText: "Search transactions...",
                            prefixIcon: const Icon(
                              Icons.search,
                              color: Colors.grey,
                            ),
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 12,
                            ),
                            filled: true,
                            fillColor: Colors.grey.shade50,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide.none,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          border: Border.all(color: Colors.grey.shade300),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            value: _selectedFilter,
                            icon: const Icon(Icons.filter_list, size: 20),
                            // Inside build() -> DropdownButton
                            items:
                                [
                                      'All',
                                      'Revenue',
                                      'Operational',
                                      'Personal',
                                      'Added Funds',
                                    ]
                                    .map(
                                      (f) => DropdownMenuItem(
                                        value: f,
                                        child: Text(f),
                                      ),
                                    )
                                    .toList(),
                            onChanged: (v) {
                              if (v != null) {
                                setState(() {
                                  _selectedFilter = v;
                                  _onFilterChanged();
                                });
                              }
                            },
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // --- TRANSACTION LIST ---
            Expanded(
              child: Container(
                color: const Color(0xFFF8FAFC), // Light grey background
                child: _filteredTransactions.isEmpty
                    ? const Center(
                        child: EmptyState(
                          icon: Icons.receipt_long,
                          title: "No Records",
                          message: "No transactions found for this month.",
                        ),
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.all(20),
                        itemCount: _filteredTransactions.length,
                        separatorBuilder: (ctx, i) =>
                            const SizedBox(height: 12),
                        itemBuilder: (ctx, i) {
                          final txn = _filteredTransactions[i];

                          return _TransactionCard(
                            txn: txn,
                            onTap: () async {
                              // 1. COMMON: Check if trying to edit a past month (Keep existing logic)
                              final now = DateTime.now();
                              final startOfCurrentMonth = DateTime(
                                now.year,
                                now.month,
                                1,
                              );

                              if (txn.date.isBefore(startOfCurrentMonth)) {
                                final proceed = await showDialog<bool>(
                                  context: context,
                                  builder: (c) => AlertDialog(
                                    title: const Row(
                                      children: [
                                        Icon(
                                          Icons.warning_amber,
                                          color: Colors.orange,
                                        ),
                                        SizedBox(width: 8),
                                        Text("Edit Past Record?"),
                                      ],
                                    ),
                                    content: const Text(
                                      "You are editing a record from a previous month.\n\n"
                                      "Changing this will affect the 'Beginning Cash' for all subsequent months. Do you want to proceed?",
                                    ),
                                    actions: [
                                      TextButton(
                                        onPressed: () =>
                                            Navigator.pop(c, false),
                                        child: const Text("Cancel"),
                                      ),
                                      ElevatedButton(
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: Colors.orange,
                                        ),
                                        onPressed: () => Navigator.pop(c, true),
                                        child: const Text("Edit Anyway"),
                                      ),
                                    ],
                                  ),
                                );
                                if (proceed != true) return;
                              }

                              // 2. ROUTING LOGIC
                              if (txn.id.startsWith('E-')) {
                                // --- EDIT EXPENSE ---

                                // NEW CHECK: Is this expense linked to a Job?
                                if (txn.relatedJob != null) {
                                  final confirmLinked = await showDialog<bool>(
                                    context: context,
                                    builder: (c) => AlertDialog(
                                      title: const Text("Edit Linked Expense?"),
                                      content: Text(
                                        "This expense is linked to Job Order ${txn.relatedJob}.\n\n"
                                        "Editing it here will change the cost record for that job. Proceed?",
                                      ),
                                      actions: [
                                        TextButton(
                                          onPressed: () =>
                                              Navigator.pop(c, false),
                                          child: const Text("Cancel"),
                                        ),
                                        ElevatedButton(
                                          onPressed: () =>
                                              Navigator.pop(c, true),
                                          child: const Text("Proceed"),
                                        ),
                                      ],
                                    ),
                                  );
                                  if (confirmLinked != true)
                                    return; // Stop if cancelled
                                }

                                // Open Dialog
                                await showDialog(
                                  context: context,
                                  builder: (_) => _AddTransactionDialog(
                                    transactionToEdit: txn,
                                  ),
                                );
                                _fetchMonthlyData();
                              } else if (txn.id.startsWith('P-')) {
                                // --- EDIT PAYMENT (Existing Logic) ---
                                final confirmEdit = await showDialog<bool>(
                                  context: context,
                                  builder: (c) => AlertDialog(
                                    title: const Text(
                                      "Edit Automated Payment?",
                                    ),
                                    content: const Text(
                                      "This payment was automatically linked to a Job Order.\n\n"
                                      "Editing it here will update the finance records, but ensure the changes align with the actual Job Order details.",
                                    ),
                                    actions: [
                                      TextButton(
                                        onPressed: () =>
                                            Navigator.pop(c, false),
                                        child: const Text("Cancel"),
                                      ),
                                      ElevatedButton(
                                        onPressed: () => Navigator.pop(c, true),
                                        child: const Text("Proceed"),
                                      ),
                                    ],
                                  ),
                                );

                                if (confirmEdit == true) {
                                  await showDialog(
                                    context: context,
                                    builder: (_) =>
                                        _EditPaymentDialog(payment: txn),
                                  );
                                  _fetchMonthlyData();
                                }
                              }
                            },
                          );
                        },
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
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
    return "${months[date.month - 1]} ${date.day}, ${date.year}";
  }

  Widget _buildBreakdownRow(
    String label,
    double amount,
    Color color, {
    bool isBold = false,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
            fontSize: isBold ? 16 : 14,
          ),
        ),
        Text(
          "${amount >= 0 ? '+' : ''}₱${amount.toStringAsFixed(2)}",
          style: TextStyle(
            color: color,
            fontWeight: FontWeight.bold,
            fontSize: isBold ? 16 : 14,
          ),
        ),
      ],
    );
  }
}

// --- WIDGETS ---

class _SummaryCard extends StatelessWidget {
  final String label;
  final double amount;
  final Color color;
  final IconData icon;
  final bool isBold; // <--- NEW
  final String? tooltip; // <--- NEW
  final VoidCallback? onTap;

  const _SummaryCard({
    required this.label,
    required this.amount,
    required this.color,
    required this.icon,
    this.isBold = false, // Default to false
    this.tooltip, // Default to null
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    // Wrap in Tooltip widget if a message exists
    Widget content = Container(
      width: 140, // Fixed width for alignment
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: color),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    color: color,
                    fontWeight: FontWeight.bold,
                    fontSize: 11,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              "₱${amount.toStringAsFixed(2)}",
              style: TextStyle(
                color: color,
                // Use the isBold flag here
                fontWeight: isBold ? FontWeight.w900 : FontWeight.w700,
                fontSize: 18,
              ),
            ),
          ),
        ],
      ),
    );

    if (tooltip != null) {
      content = Tooltip(message: tooltip, child: content);
    }

    if (onTap != null) {
      content = InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: content,
      );
    }

    return content;
  }
}

class _TransactionCard extends StatelessWidget {
  final Transaction txn;
  final VoidCallback onTap; // <--- This was missing

  const _TransactionCard({
    required this.txn,
    required this.onTap, // <--- Add this to constructor
  });

  @override
  Widget build(BuildContext context) {
    final isIncome = txn.type == 'IN';
    final isPersonal = txn.category == 'Personal';

    // Choose color based on type
    final color = isPersonal
        ? Colors.blueGrey
        : (isIncome ? Colors.green : Colors.red);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap, // <--- Connect the tap here
        borderRadius: BorderRadius.circular(12),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey.shade200, width: 1),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.04),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Colored Strip
                  Container(width: 4, color: color),

                  // Content
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: Row(
                        children: [
                          // Icon
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: color.withOpacity(0.1),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              isPersonal
                                  ? Icons.home
                                  : (isIncome
                                        ? Icons.attach_money
                                        : (txn.category == 'Petty Cash'
                                              ? Icons.monetization_on_outlined
                                              : Icons.shopping_bag)),
                              color: color,
                              size: 18,
                            ),
                          ),
                          const SizedBox(width: 12),

                          // Description & Meta
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  txn.description,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                    color: Colors.black87,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 4),
                                Wrap(
                                  spacing: 4,
                                  children: [
                                    if (txn.relatedJob != null)
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 4,
                                          vertical: 2,
                                        ),
                                        decoration: BoxDecoration(
                                          color: Colors.blue.withOpacity(0.1),
                                          borderRadius: BorderRadius.circular(
                                            4,
                                          ),
                                        ),
                                        child: Text(
                                          txn.relatedJob!,
                                          style: const TextStyle(
                                            fontSize: 10,
                                            color: Colors.blue,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                    Text(
                                      "${txn.category} • ${txn.date.month}/${txn.date.day}",
                                      style: const TextStyle(
                                        fontSize: 11,
                                        color: Colors.grey,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),

                          const SizedBox(width: 8),

                          // Amount
                          Text(
                            "${isIncome ? '+' : '-'}₱${txn.amount.toStringAsFixed(2)}",
                            style: TextStyle(
                              color: color,
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
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
        ),
      ),
    );
  }
}

// --- ADD TRANSACTION DIALOG (Refactored) ---
class _AddTransactionDialog extends StatefulWidget {
  final Transaction? transactionToEdit;
  const _AddTransactionDialog({this.transactionToEdit});

  @override
  State<_AddTransactionDialog> createState() => _AddTransactionDialogState();
}

class _AddTransactionDialogState extends State<_AddTransactionDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _amountController = TextEditingController();

  bool _isIncome = false;
  String _category = 'Operational';
  DateTime _date = DateTime.now();
  int? _selectedJobId;

  // Job Data for Search
  List<Map<String, dynamic>> _activeJobs = [];

  @override
  void initState() {
    super.initState();
    _fetchActiveJobs();

    // --- PRE-FILL DATA IF EDITING ---
    if (widget.transactionToEdit != null) {
      final txn = widget.transactionToEdit!;
      _nameController.text = txn.description;
      _amountController.text = txn.amount.toStringAsFixed(2);
      _date = txn.date;
      _isIncome = txn.type == 'IN';
      _category = txn.category;
      _selectedJobId = txn.sourceJobId;
    }
  }

  Future<void> _fetchActiveJobs() async {
    final res = await Supabase.instance.client
        .from('job_orders')
        .select('id, client_jo_number, customers(company_name, last_name)')
        .neq('status', 'Completed')
        .order('id', ascending: false);

    if (mounted) {
      setState(() {
        _activeJobs = List<Map<String, dynamic>>.from(res);
      });
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    // Input Cleaning (Remove ₱, commas)
    String cleanAmount = _amountController.text
        .replaceAll('₱', '')
        .replaceAll(',', '')
        .replaceAll(' ', '')
        .trim();

    final amount = double.tryParse(cleanAmount);
    if (amount == null) return;

    try {
      final data = {
        'expense_name': _nameController.text.trim(),
        'amount': amount,
        'date': _date.toString().split(' ')[0],
        'expense_type': _category,
        'is_income': _isIncome,
        'user_id': Supabase.instance.client.auth.currentUser?.id,
        // Only link job if it's an Operational Expense (Money Out)
        'job_order_id': ((_category == 'Operational') && !_isIncome)
            ? _selectedJobId
            : null,
      };

      if (widget.transactionToEdit != null) {
        // UPDATE EXISTING
        final rawId = widget.transactionToEdit!.id.split('-')[1];
        await Supabase.instance.client
            .from('expenses')
            .update(data)
            .eq('id', rawId);
      } else {
        // INSERT NEW
        await Supabase.instance.client.from('expenses').insert(data);
      }

      if (mounted) Navigator.pop(context);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error: $e"), backgroundColor: Colors.red),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        width: 400, // Fixed width popup
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.transactionToEdit != null ? "Edit Record" : "Add Record",
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 20),

              // 1. TYPE TOGGLE
              Row(
                children: [
                  // MONEY OUT TOGGLE
                  Expanded(
                    child: _TypeToggle(
                      label: "Money Out",
                      isSelected: !_isIncome,
                      color: Colors.red,
                      onTap: () => setState(() {
                        _isIncome = false;
                        _category = 'Operational'; // Default
                      }),
                    ),
                  ),
                  const SizedBox(width: 12),

                  // MONEY IN TOGGLE
                  Expanded(
                    child: _TypeToggle(
                      label: "Money In",
                      isSelected: _isIncome,
                      color: Colors.green,
                      onTap: () => setState(() {
                        _isIncome = true;
                        // Default to 'Added Funds' because 'Revenue' is disabled
                        _category = 'Added Funds';
                      }),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // 2. CATEGORY SELECTOR (Strict Mode)
              DropdownButtonFormField<String>(
                value: _category,
                decoration: const InputDecoration(
                  labelText: "Category",
                  border: OutlineInputBorder(),
                ),
                // LOGIC:
                // Money In: Only 'Added Funds' (Owner) or 'Other Income' (Scrap).
                //           Real Revenue MUST come from Job Orders.
                // Money Out: 'Operational' (Biz) or 'Personal' (Owner).
                items:
                    (_isIncome
                            ? ['Added Funds', 'Other Income']
                            : ['Operational', 'Personal'])
                        .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                        .toList(),
                onChanged: (v) => setState(() => _category = v!),
              ),
              const SizedBox(height: 12),

              // --- NEW: DATE PICKER WITH FUTURE LOCK ---
              GestureDetector(
                onTap: () async {
                  final now = DateTime.now();
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: _date.isAfter(now) ? now : _date,
                    firstDate: DateTime(2020),
                    // CRITICAL: This locks future dates
                    lastDate: now,
                    builder: (context, child) {
                      return Theme(
                        data: Theme.of(context).copyWith(
                          colorScheme: const ColorScheme.light(
                            primary: Colors.blueAccent,
                          ),
                        ),
                        child: child!,
                      );
                    },
                  );
                  if (picked != null) {
                    setState(() => _date = picked);
                  }
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 16,
                  ),
                  decoration: BoxDecoration(
                    border: Border.all(
                      color: Colors.grey,
                    ), // Matches default InputBorder
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        // Simple Format: MM/DD/YYYY
                        "Date: ${_date.month}/${_date.day}/${_date.year}",
                        style: const TextStyle(
                          fontSize: 16,
                          color: Colors.black87,
                        ),
                      ),
                      const Icon(Icons.calendar_today, color: Colors.grey),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 12),

              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: "Description / Name",
                  border: OutlineInputBorder(),
                ),
                validator: (v) => v!.isEmpty ? "Required" : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _amountController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: "Amount (₱)",
                  border: OutlineInputBorder(),
                ),
                validator: (v) => v!.isEmpty ? "Required" : null,
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _save,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    backgroundColor: Colors.blueAccent,
                    foregroundColor: Colors.white,
                  ),
                  child: const Text("Save Record"),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CategoryChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool isSelected;
  final VoidCallback onTap;

  const _CategoryChip({
    required this.label,
    required this.icon,
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
          color: isSelected ? Colors.blue.withOpacity(0.1) : Colors.grey[100],
          border: Border.all(
            color: isSelected ? Colors.blue : Colors.transparent,
            width: 2,
          ),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          children: [
            Icon(icon, color: isSelected ? Colors.blue : Colors.grey, size: 20),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                color: isSelected ? Colors.blue : Colors.grey,
                fontWeight: FontWeight.bold,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TypeToggle extends StatelessWidget {
  final String label;
  final Color color;
  final bool isSelected;
  final VoidCallback onTap;

  const _TypeToggle({
    required this.label,
    required this.color,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(6),
          boxShadow: isSelected
              ? [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 2)]
              : null,
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: isSelected ? color : Colors.grey,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }
}

// --- NEW: Dedicated Dialog for Editing Payments ---
class _EditPaymentDialog extends StatefulWidget {
  final Transaction payment;
  const _EditPaymentDialog({required this.payment});

  @override
  State<_EditPaymentDialog> createState() => _EditPaymentDialogState();
}

class _EditPaymentDialogState extends State<_EditPaymentDialog> {
  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();

  // Extra fields specific to payments
  String _method = 'Cash';
  DateTime _date = DateTime.now();
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadPaymentDetails();
  }

  Future<void> _loadPaymentDetails() async {
    // 1. Parse ID (Remove "P-" prefix)
    final id = widget.payment.id.split('-')[1];

    // 2. Fetch fresh data from DB
    final data = await Supabase.instance.client
        .from('payments')
        .select('amount, payment_date, payment_method')
        .eq('id', id)
        .single();

    if (mounted) {
      setState(() {
        _amountController.text = data['amount'].toString();
        _date = DateTime.parse(data['payment_date']);
        _method = data['payment_method'] ?? 'Cash';
        _isLoading = false;
      });
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    final id = widget.payment.id.split('-')[1];
    final cleanAmount = _amountController.text.replaceAll(',', '').trim();

    // BUSINESS STANDARD FIX:
    // Format explicitly as YYYY-MM-DD based on the user's selection.
    // We do NOT use toUtc() because we want to force this specific calendar date.
    final String dateString =
        "${_date.year}-${_date.month.toString().padLeft(2, '0')}-${_date.day.toString().padLeft(2, '0')}";

    try {
      await Supabase.instance.client
          .from('payments')
          .update({
            'amount': double.parse(cleanAmount),
            'payment_date': dateString,
            'payment_method': _method,
          })
          .eq('id', id);

      if (mounted) Navigator.pop(context, true); // Return true on success
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Error: $e")));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        width: 400,
        padding: const EdgeInsets.all(24),
        child: _isLoading
            ? const SizedBox(
                height: 100,
                child: Center(child: CircularProgressIndicator()),
              )
            : Form(
                key: _formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      "Edit Payment",
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      "Linked to ${widget.payment.relatedJob ?? 'Unknown Job'}",
                      style: const TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                    const SizedBox(height: 20),

                    // Date Picker
                    GestureDetector(
                      onTap: () async {
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: _date,
                          firstDate: DateTime(2020),
                          lastDate: DateTime.now(), // No future dates
                        );
                        if (picked != null) setState(() => _date = picked);
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 16,
                        ),
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              "Date: ${_date.month}/${_date.day}/${_date.year}",
                            ),
                            const Icon(
                              Icons.calendar_today,
                              color: Colors.grey,
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Amount
                    TextFormField(
                      controller: _amountController,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: const InputDecoration(
                        labelText: "Amount",
                        border: OutlineInputBorder(),
                        prefixText: "₱ ",
                      ),
                      validator: (v) => v!.isEmpty ? "Required" : null,
                    ),
                    const SizedBox(height: 12),

                    // Method Dropdown
                    DropdownButtonFormField<String>(
                      value:
                          [
                            'Cash',
                            'GCash',
                            'Bank Transfer',
                            'Cheque',
                          ].contains(_method)
                          ? _method
                          : 'Cash',
                      decoration: const InputDecoration(
                        labelText: "Payment Method",
                        border: OutlineInputBorder(),
                      ),
                      items: ['Cash', 'GCash', 'Bank Transfer', 'Cheque']
                          .map(
                            (m) => DropdownMenuItem(value: m, child: Text(m)),
                          )
                          .toList(),
                      onChanged: (v) => setState(() => _method = v!),
                    ),
                    const SizedBox(height: 24),

                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _save,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green, // Green for money
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                        ),
                        child: const Text("Update Payment"),
                      ),
                    ),
                  ],
                ),
              ),
      ),
    );
  }
}
