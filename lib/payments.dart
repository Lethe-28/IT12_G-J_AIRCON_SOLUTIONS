import 'package:flutter/material.dart';
import 'data/app_state.dart';
import 'ui_app_shell.dart';
import 'shared_header.dart';
import 'shared/widgets.dart' show AnimatedCard, HoverCard, AnimatedButton, isMobile;

class PaymentRecord {
  final int id;
  String jobOrderId;
  String customerName;
  DateTime date;
  double amount;
  String method; // Cash, GCash, Bank transfer, etc.
  String referenceNumber;
  String orNumber;
  String status; // Pending / Verified

  PaymentRecord({
    required this.id,
    required this.jobOrderId,
    required this.customerName,
    required this.date,
    required this.amount,
    required this.method,
    required this.referenceNumber,
    required this.orNumber,
    required this.status,
  });
}

class PaymentsScreen extends StatefulWidget {
  const PaymentsScreen({super.key});

  @override
  State<PaymentsScreen> createState() => _PaymentsScreenState();
}

class _PaymentsScreenState extends State<PaymentsScreen> {
  final List<PaymentRecord> _payments = [];
  String _searchQuery = '';

  bool get _isAdmin => AppState.currentRole == UserRole.admin;

  @override
  void initState() {
    super.initState();
    _seedData();
  }

  void _seedData() {
    _payments.addAll([
      PaymentRecord(
        id: 1,
        jobOrderId: 'JO-2025-001',
        customerName: 'ABC Corporation',
        date: DateTime(2025, 11, 10),
        amount: 18500,
        method: 'Bank transfer',
        referenceNumber: 'REF-001',
        orNumber: 'OR-1001',
        status: 'Verified',
      ),
      PaymentRecord(
        id: 2,
        jobOrderId: 'JO-2025-002',
        customerName: 'XYZ Retail Store',
        date: DateTime(2025, 11, 10),
        amount: 3500,
        method: 'GCash',
        referenceNumber: 'GCASH-234',
        orNumber: 'OR-1002',
        status: 'Pending',
      ),
    ]);
  }

  List<PaymentRecord> get _filteredPayments {
    if (_searchQuery.isEmpty) return _payments;
    final q = _searchQuery.toLowerCase();
    return _payments
        .where((p) =>
            p.jobOrderId.toLowerCase().contains(q) ||
            p.customerName.toLowerCase().contains(q) ||
            p.method.toLowerCase().contains(q) ||
            p.status.toLowerCase().contains(q))
        .toList();
  }

  void _onAddOrEdit({PaymentRecord? existing}) async {
    final PaymentRecord? result = await showModalBottomSheet<PaymentRecord>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _PaymentDialog(record: existing),
    );
    if (result == null) return;

    setState(() {
      if (existing == null) {
        final newId = (_payments.isNotEmpty ? _payments.last.id + 1 : 1);
        _payments.add(PaymentRecord(
          id: newId,
          jobOrderId: result.jobOrderId,
          customerName: result.customerName,
          date: result.date,
          amount: result.amount,
          method: result.method,
          referenceNumber: result.referenceNumber,
          orNumber: result.orNumber,
          status: result.status,
        ));
      } else {
        final index = _payments.indexWhere((p) => p.id == existing.id);
        if (index != -1) {
          _payments[index] = result;
        }
      }
    });
  }

  void _onDelete(PaymentRecord record) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Payment'),
        content: Text('Delete payment for ${record.jobOrderId}?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Delete')),
        ],
      ),
    );
    if (confirmed != true) return;
    setState(() {
      _payments.removeWhere((p) => p.id == record.id);
    });
  }

  String _formatDate(DateTime d) {
    final mm = d.month.toString().padLeft(2, '0');
    final dd = d.day.toString().padLeft(2, '0');
    final yyyy = d.year.toString();
    return '$mm/$dd/$yyyy';
  }

  String _formatAmount(double v) {
    return '₱${v.toStringAsFixed(2)}';
  }

  double get _totalAmount => _payments.fold(0, (sum, p) => sum + p.amount);

  @override
  Widget build(BuildContext context) {
    final payments = _filteredPayments;
    return AppShell(
      selectedIndex: 2,
      body: Column(
        children: [
          SharedHeader(
            welcomeText: 'Payments (Cash-in)',
            subtitleText: 'Verify client remittances and official receipts.',
            notificationCount: 0,
            showGreeting: false,
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Text('Payments (Cash-in)',
                          style: TextStyle(fontSize: 24, fontWeight: FontWeight.w700)),
                      const Spacer(),
                      if (_isAdmin)
                        AnimatedButton(
                          onPressed: () => _onAddOrEdit(),
                          icon: Icons.add,
                          backgroundColor: Theme.of(context).colorScheme.primary,
                          foregroundColor: Colors.white,
                          child: const Text('Add Payment'),
                        ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  AnimatedCard(
                    delay: const Duration(milliseconds: 200),
                    child: Row(
                      children: [
                        Expanded(
                          child: _statCard(
                            'Total Collected',
                            _formatAmount(_totalAmount),
                            '${payments.length} payments recorded',
                            Colors.green,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  Container(
                    decoration: _cardDeco(),
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        LayoutBuilder(
                          builder: (context, constraints) {
                            final isNarrow = constraints.maxWidth < 600;
                            if (isNarrow) {
                              return Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text('Payment Records',
                                      style: TextStyle(
                                          fontSize: 18, fontWeight: FontWeight.w700)),
                                  const SizedBox(height: 12),
                                  AnimatedCard(
                                    delay: const Duration(milliseconds: 250),
                                    child: HoverCard(
                                      padding: EdgeInsets.zero,
                                      child: TextField(
                                        onChanged: (v) => setState(() => _searchQuery = v),
                                        decoration: InputDecoration(
                                          hintText: 'Search by JO, customer...',
                                          prefixIcon: const Icon(Icons.search, size: 18),
                                          filled: true,
                                          fillColor: const Color(0xFFF8FAFC),
                                          border: OutlineInputBorder(
                                            borderRadius: BorderRadius.circular(10),
                                            borderSide: BorderSide.none,
                                          ),
                                          contentPadding: const EdgeInsets.symmetric(vertical: 12),
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              );
                            }
                            return Row(
                              children: [
                                const Text('Payment Records',
                                    style: TextStyle(
                                        fontSize: 18, fontWeight: FontWeight.w700)),
                                const Spacer(),
                                AnimatedCard(
                                  delay: const Duration(milliseconds: 250),
                                  child: Flexible(
                                    child: HoverCard(
                                      padding: EdgeInsets.zero,
                                      child: ConstrainedBox(
                                        constraints: const BoxConstraints(maxWidth: 340),
                                        child: TextField(
                                          onChanged: (v) => setState(() => _searchQuery = v),
                                          decoration: InputDecoration(
                                            hintText: 'Search by JO, customer, method, or status...',
                                            prefixIcon: const Icon(Icons.search, size: 18),
                                            filled: true,
                                            fillColor: const Color(0xFFF8FAFC),
                                            border: OutlineInputBorder(
                                              borderRadius: BorderRadius.circular(10),
                                              borderSide: BorderSide.none,
                                            ),
                                            contentPadding: const EdgeInsets.symmetric(vertical: 12),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            );
                          },
                        ),
                        const SizedBox(height: 12),
                        // Mobile card view vs desktop table
                        if (MediaQuery.of(context).size.width < 600)
                          Column(
                            children: payments.isEmpty
                                ? [
                                    Container(
                                      padding: const EdgeInsets.symmetric(vertical: 40),
                                      child: const Center(
                                        child: Text(
                                          'No payments found',
                                          style: TextStyle(color: Color(0xFF64748B)),
                                        ),
                                      ),
                                    ),
                                  ]
                                : payments.asMap().entries.map((e) => AnimatedCard(
                                    delay: Duration(milliseconds: 300 + (e.key * 50)),
                                    child: _buildMobileCard(e.value),
                                  )).toList(),
                          )
                        else
                          AnimatedCard(
                            delay: const Duration(milliseconds: 300),
                            child: HoverCard(
                              padding: EdgeInsets.zero,
                              child: SingleChildScrollView(
                                scrollDirection: Axis.horizontal,
                                child: ConstrainedBox(
                                  constraints: const BoxConstraints(minWidth: 900),
                                  child: DataTable(
                                columns: const [
                                  DataColumn(label: Text('JO NUMBER')),
                                  DataColumn(label: Text('CUSTOMER')),
                                  DataColumn(label: Text('DATE')),
                                  DataColumn(label: Text('AMOUNT')),
                                  DataColumn(label: Text('METHOD')),
                                  DataColumn(label: Text('REF / OR')),
                                  DataColumn(label: Text('STATUS')),
                                  DataColumn(label: Text('ACTIONS')),
                                ],
                                rows: payments.map(_dataRow).toList(),
                                  ),
                                ),
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
    );
  }

  DataRow _dataRow(PaymentRecord p) {
    final isVerified = p.status.toLowerCase() == 'verified';
    final badgeColor = isVerified ? const Color(0xFFE8FFF3) : const Color(0xFFFFF4E5);
    final textColor = isVerified ? const Color(0xFF059669) : const Color(0xFFB45309);

    return DataRow(
      cells: [
        DataCell(Text(p.jobOrderId)),
        DataCell(Text(p.customerName)),
        DataCell(Text(_formatDate(p.date))),
        DataCell(Text(_formatAmount(p.amount))),
        DataCell(Text(p.method)),
        DataCell(Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Ref: ${p.referenceNumber}'),
            Text('OR: ${p.orNumber}',
                style: const TextStyle(fontSize: 11, color: Colors.black54)),
          ],
        )),
        DataCell(Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: badgeColor,
            borderRadius: BorderRadius.circular(999),
          ),
          child: Text(p.status,
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: textColor)),
        )),
        DataCell(Row(
          children: [
            if (_isAdmin) ...[
              IconButton(
                icon: const Icon(Icons.edit_outlined, size: 18, color: Colors.black87),
                onPressed: () => _onAddOrEdit(existing: p),
              ),
              const SizedBox(width: 4),
              IconButton(
                icon: const Icon(Icons.delete_outline, size: 18, color: Colors.red),
                onPressed: () => _onDelete(p),
              ),
            ] else
              const Text('View only',
                  style: TextStyle(fontSize: 12, color: Colors.black54)),
          ],
        )),
      ],
    );
  }

  Widget _statCard(String title, String value, String note, Color color) {
    return Container(
      decoration: _cardDeco(),
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Container(
            decoration: BoxDecoration(
              color: color.withOpacity(.1),
              borderRadius: BorderRadius.circular(10),
            ),
            padding: const EdgeInsets.all(10),
            child: Icon(Icons.payments_outlined, color: color),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
              const SizedBox(height: 6),
              Text(value,
                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
              const SizedBox(height: 2),
              Text(note, style: const TextStyle(color: Colors.black54)),
            ],
          )
        ],
      ),
    );
  }

  Widget _buildMobileCard(PaymentRecord p) {
    final isVerified = p.status.toLowerCase() == 'verified';
    final statusColor = isVerified ? const Color(0xFF059669) : const Color(0xFFB45309);
    final statusBgColor = isVerified ? const Color(0xFFE8FFF3) : const Color(0xFFFFF4E5);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header: JO ID + Status Badge
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        p.jobOrderId,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF64748B),
                        ),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      p.customerName,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF1E293B),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: statusBgColor,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  p.status,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: statusColor,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Key Info Row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _formatAmount(p.amount),
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF1E293B),
                      ),
                    ),
                    const SizedBox(height: 2),
                    const Text(
                      'Amount',
                      style: TextStyle(
                        fontSize: 11,
                        color: Color(0xFF64748B),
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      p.method,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF1E293B),
                      ),
                    ),
                    const SizedBox(height: 2),
                    const Text(
                      'Method',
                      style: TextStyle(
                        fontSize: 11,
                        color: Color(0xFF64748B),
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _formatDate(p.date),
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF1E293B),
                      ),
                    ),
                    const SizedBox(height: 2),
                    const Text(
                      'Date',
                      style: TextStyle(
                        fontSize: 11,
                        color: Color(0xFF64748B),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Details section (expandable look)
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Text(
                      'Ref #: ',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF64748B),
                      ),
                    ),
                    Expanded(
                      child: Text(
                        p.referenceNumber,
                        style: const TextStyle(
                          fontSize: 12,
                          color: Color(0xFF1E293B),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    const Text(
                      'OR #: ',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF64748B),
                      ),
                    ),
                    Expanded(
                      child: Text(
                        p.orNumber,
                        style: const TextStyle(
                          fontSize: 12,
                          color: Color(0xFF1E293B),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          // Action buttons
          if (_isAdmin)
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _onAddOrEdit(existing: p),
                    icon: const Icon(Icons.edit_outlined, size: 16),
                    label: const Text('Edit', style: TextStyle(fontSize: 12)),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _onDelete(p),
                    icon: const Icon(Icons.delete_outline, size: 16),
                    label: const Text('Delete', style: TextStyle(fontSize: 12)),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.red,
                      side: const BorderSide(color: Colors.red),
                    ),
                  ),
                ),
              ],
            )
          else
            Container(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: const Center(
                child: Text(
                  'View Only',
                  style: TextStyle(
                    fontSize: 12,
                    color: Color(0xFF64748B),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  BoxDecoration _cardDeco() => BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      );
}

class _PaymentDialog extends StatefulWidget {
  final PaymentRecord? record;
  const _PaymentDialog({this.record});

  @override
  State<_PaymentDialog> createState() => _PaymentDialogState();
}

class _PaymentDialogState extends State<_PaymentDialog> {
  late TextEditingController _joController;
  late TextEditingController _customerController;
  late TextEditingController _amountController;
  late TextEditingController _refController;
  late TextEditingController _orController;
  String _method = 'Cash';
  String _status = 'Pending';
  DateTime _date = DateTime.now();

  @override
  void initState() {
    super.initState();
    final r = widget.record;
    _joController = TextEditingController(text: r?.jobOrderId ?? '');
    _customerController = TextEditingController(text: r?.customerName ?? '');
    _amountController = TextEditingController(
        text: r != null ? r.amount.toStringAsFixed(2) : '');
    _refController = TextEditingController(text: r?.referenceNumber ?? '');
    _orController = TextEditingController(text: r?.orNumber ?? '');
    _method = r?.method ?? 'Cash';
    _status = r?.status ?? 'Pending';
    _date = r?.date ?? DateTime.now();
  }

  @override
  void dispose() {
    _joController.dispose();
    _customerController.dispose();
    _amountController.dispose();
    _refController.dispose();
    _orController.dispose();
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
    if (_joController.text.trim().isEmpty ||
        _customerController.text.trim().isEmpty ||
        _amountController.text.trim().isEmpty) {
      return;
    }
    final amount = double.tryParse(_amountController.text.trim()) ?? 0;

    final existing = widget.record;
    final record = PaymentRecord(
      id: existing?.id ?? 0,
      jobOrderId: _joController.text.trim(),
      customerName: _customerController.text.trim(),
      date: _date,
      amount: amount,
      method: _method,
      referenceNumber: _refController.text.trim(),
      orNumber: _orController.text.trim(),
      status: _status,
    );
    Navigator.of(context).pop(record);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.9,
      ),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header with drag handle
          Container(
            padding: const EdgeInsets.fromLTRB(24, 12, 24, 16),
            decoration: const BoxDecoration(
              border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0))),
            ),
            child: Column(
              children: [
                Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE2E8F0),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.green.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.payments, color: Colors.green, size: 24),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        widget.record == null ? 'Add Payment' : 'Edit Payment',
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close, size: 20),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                  ],
                ),
              ],
            ),
          ),
          // Content
          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
            TextField(
              controller: _joController,
              decoration: const InputDecoration(labelText: 'Job Order Number'),
            ),
            TextField(
              controller: _customerController,
              decoration: const InputDecoration(labelText: 'Customer Name'),
            ),
            TextField(
              controller: _amountController,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(labelText: 'Amount (₱)'),
            ),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              initialValue: _method,
              decoration: const InputDecoration(labelText: 'Payment Method'),
              items: const [
                DropdownMenuItem(value: 'Cash', child: Text('Cash')),
                DropdownMenuItem(value: 'GCash', child: Text('GCash')),
                DropdownMenuItem(value: 'Bank transfer', child: Text('Bank transfer')),
                DropdownMenuItem(value: 'Card', child: Text('Card')),
                DropdownMenuItem(value: 'Cheque', child: Text('Cheque')),
                DropdownMenuItem(value: 'Other', child: Text('Other')),
              ],
              onChanged: (v) => setState(() => _method = v ?? 'Cash'),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _refController,
              decoration:
                  const InputDecoration(labelText: 'Reference Number (bank/GCash/etc.)'),
            ),
            TextField(
              controller: _orController,
              decoration: const InputDecoration(labelText: 'OR Number'),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Payment Date: ${_date.month.toString().padLeft(2, '0')}/${_date.day.toString().padLeft(2, '0')}/${_date.year}',
                  ),
                ),
                TextButton(onPressed: _pickDate, child: const Text('Change')),
              ],
            ),
            const SizedBox(height: 8),
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
          ),
          // Footer actions
          Container(
            padding: const EdgeInsets.all(24),
            decoration: const BoxDecoration(
              color: Colors.white,
              border: Border(top: BorderSide(color: Color(0xFFE2E8F0))),
            ),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.of(context).pop(),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    child: const Text('Cancel'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: ElevatedButton(
                    onPressed: _submit,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    child: const Text('Save Payment'),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
