import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'ui_app_shell.dart';
import 'shared/widgets.dart'; // Assumes EmptyState, etc.

class UserManagementScreen extends StatefulWidget {
  const UserManagementScreen({super.key});

  @override
  State<UserManagementScreen> createState() => _UserManagementScreenState();
}

class _UserManagementScreenState extends State<UserManagementScreen> {
  final _supabase = Supabase.instance.client;
  bool _isLoading = true;

  List<AppUser> _users = [];
  List<RoleData> _roles = [];
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _fetchData();
  }

  Future<void> _fetchData() async {
    setState(() => _isLoading = true);
    try {
      // 1. Fetch Users with Role Names
      final usersRes = await _supabase
          .from('app_users')
          .select('*, roles(role_name)')
          .order('full_name', ascending: true);

      // 2. Fetch Roles for Dropdown
      final rolesRes = await _supabase
          .from('roles')
          .select()
          .order('role_name');

      final List<AppUser> loadedUsers = [];
      for (var row in usersRes) {
        loadedUsers.add(AppUser.fromMap(row));
      }

      final List<RoleData> loadedRoles = [];
      for (var row in rolesRes) {
        loadedRoles.add(RoleData.fromMap(row));
      }

      if (mounted) {
        setState(() {
          _users = loadedUsers;
          _roles = loadedRoles;
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

  // --- ACTIONS ---

  Future<void> _onAddOrEdit({AppUser? existing}) async {
    final bool? result = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _UserDialog(user: existing, roles: _roles),
    );

    if (result == true) {
      _fetchData();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(existing == null ? 'User Added' : 'User Updated'),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _onDelete(AppUser user) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove User Access'),
        content: Text(
          'Are you sure you want to remove ${user.fullName}? They will no longer be able to log in.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Remove'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await _supabase.from('app_users').delete().eq('id', user.id);
        setState(() {
          _users.removeWhere((u) => u.id == user.id);
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('User removed'),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Delete failed: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  List<AppUser> get _filteredUsers {
    if (_searchQuery.isEmpty) return _users;
    final q = _searchQuery.toLowerCase();
    return _users.where((u) {
      return u.fullName.toLowerCase().contains(q) ||
          (u.email ?? '').toLowerCase().contains(q) ||
          u.roleName.toLowerCase().contains(q);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final filteredList = _filteredUsers;
    final isMobileView = MediaQuery.of(context).size.width < 800;

    return AppShell(
      selectedIndex: 10, // User Management Tab
      // Pass FAB to Shell
      floatingActionButton: isMobileView
          ? FloatingActionButton(
              onPressed: () => _onAddOrEdit(),
              backgroundColor: Colors.indigo,
              foregroundColor: Colors.white,
              child: const Icon(Icons.person_add),
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
                            'User Management',
                            style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          SizedBox(height: 4),
                          Text(
                            'Control system access and assign roles.',
                            style: TextStyle(color: Colors.grey),
                          ),
                        ],
                      ),
                      if (!isMobileView)
                        ElevatedButton.icon(
                          onPressed: () => _onAddOrEdit(),
                          icon: const Icon(Icons.person_add),
                          label: const Text('Add User'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.indigo,
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
                      hintText: 'Search users...',
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
                        icon: Icons.people_alt_outlined,
                        title: 'No users found',
                        message: 'Invite users to give them access.',
                      ),
                    )
                  : isMobileView
                  ? ListView.separated(
                      padding: const EdgeInsets.all(16),
                      itemCount: filteredList.length,
                      separatorBuilder: (ctx, i) => const SizedBox(height: 12),
                      itemBuilder: (ctx, i) => _MobileUserCard(
                        user: filteredList[i],
                        onEdit: () => _onAddOrEdit(existing: filteredList[i]),
                        onDelete: () => _onDelete(filteredList[i]),
                      ),
                    )
                  : SingleChildScrollView(
                      padding: const EdgeInsets.all(24),
                      child: _DesktopUserTable(
                        users: filteredList,
                        onEdit: (u) => _onAddOrEdit(existing: u),
                        onDelete: (u) => _onDelete(u),
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
class _DesktopUserTable extends StatelessWidget {
  final List<AppUser> users;
  final Function(AppUser) onEdit;
  final Function(AppUser) onDelete;

  const _DesktopUserTable({
    required this.users,
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
        headingRowColor: MaterialStateProperty.all(Colors.grey[50]),
        columns: const [
          DataColumn(
            label: Text('USER', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
          DataColumn(
            label: Text('ROLE', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
          DataColumn(
            label: Text('EMAIL', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
          DataColumn(
            label: Text(
              'ACTIONS',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        ],
        rows: users.map((u) {
          return DataRow(
            cells: [
              DataCell(
                Row(
                  children: [
                    CircleAvatar(
                      radius: 18,
                      backgroundColor: Colors.indigo[50],
                      child: Text(
                        u.initials,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: Colors.indigo[800],
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      u.fullName,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
              DataCell(_RoleBadge(roleName: u.roleName)),
              DataCell(Text(u.email ?? '-')),
              DataCell(
                Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.edit_outlined, color: Colors.blue),
                      onPressed: () => onEdit(u),
                      tooltip: "Edit Role",
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete_outline, color: Colors.red),
                      onPressed: () => onDelete(u),
                      tooltip: "Revoke Access",
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
class _MobileUserCard extends StatelessWidget {
  final AppUser user;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _MobileUserCard({
    required this.user,
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
            backgroundColor: Colors.indigo[50],
            child: Text(
              user.initials,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.indigo[800],
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        user.fullName,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                _RoleBadge(roleName: user.roleName, compact: true),
                const SizedBox(height: 4),
                Text(
                  user.email ?? 'No email',
                  style: const TextStyle(fontSize: 13, color: Colors.grey),
                ),
              ],
            ),
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert, color: Colors.grey),
            onSelected: (value) {
              if (value == 'edit') onEdit();
              if (value == 'delete') onDelete();
            },
            itemBuilder: (context) => [
              const PopupMenuItem(value: 'edit', child: Text('Edit Role')),
              const PopupMenuItem(
                value: 'delete',
                child: Text('Remove', style: TextStyle(color: Colors.red)),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// --- ROLE BADGE COMPONENT ---
class _RoleBadge extends StatelessWidget {
  final String roleName;
  final bool compact;

  const _RoleBadge({required this.roleName, this.compact = false});

  @override
  Widget build(BuildContext context) {
    Color bg;
    Color text;

    // HCI Color Coding:
    // Admin = Red/Pink (Power)
    // Staff/Manager = Blue (Business)
    // Technician = Orange (Field)
    switch (roleName.toLowerCase()) {
      case 'admin':
        bg = Colors.red[50]!;
        text = Colors.red[700]!;
        break;
      case 'technician':
        bg = Colors.orange[50]!;
        text = Colors.orange[800]!;
        break;
      default:
        bg = Colors.blue[50]!;
        text = Colors.blue[800]!;
    }

    return Container(
      padding: EdgeInsets.symmetric(horizontal: 8, vertical: compact ? 2 : 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: bg.withOpacity(0.5)), // Slight border
      ),
      child: Text(
        roleName,
        style: TextStyle(
          fontSize: compact ? 10 : 12,
          fontWeight: FontWeight.bold,
          color: text,
        ),
      ),
    );
  }
}

// --- ADD/EDIT DIALOG ---
class _UserDialog extends StatefulWidget {
  final AppUser? user;
  final List<RoleData> roles;

  const _UserDialog({this.user, required this.roles});

  @override
  State<_UserDialog> createState() => _UserDialogState();
}

class _UserDialogState extends State<_UserDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();

  int? _selectedRoleId;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    if (widget.user != null) {
      _nameCtrl.text = widget.user!.fullName;
      _emailCtrl.text = widget.user!.email ?? '';
      _selectedRoleId = widget.user!.roleId;
    } else {
      if (widget.roles.isNotEmpty) _selectedRoleId = widget.roles.first.id;
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSubmitting = true);

    final data = {
      'full_name': _nameCtrl.text.trim(),
      'email': _emailCtrl.text.trim(),
      'role_id': _selectedRoleId,
    };

    try {
      if (widget.user == null) {
        // Create (In a real app, this would trigger an Auth Invite)
        // For now, we insert into public.app_users
        await Supabase.instance.client.from('app_users').insert(data);
      } else {
        // Update
        await Supabase.instance.client
            .from('app_users')
            .update(data)
            .eq('id', widget.user!.id);
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

  @override
  Widget build(BuildContext context) {
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
                const Icon(Icons.person, color: Colors.indigo),
                const SizedBox(width: 12),
                Text(
                  widget.user == null ? 'Add User' : 'Edit User',
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
                    TextFormField(
                      controller: _nameCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Full Name *',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.badge_outlined),
                      ),
                      validator: (v) => v!.isEmpty ? 'Required' : null,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _emailCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Email Address *',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.email_outlined),
                      ),
                      // Allow edit only if new (Standard security practice)
                      enabled: widget.user == null,
                      validator: (v) => v!.isEmpty || !v.contains('@')
                          ? 'Valid email required'
                          : null,
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<int>(
                      value: _selectedRoleId,
                      decoration: const InputDecoration(
                        labelText: 'System Role *',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.security),
                      ),
                      items: widget.roles
                          .map(
                            (r) => DropdownMenuItem(
                              value: r.id,
                              child: Text(r.roleName),
                            ),
                          )
                          .toList(),
                      onChanged: (v) => setState(() => _selectedRoleId = v),
                    ),
                    if (widget.user == null) ...[
                      const SizedBox(height: 12),
                      const Text(
                        "Note: This will create a user profile. In a production app, this would verify the email via Supabase Auth.",
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),

          // Footer
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
                  backgroundColor: Colors.indigo,
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
                    : Text(widget.user == null ? 'Save User' : 'Update User'),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// --- LOCAL MODELS ---

class AppUser {
  final String id;
  final String fullName;
  final String? email;
  final int roleId;
  final String roleName;

  AppUser({
    required this.id,
    required this.fullName,
    this.email,
    required this.roleId,
    required this.roleName,
  });

  factory AppUser.fromMap(Map<String, dynamic> map) {
    final roleData = map['roles'];
    return AppUser(
      id: map['id'].toString(), // Handle UUID or Int ID
      fullName: map['full_name'] ?? 'Unknown',
      email: map['email'],
      roleId: map['role_id'] ?? 0,
      roleName: roleData != null ? roleData['role_name'] : 'User',
    );
  }

  String get initials => fullName.isNotEmpty ? fullName[0].toUpperCase() : '?';
}

class RoleData {
  final int id;
  final String roleName;

  RoleData({required this.id, required this.roleName});

  factory RoleData.fromMap(Map<String, dynamic> map) {
    return RoleData(id: map['id'], roleName: map['role_name'] ?? 'Unknown');
  }
}
