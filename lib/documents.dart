import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:printing/printing.dart';
import 'package:intl/intl.dart';
import 'ui_app_shell.dart';
import 'shared/widgets.dart' show isMobile;
import 'dialogs/generate_soa_dialog.dart';

// --- Design Constants (Moved to top-level for global access) ---
const Color kPrimaryColor = Color(0xFF2563EB);
const Color kTextPrimary = Color(0xFF1E293B);
const Color kTextSecondary = Color(0xFF64748B);
const Color kBorderColor = Color(0xFFE2E8F0);

// --- Data Model ---

class DocumentItem {
  final String title;
  final String type; // 'pdf', 'excel', 'image', 'word'
  final String size;
  final String status; // 'Verified', 'Pending'
  final String category; // 'Invoice', 'Report', 'Receipt', 'Contract'
  final String uploadedBy;
  final DateTime date;
  final List<String> tags;

  DocumentItem({
    required this.title,
    required this.type,
    required this.size,
    required this.status,
    required this.category,
    required this.uploadedBy,
    required this.date,
    required this.tags,
  });
}

// --- Main Screen ---

class DocumentsScreen extends StatefulWidget {
  const DocumentsScreen({super.key});

  @override
  State<DocumentsScreen> createState() => _DocumentsScreenState();
}

class _DocumentsScreenState extends State<DocumentsScreen> {
  final List<DocumentItem> _documents = [];
  String _selectedCategory = 'All Documents';
  String _searchQuery = '';
  bool _isGridView = true; // Toggle state
  String? _statusFilter; // null, 'Pending', 'Verified'
  String _sortBy = 'date'; // 'date', 'name'

  @override
  void initState() {
    super.initState();
    _seedData();
  }

  void _seedData() {
    _documents.addAll([
      DocumentItem(
        title: 'Invoice_ABC_Corp_Nov2025.pdf',
        type: 'pdf',
        size: '245 KB',
        status: 'Verified',
        category: 'Invoices',
        uploadedBy: 'John Doe',
        date: DateTime(2025, 11, 10),
        tags: ['Document', 'PDF'],
      ),
      DocumentItem(
        title: 'Job_Report_XYZ_Retail.xlsx',
        type: 'excel',
        size: '89 KB',
        status: 'Pending',
        category: 'Job Reports',
        uploadedBy: 'Jane Smith',
        date: DateTime(2025, 11, 10),
        tags: ['Document', 'Excel'],
      ),
      DocumentItem(
        title: 'Receipt_Fuel_20251110.jpg',
        type: 'image',
        size: '1.2 MB',
        status: 'Pending',
        category: 'Receipts',
        uploadedBy: 'Mike Johnson',
        date: DateTime(2025, 11, 10),
        tags: ['Image', 'Receipt'],
      ),
      DocumentItem(
        title: 'Service_Contract_GlobalMall.docx',
        type: 'word',
        size: '156 KB',
        status: 'Verified',
        category: 'Contracts',
        uploadedBy: 'Admin',
        date: DateTime(2025, 11, 9),
        tags: ['Contract', 'Legal'],
      ),
      DocumentItem(
        title: 'Materials_Receipt_20251109.pdf',
        type: 'pdf',
        size: '312 KB',
        status: 'Verified',
        category: 'Receipts',
        uploadedBy: 'Sarah Lee',
        date: DateTime(2025, 11, 9),
        tags: ['Receipt', 'PDF'],
      ),
      DocumentItem(
        title: 'Safety_Guidelines_v2.pdf',
        type: 'pdf',
        size: '1.5 MB',
        status: 'Verified',
        category: 'All Documents',
        uploadedBy: 'Admin',
        date: DateTime(2025, 11, 1),
        tags: ['Reference'],
      ),
    ]);
  }

  List<DocumentItem> get _filteredDocs {
    var result = _documents.where((doc) {
      final matchesCategory = _selectedCategory == 'All Documents' || doc.category == _selectedCategory;
      final matchesSearch = doc.title.toLowerCase().contains(_searchQuery.toLowerCase()) || 
                            doc.uploadedBy.toLowerCase().contains(_searchQuery.toLowerCase());
      final matchesStatus = _statusFilter == null || doc.status == _statusFilter;
      return matchesCategory && matchesSearch && matchesStatus;
    }).toList();
    
    // Sort
    if (_sortBy == 'name') {
      result.sort((a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase()));
    } else {
      result.sort((a, b) => b.date.compareTo(a.date)); // Most recent first
    }
    
    return result;
  }

  Future<void> _showGenerateModal() async {
    final choice = await showDialog<String>(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Container(
          width: 400,
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.add_circle_outline, color: kPrimaryColor, size: 28),
                  const SizedBox(width: 12),
                  const Text('Generate Document', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
                  const Spacer(),
                  IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close)),
                ],
              ),
              const Divider(height: 24),
              const Text('Select document type:', style: TextStyle(fontSize: 14, color: kTextSecondary)),
              const SizedBox(height: 16),
              _GenerateOptionTile(
                icon: Icons.receipt_long,
                title: 'Statement of Accounts (SOA)',
                subtitle: 'Generate billing statement for clients',
                onTap: () => Navigator.pop(context, 'soa'),
              ),
            ],
          ),
        ),
      ),
    );

    if (choice == 'soa') {
      _generateSOA();
    }
  }

  Future<void> _generateSOA() async {
    // Show the generation dialog
    final pdfBytes = await showDialog<Uint8List>(
      context: context,
      builder: (context) => const GenerateSOADialog(),
    );

    if (pdfBytes == null) return;

    // Show preview and save options
    await Printing.layoutPdf(
      onLayout: (format) async => pdfBytes,
      name: 'SOA_${DateFormat('yyyyMMdd_HHmmss').format(DateTime.now())}.pdf',
    );

    // Add the generated document to the list
    final now = DateTime.now();
    final fileName = 'SOA_${DateFormat('yyyyMMdd_HHmmss').format(now)}.pdf';
    final sizeKB = (pdfBytes.length / 1024).toStringAsFixed(0);
    
    setState(() {
      _documents.insert(0, DocumentItem(
        title: fileName,
        type: 'pdf',
        size: '$sizeKB KB',
        status: 'Verified',
        category: 'Invoices',
        uploadedBy: 'System',
        date: now,
        tags: ['SOA', 'Generated', 'PDF'],
      ));
    });

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('✓ $fileName generated successfully'),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppShell(
      selectedIndex: 3,
      body: Container(
        color: const Color(0xFFF8FAFC),
        child: Column(
          children: [
            // Header - Responsive
            Container(
              padding: EdgeInsets.symmetric(
                horizontal: isMobile(context) ? 16 : 24,
                vertical: isMobile(context) ? 12 : 16,
              ),
              color: Colors.white,
              width: double.infinity,
              child: isMobile(context)
                  ? Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Document Management',
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: kTextPrimary, letterSpacing: -0.5),
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          onChanged: (v) => setState(() => _searchQuery = v),
                          style: const TextStyle(fontSize: 14),
                          decoration: InputDecoration(
                            hintText: 'Search in Drive...',
                            prefixIcon: const Icon(Icons.search, color: kTextSecondary, size: 20),
                            filled: true,
                            fillColor: const Color(0xFFF1F5F9),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: BorderSide.none,
                            ),
                            contentPadding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                        ),

                      ],
                    )
                  : Row(
                      children: [
                        const Text(
                          'Document Management',
                          style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: kTextPrimary, letterSpacing: -0.5),
                        ),
                        const Spacer(),
                        SizedBox(
                          width: 300,
                          height: 40,
                          child: TextField(
                            onChanged: (v) => setState(() => _searchQuery = v),
                            style: const TextStyle(fontSize: 14),
                            decoration: InputDecoration(
                              hintText: 'Search in Drive...',
                              prefixIcon: const Icon(Icons.search, color: kTextSecondary, size: 20),
                              filled: true,
                              fillColor: const Color(0xFFF1F5F9),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide: BorderSide.none,
                              ),
                              contentPadding: const EdgeInsets.symmetric(vertical: 0),
                            ),
                          ),
                        ),

                      ],
                    ),
            ),
            const Divider(height: 1, color: kBorderColor),

            // Main Content - Responsive layout
            Expanded(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final isMobileView = isMobile(context);
                  
                  if (isMobileView) {
                    // Mobile: Stacked layout
                    return Column(
                      children: [
                        // Category filter as horizontal scroll
                        Container(
                          height: 60,
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          color: Colors.white,
                          child: SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: Row(
                              children: [
                                _buildMobileCategoryChip('All Documents', Icons.folder_open),
                                const SizedBox(width: 8),
                                _buildMobileCategoryChip('Invoices', Icons.receipt_long),
                                const SizedBox(width: 8),
                                _buildMobileCategoryChip('Job Reports', Icons.assessment_outlined),
                                const SizedBox(width: 8),
                                _buildMobileCategoryChip('Receipts', Icons.payment),
                                const SizedBox(width: 8),
                                _buildMobileCategoryChip('Contracts', Icons.gavel_outlined),
                              ],
                            ),
                          ),
                        ),
                        const Divider(height: 1, color: kBorderColor),
                        
                        // Toolbar
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          color: Colors.white,
                          child: Row(
                            children: [
                              Expanded(
                                child: Text(_selectedCategory, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: kTextPrimary)),
                              ),
                              Container(
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF1F5F9),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: kBorderColor),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    IconButton(
                                      onPressed: () => setState(() => _isGridView = true),
                                      icon: const Icon(Icons.grid_view_rounded, size: 18),
                                      color: _isGridView ? kPrimaryColor : kTextSecondary,
                                      tooltip: 'Grid View',
                                      padding: EdgeInsets.zero,
                                      constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                                    ),
                                    Container(width: 1, height: 20, color: kBorderColor),
                                    IconButton(
                                      onPressed: () => setState(() => _isGridView = false),
                                      icon: const Icon(Icons.view_list_rounded, size: 18),
                                      color: !_isGridView ? kPrimaryColor : kTextSecondary,
                                      tooltip: 'List View',
                                      padding: EdgeInsets.zero,
                                      constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                        const Divider(height: 1, color: kBorderColor),
                        
                        // Stats Row
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          color: const Color(0xFFF8FAFC),
                          child: _buildStatsRow(),
                        ),

                        // File Content
                        Expanded(
                          child: SingleChildScrollView(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _buildGenerateButton(),
                                const SizedBox(height: 16),
                                if (_filteredDocs.isEmpty)
                                  const Center(child: Padding(padding: EdgeInsets.all(40), child: Text("No documents found.")))
                                else if (_isGridView)
                                  _buildGrid(_filteredDocs)
                                else
                                  _buildList(_filteredDocs),
                              ],
                            ),
                          ),
                        ),
                      ],
                    );
                  }
                  
                  // Desktop: Sidebar + Content
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(
                        width: 250,
                        child: _buildCategorySidebar(),
                      ),
                      const VerticalDivider(width: 1, color: kBorderColor),
                      Expanded(
                        child: Column(
                          children: [
                            // Toolbar / Filters
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                              color: Colors.white,
                              child: Row(
                                children: [
                                  Text(_selectedCategory, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: kTextPrimary)),
                                  const Spacer(),
                                  Container(
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFF1F5F9),
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(color: kBorderColor),
                                    ),
                                    child: Row(
                                      children: [
                                        IconButton(
                                          onPressed: () => setState(() => _isGridView = true),
                                          icon: const Icon(Icons.grid_view_rounded, size: 20),
                                          color: _isGridView ? kPrimaryColor : kTextSecondary,
                                          tooltip: 'Grid View',
                                          padding: EdgeInsets.zero,
                                          constraints: const BoxConstraints(minWidth: 40, minHeight: 36),
                                        ),
                                        Container(width: 1, height: 20, color: kBorderColor),
                                        IconButton(
                                          onPressed: () => setState(() => _isGridView = false),
                                          icon: const Icon(Icons.view_list_rounded, size: 20),
                                          color: !_isGridView ? kPrimaryColor : kTextSecondary,
                                          tooltip: 'List View',
                                          padding: EdgeInsets.zero,
                                          constraints: const BoxConstraints(minWidth: 40, minHeight: 36),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const Divider(height: 1, color: kBorderColor),
                            
                            // Stats Row
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                              color: const Color(0xFFF8FAFC),
                              child: _buildStatsRow(),
                            ),

                            // File Content
                            Expanded(
                              child: SingleChildScrollView(
                                padding: const EdgeInsets.all(24),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    _buildGenerateButton(),
                                    const SizedBox(height: 24),
                                    if (_filteredDocs.isEmpty)
                                      const Center(child: Padding(padding: EdgeInsets.all(40), child: Text("No documents found.")))
                                    else if (_isGridView)
                                      _buildGrid(_filteredDocs)
                                    else
                                      _buildList(_filteredDocs),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  // --- Widgets ---

  Widget _buildCategorySidebar() {
    final categories = [
      {'name': 'All Documents', 'icon': Icons.folder_open},
      {'name': 'Invoices', 'icon': Icons.receipt_long},
      {'name': 'Job Reports', 'icon': Icons.assessment_outlined},
      {'name': 'Receipts', 'icon': Icons.payment},
      {'name': 'Contracts', 'icon': Icons.gavel_outlined},
    ];
    
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: categories.map((cat) {
          final name = cat['name'] as String;
          final icon = cat['icon'] as IconData;
          final isSelected = _selectedCategory == name;
          final count = name == 'All Documents' 
              ? _documents.length 
              : _documents.where((d) => d.category == name).length;
              
          return InkWell(
            onTap: () => setState(() => _selectedCategory = name),
            child: Container(
              width: double.infinity,
              margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: isSelected ? const Color(0xFFEFF6FF) : Colors.transparent,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(icon, size: 18, color: isSelected ? kPrimaryColor : kTextSecondary),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      name,
                      style: TextStyle(
                        fontSize: 14,
                        color: isSelected ? kPrimaryColor : kTextPrimary,
                        fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                      ),
                    ),
                  ),
                  if (count > 0)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: isSelected ? Colors.white : const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        count.toString(),
                        style: TextStyle(fontSize: 10, color: isSelected ? kPrimaryColor : kTextSecondary, fontWeight: FontWeight.bold),
                      ),
                    ),
                ],
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildMobileCategoryChip(String name, IconData icon) {
    final isSelected = _selectedCategory == name;
    final count = name == 'All Documents' 
        ? _documents.length 
        : _documents.where((d) => d.category == name).length;
    
    return GestureDetector(
      onTap: () => setState(() => _selectedCategory = name),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFFEFF6FF) : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? kPrimaryColor : kBorderColor,
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: isSelected ? kPrimaryColor : kTextSecondary),
            const SizedBox(width: 6),
            Text(
              name,
              style: TextStyle(
                fontSize: 12,
                color: isSelected ? kPrimaryColor : kTextPrimary,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
            if (count > 0) ...[
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: isSelected ? Colors.white : const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  count.toString(),
                  style: TextStyle(
                    fontSize: 10,
                    color: isSelected ? kPrimaryColor : kTextSecondary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildStatsRow() {
    final pending = _documents.where((d) => d.status == 'Pending').length;
    final verified = _documents.where((d) => d.status == 'Verified').length;
    final totalSize = _documents.fold<double>(0, (sum, doc) {
      final kb = double.tryParse(doc.size.replaceAll(RegExp(r'[^0-9.]'), '')) ?? 0;
      return sum + kb;
    }) / 1024; // Convert to MB
    
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          GestureDetector(
            onTap: () => setState(() => _statusFilter = null),
            child: _MiniStatChip(
              label: 'Total Files',
              value: '${_documents.length}',
              icon: Icons.folder,
              color: _statusFilter == null ? kPrimaryColor : Colors.grey,
              isActive: _statusFilter == null,
            ),
          ),
          const SizedBox(width: 12),
          GestureDetector(
            onTap: () => setState(() => _statusFilter = _statusFilter == 'Pending' ? null : 'Pending'),
            child: _MiniStatChip(
              label: 'Pending Review',
              value: '$pending',
              icon: Icons.pending_outlined,
              color: _statusFilter == 'Pending' ? Colors.orange : Colors.orange.withOpacity(0.6),
              isActive: _statusFilter == 'Pending',
            ),
          ),
          const SizedBox(width: 12),
          GestureDetector(
            onTap: () => setState(() => _statusFilter = _statusFilter == 'Verified' ? null : 'Verified'),
            child: _MiniStatChip(
              label: 'Verified',
              value: '$verified',
              icon: Icons.verified_outlined,
              color: _statusFilter == 'Verified' ? Colors.green : Colors.green.withOpacity(0.6),
              isActive: _statusFilter == 'Verified',
            ),
          ),
          const SizedBox(width: 12),
          _MiniStatChip(
            label: 'Storage Used',
            value: '${totalSize.toStringAsFixed(1)} MB',
            icon: Icons.cloud,
            color: Colors.blue,
          ),
        ],
      ),
    );
  }

  Widget _buildGenerateButton() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: kBorderColor, style: BorderStyle.solid),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: kPrimaryColor.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.add_circle_outline, size: 48, color: kPrimaryColor),
          ),
          const SizedBox(height: 16),
          const Text('Generate Documents', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: kTextPrimary)),
          const SizedBox(height: 8),
          const Text('Create statements, invoices, and reports', style: TextStyle(fontSize: 14, color: kTextSecondary)),
          const SizedBox(height: 20),
          ElevatedButton.icon(
            onPressed: _showGenerateModal,
            icon: const Icon(Icons.add),
            label: const Text('Generate'),
            style: ElevatedButton.styleFrom(
              backgroundColor: kPrimaryColor,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGrid(List<DocumentItem> docs) {
    return LayoutBuilder(
      builder: (context, constraints) {
        // Responsive Grid logic
        int crossAxisCount = 4;
        if (constraints.maxWidth < 1100) crossAxisCount = 3;
        if (constraints.maxWidth < 800) crossAxisCount = 2;
        if (constraints.maxWidth < 500) crossAxisCount = 1;
        
        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            crossAxisSpacing: 16,
            mainAxisSpacing: 16,
            childAspectRatio: 1.3, // More compact aspect ratio
          ),
          itemCount: docs.length,
          itemBuilder: (context, index) => _DocumentGridCard(doc: docs[index]),
        );
      },
    );
  }

  Widget _buildList(List<DocumentItem> docs) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isMobileView = constraints.maxWidth < 600;
        
        if (isMobileView) {
          // Mobile: Card view
          return Column(
            children: docs.map((doc) => Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: kBorderColor),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(_getFileIcon(doc.type), size: 24, color: _getFileColor(doc.type)),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          doc.title,
                          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: kTextPrimary),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Text(doc.size, style: const TextStyle(fontSize: 11, color: kTextSecondary)),
                      ],
                    ),
                  ),
                  _StatusBadge(status: doc.status),
                ],
              ),
              const SizedBox(height: 12),
              const Divider(height: 1),
              const SizedBox(height: 12),
              Row(
                children: [
                  const Icon(Icons.person_outline, size: 14, color: kTextSecondary),
                  const SizedBox(width: 6),
                  Text(doc.uploadedBy, style: const TextStyle(fontSize: 12, color: kTextSecondary)),
                  const Spacer(),
                  const Icon(Icons.calendar_today, size: 14, color: kTextSecondary),
                  const SizedBox(width: 6),
                  Text('${doc.date.month}/${doc.date.day}/${doc.date.year}', style: const TextStyle(fontSize: 12, color: kTextSecondary)),
                ],
              ),
            ],
          ),
        )).toList(),
          );
        }
        
        // Desktop/Tablet: Table view
        return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: kBorderColor),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: ConstrainedBox(
          constraints: BoxConstraints(minWidth: MediaQuery.of(context).size.width - 64),
          child: Column(
            children: [
              // Header
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: const BoxDecoration(
                  border: Border(bottom: BorderSide(color: kBorderColor)),
                  color: Color(0xFFF8FAFC),
                ),
                child: Row(
                  children: const [
                    SizedBox(width: 200, child: Text('Name', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: kTextSecondary))),
                    SizedBox(width: 120, child: Text('Owner', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: kTextSecondary))),
                    SizedBox(width: 100, child: Text('Date', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: kTextSecondary))),
                    SizedBox(width: 100, child: Text('Status', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: kTextSecondary))),
                    SizedBox(width: 40, child: Text('Actions', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: kTextSecondary))),
                  ],
                ),
              ),
              // Items
              ...docs.map((doc) => Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: const BoxDecoration(
                  border: Border(bottom: BorderSide(color: kBorderColor)),
                ),
                child: Row(
                  children: [
                    SizedBox(
                      width: 200,
                      child: Row(
                        children: [
                          Icon(_getFileIcon(doc.type), size: 20, color: _getFileColor(doc.type)),
                          const SizedBox(width: 12),
                          Expanded(child: Text(doc.title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: kTextPrimary), overflow: TextOverflow.ellipsis)),
                        ],
                      ),
                    ),
                    SizedBox(width: 120, child: Text(doc.uploadedBy, style: const TextStyle(fontSize: 13, color: kTextSecondary))),
                    SizedBox(width: 100, child: Text('${doc.date.month}/${doc.date.day}/${doc.date.year}', style: const TextStyle(fontSize: 13, color: kTextSecondary))),
                    SizedBox(width: 100, child: _StatusBadge(status: doc.status)),
                    const SizedBox(width: 40, child: Icon(Icons.more_vert, size: 18, color: kTextSecondary)),
                  ],
                ),
              )),
            ],
          ),
        ),
      ),
        );
      },
    );
  }

  // --- Helpers ---
  
  IconData _getFileIcon(String type) {
    switch(type) {
      case 'pdf': return Icons.picture_as_pdf;
      case 'excel': return Icons.table_chart;
      case 'image': return Icons.image;
      default: return Icons.description;
    }
  }

  Color _getFileColor(String type) {
    switch(type) {
      case 'pdf': return Colors.red;
      case 'excel': return Colors.green;
      case 'image': return Colors.orange;
      default: return Colors.blue;
    }
  }
}

// --- Components ---

class _MiniStatChip extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;
  final bool isActive;

  const _MiniStatChip({required this.label, required this.value, required this.icon, this.color = Colors.grey, this.isActive = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: isActive ? color.withOpacity(0.1) : Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: isActive ? color : kBorderColor, width: isActive ? 2 : 1),
      ),
      child: Row(
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: const TextStyle(fontSize: 10, color: Color(0xFF64748B))),
              Text(value, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Color(0xFF1E293B))),
            ],
          ),
        ],
      ),
    );
  }
}

class _DocumentGridCard extends StatelessWidget {
  final DocumentItem doc;
  const _DocumentGridCard({required this.doc});

  @override
  Widget build(BuildContext context) {
    IconData fileIcon;
    Color iconColor;
    Color iconBg;
    
    switch(doc.type) {
      case 'pdf':
        fileIcon = Icons.picture_as_pdf;
        iconColor = Colors.red;
        iconBg = const Color(0xFFFEF2F2);
        break;
      case 'excel':
        fileIcon = Icons.table_chart;
        iconColor = Colors.green;
        iconBg = const Color(0xFFF0FDF4);
        break;
      case 'image':
        fileIcon = Icons.image;
        iconColor = Colors.orange;
        iconBg = const Color(0xFFFFF7ED);
        break;
      default:
        fileIcon = Icons.description;
        iconColor = Colors.blue;
        iconBg = const Color(0xFFEFF6FF);
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: kBorderColor),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 4, offset: const Offset(0, 2))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(color: iconBg, borderRadius: BorderRadius.circular(8)),
                child: Icon(fileIcon, color: iconColor, size: 20),
              ),
              const Spacer(),
              _StatusBadge(status: doc.status),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            doc.title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: Color(0xFF1E293B)),
          ),
          const SizedBox(height: 4),
          Text(doc.size, style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8))),
          const Spacer(),
          const Divider(height: 1),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const CircleAvatar(radius: 8, backgroundColor: Color(0xFFF1F5F9), child: Icon(Icons.person, size: 10, color: Colors.grey)),
                  const SizedBox(width: 6),
                  Text(doc.uploadedBy, style: const TextStyle(fontSize: 11, color: Color(0xFF64748B))),
                ],
              ),
              Text('${doc.date.month}/${doc.date.day}', style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8))),
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
    final isVerified = status == 'Verified';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: isVerified ? const Color(0xFFDCFCE7) : const Color(0xFFFFF4DE),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        status,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w600,
          color: isVerified ? const Color(0xFF15803D) : const Color(0xFFB45309),
        ),
      ),
    );
  }
}

class _GenerateOptionTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _GenerateOptionTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          border: Border.all(color: kBorderColor),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: kPrimaryColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: kPrimaryColor, size: 28),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 4),
                  Text(subtitle, style: const TextStyle(fontSize: 13, color: kTextSecondary)),
                ],
              ),
            ),
            const Icon(Icons.arrow_forward_ios, size: 16, color: kTextSecondary),
          ],
        ),
      ),
    );
  }
}