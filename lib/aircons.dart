import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'ui_app_shell.dart';
import 'shared/widgets.dart'; // Assumes EmptyState, AnimatedCard, etc.

class AirconsScreen extends StatefulWidget {
  const AirconsScreen({super.key});

  @override
  State<AirconsScreen> createState() => _AirconsScreenState();
}

class _AirconsScreenState extends State<AirconsScreen> {
  final _supabase = Supabase.instance.client;
  bool _isLoading = true;

  // Main Data
  List<AirconUnit> _aircons = [];

  // Reference Data (for filters & dialogs)
  List<Map<String, dynamic>> _brands = [];
  List<Map<String, dynamic>> _types = [];
  List<Map<String, dynamic>> _customers = [];

  // Filter State
  String _searchQuery = '';
  int? _filterTypeId; // CHANGED: Now filtering by Type ID

  @override
  void initState() {
    super.initState();
    _fetchData();
  }

  Future<void> _fetchData() async {
    setState(() => _isLoading = true);
    try {
      // 1. Fetch Aircons with Relations (ONLY ACTIVE)
      final airconsRes = await _supabase
          .from('aircons')
          .select(
            '*, brands(brand_name), aircon_types(type_name), customers(first_name, last_name, company_name)',
          )
          .eq('is_active', true)
          .order('id', ascending: false);

      // 2. Fetch Reference Data
      final brandsRes = await _supabase
          .from('brands')
          .select()
          .order('brand_name');
      final typesRes = await _supabase
          .from('aircon_types')
          .select()
          .order('type_name');
      final custRes = await _supabase
          .from('customers')
          .select('id, first_name, last_name, company_name')
          .eq('is_active', true)
          .order('last_name');

      final List<AirconUnit> loaded = [];
      for (var row in airconsRes) {
        loaded.add(AirconUnit.fromMap(row));
      }

      if (mounted) {
        setState(() {
          _aircons = loaded;
          _brands = List<Map<String, dynamic>>.from(brandsRes);
          _types = List<Map<String, dynamic>>.from(typesRes);
          _customers = List<Map<String, dynamic>>.from(custRes);
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error fetching data: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading data: $e'),
            backgroundColor: Colors.red,
          ),
        );
        setState(() => _isLoading = false);
      }
    }
  }

  // --- CRUD ACTIONS ---

  Future<void> _onAddOrEdit({AirconUnit? existing}) async {
    final bool? result = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _AirconDialog(
        unit: existing,
        brands: _brands,
        types: _types,
        customers: _customers,
      ),
    );

    if (result == true) {
      _fetchData(); // Refresh list to get new brands/types/units
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(existing == null ? 'Unit Added' : 'Unit Updated'),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  // --- ARCHIVE LOGIC ---
  Future<void> _onArchive(AirconUnit unit) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Archive Unit'),
        content: Text(
          'Are you sure you want to archive this ${unit.brand} ${unit.type}?\n\n'
          'It will be hidden from this list, but previous service history will be preserved.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.orange),
            child: const Text('Archive'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await _supabase
            .from('aircons')
            .update({'is_active': false})
            .eq('id', unit.id);
        setState(() {
          _aircons.removeWhere((a) => a.id == unit.id);
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Unit archived'),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Archive failed: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  // --- FILTER LOGIC ---
  List<AirconUnit> get _filteredAircons {
    var filtered = _aircons;

    // CHANGED: Filter by Type ID instead of Customer ID
    if (_filterTypeId != null) {
      filtered = filtered.where((a) => a.typeId == _filterTypeId).toList();
    }

    // Filter by Search Text (Brand, Customer, Remarks)
    if (_searchQuery.isNotEmpty) {
      final q = _searchQuery.toLowerCase();
      filtered = filtered.where((a) {
        return a.brand.toLowerCase().contains(q) ||
            a.type.toLowerCase().contains(q) ||
            a.customerName.toLowerCase().contains(q) ||
            (a.remarks ?? '').toLowerCase().contains(q);
      }).toList();
    }

    return filtered;
  }

  @override
  Widget build(BuildContext context) {
    final filteredList = _filteredAircons;
    final isMobileView = MediaQuery.of(context).size.width < 800;

    return AppShell(
      selectedIndex: 7,
      floatingActionButton: isMobileView
          ? FloatingActionButton(
              onPressed: () => _onAddOrEdit(),
              backgroundColor: Colors.purple,
              foregroundColor: Colors.white,
              child: const Icon(Icons.add),
            )
          : null,

      body: Container(
        color: const Color(0xFFF8FAFC),
        child: Column(
          children: [
            // --- HEADER ---
            Container(
              padding: const EdgeInsets.all(24),
              color: Colors.white,
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Aircon Units',
                            style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          SizedBox(height: 4),
                          Text(
                            'Manage customer assets and specifications.',
                            style: TextStyle(color: Colors.grey),
                          ),
                        ],
                      ),
                      if (!isMobileView)
                        ElevatedButton.icon(
                          onPressed: () => _onAddOrEdit(),
                          icon: const Icon(Icons.add),
                          label: const Text('Add Unit'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.purple,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 20,
                              vertical: 16,
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 24),

                  // Filter Row
                  Row(
                    children: [
                      // SEARCH FIELD
                      Expanded(
                        flex: 2,
                        child: TextField(
                          onChanged: (v) => setState(() => _searchQuery = v),
                          decoration: InputDecoration(
                            hintText: 'Search units...',
                            prefixIcon: const Icon(Icons.search),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide.none,
                            ),
                            filled: true,
                            fillColor: Colors.grey[100],
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 14,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),

                      // TYPE DROPDOWN (Replaced Customer Dropdown)
                      Expanded(
                        flex: 1,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          decoration: BoxDecoration(
                            color: Colors.grey[100],
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton<int?>(
                              value: _filterTypeId,
                              hint: const Text("All Types"),
                              isExpanded: true,
                              items: [
                                const DropdownMenuItem(
                                  value: null,
                                  child: Text("All Types"),
                                ),
                                // Map Types from DB to Dropdown Items
                                ..._types.map(
                                  (t) => DropdownMenuItem(
                                    value: t['id'] as int,
                                    child: Text(
                                      t['type_name'],
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ),
                              ],
                              onChanged: (v) =>
                                  setState(() => _filterTypeId = v),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const Divider(height: 1),

            // --- LIST CONTENT ---
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : filteredList.isEmpty
                  ? const Center(
                      child: EmptyState(
                        icon: Icons.ac_unit,
                        title: 'No units found',
                        message: 'Try adjusting filters or add a new unit.',
                      ),
                    )
                  : isMobileView
                  ? ListView.separated(
                      padding: const EdgeInsets.all(16),
                      itemCount: filteredList.length,
                      separatorBuilder: (ctx, i) => const SizedBox(height: 12),
                      itemBuilder: (ctx, i) => _MobileAirconCard(
                        unit: filteredList[i],
                        onEdit: () => _onAddOrEdit(existing: filteredList[i]),
                        onDelete: () => _onArchive(filteredList[i]),
                      ),
                    )
                  : SingleChildScrollView(
                      padding: const EdgeInsets.all(24),
                      child: _DesktopAirconTable(
                        units: filteredList,
                        onEdit: (u) => _onAddOrEdit(existing: u),
                        onDelete: (u) => _onArchive(u),
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

// --- DESKTOP TABLE ---
class _DesktopAirconTable extends StatelessWidget {
  final List<AirconUnit> units;
  final Function(AirconUnit) onEdit;
  final Function(AirconUnit) onDelete;

  const _DesktopAirconTable({
    required this.units,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: DataTable(
        headingRowColor: WidgetStateProperty.all(Colors.grey[50]),
        columns: const [
          DataColumn(
            label: Text(
              'UNIT DETAILS',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          DataColumn(
            label: Text('TYPE', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
          DataColumn(
            label: Text('OWNER', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
          DataColumn(
            label: Text(
              'LOCATION / REMARKS',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          DataColumn(
            label: Text(
              'ACTIONS',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        ],
        rows: units.map((u) {
          return DataRow(
            cells: [
              DataCell(
                Row(
                  children: [
                    CircleAvatar(
                      radius: 18,
                      backgroundColor: Colors.purple[50],
                      child: const Icon(
                        Icons.ac_unit,
                        size: 16,
                        color: Colors.purple,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      u.brand,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
              DataCell(
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.purple[50],
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: Colors.purple[100]!),
                  ),
                  child: Text(
                    u.type,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: Colors.purple[800],
                    ),
                  ),
                ),
              ),
              DataCell(Text(u.customerName)),
              DataCell(
                SizedBox(
                  width: 250,
                  child: Text(
                    u.remarks ?? '-',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
              DataCell(
                Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.edit_outlined, color: Colors.blue),
                      onPressed: () => onEdit(u),
                      tooltip: "Edit",
                    ),
                    IconButton(
                      icon: const Icon(
                        Icons.archive_outlined,
                        color: Colors.orange,
                      ), // Changed Icon
                      onPressed: () => onDelete(u),
                      tooltip: "Archive", // Changed Tooltip
                    ),
                  ],
                ),
              ),
            ],
          );
        }).toList(),
      ),
    );
  }
}

// --- MOBILE CARD ---
class _MobileAirconCard extends StatelessWidget {
  final AirconUnit unit;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _MobileAirconCard({
    required this.unit,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.purple[50],
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.ac_unit,
                  color: Colors.purple,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      unit.brand,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      unit.type,
                      style: const TextStyle(
                        fontSize: 13,
                        color: Colors.purple,
                      ),
                    ),
                  ],
                ),
              ),
              PopupMenuButton<String>(
                icon: const Icon(Icons.more_vert, color: Colors.grey),
                onSelected: (value) {
                  if (value == 'edit') onEdit();
                  if (value == 'archive') onDelete();
                },
                itemBuilder: (context) => [
                  const PopupMenuItem(value: 'edit', child: Text('Edit')),
                  const PopupMenuItem(
                    value: 'archive',
                    child: Text(
                      'Archive',
                      style: TextStyle(color: Colors.orange),
                    ), // Changed Text
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Divider(),
          const SizedBox(height: 8),
          Row(
            children: [
              const Icon(Icons.person_outline, size: 16, color: Colors.grey),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  unit.customerName,
                  style: const TextStyle(fontWeight: FontWeight.w500),
                ),
              ),
            ],
          ),
          if (unit.remarks != null && unit.remarks!.isNotEmpty) ...[
            const SizedBox(height: 4),
            Row(
              children: [
                const Icon(
                  Icons.location_on_outlined,
                  size: 16,
                  color: Colors.grey,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    unit.remarks!,
                    style: const TextStyle(color: Colors.grey),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

// --- ADD/EDIT DIALOG ---
class _AirconDialog extends StatefulWidget {
  final AirconUnit? unit;
  final List<Map<String, dynamic>> brands;
  final List<Map<String, dynamic>> types;
  final List<Map<String, dynamic>> customers;

  const _AirconDialog({
    this.unit,
    required this.brands,
    required this.types,
    required this.customers,
  });

  @override
  State<_AirconDialog> createState() => _AirconDialogState();
}

class _AirconDialogState extends State<_AirconDialog> {
  final _formKey = GlobalKey<FormState>();
  final _remarksCtrl = TextEditingController();

  // Selection State
  String _brandName = '';
  int? _selectedTypeId;
  int? _selectedCustId; // The ID of the currently selected customer

  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    if (widget.unit != null) {
      _brandName = widget.unit!.brand;
      _selectedTypeId = widget.unit!.typeId;
      _selectedCustId = widget.unit!.customerId;
      _remarksCtrl.text = widget.unit!.remarks ?? '';
    } else {
      // For types, default to first if available
      if (widget.types.isNotEmpty) _selectedTypeId = widget.types.first['id'];
    }
  }

  // Helper to add new Type
  Future<void> _addNewType() async {
    String? newTypeName = await showDialog<String>(
      context: context,
      builder: (ctx) {
        String val = '';
        return AlertDialog(
          title: const Text("Add New Type"),
          content: TextField(
            autofocus: true,
            decoration: _inputDeco(
              "Type Name (e.g. Cassette)",
              null,
              isRequired: true,
            ),
            onChanged: (v) => val = v,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text("Cancel"),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, val),
              child: const Text("Add"),
            ),
          ],
        );
      },
    );

    if (newTypeName != null && newTypeName.trim().isNotEmpty) {
      // Create new Type in DB
      try {
        final res = await Supabase.instance.client
            .from('aircon_types')
            .insert({'type_name': newTypeName.trim()})
            .select()
            .single();

        setState(() {
          // Add to local list so it appears in dropdown immediately
          widget.types.add(res);
          _selectedTypeId = res['id'];
        });
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text("Error adding type: $e")));
        }
      }
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    // Extra Check: Ensure ID is set (Autovalidator handles display, this handles submission)
    if (_selectedCustId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select a valid Customer from the list'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // Validate Brand manually since it's not a standard text field
    final brandTrimmed = _brandName.trim();
    if (brandTrimmed.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select or type a Brand'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final supabase = Supabase.instance.client;
      int brandId;

      // 1. Handle Brand (Find or Create)
      final brandCheck = await supabase
          .from('brands')
          .select('id')
          .ilike('brand_name', brandTrimmed)
          .maybeSingle();

      if (brandCheck != null) {
        brandId = brandCheck['id'];
      } else {
        // Create new brand
        final newBrand = await supabase
            .from('brands')
            .insert({'brand_name': brandTrimmed})
            .select('id')
            .single();
        brandId = newBrand['id'];
      }

      final data = {
        'brand_id': brandId,
        'aircon_type_id': _selectedTypeId,
        'customer_id': _selectedCustId,
        'remarks': _remarksCtrl.text.trim().isEmpty
            ? null
            : _remarksCtrl.text.trim(),
        'is_active': true, // Ensure new units are active
      };

      if (widget.unit == null) {
        await supabase.from('aircons').insert(data);
      } else {
        await supabase.from('aircons').update(data).eq('id', widget.unit!.id);
      }

      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error saving: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  String _custName(Map<String, dynamic> c) {
    if (c['company_name'] != null && c['company_name'].toString().isNotEmpty) {
      return c['company_name'];
    }
    return "${c['first_name']} ${c['last_name']}".trim();
  }

  // Helper to find initial customer object
  Map<String, dynamic>? _findCustomerById(int id) {
    try {
      return widget.customers.firstWhere((c) => c['id'] == id);
    } catch (e) {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 600;
    // 1. KEYBOARD HEIGHT
    final bottomPadding = MediaQuery.of(context).viewInsets.bottom;

    return Padding(
      // 2. PUSH UP
      padding: EdgeInsets.only(bottom: bottomPadding),
      child: Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.9,
        ),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min, // Shrink to fit content
          children: [
            // --- HEADER ---
            Container(
              padding: EdgeInsets.all(isMobile ? 16 : 20),
              decoration: const BoxDecoration(
                border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0))),
              ),
              child: Row(
                children: [
                  const Icon(Icons.ac_unit, color: Colors.purple),
                  const SizedBox(width: 12),
                  Text(
                    widget.unit == null ? 'Add Unit' : 'Edit Unit',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
            ),

            // --- SCROLLABLE FORM ---
            Expanded(
              child: SingleChildScrollView(
                padding: EdgeInsets.all(isMobile ? 16 : 24),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // CUSTOMER SEARCH
                      Autocomplete<Map<String, dynamic>>(
                        initialValue: TextEditingValue(
                          text:
                              _selectedCustId != null &&
                                  _findCustomerById(_selectedCustId!) != null
                              ? _custName(_findCustomerById(_selectedCustId!)!)
                              : '',
                        ),
                        optionsBuilder: (TextEditingValue textEditingValue) {
                          if (textEditingValue.text.isEmpty) {
                            return const Iterable<Map<String, dynamic>>.empty();
                          }
                          return widget.customers.where((
                            Map<String, dynamic> option,
                          ) {
                            return _custName(option).toLowerCase().contains(
                              textEditingValue.text.toLowerCase(),
                            );
                          });
                        },
                        displayStringForOption: _custName,
                        onSelected: (Map<String, dynamic> selection) {
                          setState(() {
                            _selectedCustId = selection['id'];
                          });
                        },
                        fieldViewBuilder:
                            (
                              context,
                              textEditingController,
                              focusNode,
                              onFieldSubmitted,
                            ) {
                              return TextFormField(
                                controller: textEditingController,
                                focusNode: focusNode,
                                decoration: _inputDeco(
                                  'Owner / Customer (Search)',
                                  Icons.person_search,
                                  isRequired: true,
                                ),
                                validator: (val) {
                                  if (_selectedCustId == null)
                                    return 'You must select a customer from the list';
                                  return null;
                                },
                                onChanged: (text) {
                                  if (_selectedCustId != null)
                                    setState(() => _selectedCustId = null);
                                },
                              );
                            },
                      ),

                      const SizedBox(height: 16),

                      Row(
                        children: [
                          // BRAND
                          Expanded(
                            child: LayoutBuilder(
                              builder: (context, constraints) {
                                return Autocomplete<String>(
                                  initialValue: TextEditingValue(
                                    text: _brandName,
                                  ),
                                  optionsBuilder: (v) {
                                    if (v.text.isEmpty)
                                      return const Iterable<String>.empty();
                                    return widget.brands
                                        .map((b) => b['brand_name'] as String)
                                        .where(
                                          (name) => name.toLowerCase().contains(
                                            v.text.toLowerCase(),
                                          ),
                                        );
                                  },
                                  onSelected: (val) => _brandName = val,
                                  fieldViewBuilder: (ctx, ctrl, focus, submit) {
                                    ctrl.addListener(
                                      () => _brandName = ctrl.text,
                                    );
                                    return TextFormField(
                                      controller: ctrl,
                                      focusNode: focus,
                                      decoration: _inputDeco(
                                        'Brand (Type to create)',
                                        null,
                                        isRequired: true,
                                      ),
                                      validator: (v) =>
                                          v!.isEmpty ? 'Required' : null,
                                    );
                                  },
                                );
                              },
                            ),
                          ),
                          const SizedBox(width: 12),
                          // TYPE
                          Expanded(
                            child: Row(
                              children: [
                                Expanded(
                                  child: DropdownButtonFormField<int>(
                                    value: _selectedTypeId,
                                    isExpanded: true,
                                    decoration: _inputDeco(
                                      'Type',
                                      null,
                                      isRequired: true,
                                    ),
                                    items: widget.types
                                        .map(
                                          (t) => DropdownMenuItem(
                                            value: t['id'] as int,
                                            child: Text(t['type_name']),
                                          ),
                                        )
                                        .toList(),
                                    onChanged: (v) =>
                                        setState(() => _selectedTypeId = v),
                                    validator: (v) =>
                                        v == null ? 'Required' : null,
                                  ),
                                ),
                                IconButton(
                                  onPressed: _addNewType,
                                  icon: const Icon(
                                    Icons.add_circle_outline,
                                    color: Colors.blue,
                                  ),
                                  tooltip: "Add New Type",
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      TextFormField(
                        controller: _remarksCtrl,
                        decoration: _inputDeco('Location / Remarks', null),
                        maxLines: 3,
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // --- FOOTER ---
            Container(
              padding: EdgeInsets.all(isMobile ? 16 : 24),
              decoration: const BoxDecoration(
                color: Colors.white,
                border: Border(top: BorderSide(color: Color(0xFFE2E8F0))),
              ),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isSubmitting ? null : _submit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.purple,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: _isSubmitting
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                      : Text(widget.unit == null ? 'Save Unit' : 'Update Unit'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // FIX: Consistent Input Decoration with Red Asterisk support
  InputDecoration _inputDeco(
    String label,
    IconData? icon, {
    bool isRequired = false,
  }) {
    const labelStyle = TextStyle(
      color: Color(0xFF757575),
      fontSize: 16,
    ); // Grey 600

    return InputDecoration(
      label: isRequired
          ? RichText(
              text: TextSpan(
                text: label,
                style: labelStyle,
                children: const [
                  TextSpan(
                    text: ' *',
                    style: TextStyle(
                      color: Colors.red,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            )
          : Text(label, style: labelStyle),
      prefixIcon: icon != null
          ? Icon(icon, size: 20, color: const Color(0xFF9E9E9E)) // Grey 500
          : null,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.grey.shade300),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.grey.shade300),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      filled: true,
      fillColor: const Color(0xFFFAFAFA), // Very light grey
      floatingLabelBehavior: FloatingLabelBehavior.auto,
    );
  }
}

// --- LOCAL DATA MODEL ---
class AirconUnit {
  final int id;
  final int brandId;
  final String brand;
  final int typeId;
  final String type;
  final int customerId;
  final String customerName;
  final String? remarks;

  AirconUnit({
    required this.id,
    required this.brandId,
    required this.brand,
    required this.typeId,
    required this.type,
    required this.customerId,
    required this.customerName,
    this.remarks,
  });

  factory AirconUnit.fromMap(Map<String, dynamic> map) {
    // Nested Data Parsing
    final brandData = map['brands'];
    final typeData = map['aircon_types'];
    final custData = map['customers'];

    String cName = 'Unknown';
    if (custData != null) {
      if (custData['company_name'] != null &&
          custData['company_name'].toString().isNotEmpty) {
        cName = custData['company_name'];
      } else {
        cName = "${custData['first_name']} ${custData['last_name']}".trim();
      }
    }

    return AirconUnit(
      id: map['id'],
      brandId: map['brand_id'],
      brand: brandData != null ? brandData['brand_name'] : 'Unknown',
      typeId: map['aircon_type_id'],
      type: typeData != null ? typeData['type_name'] : 'Unknown',
      customerId: map['customer_id'],
      customerName: cName,
      remarks: map['remarks'],
    );
  }
}
