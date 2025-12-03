import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'ui_app_shell.dart';
import 'shared/widgets.dart'; // Assumes EmptyState, etc.

class MasterDataScreen extends StatefulWidget {
  const MasterDataScreen({super.key});

  @override
  State<MasterDataScreen> createState() => _MasterDataScreenState();
}

class _MasterDataScreenState extends State<MasterDataScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    // 5 Tabs: Brands, AC Types | Job Types, Statuses, Client Types
    _tabController = TabController(length: 5, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AppShell(
      selectedIndex: 9, // Master Data Tab
      body: Container(
        color: const Color(0xFFF8FAFC),
        child: Column(
          children: [
            // --- HEADER ---
            Container(
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
              color: Colors.white,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Master Data Settings',
                    style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Manage brands, types, and view system definitions.',
                    style: TextStyle(color: Colors.grey),
                  ),
                  const SizedBox(height: 16),

                  // Standard Tab Bar (Blue Text + Underline)
                  TabBar(
                    controller: _tabController,
                    isScrollable: true,
                    labelColor: Colors.blue[700],
                    unselectedLabelColor: Colors.grey[600],
                    indicatorColor: Colors.blue[700],
                    indicatorWeight: 3,
                    labelStyle: const TextStyle(fontWeight: FontWeight.bold),
                    tabAlignment: TabAlignment.start,
                    tabs: const [
                      // EDITABLE
                      Tab(text: 'Brands'),
                      Tab(text: 'AC Types'),
                      // SYSTEM (Read Only)
                      Tab(text: 'Job Types'),
                      Tab(text: 'Statuses'),
                      Tab(text: 'Client Types'),
                    ],
                  ),
                ],
              ),
            ),
            const Divider(height: 1, thickness: 1, color: Color(0xFFE2E8F0)),

            // --- TAB CONTENT ---
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: const [
                  // 1. EDITABLE TABS
                  _EditableMasterTab(
                    tableName: 'brands',
                    nameField: 'brand_name',
                    label: 'Brand',
                    icon: Icons.sell,
                    color: Colors.blue,
                  ),
                  _EditableMasterTab(
                    tableName: 'aircon_types',
                    nameField: 'type_name',
                    label: 'Aircon Type',
                    icon: Icons.ac_unit,
                    color: Colors.teal,
                  ),

                  // 2. SYSTEM TABS (Read Only / Hardcoded Logic)
                  _SystemMasterTab(
                    tableName: 'job_types',
                    nameField: 'job_type_name',
                    label: 'Job Type',
                    icon: Icons.work,
                    color: Colors.purple,
                    description: "These define the core workflow logic.",
                  ),
                  _StaticSystemTab(
                    label: 'Job Status',
                    data: ['Pending', 'In Progress', 'Completed', 'Cancelled'],
                    icon: Icons.flag,
                    color: Colors.orange,
                  ),
                  _StaticSystemTab(
                    label: 'Customer Type',
                    data: ['B2B (Corporate)', 'B2C (Individual)'],
                    icon: Icons.people,
                    color: Colors.indigo,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ==============================================================================
// 1. EDITABLE TAB (For Brands & AC Types)
// ==============================================================================

class _EditableMasterTab extends StatefulWidget {
  final String tableName;
  final String nameField;
  final String label;
  final IconData icon;
  final MaterialColor color;

  const _EditableMasterTab({
    required this.tableName,
    required this.nameField,
    required this.label,
    required this.icon,
    required this.color,
  });

  @override
  State<_EditableMasterTab> createState() => _EditableMasterTabState();
}

class _EditableMasterTabState extends State<_EditableMasterTab> {
  final _supabase = Supabase.instance.client;
  bool _isLoading = true;
  List<Map<String, dynamic>> _data = [];
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _fetchData();
  }

  Future<void> _fetchData() async {
    setState(() => _isLoading = true);
    try {
      final res = await _supabase
          .from(widget.tableName)
          .select()
          .order(widget.nameField, ascending: true);

      if (mounted) {
        setState(() {
          _data = List<Map<String, dynamic>>.from(res);
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _addOrEdit({Map<String, dynamic>? item}) async {
    final TextEditingController controller = TextEditingController(
      text: item != null ? item[widget.nameField] : '',
    );

    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(
          item == null ? 'Add ${widget.label}' : 'Edit ${widget.label}',
        ),
        content: TextField(
          controller: controller,
          decoration: InputDecoration(
            labelText: '${widget.label} Name',
            border: const OutlineInputBorder(),
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            onPressed: () async {
              final val = controller.text.trim();
              if (val.isEmpty) return;

              try {
                if (item == null) {
                  await _supabase.from(widget.tableName).insert({
                    widget.nameField: val,
                  });
                } else {
                  await _supabase
                      .from(widget.tableName)
                      .update({widget.nameField: val})
                      .eq('id', item['id']);
                }
                if (mounted) {
                  Navigator.pop(ctx);
                  _fetchData();
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text("Saved successfully")),
                  );
                }
              } catch (e) {
                ScaffoldMessenger.of(
                  context,
                ).showSnackBar(SnackBar(content: Text("Error: $e")));
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: widget.color,
              foregroundColor: Colors.white,
            ),
            child: const Text("Save"),
          ),
        ],
      ),
    );
  }

  Future<void> _delete(int id) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Delete Item"),
        content: const Text("Are you sure? This cannot be undone."),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text("Cancel"),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text("Delete"),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await _supabase.from(widget.tableName).delete().eq('id', id);
        _fetchData();
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text("Cannot delete: Item might be in use."),
            ),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _data.where((item) {
      final name = item[widget.nameField].toString().toLowerCase();
      return name.contains(_searchQuery.toLowerCase());
    }).toList();

    final isMobile = MediaQuery.of(context).size.width < 800;

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          // Header Row with Search & Add Button
          Row(
            children: [
              Expanded(
                child: TextField(
                  onChanged: (v) => setState(() => _searchQuery = v),
                  decoration: InputDecoration(
                    hintText: "Search ${widget.label}s...",
                    prefixIcon: const Icon(Icons.search),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    filled: true,
                    fillColor: Colors.white,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 14,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              ElevatedButton.icon(
                onPressed: () => _addOrEdit(),
                icon: const Icon(Icons.add),
                label: Text("Add ${widget.label}"),
                style: ElevatedButton.styleFrom(
                  backgroundColor: widget.color,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 16,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Content
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : filtered.isEmpty
                ? Center(
                    child: Text(
                      "No ${widget.label}s found.",
                      style: const TextStyle(color: Colors.grey),
                    ),
                  )
                : isMobile
                // FIX: Mobile List with Scrolling Physics
                ? ListView.separated(
                    physics: const AlwaysScrollableScrollPhysics(),
                    itemCount: filtered.length,
                    separatorBuilder: (c, i) => const SizedBox(height: 12),
                    itemBuilder: (c, i) => _MobileCard(
                      item: filtered[i],
                      nameField: widget.nameField,
                      color: widget.color,
                      icon: widget.icon,
                      onEdit: () => _addOrEdit(item: filtered[i]),
                      onDelete: () => _delete(filtered[i]['id']),
                    ),
                  )
                // FIX: Desktop Table with Scrollable Container
                : _DesktopTable(
                    data: filtered,
                    nameField: widget.nameField,
                    color: widget.color,
                    icon: widget.icon,
                    onEdit: (item) => _addOrEdit(item: item),
                    onDelete: (id) => _delete(id),
                  ),
          ),
        ],
      ),
    );
  }
}

// ==============================================================================
// 2. SYSTEM TAB (For Job Types) - READ ONLY
// ==============================================================================

class _SystemMasterTab extends StatefulWidget {
  final String tableName;
  final String nameField;
  final String label;
  final IconData icon;
  final MaterialColor color;
  final String description;

  const _SystemMasterTab({
    required this.tableName,
    required this.nameField,
    required this.label,
    required this.icon,
    required this.color,
    required this.description,
  });

  @override
  State<_SystemMasterTab> createState() => _SystemMasterTabState();
}

class _SystemMasterTabState extends State<_SystemMasterTab> {
  final _supabase = Supabase.instance.client;
  List<Map<String, dynamic>> _data = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchData();
  }

  Future<void> _fetchData() async {
    final res = await _supabase
        .from(widget.tableName)
        .select()
        .order('id', ascending: true);

    if (mounted) {
      setState(() {
        _data = List<Map<String, dynamic>>.from(res);
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.amber[50],
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.amber[200]!),
            ),
            child: Row(
              children: [
                const Icon(Icons.lock, color: Colors.amber, size: 20),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    "System Definition: ${widget.description}",
                    style: TextStyle(color: Colors.amber[900], fontSize: 13),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.05),
                          blurRadius: 4,
                        ),
                      ],
                    ),
                    child: ListView.separated(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.all(8),
                      itemCount: _data.length,
                      separatorBuilder: (ctx, i) => const Divider(height: 1),
                      itemBuilder: (ctx, i) {
                        final item = _data[i];
                        return ListTile(
                          leading: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: widget.color.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Icon(
                              widget.icon,
                              size: 18,
                              color: widget.color,
                            ),
                          ),
                          title: Text(
                            item[widget.nameField],
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          subtitle: Text("ID: ${item['id']}"),
                          trailing: const Icon(
                            Icons.lock,
                            size: 16,
                            color: Colors.grey,
                          ),
                        );
                      },
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

// ==============================================================================
// 3. STATIC SYSTEM TAB (For Hardcoded Lists like Statuses)
// ==============================================================================

class _StaticSystemTab extends StatelessWidget {
  final String label;
  final List<String> data;
  final IconData icon;
  final MaterialColor color;

  const _StaticSystemTab({
    required this.label,
    required this.data,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.grey[100],
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.grey[300]!),
            ),
            child: const Row(
              children: [
                Icon(Icons.info_outline, color: Colors.grey, size: 20),
                SizedBox(width: 12),
                Expanded(
                  child: Text(
                    "These values are hardcoded into the system logic and cannot be changed.",
                    style: TextStyle(color: Colors.black54, fontSize: 13),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 4,
                  ),
                ],
              ),
              child: ListView.separated(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(8),
                itemCount: data.length,
                separatorBuilder: (ctx, i) => const Divider(height: 1),
                itemBuilder: (ctx, i) {
                  return ListTile(
                    leading: Icon(icon, size: 18, color: color),
                    title: Text(
                      data[i],
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    trailing: const Icon(
                      Icons.lock,
                      size: 16,
                      color: Colors.grey,
                    ),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ==============================================================================
// HELPER WIDGETS
// ==============================================================================

class _MobileCard extends StatelessWidget {
  final Map<String, dynamic> item;
  final String nameField;
  final MaterialColor color;
  final IconData icon;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _MobileCard({
    required this.item,
    required this.nameField,
    required this.color,
    required this.icon,
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
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              item[nameField],
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.edit, size: 18, color: Colors.grey),
            onPressed: onEdit,
          ),
          IconButton(
            icon: const Icon(Icons.delete, size: 18, color: Colors.red),
            onPressed: onDelete,
          ),
        ],
      ),
    );
  }
}

class _DesktopTable extends StatelessWidget {
  final List<Map<String, dynamic>> data;
  final String nameField;
  final MaterialColor color;
  final IconData icon;
  final Function(Map<String, dynamic>) onEdit;
  final Function(int) onDelete;

  const _DesktopTable({
    required this.data,
    required this.nameField,
    required this.color,
    required this.icon,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      // FIX: Added ClipRRect and SingleChildScrollView for scrolling
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: ConstrainedBox(
            constraints: const BoxConstraints(minWidth: double.infinity),
            child: DataTable(
              headingRowColor: MaterialStateProperty.all(Colors.grey[50]),
              columns: const [
                DataColumn(
                  label: Text(
                    "NAME",
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
                DataColumn(
                  label: Text(
                    "ID",
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
                DataColumn(
                  label: Text(
                    "ACTIONS",
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ],
              rows: data.map((item) {
                return DataRow(
                  cells: [
                    DataCell(
                      Row(
                        children: [
                          Icon(icon, size: 16, color: color),
                          const SizedBox(width: 12),
                          Text(
                            item[nameField],
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                        ],
                      ),
                    ),
                    DataCell(Text(item['id'].toString())),
                    DataCell(
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(
                              Icons.edit_outlined,
                              color: Colors.blue,
                            ),
                            onPressed: () => onEdit(item),
                            tooltip: "Edit",
                          ),
                          IconButton(
                            icon: const Icon(
                              Icons.delete_outline,
                              color: Colors.red,
                            ),
                            onPressed: () => onDelete(item['id']),
                            tooltip: "Delete",
                          ),
                        ],
                      ),
                    ),
                  ],
                );
              }).toList(),
            ),
          ),
        ),
      ),
    );
  }
}
