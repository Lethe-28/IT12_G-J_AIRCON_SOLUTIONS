import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'ui_app_shell.dart';
import 'shared/widgets.dart'; // Assumes EmptyState and other shared widgets exist

class TechniciansScreen extends StatefulWidget {
  const TechniciansScreen({super.key});

  @override
  State<TechniciansScreen> createState() => _TechniciansScreenState();
}

class _TechniciansScreenState extends State<TechniciansScreen> {
  final _supabase = Supabase.instance.client;
  bool _isLoading = true;
  List<Technician> _technicians = [];
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _fetchTechnicians();
  }

  Future<void> _fetchTechnicians() async {
    setState(() => _isLoading = true);
    try {
      final response = await _supabase
          .from('technicians')
          .select()
          .eq('is_active', true) // <--- ONLY SHOW ACTIVE TECHNICIANS
          .order('first_name', ascending: true);

      final List<Technician> loaded = [];
      for (var row in response) {
        loaded.add(Technician.fromMap(row));
      }

      if (mounted) {
        setState(() {
          _technicians = loaded;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error fetching technicians: $e');
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

  Future<void> _onAddOrEdit({Technician? existing}) async {
    final Technician? result = await showModalBottomSheet<Technician>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _TechnicianDialog(technician: existing),
    );

    if (result != null) {
      _fetchTechnicians(); // Refresh list
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            existing == null ? 'Technician Saved' : 'Technician Updated',
          ),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  // --- CHANGED: DELETE IS NOW ARCHIVE ---
  Future<void> _onArchive(Technician technician) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Archive Technician'),
        content: Text(
          'Are you sure you want to archive ${technician.fullName}?\n\n'
          'They will be hidden from lists but their job history will be preserved.',
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
            .from('technicians')
            .update({'is_active': false})
            .eq('id', technician.id);

        setState(() {
          _technicians.removeWhere((t) => t.id == technician.id);
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Technician archived successfully'),
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

  List<Technician> get _filteredTechnicians {
    if (_searchQuery.isEmpty) return _technicians;
    final q = _searchQuery.toLowerCase();
    return _technicians.where((t) {
      return t.fullName.toLowerCase().contains(q) ||
          t.contactNumber.contains(q);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final filteredList = _filteredTechnicians;
    final isMobileView = MediaQuery.of(context).size.width < 800;

    return AppShell(
      selectedIndex: 6, // 6 = Technicians Tab
      floatingActionButton: isMobileView
          ? FloatingActionButton(
              onPressed: () => _onAddOrEdit(),
              backgroundColor: Colors.orange,
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
                            'Technician Roster',
                            style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          SizedBox(height: 4),
                          Text(
                            'Manage field technicians and contact details.',
                            style: TextStyle(color: Colors.grey),
                          ),
                        ],
                      ),
                      if (!isMobileView)
                        ElevatedButton.icon(
                          onPressed: () => _onAddOrEdit(),
                          icon: const Icon(Icons.add),
                          label: const Text('Add Technician'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.orange,
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

                  // Search Bar
                  TextField(
                    onChanged: (v) => setState(() => _searchQuery = v),
                    decoration: InputDecoration(
                      hintText: 'Search by name or contact number...',
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
                        icon: Icons.engineering,
                        title: 'No technicians found',
                        message: 'Add your first technician to get started.',
                      ),
                    )
                  : isMobileView
                  ? ListView.separated(
                      padding: const EdgeInsets.all(16),
                      itemCount: filteredList.length,
                      separatorBuilder: (ctx, i) => const SizedBox(height: 12),
                      itemBuilder: (ctx, i) => _MobileTechnicianCard(
                        technician: filteredList[i],
                        onEdit: () => _onAddOrEdit(existing: filteredList[i]),
                        onDelete: () => _onArchive(filteredList[i]),
                      ),
                    )
                  : SingleChildScrollView(
                      padding: const EdgeInsets.all(24),
                      child: _DesktopTechnicianTable(
                        technicians: filteredList,
                        onEdit: (t) => _onAddOrEdit(existing: t),
                        onDelete: (t) => _onArchive(t),
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
class _DesktopTechnicianTable extends StatelessWidget {
  final List<Technician> technicians;
  final Function(Technician) onEdit;
  final Function(Technician) onDelete;

  const _DesktopTechnicianTable({
    required this.technicians,
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
            label: Text('NAME', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
          DataColumn(
            label: Text(
              'CONTACT NUMBER',
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
        rows: technicians.map((t) {
          return DataRow(
            cells: [
              DataCell(
                Row(
                  children: [
                    CircleAvatar(
                      radius: 18,
                      backgroundColor: Colors.orange[50],
                      child: Text(
                        t.initials,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: Colors.orange[800],
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      t.fullName,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ),
              DataCell(Text(t.contactNumber)),
              DataCell(
                Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.edit_outlined, color: Colors.blue),
                      onPressed: () => onEdit(t),
                      tooltip: "Edit",
                    ),
                    IconButton(
                      icon: const Icon(
                        Icons.archive_outlined,
                        color: Colors.orange,
                      ), // Changed Icon
                      onPressed: () => onDelete(t),
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
class _MobileTechnicianCard extends StatelessWidget {
  final Technician technician;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _MobileTechnicianCard({
    required this.technician,
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
      child: Row(
        children: [
          CircleAvatar(
            radius: 24,
            backgroundColor: Colors.orange[50],
            child: Text(
              technician.initials,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.orange[800],
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  technician.fullName,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    const Icon(Icons.phone, size: 14, color: Colors.grey),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        technician.contactNumber,
                        style: const TextStyle(
                          fontSize: 14,
                          color: Colors.grey,
                        ),
                      ),
                    ),
                  ],
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
    );
  }
}

// --- ADD/EDIT DIALOG ---
class _TechnicianDialog extends StatefulWidget {
  final Technician? technician;
  const _TechnicianDialog({this.technician});

  @override
  State<_TechnicianDialog> createState() => _TechnicianDialogState();
}

class _TechnicianDialogState extends State<_TechnicianDialog> {
  final _formKey = GlobalKey<FormState>();
  final _firstCtrl = TextEditingController();
  final _middleCtrl = TextEditingController();
  final _lastCtrl = TextEditingController();
  final _contactCtrl = TextEditingController();
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    if (widget.technician != null) {
      final t = widget.technician!;
      _firstCtrl.text = t.firstName;
      _middleCtrl.text = t.middleName ?? '';
      _lastCtrl.text = t.lastName;
      _contactCtrl.text = t.contactNumber;
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSubmitting = true);

    // Prepare clean data
    final first = _firstCtrl.text.trim();
    final middle = _middleCtrl.text.trim().isEmpty
        ? null
        : _middleCtrl.text.trim();
    final last = _lastCtrl.text.trim();
    final contact = _contactCtrl.text.trim();

    final supabase = Supabase.instance.client;

    try {
      // 1. DUPLICATE CHECK (Check Contact Number)
      Map<String, dynamic>? duplicate;

      // We only care about contact number for technicians as it's the unique constraint
      if (contact.isNotEmpty) {
        final res = await supabase
            .from('technicians')
            .select('id, is_active, first_name, last_name') // Include is_active
            .eq('contact_number', contact)
            .neq('id', widget.technician?.id ?? -1)
            .limit(1)
            .maybeSingle();
        if (res != null) duplicate = res;
      }

      // 2. HANDLE DUPLICATE (Active vs Archived)
      if (duplicate != null) {
        final bool isActive = duplicate['is_active'] ?? true;
        final int duplicateId = duplicate['id'];
        final String existingName =
            "${duplicate['first_name']} ${duplicate['last_name']}";

        if (isActive) {
          // ACTIVE DUPLICATE: Error
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
                content: Text(
                  'A technician with this number already exists: $existingName',
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
          return;
        } else {
          // ARCHIVED DUPLICATE: Resurrect?
          bool restore = false;
          if (mounted) {
            restore =
                await showDialog<bool>(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    title: const Text('Found in Archive'),
                    content: Text(
                      'Technician $existingName exists in the archives with this number. Would you like to restore them with these updated details?',
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(ctx, false),
                        child: const Text('Cancel'),
                      ),
                      TextButton(
                        onPressed: () => Navigator.pop(ctx, true),
                        child: const Text('Restore'),
                      ),
                    ],
                  ),
                ) ??
                false;
          }

          if (!restore) {
            setState(() => _isSubmitting = false);
            return;
          }

          // PERFORM RESURRECTION
          final data = {
            'first_name': first,
            'middle_name': middle,
            'last_name': last,
            'contact_number': contact,
            'is_active': true, // REACTIVATE!
          };

          final response = await supabase
              .from('technicians')
              .update(data)
              .eq('id', duplicateId)
              .select()
              .single();

          if (mounted) Navigator.pop(context, Technician.fromMap(response));
          return;
        }
      }

      // 3. NORMAL SAVE (Insert/Update)
      final data = {
        'first_name': first,
        'middle_name': middle,
        'last_name': last,
        'contact_number': contact,
        'is_active': true, // Default to true
      };

      if (widget.technician == null) {
        // Create
        final response = await supabase
            .from('technicians')
            .insert(data)
            .select()
            .single();
        if (mounted) Navigator.pop(context, Technician.fromMap(response));
      } else {
        // Update
        final response = await supabase
            .from('technicians')
            .update(data)
            .eq('id', widget.technician!.id)
            .select()
            .single();
        if (mounted) Navigator.pop(context, Technician.fromMap(response));
      }
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

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 600;
    // 1. GET KEYBOARD HEIGHT
    final bottomPadding = MediaQuery.of(context).viewInsets.bottom;

    return Padding(
      // 2. APPLY PADDING TO PUSH UP
      padding: EdgeInsets.only(bottom: bottomPadding),
      child: Container(
        constraints: BoxConstraints(
          // Limit height to 90%
          maxHeight: MediaQuery.of(context).size.height * 0.9,
        ),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min, // Shrink to fit
          children: [
            // --- HEADER ---
            Container(
              padding: EdgeInsets.all(isMobile ? 16 : 20),
              decoration: const BoxDecoration(
                border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0))),
              ),
              child: Row(
                children: [
                  const Icon(Icons.engineering, color: Colors.orange),
                  const SizedBox(width: 12),
                  Text(
                    widget.technician == null
                        ? 'Add Technician'
                        : 'Edit Technician',
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
                      const Text(
                        'Basic Information',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Row for First / Middle
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
                              controller: _middleCtrl,
                              decoration: _inputDeco('Middle', null),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),

                      TextFormField(
                        controller: _lastCtrl,
                        decoration: _inputDeco(
                          'Last Name',
                          null,
                          isRequired: true,
                        ),
                        validator: (v) =>
                            v == null || v.trim().isEmpty ? 'Required' : null,
                      ),
                      const SizedBox(height: 12),

                      TextFormField(
                        controller: _contactCtrl,
                        decoration: _inputDeco(
                          'Contact Number',
                          Icons.phone,
                          isRequired: true,
                        ),
                        keyboardType: TextInputType.phone,
                        inputFormatters: [
                          FilteringTextInputFormatter.allow(
                            RegExp(r'[0-9+ \-]'),
                          ),
                        ],
                        validator: (v) {
                          if (v == null || v.trim().isEmpty) return 'Required';
                          final digits = v.replaceAll(RegExp(r'\D'), '');
                          if (digits.length < 7) return 'Too short';
                          if (digits.length > 13) return 'Too long';
                          return null;
                        },
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // --- FOOTER (Fixed above keyboard) ---
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
                    backgroundColor: Colors.orange,
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
                          widget.technician == null
                              ? 'Save Technician'
                              : 'Update Technician',
                        ),
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
class Technician {
  final int id;
  final String firstName;
  final String? middleName;
  final String lastName;
  final String contactNumber;

  Technician({
    required this.id,
    required this.firstName,
    this.middleName,
    required this.lastName,
    required this.contactNumber,
  });

  factory Technician.fromMap(Map<String, dynamic> map) {
    return Technician(
      id: map['id'],
      firstName: map['first_name'] ?? '',
      middleName: map['middle_name'],
      lastName: map['last_name'] ?? '',
      contactNumber: map['contact_number'] ?? '',
    );
  }

  String get fullName =>
      "$firstName ${middleName != null && middleName!.isNotEmpty ? '$middleName ' : ''}$lastName";

  String get initials =>
      "${firstName.isNotEmpty ? firstName[0] : ''}${lastName.isNotEmpty ? lastName[0] : ''}";
}
