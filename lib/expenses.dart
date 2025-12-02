import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'ui_app_shell.dart';
import 'shared/widgets.dart' show LoadingOverlay, EmptyState;

// --- MODEL: Unified Transaction ---
class Transaction {
  final String id;
  final DateTime date;
  final String description;
  final double amount;
  final String type; // 'IN' (Payment) or 'OUT' (Expense)
  final String category; // 'Operational' or 'Personal'
  final String? relatedJob; // "JO-123"

  Transaction({
    required this.id,
    required this.date,
    required this.description,
    required this.amount,
    required this.type,
    required this.category,
    this.relatedJob,
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

  List<Transaction> _allTransactions = []; // Stores full list
  List<Transaction> _filteredTransactions = []; // Stores search results
  final _searchController = TextEditingController();

  double _totalIn = 0;
  double _totalOut = 0;

  DateTime _selectedMonth = DateTime.now();

  @override
  void initState() {
    super.initState();
    _fetchCashFlow();
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      if (query.isEmpty) {
        _filteredTransactions = _allTransactions;
      } else {
        _filteredTransactions = _allTransactions.where((txn) {
          final matchesDesc = txn.description.toLowerCase().contains(query);
          final matchesJob =
              txn.relatedJob?.toLowerCase().contains(query) ?? false;
          final matchesCat = txn.category.toLowerCase().contains(query);
          return matchesDesc || matchesJob || matchesCat;
        }).toList();
      }
    });
  }

  Future<void> _fetchCashFlow() async {
    setState(() => _isLoading = true);
    try {
      final startOfMonth = DateTime(
        _selectedMonth.year,
        _selectedMonth.month,
        1,
      );
      final nextMonth = DateTime(
        _selectedMonth.year,
        _selectedMonth.month + 1,
        1,
      );

      final startStr = startOfMonth.toIso8601String();
      final endStr = nextMonth.toIso8601String();

      // 1. FETCH PAYMENTS
      final paymentsRes = await _supabase
          .from('payments')
          .select(
            'id, amount, payment_date, payment_method, job_orders(client_jo_number, customers(company_name, first_name, last_name))',
          )
          .gte('payment_date', startStr)
          .lt('payment_date', endStr);

      // 2. FETCH EXPENSES
      final expensesRes = await _supabase
          .from('expenses')
          .select(
            'id, amount, date, expense_name, expense_type, job_orders(client_jo_number)',
          )
          .gte('date', startStr)
          .lt('date', endStr);

      final List<Transaction> loaded = [];
      double inSum = 0;
      double outSum = 0;

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
            id: p['id'].toString(),
            date: DateTime.parse(p['payment_date']).toLocal(),
            description: desc,
            amount: amt,
            type: 'IN',
            category: 'Job Revenue',
            relatedJob: joNum,
          ),
        );
      }

      for (var e in expensesRes) {
        final amt = (e['amount'] as num).toDouble();
        outSum += amt;
        String? joNum;
        if (e['job_orders'] != null) {
          joNum = e['job_orders']['client_jo_number'];
        }
        loaded.add(
          Transaction(
            id: e['id'].toString(),
            date: DateTime.parse(e['date']).toLocal(),
            description: e['expense_name'] ?? 'Unnamed Expense',
            amount: amt,
            type: 'OUT',
            category: e['expense_type'] ?? 'Operational',
            relatedJob: joNum,
          ),
        );
      }

      // UPDATED SORTING: Date Descending, then ID Descending (Newest First)
      loaded.sort((a, b) {
        int dateComp = b.date.compareTo(a.date);
        if (dateComp != 0) return dateComp;
        // If dates are identical, use ID as tiebreaker (Assuming higher ID = newer)
        return int.parse(b.id).compareTo(int.parse(a.id));
      });

      if (mounted) {
        setState(() {
          _allTransactions = loaded;
          _filteredTransactions = loaded; // Initial state
          _totalIn = inSum;
          _totalOut = outSum;
        });
      }
    } catch (e) {
      debugPrint("Error fetching cash flow: $e");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _changeMonth(int offset) {
    setState(() {
      _selectedMonth = DateTime(
        _selectedMonth.year,
        _selectedMonth.month + offset,
      );
    });
    _fetchCashFlow();
  }

  @override
  Widget build(BuildContext context) {
    final netCash = _totalIn - _totalOut;

    return AppShell(
      selectedIndex: 2,
      body: LoadingOverlay(
        isLoading: _isLoading,
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              color: Colors.white,
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          IconButton(
                            icon: const Icon(Icons.chevron_left),
                            onPressed: () => _changeMonth(-1),
                          ),
                          Text(
                            _formatMonthYear(_selectedMonth),
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.chevron_right),
                            onPressed: () => _changeMonth(1),
                          ),
                        ],
                      ),
                      ElevatedButton.icon(
                        onPressed: () async {
                          await showDialog(
                            context: context,
                            builder: (_) => const _AddExpenseDialog(),
                          );
                          _fetchCashFlow();
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.redAccent,
                          foregroundColor: Colors.white,
                        ),
                        icon: const Icon(Icons.add),
                        label: const Text("Add Expense"),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Summary Cards
                  Row(
                    children: [
                      Expanded(
                        child: _SummaryCard(
                          label: "Cash In",
                          amount: _totalIn,
                          color: Colors.green,
                          icon: Icons.arrow_downward,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _SummaryCard(
                          label: "Cash Out",
                          amount: _totalOut,
                          color: Colors.red,
                          icon: Icons.arrow_upward,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _SummaryCard(
                          label: "Net Cash",
                          amount: netCash,
                          color: netCash >= 0 ? Colors.blue : Colors.orange,
                          icon: Icons.account_balance_wallet,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // NEW: Search Bar
                  TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      hintText: "Search by JO#, Description, or Type...",
                      prefixIcon: const Icon(Icons.search),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: Colors.grey.shade300),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                      ),
                      filled: true,
                      fillColor: Colors.grey.shade50,
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),

            Expanded(
              child: _filteredTransactions.isEmpty
                  ? const Center(
                      child: EmptyState(
                        icon: Icons.receipt_long,
                        title: "No Transactions",
                        message: "No records found matching your criteria.",
                      ),
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.all(16),
                      itemCount: _filteredTransactions.length,
                      separatorBuilder: (ctx, i) => const SizedBox(height: 12),
                      itemBuilder: (ctx, i) {
                        final txn = _filteredTransactions[i];
                        return _TransactionCard(txn: txn);
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatMonthYear(DateTime date) {
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
    return "${months[date.month - 1]} ${date.year}";
  }
}
// --- WIDGETS ---

class _SummaryCard extends StatelessWidget {
  final String label;
  final double amount;
  final Color color;
  final IconData icon;

  const _SummaryCard({
    required this.label,
    required this.amount,
    required this.color,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: color),
              const SizedBox(width: 4),
              Text(
                label,
                style: TextStyle(
                  color: color,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            "₱${amount.toStringAsFixed(2)}",
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w800,
              fontSize: 18,
            ),
          ),
        ],
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
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border(left: BorderSide(color: color, width: 4)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          // Icon Box
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              txn.category == 'Personal'
                  ? Icons.home
                  : (isIncome ? Icons.attach_money : Icons.shopping_bag),
              color: color,
              size: 20,
            ),
          ),
          const SizedBox(width: 16),

          // Details
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  txn.description,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    if (txn.relatedJob != null)
                      Container(
                        margin: const EdgeInsets.only(right: 8),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
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
                      txn.category,
                      style: const TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      "${txn.date.month}/${txn.date.day}",
                      style: const TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Amount
          Text(
            "${isIncome ? '+' : '-'} ₱${txn.amount.toStringAsFixed(2)}",
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
        ],
      ),
    );
  }
}

// --- ADD EXPENSE DIALOG ---

class _AddExpenseDialog extends StatefulWidget {
  const _AddExpenseDialog();

  @override
  State<_AddExpenseDialog> createState() => _AddExpenseDialogState();
}

class _AddExpenseDialogState extends State<_AddExpenseDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _amountController = TextEditingController();

  String _category = 'Operational'; // We will save this to 'expense_type'
  DateTime _date = DateTime.now();

  // Job Linking
  int? _selectedJobId;
  List<Map<String, dynamic>> _activeJobs = [];
  bool _isLoadingJobs = false;

  @override
  void initState() {
    super.initState();
    _fetchActiveJobs();
  }

  Future<void> _fetchActiveJobs() async {
    setState(() => _isLoadingJobs = true);
    final res = await Supabase.instance.client
        .from('job_orders')
        .select('id, client_jo_number, customers(company_name, last_name)')
        .neq('status', 'Completed') // Only show active jobs
        .order('date_scheduled', ascending: false);

    if (mounted) {
      setState(() {
        _activeJobs = List<Map<String, dynamic>>.from(res);
        _isLoadingJobs = false;
      });
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    final amount = double.tryParse(_amountController.text);
    if (amount == null) return;

    try {
      await Supabase.instance.client.from('expenses').insert({
        'expense_name': _nameController.text.trim(),
        'amount': amount,
        'date': _date.toUtc().toIso8601String(),

        // CORRECTED: Saving 'Operational' or 'Personal' to 'expense_type'
        'expense_type': _category,

        'user_id': Supabase.instance.client.auth.currentUser?.id,
        // Only link job if Operational AND selected
        'job_order_id': (_category == 'Operational') ? _selectedJobId : null,
      });

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
        width: 400,
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                "Add Expense",
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 20),

              // 1. Category Switcher
              Row(
                children: [
                  Expanded(
                    child: _CategoryChip(
                      label: "Operational",
                      icon: Icons.business,
                      isSelected: _category == 'Operational',
                      onTap: () => setState(() => _category = 'Operational'),
                    ),
                  ),
                  const SizedBox(width: 12),
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

              // 2. Name & Amount
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: "Expense Name (e.g. Fuel, Dinner)",
                  border: OutlineInputBorder(),
                  contentPadding: EdgeInsets.symmetric(
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

              // 3. Date Picker
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

              // 4. Job Link (Only if Operational)
              if (_category == 'Operational') ...[
                DropdownButtonFormField<int>(
                  value: _selectedJobId,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: "Link to Job (Optional)",
                    border: OutlineInputBorder(),
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 12,
                    ),
                  ),
                  items: [
                    const DropdownMenuItem<int>(
                      value: null,
                      child: Text("General / Unlinked"),
                    ),
                    ..._activeJobs.map((job) {
                      final joNum =
                          job['client_jo_number'] ?? 'JO-${job['id']}';
                      final cust = job['customers'];
                      final custName = cust != null
                          ? (cust['company_name'] ?? cust['last_name'])
                          : 'Unknown';
                      return DropdownMenuItem<int>(
                        value: job['id'] as int,
                        child: Text(
                          "$joNum - $custName",
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 13),
                        ),
                      );
                    }).toList(),
                  ],
                  onChanged: (v) => setState(() => _selectedJobId = v),
                ),
              ],

              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _save,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    backgroundColor: Colors.blue,
                    foregroundColor: Colors.white,
                  ),
                  child: const Text("Save Expense"),
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
