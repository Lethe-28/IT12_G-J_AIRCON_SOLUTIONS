import 'package:flutter/material.dart';
import 'ui_app_shell.dart';

class JobOrder {
  final String id;
  String clientName;
  String jobType;
  String technician;
  DateTime dateTime;
  String duration;
  String location;
  String status;
  String workType; // Installation, CM (Corrective), PM (Preventive)
  String customerType; // e.g. Commercial, Residential
  int numberOfUnits;
  String unitDescription; // what unit(s) these are
  String customerAddress;
  String customerContact;
  String workNotes;
  String followUpSchedule; // e.g. month or date

  JobOrder({
    required this.id,
    required this.clientName,
    required this.jobType,
    required this.technician,
    required this.dateTime,
    required this.duration,
    required this.location,
    required this.status,
    this.workType = '',
    this.customerType = '',
    this.numberOfUnits = 0,
    this.unitDescription = '',
    this.customerAddress = '',
    this.customerContact = '',
    this.workNotes = '',
    this.followUpSchedule = '',
  });
}

class SchedulingScreen extends StatefulWidget {
  const SchedulingScreen({super.key});

  @override
  State<SchedulingScreen> createState() => _SchedulingScreenState();
}

class _SchedulingScreenState extends State<SchedulingScreen> {
  final List<JobOrder> _orders = [];
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _seedData();
  }

  void _seedData() {
    _orders.addAll([
      JobOrder(
        id: 'JO-2025-001',
        clientName: 'ABC Corporation',
        jobType: 'Installation',
        technician: 'John Doe',
        dateTime: DateTime(2025, 11, 10, 9, 0),
        duration: '2 hours',
        location: 'Makati City',
        status: 'In progress',
      ),
      JobOrder(
        id: 'JO-2025-002',
        clientName: 'XYZ Retail Store',
        jobType: 'Maintenance',
        technician: 'Jane Smith',
        dateTime: DateTime(2025, 11, 10, 11, 30),
        duration: '1.5 hours',
        location: 'Quezon City',
        status: 'Pending',
      ),
    ]);
  }

  void _onAddOrEdit({JobOrder? existing}) async {
    final JobOrder? result = await showDialog<JobOrder>(
      context: context,
      builder: (context) => _JobOrderDialog(order: existing),
    );
    if (result == null) return;

    setState(() {
      if (existing == null) {
        _orders.add(result);
      } else {
        final index = _orders.indexWhere((o) => o.id == existing.id);
        if (index != -1) {
          _orders[index] = result;
        }
      }
    });
  }

  void _onDelete(JobOrder order) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Job Order'),
        content: Text('Are you sure you want to delete ${order.id}?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Delete')),
        ],
      ),
    );
    if (confirmed != true) return;
    setState(() {
      _orders.removeWhere((o) => o.id == order.id);
    });
  }

  List<JobOrder> get _filteredOrders {
    if (_searchQuery.isEmpty) return _orders;
    final q = _searchQuery.toLowerCase();
    return _orders
        .where((o) =>
            o.clientName.toLowerCase().contains(q) ||
            o.technician.toLowerCase().contains(q) ||
            o.id.toLowerCase().contains(q))
        .toList();
  }

  String _formatDateTime(DateTime dt) {
    final mm = dt.month.toString().padLeft(2, '0');
    final dd = dt.day.toString().padLeft(2, '0');
    final yyyy = dt.year.toString();
    final hh = dt.hour.toString().padLeft(2, '0');
    final min = dt.minute.toString().padLeft(2, '0');
    return '$mm/$dd/$yyyy\n$hh:$min';
  }

  @override
  Widget build(BuildContext context) {
    final orders = _filteredOrders;
    return AppShell(
      selectedIndex: 1,
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Text('Job Orders & Scheduling',
                    style: TextStyle(fontSize: 24, fontWeight: FontWeight.w700)),
                const Spacer(),
                OutlinedButton.icon(
                  onPressed: () {},
                  icon: const Icon(Icons.calendar_month_outlined),
                  label: const Text('Calendar View'),
                ),
                const SizedBox(width: 10),
                ElevatedButton.icon(
                  onPressed: () => _onAddOrEdit(),
                  icon: const Icon(Icons.add),
                  label: const Text('Add Job Order'),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Container(
              decoration: _cardDeco(),
              padding: const EdgeInsets.all(14),
              child: Row(
                children: const [
                  Icon(Icons.info_outline, color: Colors.black87),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                        'Manage all job orders here. Use Add to create new jobs, or tap the icons to edit and delete.'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    onChanged: (v) {
                      setState(() => _searchQuery = v);
                    },
                    decoration: InputDecoration(
                      hintText: 'Search by client, technician, or JO number...',
                      prefixIcon: const Icon(Icons.search),
                      filled: true,
                      fillColor: Colors.white,
                      border: OutlineInputBorder(
                        borderSide: BorderSide.none,
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                _filterButton('All Status'),
                const SizedBox(width: 10),
                _filterButton('All Technicians'),
                const SizedBox(width: 10),
                ElevatedButton.icon(
                  onPressed: () {},
                  icon: const Icon(Icons.picture_as_pdf_outlined),
                  label: const Text('Export to PDF'),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Expanded(
              child: Container(
                decoration: _cardDeco(),
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(minWidth: 900),
                    child: SingleChildScrollView(
                      child: DataTable(
                        columns: const [
                          DataColumn(label: Text('JO NUMBER')),
                          DataColumn(label: Text('CLIENT')),
                          DataColumn(label: Text('JOB TYPE / WORK TYPE')),
                          DataColumn(label: Text('TECHNICIAN')),
                          DataColumn(label: Text('DATE & TIME')),
                          DataColumn(label: Text('DURATION')),
                          DataColumn(label: Text('UNITS')),
                          DataColumn(label: Text('LOCATION')),
                          DataColumn(label: Text('STATUS')),
                          DataColumn(label: Text('ACTIONS')),
                        ],
                        rows: orders.map((o) => _dataRow(o)).toList(),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  DataRow _dataRow(JobOrder order) {
    final status = order.status;
    Color badgeColor = const Color(0xFFF2F4F7);
    Color textColor = const Color(0xFF6B7280);
    if (status.toLowerCase() == 'in progress') {
      badgeColor = const Color(0xFFEAEAEA);
      textColor = Colors.black87;
    } else if (status.toLowerCase() == 'completed') {
      badgeColor = const Color(0xFFE0E0E0);
      textColor = Colors.black;
    }
    String unitsText = '';
    if (order.numberOfUnits > 0 && order.unitDescription.isNotEmpty) {
      unitsText = '${order.numberOfUnits} x ${order.unitDescription}';
    } else if (order.numberOfUnits > 0) {
      unitsText = order.numberOfUnits.toString();
    } else if (order.unitDescription.isNotEmpty) {
      unitsText = order.unitDescription;
    }

    return DataRow(
      cells: [
        DataCell(Text(order.id)),
        DataCell(Text(order.clientName)),
        DataCell(Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(order.jobType),
            if (order.workType.isNotEmpty)
              Text(
                order.workType,
                style: const TextStyle(fontSize: 11, color: Colors.black54),
              ),
          ],
        )),
        DataCell(Row(children: [
          const CircleAvatar(radius: 12, child: Text('T')),
          const SizedBox(width: 8),
          Text(order.technician),
        ])),
        DataCell(Text(_formatDateTime(order.dateTime))),
        DataCell(Text(order.duration)),
        DataCell(Text(unitsText.isEmpty ? '-' : unitsText)),
        DataCell(Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(order.location),
            if (order.customerAddress.isNotEmpty)
              Text(
                order.customerAddress,
                style: const TextStyle(fontSize: 11, color: Colors.black54),
              ),
          ],
        )),
        DataCell(Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration:
              BoxDecoration(color: badgeColor, borderRadius: BorderRadius.circular(999)),
          child: Text(status, style: TextStyle(color: textColor, fontSize: 12)),
        )),
        DataCell(Row(
          children: [
            IconButton(
              icon: const Icon(Icons.edit_outlined, size: 18, color: Colors.black87),
              onPressed: () => _onAddOrEdit(existing: order),
            ),
            const SizedBox(width: 4),
            IconButton(
              icon: const Icon(Icons.delete_outline, size: 18, color: Colors.red),
              onPressed: () => _onDelete(order),
            ),
          ],
        )),
      ],
    );
  }

  BoxDecoration _cardDeco() => BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: const [
          BoxShadow(color: Color(0x11000000), blurRadius: 16, offset: Offset(0, 10)),
        ],
      );

  Widget _filterButton(String label) {
    return OutlinedButton.icon(
      onPressed: () {},
      icon: const Icon(Icons.filter_list),
      label: Text(label),
      style: OutlinedButton.styleFrom(
        foregroundColor: Colors.black87,
        side: const BorderSide(color: Color(0xFFE2E8F0)),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        backgroundColor: Colors.white,
      ),
    );
  }
}

class _JobOrderDialog extends StatefulWidget {
  final JobOrder? order;
  const _JobOrderDialog({this.order});

  @override
  State<_JobOrderDialog> createState() => _JobOrderDialogState();
}

class _JobOrderDialogState extends State<_JobOrderDialog> {
  late TextEditingController _idController;
  late TextEditingController _clientController;
  late TextEditingController _jobTypeController;
  late TextEditingController _technicianController;
  late TextEditingController _durationController;
  late TextEditingController _locationController;
  late TextEditingController _unitsController;
  late TextEditingController _unitDescController;
  late TextEditingController _addressController;
  late TextEditingController _contactController;
  late TextEditingController _notesController;
  late TextEditingController _followUpController;
  String _status = 'Pending';
  DateTime _dateTime = DateTime.now();
  String _workType = '';
  String _customerType = '';

  @override
  void initState() {
    super.initState();
    final o = widget.order;
    _idController = TextEditingController(text: o?.id ?? '');
    _clientController = TextEditingController(text: o?.clientName ?? '');
    _jobTypeController = TextEditingController(text: o?.jobType ?? '');
    _technicianController = TextEditingController(text: o?.technician ?? '');
    _durationController = TextEditingController(text: o?.duration ?? '');
    _locationController = TextEditingController(text: o?.location ?? '');
    _unitsController = TextEditingController(text: o?.numberOfUnits == null || o!.numberOfUnits == 0 ? '' : o.numberOfUnits.toString());
    _unitDescController = TextEditingController(text: o?.unitDescription ?? '');
    _addressController = TextEditingController(text: o?.customerAddress ?? '');
    _contactController = TextEditingController(text: o?.customerContact ?? '');
    _notesController = TextEditingController(text: o?.workNotes ?? '');
    _followUpController = TextEditingController(text: o?.followUpSchedule ?? '');
    _status = o?.status ?? 'Pending';
    _dateTime = o?.dateTime ?? DateTime.now();
    _workType = o?.workType ?? '';
    _customerType = o?.customerType ?? '';
  }

  @override
  void dispose() {
    _idController.dispose();
    _clientController.dispose();
    _jobTypeController.dispose();
    _technicianController.dispose();
    _durationController.dispose();
    _locationController.dispose();
    _unitsController.dispose();
    _unitDescController.dispose();
    _addressController.dispose();
    _contactController.dispose();
    _notesController.dispose();
    _followUpController.dispose();
    super.dispose();
  }

  Future<void> _pickDateTime() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _dateTime,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
    );
    if (date == null) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_dateTime),
    );
    if (time == null) return;
    setState(() {
      _dateTime = DateTime(date.year, date.month, date.day, time.hour, time.minute);
    });
  }

  void _submit() {
    if (_idController.text.trim().isEmpty ||
        _clientController.text.trim().isEmpty ||
        _jobTypeController.text.trim().isEmpty) {
      return;
    }
    final order = JobOrder(
      id: _idController.text.trim(),
      clientName: _clientController.text.trim(),
      jobType: _jobTypeController.text.trim(),
      technician: _technicianController.text.trim(),
      dateTime: _dateTime,
      duration: _durationController.text.trim(),
      location: _locationController.text.trim(),
      status: _status,
      workType: _workType,
      customerType: _customerType,
      numberOfUnits: int.tryParse(_unitsController.text.trim()) ?? 0,
      unitDescription: _unitDescController.text.trim(),
      customerAddress: _addressController.text.trim(),
      customerContact: _contactController.text.trim(),
      workNotes: _notesController.text.trim(),
      followUpSchedule: _followUpController.text.trim(),
    );
    Navigator.of(context).pop(order);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.order == null ? 'Add Job Order' : 'Edit Job Order'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _idController,
              decoration: const InputDecoration(labelText: 'JO Number'),
            ),
            TextField(
              controller: _clientController,
              decoration: const InputDecoration(labelText: 'Client Name'),
            ),
            TextField(
              controller: _jobTypeController,
              decoration: const InputDecoration(labelText: 'Job Type'),
            ),
            TextField(
              controller: _technicianController,
              decoration: const InputDecoration(labelText: 'Technician'),
            ),
            TextField(
              controller: _durationController,
              decoration: const InputDecoration(labelText: 'Duration (e.g., 2 hours)'),
            ),
            TextField(
              controller: _locationController,
              decoration: const InputDecoration(labelText: 'Location'),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<String>(
                    value: _workType.isEmpty ? null : _workType,
                    decoration: const InputDecoration(labelText: 'Work Type (Installation / CM / PM)'),
                    items: const [
                      DropdownMenuItem(value: 'Installation', child: Text('Installation')),
                      DropdownMenuItem(value: 'CM', child: Text('CM - Corrective Maintenance')),
                      DropdownMenuItem(value: 'PM', child: Text('PM - Preventive Maintenance')),
                    ],
                    onChanged: (v) => setState(() => _workType = v ?? ''),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: DropdownButtonFormField<String>(
                    value: _customerType.isEmpty ? null : _customerType,
                    decoration: const InputDecoration(labelText: 'Customer Type'),
                    items: const [
                      DropdownMenuItem(value: 'Commercial', child: Text('Commercial')),
                      DropdownMenuItem(value: 'Residential', child: Text('Residential')),
                      DropdownMenuItem(value: 'Industrial', child: Text('Industrial')),
                      DropdownMenuItem(value: 'Other', child: Text('Other')),
                    ],
                    onChanged: (v) => setState(() => _customerType = v ?? ''),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _unitsController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'Number of Units'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: _unitDescController,
                    decoration: const InputDecoration(labelText: 'Unit type (e.g. ACU, Split Wall)'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _addressController,
              decoration: const InputDecoration(labelText: 'Customer Address'),
            ),
            TextField(
              controller: _contactController,
              decoration: const InputDecoration(labelText: 'Customer Contact'),
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
                    DropdownMenuItem(value: 'In progress', child: Text('In progress')),
                    DropdownMenuItem(value: 'Completed', child: Text('Completed')),
                  ],
                  onChanged: (v) {
                    if (v == null) return;
                    setState(() => _status = v);
                  },
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: Text(
                      'Date & Time: ${_dateTime.month.toString().padLeft(2, '0')}/${_dateTime.day.toString().padLeft(2, '0')}/${_dateTime.year} '
                      '${_dateTime.hour.toString().padLeft(2, '0')}:${_dateTime.minute.toString().padLeft(2, '0')}'),
                ),
                TextButton(
                  onPressed: _pickDateTime,
                  child: const Text('Change'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _notesController,
              decoration: const InputDecoration(labelText: 'Work Notes (optional)'),
              maxLines: 2,
            ),
            TextField(
              controller: _followUpController,
              decoration: const InputDecoration(labelText: 'Follow Up Schedule (e.g. February)'),
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




