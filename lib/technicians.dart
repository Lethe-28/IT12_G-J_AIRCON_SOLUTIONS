import 'package:flutter/material.dart';
import 'data/app_state.dart';
import 'data/models.dart';
import 'ui_app_shell.dart';
import 'shared_header.dart';

class TechniciansScreen extends StatefulWidget {
  const TechniciansScreen({super.key});

  @override
  State<TechniciansScreen> createState() => _TechniciansScreenState();
}

class _TechniciansScreenState extends State<TechniciansScreen> {
  final List<TechnicianData> _technicians = [];
  String _searchQuery = '';

  bool get _isAdmin => AppState.currentRole == UserRole.admin;

  @override
  void initState() {
    super.initState();
    _seedData();
  }

  void _seedData() {
    _technicians.addAll([
      const TechnicianData(
        id: 1,
        firstName: 'John',
        middleName: 'M',
        lastName: 'Doe',
        contactNumber: '+63 912 345 6789',
      ),
      const TechnicianData(
        id: 2,
        firstName: 'Jane',
        middleName: 'A',
        lastName: 'Smith',
        contactNumber: '+63 917 123 4567',
      ),
      const TechnicianData(
        id: 3,
        firstName: 'Mike',
        middleName: 'B',
        lastName: 'Johnson',
        contactNumber: '+63 918 987 6543',
      ),
    ]);
  }

  List<TechnicianData> get _filteredTechnicians {
    if (_searchQuery.isEmpty) return _technicians;
    final q = _searchQuery.toLowerCase();
    return _technicians
        .where((t) =>
            t.firstName.toLowerCase().contains(q) ||
            t.lastName.toLowerCase().contains(q) ||
            t.contactNumber.contains(q))
        .toList();
  }

  void _onAddOrEdit({TechnicianData? existing}) async {
    final TechnicianData? result = await showDialog<TechnicianData>(
      context: context,
      builder: (context) => _TechnicianDialog(technician: existing),
    );
    if (result == null) return;

    setState(() {
      if (existing == null) {
        final newId = _technicians.isNotEmpty ? _technicians.last.id + 1 : 1;
        _technicians.add(TechnicianData(
          id: newId,
          firstName: result.firstName,
          middleName: result.middleName,
          lastName: result.lastName,
          contactNumber: result.contactNumber,
        ));
      } else {
        final index = _technicians.indexWhere((t) => t.id == existing.id);
        if (index != -1) {
          _technicians[index] = result;
        }
      }
    });
  }

  void _onDelete(TechnicianData technician) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Technician'),
        content: Text('Are you sure you want to delete ${technician.firstName} ${technician.lastName}?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Delete')),
        ],
      ),
    );
    if (confirmed != true) return;
    setState(() {
      _technicians.removeWhere((t) => t.id == technician.id);
    });
  }

  String _getFullName(TechnicianData t) {
    return '${t.firstName} ${t.middleName.isNotEmpty ? "${t.middleName} " : ""}${t.lastName}'.trim();
  }

  @override
  Widget build(BuildContext context) {
    final technicians = _filteredTechnicians;
    final fontSize = _isAdmin ? 14.0 : 16.0;

    return AppShell(
      selectedIndex: 6,
      body: Column(
        children: [
          SharedHeader(
            welcomeText: 'Technician Roster',
            subtitleText: 'Track deployment-ready specialists and contact info.',
            notificationCount: 0,
            showGreeting: false,
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: EdgeInsets.all(_isAdmin ? 20 : 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        'Technician Management',
                        style: TextStyle(fontSize: _isAdmin ? 24 : 28, fontWeight: FontWeight.w700),
                      ),
                      const Spacer(),
                      if (_isAdmin)
                        ElevatedButton.icon(
                          onPressed: () => _onAddOrEdit(),
                          icon: const Icon(Icons.add),
                          label: const Text('Add Technician'),
                        ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    onChanged: (v) => setState(() => _searchQuery = v),
                    style: TextStyle(fontSize: fontSize),
                    decoration: InputDecoration(
                      hintText: 'Search by name or contact number...',
                      prefixIcon: const Icon(Icons.search),
                      filled: true,
                      fillColor: Colors.white,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Container(
                    decoration: _cardDeco(),
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(minWidth: 800),
                        child: DataTable(
                          columns: [
                            DataColumn(label: Text('NAME', style: TextStyle(fontSize: fontSize, fontWeight: FontWeight.w700))),
                            DataColumn(label: Text('CONTACT NUMBER', style: TextStyle(fontSize: fontSize, fontWeight: FontWeight.w700))),
                            DataColumn(label: Text('ACTIONS', style: TextStyle(fontSize: fontSize, fontWeight: FontWeight.w700))),
                          ],
                          rows: technicians.map((t) => _dataRow(t)).toList(),
                        ),
                      ),
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

  DataRow _dataRow(TechnicianData t) {
    final fontSize = _isAdmin ? 14.0 : 16.0;
    return DataRow(
      cells: [
        DataCell(
          Row(
            children: [
              CircleAvatar(
                radius: 18,
                backgroundColor: const Color(0xFFEAF2FF),
                child: Text(
                  '${t.firstName[0]}${t.lastName[0]}',
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                ),
              ),
              const SizedBox(width: 12),
              Text(_getFullName(t), style: TextStyle(fontSize: fontSize, fontWeight: FontWeight.w600)),
            ],
          ),
        ),
        DataCell(Text(t.contactNumber, style: TextStyle(fontSize: fontSize))),
        DataCell(
          _isAdmin
              ? Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.edit_outlined, size: 18, color: Colors.black87),
                      onPressed: () => _onAddOrEdit(existing: t),
                    ),
                    const SizedBox(width: 4),
                    IconButton(
                      icon: const Icon(Icons.delete_outline, size: 18, color: Colors.red),
                      onPressed: () => _onDelete(t),
                    ),
                  ],
                )
              : const Text('View only', style: TextStyle(fontSize: 12, color: Colors.black54)),
        ),
      ],
    );
  }

  BoxDecoration _cardDeco() => BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      );
}

class _TechnicianDialog extends StatefulWidget {
  final TechnicianData? technician;
  const _TechnicianDialog({this.technician});

  @override
  State<_TechnicianDialog> createState() => _TechnicianDialogState();
}

class _TechnicianDialogState extends State<_TechnicianDialog> {
  late TextEditingController _firstNameController;
  late TextEditingController _middleNameController;
  late TextEditingController _lastNameController;
  late TextEditingController _contactController;

  @override
  void initState() {
    super.initState();
    final t = widget.technician;
    _firstNameController = TextEditingController(text: t?.firstName ?? '');
    _middleNameController = TextEditingController(text: t?.middleName ?? '');
    _lastNameController = TextEditingController(text: t?.lastName ?? '');
    _contactController = TextEditingController(text: t?.contactNumber ?? '');
  }

  @override
  void dispose() {
    _firstNameController.dispose();
    _middleNameController.dispose();
    _lastNameController.dispose();
    _contactController.dispose();
    super.dispose();
  }

  void _submit() {
    if (_firstNameController.text.trim().isEmpty || _lastNameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('First name and last name are required')),
      );
      return;
    }

    final technician = TechnicianData(
      id: widget.technician?.id ?? 0,
      firstName: _firstNameController.text.trim(),
      middleName: _middleNameController.text.trim(),
      lastName: _lastNameController.text.trim(),
      contactNumber: _contactController.text.trim(),
    );
    Navigator.of(context).pop(technician);
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: Container(
        width: 500,
        padding: const EdgeInsets.all(24),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.technician == null ? 'Add Technician' : 'Edit Technician',
                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _firstNameController,
                      decoration: const InputDecoration(labelText: 'First Name *'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      controller: _middleNameController,
                      decoration: const InputDecoration(labelText: 'Middle Name'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      controller: _lastNameController,
                      decoration: const InputDecoration(labelText: 'Last Name *'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _contactController,
                decoration: const InputDecoration(labelText: 'Contact Number *'),
                keyboardType: TextInputType.phone,
              ),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Cancel'),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton(
                    onPressed: _submit,
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

