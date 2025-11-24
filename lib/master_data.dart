import 'package:flutter/material.dart';
import 'data/app_state.dart';
import 'data/models.dart';
import 'ui_app_shell.dart';
import 'shared_header.dart';

class MasterDataScreen extends StatefulWidget {
  const MasterDataScreen({super.key});

  @override
  State<MasterDataScreen> createState() => _MasterDataScreenState();
}

class _MasterDataScreenState extends State<MasterDataScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
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
      selectedIndex: AppState.currentRole == UserRole.admin ? 9 : 1,
      body: Column(
        children: [
          SharedHeader(
            welcomeText: 'Master Data Settings',
            subtitleText: 'Maintain brands, types, statuses, and references.',
            notificationCount: 0,
            showGreeting: false,
          ),
          Expanded(
            child: Column(
              children: [
                Container(
                  color: Colors.white,
                  child: TabBar(
                    controller: _tabController,
                    isScrollable: true,
                    tabs: const [
                      Tab(text: 'Brands'),
                      Tab(text: 'Aircon Types'),
                      Tab(text: 'Job Types'),
                      Tab(text: 'Job Statuses'),
                      Tab(text: 'Customer Types'),
                    ],
                  ),
                ),
                Expanded(
                  child: TabBarView(
                    controller: _tabController,
                    children: const [
                      _BrandsTab(),
                      _AirconTypesTab(),
                      _JobTypesTab(),
                      _JobStatusesTab(),
                      _CustomerTypesTab(),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// Brands Tab
class _BrandsTab extends StatefulWidget {
  const _BrandsTab();

  @override
  State<_BrandsTab> createState() => _BrandsTabState();
}

class _BrandsTabState extends State<_BrandsTab> {
  final List<BrandData> _brands = [];
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _seedData();
  }

  void _seedData() {
    _brands.addAll([
      const BrandData(id: 1, name: 'Daikin'),
      const BrandData(id: 2, name: 'Carrier'),
      const BrandData(id: 3, name: 'Panasonic'),
      const BrandData(id: 4, name: 'LG'),
      const BrandData(id: 5, name: 'Samsung'),
      const BrandData(id: 6, name: 'Mitsubishi Electric'),
      const BrandData(id: 7, name: 'Toshiba'),
    ]);
  }

  List<BrandData> get _filteredBrands {
    if (_searchQuery.isEmpty) return _brands;
    final q = _searchQuery.toLowerCase();
    return _brands.where((b) => b.name.toLowerCase().contains(q)).toList();
  }

  void _onAddOrEdit({BrandData? existing}) async {
    final BrandData? result = await showDialog<BrandData>(
      context: context,
      builder: (context) => _BrandDialog(brand: existing),
    );
    if (result == null) return;

    setState(() {
      if (existing == null) {
        final newId = _brands.isNotEmpty ? _brands.last.id + 1 : 1;
        _brands.add(BrandData(id: newId, name: result.name));
      } else {
        final index = _brands.indexWhere((b) => b.id == existing.id);
        if (index != -1) {
          _brands[index] = result;
        }
      }
    });
  }

  void _onDelete(BrandData brand) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Brand'),
        content: Text('Are you sure you want to delete "${brand.name}"?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Delete')),
        ],
      ),
    );
    if (confirmed != true) return;
    setState(() {
      _brands.removeWhere((b) => b.id == brand.id);
    });
  }

  @override
  Widget build(BuildContext context) {
    final brands = _filteredBrands;
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text('Brands', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w700)),
              const Spacer(),
              ElevatedButton.icon(
                onPressed: () => _onAddOrEdit(),
                icon: const Icon(Icons.add),
                label: const Text('Add Brand'),
              ),
            ],
          ),
          const SizedBox(height: 16),
          TextField(
            onChanged: (v) => setState(() => _searchQuery = v),
            decoration: InputDecoration(
              hintText: 'Search brands...',
              prefixIcon: const Icon(Icons.search),
              filled: true,
              fillColor: Colors.white,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide.none,
              ),
            ),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: Container(
              decoration: _cardDeco(),
              child: ListView.builder(
                itemCount: brands.length,
                itemBuilder: (context, index) {
                  final brand = brands[index];
                  return ListTile(
                    title: Text(brand.name, style: const TextStyle(fontWeight: FontWeight.w600)),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.edit_outlined, size: 18),
                          onPressed: () => _onAddOrEdit(existing: brand),
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete_outline, size: 18, color: Colors.red),
                          onPressed: () => _onDelete(brand),
                        ),
                      ],
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

  BoxDecoration _cardDeco() => BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      );
}

class _BrandDialog extends StatefulWidget {
  final BrandData? brand;
  const _BrandDialog({this.brand});

  @override
  State<_BrandDialog> createState() => _BrandDialogState();
}

class _BrandDialogState extends State<_BrandDialog> {
  late TextEditingController _nameController;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.brand?.name ?? '');
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  void _submit() {
    if (_nameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Brand name is required')),
      );
      return;
    }
    Navigator.of(context).pop(BrandData(id: widget.brand?.id ?? 0, name: _nameController.text.trim()));
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: Container(
        width: 400,
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              widget.brand == null ? 'Add Brand' : 'Edit Brand',
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 20),
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(labelText: 'Brand Name *'),
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
                ElevatedButton(onPressed: _submit, child: const Text('Save')),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// Aircon Types Tab
class _AirconTypesTab extends StatefulWidget {
  const _AirconTypesTab();

  @override
  State<_AirconTypesTab> createState() => _AirconTypesTabState();
}

class _AirconTypesTabState extends State<_AirconTypesTab> {
  final List<AirconTypeData> _types = [];
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _seedData();
  }

  void _seedData() {
    _types.addAll([
      const AirconTypeData(id: 1, typeName: 'Split Type'),
      const AirconTypeData(id: 2, typeName: 'Window Type'),
      const AirconTypeData(id: 3, typeName: 'Centralized'),
      const AirconTypeData(id: 4, typeName: 'Portable'),
      const AirconTypeData(id: 5, typeName: 'Cassette'),
      const AirconTypeData(id: 6, typeName: 'Ducted'),
    ]);
  }

  List<AirconTypeData> get _filteredTypes {
    if (_searchQuery.isEmpty) return _types;
    final q = _searchQuery.toLowerCase();
    return _types.where((t) => t.typeName.toLowerCase().contains(q)).toList();
  }

  void _onAddOrEdit({AirconTypeData? existing}) async {
    final AirconTypeData? result = await showDialog<AirconTypeData>(
      context: context,
      builder: (context) => _AirconTypeDialog(type: existing),
    );
    if (result == null) return;

    setState(() {
      if (existing == null) {
        final newId = _types.isNotEmpty ? _types.last.id + 1 : 1;
        _types.add(AirconTypeData(id: newId, typeName: result.typeName));
      } else {
        final index = _types.indexWhere((t) => t.id == existing.id);
        if (index != -1) {
          _types[index] = result;
        }
      }
    });
  }

  void _onDelete(AirconTypeData type) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Aircon Type'),
        content: Text('Are you sure you want to delete "${type.typeName}"?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Delete')),
        ],
      ),
    );
    if (confirmed != true) return;
    setState(() {
      _types.removeWhere((t) => t.id == type.id);
    });
  }

  @override
  Widget build(BuildContext context) {
    final types = _filteredTypes;
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text('Aircon Types', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w700)),
              const Spacer(),
              ElevatedButton.icon(
                onPressed: () => _onAddOrEdit(),
                icon: const Icon(Icons.add),
                label: const Text('Add Type'),
              ),
            ],
          ),
          const SizedBox(height: 16),
          TextField(
            onChanged: (v) => setState(() => _searchQuery = v),
            decoration: InputDecoration(
              hintText: 'Search aircon types...',
              prefixIcon: const Icon(Icons.search),
              filled: true,
              fillColor: Colors.white,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide.none,
              ),
            ),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: Container(
              decoration: _cardDeco(),
              child: ListView.builder(
                itemCount: types.length,
                itemBuilder: (context, index) {
                  final type = types[index];
                  return ListTile(
                    title: Text(type.typeName, style: const TextStyle(fontWeight: FontWeight.w600)),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.edit_outlined, size: 18),
                          onPressed: () => _onAddOrEdit(existing: type),
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete_outline, size: 18, color: Colors.red),
                          onPressed: () => _onDelete(type),
                        ),
                      ],
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

  BoxDecoration _cardDeco() => BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      );
}

class _AirconTypeDialog extends StatefulWidget {
  final AirconTypeData? type;
  const _AirconTypeDialog({this.type});

  @override
  State<_AirconTypeDialog> createState() => _AirconTypeDialogState();
}

class _AirconTypeDialogState extends State<_AirconTypeDialog> {
  late TextEditingController _nameController;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.type?.typeName ?? '');
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  void _submit() {
    if (_nameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Type name is required')),
      );
      return;
    }
    Navigator.of(context).pop(AirconTypeData(id: widget.type?.id ?? 0, typeName: _nameController.text.trim()));
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: Container(
        width: 400,
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              widget.type == null ? 'Add Aircon Type' : 'Edit Aircon Type',
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 20),
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(labelText: 'Type Name *'),
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
                ElevatedButton(onPressed: _submit, child: const Text('Save')),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// Job Types Tab
class _JobTypesTab extends StatefulWidget {
  const _JobTypesTab();

  @override
  State<_JobTypesTab> createState() => _JobTypesTabState();
}

class _JobTypesTabState extends State<_JobTypesTab> {
  final List<JobTypeData> _jobTypes = [];
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _seedData();
  }

  void _seedData() {
    _jobTypes.addAll([
      const JobTypeData(id: 1, jobType: 'Installation'),
      const JobTypeData(id: 2, jobType: 'Maintenance'),
      const JobTypeData(id: 3, jobType: 'Repair'),
      const JobTypeData(id: 4, jobType: 'Cleaning'),
      const JobTypeData(id: 5, jobType: 'Inspection'),
    ]);
  }

  List<JobTypeData> get _filteredJobTypes {
    if (_searchQuery.isEmpty) return _jobTypes;
    final q = _searchQuery.toLowerCase();
    return _jobTypes.where((j) => j.jobType.toLowerCase().contains(q)).toList();
  }

  void _onAddOrEdit({JobTypeData? existing}) async {
    final JobTypeData? result = await showDialog<JobTypeData>(
      context: context,
      builder: (context) => _JobTypeDialog(jobType: existing),
    );
    if (result == null) return;

    setState(() {
      if (existing == null) {
        final newId = _jobTypes.isNotEmpty ? _jobTypes.last.id + 1 : 1;
        _jobTypes.add(JobTypeData(id: newId, jobType: result.jobType));
      } else {
        final index = _jobTypes.indexWhere((j) => j.id == existing.id);
        if (index != -1) {
          _jobTypes[index] = result;
        }
      }
    });
  }

  void _onDelete(JobTypeData jobType) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Job Type'),
        content: Text('Are you sure you want to delete "${jobType.jobType}"?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Delete')),
        ],
      ),
    );
    if (confirmed != true) return;
    setState(() {
      _jobTypes.removeWhere((j) => j.id == jobType.id);
    });
  }

  @override
  Widget build(BuildContext context) {
    final jobTypes = _filteredJobTypes;
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text('Job Types', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w700)),
              const Spacer(),
              ElevatedButton.icon(
                onPressed: () => _onAddOrEdit(),
                icon: const Icon(Icons.add),
                label: const Text('Add Job Type'),
              ),
            ],
          ),
          const SizedBox(height: 16),
          TextField(
            onChanged: (v) => setState(() => _searchQuery = v),
            decoration: InputDecoration(
              hintText: 'Search job types...',
              prefixIcon: const Icon(Icons.search),
              filled: true,
              fillColor: Colors.white,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide.none,
              ),
            ),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: Container(
              decoration: _cardDeco(),
              child: ListView.builder(
                itemCount: jobTypes.length,
                itemBuilder: (context, index) {
                  final jobType = jobTypes[index];
                  return ListTile(
                    title: Text(jobType.jobType, style: const TextStyle(fontWeight: FontWeight.w600)),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.edit_outlined, size: 18),
                          onPressed: () => _onAddOrEdit(existing: jobType),
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete_outline, size: 18, color: Colors.red),
                          onPressed: () => _onDelete(jobType),
                        ),
                      ],
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

  BoxDecoration _cardDeco() => BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      );
}

class _JobTypeDialog extends StatefulWidget {
  final JobTypeData? jobType;
  const _JobTypeDialog({this.jobType});

  @override
  State<_JobTypeDialog> createState() => _JobTypeDialogState();
}

class _JobTypeDialogState extends State<_JobTypeDialog> {
  late TextEditingController _nameController;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.jobType?.jobType ?? '');
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  void _submit() {
    if (_nameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Job type name is required')),
      );
      return;
    }
    Navigator.of(context).pop(JobTypeData(id: widget.jobType?.id ?? 0, jobType: _nameController.text.trim()));
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: Container(
        width: 400,
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              widget.jobType == null ? 'Add Job Type' : 'Edit Job Type',
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 20),
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(labelText: 'Job Type Name *'),
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
                ElevatedButton(onPressed: _submit, child: const Text('Save')),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// Job Statuses Tab
class _JobStatusesTab extends StatefulWidget {
  const _JobStatusesTab();

  @override
  State<_JobStatusesTab> createState() => _JobStatusesTabState();
}

class _JobStatusesTabState extends State<_JobStatusesTab> {
  final List<JobStatusData> _statuses = [];
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _seedData();
  }

  void _seedData() {
    _statuses.addAll([
      const JobStatusData(id: 1, status: 'Pending'),
      const JobStatusData(id: 2, status: 'In Progress'),
      const JobStatusData(id: 3, status: 'Completed'),
      const JobStatusData(id: 4, status: 'Cancelled'),
      const JobStatusData(id: 5, status: 'On Hold'),
    ]);
  }

  List<JobStatusData> get _filteredStatuses {
    if (_searchQuery.isEmpty) return _statuses;
    final q = _searchQuery.toLowerCase();
    return _statuses.where((s) => s.status.toLowerCase().contains(q)).toList();
  }

  void _onAddOrEdit({JobStatusData? existing}) async {
    final JobStatusData? result = await showDialog<JobStatusData>(
      context: context,
      builder: (context) => _JobStatusDialog(status: existing),
    );
    if (result == null) return;

    setState(() {
      if (existing == null) {
        final newId = _statuses.isNotEmpty ? _statuses.last.id + 1 : 1;
        _statuses.add(JobStatusData(id: newId, status: result.status));
      } else {
        final index = _statuses.indexWhere((s) => s.id == existing.id);
        if (index != -1) {
          _statuses[index] = result;
        }
      }
    });
  }

  void _onDelete(JobStatusData status) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Job Status'),
        content: Text('Are you sure you want to delete "${status.status}"?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Delete')),
        ],
      ),
    );
    if (confirmed != true) return;
    setState(() {
      _statuses.removeWhere((s) => s.id == status.id);
    });
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'pending':
        return Colors.orange;
      case 'in progress':
        return Colors.blue;
      case 'completed':
        return Colors.green;
      case 'cancelled':
        return Colors.red;
      case 'on hold':
        return Colors.grey;
      default:
        return Colors.black54;
    }
  }

  @override
  Widget build(BuildContext context) {
    final statuses = _filteredStatuses;
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text('Job Statuses', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w700)),
              const Spacer(),
              ElevatedButton.icon(
                onPressed: () => _onAddOrEdit(),
                icon: const Icon(Icons.add),
                label: const Text('Add Status'),
              ),
            ],
          ),
          const SizedBox(height: 16),
          TextField(
            onChanged: (v) => setState(() => _searchQuery = v),
            decoration: InputDecoration(
              hintText: 'Search statuses...',
              prefixIcon: const Icon(Icons.search),
              filled: true,
              fillColor: Colors.white,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide.none,
              ),
            ),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: Container(
              decoration: _cardDeco(),
              child: ListView.builder(
                itemCount: statuses.length,
                itemBuilder: (context, index) {
                  final status = statuses[index];
                  final color = _getStatusColor(status.status);
                  return ListTile(
                    leading: Container(
                      width: 12,
                      height: 12,
                      decoration: BoxDecoration(
                        color: color,
                        shape: BoxShape.circle,
                      ),
                    ),
                    title: Text(status.status, style: const TextStyle(fontWeight: FontWeight.w600)),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.edit_outlined, size: 18),
                          onPressed: () => _onAddOrEdit(existing: status),
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete_outline, size: 18, color: Colors.red),
                          onPressed: () => _onDelete(status),
                        ),
                      ],
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

  BoxDecoration _cardDeco() => BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      );
}

class _JobStatusDialog extends StatefulWidget {
  final JobStatusData? status;
  const _JobStatusDialog({this.status});

  @override
  State<_JobStatusDialog> createState() => _JobStatusDialogState();
}

class _JobStatusDialogState extends State<_JobStatusDialog> {
  late TextEditingController _nameController;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.status?.status ?? '');
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  void _submit() {
    if (_nameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Status name is required')),
      );
      return;
    }
    Navigator.of(context).pop(JobStatusData(id: widget.status?.id ?? 0, status: _nameController.text.trim()));
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: Container(
        width: 400,
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              widget.status == null ? 'Add Job Status' : 'Edit Job Status',
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 20),
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(labelText: 'Status Name *'),
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
                ElevatedButton(onPressed: _submit, child: const Text('Save')),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// Customer Types Tab
class _CustomerTypesTab extends StatefulWidget {
  const _CustomerTypesTab();

  @override
  State<_CustomerTypesTab> createState() => _CustomerTypesTabState();
}

class _CustomerTypesTabState extends State<_CustomerTypesTab> {
  final List<CustomerTypeData> _customerTypes = [];

  @override
  void initState() {
    super.initState();
    _seedData();
  }

  void _seedData() {
    _customerTypes.addAll([
      const CustomerTypeData(id: 1, type: CustomerTypeKind.b2b),
      const CustomerTypeData(id: 2, type: CustomerTypeKind.b2c),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Customer Types', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w700)),
          const SizedBox(height: 16),
          Container(
            decoration: _cardDeco(),
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Customer Types are predefined system values:',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 16),
                ..._customerTypes.map((ct) => ListTile(
                      leading: Container(
                        width: 12,
                        height: 12,
                        decoration: BoxDecoration(
                          color: ct.type == CustomerTypeKind.b2b ? Colors.blue : Colors.green,
                          shape: BoxShape.circle,
                        ),
                      ),
                      title: Text(
                        ct.type == CustomerTypeKind.b2b ? 'B2B - Business to Business' : 'B2C - Business to Customer',
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      subtitle: Text('ID: ${ct.id}'),
                    )),
              ],
            ),
          ),
        ],
      ),
    );
  }

  BoxDecoration _cardDeco() => BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      );
}

