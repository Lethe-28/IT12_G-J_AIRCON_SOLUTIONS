import 'package:flutter/material.dart';
import 'data/app_state.dart';
import 'data/models.dart';
import 'ui_app_shell.dart';
import 'shared_header.dart';

class AirconsScreen extends StatefulWidget {
  const AirconsScreen({super.key});

  @override
  State<AirconsScreen> createState() => _AirconsScreenState();
}

class _AirconsScreenState extends State<AirconsScreen> {
  final List<AirconData> _aircons = [];
  final List<BrandData> _brands = [];
  final List<AirconTypeData> _airconTypes = [];
  final List<CustomerData> _customers = [];
  String _searchQuery = '';
  int? _filterCustomerId;

  bool get _isAdmin => AppState.currentRole == UserRole.admin;

  @override
  void initState() {
    super.initState();
    _seedData();
  }

  void _seedData() {
    // Seed brands
    _brands.addAll([
      const BrandData(id: 1, name: 'Daikin'),
      const BrandData(id: 2, name: 'Carrier'),
      const BrandData(id: 3, name: 'Panasonic'),
      const BrandData(id: 4, name: 'LG'),
      const BrandData(id: 5, name: 'Samsung'),
    ]);

    // Seed aircon types
    _airconTypes.addAll([
      const AirconTypeData(id: 1, typeName: 'Split Type'),
      const AirconTypeData(id: 2, typeName: 'Window Type'),
      const AirconTypeData(id: 3, typeName: 'Centralized'),
      const AirconTypeData(id: 4, typeName: 'Portable'),
    ]);

    // Seed customers
    _customers.addAll([
      CustomerData(
        id: 1,
        customerType: const CustomerTypeData(id: 1, type: CustomerTypeKind.b2b),
        companyName: 'ABC Corporation',
        firstName: 'John',
        middleName: '',
        lastName: 'Doe',
        jobPosition: '',
        contactNumber: '',
        unitOrBuilding: '',
        street: '',
        subdivisionOrVillage: '',
        barangay: '',
        city: '',
        landmark: '',
      ),
      CustomerData(
        id: 2,
        customerType: const CustomerTypeData(id: 2, type: CustomerTypeKind.b2c),
        companyName: '',
        firstName: 'Maria',
        middleName: '',
        lastName: 'Santos',
        jobPosition: '',
        contactNumber: '',
        unitOrBuilding: '',
        street: '',
        subdivisionOrVillage: '',
        barangay: '',
        city: '',
        landmark: '',
      ),
    ]);

    // Seed aircons
    _aircons.addAll([
      AirconData(
        id: 1,
        brand: _brands[0],
        airconType: _airconTypes[0],
        customer: _customers[0],
        remarks: 'Main office unit, 3rd floor',
      ),
      AirconData(
        id: 2,
        brand: _brands[1],
        airconType: _airconTypes[1],
        customer: _customers[1],
        remarks: 'Living room unit',
      ),
    ]);
  }

  List<AirconData> get _filteredAircons {
    var filtered = _aircons;

    if (_filterCustomerId != null) {
      filtered = filtered.where((a) => a.customer.id == _filterCustomerId).toList();
    }

    if (_searchQuery.isNotEmpty) {
      final q = _searchQuery.toLowerCase();
      filtered = filtered.where((a) =>
          a.brand.name.toLowerCase().contains(q) ||
          a.airconType.typeName.toLowerCase().contains(q) ||
          a.remarks.toLowerCase().contains(q) ||
          (a.customer.companyName.isNotEmpty ? a.customer.companyName.toLowerCase() : '${a.customer.firstName} ${a.customer.lastName}'.toLowerCase()).contains(q)).toList();
    }

    return filtered;
  }

  void _onAddOrEdit({AirconData? existing}) async {
    final AirconData? result = await showDialog<AirconData>(
      context: context,
      builder: (context) => _AirconDialog(
        aircon: existing,
        brands: _brands,
        airconTypes: _airconTypes,
        customers: _customers,
      ),
    );
    if (result == null) return;

    setState(() {
      if (existing == null) {
        final newId = _aircons.isNotEmpty ? _aircons.last.id + 1 : 1;
        _aircons.add(AirconData(
          id: newId,
          brand: result.brand,
          airconType: result.airconType,
          customer: result.customer,
          remarks: result.remarks,
        ));
      } else {
        final index = _aircons.indexWhere((a) => a.id == existing.id);
        if (index != -1) {
          _aircons[index] = result;
        }
      }
    });
  }

  void _onDelete(AirconData aircon) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Aircon Unit'),
        content: Text('Are you sure you want to delete this ${aircon.brand.name} ${aircon.airconType.typeName} unit?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Delete')),
        ],
      ),
    );
    if (confirmed != true) return;
    setState(() {
      _aircons.removeWhere((a) => a.id == aircon.id);
    });
  }

  String _getCustomerName(CustomerData c) {
    if (c.companyName.isNotEmpty) return c.companyName;
    return '${c.firstName} ${c.lastName}';
  }

  @override
  Widget build(BuildContext context) {
    final aircons = _filteredAircons;
    final fontSize = _isAdmin ? 14.0 : 16.0;

    return AppShell(
      selectedIndex: 7,
      body: Column(
        children: [
          SharedHeader(
            welcomeText: 'Aircon Assets',
            subtitleText: 'Map customer equipment, locations, and notes.',
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
                        'Aircon Unit Management',
                        style: TextStyle(fontSize: _isAdmin ? 24 : 28, fontWeight: FontWeight.w700),
                      ),
                      const Spacer(),
                      if (_isAdmin)
                        ElevatedButton.icon(
                          onPressed: () => _onAddOrEdit(),
                          icon: const Icon(Icons.add),
                          label: const Text('Add Aircon Unit'),
                        ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          onChanged: (v) => setState(() => _searchQuery = v),
                          style: TextStyle(fontSize: fontSize),
                          decoration: InputDecoration(
                            hintText: 'Search by brand, type, customer, or remarks...',
                            prefixIcon: const Icon(Icons.search),
                            filled: true,
                            fillColor: Colors.white,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
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
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                        ),
                        child: DropdownButton<int?>(
                          value: _filterCustomerId,
                          underline: const SizedBox(),
                          hint: const Text('Filter by Customer'),
                          items: [
                            const DropdownMenuItem<int?>(value: null, child: Text('All Customers')),
                            ..._customers.map((c) => DropdownMenuItem<int?>(
                                  value: c.id,
                                  child: Text(_getCustomerName(c)),
                                )),
                          ],
                          onChanged: (v) => setState(() => _filterCustomerId = v),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Container(
                    decoration: _cardDeco(),
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(minWidth: 1000),
                        child: DataTable(
                          columns: [
                            DataColumn(label: Text('BRAND', style: TextStyle(fontSize: fontSize, fontWeight: FontWeight.w700))),
                            DataColumn(label: Text('TYPE', style: TextStyle(fontSize: fontSize, fontWeight: FontWeight.w700))),
                            DataColumn(label: Text('CUSTOMER', style: TextStyle(fontSize: fontSize, fontWeight: FontWeight.w700))),
                            DataColumn(label: Text('REMARKS', style: TextStyle(fontSize: fontSize, fontWeight: FontWeight.w700))),
                            DataColumn(label: Text('ACTIONS', style: TextStyle(fontSize: fontSize, fontWeight: FontWeight.w700))),
                          ],
                          rows: aircons.map((a) => _dataRow(a)).toList(),
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

  DataRow _dataRow(AirconData a) {
    final fontSize = _isAdmin ? 14.0 : 16.0;
    return DataRow(
      cells: [
        DataCell(Text(a.brand.name, style: TextStyle(fontSize: fontSize, fontWeight: FontWeight.w600))),
        DataCell(Text(a.airconType.typeName, style: TextStyle(fontSize: fontSize))),
        DataCell(Text(_getCustomerName(a.customer), style: TextStyle(fontSize: fontSize))),
        DataCell(
          SizedBox(
            width: 250,
            child: Text(
              a.remarks,
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
                      onPressed: () => _onAddOrEdit(existing: a),
                    ),
                    const SizedBox(width: 4),
                    IconButton(
                      icon: const Icon(Icons.delete_outline, size: 18, color: Colors.red),
                      onPressed: () => _onDelete(a),
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

class _AirconDialog extends StatefulWidget {
  final AirconData? aircon;
  final List<BrandData> brands;
  final List<AirconTypeData> airconTypes;
  final List<CustomerData> customers;

  const _AirconDialog({
    this.aircon,
    required this.brands,
    required this.airconTypes,
    required this.customers,
  });

  @override
  State<_AirconDialog> createState() => _AirconDialogState();
}

class _AirconDialogState extends State<_AirconDialog> {
  late BrandData _selectedBrand;
  late AirconTypeData _selectedType;
  late CustomerData _selectedCustomer;
  late TextEditingController _remarksController;

  @override
  void initState() {
    super.initState();
    final a = widget.aircon;
    _selectedBrand = a?.brand ?? widget.brands.first;
    _selectedType = a?.airconType ?? widget.airconTypes.first;
    _selectedCustomer = a?.customer ?? widget.customers.first;
    _remarksController = TextEditingController(text: a?.remarks ?? '');
  }

  @override
  void dispose() {
    _remarksController.dispose();
    super.dispose();
  }

  void _submit() {
    final aircon = AirconData(
      id: widget.aircon?.id ?? 0,
      brand: _selectedBrand,
      airconType: _selectedType,
      customer: _selectedCustomer,
      remarks: _remarksController.text.trim(),
    );
    Navigator.of(context).pop(aircon);
  }

  String _getCustomerName(CustomerData c) {
    if (c.companyName.isNotEmpty) return c.companyName;
    return '${c.firstName} ${c.lastName}';
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
                widget.aircon == null ? 'Add Aircon Unit' : 'Edit Aircon Unit',
                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 20),
              DropdownButtonFormField<BrandData>(
                value: _selectedBrand,
                decoration: const InputDecoration(labelText: 'Brand *'),
                items: widget.brands
                    .map((b) => DropdownMenuItem(value: b, child: Text(b.name)))
                    .toList(),
                onChanged: (v) => setState(() => _selectedBrand = v ?? widget.brands.first),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<AirconTypeData>(
                value: _selectedType,
                decoration: const InputDecoration(labelText: 'Aircon Type *'),
                items: widget.airconTypes
                    .map((t) => DropdownMenuItem(value: t, child: Text(t.typeName)))
                    .toList(),
                onChanged: (v) => setState(() => _selectedType = v ?? widget.airconTypes.first),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<CustomerData>(
                value: _selectedCustomer,
                decoration: const InputDecoration(labelText: 'Customer *'),
                items: widget.customers
                    .map((c) => DropdownMenuItem(value: c, child: Text(_getCustomerName(c))))
                    .toList(),
                onChanged: (v) => setState(() => _selectedCustomer = v ?? widget.customers.first),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _remarksController,
                decoration: const InputDecoration(labelText: 'Remarks / Location'),
                maxLines: 3,
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

