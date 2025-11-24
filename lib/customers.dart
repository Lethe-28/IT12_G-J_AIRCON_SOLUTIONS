import 'package:flutter/material.dart';
import 'data/app_state.dart';
import 'data/models.dart';
import 'ui_app_shell.dart';
import 'shared/widgets.dart';

class CustomersScreen extends StatefulWidget {
  const CustomersScreen({super.key});

  @override
  State<CustomersScreen> createState() => _CustomersScreenState();
}

class _CustomersScreenState extends State<CustomersScreen> {
  final List<CustomerData> _customers = [];
  String _searchQuery = '';
  String _filterType = 'All';

  bool get _isAdmin => AppState.currentRole == UserRole.admin;

  @override
  void initState() {
    super.initState();
    _seedData();
  }

  void _seedData() {
    _customers.addAll([
      CustomerData(
        id: 1,
        customerType: const CustomerTypeData(id: 1, type: CustomerTypeKind.b2b),
        companyName: 'ABC Corporation',
        firstName: 'John',
        middleName: 'M',
        lastName: 'Doe',
        jobPosition: 'Facilities Manager',
        contactNumber: '+63 912 345 6789',
        unitOrBuilding: 'Unit 5A',
        street: '123 Business Ave',
        subdivisionOrVillage: 'Business Park',
        barangay: 'Makati',
        city: 'Makati City',
        landmark: 'Near SM Makati',
      ),
      CustomerData(
        id: 2,
        customerType: const CustomerTypeData(id: 2, type: CustomerTypeKind.b2c),
        companyName: '',
        firstName: 'Maria',
        middleName: 'C',
        lastName: 'Santos',
        jobPosition: '',
        contactNumber: '+63 917 123 4567',
        unitOrBuilding: 'House #45',
        street: 'Maple Street',
        subdivisionOrVillage: 'Green Valley Subdivision',
        barangay: 'Barangay 1',
        city: 'Quezon City',
        landmark: 'Near the church',
      ),
    ]);
  }

  List<CustomerData> get _filteredCustomers {
    var filtered = _customers;
    
    if (_filterType != 'All') {
      final type = _filterType == 'B2B' ? CustomerTypeKind.b2b : CustomerTypeKind.b2c;
      filtered = filtered.where((c) => c.customerType.type == type).toList();
    }
    
    if (_searchQuery.isNotEmpty) {
      final q = _searchQuery.toLowerCase();
      filtered = filtered.where((c) =>
          c.companyName.toLowerCase().contains(q) ||
          c.firstName.toLowerCase().contains(q) ||
          c.lastName.toLowerCase().contains(q) ||
          c.contactNumber.contains(q) ||
          c.city.toLowerCase().contains(q)).toList();
    }
    
    return filtered;
  }

  void _onAddOrEdit({CustomerData? existing}) async {
    final CustomerData? result = await showDialog<CustomerData>(
      context: context,
      builder: (context) => _CustomerDialog(customer: existing),
    );
    if (result == null) return;

    setState(() {
      if (existing == null) {
        final newId = _customers.isNotEmpty ? _customers.last.id + 1 : 1;
        _customers.add(CustomerData(
          id: newId,
          customerType: result.customerType,
          companyName: result.companyName,
          firstName: result.firstName,
          middleName: result.middleName,
          lastName: result.lastName,
          jobPosition: result.jobPosition,
          contactNumber: result.contactNumber,
          unitOrBuilding: result.unitOrBuilding,
          street: result.street,
          subdivisionOrVillage: result.subdivisionOrVillage,
          barangay: result.barangay,
          city: result.city,
          landmark: result.landmark,
        ));
      } else {
        final index = _customers.indexWhere((c) => c.id == existing.id);
        if (index != -1) {
          _customers[index] = result;
        }
      }
    });
  }

  void _onDelete(CustomerData customer) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Customer'),
        content: Text('Are you sure you want to delete ${customer.companyName.isNotEmpty ? customer.companyName : "${customer.firstName} ${customer.lastName}"}?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Delete')),
        ],
      ),
    );
    if (confirmed != true) return;
    setState(() {
      _customers.removeWhere((c) => c.id == customer.id);
    });
  }

  String _getCustomerDisplayName(CustomerData c) {
    if (c.companyName.isNotEmpty) {
      return c.companyName;
    }
    return '${c.firstName} ${c.middleName.isNotEmpty ? "${c.middleName} " : ""}${c.lastName}'.trim();
  }

  String _getFullAddress(CustomerData c) {
    final parts = <String>[];
    if (c.unitOrBuilding.isNotEmpty) parts.add(c.unitOrBuilding);
    if (c.street.isNotEmpty) parts.add(c.street);
    if (c.subdivisionOrVillage.isNotEmpty) parts.add(c.subdivisionOrVillage);
    if (c.barangay.isNotEmpty) parts.add(c.barangay);
    if (c.city.isNotEmpty) parts.add(c.city);
    return parts.join(', ');
  }

  @override
  Widget build(BuildContext context) {
    final customers = _filteredCustomers;
    final fontSize = _isAdmin ? 14.0 : 16.0;
    final isMobileView = isMobile(context);
    
    return AppShell(
      selectedIndex: 5,
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
                                'Customer Directory',
                                style: TextStyle(
                                  fontSize: isMobileView ? 24 : 28,
                                  fontWeight: FontWeight.w700,
                                  color: AppDesignTokens.gray900,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'View and manage B2B and B2C relationships.',
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
                            child: const Text('Add Customer'),
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
                          child: const Text('Add Customer'),
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
                        child: Column(
                          children: [
                            if (isMobileView) ...[
                              TextField(
                                onChanged: (v) => setState(() => _searchQuery = v),
                                style: TextStyle(fontSize: fontSize),
                                decoration: InputDecoration(
                                  hintText: 'Search by name, company...',
                                  prefixIcon: const Icon(Icons.search),
                                  filled: true,
                                  fillColor: Colors.white,
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: BorderSide.none,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 12),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: const Color(0xFFE2E8F0)),
                                ),
                                child: DropdownButton<String>(
                                  value: _filterType,
                                  underline: const SizedBox(),
                                  isExpanded: true,
                                  items: const [
                                    DropdownMenuItem(value: 'All', child: Text('All Types')),
                                    DropdownMenuItem(value: 'B2B', child: Text('B2B')),
                                    DropdownMenuItem(value: 'B2C', child: Text('B2C')),
                                  ],
                                  onChanged: (v) => setState(() => _filterType = v ?? 'All'),
                                ),
                              ),
                            ] else ...[
                              Row(
                                children: [
                                  Expanded(
                                    child: TextField(
                                      onChanged: (v) => setState(() => _searchQuery = v),
                                      style: TextStyle(fontSize: fontSize),
                                      decoration: InputDecoration(
                                        hintText: 'Search by name, company, contact, or location...',
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
                                  const SizedBox(width: 12),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 12),
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(color: const Color(0xFFE2E8F0)),
                                    ),
                                    child: DropdownButton<String>(
                                      value: _filterType,
                                      underline: const SizedBox(),
                                      items: const [
                                        DropdownMenuItem(value: 'All', child: Text('All Types')),
                                        DropdownMenuItem(value: 'B2B', child: Text('B2B')),
                                        DropdownMenuItem(value: 'B2C', child: Text('B2C')),
                                      ],
                                      onChanged: (v) => setState(() => _filterType = v ?? 'All'),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    if (customers.isEmpty)
                      EmptyState(
                        icon: Icons.people_outline,
                        title: 'No customers found',
                        message: 'Add your first customer to get started.',
                        actionLabel: 'Add Customer',
                        onAction: _isAdmin ? () => _onAddOrEdit() : null,
                      )
                    else if (isMobileView)
                      ...customers.asMap().entries.map((entry) {
                        final index = entry.key;
                        final c = entry.value;
                        return AnimatedCard(
                          delay: Duration(milliseconds: 300 + (index * 50)),
                          child: _buildMobileCard(c),
                        );
                      }).toList()
                    else
                      AnimatedCard(
                        delay: const Duration(milliseconds: 300),
                        child: HoverCard(
                          padding: EdgeInsets.zero,
                          child: SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: DataTable(
                              columns: [
                                DataColumn(label: Text('NAME / COMPANY', style: TextStyle(fontSize: fontSize, fontWeight: FontWeight.w700))),
                                DataColumn(label: Text('TYPE', style: TextStyle(fontSize: fontSize, fontWeight: FontWeight.w700))),
                                DataColumn(label: Text('CONTACT', style: TextStyle(fontSize: fontSize, fontWeight: FontWeight.w700))),
                                DataColumn(label: Text('ADDRESS', style: TextStyle(fontSize: fontSize, fontWeight: FontWeight.w700))),
                                DataColumn(label: Text('ACTIONS', style: TextStyle(fontSize: fontSize, fontWeight: FontWeight.w700))),
                              ],
                              rows: customers.map((c) => _dataRow(c)).toList(),
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
  
  Widget _buildMobileCard(CustomerData c) {
    final typeLabel = c.customerType.type == CustomerTypeKind.b2b ? 'B2B' : 'B2C';
    final typeColor = c.customerType.type == CustomerTypeKind.b2b ? Colors.blue : Colors.green;
    
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
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _getCustomerDisplayName(c),
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                    ),
                    if (c.companyName.isNotEmpty && (c.firstName.isNotEmpty || c.lastName.isNotEmpty))
                      Text(
                        '${c.firstName} ${c.lastName}',
                        style: const TextStyle(fontSize: 14, color: Colors.black54),
                      ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: typeColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  typeLabel,
                  style: TextStyle(fontSize: 12, color: typeColor, fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              const Icon(Icons.phone, size: 16, color: Colors.black54),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  c.contactNumber,
                  style: const TextStyle(fontSize: 14),
                ),
              ),
            ],
          ),
          if (c.jobPosition.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              c.jobPosition,
              style: const TextStyle(fontSize: 12, color: Colors.black54),
            ),
          ],
          const SizedBox(height: 12),
          Row(
            children: [
              const Icon(Icons.location_on, size: 16, color: Colors.black54),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  _getFullAddress(c),
                  style: const TextStyle(fontSize: 12, color: Colors.black54),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          if (_isAdmin) ...[
            const SizedBox(height: 12),
            const Divider(),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton.icon(
                  onPressed: () => _onAddOrEdit(existing: c),
                  icon: const Icon(Icons.edit_outlined, size: 18),
                  label: const Text('Edit'),
                ),
                const SizedBox(width: 8),
                TextButton.icon(
                  onPressed: () => _onDelete(c),
                  icon: const Icon(Icons.delete_outline, size: 18, color: Colors.red),
                  label: const Text('Delete', style: TextStyle(color: Colors.red)),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  DataRow _dataRow(CustomerData c) {
    final fontSize = _isAdmin ? 14.0 : 16.0;
    final typeLabel = c.customerType.type == CustomerTypeKind.b2b ? 'B2B' : 'B2C';
    final typeColor = c.customerType.type == CustomerTypeKind.b2b ? Colors.blue : Colors.green;
    
    return DataRow(
      cells: [
        DataCell(
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(_getCustomerDisplayName(c), style: TextStyle(fontSize: fontSize, fontWeight: FontWeight.w600)),
              if (c.companyName.isNotEmpty && (c.firstName.isNotEmpty || c.lastName.isNotEmpty))
                Text(
                  '${c.firstName} ${c.lastName}',
                  style: TextStyle(fontSize: fontSize - 2, color: Colors.black54),
                ),
            ],
          ),
        ),
        DataCell(
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: typeColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              typeLabel,
              style: TextStyle(fontSize: fontSize - 2, color: typeColor, fontWeight: FontWeight.w600),
            ),
          ),
        ),
        DataCell(
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(c.contactNumber, style: TextStyle(fontSize: fontSize)),
              if (c.jobPosition.isNotEmpty)
                Text(c.jobPosition, style: TextStyle(fontSize: fontSize - 2, color: Colors.black54)),
            ],
          ),
        ),
        DataCell(
          SizedBox(
            width: 300,
            child: Text(
              _getFullAddress(c),
              style: TextStyle(fontSize: fontSize - 1),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ),
        DataCell(
          _isAdmin
              ? Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.edit_outlined, size: 18, color: Colors.black87),
                      onPressed: () => _onAddOrEdit(existing: c),
                    ),
                    const SizedBox(width: 4),
                    IconButton(
                      icon: const Icon(Icons.delete_outline, size: 18, color: Colors.red),
                      onPressed: () => _onDelete(c),
                    ),
                  ],
                )
              : const Text('View only', style: TextStyle(fontSize: 12, color: Colors.black54)),
        ),
      ],
    );
  }

}

class _CustomerDialog extends StatefulWidget {
  final CustomerData? customer;
  const _CustomerDialog({this.customer});

  @override
  State<_CustomerDialog> createState() => _CustomerDialogState();
}

class _CustomerDialogState extends State<_CustomerDialog> {
  late TextEditingController _companyController;
  late TextEditingController _firstNameController;
  late TextEditingController _middleNameController;
  late TextEditingController _lastNameController;
  late TextEditingController _jobPositionController;
  late TextEditingController _contactController;
  late TextEditingController _unitController;
  late TextEditingController _streetController;
  late TextEditingController _subdivisionController;
  late TextEditingController _barangayController;
  late TextEditingController _cityController;
  late TextEditingController _landmarkController;
  CustomerTypeKind _customerType = CustomerTypeKind.b2c;

  @override
  void initState() {
    super.initState();
    final c = widget.customer;
    _companyController = TextEditingController(text: c?.companyName ?? '');
    _firstNameController = TextEditingController(text: c?.firstName ?? '');
    _middleNameController = TextEditingController(text: c?.middleName ?? '');
    _lastNameController = TextEditingController(text: c?.lastName ?? '');
    _jobPositionController = TextEditingController(text: c?.jobPosition ?? '');
    _contactController = TextEditingController(text: c?.contactNumber ?? '');
    _unitController = TextEditingController(text: c?.unitOrBuilding ?? '');
    _streetController = TextEditingController(text: c?.street ?? '');
    _subdivisionController = TextEditingController(text: c?.subdivisionOrVillage ?? '');
    _barangayController = TextEditingController(text: c?.barangay ?? '');
    _cityController = TextEditingController(text: c?.city ?? '');
    _landmarkController = TextEditingController(text: c?.landmark ?? '');
    _customerType = c?.customerType.type ?? CustomerTypeKind.b2c;
  }

  @override
  void dispose() {
    _companyController.dispose();
    _firstNameController.dispose();
    _middleNameController.dispose();
    _lastNameController.dispose();
    _jobPositionController.dispose();
    _contactController.dispose();
    _unitController.dispose();
    _streetController.dispose();
    _subdivisionController.dispose();
    _barangayController.dispose();
    _cityController.dispose();
    _landmarkController.dispose();
    super.dispose();
  }

  void _submit() {
    if (_firstNameController.text.trim().isEmpty || _lastNameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('First name and last name are required')),
      );
      return;
    }

    final customer = CustomerData(
      id: widget.customer?.id ?? 0,
      customerType: CustomerTypeData(id: _customerType == CustomerTypeKind.b2b ? 1 : 2, type: _customerType),
      companyName: _companyController.text.trim(),
      firstName: _firstNameController.text.trim(),
      middleName: _middleNameController.text.trim(),
      lastName: _lastNameController.text.trim(),
      jobPosition: _jobPositionController.text.trim(),
      contactNumber: _contactController.text.trim(),
      unitOrBuilding: _unitController.text.trim(),
      street: _streetController.text.trim(),
      subdivisionOrVillage: _subdivisionController.text.trim(),
      barangay: _barangayController.text.trim(),
      city: _cityController.text.trim(),
      landmark: _landmarkController.text.trim(),
    );
    Navigator.of(context).pop(customer);
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: Container(
        width: 600,
        padding: const EdgeInsets.all(24),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.customer == null ? 'Add Customer' : 'Edit Customer',
                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 20),
              DropdownButtonFormField<CustomerTypeKind>(
                value: _customerType,
                decoration: const InputDecoration(labelText: 'Customer Type *'),
                items: const [
                  DropdownMenuItem(value: CustomerTypeKind.b2b, child: Text('B2B - Business to Business')),
                  DropdownMenuItem(value: CustomerTypeKind.b2c, child: Text('B2C - Business to Customer')),
                ],
                onChanged: (v) => setState(() => _customerType = v ?? CustomerTypeKind.b2c),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _companyController,
                decoration: const InputDecoration(
                  labelText: 'Company Name (for B2B)',
                  hintText: 'Leave empty for B2C customers',
                ),
              ),
              const SizedBox(height: 12),
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
                controller: _jobPositionController,
                decoration: const InputDecoration(labelText: 'Job Position (for B2B)'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _contactController,
                decoration: const InputDecoration(labelText: 'Contact Number *'),
                keyboardType: TextInputType.phone,
              ),
              const SizedBox(height: 20),
              const Text('Address Information', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
              const SizedBox(height: 12),
              TextField(
                controller: _unitController,
                decoration: const InputDecoration(labelText: 'Unit/Building/House #'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _streetController,
                decoration: const InputDecoration(labelText: 'Street'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _subdivisionController,
                decoration: const InputDecoration(labelText: 'Subdivision/Village'),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _barangayController,
                      decoration: const InputDecoration(labelText: 'Barangay'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      controller: _cityController,
                      decoration: const InputDecoration(labelText: 'City'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _landmarkController,
                decoration: const InputDecoration(labelText: 'Landmark'),
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

