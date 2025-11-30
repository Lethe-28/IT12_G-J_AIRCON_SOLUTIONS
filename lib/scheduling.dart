import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'data/app_state.dart';
import 'data/models.dart';
import 'ui_app_shell.dart';
import 'shared/widgets.dart' show LoadingOverlay, LoadingButton, EmptyState, FilterChipGroup, SortableColumnHeader, showConfirmDialog, showUndoSnackBar, AppDesignTokens;

// --- Data Classes ---
class JobOrder {
  final int dbId; 
  final String displayId; 
  String clientName;
  String jobType; 
  DateTime startDateTime;
  DateTime? endDateTime; 
  String location;
  String status;
  String? notes;
  
  JobOrder({
    required this.dbId,
    required this.displayId,
    required this.clientName,
    required this.jobType,
    required this.startDateTime,
    this.endDateTime,
    required this.location,
    required this.status,
    this.notes,
  });
}

// --- Main Screen ---

class SchedulingScreen extends StatefulWidget {
  const SchedulingScreen({super.key});

  @override
  State<SchedulingScreen> createState() => _SchedulingScreenState();
}

class _SchedulingScreenState extends State<SchedulingScreen> {
  List<JobOrder> _orders = [];
  bool _isLoading = true;
  
  // Calendar State
  DateTime _focusedDate = DateTime.now();
  DateTime _selectedDate = DateTime.now();
  
  @override
  void initState() {
    super.initState();
    _fetchJobOrders();
  }

  Future<void> _fetchJobOrders() async {
    setState(() => _isLoading = true);
    final supabase = Supabase.instance.client;

    try {
      // FIX: Added city and barangay to the select query
      final response = await supabase
          .from('job_orders')
          .select('*, customers(first_name, last_name, company_name, city, barangay), job_types(job_type_name)')
          .order('date_scheduled', ascending: false);

      final List<JobOrder> loaded = [];
      
      for (var row in response) {
        final customer = row['customers'];
        String clientName = 'Unknown';
        String location = 'Unknown'; // Default

        if (customer != null) {
          if (customer['company_name'] != null && customer['company_name'].toString().isNotEmpty) {
            clientName = customer['company_name'];
          } else {
            clientName = '${customer['first_name']} ${customer['last_name']}';
          }
          // FIX: Construct location string
          final city = customer['city'] ?? '';
          final brgy = customer['barangay'] ?? '';
          location = "$city $brgy".trim();
          if (location.isEmpty) location = "View Details";
        }

        DateTime start = DateTime.now();
        if (row['date_scheduled'] != null) {
          start = DateTime.parse(row['date_scheduled']);
        }

        DateTime? end;
        if (row['date_completed'] != null) {
          end = DateTime.parse(row['date_completed']);
        }

        loaded.add(JobOrder(
          dbId: row['id'],
          displayId: row['client_jo_number'] ?? 'JO-${row['id']}',
          clientName: clientName,
          jobType: row['job_types']?['job_type_name'] ?? 'Service',
          startDateTime: start,
          endDateTime: end,
          location: location, 
          status: row['status'] ?? 'Pending',
          notes: row['notes'] 
        ));
      }

      if (mounted) setState(() => _orders = loaded);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error loading jobs: $e')));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // --- ACTIONS ---

  void _onAddOrEdit() async {
    final result = await showDialog(
      context: context,
      builder: (context) => _JobOrderDialog(initialDate: _selectedDate),
    );
    
    if (result == true) {
      _fetchJobOrders();
    }
  }

  void _showJobDetails(JobOrder job) {
    showDialog(
      context: context,
      builder: (context) => _JobBillingManager(
        job: job,
        onJobUpdated: _fetchJobOrders,
        onEditRequest: () {
           // Close detail dialog and open edit wizard (TODO: Pre-fill wizard)
           Navigator.pop(context);
           _onAddOrEdit(); 
        },
      ),
    );
  }

  // --- Calendar Logic Helpers ---

  List<JobOrder> _getJobsForDay(DateTime day) {
    return _orders.where((o) {
      final start = DateTime(o.startDateTime.year, o.startDateTime.month, o.startDateTime.day);
      final check = DateTime(day.year, day.month, day.day);
      
      if (o.endDateTime != null) {
        final end = DateTime(o.endDateTime!.year, o.endDateTime!.month, o.endDateTime!.day);
        return (check.isAfter(start) || check.isAtSameMomentAs(start)) && 
               (check.isBefore(end) || check.isAtSameMomentAs(end));
      }
      
      return DateUtils.isSameDay(start, check);
    }).toList();
  }

  void _changeMonth(int increment) {
    setState(() {
      _focusedDate = DateTime(_focusedDate.year, _focusedDate.month + increment);
    });
  }

  @override
  Widget build(BuildContext context) {
    final isMobileView = MediaQuery.of(context).size.width < 600;
    final selectedDayJobs = _getJobsForDay(_selectedDate);

    return AppShell(
      selectedIndex: 1,
      body: LoadingOverlay(
        isLoading: _isLoading,
        child: Container(
          color: const Color(0xFFF8FAFC),
          child: Column(
            children: [
              // 1. Calendar Header
              Container(
                padding: EdgeInsets.symmetric(horizontal: isMobileView ? 16 : 32, vertical: 16),
                color: Colors.white,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        IconButton(
                          icon: const Icon(Icons.chevron_left),
                          onPressed: () => _changeMonth(-1),
                        ),
                        Text(
                          "${_monthName(_focusedDate.month)} ${_focusedDate.year}",
                          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: Color(0xFF1E293B)),
                        ),
                        IconButton(
                          icon: const Icon(Icons.chevron_right),
                          onPressed: () => _changeMonth(1),
                        ),
                      ],
                    ),
                    ElevatedButton.icon(
                      onPressed: _onAddOrEdit,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF2563EB),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      icon: const Icon(Icons.add, size: 18),
                      label: Text(isMobileView ? 'Add' : 'Add Job', style: const TextStyle(fontWeight: FontWeight.w700)),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),

              // 2. The Content Area
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        color: Colors.white,
                        padding: const EdgeInsets.only(bottom: 16),
                        child: _buildCalendarGrid(),
                      ),
                      
                      const Divider(height: 1),
                      
                      Padding(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              "Schedule for ${_monthName(_selectedDate.month)} ${_selectedDate.day}",
                              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: Color(0xFF64748B)),
                            ),
                            const SizedBox(height: 16),
                            
                            if (selectedDayJobs.isEmpty)
                              Center(
                                child: Padding(
                                  padding: const EdgeInsets.all(32.0),
                                  child: Column(
                                    children: [
                                      Icon(Icons.event_available, size: 48, color: Colors.grey[300]),
                                      const SizedBox(height: 12),
                                      const Text("No jobs scheduled for this day.", style: TextStyle(color: Colors.grey)),
                                    ],
                                  ),
                                ),
                              )
                            else
                              ListView.separated(
                                shrinkWrap: true,
                                physics: const NeverScrollableScrollPhysics(),
                                itemCount: selectedDayJobs.length,
                                separatorBuilder: (ctx, i) => const SizedBox(height: 12),
                                itemBuilder: (ctx, i) => GestureDetector(
                                  onTap: () => _showJobDetails(selectedDayJobs[i]),
                                  child: _JobCard(order: selectedDayJobs[i]),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCalendarGrid() {
    final daysInMonth = DateUtils.getDaysInMonth(_focusedDate.year, _focusedDate.month);
    final firstDayOfMonth = DateTime(_focusedDate.year, _focusedDate.month, 1);
    final int firstWeekday = firstDayOfMonth.weekday % 7; 

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"]
                .map((day) => Expanded(child: Center(child: Text(day, style: const TextStyle(color: Colors.grey, fontSize: 12, fontWeight: FontWeight.bold)))))
                .toList(),
          ),
        ),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: daysInMonth + firstWeekday,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 7, 
            childAspectRatio: 1.2,
          ),
          itemBuilder: (context, index) {
            if (index < firstWeekday) return const SizedBox();
            
            final dayInt = index - firstWeekday + 1;
            final currentDay = DateTime(_focusedDate.year, _focusedDate.month, dayInt);
            
            final isSelected = DateUtils.isSameDay(currentDay, _selectedDate);
            final isToday = DateUtils.isSameDay(currentDay, DateTime.now());
            final hasJobs = _getJobsForDay(currentDay).isNotEmpty;

            return GestureDetector(
              onTap: () => setState(() => _selectedDate = currentDay),
              child: Container(
                margin: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: isSelected ? const Color(0xFF2563EB) : (isToday ? const Color(0xFFEFF6FF) : Colors.transparent),
                  borderRadius: BorderRadius.circular(8),
                  border: isToday && !isSelected ? Border.all(color: const Color(0xFF2563EB)) : null,
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      "$dayInt",
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: isSelected ? Colors.white : Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 4),
                    if (hasJobs)
                      Container(
                        width: 6,
                        height: 6,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: isSelected ? Colors.white : Colors.orange,
                        ),
                      )
                    else
                      const SizedBox(height: 6),
                  ],
                ),
              ),
            );
          },
        ),
      ],
    );
  }

  String _monthName(int month) {
    const months = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"];
    return months[month - 1];
  }
}

// --- JOB MANAGEMENT & BILLING HUB (Combined) ---

class _JobBillingManager extends StatefulWidget {
  final JobOrder job;
  final VoidCallback onJobUpdated;
  final VoidCallback onEditRequest;

  const _JobBillingManager({required this.job, required this.onJobUpdated, required this.onEditRequest});

  @override
  State<_JobBillingManager> createState() => _JobBillingManagerState();
}

class _JobBillingManagerState extends State<_JobBillingManager> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _isLoading = true;
  final _supabase = Supabase.instance.client;

  // Billing Data
  List<Map<String, dynamic>> _lineItems = [];
  List<Map<String, dynamic>> _serviceCatalog = [];
  double _totalAmount = 0.0;
  double _totalPaid = 0.0;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _fetchBillingData();
  }

  Future<void> _fetchBillingData() async {
    setState(() => _isLoading = true);
    try {
      final items = await _supabase.from('job_order_line_items').select('id, quantity, actual_price, service_items(item_name)').eq('job_order_id', widget.job.dbId);
      final payments = await _supabase.from('payments').select('amount').eq('job_order_id', widget.job.dbId);
      final catalog = await _supabase.from('service_items').select().order('item_name');

      double total = 0;
      for (var i in items) total += (i['actual_price'] * i['quantity']);

      double paid = 0;
      for (var p in payments) paid += p['amount'];

      if (mounted) {
        setState(() {
          _lineItems = List<Map<String, dynamic>>.from(items);
          _serviceCatalog = List<Map<String, dynamic>>.from(catalog);
          _totalAmount = total;
          _totalPaid = paid;
        });
      }
    } catch (e) {
      debugPrint('Error: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // --- ACTIONS ---
  
  void _deleteJob() async {
    final confirm = await showConfirmDialog(
      context: context, 
      title: "Delete Job?", 
      message: "This will remove the job and all billing records.",
      confirmLabel: "Delete Forever",
      isDestructive: true
    );
    
    if (confirm == true) {
      try {
        await _supabase.from('job_orders').delete().eq('id', widget.job.dbId);
        if (mounted) {
          Navigator.pop(context);
          widget.onJobUpdated();
        }
      } catch (e) {
        if(mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Delete Error: $e")));
      }
    }
  }

  void _onReschedule() async {
    final d = await showDatePicker(context: context, initialDate: widget.job.startDateTime, firstDate: DateTime(2020), lastDate: DateTime(2030));
    if (d != null) {
      await _supabase.from('job_orders').update({'date_scheduled': d.toIso8601String()}).eq('id', widget.job.dbId);
      widget.onJobUpdated();
      if (mounted) Navigator.pop(context);
    }
  }

  void _onExtend() async {
    final d = await showDatePicker(
      context: context, 
      initialDate: widget.job.endDateTime ?? widget.job.startDateTime, 
      firstDate: widget.job.startDateTime, 
      lastDate: DateTime(2030),
      helpText: "Select End Date"
    );
    if (d != null) {
      await _supabase.from('job_orders').update({'date_completed': d.toIso8601String()}).eq('id', widget.job.dbId);
      widget.onJobUpdated();
      if (mounted) Navigator.pop(context);
    }
  }

  void _addItemDialog() {
    int? selectedItemId;
    final priceController = TextEditingController();
    final qtyController = TextEditingController(text: '1');
    final nameController = TextEditingController();
    bool isCustom = false;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            title: const Text("Add Service/Item"),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(children: [
                  Expanded(child: ChoiceChip(label: const Text("From Catalog"), selected: !isCustom, onSelected: (v) => setDialogState(() => isCustom = !v))),
                  const SizedBox(width: 8),
                  Expanded(child: ChoiceChip(label: const Text("Custom Item"), selected: isCustom, onSelected: (v) => setDialogState(() { isCustom = v; selectedItemId = null; priceController.clear(); }))),
                ]),
                const SizedBox(height: 16),
                if (!isCustom)
                  DropdownButtonFormField<int>(
                    value: selectedItemId,
                    isExpanded: true,
                    decoration: const InputDecoration(labelText: "Select Item", border: OutlineInputBorder()),
                    items: _serviceCatalog.map((item) => DropdownMenuItem(value: item['id'] as int, child: Text("${item['item_name']} (₱${item['price']})", overflow: TextOverflow.ellipsis))).toList(),
                    onChanged: (val) {
                      setDialogState(() {
                        selectedItemId = val;
                        final item = _serviceCatalog.firstWhere((i) => i['id'] == val);
                        priceController.text = item['price'].toString();
                      });
                    },
                  )
                else
                  TextFormField(controller: nameController, decoration: const InputDecoration(labelText: "Item Name", border: OutlineInputBorder())),
                const SizedBox(height: 12),
                Row(children: [
                  Expanded(child: TextFormField(controller: priceController, decoration: const InputDecoration(labelText: "Price (₱)", border: OutlineInputBorder()), keyboardType: TextInputType.number)),
                  const SizedBox(width: 12),
                  Expanded(child: TextFormField(controller: qtyController, decoration: const InputDecoration(labelText: "Qty", border: OutlineInputBorder()), keyboardType: TextInputType.number)),
                ]),
              ],
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancel")),
              ElevatedButton(
                onPressed: () async {
                  await _saveLineItem(isCustom: isCustom, itemId: selectedItemId, customName: nameController.text, price: double.tryParse(priceController.text) ?? 0, qty: double.tryParse(qtyController.text) ?? 1);
                  if (mounted) Navigator.pop(context);
                },
                child: const Text("Add to Bill"),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _saveLineItem({required bool isCustom, int? itemId, String? customName, required double price, required double qty}) async {
    try {
      int finalItemId;
      if (isCustom) {
        final res = await _supabase.from('service_items').insert({'item_name': customName ?? 'Custom Service', 'item_type': 'Custom', 'price': price}).select('id').single();
        finalItemId = res['id'];
      } else {
        if (itemId == null) return;
        finalItemId = itemId;
      }
      await _supabase.from('job_order_line_items').insert({'job_order_id': widget.job.dbId, 'service_item_id': finalItemId, 'quantity': qty, 'actual_price': price});
      _fetchBillingData(); 
    } catch (e) {
      if(mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e")));
    }
  }

  void _recordPaymentDialog() {
    final amountController = TextEditingController(text: (_totalAmount - _totalPaid).toString());
    String method = 'Cash';
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Record Payment"),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
            const Text("Record cash-in from client."),
            const SizedBox(height: 16),
            TextFormField(controller: amountController, decoration: const InputDecoration(labelText: "Amount Received", prefixText: "₱ ", border: OutlineInputBorder()), keyboardType: TextInputType.number),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(value: method, decoration: const InputDecoration(labelText: "Payment Method", border: OutlineInputBorder()), items: ['Cash', 'GCash', 'Bank Transfer', 'Cheque'].map((m) => DropdownMenuItem(value: m, child: Text(m))).toList(), onChanged: (v) => method = v!),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancel")),
          ElevatedButton(style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white), onPressed: () async {
              await _supabase.from('payments').insert({'job_order_id': widget.job.dbId, 'amount': double.tryParse(amountController.text) ?? 0, 'payment_method': method, 'payment_date': DateTime.now().toIso8601String(), 'status': 'Verified'});
              if (mounted) { Navigator.pop(context); _fetchBillingData(); ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Payment Recorded!"))); }
            }, child: const Text("Confirm Payment")),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // FIX: Using LayoutBuilder to control height dynamically
    return LayoutBuilder(
      builder: (context, constraints) {
        return Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: Container(
            width: 500,
            // FIX: Dynamic height (80% of screen) to prevent overflow
            height: constraints.maxHeight * 0.8, 
            color: Colors.white,
            child: Column(
              children: [
                // Header
                Container(
                  padding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Expanded(child: Text(widget.job.clientName, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold))), IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close))]),
                      Text("${widget.job.jobType} • ${widget.job.displayId}", style: const TextStyle(color: Colors.grey)),
                      const SizedBox(height: 16),
                      TabBar(controller: _tabController, labelColor: Colors.blue, unselectedLabelColor: Colors.grey, indicatorColor: Colors.blue, tabs: const [Tab(text: "Details & Actions"), Tab(text: "Billing & Payment")]),
                    ],
                  ),
                ),
                const Divider(height: 1),
                Expanded(child: _isLoading ? const Center(child: CircularProgressIndicator()) : TabBarView(controller: _tabController, children: [_buildDetailsTab(), _buildBillingTab()])),
              ],
            ),
          ),
        );
      }
    );
  }

  Widget _buildDetailsTab() {
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        _infoSection("Schedule", [_infoRow(Icons.calendar_today, "${widget.job.startDateTime.toLocal()}".split('.')[0]), _infoRow(Icons.location_on, widget.job.location)]),
        const SizedBox(height: 24),
        const Text("Quick Actions", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
        const SizedBox(height: 12),
        // FIX: Restored REST of buttons
        Wrap(spacing: 12, runSpacing: 12, children: [
            _ActionButton(icon: Icons.edit, label: "Edit Details", color: Colors.blue, onTap: widget.onEditRequest),
            _ActionButton(icon: Icons.calendar_month, label: "Reschedule", color: Colors.orange, onTap: _onReschedule),
            _ActionButton(icon: Icons.update, label: "Extend Job", color: Colors.purple, onTap: _onExtend),
            _ActionButton(icon: Icons.delete, label: "Delete Job", color: Colors.red, onTap: _deleteJob),
        ]),
      ],
    );
  }

  Widget _buildBillingTab() {
    final balance = _totalAmount - _totalPaid;
    final isPaid = balance <= 0 && _totalAmount > 0;
    return Column(children: [
        Expanded(child: _lineItems.isEmpty ? EmptyState(icon: Icons.receipt_long, title: "No Items Yet", message: "Add services or parts to create the bill.", actionLabel: "Add Item", onAction: _addItemDialog) : ListView.separated(padding: const EdgeInsets.all(24), itemCount: _lineItems.length, separatorBuilder: (ctx, i) => const Divider(), itemBuilder: (ctx, i) { final item = _lineItems[i]; final name = item['service_items']['item_name']; final price = item['actual_price']; final qty = item['quantity']; return Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(name, style: const TextStyle(fontWeight: FontWeight.w600)), Text("$qty x ₱$price", style: const TextStyle(fontSize: 12, color: Colors.grey))])), Text("₱${(price * qty).toStringAsFixed(2)}", style: const TextStyle(fontWeight: FontWeight.bold))]); })),
        Container(padding: const EdgeInsets.all(24), decoration: BoxDecoration(color: Colors.grey[50], border: const Border(top: BorderSide(color: Color(0xFFE2E8F0)))), child: Column(children: [_totalRow("Total Bill", _totalAmount), _totalRow("Paid", _totalPaid, color: Colors.green), const Divider(height: 24), _totalRow("Balance Due", balance, isBold: true, color: balance > 0 ? Colors.red : Colors.grey), const SizedBox(height: 20), Row(children: [Expanded(child: OutlinedButton.icon(onPressed: _addItemDialog, icon: const Icon(Icons.add), label: const Text("Add Item"), style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16)))), const SizedBox(width: 12), Expanded(child: ElevatedButton.icon(onPressed: isPaid ? null : _recordPaymentDialog, icon: const Icon(Icons.payment), label: Text(isPaid ? "Paid" : "Record Payment"), style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 16))))])])),
    ]);
  }

  Widget _totalRow(String label, double value, {bool isBold = false, Color? color}) {
    return Padding(padding: const EdgeInsets.symmetric(vertical: 4), child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text(label, style: TextStyle(fontWeight: isBold ? FontWeight.bold : FontWeight.normal, fontSize: isBold ? 16 : 14)), Text("₱${value.toStringAsFixed(2)}", style: TextStyle(fontWeight: isBold ? FontWeight.bold : FontWeight.normal, fontSize: isBold ? 18 : 14, color: color))]));
  }

  Widget _infoSection(String title, List<Widget> children) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(title, style: const TextStyle(color: Colors.grey, fontWeight: FontWeight.bold, fontSize: 12)), const SizedBox(height: 8), ...children]);
  }

  Widget _infoRow(IconData icon, String text) {
    return Padding(padding: const EdgeInsets.only(bottom: 8), child: Row(children: [Icon(icon, size: 16, color: Colors.grey), const SizedBox(width: 8), Expanded(child: Text(text))]));
  }
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;
  const _ActionButton({required this.icon, required this.label, required this.color, required this.onTap});
  @override
  Widget build(BuildContext context) {
    return InkWell(onTap: onTap, borderRadius: BorderRadius.circular(8), child: Container(width: 100, padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8), decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(8), border: Border.all(color: color.withOpacity(0.3))), child: Column(children: [Icon(icon, color: color, size: 20), const SizedBox(height: 4), Text(label, style: TextStyle(color: color, fontWeight: FontWeight.w600, fontSize: 12))])));
  }
}

// --- VISUAL WIZARD DIALOG ---

class _JobOrderDialog extends StatefulWidget {
  final DateTime? initialDate;
  const _JobOrderDialog({this.initialDate});
  @override
  State<_JobOrderDialog> createState() => _JobOrderDialogState();
}

class _JobOrderDialogState extends State<_JobOrderDialog> {
  int _currentStep = 0;
  bool _isSubmitting = false;
  final _supabase = Supabase.instance.client;
  final _formKey = GlobalKey<FormState>();

  // Data
  String _jobTypeName = 'Installation'; 
  int? _jobTypeId;
  bool _isNewClient = false;
  List<Map<String, dynamic>> _existingClients = [];
  List<String> _brandOptions = []; 
  List<Map<String, dynamic>> _airconTypes = []; 
  int? _selectedClientId;
  List<Map<String, dynamic>> _clientAircons = [];
  final List<int> _selectedAirconIds = [];

  // Controllers
  final _firstNameController = TextEditingController();
  final _middleNameController = TextEditingController(); 
  final _lastNameController = TextEditingController(); 
  final _companyController = TextEditingController();
  final _jobPositionController = TextEditingController();
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();
  final _unitController = TextEditingController();
  final _streetController = TextEditingController();
  final _villageController = TextEditingController();
  final _barangayController = TextEditingController();
  final _cityController = TextEditingController();
  final _landmarkController = TextEditingController();
  
  String _selectedBrandName = ''; 
  int? _selectedAirconTypeId;
  final _unitRemarkController = TextEditingController();

  late DateTime _scheduleDate;
  TimeOfDay _scheduleTime = const TimeOfDay(hour: 9, minute: 0);
  final _notesController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _scheduleDate = widget.initialDate ?? DateTime.now();
    _fetchInitialData();
  }

  Future<void> _fetchInitialData() async {
    final customers = await _supabase
        .from('customers')
        .select('id, first_name, last_name, company_name, city, barangay')
        .order('last_name', ascending: true);
    
    final types = await _supabase.from('job_types').select();
    final brands = await _supabase.from('brands').select('brand_name').order('brand_name');
    final acTypes = await _supabase.from('aircon_types').select('id, type_name');
    
    if (mounted) {
      setState(() {
        _existingClients = List<Map<String, dynamic>>.from(customers);
        _brandOptions = List<String>.from(brands.map((b) => b['brand_name']));
        _airconTypes = List<Map<String, dynamic>>.from(acTypes);
        
        final installType = types.firstWhere((t) => t['job_type_name'] == 'Installation', orElse: () => types.first);
        _jobTypeId = installType['id']; 
        
        if (_airconTypes.isNotEmpty) {
          _selectedAirconTypeId = _airconTypes.first['id'];
        }
      });
    }
  }

  Future<void> _fetchClientAircons(int clientId) async {
    final units = await _supabase
        .from('aircons')
        .select('id, remarks, brands(brand_name), aircon_types(type_name)')
        .eq('customer_id', clientId);
    
    if (mounted) {
      setState(() {
        _clientAircons = List<Map<String, dynamic>>.from(units);
        _selectedAirconIds.clear(); 
      });
    }
  }

  // --- VALIDATORS ---
  String? _validatePhone(String? value) {
    if (value == null || value.isEmpty) return 'Required';
    final trimmed = value.trim();
    if (!RegExp(r'^(09\d{9}|\d{7,10})$').hasMatch(trimmed)) {
      return 'Invalid #';
    }
    return null;
  }

  String? _validateEmail(String? value) {
    if (value == null || value.isEmpty) return null; 
    if (!value.contains('@') || !value.contains('.')) return 'Invalid email';
    return null;
  }

  // --- SUBMIT ---
  Future<void> _submit() async {
    if (_isNewClient) {
      if (!_formKey.currentState!.validate()) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Please fix errors in red"), backgroundColor: Colors.red));
        return; 
      }
    }

    setState(() => _isSubmitting = true);

    try {
      int? finalCustomerId = _selectedClientId;

      // 1. CREATE CUSTOMER
      if (_isNewClient) {
        final newCustomerData = {
          'first_name': _firstNameController.text,
          'middle_name': _middleNameController.text.isNotEmpty ? _middleNameController.text : null,
          'last_name': _lastNameController.text,
          'company_name': _companyController.text.isNotEmpty ? _companyController.text : null,
          'job_position': _jobPositionController.text.isNotEmpty ? _jobPositionController.text : null,
          'contact_number': _phoneController.text,
          'email': _emailController.text.isNotEmpty ? _emailController.text : null,
          'unit_building_house_no': _unitController.text,
          'street': _streetController.text,
          'subdivision_village': _villageController.text,
          'barangay': _barangayController.text,
          'city': _cityController.text,
          'landmark': _landmarkController.text,
          'customer_type_id': _companyController.text.isNotEmpty ? 1 : 2, 
        };
        final custRes = await _supabase.from('customers').insert(newCustomerData).select('id').single();
        finalCustomerId = custRes['id'];
      }

      if (finalCustomerId == null) throw "Customer ID missing";

      // 2. CREATE AIRCON
      if (_isNewClient && _selectedBrandName.isNotEmpty) {
        final brandName = _selectedBrandName.trim();
        int brandId;
        final brandCheck = await _supabase.from('brands').select('id').ilike('brand_name', brandName).maybeSingle();
        if (brandCheck != null) {
          brandId = brandCheck['id'];
        } else {
          final newBrand = await _supabase.from('brands').insert({'brand_name': brandName}).select('id').single();
          brandId = newBrand['id'];
        }

        final newAircon = await _supabase.from('aircons').insert({
          'customer_id': finalCustomerId,
          'brand_id': brandId,
          'aircon_type_id': _selectedAirconTypeId ?? 1, 
          'remarks': _unitRemarkController.text.isNotEmpty ? _unitRemarkController.text : 'New Unit',
        }).select('id').single();
        _selectedAirconIds.add(newAircon['id']);
      }

      // 3. CREATE JOB
      final typeRes = await _supabase.from('job_types').select('id').eq('job_type_name', _jobTypeName).maybeSingle();
      final correctTypeId = typeRes != null ? typeRes['id'] : _jobTypeId;

      final scheduleDateTime = DateTime(
        _scheduleDate.year, _scheduleDate.month, _scheduleDate.day,
        _scheduleTime.hour, _scheduleTime.minute
      );

      final joRes = await _supabase.from('job_orders').insert({
        'customer_id': finalCustomerId,
        'job_type_id': correctTypeId,
        'date_scheduled': scheduleDateTime.toIso8601String(),
        'status': 'Pending',
        'user_id': _supabase.auth.currentUser?.id,
        'client_jo_number': 'JO-${DateTime.now().millisecondsSinceEpoch.toString().substring(9)}',
      }).select('id').single();

      final int newJoId = joRes['id'];

      // 4. LINK AIRCONS
      for (int airconId in _selectedAirconIds) {
        await _supabase.from('job_order_aircons').insert({
          'job_order_id': newJoId,
          'aircon_id': airconId,
        });
      }

      if (mounted) {
        Navigator.pop(context, true);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Job Order Created!")));
      }

    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e"), backgroundColor: Colors.red));
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    // FIX: Using LayoutBuilder for dynamic sizing
    return LayoutBuilder(
      builder: (context, constraints) {
        return Dialog(
          insetPadding: constraints.maxWidth < 600 ? EdgeInsets.zero : const EdgeInsets.all(40),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: Container(
            width: constraints.maxWidth < 600 ? double.infinity : 600,
            // FIX: Allow dialog to be 85% of screen height to prevent overflow
            height: constraints.maxHeight * 0.85,
            color: Colors.white,
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0)))),
                  child: Row(
                    children: [
                      if (_currentStep > 0) IconButton(icon: const Icon(Icons.arrow_back), onPressed: () => setState(() => _currentStep--)),
                      Expanded(
                        child: Text(
                          _currentStep == 0 ? "Service Type" : _currentStep == 1 ? "Customer & Asset" : "Schedule",
                          textAlign: TextAlign.center,
                          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                      ),
                      IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(context)),
                    ],
                  ),
                ),
                
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: _buildCurrentStep(),
                  ),
                ),

                Padding(
                  padding: const EdgeInsets.all(24),
                  child: SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      onPressed: _isSubmitting ? null : (_currentStep == 2 ? _submit : () => setState(() => _currentStep++)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF2563EB),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: _isSubmitting 
                        ? const CircularProgressIndicator(color: Colors.white) 
                        : Text(_currentStep == 2 ? 'Create Job Order' : 'Next Step', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      }
    );
  }

  Widget _buildCurrentStep() {
    if (_currentStep == 0) return _stepOne();
    if (_currentStep == 1) return _stepTwo();
    return _stepThree();
  }

  Widget _stepOne() {
    return SingleChildScrollView(
      child: Column(
        children: [
          _BigVisualOption(icon: Icons.build_circle_outlined, title: "Installation", color: Colors.blue, isSelected: _jobTypeName == 'Installation', onTap: () => setState(() => _jobTypeName = 'Installation')),
          const SizedBox(height: 12),
          _BigVisualOption(icon: Icons.cleaning_services_outlined, title: "Maintenance", color: Colors.green, isSelected: _jobTypeName == 'Maintenance', onTap: () => setState(() => _jobTypeName = 'Maintenance')),
          const SizedBox(height: 12),
          _BigVisualOption(icon: Icons.handyman_outlined, title: "Repair", color: Colors.orange, isSelected: _jobTypeName == 'Repair', onTap: () => setState(() => _jobTypeName = 'Repair')),
          const SizedBox(height: 12),
          _BigVisualOption(icon: Icons.remove_circle_outline, title: "De-installation", color: Colors.red, isSelected: _jobTypeName == 'De-installation', onTap: () => setState(() => _jobTypeName = 'De-installation')),
        ],
      ),
    );
  }

  Widget _stepTwo() {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(color: Colors.grey[100], borderRadius: BorderRadius.circular(12)),
            child: Row(
              children: [
                Expanded(child: _ToggleOption(label: "Existing", isSelected: !_isNewClient, onTap: () => setState(() => _isNewClient = false))),
                Expanded(child: _ToggleOption(label: "New Client", isSelected: _isNewClient, onTap: () => setState(() => _isNewClient = true))),
              ],
            ),
          ),
          const SizedBox(height: 20),

          if (!_isNewClient) ...[
            const Text("Search Database", style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            DropdownButtonFormField<int>(
              value: _selectedClientId,
              isExpanded: true,
              decoration: InputDecoration(
                hintText: "Select Customer...",
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                filled: true, fillColor: Colors.white,
              ),
              items: _existingClients.map((c) {
                final name = c['company_name'] ?? '${c['first_name']} ${c['last_name']}';
                final loc = c['barangay'] ?? c['city'] ?? '';
                return DropdownMenuItem(value: c['id'] as int, child: Text("$name ($loc)"));
              }).toList(),
              onChanged: (val) {
                setState(() => _selectedClientId = val);
                if (val != null) _fetchClientAircons(val);
              },
            ),
            if (_selectedClientId != null && _clientAircons.isNotEmpty) ...[
              const SizedBox(height: 20),
              const Text("Select Units", style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              ..._clientAircons.map((unit) {
                final brand = unit['brands'] != null ? unit['brands']['brand_name'] : 'Unknown';
                final type = unit['aircon_types'] != null ? unit['aircon_types']['type_name'] : 'Unit';
                return CheckboxListTile(
                  title: Text("$brand $type"),
                  subtitle: Text(unit['remarks'] ?? ''),
                  value: _selectedAirconIds.contains(unit['id']),
                  onChanged: (v) {
                    setState(() {
                      if (v == true) _selectedAirconIds.add(unit['id']);
                      else _selectedAirconIds.remove(unit['id']);
                    });
                  },
                );
              }),
            ]
          ] else ...[
            Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text("Client Info", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blue)),
                  const SizedBox(height: 12),
                  // FIX: Layout to prevent overflow
                  Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Expanded(child: _SimpleInput(controller: _firstNameController, hint: "First Name", icon: Icons.person, isRequired: true, textCapitalization: TextCapitalization.words)),
                    const SizedBox(width: 8),
                    Expanded(child: _SimpleInput(controller: _middleNameController, hint: "Middle (Opt)", textCapitalization: TextCapitalization.words)),
                  ]),
                  const SizedBox(height: 12),
                  _SimpleInput(controller: _lastNameController, hint: "Last Name", isRequired: true, textCapitalization: TextCapitalization.words),
                  const SizedBox(height: 12),
                  _SimpleInput(controller: _companyController, hint: "Company Name (Optional)", icon: Icons.business, textCapitalization: TextCapitalization.words),
                  const SizedBox(height: 12),
                  _SimpleInput(controller: _jobPositionController, hint: "Job Position (e.g. Manager)", icon: Icons.badge, textCapitalization: TextCapitalization.words),
                  const SizedBox(height: 12),
                  Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Expanded(child: _SimpleInput(controller: _phoneController, hint: "Mobile/Landline", icon: Icons.phone, isRequired: true, keyboardType: TextInputType.phone, validator: _validatePhone)),
                    const SizedBox(width: 12),
                    Expanded(child: _SimpleInput(controller: _emailController, hint: "Email Address", icon: Icons.email, keyboardType: TextInputType.emailAddress, validator: _validateEmail)),
                  ]),
                  
                  const SizedBox(height: 24),
                  const Text("Detailed Address", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blue)),
                  const SizedBox(height: 12),
                  Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Expanded(child: _SimpleInput(controller: _unitController, hint: "Unit/House #")),
                    const SizedBox(width: 12),
                    Expanded(child: _SimpleInput(controller: _streetController, hint: "Street Name", isRequired: true, textCapitalization: TextCapitalization.words)),
                  ]),
                  const SizedBox(height: 12),
                  _SimpleInput(controller: _villageController, hint: "Subdivision / Village", textCapitalization: TextCapitalization.words),
                  const SizedBox(height: 12),
                  Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Expanded(child: _SimpleInput(controller: _barangayController, hint: "Barangay", isRequired: true, textCapitalization: TextCapitalization.words)),
                    const SizedBox(width: 12),
                    Expanded(child: _SimpleInput(controller: _cityController, hint: "City", icon: Icons.location_city, isRequired: true, textCapitalization: TextCapitalization.words)),
                  ]),
                  const SizedBox(height: 12),
                  _SimpleInput(controller: _landmarkController, hint: "Landmark (Near...)", icon: Icons.flag, textCapitalization: TextCapitalization.sentences),

                  const SizedBox(height: 24),
                  const Text("First Aircon Unit", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blue)),
                  const SizedBox(height: 12),
                  Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Expanded(
                      child: LayoutBuilder(
                        builder: (context, constraints) {
                          return Autocomplete<String>(
                            optionsBuilder: (TextEditingValue textEditingValue) {
                              if (textEditingValue.text == '') return const Iterable<String>.empty();
                              return _brandOptions.where((String option) {
                                return option.toLowerCase().contains(textEditingValue.text.toLowerCase());
                              });
                            },
                            onSelected: (String selection) {
                              _selectedBrandName = selection;
                            },
                            fieldViewBuilder: (context, textEditingController, focusNode, onFieldSubmitted) {
                              textEditingController.addListener(() {
                                _selectedBrandName = textEditingController.text;
                              });
                              return TextFormField(
                                controller: textEditingController,
                                focusNode: focusNode,
                                decoration: InputDecoration(
                                  label: RichText(text: TextSpan(text: "Brand (Search/Add)", style: TextStyle(color: Colors.grey[600], fontSize: 14), children: const [TextSpan(text: ' *', style: TextStyle(color: Colors.red))])),
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                                  filled: true, fillColor: Colors.white,
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                                ),
                                validator: (val) => val == null || val.isEmpty ? 'Required' : null,
                              );
                            },
                          );
                        }
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: DropdownButtonFormField<int>(
                        value: _selectedAirconTypeId,
                        decoration: InputDecoration(
                          hintText: "Type",
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                          filled: true, fillColor: Colors.white,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                        ),
                        items: _airconTypes.map((t) => DropdownMenuItem(value: t['id'] as int, child: Text(t['type_name']))).toList(),
                        onChanged: (v) => setState(() => _selectedAirconTypeId = v),
                      ),
                    ),
                  ]),
                  const SizedBox(height: 12),
                  _SimpleInput(controller: _unitRemarkController, hint: "Location (e.g. Lobby)", isRequired: true, textCapitalization: TextCapitalization.words),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _stepThree() {
    return Column(
      children: [
        const Text("Date & Time", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        const SizedBox(height: 16),
        ListTile(
          tileColor: Colors.grey[50],
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: Colors.grey.shade300)),
          leading: const Icon(Icons.calendar_month, color: Colors.blue),
          title: Text("${_scheduleDate.toLocal()}".split(' ')[0]),
          onTap: () async {
            final d = await showDatePicker(context: context, initialDate: _scheduleDate, firstDate: DateTime.now(), lastDate: DateTime(2030));
            if (d != null) setState(() => _scheduleDate = d);
          },
        ),
        const SizedBox(height: 12),
        ListTile(
          tileColor: Colors.grey[50],
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: Colors.grey.shade300)),
          leading: const Icon(Icons.access_time, color: Colors.orange),
          title: Text(_scheduleTime.format(context)),
          onTap: () async {
            final t = await showTimePicker(context: context, initialTime: _scheduleTime);
            if (t != null) setState(() => _scheduleTime = t);
          },
        ),
        const SizedBox(height: 20),
        TextField(
          controller: _notesController,
          maxLines: 3,
          decoration: InputDecoration(
            hintText: "Additional Notes...",
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            filled: true, fillColor: Colors.grey[50],
          ),
        ),
      ],
    );
  }
}

// --- VISUAL HELPERS ---

class _BigVisualOption extends StatelessWidget {
  final IconData icon;
  final String title;
  final Color color;
  final bool isSelected;
  final VoidCallback onTap;

  const _BigVisualOption({required this.icon, required this.title, required this.color, required this.isSelected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected ? color.withOpacity(0.1) : Colors.white,
          border: Border.all(color: isSelected ? color : Colors.grey.shade200, width: 2),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(children: [
          Icon(icon, color: isSelected ? color : Colors.grey, size: 28),
          const SizedBox(width: 16),
          Text(title, style: TextStyle(fontSize: 16, fontWeight: isSelected ? FontWeight.bold : FontWeight.normal)),
          const Spacer(),
          if (isSelected) Icon(Icons.check_circle, color: color),
        ]),
      ),
    );
  }
}

class _ToggleOption extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;
  const _ToggleOption({required this.label, required this.isSelected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
          boxShadow: isSelected ? [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 2)] : null,
        ),
        child: Text(label, textAlign: TextAlign.center, style: TextStyle(fontWeight: isSelected ? FontWeight.bold : FontWeight.normal, color: isSelected ? Colors.blue : Colors.grey)),
      ),
    );
  }
}

// UPDATED: Now uses TextFormField for Validation
class _SimpleInput extends StatelessWidget {
  final TextEditingController controller;
  final IconData? icon;
  final String hint;
  final bool isRequired;
  final String? Function(String?)? validator;
  final TextInputType? keyboardType;
  final TextCapitalization textCapitalization;
  
  const _SimpleInput({
    required this.controller, 
    this.icon, 
    required this.hint, 
    this.isRequired = false,
    this.validator,
    this.keyboardType,
    this.textCapitalization = TextCapitalization.none,
  });

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      textCapitalization: textCapitalization,
      validator: (value) {
        if (isRequired && (value == null || value.isEmpty)) {
          return '$hint is required';
        }
        if (validator != null) {
          return validator!(value);
        }
        return null;
      },
      decoration: InputDecoration(
        label: RichText(
          text: TextSpan(
            text: hint,
            style: TextStyle(color: Colors.grey[600], fontSize: 14),
            children: [
              if (isRequired) const TextSpan(text: ' *', style: TextStyle(color: Colors.red)),
            ],
          ),
        ),
        prefixIcon: icon != null ? Icon(icon, size: 20) : null,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        filled: true, fillColor: Colors.white,
      ),
    );
  }
}

class _JobCard extends StatelessWidget {
  final JobOrder order;
  const _JobCard({required this.order});

  @override
  Widget build(BuildContext context) {
    // If job spans multiple days, show range
    String dateText = "${order.startDateTime.month}/${order.startDateTime.day}";
    if (order.endDateTime != null) {
      dateText += " - ${order.endDateTime!.month}/${order.endDateTime!.day}";
    } else {
      dateText += " ${order.startDateTime.hour}:${order.startDateTime.minute.toString().padLeft(2, '0')}";
    }

    return Container(
      width: double.infinity, 
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 4, offset: const Offset(0, 2))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Text(order.jobType, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.blue)),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(color: Colors.orange.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
              child: Text(order.status, style: const TextStyle(fontSize: 10, color: Colors.deepOrange, fontWeight: FontWeight.bold)),
            ),
          ]),
          const SizedBox(height: 8),
          Text(order.clientName, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          // FIX: Shows the actual address (City/Barangay) instead of 'View Details'
          Text(order.location, style: const TextStyle(color: Colors.grey)),
          const SizedBox(height: 4),
          Row(children: [
            const Icon(Icons.calendar_today, size: 12, color: Colors.grey),
            const SizedBox(width: 4),
            Text(dateText, style: const TextStyle(fontSize: 13, color: Colors.grey)),
          ]),
        ],
      ),
    );
  }
}