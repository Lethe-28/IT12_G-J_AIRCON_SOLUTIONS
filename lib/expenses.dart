import 'package:flutter/material.dart';
import 'data/app_state.dart';
import 'ui_app_shell.dart';

// --- Data Models ---

class ExpenseEntry {
  final int id;
  String category;
  String jobOrderId;
  String description;
  DateTime date;
  double amount;
  String status;
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

// --- Main Screen ---

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
  
  // Design Constants
  static const Color kPrimaryColor = Color(0xFFDC2626);
  static const Color kTextPrimary = Color(0xFF1E293B);
  static const Color kTextSecondary = Color(0xFF64748B);
  static const Color kBorderColor = Color(0xFFE2E8F0);

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
    
    if (_dateFilterStart != null || _dateFilterEnd != null) {
      final start = _dateFilterStart ?? DateTime(2000);
      final end = (_dateFilterEnd ?? DateTime.now()).add(const Duration(days: 1));
      result = result.where((e) => e.date.isAfter(start) && e.date.isBefore(end)).toList();
    }
    
    return result;
  }

  // --- Calculations ---

  double get _todayTotal {
    final now = DateTime.now();
    return _expenses
        .where((e) => e.date.year == now.year && e.date.month == now.month && e.date.day == now.day)
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

  double get _totalExpenses => _expenses.fold(0, (sum, e) => sum + e.amount);

  Map<String, double> get _categoryTotals {
    final map = <String, double>{};
    for (final e in _expenses) {
      map[e.category] = (map[e.category] ?? 0) + e.amount;
    }
    final sortedKeys = map.keys.toList(growable: false)
      ..sort((k1, k2) => map[k2]!.compareTo(map[k1]!));
    return Map.fromEntries(sortedKeys.map((k) => MapEntry(k, map[k]!)));
  }

  // --- Actions ---

  void _onAddOrEdit({ExpenseEntry? existing}) async {
    final ExpenseEntry? result = await showDialog<ExpenseEntry>(
      context: context,
      builder: (context) => _ExpenseDialog(entry: existing),
    );
    if (result == null) return;

    setState(() {
      if (existing == null) {
        final newId = _expenses.isNotEmpty ? _expenses.last.id + 1 : 1;
        _expenses.add(result);
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
        title: const Text('Archive Expense'),
        content: Text('Archive expense "${entry.description}"?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(context, true), 
            style: TextButton.styleFrom(foregroundColor: Colors.orange),
            child: const Text('Archive')
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    setState(() {
      _expenses.removeWhere((e) => e.id == entry.id);
    });
  }

  String _formatAmount(double v) => '₱${v.toStringAsFixed(2)}';
  String _formatDate(DateTime d) => '${d.month}/${d.day}/${d.year}';

  // --- UI Builders ---

  @override
  Widget build(BuildContext context) {
    final records = _filteredExpenses;

    return AppShell(
      selectedIndex: 2,
      body: Container(
        color: const Color(0xFFF8FAFC),
        child: Column(
          children: [
            // Header
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
              color: Colors.white,
              width: double.infinity,
              child: Row(
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Expense Tracking (Cash-out)',
                        style: TextStyle(fontSize: 24, fontWeight: FontWeight.w700, color: kTextPrimary, letterSpacing: -0.5),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Monitor spending, reimbursements, and job costs.',
                        style: TextStyle(fontSize: 14, color: kTextSecondary),
                      ),
                    ],
                  ),
                  const Spacer(),
                  _ActionButton(
                    label: 'Date Filter',
                    icon: Icons.calendar_today_outlined,
                    onPressed: _showDateRangePicker,
                  ),
                  const SizedBox(width: 12),
                  if (_isServiceManager)
                    _ActionButton(
                      label: 'Add Expense',
                      icon: Icons.add,
                      isPrimary: true,
                      onPressed: () => _onAddOrEdit(),
                    ),
                ],
              ),
            ),
            const Divider(height: 1, color: kBorderColor),

            // Scrollable Body
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(32),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 1. Chart Section (Top)
                    _buildSpendingChart(),
                    const SizedBox(height: 24),
                    
                    // 2. Unified Stats Grid (Middle - Now perfectly aligned)
                    _buildStatsGrid(),
                    const SizedBox(height: 24),
                    
                    // 3. Table Section (Bottom)
                    _buildRecordsTable(records),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatsGrid() {
    // Using LayoutBuilder to create a grid that is aware of screen width
    // But utilizing IntrinsicHeight or explicit AspectRatio logic in cards for alignment
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        // 4 columns on large, 2 on medium, 1 on small
        int crossAxisCount = 4;
        if (width < 1200) crossAxisCount = 2;
        if (width < 600) crossAxisCount = 1;
        
        final gap = 24.0;
        final totalGap = gap * (crossAxisCount - 1);
        final cardWidth = (width - totalGap) / crossAxisCount;
        
        // Ensure all cards including "Total Expenses" look uniform
        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: [
            _StatCard(
              title: "Today's Total",
              value: _formatAmount(_todayTotal),
              icon: Icons.trending_up,
              color: Colors.blue,
              width: cardWidth,
            ),
            _StatCard(
              title: "Last 7 Days",
              value: _formatAmount(_weekTotal),
              icon: Icons.calendar_today,
              color: Colors.green,
              width: cardWidth,
            ),
            _StatCard(
              title: "This Month",
              value: _formatAmount(_monthTotal),
              icon: Icons.bar_chart,
              color: Colors.purple,
              width: cardWidth,
            ),
            _StatCard(
              title: "Total Expenses",
              value: _formatAmount(_totalExpenses),
              icon: Icons.account_balance_wallet,
              color: kPrimaryColor,
              width: cardWidth,
              isHighlight: true, // Special styling for Total
            ),
          ],
        );
      },
    );
  }

  Widget _buildSpendingChart() {
    final data = _categoryTotals.entries.toList();
    
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: kBorderColor),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 8, offset: const Offset(0,4))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Spending Distribution', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: kTextPrimary)),
          const SizedBox(height: 24),
          if (data.isEmpty)
            Center(child: Text("No data available", style: TextStyle(color: kTextSecondary)))
          else ...[
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: SizedBox(
                height: 32,
                child: Row(
                  children: data.map((e) => Expanded(
                    flex: (e.value * 100).toInt().clamp(1, 10000),
                    child: Tooltip(
                      message: '${e.key}: ${_formatAmount(e.value)}',
                      child: Container(color: _colorForCategory(e.key)),
                    ),
                  )).toList(),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Wrap(
              spacing: 24,
              runSpacing: 12,
              children: data.map((e) => Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(width: 12, height: 12, decoration: BoxDecoration(color: _colorForCategory(e.key), borderRadius: BorderRadius.circular(4))),
                  const SizedBox(width: 8),
                  Text('${e.key}: ', style: TextStyle(fontSize: 13, color: kTextSecondary, fontWeight: FontWeight.w500)),
                  Text(_formatAmount(e.value), style: TextStyle(fontSize: 13, color: kTextPrimary, fontWeight: FontWeight.w600)),
                ],
              )).toList(),
            ),
          ]
        ],
      ),
    );
  }

  Widget _buildRecordsTable(List<ExpenseEntry> records) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: kBorderColor),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 8, offset: const Offset(0,4))],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          // Table Toolbar - Aligned nicely
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            child: Row(
              children: [
                const Text('Expense Records', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: kTextPrimary)),
                const Spacer(),
                SizedBox(
                  width: 280,
                  height: 38,
                  child: TextField(
                    onChanged: (v) => setState(() => _searchQuery = v),
                    style: const TextStyle(fontSize: 14),
                    decoration: InputDecoration(
                      hintText: 'Search expenses...',
                      hintStyle: TextStyle(color: kTextSecondary, fontSize: 13),
                      prefixIcon: Icon(Icons.search, color: kTextSecondary, size: 18),
                      filled: true,
                      fillColor: const Color(0xFFF8FAFC),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: const EdgeInsets.symmetric(vertical: 0),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: kBorderColor),
          
          // Table
          LayoutBuilder(
            builder: (context, constraints) {
              // Dynamically calculate column spacing to fill width
              // Base spacing is generic, but we can make it cleaner
              final width = constraints.maxWidth;
              final spacing = (width > 800) ? (width / 20) : 24.0;
              
              return SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: ConstrainedBox(
                  constraints: BoxConstraints(minWidth: width),
                  child: DataTable(
                    headingRowColor: MaterialStateProperty.all(const Color(0xFFF8FAFC)),
                    headingRowHeight: 48,
                    dataRowMinHeight: 56,
                    dataRowMaxHeight: 64,
                    horizontalMargin: 24,
                    columnSpacing: spacing, // Better spacing
                    columns: const [
                      DataColumn(label: Text('CATEGORY', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: kTextPrimary))),
                      DataColumn(label: Text('JOB ORDER', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: kTextPrimary))),
                      DataColumn(label: Text('DESCRIPTION', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: kTextPrimary))),
                      DataColumn(label: Text('DATE', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: kTextPrimary))),
                      DataColumn(label: Text('AMOUNT', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: kTextPrimary))),
                      DataColumn(label: Text('STATUS', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: kTextPrimary))),
                      DataColumn(label: Text('ACTIONS', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: kTextPrimary))),
                    ],
                    rows: records.map((e) {
                      return DataRow(
                        color: MaterialStateProperty.resolveWith((states) => states.contains(MaterialState.hovered) ? const Color(0xFFF1F5F9) : Colors.white),
                        cells: [
                          DataCell(
                            Row(children: [
                              Container(
                                width: 8, height: 8, 
                                decoration: BoxDecoration(color: _colorForCategory(e.category), shape: BoxShape.circle)
                              ),
                              const SizedBox(width: 10),
                              Text(e.category, style: TextStyle(color: kTextPrimary, fontWeight: FontWeight.w500, fontSize: 13)),
                            ])
                          ),
                          DataCell(Text(e.jobOrderId.isEmpty ? '-' : e.jobOrderId, style: TextStyle(color: kTextSecondary, fontSize: 13))),
                          DataCell(
                            SizedBox(
                              width: 250, // More space for description
                              child: Text(e.description, overflow: TextOverflow.ellipsis, style: TextStyle(color: kTextPrimary, fontSize: 13))
                            )
                          ),
                          DataCell(Text(_formatDate(e.date), style: TextStyle(color: kTextSecondary, fontSize: 13))),
                          DataCell(Text(_formatAmount(e.amount), style: const TextStyle(fontWeight: FontWeight.w600, color: kTextPrimary, fontSize: 13))),
                          DataCell(_StatusBadge(status: e.status)),
                          DataCell(
                            Row(
                              children: [
                                if (_isServiceManager) ...[
                                  IconButton(
                                    icon: const Icon(Icons.edit_outlined, size: 16, color: kTextSecondary),
                                    onPressed: () => _onAddOrEdit(existing: e),
                                    tooltip: 'Edit',
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.archive_outlined, size: 16, color: Colors.orange),
                                    onPressed: () => _onDelete(e),
                                    tooltip: 'Archive',
                                  ),
                                ] else
                                  Text('View only', style: TextStyle(fontSize: 11, color: kTextSecondary)),
                              ],
                            ),
                          ),
                        ],
                      );
                    }).toList(),
                  ),
                ),
              );
            }
          ),
          if (records.isEmpty)
            Padding(
              padding: const EdgeInsets.all(32),
              child: Center(child: Text("No expense records found.", style: TextStyle(color: kTextSecondary))),
            ),
        ],
      ),
    );
  }

  // --- Helpers ---

  Future<void> _showDateRangePicker() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      initialDateRange: _dateFilterStart != null 
        ? DateTimeRange(start: _dateFilterStart!, end: _dateFilterEnd ?? DateTime.now())
        : null,
    );
    if (picked != null) {
      setState(() {
        _dateFilterStart = picked.start;
        _dateFilterEnd = picked.end;
      });
    }
  }

  Color _colorForCategory(String category) {
    switch (category.toLowerCase()) {
      case 'fuel': return Colors.blue;
      case 'materials': return Colors.purple;
      case 'food': return Colors.green;
      case 'transportation': return Colors.orange;
      case 'toll': return Colors.amber;
      default: return Colors.teal;
    }
  }
}

// --- Custom Widgets ---

class _StatData {
  final String title;
  final String value;
  final IconData icon;
  final Color color;
  _StatData(this.title, this.value, this.icon, this.color);
}

class _StatCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color color;
  final double width;
  final bool isHighlight;

  const _StatCard({
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
    required this.width,
    this.isHighlight = false,
  });

  @override
  Widget build(BuildContext context) {
    // Using AspectRatio or explicit heights to ensure perfect grid alignment
    return SizedBox(
      width: width,
      height: 110, // Fixed height for alignment
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFE2E8F0)),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 8, offset: const Offset(0,4))],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isHighlight ? const Color(0xFFFEF2F2) : color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color, size: 24),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(title, style: TextStyle(fontSize: 12, color: const Color(0xFF64748B), fontWeight: FontWeight.w600)),
                  const SizedBox(height: 4),
                  Text(
                    value, 
                    style: TextStyle(
                      fontSize: isHighlight ? 22 : 20, // Slight emphasis for total
                      fontWeight: FontWeight.w800, 
                      color: isHighlight ? color : const Color(0xFF1E293B)
                    ),
                  ),
                ],
              ),
            ),
          ],
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
    final isVerified = status.toLowerCase() == 'verified';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: isVerified ? const Color(0xFFDCFCE7) : const Color(0xFFFFF4DE),
        borderRadius: BorderRadius.circular(6), // Slightly squarer for modern look
      ),
      child: Text(
        status,
        style: TextStyle(
          fontSize: 11, 
          fontWeight: FontWeight.w700, 
          color: isVerified ? const Color(0xFF15803D) : const Color(0xFFB45309)
        ),
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback onPressed;
  final bool isPrimary;

  const _ActionButton({
    required this.label,
    required this.icon,
    required this.onPressed,
    this.isPrimary = false,
  });

  @override
  Widget build(BuildContext context) {
    return ElevatedButton.icon(
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: isPrimary ? const Color(0xFF2563EB) : Colors.white,
        foregroundColor: isPrimary ? Colors.white : const Color(0xFF475569),
        elevation: 0,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: isPrimary ? BorderSide.none : const BorderSide(color: Color(0xFFE2E8F0)),
        ),
      ),
      icon: Icon(icon, size: 16),
      label: Text(label, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
    );
  }
}

// --- Dialog ---

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
    _amountController = TextEditingController(text: e != null ? e.amount.toStringAsFixed(2) : '');
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

  InputDecoration _inputDecor(String label) {
    return InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(fontSize: 13, color: Color(0xFF64748B)),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: Color(0xFF2563EB), width: 1.5),
      ),
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      isDense: true,
    );
  }

  Future<void> _pickDate() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
    );
    if (date != null) setState(() => _date = date);
  }

  void _submit() {
    if (_amountController.text.trim().isEmpty) return;
    final amount = double.tryParse(_amountController.text.trim()) ?? 0;

    final entry = ExpenseEntry(
      id: widget.entry?.id ?? 0,
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
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        width: 500,
        padding: const EdgeInsets.all(24),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                widget.entry == null ? 'Add Expense' : 'Edit Expense',
                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: Color(0xFF1E293B)),
              ),
              const SizedBox(height: 24),
              Row(children: [
                Expanded(
                  child: DropdownButtonFormField<String>(
                    value: _categoryController.text.isEmpty ? 'Fuel' : _categoryController.text,
                    decoration: _inputDecor('Category'),
                    items: ['Fuel', 'Materials', 'Food', 'Transportation', 'Toll', 'Other'].map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
                    onChanged: (v) => setState(() => _categoryController.text = v!),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(child: TextField(controller: _amountController, decoration: _inputDecor('Amount (₱)'), keyboardType: TextInputType.number)),
              ]),
              const SizedBox(height: 16),
              TextField(controller: _joController, decoration: _inputDecor('Linked Job Order (Optional)')),
              const SizedBox(height: 16),
              TextField(controller: _descriptionController, decoration: _inputDecor('Description')),
              const SizedBox(height: 16),
              InkWell(
                onTap: _pickDate,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  decoration: BoxDecoration(
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.calendar_today, size: 16, color: Color(0xFF64748B)),
                      const SizedBox(width: 8),
                      Text('${_date.month}/${_date.day}/${_date.year}', style: const TextStyle(fontSize: 14)),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              SwitchListTile(
                title: const Text('Customer-funded item', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
                subtitle: const Text('Expenses paid directly by client', style: TextStyle(fontSize: 12, color: Colors.grey)),
                value: _isCustomerFunded,
                onChanged: (v) => setState(() => _isCustomerFunded = v),
                contentPadding: EdgeInsets.zero,
              ),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    style: TextButton.styleFrom(foregroundColor: const Color(0xFF64748B)),
                    child: const Text('Cancel'),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: _submit,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF2563EB),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    child: const Text('Save'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}