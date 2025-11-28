import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'data/app_state.dart';
import 'data/models.dart';
import 'ui_app_shell.dart';
import 'calendar_view.dart';
import 'shared/widgets.dart'
    show
        LoadingOverlay,
        LoadingButton,
        EmptyState,
        FilterChipGroup,
        SortableColumnHeader,
        showConfirmDialog,
        showUndoSnackBar,
        AppDesignTokens;

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
  DateTime dateTime;
  String location;
  String status;
  String? notes;

  JobOrder({
    required this.id,
    required this.clientName,
    required this.jobType,
    required this.dateTime,
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
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _fetchJobOrders();
  }

  Future<void> _fetchJobOrders() async {
    setState(() => _isLoading = true);
    final supabase = Supabase.instance.client;

    try {
      final response = await supabase
          .from('job_orders')
          .select(
            '*, customers(first_name, last_name, company_name), job_types(job_type_name)',
          )
          .order('date_scheduled', ascending: false);

      final List<JobOrder> loaded = [];

      for (var row in response) {
        final customer = row['customers'];
        String clientName = 'Unknown';
        if (customer != null) {
          if (customer['company_name'] != null &&
              customer['company_name'].toString().isNotEmpty) {
            clientName = customer['company_name'];
          } else {
            clientName = '${customer['first_name']} ${customer['last_name']}';
          }
        }

        DateTime date = DateTime.now();
        if (row['date_scheduled'] != null) {
          date = DateTime.parse(row['date_scheduled']);
        }

        loaded.add(
          JobOrder(
            id: row['client_jo_number'] ?? 'JO-${row['id']}',
            clientName: clientName,
            jobType: row['job_types']?['job_type_name'] ?? 'Service',
            dateTime: date,
            location: 'View Details',
            status: row['status'] ?? 'Pending',
          ),
        );
      }

      if (mounted) setState(() => _orders = loaded);
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error loading jobs: $e')));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _onAddOrEdit() async {
    final result = await showDialog(
      context: context,
      builder: (context) => const _JobOrderDialog(),
    );

    if (result == true) {
      _fetchJobOrders();
    }
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _orders
        .where(
          (o) =>
              o.clientName.toLowerCase().contains(_searchQuery.toLowerCase()) ||
              o.id.toLowerCase().contains(_searchQuery.toLowerCase()),
        )
        .toList();

    final isMobileView = MediaQuery.of(context).size.width < 600;

    return AppShell(
      selectedIndex: 1,
      body: LoadingOverlay(
        isLoading: _isLoading,
        child: Container(
          color: const Color(0xFFF8FAFC),
          child: Column(
            children: [
              Container(
                padding: EdgeInsets.symmetric(
                  horizontal: isMobileView ? 16 : 32,
                  vertical: 16,
                ),
                color: Colors.white,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Job Orders',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF1E293B),
                      ),
                    ),
                    ElevatedButton.icon(
                      onPressed: _onAddOrEdit,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF2563EB),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 16,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      icon: const Icon(Icons.add_circle, size: 20),
                      label: const Text(
                        'Create Job',
                        style: TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    children: [
                      TextField(
                        onChanged: (v) => setState(() => _searchQuery = v),
                        decoration: InputDecoration(
                          hintText: 'Search jobs...',
                          prefixIcon: const Icon(Icons.search),
                          filled: true,
                          fillColor: Colors.white,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide.none,
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                      if (filtered.isEmpty)
                        const Padding(
                          padding: EdgeInsets.all(40),
                          child: Text("No jobs found."),
                        )
                      else
                        Wrap(
                          spacing: 16,
                          runSpacing: 16,
                          children: filtered
                              .map((o) => _JobCard(order: o))
                              .toList(),
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
}

// --- VISUAL WIZARD DIALOG ---

class _JobOrderDialog extends StatefulWidget {
  const _JobOrderDialog();
  @override
  State<_JobOrderDialog> createState() => _JobOrderDialogState();
}

class _JobOrderDialogState extends State<_JobOrderDialog> {
  int _currentStep = 0;
  bool _isSubmitting = false;
  final _supabase = Supabase.instance.client;

  // STEP 1 DATA
  String _jobTypeName = 'Installation';
  int? _jobTypeId;

  // STEP 2 DATA
  bool _isNewClient = false;

  // Lookup Data
  List<Map<String, dynamic>> _existingClients = [];
  List<String> _brandOptions = []; // For Autocomplete
  List<Map<String, dynamic>> _airconTypes = []; // For Dropdown

  int? _selectedClientId;
  List<Map<String, dynamic>> _clientAircons = [];
  final List<int> _selectedAirconIds = [];

  // New Client Data
  final _firstNameController = TextEditingController();
  final _middleNameController = TextEditingController(); // ADDED
  final _lastNameController = TextEditingController();
  final _companyController = TextEditingController();
  final _jobPositionController = TextEditingController();
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();

  // Detailed Address Fields
  final _unitController = TextEditingController();
  final _streetController = TextEditingController();
  final _villageController = TextEditingController();
  final _barangayController = TextEditingController();
  final _cityController = TextEditingController();
  final _landmarkController = TextEditingController();

  // New Unit Data
  // Note: We use Autocomplete, so we need a way to capture the text
  String _selectedBrandName = '';
  int? _selectedAirconTypeId;
  final _unitRemarkController = TextEditingController();

  // STEP 3 DATA
  DateTime _scheduleDate = DateTime.now();
  TimeOfDay _scheduleTime = const TimeOfDay(hour: 9, minute: 0);
  final _notesController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _fetchInitialData();
  }

  Future<void> _fetchInitialData() async {
    // 1. Fetch Customers
    final customers = await _supabase
        .from('customers')
        .select('id, first_name, last_name, company_name, city, barangay')
        .order('last_name', ascending: true);

    // 2. Fetch Job Types
    final types = await _supabase.from('job_types').select();

    // 3. Fetch Brands (For Autocomplete)
    final brands = await _supabase
        .from('brands')
        .select('brand_name')
        .order('brand_name');

    // 4. Fetch Aircon Types (For Dropdown)
    final acTypes = await _supabase
        .from('aircon_types')
        .select('id, type_name');

    if (mounted) {
      setState(() {
        _existingClients = List<Map<String, dynamic>>.from(customers);
        _brandOptions = List<String>.from(brands.map((b) => b['brand_name']));
        _airconTypes = List<Map<String, dynamic>>.from(acTypes);

        // Defaults
        final installType = types.firstWhere(
          (t) => t['job_type_name'] == 'Installation',
          orElse: () => types.first,
        );
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

  Future<void> _submit() async {
    setState(() => _isSubmitting = true);

    try {
      int? finalCustomerId = _selectedClientId;

      // 1. CREATE CUSTOMER (If New)
      if (_isNewClient) {
        // Validate required fields
        if (_firstNameController.text.isEmpty ||
            _lastNameController.text.isEmpty ||
            _phoneController.text.isEmpty) {
          throw "Please fill in all required customer fields (*)";
        }

        final newCustomerData = {
          'first_name': _firstNameController.text,
          'middle_name': _middleNameController.text.isNotEmpty
              ? _middleNameController.text
              : null, // ADDED
          'last_name': _lastNameController.text,
          'company_name': _companyController.text.isNotEmpty
              ? _companyController.text
              : null,
          'job_position': _jobPositionController.text.isNotEmpty
              ? _jobPositionController.text
              : null,
          'contact_number': _phoneController.text,
          'email': _emailController.text.isNotEmpty
              ? _emailController.text
              : null,
          'unit_building_house_no': _unitController.text,
          'street': _streetController.text,
          'subdivision_village': _villageController.text,
          'barangay': _barangayController.text,
          'city': _cityController.text,
          'landmark': _landmarkController.text,
          'customer_type_id': _companyController.text.isNotEmpty ? 1 : 2,
        };

        final custRes = await _supabase
            .from('customers')
            .insert(newCustomerData)
            .select('id')
            .single();
        finalCustomerId = custRes['id'];
      }

      if (finalCustomerId == null) throw "Customer ID missing";

      // 2. CREATE AIRCON (If New/Manual)
      // Check if user typed a brand
      if (_isNewClient && _selectedBrandName.isNotEmpty) {
        final brandName = _selectedBrandName.trim();
        int brandId;

        // Smart Search: Check if brand exists, else create
        final brandCheck = await _supabase
            .from('brands')
            .select('id')
            .ilike('brand_name', brandName)
            .maybeSingle();
        if (brandCheck != null) {
          brandId = brandCheck['id'];
        } else {
          final newBrand = await _supabase
              .from('brands')
              .insert({'brand_name': brandName})
              .select('id')
              .single();
          brandId = newBrand['id'];
        }

        final newAircon = await _supabase
            .from('aircons')
            .insert({
              'customer_id': finalCustomerId,
              'brand_id': brandId,
              'aircon_type_id': _selectedAirconTypeId ?? 1,
              'remarks': _unitRemarkController.text.isNotEmpty
                  ? _unitRemarkController.text
                  : 'New Unit',
            })
            .select('id')
            .single();

        _selectedAirconIds.add(newAircon['id']);
      }

      // 3. CREATE JOB ORDER
      final typeRes = await _supabase
          .from('job_types')
          .select('id')
          .eq('job_type_name', _jobTypeName)
          .single();
      final correctTypeId = typeRes['id'];

      final scheduleDateTime = DateTime(
        _scheduleDate.year,
        _scheduleDate.month,
        _scheduleDate.day,
        _scheduleTime.hour,
        _scheduleTime.minute,
      );

      final joRes = await _supabase
          .from('job_orders')
          .insert({
            'customer_id': finalCustomerId,
            'job_type_id': correctTypeId,
            'date_scheduled': scheduleDateTime.toIso8601String(),
            'status': 'Pending',
            'user_id': _supabase.auth.currentUser?.id,
            'client_jo_number':
                'JO-${DateTime.now().millisecondsSinceEpoch.toString().substring(9)}',
          })
          .select('id')
          .single();

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
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Job Order Created Successfully!")),
        );
      }
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error: $e"), backgroundColor: Colors.red),
        );
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 600;

    return Dialog(
      insetPadding: isMobile ? EdgeInsets.zero : const EdgeInsets.all(40),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        width: isMobile ? double.infinity : 600,
        height: isMobile ? double.infinity : 750,
        color: Colors.white,
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: const BoxDecoration(
                border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0))),
              ),
              child: Row(
                children: [
                  if (_currentStep > 0)
                    IconButton(
                      icon: const Icon(Icons.arrow_back),
                      onPressed: () => setState(() => _currentStep--),
                    ),
                  Expanded(
                    child: Text(
                      _currentStep == 0
                          ? "Service Type"
                          : _currentStep == 1
                          ? "Customer & Asset"
                          : "Schedule",
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
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
                  onPressed: _isSubmitting
                      ? null
                      : (_currentStep == 2
                            ? _submit
                            : () => setState(() => _currentStep++)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2563EB),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: _isSubmitting
                      ? const CircularProgressIndicator(color: Colors.white)
                      : Text(
                          _currentStep == 2 ? 'Create Job Order' : 'Next Step',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                ),
              ),
            ),
          ],
        ),
      ),
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
          _BigVisualOption(
            icon: Icons.build_circle_outlined,
            title: "Installation",
            color: Colors.blue,
            isSelected: _jobTypeName == 'Installation',
            onTap: () => setState(() => _jobTypeName = 'Installation'),
          ),
          const SizedBox(height: 12),
          _BigVisualOption(
            icon: Icons.cleaning_services_outlined,
            title: "Maintenance",
            color: Colors.green,
            isSelected: _jobTypeName == 'Maintenance',
            onTap: () => setState(() => _jobTypeName = 'Maintenance'),
          ),
          const SizedBox(height: 12),
          _BigVisualOption(
            icon: Icons.handyman_outlined,
            title: "Repair",
            color: Colors.orange,
            isSelected: _jobTypeName == 'Repair',
            onTap: () => setState(() => _jobTypeName = 'Repair'),
          ),
          const SizedBox(height: 12),
          _BigVisualOption(
            icon: Icons.remove_circle_outline,
            title: "De-installation",
            color: Colors.red,
            isSelected: _jobTypeName == 'De-installation',
            onTap: () => setState(() => _jobTypeName = 'De-installation'),
          ),
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
            decoration: BoxDecoration(
              color: Colors.grey[100],
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Expanded(
                  child: _ToggleOption(
                    label: "Existing",
                    isSelected: !_isNewClient,
                    onTap: () => setState(() => _isNewClient = false),
                  ),
                ),
                Expanded(
                  child: _ToggleOption(
                    label: "New Client",
                    isSelected: _isNewClient,
                    onTap: () => setState(() => _isNewClient = true),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          if (!_isNewClient) ...[
            const Text(
              "Search Database",
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            DropdownButtonFormField<int>(
              value: _selectedClientId,
              isExpanded: true,
              decoration: InputDecoration(
                hintText: "Select Customer...",
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                filled: true,
                fillColor: Colors.white,
              ),
              items: _existingClients.map((c) {
                final name =
                    c['company_name'] ?? '${c['first_name']} ${c['last_name']}';
                final loc = c['barangay'] ?? c['city'] ?? '';
                return DropdownMenuItem(
                  value: c['id'] as int,
                  child: Text("$name ($loc)"),
                );
              }).toList(),
              onChanged: (val) {
                setState(() => _selectedClientId = val);
                if (val != null) _fetchClientAircons(val);
              },
            ),
            if (_selectedClientId != null && _clientAircons.isNotEmpty) ...[
              const SizedBox(height: 20),
              const Text(
                "Select Units",
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              ..._clientAircons.map((unit) {
                final brand = unit['brands'] != null
                    ? unit['brands']['brand_name']
                    : 'Unknown';
                final type = unit['aircon_types'] != null
                    ? unit['aircon_types']['type_name']
                    : 'Unit';
                return CheckboxListTile(
                  title: Text("$brand $type"),
                  subtitle: Text(unit['remarks'] ?? ''),
                  value: _selectedAirconIds.contains(unit['id']),
                  onChanged: (v) {
                    setState(() {
                      if (v == true)
                        _selectedAirconIds.add(unit['id']);
                      else
                        _selectedAirconIds.remove(unit['id']);
                    });
                  },
                );
              }),
            ],
          ] else ...[
            // --- NEW CLIENT FORM ---
            const Text(
              "Client Info",
              style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blue),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _SimpleInput(
                    controller: _firstNameController,
                    hint: "First Name",
                    isRequired: true,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _SimpleInput(
                    controller: _middleNameController,
                    hint: "Middle Name (Opt)",
                  ),
                ), // ADDED
                const SizedBox(width: 8),
                Expanded(
                  child: _SimpleInput(
                    controller: _lastNameController,
                    hint: "Last Name",
                    isRequired: true,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _SimpleInput(
              controller: _companyController,
              hint: "Company Name (Optional - B2B)",
              icon: Icons.business,
            ),
            const SizedBox(height: 12),
            _SimpleInput(
              controller: _jobPositionController,
              hint: "Job Position (e.g. Manager)",
              icon: Icons.badge,
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _SimpleInput(
                    controller: _phoneController,
                    hint: "Contact Number",
                    icon: Icons.phone,
                    isRequired: true,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _SimpleInput(
                    controller: _emailController,
                    hint: "Email Address",
                    icon: Icons.email,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 24),
            const Text(
              "Detailed Address",
              style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blue),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _SimpleInput(
                    controller: _unitController,
                    hint: "Unit/House #",
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _SimpleInput(
                    controller: _streetController,
                    hint: "Street Name",
                    isRequired: true,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _SimpleInput(
              controller: _villageController,
              hint: "Subdivision / Village",
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _SimpleInput(
                    controller: _barangayController,
                    hint: "Barangay",
                    isRequired: true,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _SimpleInput(
                    controller: _cityController,
                    hint: "City",
                    icon: Icons.location_city,
                    isRequired: true,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _SimpleInput(
              controller: _landmarkController,
              hint: "Landmark (Near...)",
              icon: Icons.flag,
            ),

            const SizedBox(height: 24),
            const Text(
              "First Aircon Unit",
              style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blue),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                // BRAND AUTOCOMPLETE
                Expanded(
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      return Autocomplete<String>(
                        optionsBuilder: (TextEditingValue textEditingValue) {
                          if (textEditingValue.text == '') {
                            return const Iterable<String>.empty();
                          }
                          return _brandOptions.where((String option) {
                            return option.toLowerCase().contains(
                              textEditingValue.text.toLowerCase(),
                            );
                          });
                        },
                        onSelected: (String selection) {
                          _selectedBrandName = selection;
                        },
                        fieldViewBuilder:
                            (
                              context,
                              textEditingController,
                              focusNode,
                              onFieldSubmitted,
                            ) {
                              // Capture text even if they don't select an option (Create New Brand)
                              textEditingController.addListener(() {
                                _selectedBrandName = textEditingController.text;
                              });
                              return TextField(
                                controller: textEditingController,
                                focusNode: focusNode,
                                decoration: InputDecoration(
                                  hintText: "Brand (Search/Add) *",
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  filled: true,
                                  fillColor: Colors.white,
                                  contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 14,
                                  ),
                                ),
                              );
                            },
                      );
                    },
                  ),
                ),
                const SizedBox(width: 12),
                // TYPE DROPDOWN
                Expanded(
                  child: DropdownButtonFormField<int>(
                    value: _selectedAirconTypeId,
                    decoration: InputDecoration(
                      hintText: "Type",
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      filled: true,
                      fillColor: Colors.white,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 14,
                      ),
                    ),
                    items: _airconTypes
                        .map(
                          (t) => DropdownMenuItem(
                            value: t['id'] as int,
                            child: Text(t['type_name']),
                          ),
                        )
                        .toList(),
                    onChanged: (v) => setState(() => _selectedAirconTypeId = v),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _SimpleInput(
              controller: _unitRemarkController,
              hint: "Location (e.g. Lobby, Bedroom 1) *",
              isRequired: true,
            ),
          ],
        ],
      ),
    );
  }

  Widget _stepThree() {
    return Column(
      children: [
        const Text(
          "Date & Time",
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        const SizedBox(height: 16),
        ListTile(
          tileColor: Colors.grey[50],
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(color: Colors.grey.shade300),
          ),
          leading: const Icon(Icons.calendar_month, color: Colors.blue),
          title: Text("${_scheduleDate.toLocal()}".split(' ')[0]),
          onTap: () async {
            final d = await showDatePicker(
              context: context,
              initialDate: _scheduleDate,
              firstDate: DateTime.now(),
              lastDate: DateTime(2030),
            );
            if (d != null) setState(() => _scheduleDate = d);
          },
        ),
        const SizedBox(height: 12),
        ListTile(
          tileColor: Colors.grey[50],
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(color: Colors.grey.shade300),
          ),
          leading: const Icon(Icons.access_time, color: Colors.orange),
          title: Text(_scheduleTime.format(context)),
          onTap: () async {
            final t = await showTimePicker(
              context: context,
              initialTime: _scheduleTime,
            );
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
            filled: true,
            fillColor: Colors.grey[50],
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

  const _BigVisualOption({
    required this.icon,
    required this.title,
    required this.color,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected ? color.withOpacity(0.1) : Colors.white,
          border: Border.all(
            color: isSelected ? color : Colors.grey.shade200,
            width: 2,
          ),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            Icon(icon, color: isSelected ? color : Colors.grey, size: 28),
            const SizedBox(width: 16),
            Text(
              title,
              style: TextStyle(
                fontSize: 16,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              ),
            ),
            const Spacer(),
            if (isSelected) Icon(Icons.check_circle, color: color),
          ],
        ),
      ),
    );
  }
}

class _ToggleOption extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;
  const _ToggleOption({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 2,
                  ),
                ]
              : null,
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            color: isSelected ? Colors.blue : Colors.grey,
          ),
        ),
      ),
    );
  }
}

class _SimpleInput extends StatelessWidget {
  final TextEditingController controller;
  final IconData? icon;
  final String hint;
  final bool isRequired;

  const _SimpleInput({
    required this.controller,
    this.icon,
    required this.hint,
    this.isRequired = false,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      decoration: InputDecoration(
        // Visual indicator for required fields
        label: RichText(
          text: TextSpan(
            text: hint,
            style: TextStyle(color: Colors.grey[600], fontSize: 14),
            children: [
              if (isRequired)
                const TextSpan(
                  text: ' *',
                  style: TextStyle(color: Colors.red),
                ),
            ],
          ),
        ),
        prefixIcon: icon != null ? Icon(icon, size: 20) : null,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
        filled: true,
        fillColor: Colors.white,
      ),
    );
  }
}

class _JobCard extends StatelessWidget {
  final JobOrder order;
  const _JobCard({required this.order});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                order.jobType,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.blue,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.orange.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  order.status,
                  style: const TextStyle(
                    fontSize: 10,
                    color: Colors.deepOrange,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            order.clientName,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              const Icon(Icons.calendar_today, size: 12, color: Colors.grey),
              const SizedBox(width: 4),
              Text(
                "${order.dateTime.month}/${order.dateTime.day} ${order.dateTime.hour}:${order.dateTime.minute.toString().padLeft(2, '0')}",
                style: const TextStyle(fontSize: 13, color: Colors.grey),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
