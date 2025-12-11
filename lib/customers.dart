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

  // Controllers
  final _companyCtrl = TextEditingController();
  final _firstCtrl = TextEditingController();
  final _middleCtrl = TextEditingController();
  final _lastCtrl = TextEditingController();
  final _jobCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();

  // Address
  final _unitCtrl = TextEditingController();
  final _streetCtrl = TextEditingController();
  final _villageCtrl = TextEditingController();
  final _brgyCtrl = TextEditingController();
  final _cityCtrl = TextEditingController();
  final _landmarkCtrl = TextEditingController();

  int _typeId = 2; // Default to B2C (2), B2B is (1)
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
      _unitCtrl.text = c.unitNo ?? '';
      _streetCtrl.text = c.street ?? '';
      _villageCtrl.text = c.village ?? '';
      _brgyCtrl.text = c.barangay ?? '';
      _cityCtrl.text = c.city ?? '';
      _landmarkCtrl.text = c.landmark ?? '';
    }
  }

  Future<void> _submit() async {
    // 1. Basic Form Validation
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSubmitting = true);

    // Prepare clean data variables
    final typeId = _typeId;
    final company = _companyCtrl.text.trim();
    final first = _firstCtrl.text.trim();
    final last = _lastCtrl.text.trim();
    final phone = _phoneCtrl.text.trim();

    final supabase = Supabase.instance.client;

    try {
      // 2. DUPLICATE CHECKING LOGIC (With Active/Inactive check)
      Map<String, dynamic>? duplicate;

      // Note: We SELECT 'is_active' to know if we can resurrect
      if (typeId == 1) {
        // --- B2B CHECK ---
        // Check 1: Company Name
        if (company.isNotEmpty) {
          final res = await supabase
              .from('customers')
              .select('id, is_active, company_name') // Include is_active
              .ilike('company_name', company)
              .neq('id', widget.customer?.id ?? -1)
              .limit(1)
              .maybeSingle();
          if (res != null) duplicate = res;
        }

        // Check 2: Phone
        if (duplicate == null && phone.isNotEmpty) {
          final res = await supabase
              .from('customers')
              .select('id, is_active, company_name') // Include is_active
              .eq('contact_number', phone)
              .neq('id', widget.customer?.id ?? -1)
              .limit(1)
              .maybeSingle();
          if (res != null) duplicate = res;
        }
      } else {
        // --- B2C CHECK ---
        // Check 1: Name Combination
        final nameRes = await supabase
            .from('customers')
            .select('id, is_active, first_name, last_name') // Include is_active
            .eq('customer_type_id', 2)
            .ilike('first_name', first)
            .ilike('last_name', last)
            .neq('id', widget.customer?.id ?? -1)
            .limit(1)
            .maybeSingle();

        if (nameRes != null) {
          duplicate = nameRes;
        } else if (phone.isNotEmpty) {
          // Check 2: Phone Match
          final phoneRes = await supabase
              .from('customers')
              .select(
                'id, is_active, first_name, last_name',
              ) // Include is_active
              .eq('contact_number', phone)
              .neq('id', widget.customer?.id ?? -1)
              .limit(1)
              .maybeSingle();
          if (phoneRes != null) duplicate = phoneRes;
        }
      }

      // 3. HANDLING DUPLICATES (Resurrection Logic)
      if (duplicate != null) {
        final bool isActive = duplicate['is_active'] ?? true;
        final int duplicateId = duplicate['id'];

        if (isActive) {
          // CASE A: REAL DUPLICATE (Active User)
          if (mounted) {
            await showDialog(
              context: context,
              builder: (ctx) => AlertDialog(
                title: const Row(
                  children: [
                    Icon(Icons.warning_amber_rounded, color: Colors.orange),
                    SizedBox(width: 8),
                    Text('Duplicate Found'),
                  ],
                ),
                content: const Text(
                  'A customer with this Name or Phone Number already exists and is active.',
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(ctx),
                    child: const Text('OK'),
                  ),
                ],
              ),
            );
          }
          setState(() => _isSubmitting = false);
          return; // Stop.
        } else {
          // CASE B: RESURRECTION (Archived User)
          bool restore = false;
          if (mounted) {
            restore =
                await showDialog<bool>(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    title: const Text('Found in Archive'),
                    content: const Text(
                      'This customer exists but was archived. Would you like to restore their profile with these new details?',
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(ctx, false),
                        child: const Text('Cancel'),
                      ),
                      TextButton(
                        onPressed: () => Navigator.pop(ctx, true),
                        child: const Text('Restore Profile'),
                      ),
                    ],
                  ),
                ) ??
                false;
          }

          if (!restore) {
            setState(() => _isSubmitting = false);
            return; // User cancelled
          }

          // Proceed to update the ARCHIVED record instead of inserting new
          // We set widget.customer temporarily to null logic below handles updates if we had the ID,
          // but here we have the duplicateId. We will execute the update explicitly here.

          final data = _prepareData();
          data['is_active'] = true; // REACTIVATE!

          final response = await supabase
              .from('customers')
              .update(data)
              .eq('id', duplicateId) // Update the old ghost record
              .select('*, customer_types(type_name)')
              .single();

          if (mounted) Navigator.pop(context, Customer.fromMap(response));
          return;
        }
      }

      // 4. NORMAL INSERT / UPDATE (No Duplicates found)
      final data = _prepareData();
      // Ensure new records are active
      data['is_active'] = true;

      if (widget.customer == null) {
        // Insert
        final response = await supabase
            .from('customers')
            .insert(data)
            .select('*, customer_types(type_name)')
            .single();
        if (mounted) Navigator.pop(context, Customer.fromMap(response));
      } else {
        // Update existing
        final response = await supabase
            .from('customers')
            .update(data)
            .eq('id', widget.customer!.id)
            .select('*, customer_types(type_name)')
            .single();
        if (mounted) Navigator.pop(context, Customer.fromMap(response));
      }
    } catch (e) {
      if (mounted) {
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('System Error'),
            content: Text('Failed to save record: $e'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('OK'),
              ),
            ],
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  // Helper to bundle form data
  Map<String, dynamic> _prepareData() {
    return {
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
      'unit_building_house_no': _unitCtrl.text.trim(),
      'street': _streetCtrl.text.trim(),
      'subdivision_village': _villageCtrl.text.trim(),
      'barangay': _brgyCtrl.text.trim(),
      'city': _cityCtrl.text.trim(),
      'landmark': _landmarkCtrl.text.trim().isEmpty
          ? null
          : _landmarkCtrl.text.trim(),
    };
  }

  @override
  Widget build(BuildContext context) {
    final isB2B = _typeId == 1;

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.9,
      ),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          // Header
          Container(
            padding: const EdgeInsets.all(20),
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

          // Form
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
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

                    // Basic Info
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
                        validator: (v) {
                          if (!isB2B) return null;
                          if (v == null || v.trim().isEmpty)
                            return 'Company Name is required for B2B';
                          return null;
                        },
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
                          Icons.badge_outlined,
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
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(RegExp(r'[0-9+ \-]')),
                      ],
                      validator: (v) {
                        if (v == null || v.trim().isEmpty) return 'Required';
                        final digits = v.replaceAll(RegExp(r'\D'), '');
                        if (digits.length < 7)
                          return 'Too short (min 7 digits)';
                        if (digits.length > 15) return 'Too long';
                        return null;
                      },
                    ),

                    const SizedBox(height: 24),
                    const Text(
                      'Address',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 16),

                    TextFormField(
                      controller: _unitCtrl,
                      decoration: _inputDeco('Unit / House #', null),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _streetCtrl,
                      decoration: _inputDeco('Street Name', null),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _brgyCtrl,
                            decoration: _inputDeco(
                              'Barangay',
                              null,
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
                            controller: _cityCtrl,
                            decoration: _inputDeco(
                              'City',
                              Icons.location_city,
                              isRequired: true,
                            ),
                            validator: (v) => v == null || v.trim().isEmpty
                                ? 'Required'
                                : null,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Footer Action
          Container(
            padding: const EdgeInsets.all(24),
            decoration: const BoxDecoration(
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
      floatingLabelBehavior: FloatingLabelBehavior.auto,
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
    final parts = [unitNo, street, village, barangay, city];
    return parts.where((p) => p != null && p.isNotEmpty).join(', ');
  }
}
