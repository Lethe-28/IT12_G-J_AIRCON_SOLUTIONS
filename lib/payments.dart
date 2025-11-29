import 'package:flutter/material.dart';
import 'data/app_state.dart';
import 'ui_app_shell.dart';
import 'shared_header.dart';

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
    final PaymentRecord? result = await showDialog<PaymentRecord>(
      context: context,
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
                        ElevatedButton.icon(
                          onPressed: () => _onAddOrEdit(),
                          icon: const Icon(Icons.add),
                          label: const Text('Add Payment'),
                        ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Row(
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
                  const SizedBox(height: 14),
                  Container(
                    decoration: _cardDeco(),
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Text('Payment Records',
                                style: TextStyle(
                                    fontSize: 18, fontWeight: FontWeight.w700)),
                            const Spacer(),
                            SizedBox(
                              width: 260,
                              child: TextField(
                                onChanged: (v) => setState(() => _searchQuery = v),
                                decoration: InputDecoration(
                                  hintText: 'Search by JO, customer, method, or status...',
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
    return AlertDialog(
      title: Text(widget.record == null ? 'Add Payment' : 'Edit Payment'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
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
