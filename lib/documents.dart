import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:printing/printing.dart';
import 'package:intl/intl.dart';
import 'ui_app_shell.dart';
import 'shared/widgets.dart' show AnimatedCard, HoverCard, AnimatedButton, isMobile;
import 'dialogs/generate_soa_dialog.dart';
import 'dialogs/generate_deferment_dialog.dart';
import 'dialogs/generate_weekly_report_dialog.dart';
import 'data/dashboard_provider.dart';
import 'dart:io';
import 'package:path_provider/path_provider.dart';

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
  final String category; // 'Statement of Account', 'Deferment Form', 'Weekly Report'
  final String uploadedBy;
  final DateTime date;
  final List<String> tags;
  final Uint8List? fileBytes; // Store actual file data for accurate storage

  DocumentItem({
    required this.title,
    required this.type,
    required this.size,
    required this.status,
    required this.category,
    required this.uploadedBy,
    required this.date,
    required this.tags,
    this.fileBytes,
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
  final String _sortBy = 'date'; // 'date', 'name'
  
  // Dynamic categories - start with predefined ones
  final List<String> _categories = [
    'Statement of Account',
    'Deferment Form',
    'Weekly Report',
  ];

  @override
  void initState() {
    super.initState();
    _seedData();
  }

  void _seedData() {
    // Start with an empty documents list so the UI shows only real/generated
    // documents (for example, SOAs created via the Generate dialog).
    // Previously this method seeded demo/sample documents; those samples
    // were removed to ensure only actual documents are displayed.
    _documents.clear();
    _updateDashboardPendingDocs();
  }

  void _updateDashboardPendingDocs() {
    final pendingCount = _documents.where((d) => d.status == 'Pending').length;
    DashboardProvider().updatePendingDocsCount(pendingCount);
  }
  
  Future<void> _addNewCategory() async {
    final controller = TextEditingController();
    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add New Category'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(
            labelText: 'Category Name',
            hintText: 'e.g., Permits, Licenses',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              final name = controller.text.trim();
              if (name.isNotEmpty && !_categories.contains(name)) {
                Navigator.pop(context, name);
              }
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
    
    if (result != null && result.isNotEmpty) {
      setState(() {
        _categories.add(result);
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Category "$result" added'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }
  
  Future<void> _toggleDocumentStatus(DocumentItem doc) async {
    final newStatus = doc.status == 'Verified' ? 'Pending' : 'Verified';
    setState(() {
      final index = _documents.indexWhere((d) => d == doc);
      if (index != -1) {
        _documents[index] = DocumentItem(
          title: doc.title,
          type: doc.type,
          size: doc.size,
          status: newStatus,
          category: doc.category,
          uploadedBy: doc.uploadedBy,
          date: doc.date,
          tags: doc.tags,
        );
      }
    });
    _updateDashboardPendingDocs();
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Document marked as $newStatus'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
  
  Future<void> _archiveDocument(DocumentItem doc) async {
    // Check if it's a generated document
    final isGenerated = doc.tags.contains('Generated') || doc.uploadedBy == 'System';
    
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Archive Document'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Are you sure you want to archive "${doc.title}"?'),
            if (isGenerated) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.orange.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.orange),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.warning_amber_rounded, color: Colors.orange, size: 20),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'This is a generated document. Once archived, you may need to regenerate it.',
                        style: TextStyle(fontSize: 13),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Archive'),
          ),
        ],
      ),
    );
    
    if (confirmed == true) {
      setState(() {
        _documents.remove(doc);
      });
      _updateDashboardPendingDocs();
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${doc.title} archived'),
            backgroundColor: Colors.orange,
            behavior: SnackBarBehavior.floating,
            action: SnackBarAction(
              label: 'Undo',
              textColor: Colors.white,
              onPressed: () {
                setState(() {
                  _documents.insert(0, doc);
                });
                _updateDashboardPendingDocs();
              },
            ),
          ),
        );
      }
    }
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
    final choice = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 24),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Drag handle
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE2E8F0),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              // Header
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: kPrimaryColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.add_circle_outline, color: kPrimaryColor, size: 24),
                  ),
                  const SizedBox(width: 12),
                  const Text('Generate Document', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
                  const Spacer(),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close, size: 20),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              const Text('Select document type:', style: TextStyle(fontSize: 14, color: kTextSecondary)),
              const SizedBox(height: 16),
              _GenerateOptionTile(
                icon: Icons.receipt_long,
                title: 'Statement of Accounts (SOA)',
                subtitle: 'Generate billing statement for clients',
                onTap: () => Navigator.pop(context, 'soa'),
              ),
              const SizedBox(height: 12),
              _GenerateOptionTile(
                icon: Icons.assignment_outlined,
                title: 'Deferment Form',
                subtitle: 'Generate technical deferment form',
                onTap: () => Navigator.pop(context, 'deferment'),
              ),
              const SizedBox(height: 12),
              _GenerateOptionTile(
                icon: Icons.table_chart_outlined,
                title: 'Weekly Report',
                subtitle: 'Generate weekly status report (Excel)',
                onTap: () => Navigator.pop(context, 'weekly_report'),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );

    if (choice == 'soa') {
      _generateSOA();
    } else if (choice == 'deferment') {
      _generateDefermentForm();
    } else if (choice == 'weekly_report') {
      _generateWeeklyReport();
    }
  }

  Future<void> _generateWeeklyReport() async {
    final excelBytes = await showModalBottomSheet<Uint8List>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => const GenerateWeeklyReportDialog(),
    );

    if (excelBytes == null) return;

    final now = DateTime.now();
    final fileName = 'WeeklyReport_${DateFormat('yyyyMMdd_HHmmss').format(now)}.xlsx';
    final sizeKB = (excelBytes.length / 1024).toStringAsFixed(0);
    
    // For Excel, we might want to save it to a temporary file so it can be opened/shared properly
    // But for now, we follow the pattern of storing bytes.
    
    setState(() {
      _documents.insert(0, DocumentItem(
        title: fileName,
        type: 'excel',
        size: '$sizeKB KB',
        status: 'Pending',
        category: 'Weekly Report',
        uploadedBy: 'System',
        date: now,
        tags: ['Weekly Report', 'Generated', 'Excel'],
        fileBytes: excelBytes,
      ));
    });
    _updateDashboardPendingDocs();

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('✓ $fileName generated successfully'),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
          action: SnackBarAction(
            label: 'Open',
            textColor: Colors.white,
            onPressed: () async {
               // Initial attempt to save and open
               try {
                 final dir = await getApplicationDocumentsDirectory();
                 final file = File('${dir.path}/$fileName');
                 await file.writeAsBytes(excelBytes);
                 // We can't easily "open" it without a launcher, but we saved it.
                 // For now, just show it's saved.
                 // Printing.sharePdf might not work well for xlsx on all platforms but let's try sharing
                 await Printing.sharePdf(bytes: excelBytes, filename: fileName);
               } catch (e) {
                 print('Error opening file: $e');
               }
            },
          ),
        ),
      );
    }
  }

  Future<void> _generateDefermentForm() async {
    final pdfBytes = await showModalBottomSheet<Uint8List>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => const GenerateDefermentDialog(),
    );

    if (pdfBytes == null) return;

    await Printing.layoutPdf(
      onLayout: (format) async => pdfBytes,
      name: 'Deferment_Form_${DateFormat('yyyyMMdd_HHmmss').format(DateTime.now())}.pdf',
    );

    final now = DateTime.now();
    final fileName = 'Deferment_${DateFormat('yyyyMMdd_HHmmss').format(now)}.pdf';
    final sizeKB = (pdfBytes.length / 1024).toStringAsFixed(0);
    
    setState(() {
      _documents.insert(0, DocumentItem(
        title: fileName,
        type: 'pdf',
        size: '$sizeKB KB',
        status: 'Pending',
        category: 'Deferment Form',
        uploadedBy: 'System',
        date: now,
        tags: ['Deferment', 'Generated', 'PDF'],
        fileBytes: pdfBytes,
      ));
    });
    _updateDashboardPendingDocs();

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

  Future<void> _generateSOA() async {
    // Show the generation bottom sheet
    final pdfBytes = await showModalBottomSheet<Uint8List>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
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
        status: 'Pending',
        category: 'Statement of Account',
        uploadedBy: 'System',
        date: now,
        tags: ['SOA', 'Generated', 'PDF'],
        fileBytes: pdfBytes, // Store actual bytes for storage calculation
      ));
    });
    _updateDashboardPendingDocs();

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
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            child: Row(
                              children: [
                                _buildMobileCategoryChip('All Documents', Icons.folder_open),
                                const SizedBox(width: 8),
                                ..._categories.map((cat) {
                                  final categoryIcons = {
                                    'Statement of Account': Icons.receipt_long,
                                    'Deferment Form': Icons.assignment_turned_in,
                                    'Weekly Report': Icons.assessment_outlined,
                                  };
                                  return Padding(
                                    padding: const EdgeInsets.only(right: 8),
                                    child: _buildMobileCategoryChip(cat, categoryIcons[cat] ?? Icons.folder),
                                  );
                                }),
                                // Add Category button
                                GestureDetector(
                                  onTap: _addNewCategory,
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(20),
                                      border: Border.all(color: kPrimaryColor, width: 1.5),
                                    ),
                                    child: const Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(Icons.add, size: 16, color: kPrimaryColor),
                                        SizedBox(width: 6),
                                        Text(
                                          'Add Category',
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: kPrimaryColor,
                                            fontWeight: FontWeight.w600,
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
                                if (_filteredDocs.isEmpty)
                                  Column(
                                    children: [
                                      _buildGenerateButton(),
                                      const SizedBox(height: 24),
                                      const Center(
                                        child: Padding(
                                          padding: EdgeInsets.all(40),
                                          child: Column(
                                            children: [
                                              Icon(Icons.folder_open, size: 64, color: Color(0xFFCBD5E1)),
                                              SizedBox(height: 16),
                                              Text(
                                                "No documents found",
                                                style: TextStyle(fontSize: 16, color: Color(0xFF64748B), fontWeight: FontWeight.w500),
                                              ),
                                              SizedBox(height: 8),
                                              Text(
                                                "Generate your first document above",
                                                style: TextStyle(fontSize: 13, color: Color(0xFF94A3B8)),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ],
                                  )
                                else ...[
                                  if (_isGridView)
                                    _buildGrid(_filteredDocs)
                                  else
                                    _buildList(_filteredDocs),
                                  const SizedBox(height: 16),
                                  _buildGenerateButton(),
                                ],
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
                                    if (_filteredDocs.isEmpty)
                                      Column(
                                        children: [
                                          _buildGenerateButton(),
                                          const SizedBox(height: 40),
                                          const Center(
                                            child: Padding(
                                              padding: EdgeInsets.all(40),
                                              child: Column(
                                                children: [
                                                  Icon(Icons.folder_open, size: 80, color: Color(0xFFCBD5E1)),
                                                  SizedBox(height: 20),
                                                  Text(
                                                    "No documents found",
                                                    style: TextStyle(fontSize: 18, color: Color(0xFF64748B), fontWeight: FontWeight.w600),
                                                  ),
                                                  SizedBox(height: 8),
                                                  Text(
                                                    "Generate your first document using the button above",
                                                    style: TextStyle(fontSize: 14, color: Color(0xFF94A3B8)),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ),
                                        ],
                                      )
                                    else ...[
                                      if (_isGridView)
                                        _buildGrid(_filteredDocs)
                                      else
                                        _buildList(_filteredDocs),
                                      const SizedBox(height: 24),
                                      _buildGenerateButton(),
                                    ],
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
    final categoryIcons = {
      'Statement of Account': Icons.receipt_long,
      'Deferment Form': Icons.assignment_turned_in,
      'Weekly Report': Icons.assessment_outlined,
    };
    
    final categories = [
      {'name': 'All Documents', 'icon': Icons.folder_open},
      ..._categories.map((cat) => {
        'name': cat,
        'icon': categoryIcons[cat] ?? Icons.folder,
      }),
    ];
    
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ...categories.map((cat) {
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
          }),
          const SizedBox(height: 8),
          InkWell(
            onTap: _addNewCategory,
            child: Container(
              width: double.infinity,
              margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.transparent,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: kPrimaryColor, width: 1.5),
              ),
              child: const Row(
                children: [
                  Icon(Icons.add, size: 18, color: kPrimaryColor),
                  SizedBox(width: 12),
                  Text(
                    'Add Category',
                    style: TextStyle(
                      fontSize: 14,
                      color: kPrimaryColor,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
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
    
    // Calculate actual storage from file bytes
    final totalBytes = _documents.fold<int>(0, (sum, doc) {
      return sum + (doc.fileBytes?.length ?? 0);
    });
    final totalMB = totalBytes / (1024 * 1024);
    
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
            value: totalMB >= 1 ? '${totalMB.toStringAsFixed(2)} MB' : '${(totalBytes / 1024).toStringAsFixed(1)} KB',
            icon: Icons.cloud,
            color: Colors.blue,
          ),
        ],
      ),
    );
  }

  Widget _buildGenerateButton() {
    final isMobileView = isMobile(context);
    
    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(
        vertical: isMobileView ? 16 : 32,
        horizontal: isMobileView ? 16 : 24,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: kBorderColor, style: BorderStyle.solid),
      ),
      child: isMobileView
          ? Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: kPrimaryColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.add_circle_outline, size: 24, color: kPrimaryColor),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Generate Documents',
                        style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: kTextPrimary),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Create SOA, deferment forms, weekly reports',
                        style: TextStyle(fontSize: 12, color: kTextSecondary.withOpacity(0.8)),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: _showGenerateModal,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: kPrimaryColor,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    elevation: 0,
                  ),
                  child: const Text('Create', style: TextStyle(fontSize: 14)),
                ),
              ],
            )
          : Column(
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
                const Text('Create statements, deferment forms, and weekly reports', style: TextStyle(fontSize: 14, color: kTextSecondary)),
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
          itemBuilder: (context, index) => AnimatedCard(
            delay: Duration(milliseconds: 300 + (index * 50)),
            child: _DocumentGridCard(
              doc: docs[index],
              onToggleStatus: _toggleDocumentStatus,
              onArchive: _archiveDocument,
            ),
          ),
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
            children: docs.asMap().entries.map((entry) => AnimatedCard(
              delay: Duration(milliseconds: 300 + (entry.key * 50)),
              child: Container(
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
                  Icon(_getFileIcon(entry.value.type), size: 24, color: _getFileColor(entry.value.type)),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          entry.value.title,
                          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: kTextPrimary),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Text(entry.value.size, style: const TextStyle(fontSize: 11, color: kTextSecondary)),
                      ],
                    ),
                  ),
                  _StatusBadge(status: entry.value.status),
                  PopupMenuButton<String>(
                    icon: const Icon(Icons.more_vert, size: 18, color: kTextSecondary),
                    itemBuilder: (context) => [
                      if (entry.value.fileBytes != null) ...[
                        const PopupMenuItem(
                          value: 'edit',
                          child: Row(
                            children: [
                              Icon(Icons.edit, size: 18, color: Colors.blue),
                              SizedBox(width: 8),
                              Text('Edit'),
                            ],
                          ),
                        ),
                        const PopupMenuItem(
                          value: 'download',
                          child: Row(
                            children: [
                              Icon(Icons.download, size: 18, color: Colors.green),
                              SizedBox(width: 8),
                              Text('Download'),
                            ],
                          ),
                        ),
                      ],
                      PopupMenuItem(
                        value: 'verify',
                        child: Row(
                          children: [
                            Icon(
                              entry.value.status == 'Verified' ? Icons.pending : Icons.verified,
                              size: 18,
                              color: entry.value.status == 'Verified' ? Colors.orange : Colors.green,
                            ),
                            const SizedBox(width: 8),
                            Text(entry.value.status == 'Verified' ? 'Mark as Pending' : 'Mark as Verified'),
                          ],
                        ),
                      ),
                      const PopupMenuItem(
                        value: 'archive',
                        child: Row(
                          children: [
                            Icon(Icons.archive, size: 18, color: Colors.red),
                            SizedBox(width: 8),
                            Text('Archive'),
                          ],
                        ),
                      ),
                    ],
                    onSelected: (value) async {
                      if (value == 'edit') {
                        await Printing.layoutPdf(
                          onLayout: (format) async => entry.value.fileBytes!,
                          name: entry.value.title,
                        );
                      } else if (value == 'download') {
                        await Printing.sharePdf(
                          bytes: entry.value.fileBytes!,
                          filename: entry.value.title,
                        );
                      } else if (value == 'verify') {
                        _toggleDocumentStatus(entry.value);
                      } else if (value == 'archive') {
                        _archiveDocument(entry.value);
                      }
                    },
                  ),
                ],
              ),
              const SizedBox(height: 12),
              const Divider(height: 1),
              const SizedBox(height: 12),
              Row(
                children: [
                  const Icon(Icons.person_outline, size: 14, color: kTextSecondary),
                  const SizedBox(width: 6),
                  Text(entry.value.uploadedBy, style: const TextStyle(fontSize: 12, color: kTextSecondary)),
                  const Spacer(),
                  const Icon(Icons.calendar_today, size: 14, color: kTextSecondary),
                  const SizedBox(width: 6),
                  Text('${entry.value.date.month}/${entry.value.date.day}/${entry.value.date.year}', style: const TextStyle(fontSize: 12, color: kTextSecondary)),
                ],
              ),
            ],
          ),
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
                    SizedBox(
                      width: 40,
                      child: PopupMenuButton<String>(
                        icon: const Icon(Icons.more_vert, size: 18, color: kTextSecondary),
                        itemBuilder: (context) => [
                          if (doc.fileBytes != null) ...[
                            const PopupMenuItem(
                              value: 'edit',
                              child: Row(
                                children: [
                                  Icon(Icons.edit, size: 18, color: Colors.blue),
                                  SizedBox(width: 8),
                                  Text('Edit'),
                                ],
                              ),
                            ),
                            const PopupMenuItem(
                              value: 'download',
                              child: Row(
                                children: [
                                  Icon(Icons.download, size: 18, color: Colors.green),
                                  SizedBox(width: 8),
                                  Text('Download'),
                                ],
                              ),
                            ),
                          ],
                          PopupMenuItem(
                            value: 'verify',
                            child: Row(
                              children: [
                                Icon(
                                  doc.status == 'Verified' ? Icons.pending : Icons.verified,
                                  size: 18,
                                  color: doc.status == 'Verified' ? Colors.orange : Colors.green,
                                ),
                                const SizedBox(width: 8),
                                Text(doc.status == 'Verified' ? 'Mark as Pending' : 'Mark as Verified'),
                              ],
                            ),
                          ),
                          const PopupMenuItem(
                            value: 'archive',
                            child: Row(
                              children: [
                                Icon(Icons.archive, size: 18, color: Colors.red),
                                SizedBox(width: 8),
                                Text('Archive'),
                              ],
                            ),
                          ),
                        ],
                        onSelected: (value) async {
                          if (value == 'edit') {
                            await Printing.layoutPdf(
                              onLayout: (format) async => doc.fileBytes!,
                              name: doc.title,
                            );
                          } else if (value == 'download') {
                            await Printing.sharePdf(
                              bytes: doc.fileBytes!,
                              filename: doc.title,
                            );
                          } else if (value == 'verify') {
                            _toggleDocumentStatus(doc);
                          } else if (value == 'archive') {
                            _archiveDocument(doc);
                          }
                        },
                      ),
                    ),
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
  final Function(DocumentItem) onToggleStatus;
  final Function(DocumentItem) onArchive;
  const _DocumentGridCard({
    required this.doc,
    required this.onToggleStatus,
    required this.onArchive,
  });

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
              PopupMenuButton<String>(
                icon: const Icon(Icons.more_vert, size: 16, color: kTextSecondary),
                padding: EdgeInsets.zero,
                itemBuilder: (context) => [
                  if (doc.fileBytes != null) ...[
                    const PopupMenuItem(
                      value: 'edit',
                      child: Row(
                        children: [
                          Icon(Icons.edit, size: 16, color: Colors.blue),
                          SizedBox(width: 8),
                          Text('Edit', style: TextStyle(fontSize: 13)),
                        ],
                      ),
                    ),
                    const PopupMenuItem(
                      value: 'download',
                      child: Row(
                        children: [
                          Icon(Icons.download, size: 16, color: Colors.green),
                          SizedBox(width: 8),
                          Text('Download', style: TextStyle(fontSize: 13)),
                        ],
                      ),
                    ),
                  ],
                  PopupMenuItem(
                    value: 'verify',
                    child: Row(
                      children: [
                        Icon(
                          doc.status == 'Verified' ? Icons.pending : Icons.verified,
                          size: 16,
                          color: doc.status == 'Verified' ? Colors.orange : Colors.green,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          doc.status == 'Verified' ? 'Pending' : 'Verify',
                          style: const TextStyle(fontSize: 13),
                        ),
                      ],
                    ),
                  ),
                  const PopupMenuItem(
                    value: 'archive',
                    child: Row(
                      children: [
                        Icon(Icons.archive, size: 16, color: Colors.red),
                        SizedBox(width: 8),
                        Text('Archive', style: TextStyle(fontSize: 13)),
                      ],
                    ),
                  ),
                ],
                onSelected: (value) async {
                  if (value == 'edit') {
                    await Printing.layoutPdf(
                      onLayout: (format) async => doc.fileBytes!,
                      name: doc.title,
                    );
                  } else if (value == 'download') {
                    await Printing.sharePdf(
                      bytes: doc.fileBytes!,
                      filename: doc.title,
                    );
                  } else if (value == 'verify') {
                    onToggleStatus(doc);
                  } else if (value == 'archive') {
                    onArchive(doc);
                  }
                },
              ),
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