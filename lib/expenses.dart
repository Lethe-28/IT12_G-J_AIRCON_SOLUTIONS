import 'package:flutter/material.dart';
import 'data/app_state.dart';
import 'ui_app_shell.dart';

class ExpenseEntry {
  final int id;
  String category; // Fuel, Materials, Food, Transportation, etc.
  String jobOrderId; // optional link to JO
  String description;
  DateTime date;
  double amount;
  String status; // Pending / Verified
  bool isCustomerFunded;

  ExpenseEntry({
    required this.id,
    required this.category,
    required this.jobOrderId,
    required this.description,
    required this.date,
    required this.amount,
    required this.status,
    required this.isCustomerFunded,
  });
}

class ExpensesScreen extends StatefulWidget {
  const ExpensesScreen({super.key});

  @override
  State<ExpensesScreen> createState() => _ExpensesScreenState();
}

class _ExpensesScreenState extends State<ExpensesScreen> {
  final List<ExpenseEntry> _expenses = [];
  String _searchQuery = '';
  DateTime? _dateFilterStart;
  DateTime? _dateFilterEnd;
  bool _showDateFilter = false;

  bool get _isServiceManager => AppState.currentRole == UserRole.serviceManager;

  @override
  void initState() {
    super.initState();
    _seedData();
  }

  void _seedData() {
    final now = DateTime.now();
    _expenses.addAll([
      ExpenseEntry(
        id: 1,
        category: 'Fuel',
        jobOrderId: 'JO-2025-001',
        description: 'Fuel for service vehicle',
        date: now,
        amount: 450,
        status: 'Verified',
        isCustomerFunded: false,
      ),
      ExpenseEntry(
        id: 2,
        category: 'Materials',
        jobOrderId: 'JO-2025-002',
        description: 'Freon (customer-funded)',
        date: now.subtract(const Duration(days: 1)),
        amount: 2500,
        status: 'Pending',
        isCustomerFunded: true,
      ),
      ExpenseEntry(
        id: 3,
        category: 'Food',
        jobOrderId: '',
        description: 'Team lunch',
        date: now.subtract(const Duration(days: 3)),
        amount: 380,
        status: 'Verified',
        isCustomerFunded: false,
      ),
    ]);
  }

  List<ExpenseEntry> get _filteredExpenses {
    var result = _expenses;
    
    // Filter by search query
    if (_searchQuery.isNotEmpty) {
      final q = _searchQuery.toLowerCase();
      result = result
          .where((e) =>
              e.category.toLowerCase().contains(q) ||
              e.jobOrderId.toLowerCase().contains(q) ||
              e.description.toLowerCase().contains(q) ||
              e.status.toLowerCase().contains(q))
          .toList();
    }
    
    // Filter by date range
    if (_dateFilterStart != null || _dateFilterEnd != null) {
      final start = _dateFilterStart ?? DateTime(2000);
      final end = (_dateFilterEnd ?? DateTime.now()).add(const Duration(days: 1));
      result = result.where((e) => e.date.isAfter(start) && e.date.isBefore(end)).toList();
    }
    
    return result;
  }

  double get _todayTotal {
    final now = DateTime.now();
    return _expenses
        .where((e) =>
            e.date.year == now.year &&
            e.date.month == now.month &&
            e.date.day == now.day)
        .fold(0, (sum, e) => sum + e.amount);
  }

  double get _weekTotal {
    final now = DateTime.now();
    final weekAgo = now.subtract(const Duration(days: 7));
    return _expenses
        .where((e) => e.date.isAfter(weekAgo) && e.date.isBefore(now.add(const Duration(days: 1))))
        .fold(0, (sum, e) => sum + e.amount);
  }

  double get _monthTotal {
    final now = DateTime.now();
    return _expenses
        .where((e) => e.date.year == now.year && e.date.month == now.month)
        .fold(0, (sum, e) => sum + e.amount);
  }

  double get _totalExpenses {
    return _expenses.fold(0, (sum, e) => sum + e.amount);
  }

  Map<String, double> get _categoryTotals {
    final map = <String, double>{};
    for (final e in _expenses) {
      map[e.category] = (map[e.category] ?? 0) + e.amount;
    }
    return map;
  }

  void _onAddOrEdit({ExpenseEntry? existing}) async {
    final ExpenseEntry? result = await showDialog<ExpenseEntry>(
      context: context,
      builder: (context) => _ExpenseDialog(entry: existing),
    );
    if (result == null) return;

    setState(() {
      if (existing == null) {
        final newId = _expenses.isNotEmpty ? _expenses.last.id + 1 : 1;
        _expenses.add(ExpenseEntry(
          id: newId,
          category: result.category,
          jobOrderId: result.jobOrderId,
          description: result.description,
          date: result.date,
          amount: result.amount,
          status: result.status,
          isCustomerFunded: result.isCustomerFunded,
        ));
      } else {
        final index = _expenses.indexWhere((e) => e.id == existing.id);
        if (index != -1) {
          _expenses[index] = result;
        }
      }
    });
  }

  void _onDelete(ExpenseEntry entry) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Expense'),
        content: Text('Delete expense "${entry.description}"?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Delete')),
        ],
      ),
    );
    if (confirmed != true) return;
    setState(() {
      _expenses.removeWhere((e) => e.id == entry.id);
    });
  }

  void _onExport() {
    // Generate CSV content
    final buffer = StringBuffer();
    buffer.writeln('Date,Category,Description,Amount,Status,Customer Funded,Job Order ID');
    
    for (final expense in _filteredExpenses) {
      final date = _formatDate(expense.date);
      final category = expense.category;
      final description = '"${expense.description}"';
      final amount = expense.amount.toStringAsFixed(2);
      final status = expense.status;
      final funded = expense.isCustomerFunded ? 'Yes' : 'No';
      final joId = expense.jobOrderId.isEmpty ? '-' : expense.jobOrderId;
      buffer.writeln('$date,$category,$description,$amount,$status,$funded,$joId');
    }
    
    // Show success message
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Export ready: ${_filteredExpenses.length} entries as CSV'),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  String _formatDate(DateTime d) {
    final mm = d.month.toString().padLeft(2, '0');
    final dd = d.day.toString().padLeft(2, '0');
    final yyyy = d.year.toString();
    return '$mm/$dd/$yyyy';
  }

  String _formatAmount(double v) => '₱${v.toStringAsFixed(2)}';

  Widget _totalSummaryCard() {
    return Container(
      decoration: _cardDeco(),
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.red.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(Icons.account_balance_wallet, color: Colors.red[600], size: 28),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Total Expenses',
                    style: TextStyle(fontSize: 13, color: Colors.black54, fontWeight: FontWeight.w600)),
                const SizedBox(height: 4),
                Text(_formatAmount(_totalExpenses),
                    style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w800, color: Colors.red)),
                const SizedBox(height: 4),
                Text('${_expenses.length} entries',
                    style: const TextStyle(fontSize: 12, color: Colors.black45)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _dateFilterPanel() {
    return Container(
      decoration: _cardDeco(),
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Expanded(
            child: _datePickerField(
              label: 'From Date',
              value: _dateFilterStart,
              onChanged: (date) => setState(() => _dateFilterStart = date),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: _datePickerField(
              label: 'To Date',
              value: _dateFilterEnd,
              onChanged: (date) => setState(() => _dateFilterEnd = date),
            ),
          ),
          const SizedBox(width: 16),
          TextButton.icon(
            onPressed: () => setState(() {
              _dateFilterStart = null;
              _dateFilterEnd = null;
            }),
            icon: const Icon(Icons.clear),
            label: const Text('Clear Filters'),
          ),
        ],
      ),
    );
  }

  Widget _datePickerField({
    required String label,
    required DateTime? value,
    required Function(DateTime?) onChanged,
  }) {
    return InkWell(
      onTap: () async {
        final picked = await showDatePicker(
          context: context,
          initialDate: value ?? DateTime.now(),
          firstDate: DateTime(2020),
          lastDate: DateTime.now(),
        );
        if (picked != null) onChanged(picked);
      },
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          border: Border.all(color: const Color(0xFFE2E8F0)),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: const TextStyle(fontSize: 12, color: Colors.black54)),
            const SizedBox(height: 6),
            Text(
              value != null ? _formatDate(value) : 'Not set',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: value != null ? Colors.black87 : Colors.black45,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final records = _filteredExpenses;

    return AppShell(
      selectedIndex: 2,
      body: Column(
        children: [
          
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Text('Expense Tracking (Cash-out)',
                          style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
                      const Spacer(),
                      ElevatedButton.icon(
                        onPressed: () => setState(() => _showDateFilter = !_showDateFilter),
                        icon: const Icon(Icons.calendar_today, size: 18),
                        label: const Text('Date Filter'),
                      ),
                      const SizedBox(width: 12),
                      ElevatedButton.icon(
                        onPressed: _onExport,
                        icon: const Icon(Icons.download, size: 18),
                        label: const Text('Export'),
                      ),
                      const SizedBox(width: 12),
                      if (_isServiceManager)
                        ElevatedButton.icon(
                          onPressed: () => _onAddOrEdit(),
                          icon: const Icon(Icons.add),
                          label: const Text('Add Expense'),
                        ),
                    ],
                  ),
                  if (_showDateFilter) ...[
                    const SizedBox(height: 12),
                    _dateFilterPanel(),
                  ],
                  const SizedBox(height: 14),
                  _totalSummaryCard(),
                  const SizedBox(height: 14),
                  _overviewStatsRow(),
                  const SizedBox(height: 14),
                  _chartAndRecordsSection(records),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _overviewStatsRow() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isSmall = constraints.maxWidth < 600;
        final isMedium = constraints.maxWidth < 1000;
        
        int crossAxisCount = 3;
        if (isSmall) crossAxisCount = 1;
        else if (isMedium) crossAxisCount = 2;

        return GridView.count(
          crossAxisCount: crossAxisCount,
          mainAxisSpacing: 8,
          crossAxisSpacing: 8,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          childAspectRatio: 0.95,
          children: [
            _smallStatCard("Today's Total", _formatAmount(_todayTotal), 'For ${_formatDate(DateTime.now())}', Colors.blue, Icons.trending_up),
            _smallStatCard('Last 7 Days', _formatAmount(_weekTotal), 'Rolling week', Colors.green, Icons.calendar_today),
            _smallStatCard('This Month', _formatAmount(_monthTotal), 'Month total', Colors.purple, Icons.bar_chart),
          ],
        );
      },
    );
  }

  Widget _smallStatCard(String title, String value, String note, Color color, IconData icon) {
    return Container(
      decoration: _cardDeco(),
      padding: const EdgeInsets.all(10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
            child: Icon(icon, color: color, size: 16),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(fontSize: 11, color: Colors.black54, fontWeight: FontWeight.w600)),
              const SizedBox(height: 2),
              Text(value, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800)),
              const SizedBox(height: 2),
              Text(note, style: const TextStyle(fontSize: 10, color: Colors.black45)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _spendingChart() {
    final data = _categoryTotals.entries.toList();
    if (data.isEmpty) {
      return Container(
        decoration: _cardDeco(),
        padding: const EdgeInsets.all(16),
        child: const Text('No expenses recorded yet.'),
      );
    }

    return Container(
      decoration: _cardDeco(),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Spending Distribution',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
          const SizedBox(height: 16),
          Container(
            height: 22,
            decoration: BoxDecoration(
              color: const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(999),
            ),
            clipBehavior: Clip.antiAlias,
            child: Row(
              children: data
                  .map((e) => Expanded(
                        flex: (e.value * 100).toInt().clamp(1, 1000),
                        child: Container(
                          color: _colorForCategory(e.key),
                        ),
                      ))
                  .toList(),
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 16,
            runSpacing: 8,
            children: data
                .map((e) => Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(width: 10, height: 10, color: _colorForCategory(e.key)),
                        const SizedBox(width: 6),
                        Text('${e.key} ${_formatAmount(e.value)}'),
                      ],
                    ))
                .toList(),
          ),
        ],
      ),
    );
  }

  Color _colorForCategory(String category) {
    switch (category.toLowerCase()) {
      case 'fuel':
        return Colors.blue;
      case 'materials':
        return Colors.purple;
      case 'food':
        return Colors.green;
      case 'transportation':
        return Colors.orange;
      default:
        return Colors.teal;
    }
  }

  Widget _recordsTable(List<ExpenseEntry> records) {
    return Container(
      decoration: _cardDeco(),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text('Expense Records',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
              const Spacer(),
              SizedBox(
                width: 260,
                child: TextField(
                  onChanged: (v) => setState(() => _searchQuery = v),
                  decoration: InputDecoration(
                    hintText: 'Search expenses...',
                    prefixIcon: const Icon(Icons.search),
                    filled: true,
                    fillColor: const Color(0xFFF8FAFC),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: DataTable(
              headingRowColor: MaterialStateProperty.resolveWith(
                  (states) => const Color(0xFFF8FAFC)),
              columns: const [
                DataColumn(label: Text('CATEGORY')),
                DataColumn(label: Text('JOB ORDER')),
                DataColumn(label: Text('DESCRIPTION')),
                DataColumn(label: Text('DATE')),
                DataColumn(label: Text('AMOUNT')),
                DataColumn(label: Text('STATUS')),
                DataColumn(label: Text('ACTIONS')),
              ],
              rows: records.map((e) {
                final statusColor =
                    e.status.toLowerCase() == 'verified' ? Colors.green : Colors.orange;
                return DataRow(
                  color: MaterialStateProperty.resolveWith((states) {
                    if (states.contains(MaterialState.hovered)) {
                      return const Color(0xFFF0F4F8);
                    }
                    return null;
                  }),
                  cells: [
                    DataCell(Text(e.category)),
                    DataCell(Text(e.jobOrderId.isEmpty ? '-' : e.jobOrderId)),
                    DataCell(SizedBox(
                      width: 220,
                      child: Text(
                        e.description.isEmpty ? '-' : e.description,
                        overflow: TextOverflow.ellipsis,
                      ),
                    )),
                    DataCell(Text(_formatDate(e.date))),
                    DataCell(Text(_formatAmount(e.amount))),
                    DataCell(Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: statusColor.withOpacity(.15),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        e.status,
                        style: TextStyle(color: statusColor, fontSize: 12, fontWeight: FontWeight.w600),
                      ),
                    )),
                    DataCell(Row(
                      children: [
                        if (_isServiceManager)
                          IconButton(
                            icon: const Icon(Icons.edit_outlined, size: 18, color: Colors.indigo),
                            onPressed: () => _onAddOrEdit(existing: e),
                          ),
                        if (_isServiceManager)
                          IconButton(
                            icon: const Icon(Icons.delete_outline, size: 18, color: Colors.red),
                            onPressed: () => _onDelete(e),
                          ),
                        if (!_isServiceManager)
                          const Text('View only', style: TextStyle(fontSize: 12, color: Colors.black54)),
                      ],
                    )),
                  ],
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _chartAndRecordsSection(List<ExpenseEntry> records) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isNarrow = constraints.maxWidth < 1200;

        if (isNarrow) {
          return Column(
            children: [
              _spendingChart(),
              const SizedBox(height: 14),
              _recordsTable(records),
            ],
          );
        }

        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              flex: 1,
              child: _spendingChart(),
            ),
            const SizedBox(width: 14),
            Expanded(
              flex: 2,
              child: _recordsTable(records),
            ),
          ],
        );
      },
    );
  }

  BoxDecoration _cardDeco() => BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      );
}

class _ExpenseDialog extends StatefulWidget {
  final ExpenseEntry? entry;
  const _ExpenseDialog({this.entry});

  @override
  State<_ExpenseDialog> createState() => _ExpenseDialogState();
}

class _ExpenseDialogState extends State<_ExpenseDialog> {
  late TextEditingController _categoryController;
  late TextEditingController _joController;
  late TextEditingController _descriptionController;
  late TextEditingController _amountController;
  String _status = 'Pending';
  bool _isCustomerFunded = false;
  DateTime _date = DateTime.now();

  @override
  void initState() {
    super.initState();
    final e = widget.entry;
    _categoryController = TextEditingController(text: e?.category ?? 'Fuel');
    _joController = TextEditingController(text: e?.jobOrderId ?? '');
    _descriptionController = TextEditingController(text: e?.description ?? '');
    _amountController =
        TextEditingController(text: e != null ? e.amount.toStringAsFixed(2) : '');
    _status = e?.status ?? 'Pending';
    _isCustomerFunded = e?.isCustomerFunded ?? false;
    _date = e?.date ?? DateTime.now();
  }

  @override
  void dispose() {
    _categoryController.dispose();
    _joController.dispose();
    _descriptionController.dispose();
    _amountController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
    );
    if (date == null) return;
    setState(() {
      _date = date;
    });
  }

  void _submit() {
    if (_amountController.text.trim().isEmpty) return;
    final amount = double.tryParse(_amountController.text.trim()) ?? 0;

    final existing = widget.entry;
    final entry = ExpenseEntry(
      id: existing?.id ?? 0,
      category: _categoryController.text.trim(),
      jobOrderId: _joController.text.trim(),
      description: _descriptionController.text.trim(),
      date: _date,
      amount: amount,
      status: _status,
      isCustomerFunded: _isCustomerFunded,
    );
    Navigator.of(context).pop(entry);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.entry == null ? 'Add Expense' : 'Edit Expense'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            DropdownButtonFormField<String>(
              value: _categoryController.text.isEmpty
                  ? 'Fuel'
                  : _categoryController.text,
              decoration: const InputDecoration(labelText: 'Category'),
              items: const [
                DropdownMenuItem(value: 'Fuel', child: Text('Fuel')),
                DropdownMenuItem(value: 'Materials', child: Text('Materials')),
                DropdownMenuItem(value: 'Food', child: Text('Food')),
                DropdownMenuItem(value: 'Transportation', child: Text('Transportation')),
                DropdownMenuItem(value: 'Toll', child: Text('Toll / Parking')),
                DropdownMenuItem(value: 'Other', child: Text('Other')),
              ],
              onChanged: (v) => setState(() => _categoryController.text = v ?? 'Fuel'),
            ),
            TextField(
              controller: _joController,
              decoration: const InputDecoration(
                  labelText: 'Job Order Number (optional)'),
            ),
            TextField(
              controller: _descriptionController,
              decoration: const InputDecoration(labelText: 'Description'),
            ),
            TextField(
              controller: _amountController,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(labelText: 'Amount (₱)'),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Expense Date: ${_date.month.toString().padLeft(2, '0')}/${_date.day.toString().padLeft(2, '0')}/${_date.year}',
                  ),
                ),
                TextButton(onPressed: _pickDate, child: const Text('Change')),
              ],
            ),
            const SizedBox(height: 8),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Customer-funded item (e.g. freon)'),
              value: _isCustomerFunded,
              onChanged: (v) => setState(() => _isCustomerFunded = v),
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                const Text('Status:'),
                const SizedBox(width: 8),
                DropdownButton<String>(
                  value: _status,
                  items: const [
                    DropdownMenuItem(value: 'Pending', child: Text('Pending')),
                    DropdownMenuItem(value: 'Verified', child: Text('Verified')),
                  ],
                  onChanged: (v) {
                    if (v == null) return;
                    setState(() => _status = v);
                  },
                ),
              ],
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: _submit,
          child: const Text('Save'),
        ),
      ],
    );
  }
}





