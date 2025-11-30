import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'data/app_state.dart';
import 'ui_app_shell.dart';
import 'shared/widgets.dart'
    show LoadingOverlay, showConfirmDialog, AppDesignTokens;

// --- Data Model ---
class ExpenseRecord {
  final int id;
  final String category;
  final String description;
  final double amount;
  final DateTime date;
  final String status;
  final String? jobOrderId;
  final int? dbJobId;

  ExpenseRecord({
    required this.id,
    required this.category,
    required this.description,
    required this.amount,
    required this.date,
    required this.status,
    this.jobOrderId,
    this.dbJobId,
  });
}

class ExpensesScreen extends StatefulWidget {
  const ExpensesScreen({super.key});

  @override
  State<ExpensesScreen> createState() => _ExpensesScreenState();
}

class _ExpensesScreenState extends State<ExpensesScreen> {
  List<ExpenseRecord> _expenses = [];
  bool _isLoading = true;
  String _searchQuery = '';

  // Cash Flow Stats
  double _totalIncome = 0; // From Payments
  double _totalExpenses = 0; // From Expenses

  @override
  void initState() {
    super.initState();
    _fetchCashFlowData();
  }

  Future<void> _fetchCashFlowData() async {
    setState(() => _isLoading = true);
    final supabase = Supabase.instance.client;

    try {
      // 1. Fetch Expenses (Cash Out)
      final expenseRes = await supabase
          .from('expenses')
          .select('*, job_orders(client_jo_number)')
          .order('date', ascending: false);

      // 2. Fetch Payments (Cash In) - To calculate Net Cash
      final paymentRes = await supabase
          .from('payments')
          .select('amount')
          .eq('status', 'Verified'); // Only count verified money

      // Process Expenses
      final List<ExpenseRecord> loadedExpenses = [];
      double expenseTotal = 0;

      for (var row in expenseRes) {
        final jo = row['job_orders'];
        final displayJo = jo != null ? jo['client_jo_number'] : null;
        final amount = (row['amount'] as num).toDouble();
        expenseTotal += amount;

        loadedExpenses.add(
          ExpenseRecord(
            id: row['id'],
            category: row['expense_type'] ?? 'General',
            description: row['expense_name'] ?? '',
            amount: amount,
            date: DateTime.parse(row['date']),
            status: row['status'] ?? 'Pending',
            jobOrderId: displayJo,
            dbJobId: row['job_order_id'],
          ),
        );
      }

      // Process Income
      double incomeTotal = 0;
      for (var row in paymentRes) {
        incomeTotal += (row['amount'] as num).toDouble();
      }

      if (mounted) {
        setState(() {
          _expenses = loadedExpenses;
          _totalExpenses = expenseTotal;
          _totalIncome = incomeTotal;
        });
      }
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error loading data: $e')));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _onAddOrEdit() async {
    final result = await showDialog(
      context: context,
      builder: (context) => const _ExpenseDialog(),
    );
    if (result == true) {
      _fetchCashFlowData();
    }
  }

  Future<void> _deleteExpense(int id) async {
    final confirm = await showConfirmDialog(
      context: context,
      title: "Delete Record?",
      message: "This will permanently remove this expense.",
      confirmLabel: "Delete",
      isDestructive: true,
    );

    if (confirm == true) {
      try {
        await Supabase.instance.client.from('expenses').delete().eq('id', id);
        _fetchCashFlowData();
      } catch (e) {
        if (mounted)
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text("Error: $e")));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isMobileView = MediaQuery.of(context).size.width < 800;

    // Calculate Net Cash (Profit)
    final double netCash = _totalIncome - _totalExpenses;
    final bool isPositive = netCash >= 0;

    final filtered = _expenses
        .where(
          (e) =>
              e.description.toLowerCase().contains(
                _searchQuery.toLowerCase(),
              ) ||
              (e.jobOrderId ?? '').toLowerCase().contains(
                _searchQuery.toLowerCase(),
              ),
        )
        .toList();

    return AppShell(
      selectedIndex: 2,
      body: LoadingOverlay(
        isLoading: _isLoading,
        child: Container(
          color: const Color(0xFFF8FAFC),
          child: Column(
            children: [
              // Header & Stats
              Container(
                padding: EdgeInsets.all(isMobileView ? 16 : 24),
                color: Colors.white,
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Cash Flow & Expenses',
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF1E293B),
                          ),
                        ),
                        ElevatedButton.icon(
                          onPressed: _onAddOrEdit,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF2563EB),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 20,
                              vertical: 16,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          icon: const Icon(Icons.add_circle, size: 20),
                          label: const Text(
                            'Add Expense',
                            style: TextStyle(fontWeight: FontWeight.w700),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    // CASH FLOW CARDS (Matches Spreadsheet Logic)
                    Row(
                      children: [
                        Expanded(
                          child: _StatCard(
                            label: "Cash In (Income)",
                            value: "₱${_totalIncome.toStringAsFixed(2)}",
                            icon: Icons.arrow_downward,
                            color: Colors.green,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _StatCard(
                            label: "Cash Out (Expenses)",
                            value: "₱${_totalExpenses.toStringAsFixed(2)}",
                            icon: Icons.arrow_upward,
                            color: Colors.red,
                          ),
                        ),
                        if (!isMobileView) ...[
                          const SizedBox(width: 12),
                          Expanded(
                            child: _StatCard(
                              label: "Net Cash",
                              value: "₱${netCash.abs().toStringAsFixed(2)}",
                              icon: isPositive
                                  ? Icons.trending_up
                                  : Icons.trending_down,
                              color: isPositive ? Colors.blue : Colors.orange,
                            ),
                          ),
                        ],
                      ],
                    ),
                    if (isMobileView) ...[
                      const SizedBox(height: 12),
                      _StatCard(
                        label: "Net Cash (Profit)",
                        value: "₱${netCash.toStringAsFixed(2)}",
                        icon: isPositive
                            ? Icons.trending_up
                            : Icons.trending_down,
                        color: isPositive ? Colors.blue : Colors.orange,
                      ),
                    ],
                  ],
                ),
              ),
              const Divider(height: 1),

              // Content
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Search
                      TextField(
                        onChanged: (v) => setState(() => _searchQuery = v),
                        decoration: InputDecoration(
                          hintText: 'Search expenses...',
                          prefixIcon: const Icon(Icons.search),
                          filled: true,
                          fillColor: Colors.white,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide.none,
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),

                      const Text(
                        "Expense Records",
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF64748B),
                        ),
                      ),
                      const SizedBox(height: 12),

                      // List View
                      if (filtered.isEmpty)
                        const Padding(
                          padding: EdgeInsets.all(40),
                          child: Center(
                            child: Text("No expense records found."),
                          ),
                        )
                      else if (isMobileView)
                        Column(
                          children: filtered
                              .map((e) => _buildMobileExpenseCard(e))
                              .toList(),
                        )
                      else
                        _buildWebTable(filtered),
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

  // --- Web Table View ---
  Widget _buildWebTable(List<ExpenseRecord> data) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      padding: const EdgeInsets.all(16),
      child: SizedBox(
        width: double.infinity,
        child: DataTable(
          columns: const [
            DataColumn(
              label: Text(
                'CATEGORY',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
            DataColumn(
              label: Text(
                'JOB ORDER',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
            DataColumn(
              label: Text(
                'DESCRIPTION',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
            DataColumn(
              label: Text(
                'DATE',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
            DataColumn(
              label: Text(
                'AMOUNT',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
            DataColumn(
              label: Text(
                'STATUS',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
            DataColumn(
              label: Text(
                'ACTION',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ],
          rows: data.map((e) {
            return DataRow(
              cells: [
                DataCell(_CategoryBadge(category: e.category)),
                DataCell(
                  Text(
                    e.jobOrderId ?? '-',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
                DataCell(Text(e.description)),
                DataCell(Text("${e.date.month}/${e.date.day}/${e.date.year}")),
                DataCell(
                  Text(
                    "₱${e.amount.toStringAsFixed(2)}",
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
                DataCell(_StatusBadge(status: e.status)),
                DataCell(
                  IconButton(
                    icon: const Icon(Icons.delete_outline, color: Colors.red),
                    onPressed: () => _deleteExpense(e.id),
                  ),
                ),
              ],
            );
          }).toList(),
        ),
      ),
    );
  }

  // --- Mobile Card View ---
  Widget _buildMobileExpenseCard(ExpenseRecord e) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _CategoryBadge(category: e.category),
              Text(
                "₱${e.amount.toStringAsFixed(2)}",
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.red,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            e.description,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
          ),
          if (e.jobOrderId != null)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Row(
                children: [
                  const Icon(Icons.work_outline, size: 14, color: Colors.grey),
                  const SizedBox(width: 4),
                  Text(
                    "Linked to: ${e.jobOrderId}",
                    style: const TextStyle(
                      color: Colors.blue,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                "${e.date.month}/${e.date.day}/${e.date.year}",
                style: const TextStyle(color: Colors.grey),
              ),
              Row(
                children: [
                  _StatusBadge(status: e.status),
                  const SizedBox(width: 8),
                  IconButton(
                    icon: const Icon(
                      Icons.delete,
                      color: Colors.grey,
                      size: 20,
                    ),
                    onPressed: () => _deleteExpense(e.id),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// --- Add/Edit Dialog ---

class _ExpenseDialog extends StatefulWidget {
  const _ExpenseDialog();
  @override
  State<_ExpenseDialog> createState() => _ExpenseDialogState();
}

class _ExpenseDialogState extends State<_ExpenseDialog> {
  final _formKey = GlobalKey<FormState>();
  final _descController = TextEditingController();
  final _amountController = TextEditingController();
  String _category = 'Fuel';
  int? _selectedJobId;
  bool _isSubmitting = false;

  List<Map<String, dynamic>> _activeJobs = [];

  @override
  void initState() {
    super.initState();
    _fetchActiveJobs();
  }

  Future<void> _fetchActiveJobs() async {
    final res = await Supabase.instance.client
        .from('job_orders')
        .select(
          'id, client_jo_number, customers(company_name, first_name, last_name)',
        )
        .order('created_at', ascending: false)
        .limit(20);

    if (mounted) {
      setState(() {
        _activeJobs = List<Map<String, dynamic>>.from(res);
      });
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSubmitting = true);

    try {
      final user = Supabase.instance.client.auth.currentUser;

      await Supabase.instance.client.from('expenses').insert({
        'expense_name': _descController.text,
        'expense_type': _category,
        'amount': double.parse(_amountController.text),
        'date': DateTime.now().toIso8601String(),
        'status': 'Pending',
        'job_order_id': _selectedJobId,
        'user_id': user?.id,
      });

      if (mounted) {
        Navigator.pop(context, true);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text("Expense Recorded")));
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
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        padding: const EdgeInsets.all(24),
        constraints: const BoxConstraints(maxWidth: 400),
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
              const SizedBox(height: 24),

              DropdownButtonFormField<String>(
                value: _category,
                decoration: _inputDecor("Category"),
                items: ['Fuel', 'Materials', 'Food', 'Overhead', 'Other']
                    .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                    .toList(),
                onChanged: (v) => setState(() => _category = v!),
              ),
              const SizedBox(height: 16),

              DropdownButtonFormField<int>(
                value: _selectedJobId,
                decoration: _inputDecor("Link to Job Order (Optional)"),
                items: [
                  const DropdownMenuItem(
                    value: null,
                    child: Text("None (General Expense)"),
                  ),
                  ..._activeJobs.map((j) {
                    final cust = j['customers'];
                    String name = cust != null
                        ? (cust['company_name'] ?? cust['first_name'])
                        : 'Unknown';
                    return DropdownMenuItem(
                      value: j['id'] as int,
                      child: Text(
                        "${j['client_jo_number']} - $name",
                        overflow: TextOverflow.ellipsis,
                      ),
                    );
                  }),
                ],
                onChanged: (v) => setState(() => _selectedJobId = v),
                isExpanded: true,
              ),
              const SizedBox(height: 16),

              TextFormField(
                controller: _descController,
                decoration: _inputDecor("Description (e.g. 5L Gasoline)"),
                validator: (v) => v!.isEmpty ? "Required" : null,
              ),
              const SizedBox(height: 16),

              TextFormField(
                controller: _amountController,
                decoration: _inputDecor("Amount (₱)"),
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                validator: (v) => v!.isEmpty ? "Required" : null,
              ),

              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  onPressed: _isSubmitting ? null : _submit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2563EB),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: _isSubmitting
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Text(
                          "Save Expense",
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  InputDecoration _inputDecor(String label) {
    return InputDecoration(
      labelText: label,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      filled: true,
      fillColor: Colors.grey[50],
    );
  }
}

// --- Visual Helpers ---

class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;
  const _StatCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 28),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                value,
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: color,
                ),
              ),
              Text(
                label,
                style: const TextStyle(fontSize: 12, color: Colors.black54),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _CategoryBadge extends StatelessWidget {
  final String category;
  const _CategoryBadge({required this.category});

  @override
  Widget build(BuildContext context) {
    Color color;
    switch (category) {
      case 'Fuel':
        color = Colors.orange;
        break;
      case 'Materials':
        color = Colors.purple;
        break;
      case 'Food':
        color = Colors.green;
        break;
      default:
        color = Colors.grey;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        category,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.bold,
          color: color,
        ),
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final String status;
  const _StatusBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    final isVerified = status == 'Verified';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: isVerified
            ? Colors.green.withOpacity(0.1)
            : Colors.amber.withOpacity(0.1),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        status,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.bold,
          color: isVerified ? Colors.green : Colors.amber[800],
        ),
      ),
    );
  }
}
