import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'data/app_state.dart';
import 'ui_app_shell.dart';
import 'shared/widgets.dart' show LoadingOverlay, EmptyState, showConfirmDialog, showUndoSnackBar, AppDesignTokens, isMobile;

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
  String? _categoryFilter;
  String? _statusFilter;
  final bool _isLoading = false;
  ExpenseEntry? _lastDeletedExpense;
  int? _lastDeletedIndex;
  final List<String> _categories = ['Fuel', 'Materials', 'Food', 'Transportation', 'Toll', 'Other'];

  Future<String?> _promptNewCategory() async {
    String value = '';
    return showDialog<String>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Text('Add Category'),
          content: TextField(
            autofocus: true,
            decoration: const InputDecoration(hintText: 'Category name'),
            onChanged: (v) => value = v,
          ),
          actions: [
            TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Cancel')),
            ElevatedButton(onPressed: () => Navigator.of(ctx).pop(value.trim().isEmpty ? null : value.trim()), child: const Text('Add')),
          ],
        );
      },
    );
  }
  
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
    
    if (_categoryFilter != null && _categoryFilter!.isNotEmpty && _categoryFilter != 'All') {
      result = result.where((e) => e.category == _categoryFilter).toList();
    }
    
    if (_statusFilter != null && _statusFilter!.isNotEmpty && _statusFilter != 'All') {
      result = result.where((e) => e.status.toLowerCase() == _statusFilter!.toLowerCase()).toList();
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
    ExpenseEntry? result;
    if (isMobile(context)) {
      result = await _showExpenseBottomSheet(existing: existing);
    } else {
      result = await showDialog<ExpenseEntry>(
        context: context,
        builder: (context) => _ExpenseDialog(entry: existing, categories: _categories),
      );
    }
    if (result == null) return;

    final res = result; // promote to a local non-nullable variable

    // Persist any new category into the master list so filters include it
    if (!_categories.contains(res.category)) {
      setState(() {
        _categories.add(res.category);
      });
    }

    setState(() {
      if (existing == null) {
        _expenses.add(res);
      } else {
        final index = _expenses.indexWhere((e) => e.id == existing.id);
        if (index != -1) {
          _expenses[index] = res;
        }
      }
    });
  }

  void _onDelete(ExpenseEntry entry) async {
    final confirmed = await showConfirmDialog(
      context: context,
      title: 'Archive Expense',
      message: 'Archive expense "${entry.description}"? This action can be undone.',
      confirmLabel: 'Archive',
      cancelLabel: 'Cancel',
      isDestructive: false,
    );
    if (confirmed != true) return;
    
    setState(() {
      final index = _expenses.indexWhere((e) => e.id == entry.id);
      if (index != -1) {
        _lastDeletedExpense = entry;
        _lastDeletedIndex = index;
        _expenses.removeAt(index);
      }
    });
    
    if (mounted && _lastDeletedExpense != null) {
      showUndoSnackBar(
        context: context,
        message: 'Expense "${entry.description}" has been archived',
        onUndo: () {
          if (_lastDeletedExpense != null && _lastDeletedIndex != null) {
            setState(() {
              _expenses.insert(_lastDeletedIndex!, _lastDeletedExpense!);
              _lastDeletedExpense = null;
              _lastDeletedIndex = null;
            });
          }
        },
      );
    }
  }

  String _formatAmount(double v) => '₱${v.toStringAsFixed(2)}';
  String _formatDate(DateTime d) => '${d.month}/${d.day}/${d.year}';

  // --- UI Builders ---

  @override
  Widget build(BuildContext context) {
    final records = _filteredExpenses;

    return AppShell(
      selectedIndex: 2,
      body: LoadingOverlay(
        isLoading: _isLoading,
        child: RefreshIndicator(
          onRefresh: () async {
            HapticFeedback.lightImpact();
            await Future.delayed(const Duration(milliseconds: 500));
            if (mounted) {
              setState(() {});
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Expenses refreshed'),
                  duration: Duration(seconds: 1),
                  behavior: SnackBarBehavior.floating,
                ),
              );
            }
          },
          child: Builder(
            builder: (context) {
              final isMobileView = isMobile(context);
              return Stack(
                children: [
                  // Main content column
                  Container(
                    color: const Color(0xFFF8FAFC),
                    child: Column(
                      children: [
                        // Header
                        Container(
                          padding: EdgeInsets.symmetric(horizontal: isMobileView ? 16 : 32, vertical: isMobileView ? 16 : 24),
                          color: Colors.white,
                          width: double.infinity,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Expense Tracking (Cash-out)', style: TextStyle(fontSize: isMobileView ? 20 : 24, fontWeight: FontWeight.w700, color: kTextPrimary, letterSpacing: -0.5)),
                              const SizedBox(height: 6),
                              Text('Monitor spending, reimbursements, and job costs.', style: TextStyle(fontSize: isMobileView ? 12 : 14, color: kTextSecondary)),
                              if (isMobileView) ...[
                                const SizedBox(height: 12),
                                Row(children: [
                                  Expanded(child: _ActionButton(label: 'Date Filter', icon: Icons.calendar_today_outlined, onPressed: _showDateRangePicker)),
                                  if (_isServiceManager) ...[
                                    const SizedBox(width: 8),
                                    Expanded(child: _ActionButton(label: 'Add', icon: Icons.add, isPrimary: true, onPressed: () => _onAddOrEdit())),
                                  ],
                                ]),
                              ] else ...[
                                const SizedBox(height: 12),
                                Row(mainAxisAlignment: MainAxisAlignment.end, children: [
                                  _ActionButton(label: 'Date Filter', icon: Icons.calendar_today_outlined, onPressed: _showDateRangePicker),
                                  const SizedBox(width: 12),
                                  if (_isServiceManager) _ActionButton(label: 'Add Expense', icon: Icons.add, isPrimary: true, onPressed: () => _onAddOrEdit()),
                                ]),
                              ],
                            ],
                          ),
                        ),
                        const Divider(height: 1, color: kBorderColor),

                        // Scrollable content
                        Expanded(
                          child: SingleChildScrollView(
                            padding: EdgeInsets.all(isMobileView ? 16 : 32),
                            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                              if (!isMobileView) ...[
                                Row(
                                  children: [
                                    Expanded(
                                      child: DropdownButtonFormField<String>(
                                        value: _categoryFilter ?? 'All',
                                        decoration: InputDecoration(labelText: 'Category', border: OutlineInputBorder(borderRadius: BorderRadius.circular(8))),
                                        items: ['All', ..._categories].map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
                                        onChanged: (value) => setState(() => _categoryFilter = value == 'All' ? null : value),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    SizedBox(
                                      width: 220,
                                      child: DropdownButtonFormField<String>(
                                        value: _statusFilter ?? 'All',
                                        decoration: InputDecoration(labelText: 'Status', border: OutlineInputBorder(borderRadius: BorderRadius.circular(8))),
                                        items: ['All', 'Pending', 'Verified'].map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
                                        onChanged: (value) => setState(() => _statusFilter = value == 'All' ? null : value),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 24),
                              ],
                              _buildSpendingChart(),
                              const SizedBox(height: 24),
                              _buildStatsGrid(),
                              const SizedBox(height: 24),
                              records.isEmpty ? _buildEmptyState() : _buildRecordsTable(records),
                            ]),
                          ),
                        ),
                      ],
                    ),
                  ),

                  // FAB overlay for mobile
                  if (isMobileView && _isServiceManager)
                    Positioned(right: 16, bottom: 24, child: FloatingActionButton.extended(onPressed: () => _onAddOrEdit(), label: const Text('Add'), icon: const Icon(Icons.add), elevation: 4, materialTapTargetSize: MaterialTapTargetSize.padded)),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  // Mobile bottom-sheet form for add/edit to improve UX on phones
  Future<ExpenseEntry?> _showExpenseBottomSheet({ExpenseEntry? existing}) async {
    return showModalBottomSheet<ExpenseEntry>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (context) {
        // Use StatefulBuilder to manage local form state inside the sheet
        return Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
          child: StatefulBuilder(
            builder: (context, innerSetState) {
              final tcCategory = TextEditingController(text: existing?.category ?? _categories.first);
              final tcJO = TextEditingController(text: existing?.jobOrderId ?? '');
              final tcDesc = TextEditingController(text: existing?.description ?? '');
              final tcAmount = TextEditingController(text: existing != null ? existing.amount.toStringAsFixed(2) : '');
              String status = existing?.status ?? 'Pending';
              bool isCustomerFunded = existing?.isCustomerFunded ?? false;
              DateTime date = existing?.date ?? DateTime.now();
              final localCats = List<String>.from(_categories);

              Future<void> pickDate() async {
                final d = await showDatePicker(context: context, initialDate: date, firstDate: DateTime(2020), lastDate: DateTime(2030));
                if (d != null) innerSetState(() => date = d);
              }

              void submit() {
                final amount = double.tryParse(tcAmount.text.trim()) ?? 0;
                if (tcDesc.text.trim().isEmpty || amount <= 0) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please provide a valid amount and description')));
                  return;
                }
                final entry = ExpenseEntry(
                  id: existing?.id ?? DateTime.now().millisecondsSinceEpoch,
                  category: tcCategory.text.trim(),
                  jobOrderId: tcJO.text.trim(),
                  description: tcDesc.text.trim(),
                  date: date,
                  amount: amount,
                  status: status,
                  isCustomerFunded: isCustomerFunded,
                );
                Navigator.of(context).pop(entry);
              }

              return SafeArea(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(existing == null ? 'Add Expense' : 'Edit Expense', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
                          IconButton(onPressed: () => Navigator.of(context).pop(), icon: const Icon(Icons.close)),
                        ],
                      ),
                      const SizedBox(height: 8),
                      DropdownButtonFormField<String>(
                        value: tcCategory.text.isEmpty ? localCats.first : tcCategory.text,
                        items: [
                          ...localCats.map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
                          const DropdownMenuItem(value: '__add_new__', child: Text('Add new...')),
                        ],
                        onChanged: (v) async {
                          if (v == '__add_new__') {
                            final newCat = await _promptNewCategory();
                            if (newCat != null) {
                              innerSetState(() {
                                localCats.add(newCat);
                                tcCategory.text = newCat;
                              });
                            }
                          } else if (v != null) {
                            innerSetState(() => tcCategory.text = v);
                          }
                        },
                        decoration: InputDecoration(labelText: 'Category', border: OutlineInputBorder(borderRadius: BorderRadius.circular(8))),
                      ),
                      const SizedBox(height: 8),
                      TextField(controller: tcAmount, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(labelText: 'Amount (₱)', border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(8))))),
                      const SizedBox(height: 8),
                      TextField(controller: tcJO, decoration: const InputDecoration(labelText: 'Job Order (optional)', border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(8))))),
                      const SizedBox(height: 8),
                      TextField(controller: tcDesc, decoration: const InputDecoration(labelText: 'Description', border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(8))))),
                      const SizedBox(height: 8),
                      Row(children: [
                        ElevatedButton.icon(onPressed: pickDate, icon: const Icon(Icons.calendar_today), label: const Text('Pick date')),
                        const SizedBox(width: 12),
                        Expanded(child: Text('${date.month}/${date.day}/${date.year}')),
                      ]),
                      const SizedBox(height: 12),
                      Row(children: [
                        Expanded(child: OutlinedButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancel'))),
                        const SizedBox(width: 8),
                        ElevatedButton(onPressed: submit, child: const Text('Save')),
                      ]),
                      const SizedBox(height: 8),
                    ],
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }

  Widget _buildEmptyState() {
    return EmptyState(
      icon: Icons.receipt_long_outlined,
      title: 'No Expenses Found',
      message: _searchQuery.isNotEmpty || _categoryFilter != null || _statusFilter != null
          ? 'Try adjusting your search or filters to find what you\'re looking for.'
          : 'Start tracking expenses by adding your first expense entry.',
      actionLabel: _isServiceManager ? 'Add Expense' : null,
      onAction: _isServiceManager ? () => _onAddOrEdit() : null,
      iconColor: kPrimaryColor,
    );
  }
  
  Widget _buildStatsGrid() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final isMobileView = width < 600;
        final isTabletView = width >= 600 && width < 1024;
        
        // 4 columns on large, 2 on medium/tablet, 1 on mobile
        int crossAxisCount = 4;
        if (isTabletView) crossAxisCount = 2;
        if (isMobileView) crossAxisCount = 1;
        
        final gap = isMobileView ? 12.0 : 24.0;
        final totalGap = gap * (crossAxisCount - 1);
        final cardWidth = isMobileView ? width : (width - totalGap) / crossAxisCount;
        
        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: [
            _StatCard(
              title: "Today's Total",
              value: _formatAmount(_todayTotal),
              icon: Icons.trending_up,
              color: Colors.blue,
              width: isMobileView ? double.infinity : cardWidth,
            ),
            _StatCard(
              title: "Last 7 Days",
              value: _formatAmount(_weekTotal),
              icon: Icons.calendar_today,
              color: Colors.green,
              width: isMobileView ? double.infinity : cardWidth,
            ),
            _StatCard(
              title: "This Month",
              value: _formatAmount(_monthTotal),
              icon: Icons.bar_chart,
              color: Colors.purple,
              width: isMobileView ? double.infinity : cardWidth,
            ),
            _StatCard(
              title: "Total Expenses",
              value: _formatAmount(_totalExpenses),
              icon: Icons.account_balance_wallet,
              color: kPrimaryColor,
              width: isMobileView ? double.infinity : cardWidth,
              isHighlight: true,
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
          // Table Toolbar - Responsive
          Padding(
            padding: EdgeInsets.symmetric(
              horizontal: isMobile(context) ? 16 : 24,
              vertical: 16,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      'Expense Records',
                      style: TextStyle(
                        fontSize: isMobile(context) ? 14 : 16,
                        fontWeight: FontWeight.w700,
                        color: kTextPrimary,
                      ),
                    ),
                    if (!isMobile(context)) const Spacer(),
                  ],
                ),
                if (isMobile(context)) ...[
                  const SizedBox(height: 12),
                  TextField(
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
                      contentPadding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                  const SizedBox(height: 12),
                  // Show Category and Status side-by-side on mobile as two columns
                  Row(
                    children: [
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          value: _categoryFilter ?? 'All',
                          decoration: InputDecoration(labelText: 'Category', border: OutlineInputBorder(borderRadius: BorderRadius.circular(8))),
                          items: ['All', ..._categories].map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
                          onChanged: (value) => setState(() => _categoryFilter = value == 'All' ? null : value),
                        ),
                      ),
                      const SizedBox(width: 12),
                      SizedBox(
                        width: 140,
                        child: DropdownButtonFormField<String>(
                          value: _statusFilter ?? 'All',
                          decoration: InputDecoration(labelText: 'Status', border: OutlineInputBorder(borderRadius: BorderRadius.circular(8))),
                          items: ['All', 'Pending', 'Verified'].map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
                          onChanged: (value) => setState(() => _statusFilter = value == 'All' ? null : value),
                        ),
                      ),
                    ],
                  ),
                ] else ...[
                  const SizedBox(height: 12),
                  Row(
                    children: [
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
                ],
              ],
            ),
          ),
          const Divider(height: 1, color: kBorderColor),
          
          // Table
          LayoutBuilder(
            builder: (context, constraints) {
              final width = constraints.maxWidth;
              final spacing = (width > 800) ? (width / 20) : 24.0;

              if (isMobile(context)) {
                // Mobile: vertical list with slidable actions
                return Column(
                  children: records.map((e) => Padding(
                      padding: const EdgeInsets.symmetric(vertical: 6.0, horizontal: 0),
                      child: Dismissible(
                        key: ValueKey(e.id),
                        direction: DismissDirection.endToStart,
                        confirmDismiss: (dir) async {
                          // Ask the existing confirm dialog to archive
                          final confirmed = await showConfirmDialog(
                            context: context,
                            title: 'Archive Expense',
                            message: 'Archive expense "${e.description}"? This action can be undone.',
                            confirmLabel: 'Archive',
                            cancelLabel: 'Cancel',
                            isDestructive: false,
                          );
                          if (confirmed == true) {
                            // perform deletion logic
                            setState(() {
                              final index = _expenses.indexWhere((x) => x.id == e.id);
                              if (index != -1) {
                                _lastDeletedExpense = _expenses[index];
                                _lastDeletedIndex = index;
                                _expenses.removeAt(index);
                              }
                            });
                            if (mounted && _lastDeletedExpense != null) {
                              showUndoSnackBar(
                                context: context,
                                message: 'Expense "${e.description}" has been archived',
                                onUndo: () {
                                  if (_lastDeletedExpense != null && _lastDeletedIndex != null) {
                                    setState(() {
                                      _expenses.insert(_lastDeletedIndex!, _lastDeletedExpense!);
                                      _lastDeletedExpense = null;
                                      _lastDeletedIndex = null;
                                    });
                                  }
                                },
                              );
                            }
                          }
                          return confirmed == true;
                        },
                        background: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          alignment: Alignment.centerRight,
                          decoration: BoxDecoration(color: Colors.orange, borderRadius: BorderRadius.circular(12)),
                          child: const Icon(Icons.archive_outlined, color: Colors.white),
                        ),
                        child: Card(
                          elevation: 0,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          child: ListTile(
                            onTap: () => _onAddOrEdit(existing: e),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                            leading: Container(width: 40, height: 40, decoration: BoxDecoration(color: _colorForCategory(e.category), borderRadius: BorderRadius.circular(8))),
                            title: Text(e.description, style: const TextStyle(fontWeight: FontWeight.w600)),
                            subtitle: Text('${e.jobOrderId.isEmpty ? '-' : e.jobOrderId} • ${_formatDate(e.date)}', style: const TextStyle(fontSize: 12)),
                            trailing: Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(_formatAmount(e.amount), style: const TextStyle(fontWeight: FontWeight.w700)),
                                const SizedBox(height: 6),
                                _StatusBadge(status: e.status),
                              ],
                            ),
                          ),
                        ),
                      ),
                    )).toList(),
                );
              }

              // Desktop / larger screens: keep the DataTable
              return SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: ConstrainedBox(
                  constraints: BoxConstraints(minWidth: width),
                  child: DataTable(
                    headingRowColor: WidgetStateProperty.all(const Color(0xFFF8FAFC)),
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
                        color: WidgetStateProperty.resolveWith((states) => states.contains(WidgetState.hovered) ? const Color(0xFFF1F5F9) : Colors.white),
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
                                    onPressed: () {
                                      HapticFeedback.selectionClick();
                                      _onAddOrEdit(existing: e);
                                    },
                                    tooltip: 'Edit',
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.archive_outlined, size: 16, color: Colors.orange),
                                    onPressed: () {
                                      HapticFeedback.mediumImpact();
                                      _onDelete(e);
                                    },
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

// Removed unused _StatData class

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
  final List<String>? categories;
  const _ExpenseDialog({this.entry, this.categories});

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
  bool _isSubmitting = false;
  String? _amountError;
  String? _descriptionError;

  @override
  void initState() {
    super.initState();
    final e = widget.entry;
    final cats = widget.categories ?? ['Fuel', 'Materials', 'Food', 'Transportation', 'Toll', 'Other'];
    _categoryController = TextEditingController(text: e?.category ?? cats.first);
    _joController = TextEditingController(text: e?.jobOrderId ?? '');
    _descriptionController = TextEditingController(text: e?.description ?? '');
    _amountController = TextEditingController(text: e != null ? e.amount.toStringAsFixed(2) : '');
    _status = e?.status ?? 'Pending';
    _isCustomerFunded = e?.isCustomerFunded ?? false;
    _date = e?.date ?? DateTime.now();
  }

  Future<void> _pickDate() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
    );
    if (date != null && mounted) setState(() => _date = date);
  }

  InputDecoration _inputDecor(String label) {
    return InputDecoration(
      labelText: label,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
    );
  }

  void _validateForm() {
    setState(() {
      _amountError = null;
      _descriptionError = null;
      
      if (_amountController.text.trim().isEmpty) {
        _amountError = 'Amount is required';
      } else {
        final amount = double.tryParse(_amountController.text.trim());
        if (amount == null || amount <= 0) {
          _amountError = 'Please enter a valid amount greater than 0';
        }
      }
      
      if (_descriptionController.text.trim().isEmpty) {
        _descriptionError = 'Description is required';
      }
    });
  }
  
  bool get _isFormValid {
    if (_amountController.text.trim().isEmpty) return false;
    final amount = double.tryParse(_amountController.text.trim());
    if (amount == null || amount <= 0) return false;
    if (_descriptionController.text.trim().isEmpty) return false;
    return true;
  }
  
  Future<void> _submit() async {
    _validateForm();
    if (!_isFormValid) {
      return;
    }
    
    setState(() => _isSubmitting = true);
    
    // Simulate async operation
    await Future.delayed(const Duration(milliseconds: 500));
    
    if (!mounted) return;
    
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
    
    if (mounted) {
      Navigator.of(context).pop(entry);
    }
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
                    initialValue: _categoryController.text.isEmpty ? 'Fuel' : _categoryController.text,
                    decoration: _inputDecor('Category'),
                    items: [
                      ...['Fuel', 'Materials', 'Food', 'Transportation', 'Toll', 'Other'].map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
                      const DropdownMenuItem(value: '__add_new__', child: Text('Add new...')),
                    ],
                    onChanged: (v) async {
                      if (v == '__add_new__') {
                        String name = '';
                        final newCat = await showDialog<String>(
                          context: context,
                          builder: (ctx) => AlertDialog(
                            title: const Text('Add Category'),
                            content: TextField(autofocus: true, onChanged: (t) => name = t, decoration: const InputDecoration(hintText: 'Category name')),
                            actions: [
                              TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Cancel')),
                              ElevatedButton(onPressed: () => Navigator.of(ctx).pop(name.trim().isEmpty ? null : name.trim()), child: const Text('Add')),
                            ],
                          ),
                        );
                        if (newCat != null) setState(() => _categoryController.text = newCat);
                      } else if (v != null) {
                        setState(() => _categoryController.text = v);
                      }
                    },
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: TextField(
                    controller: _amountController,
                    decoration: _inputDecor('Amount (₱)').copyWith(
                      errorText: _amountError,
                      suffixIcon: _amountController.text.trim().isNotEmpty &&
                              _amountError == null &&
                              (double.tryParse(_amountController.text.trim()) ?? 0) > 0
                          ? const Icon(Icons.check_circle, color: AppDesignTokens.success, size: 20)
                          : null,
                    ),
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    onChanged: (v) {
                      if (v.trim().isNotEmpty) {
                        final amount = double.tryParse(v.trim());
                        if (amount != null && amount > 0) {
                          setState(() => _amountError = null);
                        }
                      }
                    },
                  ),
                ),
              ]),
              const SizedBox(height: 16),
              TextField(controller: _joController, decoration: _inputDecor('Linked Job Order (Optional)')),
              const SizedBox(height: 16),
              TextField(
                controller: _descriptionController,
                decoration: _inputDecor('Description').copyWith(
                  errorText: _descriptionError,
                  suffixIcon: _descriptionController.text.trim().isNotEmpty && _descriptionError == null
                      ? const Icon(Icons.check_circle, color: AppDesignTokens.success, size: 20)
                      : null,
                ),
                onChanged: (v) {
                  if (v.trim().isNotEmpty) {
                    setState(() => _descriptionError = null);
                  }
                },
              ),
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
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _isSubmitting ? null : () => Navigator.pop(context),
                      child: const Padding(padding: EdgeInsets.symmetric(vertical: 12), child: Text('Cancel')),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _isSubmitting ? null : _submit,
                      style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 12)),
                      child: const Text('Save'),
                    ),
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