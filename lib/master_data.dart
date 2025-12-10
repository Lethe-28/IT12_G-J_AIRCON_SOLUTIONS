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
    // Reduced to 3 Tabs: Brands, AC Types, and a combined "System References"
    _tabController = TabController(length: 3, vsync: this);
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
                    'Manage system options and view reference definitions.',
                    style: TextStyle(color: Colors.grey),
                  ),
                  const SizedBox(height: 16),

                  // Standard Tab Bar
                  TabBar(
                    controller: _tabController,
                    isScrollable:
                        false, // Fixed width looks cleaner for 3 items
                    labelColor: Colors.blue[700],
                    unselectedLabelColor: Colors.grey[600],
                    indicatorColor: Colors.blue[700],
                    indicatorWeight: 3,
                    labelStyle: const TextStyle(fontWeight: FontWeight.bold),
                    tabs: const [
                      Tab(text: 'Brands'),
                      Tab(text: 'AC Types'),
                      Tab(
                        icon: Icon(Icons.lock_outline, size: 16),
                        text: 'System Ref',
                      ),
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
                  // 1. EDITABLE: Brands
                  _EditableMasterTab(
                    tableName: 'brands',
                    nameField: 'brand_name',
                    label: 'Brand',
                    icon: Icons.sell,
                    color: Colors.blue,
                  ),
                  // 2. EDITABLE: AC Types
                  _EditableMasterTab(
                    tableName: 'aircon_types',
                    nameField: 'type_name',
                    label: 'Aircon Type',
                    icon: Icons.ac_unit,
                    color: Colors.teal,
                  ),
                  // 3. READ-ONLY: System References (Combined)
                  _SystemReferenceTab(),
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
    final formKey = GlobalKey<FormState>();
    final TextEditingController controller = TextEditingController(
      text: item != null ? item[widget.nameField] : '',
    );

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: Text(
          item == null ? 'Add ${widget.label}' : 'Edit ${widget.label}',
        ),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: controller,
                autofocus: true,
                // VALIDATION: Required & Trim check
                validator: (v) {
                  if (v == null || v.trim().isEmpty) return 'Required';
                  return null;
                },
                decoration: InputDecoration(
                  label: RichText(
                    text: TextSpan(
                      text: '${widget.label} Name',
                      style: const TextStyle(color: Colors.grey, fontSize: 16),
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
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  filled: true,
                  fillColor: const Color(0xFFFAFAFA),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 14,
                  ),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            onPressed: () async {
              if (!formKey.currentState!.validate()) return;

              final val = controller.text.trim();

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
                    const SnackBar(
                      content: Text("Saved successfully"),
                      backgroundColor: Colors.green,
                    ),
                  );
                }
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text("Error: $e"),
                    backgroundColor: Colors.red,
                  ),
                );
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
              backgroundColor: Colors.red,
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
// 2. SYSTEM REFERENCE TAB (Combined Read-Only)
// ==============================================================================

class _SystemReferenceTab extends StatelessWidget {
  const _SystemReferenceTab();

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.amber[50],
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.amber[200]!),
            ),
            child: Row(
              children: [
                Icon(Icons.lock_outline, color: Colors.amber[800]),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "System Definitions",
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.amber[900],
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        "These values are hardcoded into the application logic and cannot be modified to ensure system stability.",
                        style: TextStyle(color: Colors.amber[900]),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Job Types Section
          _SystemExpansionTile(
            title: "Job Types",
            icon: Icons.work,
            color: Colors.purple,
            tableName: 'job_types',
            nameField: 'job_type_name',
          ),
          const SizedBox(height: 16),

          // Static Lists
          _StaticExpansionTile(
            title: "Job Statuses",
            icon: Icons.flag,
            color: Colors.orange,
            items: const ['Pending', 'In Progress', 'Completed', 'Cancelled'],
          ),
          const SizedBox(height: 16),

          _StaticExpansionTile(
            title: "Customer Types",
            icon: Icons.people,
            color: Colors.indigo,
            items: const ['B2B (Corporate)', 'B2C (Individual)'],
          ),
        ],
      ),
    );
  }
}

// Helper for DB-fetched system data
class _SystemExpansionTile extends StatefulWidget {
  final String title;
  final IconData icon;
  final MaterialColor color;
  final String tableName;
  final String nameField;

  const _SystemExpansionTile({
    required this.title,
    required this.icon,
    required this.color,
    required this.tableName,
    required this.nameField,
  });

  @override
  State<_SystemExpansionTile> createState() => _SystemExpansionTileState();
}

class _SystemExpansionTileState extends State<_SystemExpansionTile> {
  List<String> _items = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    Supabase.instance.client.from(widget.tableName).select().order('id').then((
      res,
    ) {
      if (mounted) {
        setState(() {
          _items = (res as List)
              .map((e) => e[widget.nameField].toString())
              .toList();
          _loading = false;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return _StaticExpansionTile(
      title: widget.title,
      icon: widget.icon,
      color: widget.color,
      items: _items,
      isLoading: _loading,
    );
  }
}

// Helper for Static Lists
class _StaticExpansionTile extends StatelessWidget {
  final String title;
  final IconData icon;
  final MaterialColor color;
  final List<String> items;
  final bool isLoading;

  const _StaticExpansionTile({
    required this.title,
    required this.icon,
    required this.color,
    required this.items,
    this.isLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: Color(0xFFE2E8F0)),
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          leading: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: color),
          ),
          title: Text(
            title,
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          subtitle: Text("${items.length} defined items"),
          children: [
            const Divider(height: 1),
            if (isLoading)
              const Padding(
                padding: EdgeInsets.all(20),
                child: Center(child: CircularProgressIndicator()),
              )
            else
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: items.length,
                separatorBuilder: (ctx, i) =>
                    const Divider(height: 1, indent: 16, endIndent: 16),
                itemBuilder: (ctx, i) => ListTile(
                  dense: true,
                  title: Text(items[i]),
                  leading: const Icon(
                    Icons.check_circle,
                    size: 16,
                    color: Colors.green,
                  ),
                  trailing: const Icon(
                    Icons.lock,
                    size: 14,
                    color: Colors.grey,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// ==============================================================================
// SHARED WIDGETS (Cards/Tables)
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
