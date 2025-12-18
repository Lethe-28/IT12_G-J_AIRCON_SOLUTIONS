import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'ui_app_shell.dart';
import 'shared/widgets.dart'; // Assumes your widget library exists

class CustomersScreen extends StatefulWidget {
  const CustomersScreen({super.key});

  @override
  State<CustomersScreen> createState() => _CustomersScreenState();
}

class _CustomersScreenState extends State<CustomersScreen> {
  final _supabase = Supabase.instance.client;
  bool _isLoading = true;
  List<Customer> _customers = [];

  // Filter & Search State
  String _searchQuery = '';
  String _filterType = 'All'; // All, B2B, B2C

  @override
  void initState() {
    super.initState();
    _fetchCustomers();
  }

  Future<void> _fetchCustomers() async {
    setState(() => _isLoading = true);
    try {
      final response = await _supabase
          .from('customers')
          .select('*, customer_types(type_name)')
          .eq('is_active', true) // <--- ONLY SHOW ACTIVE CUSTOMERS
          .order('id', ascending: false);

      final List<Customer> loaded = [];
      for (var row in response) {
        loaded.add(Customer.fromMap(row));
      }

      if (mounted) {
        setState(() {
          _customers = loaded;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error fetching customers: $e');
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

  Future<void> _onAddOrEdit({Customer? existing}) async {
    final Customer? result = await showModalBottomSheet<Customer>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _CustomerDialog(customer: existing),
    );

    if (result != null) {
      _fetchCustomers();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            existing == null ? 'Customer Saved' : 'Customer Updated',
          ),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  // --- CHANGED: DELETE IS NOW ARCHIVE ---
  Future<void> _onArchive(Customer customer) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Archive Customer'),
        content: Text(
          'Are you sure you want to archive ${customer.displayName}?\n\n'
          'They will be hidden from lists but their history (Job Orders, Payments) will be preserved.',
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
        // SOFT DELETE: Set is_active to false
        await _supabase
            .from('customers')
            .update({'is_active': false})
            .eq('id', customer.id);

        setState(() {
          _customers.removeWhere((c) => c.id == customer.id);
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Customer archived successfully'),
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

  List<Customer> get _filteredCustomers {
    var filtered = _customers;

    if (_filterType != 'All') {
      filtered = filtered.where((c) => c.typeName == _filterType).toList();
    }

    if (_searchQuery.isNotEmpty) {
      final q = _searchQuery.toLowerCase();
      filtered = filtered.where((c) {
        return c.displayName.toLowerCase().contains(q) ||
            c.contactNumber.contains(q) ||
            c.fullAddress.toLowerCase().contains(q) ||
            (c.email ?? '').toLowerCase().contains(q);
      }).toList();
    }

    return filtered;
  }

  @override
  Widget build(BuildContext context) {
    final filteredList = _filteredCustomers;
    final isMobileView = MediaQuery.of(context).size.width < 800;

    return AppShell(
      selectedIndex: 5,
      floatingActionButton: isMobileView
          ? FloatingActionButton(
              onPressed: () => _onAddOrEdit(),
              backgroundColor: Colors.blue,
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
                            'Customer Directory',
                            style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          SizedBox(height: 4),
                          Text(
                            'Manage B2B and B2C client records.',
                            style: TextStyle(color: Colors.grey),
                          ),
                        ],
                      ),
                      if (!isMobileView)
                        ElevatedButton.icon(
                          onPressed: () => _onAddOrEdit(),
                          icon: const Icon(Icons.add),
                          label: const Text('Add Customer'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blue,
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
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          onChanged: (v) => setState(() => _searchQuery = v),
                          decoration: InputDecoration(
                            hintText: 'Search customers...',
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
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        decoration: BoxDecoration(
                          color: Colors.grey[100],
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            value: _filterType,
                            items: const [
                              DropdownMenuItem(
                                value: 'All',
                                child: Text('All Types'),
                              ),
                              DropdownMenuItem(
                                value: 'B2B',
                                child: Text('B2B Only'),
                              ),
                              DropdownMenuItem(
                                value: 'B2C',
                                child: Text('B2C Only'),
                              ),
                            ],
                            onChanged: (v) =>
                                setState(() => _filterType = v ?? 'All'),
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
                        icon: Icons.people_outline,
                        title: 'No customers found',
                        message:
                            'Try adjusting your search or add a new customer.',
                      ),
                    )
                  : isMobileView
                  ? ListView.separated(
                      padding: const EdgeInsets.all(16),
                      itemCount: filteredList.length,
                      separatorBuilder: (ctx, i) => const SizedBox(height: 12),
                      itemBuilder: (ctx, i) => _MobileCustomerCard(
                        customer: filteredList[i],
                        onEdit: () => _onAddOrEdit(existing: filteredList[i]),
                        onDelete: () => _onArchive(filteredList[i]),
                      ),
                    )
                  : SingleChildScrollView(
                      padding: const EdgeInsets.all(24),
                      child: _DesktopCustomerTable(
                        customers: filteredList,
                        onEdit: (c) => _onAddOrEdit(existing: c),
                        onDelete: (c) => _onArchive(c),
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

// --- DESKTOP TABLE VIEW ---
class _DesktopCustomerTable extends StatelessWidget {
  final List<Customer> customers;
  final Function(Customer) onEdit;
  final Function(Customer) onDelete;

  const _DesktopCustomerTable({
    required this.customers,
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
              'CLIENT',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          DataColumn(
            label: Text('TYPE', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
          DataColumn(
            label: Text(
              'CONTACT',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          DataColumn(
            label: Text(
              'ADDRESS',
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
        rows: customers.map((c) {
          final isB2B = c.typeName == 'B2B';
          return DataRow(
            cells: [
              DataCell(
                Row(
                  children: [
                    CircleAvatar(
                      backgroundColor: isB2B
                          ? Colors.blue[50]
                          : Colors.green[50],
                      child: Icon(
                        isB2B ? Icons.business : Icons.person,
                        color: isB2B ? Colors.blue : Colors.green,
                        size: 18,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          c.displayName,
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        if (isB2B && c.contactPersonName.isNotEmpty)
                          Text(
                            c.contactPersonName,
                            style: const TextStyle(
                              fontSize: 12,
                              color: Colors.grey,
                            ),
                          ),
                      ],
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
                    color: isB2B ? Colors.blue[50] : Colors.green[50],
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                      color: isB2B ? Colors.blue[100]! : Colors.green[100]!,
                    ),
                  ),
                  child: Text(
                    c.typeName,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: isB2B ? Colors.blue[800] : Colors.green[800],
                    ),
                  ),
                ),
              ),
              DataCell(Text(c.contactNumber)),
              DataCell(
                SizedBox(
                  width: 250,
                  child: Text(
                    c.fullAddress,
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
                      onPressed: () => onEdit(c),
                      tooltip: "Edit",
                    ),
                    IconButton(
                      icon: const Icon(
                        Icons.archive_outlined,
                        color: Colors.orange,
                      ), // Changed Icon
                      onPressed: () => onDelete(c),
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

// --- MOBILE CARD VIEW ---
class _MobileCustomerCard extends StatelessWidget {
  final Customer customer;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _MobileCustomerCard({
    required this.customer,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final isB2B = customer.typeName == 'B2B';

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
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: isB2B ? Colors.blue[50] : Colors.green[50],
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  isB2B ? Icons.business : Icons.person,
                  color: isB2B ? Colors.blue : Colors.green,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      customer.displayName,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    if (isB2B && customer.contactPersonName.isNotEmpty)
                      Text(
                        customer.contactPersonName,
                        style: const TextStyle(
                          fontSize: 13,
                          color: Colors.grey,
                        ),
                      ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: isB2B ? Colors.blue[50] : Colors.green[50],
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  customer.typeName,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: isB2B ? Colors.blue[800] : Colors.green[800],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Divider(),
          const SizedBox(height: 8),
          _infoRow(Icons.phone, customer.contactNumber),
          const SizedBox(height: 4),
          _infoRow(Icons.location_on, customer.fullAddress),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton.icon(
                onPressed: onEdit,
                icon: const Icon(Icons.edit, size: 16),
                label: const Text("Edit"),
              ),
              TextButton.icon(
                onPressed: onDelete,
                icon: const Icon(Icons.archive, size: 16), // Changed Icon
                label: const Text("Archive"), // Changed Text
                style: TextButton.styleFrom(foregroundColor: Colors.orange),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _infoRow(IconData icon, String text) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 14, color: Colors.grey),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(fontSize: 13, color: Colors.black87),
          ),
        ),
      ],
    );
  }
}

// --- ADD/EDIT DIALOG ---
class _CustomerDialog extends StatefulWidget {
  final Customer? customer;
  const _CustomerDialog({this.customer});

  @override
  State<_CustomerDialog> createState() => _CustomerDialogState();
}

class _CustomerDialogState extends State<_CustomerDialog> {
  final _formKey = GlobalKey<FormState>();

  // Basic Info Controllers
  final _companyCtrl = TextEditingController();
  final _firstCtrl = TextEditingController();
  final _middleCtrl = TextEditingController();
  final _lastCtrl = TextEditingController();
  final _jobCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();

  // Address Controllers
  final _addressCtrl = TextEditingController(); // The new "Complete Address"
  final _landmarkCtrl = TextEditingController(); // Restored Landmark

  int _typeId = 2; // Default to B2C (2)
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    if (widget.customer != null) {
      final c = widget.customer!;
      _typeId = c.typeId;
      _companyCtrl.text = c.companyName ?? '';
      _firstCtrl.text = c.firstName;
      _middleCtrl.text = c.middleName ?? '';
      _lastCtrl.text = c.lastName;
      _jobCtrl.text = c.jobPosition ?? '';
      _phoneCtrl.text = c.contactNumber;
      _emailCtrl.text = c.email ?? '';
      _landmarkCtrl.text = c.landmark ?? ''; // Load Landmark

      // --- SMART ADDRESS LOADING ---
      if (c.addressComplete != null && c.addressComplete!.isNotEmpty) {
        // 1. Prefer the new Complete Address if it exists
        _addressCtrl.text = c.addressComplete!;
      } else {
        // 2. Fallback: Combine legacy fields (excluding landmark, since it has its own box)
        final parts = [
          c.unitNo,
          c.street,
          c.village,
          c.barangay,
          c.city,
        ].where((s) => s != null && s.trim().isNotEmpty).join(', ');

        _addressCtrl.text = parts;
      }
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSubmitting = true);

    final supabase = Supabase.instance.client;

    try {
      // --- PREPARE DATA ---
      final data = {
        'customer_type_id': _typeId,
        'company_name': _companyCtrl.text.trim().isEmpty
            ? null
            : _companyCtrl.text.trim(),
        'first_name': _firstCtrl.text.trim(),
        'middle_name': _middleCtrl.text.trim().isEmpty
            ? null
            : _middleCtrl.text.trim(),
        'last_name': _lastCtrl.text.trim(),
        'job_position': _jobCtrl.text.trim().isEmpty
            ? null
            : _jobCtrl.text.trim(),
        'contact_number': _phoneCtrl.text.trim(),
        'email': _emailCtrl.text.trim().isEmpty ? null : _emailCtrl.text.trim(),

        // --- SAVE ADDRESS & LANDMARK SEPARATELY ---
        'address_complete': _addressCtrl.text.trim(),
        'landmark': _landmarkCtrl.text.trim().isEmpty
            ? null
            : _landmarkCtrl.text.trim(),

        'is_active': true,
      };

      if (widget.customer == null) {
        final response = await supabase
            .from('customers')
            .insert(data)
            .select('*, customer_types(type_name)')
            .single();
        if (mounted) Navigator.pop(context, Customer.fromMap(response));
      } else {
        final response = await supabase
            .from('customers')
            .update(data)
            .eq('id', widget.customer!.id)
            .select('*, customer_types(type_name)')
            .single();
        if (mounted) Navigator.pop(context, Customer.fromMap(response));
      }
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  // --- VALIDATORS ---
  String? _validatePhone(String? value) {
    if (value == null || value.trim().isEmpty) return 'Required';
    final trimmed = value.trim();
    // Regex: Matches PH Mobile (09xxxxxxxxx) OR Landlines (7-12 digits)
    if (!RegExp(r'^(09\d{9}|\d{7,12})$').hasMatch(trimmed)) {
      return 'Invalid format (e.g. 09171234567)';
    }
    return null;
  }

  String? _validateEmail(String? value) {
    if (value == null || value.trim().isEmpty) return null; // Email is optional
    // Basic Email Regex
    final emailRegex = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
    if (!emailRegex.hasMatch(value.trim())) {
      return 'Invalid email address';
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final isB2B = _typeId == 1;
    final isMobile = MediaQuery.of(context).size.width < 600;
    final bottomPadding = MediaQuery.of(context).viewInsets.bottom;

    return Padding(
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
          mainAxisSize: MainAxisSize.min,
          children: [
            // --- HEADER ---
            Container(
              padding: EdgeInsets.all(isMobile ? 16 : 20),
              decoration: const BoxDecoration(
                border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0))),
              ),
              child: Row(
                children: [
                  const Icon(Icons.person_add, color: Colors.blue),
                  const SizedBox(width: 12),
                  Text(
                    widget.customer == null ? 'Add Customer' : 'Edit Customer',
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

            // --- SCROLLABLE CONTENT ---
            Expanded(
              child: SingleChildScrollView(
                padding: EdgeInsets.all(isMobile ? 16 : 24),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Type Selector
                      Row(
                        children: [
                          Expanded(
                            child: _TypeSelectionCard(
                              title: 'Corporate (B2B)',
                              icon: Icons.business,
                              isSelected: isB2B,
                              onTap: () => setState(() => _typeId = 1),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _TypeSelectionCard(
                              title: 'Individual (B2C)',
                              icon: Icons.person,
                              isSelected: !isB2B,
                              onTap: () => setState(() => _typeId = 2),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),

                      const Text(
                        'Basic Information',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 16),

                      if (isB2B) ...[
                        TextFormField(
                          controller: _companyCtrl,
                          decoration: _inputDeco(
                            'Company Name',
                            Icons.domain,
                            isRequired: true,
                          ),
                          validator: (v) => (!isB2B)
                              ? null
                              : (v == null || v.trim().isEmpty
                                    ? 'Required'
                                    : null),
                        ),
                        const SizedBox(height: 12),
                      ],

                      Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: _firstCtrl,
                              decoration: _inputDeco(
                                'First Name',
                                Icons.person_outline,
                                isRequired: true,
                              ),
                              validator: (v) => v == null || v.trim().isEmpty
                                  ? 'Required'
                                  : null,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: TextFormField(
                              controller: _lastCtrl,
                              decoration: _inputDeco(
                                'Last Name',
                                null,
                                isRequired: true,
                              ),
                              validator: (v) => v == null || v.trim().isEmpty
                                  ? 'Required'
                                  : null,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),

                      if (isB2B) ...[
                        TextFormField(
                          controller: _jobCtrl,
                          decoration: _inputDeco(
                            'Job Position',
                            Icons.work_outline,
                          ),
                        ),
                        const SizedBox(height: 12),
                      ],

                      TextFormField(
                        controller: _phoneCtrl,
                        decoration: _inputDeco(
                          'Phone Number',
                          Icons.phone,
                          isRequired: true,
                        ),
                        keyboardType: TextInputType.phone,
                        validator: _validatePhone,
                      ),

                      const SizedBox(height: 12),

                      // 5. Email Address (Added)
                      TextFormField(
                        controller: _emailCtrl,
                        decoration: _inputDeco(
                          'Email Address',
                          Icons.email_outlined,
                        ),
                        keyboardType: TextInputType.emailAddress,
                        validator: _validateEmail,
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'Location Details',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 16),

                      // --- COMPLETE ADDRESS FIELD ---
                      TextFormField(
                        controller: _addressCtrl,
                        decoration: _inputDeco(
                          'Complete Address',
                          Icons.location_on,
                        ),
                        maxLines: 3,
                        textCapitalization: TextCapitalization.sentences,
                      ),

                      const SizedBox(height: 12),

                      // --- LANDMARK FIELD (RESTORED) ---
                      TextFormField(
                        controller: _landmarkCtrl,
                        decoration: _inputDeco(
                          'Landmark / Instructions',
                          Icons.flag,
                        ),
                        textCapitalization: TextCapitalization.sentences,
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
                    backgroundColor: Colors.blue,
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
                      : Text(
                          widget.customer == null
                              ? 'Save Customer'
                              : 'Update Customer',
                        ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  InputDecoration _inputDeco(
    String label,
    IconData? icon, {
    bool isRequired = false,
  }) {
    const labelStyle = TextStyle(color: Color(0xFF757575), fontSize: 16);
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
          ? Icon(icon, size: 20, color: const Color(0xFF9E9E9E))
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
      fillColor: const Color(0xFFFAFAFA),
      alignLabelWithHint: true,
    );
  }
}

class _TypeSelectionCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final bool isSelected;
  final VoidCallback onTap;

  const _TypeSelectionCard({
    required this.title,
    required this.icon,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? Colors.blue.withOpacity(0.1) : Colors.grey[100],
          border: Border.all(
            color: isSelected ? Colors.blue : Colors.transparent,
            width: 2,
          ),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            Icon(icon, color: isSelected ? Colors.blue : Colors.grey),
            const SizedBox(height: 4),
            Text(
              title,
              style: TextStyle(
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                color: isSelected ? Colors.blue : Colors.grey[700],
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// --- LOCAL DATA MODEL (Self-Contained) ---
class Customer {
  final int id;
  final int typeId;
  final String typeName; // 'B2B' or 'B2C'
  final String? companyName;
  final String firstName;
  final String? middleName;
  final String lastName;
  final String? jobPosition;
  final String contactNumber;
  final String? email;
  final String? unitNo;
  final String? street;
  final String? village;
  final String? barangay;
  final String? city;
  final String? landmark;
  final String? addressComplete;

  Customer({
    required this.id,
    required this.typeId,
    required this.typeName,
    this.companyName,
    required this.firstName,
    this.middleName,
    required this.lastName,
    this.jobPosition,
    required this.contactNumber,
    this.email,
    this.unitNo,
    this.street,
    this.village,
    this.barangay,
    this.city,
    this.landmark,
    this.addressComplete,
  });

  factory Customer.fromMap(Map<String, dynamic> map) {
    final typeData = map['customer_types'];
    final typeNameStr = typeData != null ? typeData['type_name'] : 'Unknown';

    return Customer(
      id: map['id'],
      typeId: map['customer_type_id'],
      typeName: typeNameStr,
      companyName: map['company_name'],
      firstName: map['first_name'] ?? '',
      middleName: map['middle_name'],
      lastName: map['last_name'] ?? '',
      jobPosition: map['job_position'],
      contactNumber: map['contact_number'] ?? '',
      email: map['email'],
      unitNo: map['unit_building_house_no'],
      street: map['street'],
      village: map['subdivision_village'],
      barangay: map['barangay'],
      city: map['city'],
      landmark: map['landmark'],
      addressComplete: map['address_complete'],
    );
  }

  String get displayName {
    if (typeName == 'B2B' && companyName != null && companyName!.isNotEmpty) {
      return companyName!;
    }
    return "$firstName $lastName";
  }

  String get contactPersonName => "$firstName $lastName";

  String get fullAddress {
    // 1. If we have the new complete address, use it immediately.
    if (addressComplete != null && addressComplete!.isNotEmpty) {
      return addressComplete!;
    }

    // 2. Fallback: Try to build it from legacy fields
    final parts = [
      unitNo,
      street,
      village,
      barangay,
      city,
    ].where((s) => s != null && s.trim().isNotEmpty).join(', ');

    return parts.isEmpty ? 'No address provided' : parts;
  }
}
