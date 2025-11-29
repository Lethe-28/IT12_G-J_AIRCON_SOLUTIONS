import 'package:flutter/material.dart';
import 'data/app_state.dart';
import 'data/models.dart';
import 'ui_app_shell.dart';
import 'shared/widgets.dart';

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
    final isMobileView = isMobile(context);

    return AppShell(
      selectedIndex: 6,
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [AppDesignTokens.gray50, Colors.white],
          ),
        ),
        child: Column(
          children: [
            AnimatedCard(
              delay: const Duration(milliseconds: 100),
              child: Container(
                padding: EdgeInsets.all(isMobileView ? 16 : 24),
                decoration: BoxDecoration(
                  color: Colors.white,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 10,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Technician Roster',
                                style: TextStyle(
                                  fontSize: isMobileView ? 24 : 28,
                                  fontWeight: FontWeight.w700,
                                  color: AppDesignTokens.gray900,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Track deployment-ready specialists and contact info.',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: AppDesignTokens.gray500,
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (!isMobileView && _isAdmin)
                          AnimatedButton(
                            onPressed: () => _onAddOrEdit(),
                            icon: Icons.add,
                            backgroundColor: AppDesignTokens.primary,
                            foregroundColor: Colors.white,
                            child: const Text('Add Technician'),
                          ),
                      ],
                    ),
                    if (isMobileView && _isAdmin) ...[
                      const SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        child: AnimatedButton(
                          onPressed: () => _onAddOrEdit(),
                          icon: Icons.add,
                          backgroundColor: AppDesignTokens.primary,
                          foregroundColor: Colors.white,
                          child: const Text('Add Technician'),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: EdgeInsets.all(isMobileView ? 16 : 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    AnimatedCard(
                      delay: const Duration(milliseconds: 200),
                      child: HoverCard(
                        padding: EdgeInsets.zero,
                        child: TextField(
                          onChanged: (v) => setState(() => _searchQuery = v),
                          style: TextStyle(fontSize: fontSize),
                          decoration: InputDecoration(
                            hintText: 'Search by name or contact number...',
                            prefixIcon: const Icon(Icons.search),
                            filled: true,
                            fillColor: Colors.white,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide.none,
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    if (technicians.isEmpty)
                      EmptyState(
                        icon: Icons.engineering_outlined,
                        title: 'No technicians found',
                        message: 'Add your first technician to get started.',
                        actionLabel: 'Add Technician',
                        onAction: _isAdmin ? () => _onAddOrEdit() : null,
                      )
                    else if (isMobileView)
                      ...technicians.asMap().entries.map((entry) {
                        final index = entry.key;
                        final t = entry.value;
                        return AnimatedCard(
                          delay: Duration(milliseconds: 300 + (index * 50)),
                          child: _buildMobileCard(t),
                        );
                      })
                    else
                      AnimatedCard(
                        delay: const Duration(milliseconds: 300),
                        child: HoverCard(
                          padding: EdgeInsets.zero,
                          child: SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
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
      ),
    );
  }
  
  Widget _buildMobileCard(TechnicianData t) {
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
      child: Row(
        children: [
          CircleAvatar(
            radius: 24,
            backgroundColor: AppDesignTokens.primary.withOpacity(0.1),
            child: Text(
              '${t.firstName[0]}${t.lastName[0]}',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: AppDesignTokens.primary,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _getFullName(t),
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    const Icon(Icons.phone, size: 14, color: Colors.black54),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        t.contactNumber,
                        style: const TextStyle(fontSize: 14, color: Colors.black54),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          if (_isAdmin)
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: const Icon(Icons.edit_outlined, size: 18),
                  onPressed: () => _onAddOrEdit(existing: t),
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline, size: 18, color: Colors.red),
                  onPressed: () => _onDelete(t),
                ),
              ],
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

