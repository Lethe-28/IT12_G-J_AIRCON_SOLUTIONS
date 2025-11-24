import 'package:flutter/material.dart';
import 'data/app_state.dart';
import 'data/models.dart';
import 'ui_app_shell.dart';
import 'calendar_view.dart';

// --- Data Classes ---

class JobOrderTechnician {
  final TechnicianData technician;
  final String role;

  JobOrderTechnician({required this.technician, this.role = 'Technician'});
}

class JobOrderAircon {
  final AirconData aircon;
  JobOrderAircon({required this.aircon});
}

class JobOrderServiceItem {
  final ServiceItemData serviceItem;
  final int quantity;
  final double actualPrice;

  JobOrderServiceItem({
    required this.serviceItem,
    required this.quantity,
    required this.actualPrice,
  });
}

class JobOrder {
  final String id;
  String clientName;
  String jobType;
  String technician;
  DateTime dateTime;
  DateTime? dateStarted;
  DateTime? dateCompleted;
  String duration;
  String location;
  String status;
  String workType;
  String customerType;
  String segment;
  String customerStatus;
  int numberOfUnits;
  String unitDescription;
  String customerAddress;
  String customerContact;
  String brand;
  String unitLocation;
  String installationDetails;
  String workNotes;
  String followUpSchedule;
  
  List<JobOrderTechnician> technicians = [];
  List<JobOrderAircon> aircons = [];
  List<JobOrderServiceItem> serviceItems = [];

  JobOrder({
    required this.id,
    required this.clientName,
    required this.jobType,
    required this.technician,
    required this.dateTime,
    DateTime? dateStarted,
    this.dateCompleted,
    required this.duration,
    required this.location,
    required this.status,
    this.workType = '',
    this.customerType = '',
    this.segment = '',
    this.customerStatus = '',
    this.numberOfUnits = 0,
    this.unitDescription = '',
    this.customerAddress = '',
    this.customerContact = '',
    this.brand = '',
    this.unitLocation = '',
    this.installationDetails = '',
    this.workNotes = '',
    this.followUpSchedule = '',
    List<JobOrderTechnician>? technicians,
    List<JobOrderAircon>? aircons,
    List<JobOrderServiceItem>? serviceItems,
  }) : technicians = technicians ?? [],
       aircons = aircons ?? [],
       serviceItems = serviceItems ?? [],
       dateStarted = dateStarted ?? dateTime;
}

// --- Main Screen ---

class SchedulingScreen extends StatefulWidget {
  const SchedulingScreen({super.key});

  @override
  State<SchedulingScreen> createState() => _SchedulingScreenState();
}

class _SchedulingScreenState extends State<SchedulingScreen> {
  String _searchQuery = '';
  final Set<String> _selectedOrderIds = {};
  bool get _isServiceManager => AppState.currentRole == UserRole.serviceManager;
  String? _hoveredOrderId;
  int _currentPage = 0;
  final int _rowsPerPage = 10;
  bool _isTableView = true; 

  // Design Constants
  static const Color kPrimaryColor = Color(0xFF2563EB);
  static const Color kTextPrimary = Color(0xFF1E293B);
  static const Color kTextSecondary = Color(0xFF64748B);
  static const Color kBorderColor = Color(0xFFE2E8F0);

  List<JobOrder> get _orders {
    try {
      final shared = AppState.sharedJobOrders;
      if (shared.isEmpty) return [];
      return shared.map((o) {
        try {
          return o as JobOrder;
        } catch (e) {
          return null;
        }
      }).whereType<JobOrder>().toList();
    } catch (e) {
      return [];
    }
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _seedData();
    });
  }

  void _seedData() {
    if (!AppState.jobOrdersSeeded && AppState.sharedJobOrders.isEmpty) {
      final seedOrders = [
        JobOrder(
          id: 'JO-2025-001',
          clientName: 'ABC Corporation',
          jobType: 'Installation',
          technician: 'John Doe',
          dateTime: DateTime(2025, 11, 10, 9, 0),
          dateStarted: DateTime(2025, 11, 1),
          dateCompleted: DateTime(2025, 11, 6),
          duration: '2 hours',
          location: 'Makati City',
          status: 'In progress',
          workType: 'Installation',
          followUpSchedule: 'February',
          brand: 'Daikin',
          segment: 'B2B',
        ),
        JobOrder(
          id: 'JO-2025-002',
          clientName: 'XYZ Retail Store',
          jobType: 'Maintenance',
          technician: 'Jane Smith',
          dateTime: DateTime(2025, 11, 10, 11, 30),
          dateStarted: DateTime(2025, 11, 3),
          dateCompleted: DateTime(2025, 11, 3),
          duration: '1.5 hours',
          location: 'Quezon City',
          status: 'Pending',
          workType: 'PM',
          customerAddress: '123 Main St.',
          segment: 'B2C',
        ),
      ];
      AppState.sharedJobOrders.addAll(seedOrders);
      AppState.setJobOrdersSeeded(true);
      if (mounted) setState(() {});
    }
  }

  void _onAddOrEdit({JobOrder? existing}) async {
    final JobOrder? result = await showDialog<JobOrder>(
      context: context,
      builder: (context) => _JobOrderDialog(order: existing),
    );
    if (result == null) return;

    setState(() {
      if (existing == null) {
        AppState.sharedJobOrders.add(result);
      } else {
        final index = AppState.sharedJobOrders.indexWhere((o) => (o as JobOrder).id == existing.id);
        if (index != -1) {
          AppState.sharedJobOrders[index] = result;
        }
      }
    });
  }

  void _onViewDetails(JobOrder order) {
    showDialog(
      context: context,
      builder: (context) => _JobOrderDetailsDialog(order: order),
    );
  }

  void _onArchive(JobOrder order) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Archive Job Order'),
        content: Text('Are you sure you want to archive ${order.id}?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(context, true), 
            style: TextButton.styleFrom(foregroundColor: Colors.orange),
            child: const Text('Archive')
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    setState(() {
      AppState.sharedJobOrders.removeWhere((o) => (o as JobOrder).id == order.id);
      _selectedOrderIds.remove(order.id);
    });
    if (mounted) {
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${order.id} has been archived'),
          backgroundColor: Colors.orange[800],
          behavior: SnackBarBehavior.floating,
          width: 300,
        ),
      );
    }
  }

  void _onCheckboxToggle(String joNumber, bool selected) {
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    if (_selectedOrderIds.isEmpty) return;

    final isSingleSelection = _selectedOrderIds.length == 1;
    final lastSelectedId = _selectedOrderIds.last;
    final jobOrder = _orders.firstWhere((o) => o.id == lastSelectedId);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Text(isSingleSelection 
              ? 'JO $lastSelectedId selected' 
              : '${_selectedOrderIds.length} items selected'),
            const Spacer(),
            if (isSingleSelection)
              TextButton(
                onPressed: () {
                  ScaffoldMessenger.of(context).hideCurrentSnackBar();
                  _onAddOrEdit(existing: jobOrder);
                },
                child: const Text('Edit', style: TextStyle(color: Colors.blueAccent, fontWeight: FontWeight.bold)),
              ),
            const SizedBox(width: 8),
            TextButton(
              onPressed: () {
                ScaffoldMessenger.of(context).hideCurrentSnackBar();
                _onArchive(jobOrder); 
              },
              child: Text(isSingleSelection ? 'Archive' : 'Archive All', 
                style: const TextStyle(color: Colors.orangeAccent, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
        behavior: SnackBarBehavior.floating,
        width: 450,
        backgroundColor: const Color(0xFF1E293B),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        duration: const Duration(seconds: 6),
      ),
    );
  }

  List<JobOrder> get _filteredOrders {
    if (_searchQuery.isEmpty) return _orders;
    final q = _searchQuery.toLowerCase();
    return _orders
        .where((o) =>
            o.clientName.toLowerCase().contains(q) ||
            o.technician.toLowerCase().contains(q) ||
            o.id.toLowerCase().contains(q))
        .toList();
  }

  String _formatDate(DateTime? dt) {
    if (dt == null) return '-';
    return '${dt.month.toString().padLeft(2,'0')}/${dt.day.toString().padLeft(2,'0')}/${dt.year}';
  }

  String _formatDateRange(DateTime? start, DateTime? end) {
    final s = _formatDate(start);
    final e = end != null ? _formatDate(end) : 'Ongoing';
    return '$s - $e';
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filteredOrders;

    return AppShell(
      selectedIndex: 1,
      body: Container(
        color: const Color(0xFFF8FAFC),
        child: Column(
          children: [
            // Header
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
              color: Colors.white,
              width: double.infinity,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Job Orders & Scheduling',
                    style: TextStyle(fontSize: 24, fontWeight: FontWeight.w700, color: kTextPrimary, letterSpacing: -0.5),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Manage deployments, track progress, and view schedule.',
                    style: TextStyle(fontSize: 14, color: kTextSecondary),
                  ),
                ],
              ),
            ),
            const Divider(height: 1, color: kBorderColor),
            
            // Content
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(32),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildStatsCards(),
                    const SizedBox(height: 32),
                    _buildToolbar(),
                    const SizedBox(height: 16),
                    _isTableView 
                      ? _buildJobTable(filtered)
                      : _buildJobCards(filtered),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatsCards() {
    final pending = _orders.where((o) => o.status.toLowerCase() == 'pending').length;
    final inProgress = _orders.where((o) => o.status.toLowerCase() == 'in progress').length;
    final completed = _orders.where((o) => o.status.toLowerCase() == 'completed').length;

    return LayoutBuilder(builder: (context, constraints) {
      final isMobile = constraints.maxWidth < 800;
      final width = isMobile ? constraints.maxWidth : (constraints.maxWidth - 48) / 3;

      return Wrap(
        spacing: 24,
        runSpacing: 16,
        children: [
          _StatCard(
            title: 'Open Jobs',
            value: pending.toString(),
            icon: Icons.pending_actions_rounded,
            color: Colors.orange,
            width: width,
          ),
          _StatCard(
            title: 'In Progress',
            value: inProgress.toString(),
            icon: Icons.engineering_rounded,
            color: kPrimaryColor,
            width: width,
          ),
          _StatCard(
            title: 'Completed (30d)',
            value: completed.toString(),
            icon: Icons.verified_rounded,
            color: Colors.green,
            width: width,
          ),
        ],
      );
    });
  }

  Widget _buildToolbar() {
    return Row(
      children: [
        Container(
          decoration: BoxDecoration(
            color: const Color(0xFFE2E8F0),
            borderRadius: BorderRadius.circular(8),
          ),
          padding: const EdgeInsets.all(2),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _ViewToggleButton(
                label: 'Table', 
                icon: Icons.table_chart_outlined,
                isSelected: _isTableView,
                onTap: () => setState(() => _isTableView = true),
              ),
              _ViewToggleButton(
                label: 'Cards', 
                icon: Icons.grid_view_outlined,
                isSelected: !_isTableView,
                onTap: () => setState(() => _isTableView = false),
              ),
            ],
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Container(
            height: 40,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: kBorderColor),
            ),
            child: TextField(
              onChanged: (v) => setState(() => _searchQuery = v),
              style: const TextStyle(fontSize: 14),
              decoration: const InputDecoration(
                hintText: 'Search client, JO number...',
                hintStyle: TextStyle(color: kTextSecondary, fontSize: 13),
                prefixIcon: Icon(Icons.search, color: kTextSecondary, size: 18),
                border: InputBorder.none,
                contentPadding: EdgeInsets.symmetric(vertical: 10),
              ),
            ),
          ),
        ),
        const SizedBox(width: 16),
        _ActionButton(
          label: 'Calendar',
          icon: Icons.calendar_month,
          onPressed: () {
             showDialog(
                context: context,
                builder: (context) => CalendarViewScreen(jobOrders: _orders),
              );
          },
        ),
        const SizedBox(width: 8),
        _ActionButton(
          label: 'Add Job Order',
          icon: Icons.add,
          isPrimary: true,
          onPressed: () => _onAddOrEdit(),
        ),
      ],
    );
  }

  Widget _buildJobTable(List<JobOrder> orders) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: kBorderColor),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 8, offset: const Offset(0, 4)),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Theme(
            data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
            child: DataTable(
              headingRowColor: MaterialStateProperty.all(const Color(0xFFF8FAFC)),
              headingRowHeight: 48,
              dataRowMinHeight: 60,
              dataRowMaxHeight: 68,
              horizontalMargin: 24,
              columnSpacing: 24,
              columns: const [
                DataColumn(label: Text('CHECK', style: TextStyle(fontWeight: FontWeight.w700, color: kTextPrimary, fontSize: 11))),
                DataColumn(label: Text('JO NUMBER', style: TextStyle(fontWeight: FontWeight.w700, color: kTextPrimary, fontSize: 11))),
                DataColumn(label: Text('CLIENT', style: TextStyle(fontWeight: FontWeight.w700, color: kTextPrimary, fontSize: 11))),
                DataColumn(label: Text('JOB / WORK TYPE', style: TextStyle(fontWeight: FontWeight.w700, color: kTextPrimary, fontSize: 11))),
                DataColumn(label: Text('DATE STARTED / COMPLETED', style: TextStyle(fontWeight: FontWeight.w700, color: kTextPrimary, fontSize: 11))),
                DataColumn(label: Text('LOCATION', style: TextStyle(fontWeight: FontWeight.w700, color: kTextPrimary, fontSize: 11))),
                DataColumn(label: Text('STATUS', style: TextStyle(fontWeight: FontWeight.w700, color: kTextPrimary, fontSize: 11))),
                DataColumn(label: Text('ACTIONS', style: TextStyle(fontWeight: FontWeight.w700, color: kTextPrimary, fontSize: 11))),
              ],
              rows: orders.map((order) => _buildDataRow(order)).toList(),
            ),
          ),
          if (orders.isEmpty)
            const Padding(
              padding: EdgeInsets.all(40),
              child: Center(child: Text("No job orders found.", style: TextStyle(color: kTextSecondary))),
            ),
        ],
      ),
    );
  }

  DataRow _buildDataRow(JobOrder order) {
    final isSelected = _selectedOrderIds.contains(order.id);
    
    return DataRow(
      color: MaterialStateProperty.resolveWith((states) {
        if (states.contains(MaterialState.hovered)) return const Color(0xFFF1F5F9);
        return Colors.white;
      }),
      cells: [
        // Checkbox
        DataCell(
          SizedBox(
            width: 24,
            height: 24,
            child: Checkbox(
              value: isSelected,
              activeColor: kPrimaryColor,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
              onChanged: (v) {
                setState(() {
                  if (v == true) {
                    _selectedOrderIds.add(order.id);
                  } else {
                    _selectedOrderIds.remove(order.id);
                  }
                });
                _onCheckboxToggle(order.id, v == true);
              },
            ),
          ),
        ),
        DataCell(Text(order.id, style: const TextStyle(fontWeight: FontWeight.w600, color: kTextPrimary, fontSize: 13))),
        DataCell(
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(order.clientName, style: const TextStyle(fontWeight: FontWeight.w500, color: kTextPrimary, fontSize: 13)),
              if (order.segment.isNotEmpty)
                Text(order.segment, style: const TextStyle(fontSize: 11, color: kTextSecondary)),
            ],
          ),
        ),
        DataCell(
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(order.jobType, style: const TextStyle(color: kTextPrimary, fontSize: 13)),
              if (order.workType.isNotEmpty)
                Text(order.workType, style: const TextStyle(fontSize: 11, color: kTextSecondary)),
            ],
          ),
        ),
        DataCell(Text(_formatDateRange(order.dateStarted, order.dateCompleted), style: const TextStyle(color: kTextPrimary, fontSize: 13))),
        DataCell(Text(order.location, style: const TextStyle(color: kTextPrimary, fontSize: 13))),
        DataCell(_StatusBadge(status: order.status)),
        DataCell(
          TextButton(
            onPressed: () => _onViewDetails(order),
            child: const Text('See More', style: TextStyle(color: kPrimaryColor, fontSize: 12, fontWeight: FontWeight.w600)),
          )
        ),
      ],
    );
  }

  Widget _buildJobCards(List<JobOrder> orders) {
    if (orders.isEmpty) {
      return const Center(child: Text("No job orders found."));
    }
    return LayoutBuilder(
      builder: (context, constraints) {
        final cardWidth = constraints.maxWidth < 700 ? constraints.maxWidth : (constraints.maxWidth - 16) / 2;
        return Wrap(
          spacing: 16,
          runSpacing: 16,
          children: orders.map((order) => _JobCard(
            order: order, 
            width: cardWidth,
            onView: () => _onViewDetails(order),
          )).toList(),
        );
      }
    );
  }
}

// --- Reusable Widgets ---

class _ViewToggleButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool isSelected;
  final VoidCallback onTap;

  const _ViewToggleButton({required this.label, required this.icon, required this.isSelected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(6),
          boxShadow: isSelected ? [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 2)] : null,
        ),
        child: Row(
          children: [
            Icon(icon, size: 16, color: isSelected ? Colors.black87 : Colors.black54),
            const SizedBox(width: 6),
            Text(label, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: isSelected ? Colors.black87 : Colors.black54)),
          ],
        ),
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback onPressed;
  final bool isPrimary;

  const _ActionButton({
    required this.label,
    required this.icon,
    required this.onPressed,
    this.isPrimary = false,
  });

  @override
  Widget build(BuildContext context) {
    return ElevatedButton.icon(
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: isPrimary ? const Color(0xFF2563EB) : Colors.white,
        foregroundColor: isPrimary ? Colors.white : const Color(0xFF475569),
        elevation: 0,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: isPrimary ? BorderSide.none : const BorderSide(color: Color(0xFFE2E8F0)),
        ),
      ),
      icon: Icon(icon, size: 16),
      label: Text(label, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color color;
  final double width;

  const _StatCard({
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
    required this.width,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(width: 16),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(fontSize: 13, color: Color(0xFF64748B), fontWeight: FontWeight.w500)),
              const SizedBox(height: 2),
              Text(value, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w700, color: Color(0xFF1E293B))),
            ],
          ),
        ],
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final String status;

  const _StatusBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    Color bg;
    Color text;
    String label = status;

    switch (status.toLowerCase()) {
      case 'in progress':
        bg = const Color(0xFFDBEAFE); 
        text = const Color(0xFF1D4ED8); 
        break;
      case 'pending':
        bg = const Color(0xFFFFEDD5); 
        text = const Color(0xFFC2410C); 
        break;
      case 'completed':
        bg = const Color(0xFFDCFCE7); 
        text = const Color(0xFF15803D); 
        break;
      default:
        bg = const Color(0xFFF1F5F9); 
        text = const Color(0xFF475569); 
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: TextStyle(color: text, fontSize: 11, fontWeight: FontWeight.w700),
      ),
    );
  }
}

class _JobCard extends StatelessWidget {
  final JobOrder order;
  final double width;
  final VoidCallback onView;

  const _JobCard({required this.order, required this.width, required this.onView});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 4, offset: const Offset(0,2))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _StatusBadge(status: order.status),
            ],
          ),
          const SizedBox(height: 12),
          Text(order.id, style: const TextStyle(fontSize: 12, color: Color(0xFF64748B), fontWeight: FontWeight.w600)),
          const SizedBox(height: 4),
          Text(order.clientName, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Color(0xFF1E293B))),
          const SizedBox(height: 8),
          Row(
            children: [
              const Icon(Icons.location_on_outlined, size: 14, color: Color(0xFF64748B)),
              const SizedBox(width: 4),
              Text(order.location, style: const TextStyle(fontSize: 12, color: Color(0xFF64748B))),
            ],
          ),
          const SizedBox(height: 16),
          const Divider(height: 1),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Work Type', style: TextStyle(fontSize: 10, color: Color(0xFF94A3B8))),
                  Text(order.jobType, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                ],
              ),
              ElevatedButton(
                onPressed: onView,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFF1F5F9),
                  foregroundColor: const Color(0xFF475569),
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  minimumSize: Size.zero,
                ),
                child: const Text('See More', style: TextStyle(fontSize: 11)),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// --- Comprehensive Add/Edit Dialog ---

class _JobOrderDialog extends StatefulWidget {
  final JobOrder? order;
  const _JobOrderDialog({this.order});
  @override
  State<_JobOrderDialog> createState() => _JobOrderDialogState();
}

class _JobOrderDialogState extends State<_JobOrderDialog> {
  late TextEditingController _idController;
  late TextEditingController _clientController;
  late TextEditingController _jobTypeController;
  late TextEditingController _locationController;
  late TextEditingController _durationController;
  
  // Extra details controllers
  late TextEditingController _unitDescController;
  late TextEditingController _addressController;
  late TextEditingController _contactController;
  late TextEditingController _brandController;
  late TextEditingController _unitLocationController;
  late TextEditingController _installDetailsController;
  late TextEditingController _notesController;
  late TextEditingController _followUpController;
  
  String _status = 'Pending';
  DateTime _dateTime = DateTime.now();
  String _segment = 'B2C';
  String _customerStatus = 'New';
  String _workType = 'Installation';
  String _customerType = 'Residential';
  DateTime? _dateStarted;
  DateTime? _dateCompleted;
  
  List<JobOrderTechnician> _selectedTechnicians = [];
  List<JobOrderAircon> _selectedAircons = [];
  List<JobOrderServiceItem> _selectedServiceItems = [];

  // Data Sources (Mock)
  final List<TechnicianData> _availableTechnicians = [
    const TechnicianData(id: 1, firstName: 'John', middleName: 'M', lastName: 'Doe', contactNumber: '+63 912 345 6789'),
    const TechnicianData(id: 2, firstName: 'Jane', middleName: 'A', lastName: 'Smith', contactNumber: '+63 917 123 4567'),
  ];
  final List<AirconData> _availableAircons = [
    AirconData(
      id: 1,
      brand: const BrandData(id: 1, name: 'Daikin'),
      airconType: const AirconTypeData(id: 1, typeName: 'Split Type'),
      customer: const CustomerData(
        id: 1,
        customerType: CustomerTypeData(id: 1, type: CustomerTypeKind.b2b),
        companyName: 'ABC Corp',
        firstName: 'John', middleName: '', lastName: 'Manager',
        jobPosition: 'Facilities', contactNumber: '', unitOrBuilding: '', street: '', subdivisionOrVillage: '', barangay: '', city: '', landmark: '',
      ),
      remarks: 'Main Lobby',
    ),
  ];
  final List<ServiceItemData> _availableServiceItems = [
    const ServiceItemData(id: 1, itemName: 'Installation', itemType: 'Service', price: 5000),
  ];

  @override
  void initState() {
    super.initState();
    final o = widget.order;
    _idController = TextEditingController(text: o?.id ?? '');
    _clientController = TextEditingController(text: o?.clientName ?? '');
    _jobTypeController = TextEditingController(text: o?.jobType ?? '');
    _locationController = TextEditingController(text: o?.location ?? '');
    _durationController = TextEditingController(text: o?.duration ?? '');
    
    _unitDescController = TextEditingController(text: o?.unitDescription ?? '');
    _addressController = TextEditingController(text: o?.customerAddress ?? '');
    _contactController = TextEditingController(text: o?.customerContact ?? '');
    _brandController = TextEditingController(text: o?.brand ?? '');
    _unitLocationController = TextEditingController(text: o?.unitLocation ?? '');
    _installDetailsController = TextEditingController(text: o?.installationDetails ?? '');
    _notesController = TextEditingController(text: o?.workNotes ?? '');
    _followUpController = TextEditingController(text: o?.followUpSchedule ?? '');
    
    _status = o?.status ?? 'Pending';
    _dateTime = o?.dateTime ?? DateTime.now();
    _segment = o?.segment ?? 'B2C';
    _customerStatus = o?.customerStatus ?? 'New';
    _workType = o?.workType ?? 'Installation';
    _customerType = o?.customerType ?? 'Residential';
    
    _dateStarted = o?.dateStarted;
    _dateCompleted = o?.dateCompleted;
    
    _selectedTechnicians = o?.technicians ?? [];
    _selectedAircons = o?.aircons ?? [];
    _selectedServiceItems = o?.serviceItems ?? [];
  }

  @override
  void dispose() {
    _idController.dispose();
    _clientController.dispose();
    _jobTypeController.dispose();
    _locationController.dispose();
    _durationController.dispose();
    _unitDescController.dispose();
    _addressController.dispose();
    _contactController.dispose();
    _brandController.dispose();
    _unitLocationController.dispose();
    _installDetailsController.dispose();
    _notesController.dispose();
    _followUpController.dispose();
    super.dispose();
  }

  void _submit() {
    final order = JobOrder(
      id: _idController.text.trim(),
      clientName: _clientController.text.trim(),
      jobType: _jobTypeController.text.trim(),
      technician: _selectedTechnicians.isNotEmpty ? _selectedTechnicians.first.technician.firstName : 'Unassigned',
      dateTime: _dateTime,
      duration: _durationController.text.trim(),
      location: _locationController.text.trim(),
      status: _status,
      segment: _segment,
      customerStatus: _customerStatus,
      workType: _workType,
      customerType: _customerType,
      unitDescription: _unitDescController.text.trim(),
      customerAddress: _addressController.text.trim(),
      customerContact: _contactController.text.trim(),
      brand: _brandController.text.trim(),
      unitLocation: _unitLocationController.text.trim(),
      installationDetails: _installDetailsController.text.trim(),
      workNotes: _notesController.text.trim(),
      followUpSchedule: _followUpController.text.trim(),
      technicians: _selectedTechnicians,
      aircons: _selectedAircons,
      serviceItems: _selectedServiceItems,
      dateStarted: _dateStarted,
      dateCompleted: _dateCompleted,
    );
    Navigator.of(context).pop(order);
  }

  InputDecoration _inputDecor(String label) {
    return InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(fontSize: 13, color: Color(0xFF64748B)),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: Color(0xFF2563EB), width: 1.5),
      ),
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      isDense: true,
    );
  }

  Future<void> _pickDateTime() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _dateTime,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
    );
    if (date == null) return;
    if (!mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_dateTime),
    );
    if (time == null) return;
    setState(() {
      _dateTime = DateTime(date.year, date.month, date.day, time.hour, time.minute);
    });
  }
  
  void _manageTechnicians() async {
    final result = await showDialog<List<JobOrderTechnician>>(
      context: context,
      builder: (context) => _TechnicianSelectionDialog(
        available: _availableTechnicians,
        selected: _selectedTechnicians,
      ),
    );
    if (result != null) {
      setState(() => _selectedTechnicians = result);
    }
  }

  void _manageAircons() async {
    final result = await showDialog<List<JobOrderAircon>>(
      context: context,
      builder: (context) => _AirconSelectionDialog(
        available: _availableAircons,
        selected: _selectedAircons,
      ),
    );
    if (result != null) {
      setState(() => _selectedAircons = result);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        width: 600,
        constraints: const BoxConstraints(maxHeight: 700),
        padding: const EdgeInsets.all(24),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                widget.order == null ? 'Add Job Order' : 'Edit Job Order',
                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: Color(0xFF1E293B)),
              ),
              const SizedBox(height: 4),
              const Text(
                'Enter all necessary details for this job.',
                style: TextStyle(fontSize: 13, color: Color(0xFF64748B)),
              ),
              const SizedBox(height: 24),
              
              // Essential Fields (Primary)
              Row(
                children: [
                  Expanded(child: TextField(controller: _idController, decoration: _inputDecor('JO Number'))),
                  const SizedBox(width: 16),
                  Expanded(child: 
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      decoration: BoxDecoration(
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: _status,
                          isExpanded: true,
                          items: ['Pending', 'In progress', 'Completed'].map((s) => DropdownMenuItem(value: s, child: Text(s, style: const TextStyle(fontSize: 14)))).toList(),
                          onChanged: (v) => setState(() => _status = v!),
                        ),
                      ),
                    )
                  ),
                ],
              ),
              const SizedBox(height: 16),
              TextField(controller: _clientController, decoration: _inputDecor('Client Name')),
              const SizedBox(height: 16),
              InkWell(
                onTap: _pickDateTime,
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  decoration: BoxDecoration(
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.calendar_today, size: 16, color: Color(0xFF64748B)),
                      const SizedBox(width: 8),
                      Text(
                        'Schedule: ${_dateTime.month}/${_dateTime.day}/${_dateTime.year} ${_dateTime.hour.toString().padLeft(2,'0')}:${_dateTime.minute.toString().padLeft(2,'0')}',
                        style: const TextStyle(fontSize: 14, color: Color(0xFF1E293B)),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(child: TextField(controller: _jobTypeController, decoration: _inputDecor('Job Type'))),
                  const SizedBox(width: 16),
                  Expanded(child: TextField(controller: _locationController, decoration: _inputDecor('Location'))),
                ],
              ),

              const SizedBox(height: 24),
              
              // Collapsible Additional Details (Full functionality)
              Theme(
                data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
                child: ExpansionTile(
                  title: const Text('Additional Details', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: Color(0xFF2563EB))),
                  tilePadding: EdgeInsets.zero,
                  initiallyExpanded: false,
                  children: [
                    const SizedBox(height: 8),
                    const Text("Customer Info", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF94A3B8))),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            value: _segment,
                            decoration: _inputDecor('Segment'),
                            items: ['B2C', 'B2B'].map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
                            onChanged: (v) => setState(() => _segment = v!),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            value: _customerStatus,
                            decoration: _inputDecor('Customer Status'),
                            items: ['New', 'Returning'].map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
                            onChanged: (v) => setState(() => _customerStatus = v!),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    TextField(controller: _addressController, decoration: _inputDecor('Customer Address')),
                    const SizedBox(height: 12),
                    TextField(controller: _contactController, decoration: _inputDecor('Customer Contact')),
                    
                    const SizedBox(height: 16),
                    const Text("Technical & Units", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF94A3B8))),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(child: TextField(controller: _durationController, decoration: _inputDecor('Duration (e.g., 2h)'))),
                        const SizedBox(width: 12),
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            value: _workType,
                            decoration: _inputDecor('Work Type'),
                            items: ['Installation', 'Maintenance', 'Repair'].map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
                            onChanged: (v) => setState(() => _workType = v!),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: _manageTechnicians,
                            icon: const Icon(Icons.people, size: 16),
                            label: Text(_selectedTechnicians.isEmpty ? 'Assign Technicians' : '${_selectedTechnicians.length} Techs'),
                            style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16)),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: _manageAircons,
                            icon: const Icon(Icons.ac_unit, size: 16),
                            label: Text(_selectedAircons.isEmpty ? 'Select Units' : '${_selectedAircons.length} Units'),
                            style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16)),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    const Text("Manual Unit Entry (If not selected above)", style: TextStyle(fontSize: 11, fontStyle: FontStyle.italic, color: Colors.grey)),
                    const SizedBox(height: 4),
                    Row(children: [
                      Expanded(child: TextField(controller: _brandController, decoration: _inputDecor('Brand'))),
                      const SizedBox(width: 12),
                      Expanded(child: TextField(controller: _unitLocationController, decoration: _inputDecor('Unit Location'))),
                    ]),
                    const SizedBox(height: 12),
                    TextField(controller: _installDetailsController, decoration: _inputDecor('Installation Details')),
                    
                    const SizedBox(height: 16),
                    const Text("Notes", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF94A3B8))),
                    const SizedBox(height: 8),
                    TextField(controller: _notesController, decoration: _inputDecor('Work Notes'), maxLines: 3),
                    const SizedBox(height: 12),
                    TextField(controller: _followUpController, decoration: _inputDecor('Follow-up Schedule')),
                  ],
                ),
              ),

              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    style: TextButton.styleFrom(foregroundColor: const Color(0xFF64748B)),
                    child: const Text('Cancel'),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: _submit,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF2563EB),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
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

// --- Read-Only Details Dialog ---

class _JobOrderDetailsDialog extends StatelessWidget {
  final JobOrder order;
  const _JobOrderDetailsDialog({required this.order});

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        width: 600,
        padding: const EdgeInsets.all(32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(order.id, style: const TextStyle(fontSize: 14, color: Color(0xFF64748B), fontWeight: FontWeight.w600)),
                    const SizedBox(height: 4),
                    Text(order.clientName, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w700, color: Color(0xFF1E293B))),
                  ],
                ),
                _StatusBadge(status: order.status),
              ],
            ),
            const SizedBox(height: 24),
            const Divider(),
            const SizedBox(height: 24),
            _detailRow('Job Type', order.jobType),
            _detailRow('Schedule', '${order.dateTime}'),
            _detailRow('Location', order.location),
            _detailRow('Address', order.customerAddress.isEmpty ? '-' : order.customerAddress),
            _detailRow('Contact', order.customerContact.isEmpty ? '-' : order.customerContact),
            const SizedBox(height: 16),
            const Text("Technical Info", style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            _detailRow('Work Type', order.workType.isEmpty ? '-' : order.workType),
            _detailRow('Duration', order.duration.isEmpty ? '-' : order.duration),
            _detailRow('Technicians', order.technicians.isEmpty ? 'Unassigned' : order.technicians.map((t) => t.technician.firstName).join(', ')),
            const SizedBox(height: 16),
            const Text("Unit Details", style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            _detailRow('Units', order.aircons.isEmpty ? (order.numberOfUnits > 0 ? '${order.numberOfUnits}' : '-') : '${order.aircons.length} units selected'),
            _detailRow('Brand', order.brand.isEmpty ? '-' : order.brand),
            _detailRow('Unit Location', order.unitLocation.isEmpty ? '-' : order.unitLocation),
            _detailRow('Install Details', order.installationDetails.isEmpty ? '-' : order.installationDetails),
            const SizedBox(height: 16),
            const Text("Notes", style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Text(order.workNotes.isEmpty ? 'No additional notes.' : order.workNotes, style: const TextStyle(fontSize: 14, color: Color(0xFF334155))),
            ),
            const SizedBox(height: 32),
            Align(
              alignment: Alignment.centerRight,
              child: OutlinedButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Close'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _detailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 120, child: Text(label, style: const TextStyle(fontSize: 13, color: Color(0xFF64748B), fontWeight: FontWeight.w500))),
          Expanded(child: Text(value, style: const TextStyle(fontSize: 14, color: Color(0xFF1E293B), fontWeight: FontWeight.w500))),
        ],
      ),
    );
  }
}

// --- Helper Selection Dialogs ---

class _TechnicianSelectionDialog extends StatefulWidget {
  final List<TechnicianData> available;
  final List<JobOrderTechnician> selected;

  const _TechnicianSelectionDialog({required this.available, required this.selected});

  @override
  State<_TechnicianSelectionDialog> createState() => _TechnicianSelectionDialogState();
}

class _TechnicianSelectionDialogState extends State<_TechnicianSelectionDialog> {
  late List<JobOrderTechnician> _selected;
  final Map<int, String> _roles = {};

  @override
  void initState() {
    super.initState();
    _selected = List.from(widget.selected);
    for (var t in _selected) {
      _roles[t.technician.id] = t.role;
    }
  }

  void _toggleTechnician(TechnicianData tech) {
    setState(() {
      final existing = _selected.indexWhere((t) => t.technician.id == tech.id);
      if (existing >= 0) {
        _selected.removeAt(existing);
        _roles.remove(tech.id);
      } else {
        _selected.add(JobOrderTechnician(
          technician: tech,
          role: _roles[tech.id] ?? 'Technician',
        ));
      }
    });
  }

  void _updateRole(TechnicianData tech, String role) {
    setState(() {
      _roles[tech.id] = role;
      final index = _selected.indexWhere((t) => t.technician.id == tech.id);
      if (index >= 0) {
        _selected[index] = JobOrderTechnician(technician: tech, role: role);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: Container(
        width: 500,
        height: 600,
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Select Technicians', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
            const SizedBox(height: 16),
            Expanded(
              child: ListView.builder(
                itemCount: widget.available.length,
                itemBuilder: (context, index) {
                  final tech = widget.available[index];
                  final isSelected = _selected.any((t) => t.technician.id == tech.id);
                  return CheckboxListTile(
                    title: Text('${tech.firstName} ${tech.lastName}'),
                    subtitle: Text(tech.contactNumber),
                    value: isSelected,
                    onChanged: (v) => _toggleTechnician(tech),
                    secondary: isSelected
                        ? DropdownButton<String>(
                            value: _roles[tech.id] ?? 'Technician',
                            underline: const SizedBox(),
                            items: const [
                              DropdownMenuItem(value: 'Technician', child: Text('Technician')),
                              DropdownMenuItem(value: 'Lead', child: Text('Lead')),
                              DropdownMenuItem(value: 'Assistant', child: Text('Assistant')),
                            ],
                            onChanged: (v) {
                              if (v != null) _updateRole(tech, v);
                            },
                          )
                        : null,
                  );
                },
              ),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
                const SizedBox(width: 12),
                ElevatedButton(onPressed: () => Navigator.pop(context, _selected), child: const Text('Save')),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _AirconSelectionDialog extends StatefulWidget {
  final List<AirconData> available;
  final List<JobOrderAircon> selected;

  const _AirconSelectionDialog({required this.available, required this.selected});

  @override
  State<_AirconSelectionDialog> createState() => _AirconSelectionDialogState();
}

class _AirconSelectionDialogState extends State<_AirconSelectionDialog> {
  late List<JobOrderAircon> _selected;

  @override
  void initState() {
    super.initState();
    _selected = List.from(widget.selected);
  }

  void _toggle(AirconData aircon) {
    setState(() {
      final index = _selected.indexWhere((a) => a.aircon.id == aircon.id);
      if (index >= 0) {
        _selected.removeAt(index);
      } else {
        _selected.add(JobOrderAircon(aircon: aircon));
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: Container(
        width: 520,
        height: 520,
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Select Aircon Units', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
            const SizedBox(height: 16),
            Expanded(
              child: ListView.builder(
                itemCount: widget.available.length,
                itemBuilder: (context, index) {
                  final aircon = widget.available[index];
                  final isSelected = _selected.any((a) => a.aircon.id == aircon.id);
                  return CheckboxListTile(
                    title: Text('${aircon.brand.name} • ${aircon.airconType.typeName}'),
                    subtitle: Text(aircon.remarks),
                    value: isSelected,
                    onChanged: (_) => _toggle(aircon),
                  );
                },
              ),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
                const SizedBox(width: 12),
                ElevatedButton(onPressed: () => Navigator.pop(context, _selected), child: const Text('Save')),
              ],
            ),
          ],
        ),
      ),
    );
  }
}