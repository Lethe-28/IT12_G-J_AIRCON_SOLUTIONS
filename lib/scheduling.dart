import 'package:flutter/material.dart';
import 'data/app_state.dart';
import 'data/models.dart';
import 'ui_app_shell.dart';
import 'calendar_view.dart';

// Junction table data classes
class JobOrderTechnician {
  final TechnicianData technician;
  final String role; // e.g., "Lead", "Assistant"

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
  String technician; // Keep for backward compatibility
  DateTime dateTime; // Keep for backward compatibility, use dateStarted
  DateTime? dateStarted;
  DateTime? dateCompleted;
  String duration;
  String location;
  String status;
  String workType; // Installation, CM (Corrective), PM (Preventive)
  String customerType; // e.g. Commercial, Residential
  String segment; // B2B or B2C
  String customerStatus; // New or Returning customer
  int numberOfUnits;
  String unitDescription; // what unit(s) these are
  String customerAddress;
  String customerContact;
  String brand; // Brand of the unit/equipment
  String unitLocation; // Where the unit is located
  String installationDetails; // How the unit is installed/positioned
  String workNotes;
  String followUpSchedule; // e.g. month or date
  
  // Junction table relationships
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
  
  String get techniciansDisplay {
    if (technicians.isEmpty) return technician;
    return technicians.map((t) => '${t.technician.firstName} ${t.technician.lastName}').join(', ');
  }
}

class SchedulingScreen extends StatefulWidget {
  const SchedulingScreen({super.key});

  @override
  State<SchedulingScreen> createState() => _SchedulingScreenState();
}

class _SchedulingScreenState extends State<SchedulingScreen> {
  String _searchQuery = '';
  final Set<String> _selectedOrderIds = {}; // Track selected orders by ID
  bool get _isServiceManager => AppState.currentRole == UserRole.serviceManager;
  String? _hoveredOrderId; // Track which row is hovered
  int _currentPage = 0;
  final int _rowsPerPage = 10;

  // Get shared job orders list - cached to avoid repeated conversions
  List<JobOrder> get _orders {
    try {
      final shared = AppState.sharedJobOrders;
      if (shared.isEmpty) return [];
      // Safely cast each element, filter out any nulls
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

  bool get _allSelected {
    final orders = _orders;
    return orders.isNotEmpty && _selectedOrderIds.length == orders.length;
  }

  @override
  void initState() {
    super.initState();
    // Use WidgetsBinding to ensure this runs after the first frame
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _seedData();
    });
  }

  void _seedData() {
    // Only seed if not already seeded (first time initialization)
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
        ),
      ];
      AppState.sharedJobOrders.addAll(seedOrders);
      AppState.setJobOrdersSeeded(true);
      if (mounted) {
        setState(() {});
      }
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

  void _onDelete(JobOrder order) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Job Order'),
        content: Text('Are you sure you want to delete ${order.id}?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Delete')),
        ],
      ),
    );
    if (confirmed != true) return;
    setState(() {
      AppState.sharedJobOrders.removeWhere((o) => (o as JobOrder).id == order.id);
      _selectedOrderIds.remove(order.id);
    });
  }

  void _showOrderActionsPopup(JobOrder order) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Order ${order.id}'),
        content: Text('${order.clientName} - ${order.jobType}'),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _onAddOrEdit(existing: order);
            },
            child: const Text('Edit'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _onDelete(order);
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
        ],
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

  List<JobOrder> get _paginatedOrders {
    final filtered = _filteredOrders;
    final startIndex = _currentPage * _rowsPerPage;
    final endIndex = startIndex + _rowsPerPage;
    if (startIndex >= filtered.length) return [];
    return filtered.sublist(startIndex, endIndex > filtered.length ? filtered.length : endIndex);
  }

  int get _totalPages {
    final total = _filteredOrders.length;
    return (total / _rowsPerPage).ceil();
  }

  String _formatDate(DateTime? dt) {
    if (dt == null) return '-';
    final mm = dt.month.toString().padLeft(2, '0');
    final dd = dt.day.toString().padLeft(2, '0');
    final yyyy = dt.year.toString();
    return '$mm/$dd/$yyyy';
  }

  String _formatDateRange(DateTime? started, DateTime? completed) {
    final start = _formatDate(started);
    final end = completed != null ? _formatDate(completed) : 'Ongoing';
    return '$start\n$end';
  }

  String _formatWorkNotes(List<JobOrderAircon> aircons) {
    if (aircons.isEmpty) return '-';
    return aircons.map((a) => '${a.aircon.brand.name} ${a.aircon.airconType.typeName}').join(', ');
  }

  Widget _paginationControls() {
    final totalPages = _totalPages;
    final currentPage = _currentPage + 1;
    
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          IconButton(
            onPressed: _currentPage > 0 ? () => setState(() => _currentPage--) : null,
            icon: const Icon(Icons.navigate_before),
            tooltip: 'Previous page',
          ),
          const SizedBox(width: 8),
          Text('Page $currentPage of $totalPages',
              style: const TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(width: 8),
          IconButton(
            onPressed: _currentPage < totalPages - 1 ? () => setState(() => _currentPage++) : null,
            icon: const Icon(Icons.navigate_next),
            tooltip: 'Next page',
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Safely get filtered and paginated orders
    List<JobOrder> orders;
    try {
      orders = _paginatedOrders;
    } catch (e) {
      orders = [];
    }
    
    return AppShell(
      selectedIndex: 1,
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Job Orders & Scheduling',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 14),
                  _summarySection(),
                  const SizedBox(height: 14),
                  _filtersRow(),
                  const SizedBox(height: 14),
                  _jobOrdersTable(orders),
                  if (_totalPages > 1) ...[
                    const SizedBox(height: 16),
                    _paginationControls(),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _summarySection() {
    final pending = _orders.where((o) => o.status.toLowerCase() == 'pending').length;
    final inProgress = _orders.where((o) => o.status.toLowerCase() == 'in progress').length;
    final completed = _orders.where((o) => o.status.toLowerCase() == 'completed').length;
    final cards = [
      _summaryCard('Open Jobs', pending.toString(), Icons.pending_actions, Colors.orange),
      _summaryCard('In Progress', inProgress.toString(), Icons.engineering, Colors.blue),
      _summaryCard('Completed (30d)', completed.toString(), Icons.verified, Colors.green),
    ];
    return LayoutBuilder(
      builder: (context, constraints) {
        final isNarrow = constraints.maxWidth < 900;
        if (isNarrow) {
          return Column(
            children: [
              for (final card in cards) ...[
                card,
                const SizedBox(height: 12),
              ],
            ],
          );
        }
        return Row(
          children: [
            Expanded(child: cards[0]),
            const SizedBox(width: 12),
            Expanded(child: cards[1]),
            const SizedBox(width: 12),
            Expanded(child: cards[2]),
          ],
        );
      },
    );
  }

  Widget _summaryCard(String title, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: _cardDeco(),
      child: Row(
        children: [
          Container(
            decoration: BoxDecoration(
              color: color.withOpacity(.15),
              borderRadius: BorderRadius.circular(12),
            ),
            padding: const EdgeInsets.all(12),
            child: Icon(icon, color: color),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(fontSize: 13, color: Colors.black54)),
              const SizedBox(height: 4),
              Text(value, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
            ],
          ),
        ],
      ),
    );
  }



  Widget _jobOrdersTable(List<JobOrder> orders) {
    final fontSize = _isServiceManager ? 16.0 : 14.0;
    return Container(
      decoration: _cardDeco(),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text('All Job Orders',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: Colors.grey[900])),
              const Spacer(),
              ElevatedButton.icon(
                onPressed: () => _onAddOrEdit(),
                icon: Icon(Icons.add, size: _isServiceManager ? 22 : 20),
                label: Text('Add Job Order', style: TextStyle(fontSize: fontSize)),
                style: ElevatedButton.styleFrom(
                  padding: EdgeInsets.symmetric(
                    horizontal: _isServiceManager ? 20 : 16,
                    vertical: _isServiceManager ? 16 : 12,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              ElevatedButton.icon(
                onPressed: () {
                  showDialog(
                    context: context,
                    builder: (context) => CalendarViewScreen(jobOrders: _orders),
                  );
                },
                icon: Icon(Icons.calendar_month_outlined, size: _isServiceManager ? 22 : 20),
                label: Text('Calendar View', style: TextStyle(fontSize: fontSize)),
                style: ElevatedButton.styleFrom(
                  padding: EdgeInsets.symmetric(
                    horizontal: _isServiceManager ? 20 : 16,
                    vertical: _isServiceManager ? 16 : 12,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              ElevatedButton.icon(
                onPressed: () {},
                icon: Icon(Icons.picture_as_pdf_outlined, size: _isServiceManager ? 22 : 20),
                label: Text('Export Table', style: TextStyle(fontSize: fontSize)),
                style: ElevatedButton.styleFrom(
                  padding: EdgeInsets.symmetric(
                    horizontal: _isServiceManager ? 20 : 16,
                    vertical: _isServiceManager ? 16 : 12,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: DataTable(
              headingRowColor: MaterialStateProperty.resolveWith(
                  (states) => const Color(0xFFF8FAFC)),
              columns: [
                  DataColumn(
                    label: Checkbox(
                      value: _allSelected,
                      tristate: true,
                      onChanged: (bool? value) {
                        setState(() {
                          if (value == true) {
                            _selectedOrderIds.addAll(orders.map((o) => o.id));
                          } else {
                            _selectedOrderIds.clear();
                          }
                        });
                      },
                    ),
                  ),
                  const DataColumn(label: Text('JO NUMBER', style: TextStyle(fontWeight: FontWeight.w700))),
                  const DataColumn(label: Text('CLIENT', style: TextStyle(fontWeight: FontWeight.w700))),
                  const DataColumn(label: Text('JOB / WORK TYPE', style: TextStyle(fontWeight: FontWeight.w700))),
                  const DataColumn(label: Text('TECHNICIANS', style: TextStyle(fontWeight: FontWeight.w700))),
                  const DataColumn(label: Text('DATE STARTED / COMPLETED', style: TextStyle(fontWeight: FontWeight.w700))),
                  const DataColumn(label: Text('UNITS', style: TextStyle(fontWeight: FontWeight.w700))),
                  const DataColumn(label: Text('WORK NOTES', style: TextStyle(fontWeight: FontWeight.w700))),
                  const DataColumn(label: Text('FOLLOW UP SCHEDULE', style: TextStyle(fontWeight: FontWeight.w700))),
                  const DataColumn(label: Text('LOCATION', style: TextStyle(fontWeight: FontWeight.w700))),
                  const DataColumn(label: Text('STATUS', style: TextStyle(fontWeight: FontWeight.w700))),
                ],
                rows: orders.map((o) => _dataRow(o)).toList(),
              ),
            ),
        ],
      ),
    );
  }
  
  Widget _filtersRow() {
    final fontSize = _isServiceManager ? 16.0 : 14.0;
    return Row(
      children: [
        Expanded(
          child: TextField(
            onChanged: (v) {
              setState(() => _searchQuery = v);
            },
            style: TextStyle(fontSize: fontSize),
            decoration: InputDecoration(
              hintText: 'Search by client, technician, work type...',
              hintStyle: TextStyle(fontSize: fontSize),
              prefixIcon: Icon(Icons.search, size: _isServiceManager ? 24 : 20),
              filled: true,
              fillColor: Colors.white,
              border: OutlineInputBorder(
                borderSide: BorderSide.none,
                borderRadius: BorderRadius.circular(10),
              ),
              contentPadding: EdgeInsets.symmetric(
                horizontal: 16,
                vertical: _isServiceManager ? 16 : 12,
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        PopupMenuButton<String>(
          onSelected: (value) {
            // Handle sort selection
          },
          itemBuilder: (BuildContext context) => [
            const PopupMenuItem(
              value: 'schedule_time',
              child: Text('Schedule Time'),
            ),
            const PopupMenuItem(
              value: 'work_type',
              child: Text('Work Type'),
            ),
            const PopupMenuItem(
              value: 'this_week',
              child: Text('This Week'),
            ),
            const PopupMenuItem(
              value: 'this_month',
              child: Text('This Month'),
            ),
          ],
          child: ElevatedButton.icon(
            onPressed: null,
            icon: const Icon(Icons.unfold_more, size: 18),
            label: const Text('Sort By', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
            style: ElevatedButton.styleFrom(
              padding: EdgeInsets.symmetric(
                horizontal: _isServiceManager ? 20 : 16,
                vertical: _isServiceManager ? 16 : 12,
              ),
            ),
          ),
        ),
      ],
    );
  }

  DataRow _dataRow(JobOrder order) {
    final status = order.status;
    
    // Define status-specific colors
    Color badgeColor = const Color(0xFFF2F4F7);
    Color textColor = const Color(0xFF6B7280);
    
    if (status.toLowerCase() == 'in progress') {
      badgeColor = const Color(0xFFDEF4FF); // Light blue
      textColor = const Color(0xFF0078D4); // Dark blue
    } else if (status.toLowerCase() == 'pending') {
      badgeColor = const Color(0xFFFFF4DE); // Light orange
      textColor = const Color(0xFFD97706); // Dark orange
    } else if (status.toLowerCase() == 'completed') {
      badgeColor = const Color(0xFFDCFCE7); // Light green
      textColor = const Color(0xFF059669); // Dark green
    }
    
    String unitsText = '';
    if (order.numberOfUnits > 0 && order.unitDescription.isNotEmpty) {
      unitsText = '${order.numberOfUnits} x ${order.unitDescription}';
    } else if (order.numberOfUnits > 0) {
      unitsText = order.numberOfUnits.toString();
    } else if (order.unitDescription.isNotEmpty) {
      unitsText = order.unitDescription;
    }

    final isSelected = _selectedOrderIds.contains(order.id);
    
    return DataRow(
      color: MaterialStateProperty.resolveWith((states) {
        if (states.contains(MaterialState.hovered)) {
          // Update hover state and trigger rebuild
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (_hoveredOrderId != order.id) {
              setState(() {
                _hoveredOrderId = order.id;
              });
            }
          });
          return const Color(0xFFF0F4F8);
        } else if (_hoveredOrderId == order.id) {
          // Mouse left - clear hover state
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              setState(() {
                _hoveredOrderId = null;
              });
            }
          });
        }
        return null;
      }),
      cells: [
        DataCell(
          Checkbox(
            value: isSelected,
            onChanged: (bool? value) {
              setState(() {
                if (value == true) {
                  _selectedOrderIds.add(order.id);
                  _showOrderActionsPopup(order);
                } else {
                  _selectedOrderIds.remove(order.id);
                }
              });
            },
          ),
        ),
        DataCell(Text(order.id)),
        DataCell(
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(order.clientName),
              if (order.segment.isNotEmpty ||
                  order.customerStatus.isNotEmpty ||
                  order.brand.isNotEmpty)
                Text(
                  [
                    if (order.segment.isNotEmpty) order.segment,
                    if (order.customerStatus.isNotEmpty) order.customerStatus,
                    if (order.brand.isNotEmpty) 'Brand: ${order.brand}',
                  ].join(' • '),
                  style: const TextStyle(fontSize: 11, color: Colors.black54),
                ),
            ],
          ),
        ),
        DataCell(Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(order.jobType),
            if (order.workType.isNotEmpty)
              Text(
                order.workType,
                style: const TextStyle(fontSize: 11, color: Colors.black54),
              ),
          ],
        )),
        DataCell(
          order.technicians.isNotEmpty
              ? Wrap(
                  spacing: 4,
                  runSpacing: 4,
                  children: order.technicians
                      .map(
                        (t) => Chip(
                          label: Text(
                            '${t.technician.firstName} ${t.technician.lastName}',
                            style: const TextStyle(fontSize: 11),
                          ),
                          padding: EdgeInsets.zero,
                          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                      )
                      .toList(),
                )
              : Row(
                  children: [
          const CircleAvatar(radius: 12, child: Text('T')),
          const SizedBox(width: 8),
          Text(order.technician),
                  ],
                ),
        ),
        DataCell(Text(_formatDateRange(order.dateStarted, order.dateCompleted))),
        DataCell(Text(order.aircons.isNotEmpty ? order.aircons.length.toString() : (unitsText.isEmpty ? '-' : unitsText))),
        DataCell(
          SizedBox(
            width: 200,
            child: Text(
              order.aircons.isNotEmpty ? _formatWorkNotes(order.aircons) : (order.workNotes.isNotEmpty ? order.workNotes : '-'),
              style: const TextStyle(fontSize: 12),
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ),
        DataCell(Text(order.followUpSchedule.isEmpty ? '-' : order.followUpSchedule)),
        DataCell(Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(order.location),
            if (order.customerAddress.isNotEmpty)
              Text(
                order.customerAddress,
                style: const TextStyle(fontSize: 11, color: Colors.black54),
              ),
          ],
        )),
        DataCell(Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration:
              BoxDecoration(color: badgeColor, borderRadius: BorderRadius.circular(999)),
          child: Text(status, style: TextStyle(color: textColor, fontSize: 12)),
        )),
      ],
    );
  }

  BoxDecoration _cardDeco() => BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      );


}

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
  late TextEditingController _technicianController;
  late TextEditingController _durationController;
  late TextEditingController _locationController;
  late TextEditingController _unitsController;
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
  DateTime? _dateStarted;
  DateTime? _dateCompleted;
  String _workType = '';
  String _customerType = '';
  String _segment = 'B2C';
  String _customerStatus = '';
  
  // Junction table data
  List<JobOrderTechnician> _selectedTechnicians = [];
  List<JobOrderAircon> _selectedAircons = [];
  List<JobOrderServiceItem> _selectedServiceItems = [];
  
  // Sample data for selection (in production, these would come from data services)
  final List<TechnicianData> _availableTechnicians = [
    const TechnicianData(id: 1, firstName: 'John', middleName: 'M', lastName: 'Doe', contactNumber: '+63 912 345 6789'),
    const TechnicianData(id: 2, firstName: 'Jane', middleName: 'A', lastName: 'Smith', contactNumber: '+63 917 123 4567'),
    const TechnicianData(id: 3, firstName: 'Mike', middleName: 'B', lastName: 'Johnson', contactNumber: '+63 918 987 6543'),
  ];
  final List<AirconData> _availableAircons = [
    AirconData(
      id: 1,
      brand: const BrandData(id: 1, name: 'Daikin'),
      airconType: const AirconTypeData(id: 1, typeName: 'Split Type'),
      customer: CustomerData(
        id: 1,
        customerType: const CustomerTypeData(id: 1, type: CustomerTypeKind.b2b),
        companyName: 'ABC Corporation',
        firstName: 'John',
        middleName: '',
        lastName: 'Manager',
        jobPosition: 'Facilities',
        contactNumber: '+63 912 111 1111',
        unitOrBuilding: 'Tower A',
        street: 'Paseo Blvd',
        subdivisionOrVillage: 'Business Park',
        barangay: 'San Lorenzo',
        city: 'Makati',
        landmark: 'Near Ayala',
      ),
      remarks: 'HQ - 3rd floor lobby',
    ),
    AirconData(
      id: 2,
      brand: const BrandData(id: 2, name: 'Carrier'),
      airconType: const AirconTypeData(id: 2, typeName: 'Window Type'),
      customer: CustomerData(
        id: 2,
        customerType: const CustomerTypeData(id: 2, type: CustomerTypeKind.b2c),
        companyName: '',
        firstName: 'Maria',
        middleName: '',
        lastName: 'Santos',
        jobPosition: 'Homeowner',
        contactNumber: '+63 917 222 2222',
        unitOrBuilding: 'Blk 5 Lot 2',
        street: 'Narra Street',
        subdivisionOrVillage: 'Green Village',
        barangay: 'Holy Spirit',
        city: 'Quezon City',
        landmark: 'Near clubhouse',
      ),
      remarks: 'Bedroom unit',
    ),
  ];
  
  final List<ServiceItemData> _availableServiceItems = [
    const ServiceItemData(id: 1, itemName: 'AC Installation', itemType: 'Service', price: 5000.0),
    const ServiceItemData(id: 2, itemName: 'Preventive Maintenance', itemType: 'Service', price: 1500.0),
    const ServiceItemData(id: 3, itemName: 'Freon Refill', itemType: 'Material', price: 2500.0),
    const ServiceItemData(id: 4, itemName: 'AC Cleaning', itemType: 'Service', price: 800.0),
  ];

  @override
  void initState() {
    super.initState();
    final o = widget.order;
    _idController = TextEditingController(text: o?.id ?? '');
    _clientController = TextEditingController(text: o?.clientName ?? '');
    _jobTypeController = TextEditingController(text: o?.jobType ?? '');
    _technicianController = TextEditingController(text: o?.technician ?? '');
    _durationController = TextEditingController(text: o?.duration ?? '');
    _locationController = TextEditingController(text: o?.location ?? '');
    _unitsController = TextEditingController(text: o?.numberOfUnits == null || o!.numberOfUnits == 0 ? '' : o.numberOfUnits.toString());
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
    _dateStarted = o?.dateStarted ?? o?.dateTime;
    _dateCompleted = o?.dateCompleted;
    _workType = o?.workType ?? '';
    _customerType = o?.customerType ?? '';
    _segment = o?.segment ?? 'B2C';
    _customerStatus = o?.customerStatus ?? '';
    
    // Load existing relationships
    _selectedTechnicians = o?.technicians ?? [];
    _selectedAircons = o?.aircons ?? [];
    _selectedServiceItems = o?.serviceItems ?? [];
    
    // Update units count based on selected aircons
    if (_selectedAircons.isNotEmpty) {
      _unitsController.text = _selectedAircons.length.toString();
    }
  }

  @override
  void dispose() {
    _idController.dispose();
    _clientController.dispose();
    _jobTypeController.dispose();
    _technicianController.dispose();
    _durationController.dispose();
    _locationController.dispose();
    _unitsController.dispose();
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

  Future<void> _pickDateTime() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _dateTime,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
    );
    if (date == null) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_dateTime),
    );
    if (time == null) return;
    setState(() {
      _dateTime = DateTime(date.year, date.month, date.day, time.hour, time.minute);
    });
  }

  Future<void> _pickDateStarted() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _dateStarted ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
    );
    if (date != null) {
      setState(() {
        _dateStarted = date;
      });
    }
  }

  Future<void> _pickDateCompleted() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _dateCompleted ?? (_dateStarted ?? DateTime.now()),
      firstDate: _dateStarted ?? DateTime(2020),
      lastDate: DateTime(2030),
    );
    if (date != null) {
      setState(() {
        _dateCompleted = date;
      });
    }
  }

  void _submit() {
    if (_idController.text.trim().isEmpty ||
        _clientController.text.trim().isEmpty ||
        _jobTypeController.text.trim().isEmpty) {
      return;
    }
    // Sync units count with selected aircons
    final unitsCount = _selectedAircons.isNotEmpty ? _selectedAircons.length : (int.tryParse(_unitsController.text.trim()) ?? 0);
    final order = JobOrder(
      id: _idController.text.trim(),
      clientName: _clientController.text.trim(),
      jobType: _jobTypeController.text.trim(),
      technician: _technicianController.text.trim(),
      dateTime: _dateTime,
      dateStarted: _dateStarted,
      dateCompleted: _dateCompleted,
      duration: _durationController.text.trim(),
      location: _locationController.text.trim(),
      status: _status,
      workType: _workType,
      customerType: _customerType,
      segment: _segment,
      customerStatus: _customerStatus,
      numberOfUnits: unitsCount,
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
    );
    Navigator.of(context).pop(order);
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
  
  void _manageServiceItems() async {
    final result = await showDialog<List<JobOrderServiceItem>>(
      context: context,
      builder: (context) => _ServiceItemSelectionDialog(
        available: _availableServiceItems,
        selected: _selectedServiceItems,
      ),
    );
    if (result != null) {
      setState(() => _selectedServiceItems = result);
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
      setState(() {
        _selectedAircons = result;
        // Sync units count with selected aircons
        _unitsController.text = result.length.toString();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.order == null ? 'Add Job Order' : 'Edit Job Order'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _idController,
              decoration: const InputDecoration(labelText: 'JO Number'),
            ),
            TextField(
              controller: _clientController,
              decoration: const InputDecoration(labelText: 'Client Name'),
            ),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              value: _segment.isEmpty ? null : _segment,
              decoration: const InputDecoration(
                labelText: 'Customer Segment (B2C / B2B)',
              ),
              items: const [
                DropdownMenuItem(
                    value: 'B2C', child: Text('B2C - Business to Customer')),
                DropdownMenuItem(
                    value: 'B2B', child: Text('B2B - Business to Business')),
              ],
              onChanged: (v) => setState(() => _segment = v ?? 'B2C'),
            ),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              value: _customerStatus.isEmpty ? null : _customerStatus,
              decoration: const InputDecoration(
                labelText: 'Customer Status',
              ),
              items: const [
                DropdownMenuItem(
                    value: 'New customer', child: Text('New customer')),
                DropdownMenuItem(
                    value: 'Returning customer',
                    child: Text('Returning customer')),
              ],
              onChanged: (v) => setState(() => _customerStatus = v ?? ''),
            ),
            TextField(
              controller: _jobTypeController,
              decoration: const InputDecoration(labelText: 'Job Type'),
            ),
            Row(
              children: [
                Expanded(
                  child: TextField(
              controller: _technicianController,
                    decoration: const InputDecoration(labelText: 'Primary Technician (legacy)'),
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton.icon(
                  onPressed: _manageTechnicians,
                  icon: const Icon(Icons.people, size: 18),
                  label: Text('Manage (${_selectedTechnicians.length})'),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                  ),
                ),
              ],
            ),
            if (_selectedTechnicians.isNotEmpty) ...[
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _selectedTechnicians.map((t) => Chip(
                  label: Text('${t.technician.firstName} ${t.technician.lastName}${t.role != 'Technician' ? ' (${t.role})' : ''}'),
                  onDeleted: () {
                    setState(() => _selectedTechnicians.remove(t));
                  },
                )).toList(),
              ),
            ],
            const SizedBox(height: 12),
            const Divider(),
            const SizedBox(height: 8),
            Row(
              children: [
                const Text('Work Notes (Aircon Units)', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                const Spacer(),
                ElevatedButton.icon(
                  onPressed: _manageAircons,
                  icon: const Icon(Icons.ac_unit_outlined, size: 18),
                  label: Text('Select Units (${_selectedAircons.length})'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Number of Units: ${_selectedAircons.isNotEmpty ? _selectedAircons.length.toString() : (int.tryParse(_unitsController.text.trim()) ?? 0).toString()}',
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
            ),
            if (_selectedAircons.isNotEmpty) ...[
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _selectedAircons.map((a) => Chip(
                  avatar: const Icon(Icons.ac_unit, size: 16),
                  label: Text('${a.aircon.brand.name} ${a.aircon.airconType.typeName}'),
                  onDeleted: () {
                    setState(() {
                      _selectedAircons.remove(a);
                      _unitsController.text = _selectedAircons.length.toString();
                    });
                  },
                )).toList(),
              ),
            ],
            TextField(
              controller: _durationController,
              decoration: const InputDecoration(labelText: 'Duration (e.g., 2 hours)'),
            ),
            TextField(
              controller: _locationController,
              decoration: const InputDecoration(labelText: 'Location'),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<String>(
                    value: _workType.isEmpty ? null : _workType,
                    decoration: const InputDecoration(labelText: 'Work Type (Installation / CM / PM)'),
                    items: const [
                      DropdownMenuItem(value: 'Installation', child: Text('Installation')),
                      DropdownMenuItem(value: 'CM', child: Text('CM - Corrective Maintenance')),
                      DropdownMenuItem(value: 'PM', child: Text('PM - Preventive Maintenance')),
                    ],
                    onChanged: (v) => setState(() => _workType = v ?? ''),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: DropdownButtonFormField<String>(
                    value: _customerType.isEmpty ? null : _customerType,
                    decoration: const InputDecoration(labelText: 'Customer Type'),
                    items: const [
                      DropdownMenuItem(value: 'Commercial', child: Text('Commercial')),
                      DropdownMenuItem(value: 'Residential', child: Text('Residential')),
                      DropdownMenuItem(value: 'Industrial', child: Text('Industrial')),
                      DropdownMenuItem(value: 'Other', child: Text('Other')),
                    ],
                    onChanged: (v) => setState(() => _customerType = v ?? ''),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _unitsController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'Number of Units'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: _unitDescController,
                    decoration: const InputDecoration(labelText: 'Unit type (e.g. ACU, Split Wall)'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _brandController,
              decoration: const InputDecoration(
                  labelText: 'Brand of unit (e.g. Daikin, Panasonic)'),
            ),
            TextField(
              controller: _unitLocationController,
              decoration: const InputDecoration(
                  labelText: 'Where is the unit located? (e.g. 3rd floor, lobby)'),
            ),
            TextField(
              controller: _installDetailsController,
              decoration: const InputDecoration(
                  labelText: 'How is the unit installed/positioned?'),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _addressController,
              decoration: const InputDecoration(labelText: 'Customer Address (optional)'),
            ),
            TextField(
              controller: _contactController,
              decoration: const InputDecoration(labelText: 'Customer Contact (optional)'),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                const Text('Status:'),
                const SizedBox(width: 8),
                DropdownButton<String>(
                  value: _status,
                  items: const [
                    DropdownMenuItem(value: 'Pending', child: Text('Pending')),
                    DropdownMenuItem(value: 'In progress', child: Text('In progress')),
                    DropdownMenuItem(value: 'Completed', child: Text('Completed')),
                  ],
                  onChanged: (v) {
                    if (v == null) return;
                    setState(() => _status = v);
                  },
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Date Started: ${_dateStarted != null ? "${_dateStarted!.month.toString().padLeft(2, '0')}/${_dateStarted!.day.toString().padLeft(2, '0')}/${_dateStarted!.year}" : "Not set"}'),
                      TextButton(
                        onPressed: _pickDateStarted,
                        child: const Text('Set Date Started'),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Date Completed: ${_dateCompleted != null ? "${_dateCompleted!.month.toString().padLeft(2, '0')}/${_dateCompleted!.day.toString().padLeft(2, '0')}/${_dateCompleted!.year}" : "Not set"}'),
                      TextButton(
                        onPressed: _pickDateCompleted,
                        child: const Text('Set Date Completed'),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: Text(
                      'Schedule Time: ${_dateTime.month.toString().padLeft(2, '0')}/${_dateTime.day.toString().padLeft(2, '0')}/${_dateTime.year} '
                      '${_dateTime.hour.toString().padLeft(2, '0')}:${_dateTime.minute.toString().padLeft(2, '0')}'),
                ),
                TextButton(
                  onPressed: _pickDateTime,
                  child: const Text('Change'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _notesController,
              decoration: const InputDecoration(labelText: 'Work Notes (optional)'),
              maxLines: 2,
            ),
            TextField(
              controller: _followUpController,
              decoration: const InputDecoration(labelText: 'Follow Up Schedule (e.g. February)'),
            ),
            const SizedBox(height: 16),
            const Divider(),
            const SizedBox(height: 8),
            Row(
              children: [
                const Text('Service Items', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                const Spacer(),
                ElevatedButton.icon(
                  onPressed: _manageServiceItems,
                  icon: const Icon(Icons.add, size: 18),
                  label: Text('Add Items (${_selectedServiceItems.length})'),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                  ),
                ),
              ],
            ),
            if (_selectedServiceItems.isNotEmpty) ...[
              const SizedBox(height: 8),
              ..._selectedServiceItems.map((item) => Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(item.serviceItem.itemName, style: const TextStyle(fontWeight: FontWeight.w600)),
                          Text('Qty: ${item.quantity} × ₱${item.actualPrice.toStringAsFixed(2)} = ₱${(item.quantity * item.actualPrice).toStringAsFixed(2)}'),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete_outline, size: 18, color: Colors.red),
                      onPressed: () {
                        setState(() => _selectedServiceItems.remove(item));
                      },
                    ),
                  ],
                ),
              )),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: _submit,
          child: const Text('Save'),
        ),
      ],
    );
  }
}

// Technician Selection Dialog
class _TechnicianSelectionDialog extends StatefulWidget {
  final List<TechnicianData> available;
  final List<JobOrderTechnician> selected;

  const _TechnicianSelectionDialog({required this.available, required this.selected});

  @override
  State<_TechnicianSelectionDialog> createState() => _TechnicianSelectionDialogState();
}

class _TechnicianSelectionDialogState extends State<_TechnicianSelectionDialog> {
  late List<JobOrderTechnician> _selected;
  final Map<int, String> _roles = {}; // technician id -> role

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
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Cancel'),
                ),
                const SizedBox(width: 12),
                ElevatedButton(
                  onPressed: () => Navigator.of(context).pop(_selected),
                  child: const Text('Save'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// Service Item Selection Dialog
class _ServiceItemSelectionDialog extends StatefulWidget {
  final List<ServiceItemData> available;
  final List<JobOrderServiceItem> selected;

  const _ServiceItemSelectionDialog({required this.available, required this.selected});

  @override
  State<_ServiceItemSelectionDialog> createState() => _ServiceItemSelectionDialogState();
}

class _ServiceItemSelectionDialogState extends State<_ServiceItemSelectionDialog> {
  late List<JobOrderServiceItem> _selected;
  final Map<int, int> _quantities = {}; // item id -> quantity
  final Map<int, double> _prices = {}; // item id -> actual price

  @override
  void initState() {
    super.initState();
    _selected = List.from(widget.selected);
    for (var item in _selected) {
      _quantities[item.serviceItem.id] = item.quantity;
      _prices[item.serviceItem.id] = item.actualPrice;
    }
  }

  void _toggleServiceItem(ServiceItemData item) {
    setState(() {
      final existing = _selected.indexWhere((s) => s.serviceItem.id == item.id);
      if (existing >= 0) {
        _selected.removeAt(existing);
        _quantities.remove(item.id);
        _prices.remove(item.id);
      } else {
        _selected.add(JobOrderServiceItem(
          serviceItem: item,
          quantity: _quantities[item.id] ?? 1,
          actualPrice: _prices[item.id] ?? item.price,
        ));
        _quantities[item.id] = _quantities[item.id] ?? 1;
        _prices[item.id] = _prices[item.id] ?? item.price;
      }
    });
  }

  void _updateQuantity(ServiceItemData item, int quantity) {
    setState(() {
      _quantities[item.id] = quantity;
      final index = _selected.indexWhere((s) => s.serviceItem.id == item.id);
      if (index >= 0) {
        _selected[index] = JobOrderServiceItem(
          serviceItem: item,
          quantity: quantity,
          actualPrice: _prices[item.id] ?? item.price,
        );
      }
    });
  }

  void _updatePrice(ServiceItemData item, double price) {
    setState(() {
      _prices[item.id] = price;
      final index = _selected.indexWhere((s) => s.serviceItem.id == item.id);
      if (index >= 0) {
        _selected[index] = JobOrderServiceItem(
          serviceItem: item,
          quantity: _quantities[item.id] ?? 1,
          actualPrice: price,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: Container(
        width: 600,
        height: 600,
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Select Service Items', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
            const SizedBox(height: 16),
            Expanded(
              child: ListView.builder(
                itemCount: widget.available.length,
                itemBuilder: (context, index) {
                  final item = widget.available[index];
                  final isSelected = _selected.any((s) => s.serviceItem.id == item.id);
                  final quantity = _quantities[item.id] ?? 1;
                  final price = _prices[item.id] ?? item.price;
                  
                  return Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: isSelected ? const Color(0xFFEAF2FF) : Colors.white,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: isSelected ? const Color(0xFF2563EB) : const Color(0xFFE2E8F0),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        CheckboxListTile(
                          title: Text(item.itemName, style: const TextStyle(fontWeight: FontWeight.w600)),
                          subtitle: Text('${item.itemType} • Base Price: ₱${item.price.toStringAsFixed(2)}'),
                          value: isSelected,
                          onChanged: (v) => _toggleServiceItem(item),
                          contentPadding: EdgeInsets.zero,
                        ),
                        if (isSelected) ...[
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Expanded(
                                child: TextField(
                                  decoration: const InputDecoration(labelText: 'Quantity', isDense: true),
                                  keyboardType: TextInputType.number,
                                  controller: TextEditingController(text: quantity.toString())
                                    ..selection = TextSelection.collapsed(offset: quantity.toString().length),
                                  onChanged: (v) {
                                    final qty = int.tryParse(v) ?? 1;
                                    if (qty > 0) _updateQuantity(item, qty);
                                  },
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: TextField(
                                  decoration: const InputDecoration(labelText: 'Actual Price (₱)', isDense: true),
                                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                  controller: TextEditingController(text: price.toStringAsFixed(2))
                                    ..selection = TextSelection.collapsed(offset: price.toStringAsFixed(2).length),
                                  onChanged: (v) {
                                    final p = double.tryParse(v) ?? item.price;
                                    if (p > 0) _updatePrice(item, p);
                                  },
                                ),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Cancel'),
                ),
                const SizedBox(width: 12),
                ElevatedButton(
                  onPressed: () => Navigator.of(context).pop(_selected),
                  child: const Text('Save'),
                ),
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
            const Text('Select Aircon Units',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
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
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Cancel'),
                ),
                const SizedBox(width: 12),
                ElevatedButton(
                  onPressed: () => Navigator.of(context).pop(_selected),
                  child: const Text('Save'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}


