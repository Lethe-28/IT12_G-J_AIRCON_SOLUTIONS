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
  final String category; // 'Operational', 'Personal', 'Job Revenue', 'General Income'
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

  List<Transaction> _allTransactions = [];
  List<Transaction> _filteredTransactions = [];
  final _searchController = TextEditingController();

  // FILTER STATE
  String _selectedFilter = 'All'; // All, Operational, Personal, Revenue/In
  // Removed range selector, default to daily

  double _displayIn = 0;
  double _displayOut = 0;

  DateTime _selectedDate = DateTime.now();

  // PAGINATION STATE
  int _itemsPerPage = 10;
  int _currentPage = 1;

  @override
  void initState() {
    super.initState();
    _fetchCashFlow();
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
      _filteredTransactions = _allTransactions.where((txn) {
        // 1. Text Search
        final matchesQuery =
            txn.description.toLowerCase().contains(query) ||
            (txn.relatedJob?.toLowerCase().contains(query) ?? false) ||
            txn.category.toLowerCase().contains(query);

        if (!matchesQuery) return false;

        // 2. Category Filter
        if (_selectedFilter == 'All') return true;
        if (_selectedFilter == 'Revenue / In') return txn.type == 'IN';
        if (_selectedFilter == 'Expenses / Out') return txn.type == 'OUT'; // Added Filter
        if (_selectedFilter == 'Operational')
          return txn.category == 'Operational';
        if (_selectedFilter == 'Petty Cash')
          return txn.category == 'Petty Cash';
        if (_selectedFilter == 'Personal') return txn.category == 'Personal';

        return true;
      }).toList();

      // Reset to page 1 when filter changes
      _currentPage = 1;

      // 3. Recalculate Totals based on Filter
      double tempIn = 0;
      double tempOut = 0;

      for (var txn in _filteredTransactions) {
        if (txn.type == 'IN') {
           // Rule: Only count Personal Income if explicitly filtering for Personal
           // Otherwise, "Cash In" means Business Revenue
           if (txn.category == 'Personal') {
             if (_selectedFilter == 'Personal') {
               tempIn += txn.amount;
             }
           } else {
             // Normal Business Revenue
             tempIn += txn.amount;
           }
        } else {
           // Expenses (OUT)
           tempOut += txn.amount;
        }
      }
      
      _displayIn = tempIn;
      _displayOut = tempOut;

      debugPrint(
        "Filtered transactions: ${_filteredTransactions.length} (from ${_allTransactions.length})",
      );
    });
  }



  Future<void> _fetchCashFlow() async {
    setState(() => _isLoading = true);
    try {
      final range = _computeRange();

      final startStr = range.start.toIso8601String();
      final endStr = range.end.toIso8601String();

      // 1. FETCH PAYMENTS (Job Revenue - ALWAYS IN)
      final paymentsRes = await _supabase
          .from('payments')
          .select(
            'id, amount, payment_date, payment_method, job_orders(client_jo_number, customers(company_name, first_name, last_name))',
          )
          .gte('payment_date', startStr)
          .lt('payment_date', endStr);

      debugPrint("Payments fetched: ${paymentsRes.length}");

      // 2. FETCH EXPENSES (Can be IN or OUT based on is_income)
      final expensesRes = await _supabase
          .from('expenses')
          .select(
            'id, amount, date, expense_name, expense_type, is_income, job_order_id, job_orders(client_jo_number)',
          )
          .gte('date', startStr)
          .lt('date', endStr);

      debugPrint("Expenses fetched: ${expensesRes.length}");

      final List<Transaction> loaded = [];
      double inSum = 0;
      double outSum = 0;

      // Process Job Payments
      for (var p in paymentsRes) {
        final amt = (p['amount'] as num).toDouble();
        inSum += amt;

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

      // Process Expenses Table (Includes Expenses AND General Income)
      for (var e in expensesRes) {
        final amt = (e['amount'] as num).toDouble();
        final isIncome = e['is_income'] == true;

        if (isIncome) {
          // FIX: Exclude 'Personal' income from "Cash In" (Revenue)
          if (e['expense_type'] != 'Personal') {
             inSum += amt;
          }
        } else {
          outSum += amt;
        }

        String? joNum;
        if (e['job_orders'] != null) {
          joNum = e['job_orders']['client_jo_number'];
        }

        loaded.add(
          Transaction(
            id: "E-${e['id']}",
            date: DateTime.parse(e['date']).toLocal(),
            description: e['expense_name'] ?? 'Unnamed Transaction',
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

      // FIX: UPDATED SORTING LOGIC
      // 1. Sort by Date Descending
      // 2. Tie-Breaker: Sort by ID Descending (Newest Entry on Top)
      loaded.sort((a, b) {
        int dateComp = b.date.compareTo(a.date);
        if (dateComp != 0) return dateComp;

        // Tie-breaker: ID
        // Strip the prefix (P- or E-) to compare actual ID numbers
        int idA = int.tryParse(a.id.split('-')[1]) ?? 0;
        int idB = int.tryParse(b.id.split('-')[1]) ?? 0;

        return idB.compareTo(idA); // Descending ID
      });

      if (mounted) {
        setState(() {
          _allTransactions = loaded;
          // Note: Initial totals are now handled by _onFilterChanged
        });
        debugPrint("Fetched ${loaded.length} transactions");
        _onFilterChanged(); // Apply filters immediately
      }
    } catch (e) {
      debugPrint("Error fetching cash flow: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Error loading data: $e"),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _changeDate(int offset) {
    setState(() {
      _selectedDate = _selectedDate.add(Duration(days: offset));
    });
    _fetchCashFlow();
  }

  DateTimeRange _computeRange() {
    // Fixed: Always Daily
    final start = DateTime(_selectedDate.year, _selectedDate.month, _selectedDate.day);
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

  @override
  Widget build(BuildContext context) {
    final netCash = _displayIn - _displayOut;

    return AppShell(
      selectedIndex: 2,
      body: LoadingOverlay(
        isLoading: _isLoading,
        child: Column(
          children: [
            // --- HEADER ---
            Container(
              padding: const EdgeInsets.all(24),
              color: Colors.white,
              child: Column(
                children: [
                  // 1. Month Selector & Add Button
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
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
                              onPressed: () => _changeDate(-1),
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                            ),
                            const SizedBox(width: 4),
                            TextButton(
                              onPressed: () {
                                setState(() {
                                  _selectedDate = DateTime.now();
                                  _currentPage = 1;
                                });
                                _fetchCashFlow();
                              },
                              style: TextButton.styleFrom(
                                padding: const EdgeInsets.symmetric(horizontal: 4),
                                minimumSize: Size.zero,
                                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              ),
                              child: const Text("Today", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.blueAccent)),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              _formatDate(_selectedDate),
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Colors.black87,
                              ),
                            ),
                            const SizedBox(width: 8),
                            IconButton(
                              icon: const Icon(Icons.chevron_right, size: 20),
                              onPressed: () => _changeDate(1),
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                            ),
                          ],
                        ),
                      ),
                      ElevatedButton.icon(
                        onPressed: () async {
                          await showDialog(
                            context: context,
                            builder: (_) => const _AddTransactionDialog(),
                          );
                          _fetchCashFlow();
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blueAccent,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 12,
                          ),
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        icon: const Icon(Icons.add, size: 20),
                        label: const Text(
                          "Add Record",
                          style: TextStyle(fontWeight: FontWeight.w600),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // 2. Summary Cards (Scrollable for Mobile)
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        SizedBox(
                          width: 115,
                          child: _SummaryCard(
                            label: _selectedFilter == 'Personal' ? "Personal In" : "Cash In",
                            amount: _displayIn,
                            color: Colors.green.shade600,
                            icon: Icons.arrow_downward,
                            onTap: () {
                              setState(() {
                                _selectedFilter = 'Revenue / In';
                                _onFilterChanged();
                              });
                            },
                          ),
                        ),
                        const SizedBox(width: 10),
                        SizedBox(
                          width: 115,
                          child: _SummaryCard(
                            label: _selectedFilter == 'Personal' ? "Personal Out" : "Cash Out",
                            amount: _displayOut,
                            color: Colors.red.shade600,
                            icon: Icons.arrow_upward,
                            onTap: () {
                              setState(() {
                                _selectedFilter = 'Expenses / Out';
                                _onFilterChanged();
                              });
                            },
                          ),
                        ),
                        const SizedBox(width: 10),
                        SizedBox(
                          width: 125,
                          child: _SummaryCard(
                            label: "Net Cash",
                            amount: netCash,
                            color: netCash >= 0
                                ? Colors.blue.shade600
                                : Colors.orange.shade600,
                            icon: Icons.account_balance_wallet,
                            onTap: () {
                              showDialog(
                                context: context, 
                                builder: (_) => AlertDialog(
                                  title: const Text("Net Cash Breakdown"),
                                  content: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      _buildBreakdownRow("Total Cash In", _displayIn, Colors.green),
                                      const SizedBox(height: 8),
                                      _buildBreakdownRow("Total Cash Out", _displayOut, Colors.red),
                                      const Divider(),
                                      _buildBreakdownRow("Net Cash", netCash, Colors.blue, isBold: true),
                                    ],
                                  ),
                                  actions: [
                                    TextButton(
                                      onPressed: () => Navigator.pop(context),
                                      child: const Text("Close"),
                                    )
                                  ],
                                )
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  // 3. Search Bar & Filter Dropdown (Combined Row)
                  Row(
                    children: [
                      // Search Bar (Expanded to take available space)
                      Expanded(
                        child: TextField(
                          controller: _searchController,
                          decoration: InputDecoration(
                            hintText: "Search transactions...",
                            hintStyle: TextStyle(color: Colors.grey.shade400),
                            prefixIcon: Icon(
                              Icons.search,
                              color: Colors.grey.shade600,
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(
                                color: Colors.grey.shade300,
                              ),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(
                                color: Colors.grey.shade300,
                              ),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: const BorderSide(
                                color: Colors.blueAccent,
                                width: 2,
                              ),
                            ),
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 14,
                            ),
                            filled: true,
                            fillColor: Colors.white,
                          ),
                        ),
                      ),

                      const SizedBox(width: 12),
                      // Filter Dropdown
                      Container(
                        height: 48,
                        padding: const EdgeInsets.symmetric(horizontal: 14),
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey.shade300),
                          borderRadius: BorderRadius.circular(12),
                          color: Colors.white,
                        ),
                        child: DropdownButton<String>(
                          value: _selectedFilter,
                          underline: const SizedBox.shrink(),
                          icon: Icon(
                            Icons.arrow_drop_down,
                            color: Colors.grey.shade700,
                          ),
                          style: const TextStyle(
                            color: Colors.black87,
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                          items:
                              ['All', 'Revenue / In', 'Expenses / Out', 'Operational', 'Petty Cash', 'Personal']
                                  .map(
                                    (filter) => DropdownMenuItem(
                                      value: filter,
                                      child: Text(filter),
                                    ),
                                  )
                                  .toList(),
                          onChanged: (value) {
                            if (value != null) {
                              setState(() {
                                _selectedFilter = value;
                                _onFilterChanged();
                              });
                            }
                          },
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const Divider(height: 1),

            // --- TRANSACTION LIST WITH PAGINATION ---
            Expanded(
              child: Container(
                color: Colors.grey.shade50,
                child: _filteredTransactions.isEmpty
                    ? LayoutBuilder(
                        builder: (context, constraints) {
                          // FIX: Scrollable Empty State to prevent overflow on small screens
                          return SingleChildScrollView(
                              physics: const AlwaysScrollableScrollPhysics(),
                              child: ConstrainedBox(
                              constraints: BoxConstraints(
                                minHeight: constraints.maxHeight,
                              ),
                              child: const Center(
                                child: Padding(
                                  padding: EdgeInsets.all(20.0),
                                  child: EmptyState(
                                    icon: Icons.receipt_long,
                                    title: "No Transactions",
                                    message:
                                        "No records found matching your criteria.",
                                  ),
                                ),
                              ),
                            ),
                          );
                        },
                      )
                    : Column(
                          children: [
                          // List with Pagination
                          Expanded(
                            child: _getPaginatedItems().isEmpty
                                ? const Center(
                                    child: Padding(
                                      padding: EdgeInsets.all(20.0),
                                      child: Text(
                                        "No transactions on this page",
                                        style: TextStyle(
                                          color: Colors.grey,
                                          fontSize: 14,
                                        ),
                                      ),
                                    ),
                                  )
                                : ListView.separated(
                                    padding: const EdgeInsets.all(16),
                                    itemCount: _getPaginatedItems().length,
                                    separatorBuilder: (ctx, i) =>
                                        const SizedBox(height: 12),
                                    itemBuilder: (ctx, i) {
                                      final txn = _getPaginatedItems()[i];
                                      return InkWell(
                                        onTap: () async {
                                          if (!txn.id.startsWith('E-')) {
                                             ScaffoldMessenger.of(context).showSnackBar(
                                               const SnackBar(content: Text("Cannot edit job payments here.")),
                                             );
                                             return;
                                          }
                                          await showDialog(
                                            context: context,
                                            builder: (_) => _AddTransactionDialog(transactionToEdit: txn),
                                          );
                                          _fetchCashFlow();
                                        },
                                        child: _TransactionCard(txn: txn),
                                      );
                                    },
                                    ),
                          ),
                          // Pagination Controls
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 12,
                            ),
                            decoration: BoxDecoration(
                              border: Border(
                                top: BorderSide(color: Colors.grey.shade300),
                              ),
                              color: Colors.white,
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                // Previous Button
                                ElevatedButton.icon(
                                  onPressed: _currentPage > 1
                                      ? () => setState(() => _currentPage--)
                                      : null,
                                  icon: const Icon(
                                    Icons.chevron_left,
                                    size: 18,
                                  ),
                                  label: const Text(
                                    "Previous",
                                    style: TextStyle(
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.blueAccent,
                                    foregroundColor: Colors.white,
                                    disabledBackgroundColor:
                                        Colors.grey.shade300,
                                    disabledForegroundColor:
                                        Colors.grey.shade500,
                                    elevation: 0,
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 16,
                                      vertical: 10,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                  ),
                                ),
                                // Page Info
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 8,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.grey.shade100,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    "Page $_currentPage of ${_getTotalPages()}",
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 13,
                                      color: Colors.black87,
                                    ),
                                  ),
                                ),
                                // Next Button
                                ElevatedButton.icon(
                                  onPressed: _currentPage < _getTotalPages()
                                      ? () => setState(() => _currentPage++)
                                      : null,
                                  iconAlignment: IconAlignment.end,
                                  icon: const Icon(
                                    Icons.chevron_right,
                                    size: 18,
                                  ),
                                  label: const Text(
                                    "Next",
                                    style: TextStyle(
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.blueAccent,
                                    foregroundColor: Colors.white,
                                    disabledBackgroundColor:
                                        Colors.grey.shade300,
                                    disabledForegroundColor:
                                        Colors.grey.shade500,
                                    elevation: 0,
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 16,
                                      vertical: 10,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(8),
                                    ),
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
    );
  }

  String _formatDate(DateTime date) {
    const months = [
      "Jan", "Feb", "Mar", "Apr", "May", "Jun", 
      "Jul", "Aug", "Sep", "Oct", "Nov", "Dec",
    ];
    return "${months[date.month - 1]} ${date.day}, ${date.year}";
  }

  Widget _buildBreakdownRow(String label, double amount, Color color, {bool isBold = false}) {
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
  final VoidCallback? onTap;

  const _SummaryCard({
    required this.label,
    required this.amount,
    required this.color,
    required this.icon,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(icon, size: 16, color: color),
                    const SizedBox(width: 4),
                    // FIX: Flexible allows text to shrink if needed
                    Expanded(
                      child: Text(
                        label,
                        style: TextStyle(
                          color: color,
                          fontWeight: FontWeight.bold,
                          fontSize: 11, // Slightly smaller font
                        ),
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                // FIX: FittedBox forces the amount to scale down instead of overflowing
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    "₱${amount.toStringAsFixed(2)}",
                    style: TextStyle(
                      color: color,
                      fontWeight: FontWeight.w800,
                      fontSize: 18,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _TransactionCard extends StatelessWidget {
  final Transaction txn;
  const _TransactionCard({required this.txn});

  @override
  Widget build(BuildContext context) {
    final isIncome = txn.type == 'IN';
    final color = isIncome ? Colors.green : Colors.red;

    return Container(
      // 1. Remove padding from here (moved inside) so the colored strip touches the edge
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        // 2. FIX: Use a uniform border here (all sides same color/width) to support borderRadius
        border: Border.all(color: Colors.grey.shade200, width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      // 3. Clip children so the colored strip respects the rounded corners
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 4. The Colored Strip (Simulates the left border)
              Container(width: 4, color: color),

              // 5. The Content
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(14), // Padding is now here
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
                          txn.category == 'Personal'
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

                      // Description
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
                            // Tags
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
                                      borderRadius: BorderRadius.circular(4),
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

  bool _isIncome = false; // Toggle for General Cash In
  String _category = 'Operational';
  DateTime _date = DateTime.now();
  int? _selectedJobId;

  // Job Data for Search
  List<Map<String, dynamic>> _activeJobs = [];

  @override
  void initState() {
    super.initState();
    _fetchActiveJobs();
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
        .select(
          'id, client_jo_number, date_scheduled, customers(company_name, last_name)',
        )
        .neq('status', 'Completed')
        // FIX: Order by ID descending (Latest created job first)
        .order('id', ascending: false);

    if (mounted) {
      setState(() {
        _activeJobs = List<Map<String, dynamic>>.from(res);
      });
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    
    // FIX: Flexible Input Cleaning (Remove ₱, commas, spaces)
    String cleanAmount = _amountController.text
        .replaceAll('₱', '')
        .replaceAll(',', '')
        .replaceAll(' ', '')
        .trim();
        
    final amount = double.tryParse(cleanAmount);
    if (amount == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Invalid amount format"), backgroundColor: Colors.red),
      );
      return;
    }

    try {
      final data = {
        'expense_name': _nameController.text.trim(),
        'amount': amount,
        'date': _date.toString().split(' ')[0],
        'expense_type': _category,
        'is_income': _isIncome,
        'user_id': Supabase.instance.client.auth.currentUser?.id,
        'job_order_id': ((_category == 'Operational' || _category == 'Petty Cash') && !_isIncome)
            ? _selectedJobId
            : null,
      };

      if (widget.transactionToEdit != null) {
        // UPDATE
        // Extract ID from "E-123"
        final rawId = widget.transactionToEdit!.id.split('-')[1];
        await Supabase.instance.client
            .from('expenses')
            .update(data)
            .eq('id', rawId);

        await ActivityLogger.log(
          type: _isIncome ? 'Payment' : 'Expense',
          details: 'Updated Transaction: ₱${amount.toStringAsFixed(2)} (${_nameController.text})',
        );
      } else {
        // INSERT
        await Supabase.instance.client.from('expenses').insert(data);
        
        await ActivityLogger.log(
          type: _isIncome ? 'Payment' : 'Expense',
          details: _isIncome
              ? 'Recorded Cash In: ₱${amount.toStringAsFixed(2)} (${_nameController.text})'
              : 'Recorded Expense: ₱${amount.toStringAsFixed(2)} for ${_nameController.text}',
        );
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
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 450),
        child: SingleChildScrollView(
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

              // 1. Transaction Type Toggle
              Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: _TypeToggle(
                        label: "Money Out",
                        color: Colors.red,
                        isSelected: !_isIncome,
                        onTap: () => setState(() {
                          _isIncome = false;
                          _category = 'Operational'; // Reset to default
                        }),
                      ),
                    ),
                    Expanded(
                      child: _TypeToggle(
                        label: "Money In",
                        color: Colors.green,
                        isSelected: _isIncome,
                        onTap: () => setState(() {
                          _isIncome = true;
                          _category = 'General Income';
                        }),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // 2. Category Switcher (Now available for BOTH In and Out)
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: _CategoryChip(
                      label: _isIncome ? "General" : "Operational",
                      icon: Icons.business,
                      isSelected: _category == (_isIncome ? 'General Income' : 'Operational'),
                      onTap: () => setState(() => _category = _isIncome ? 'General Income' : 'Operational'),
                    ),
                  ),
                  const SizedBox(width: 8), 
                  // Petty Cash only for Expenses (Money Out)
                  if (!_isIncome) ...[
                    Expanded(
                      child: _CategoryChip(
                        label: "Petty Cash",
                        icon: Icons.monetization_on_outlined,
                        isSelected: _category == 'Petty Cash',
                        onTap: () => setState(() => _category = 'Petty Cash'),
                      ),
                    ),
                    const SizedBox(width: 8), 
                  ],
                  Expanded(
                    child: _CategoryChip(
                      label: "Personal",
                      icon: Icons.home,
                      isSelected: _category == 'Personal',
                      onTap: () => setState(() => _category = 'Personal'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // 3. Name & Amount
              TextFormField(
                controller: _nameController,
                decoration: InputDecoration(
                  labelText: _isIncome
                      ? "Source (e.g. Personal Savings)"
                      : "Expense Name",
                  border: const OutlineInputBorder(),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 12,
                  ),
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
                  contentPadding: EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 12,
                  ),
                ),
                validator: (v) => v!.isEmpty ? "Required" : null,
              ),

              const SizedBox(height: 12),

              // 4. Date Picker
              InkWell(
                onTap: () async {
                  final d = await showDatePicker(
                    context: context,
                    initialDate: _date,
                    firstDate: DateTime(2020),
                    lastDate: DateTime(2030),
                  );
                  if (d != null) setState(() => _date = d);
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 14,
                  ),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text("Date: ${_date.toString().split(' ')[0]}"),
                      const Icon(Icons.calendar_today, size: 16),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 12),

              // 5. Smart Job Search (Only for Operational/Petty Cash Expenses)
              if (!_isIncome && (_category == 'Operational' || _category == 'Petty Cash')) ...[
                LayoutBuilder(
                  builder: (context, constraints) {
                    return Autocomplete<Map<String, dynamic>>(
                      optionsBuilder: (TextEditingValue textEditingValue) {
                        if (textEditingValue.text == '') {
                          return const Iterable<Map<String, dynamic>>.empty();
                        }
                        return _activeJobs.where((job) {
                          final joNum =
                              (job['client_jo_number'] ?? 'JO-${job['id']}')
                                  .toString()
                                  .toLowerCase();
                          final cust = job['customers'];
                          final custName = cust != null
                              ? (cust['company_name'] ?? cust['last_name'])
                                    .toString()
                                    .toLowerCase()
                              : '';
                          return joNum.contains(
                                textEditingValue.text.toLowerCase(),
                              ) ||
                              custName.contains(
                                textEditingValue.text.toLowerCase(),
                              );
                        });
                      },
                      displayStringForOption: (Map<String, dynamic> option) {
                        final joNum =
                            option['client_jo_number'] ?? 'JO-${option['id']}';
                        final cust = option['customers'];
                        final custName = cust != null
                            ? (cust['company_name'] ?? cust['last_name'])
                            : 'Unknown';
                        return "$custName ($joNum)";
                      },
                      onSelected: (Map<String, dynamic> selection) {
                        setState(() {
                          _selectedJobId = selection['id'];
                        });
                      },
                      fieldViewBuilder:
                          (context, controller, focusNode, onFieldSubmitted) {
                            return TextField(
                              controller: controller,
                              focusNode: focusNode,
                              decoration: InputDecoration(
                                labelText: "Link to Job (Search Name or JO)",
                                border: const OutlineInputBorder(),
                                prefixIcon: const Icon(Icons.link),
                                suffixIcon: _selectedJobId != null
                                    ? const Icon(
                                        Icons.check_circle,
                                        color: Colors.green,
                                      )
                                    : null,
                              ),
                            );
                          },
                    );
                  },
                ),
              ],

              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _save,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    backgroundColor: _isIncome ? Colors.green : Colors.red,
                    foregroundColor: Colors.white,
                  ),
                  child: Text(
                      widget.transactionToEdit != null ? "Update Record" : (_isIncome ? "Save Cash In" : "Save Expense")
                  ),
                ),
              ),
            ],
          ),
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
