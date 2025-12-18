import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:printing/printing.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'ui_app_shell.dart';
import 'data/app_state.dart';
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
  final String? id; // Supabase ID
  final String title;
  final String type; // 'pdf', 'excel', 'image', 'word'
  final String size;
  final String category; // 'Statement of Account', 'Deferment Form', 'Weekly Report'
  final String uploadedBy;
  final DateTime date;
  final List<String> tags;
  final Uint8List? fileBytes;
  bool isArchived;

  DocumentItem({
    this.id,
    required this.title,
    required this.type,
    required this.size,
    required this.category,
    required this.uploadedBy,
    required this.date,
    required this.tags,
    this.fileBytes,
    this.isArchived = false,
  });

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'title': title,
      'type': type,
      'size': size,
      'category': category,
      'uploaded_by': uploadedBy,
      'date': date.toIso8601String(),
      'tags': tags,
      'is_archived': isArchived,
    };
  }

  factory DocumentItem.fromMap(Map<String, dynamic> map) {
    return DocumentItem(
      id: map['id']?.toString(),
      title: map['title'] ?? '',
      type: map['type'] ?? 'pdf',
      size: map['size'] ?? '0 KB',
      category: map['category'] ?? 'Other',
      uploadedBy: map['uploaded_by'] ?? 'System',
      date: DateTime.parse(map['date'] ?? DateTime.now().toIso8601String()),
      tags: List<String>.from(map['tags'] ?? []),
      isArchived: map['is_archived'] ?? false,
    );
  }
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
  final String _sortBy = 'date';
  String _dateFilter = 'All Time'; // All Time, Today, This Week, This Month
  
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
    _fetchDocuments();
  }

  Future<void> _fetchDocuments() async {
    try {
      final supabase = Supabase.instance.client;
      final response = await supabase
          .from('documents')
          .select()
          .order('date', ascending: false);
      
      if (mounted) {
        setState(() {
          _documents.clear();
          _documents.addAll((response as List).map((m) => DocumentItem.fromMap(m)));
        });
        _updateDashboardPendingDocs();
      }
    } catch (e) {
      debugPrint('Error fetching documents: $e');
    }
  }

  Future<String?> _saveToDatabase(DocumentItem doc) async {
    try {
      final supabase = Supabase.instance.client;
      final map = doc.toMap();
      
      final response = await supabase
          .from('documents')
          .upsert(map)
          .select()
          .single();
      
      return response['id']?.toString();
    } catch (e) {
      debugPrint('Error saving document: $e');
      return null;
    }
  }

  Future<void> _deleteFromDatabase(String id) async {
    try {
      final supabase = Supabase.instance.client;
      await supabase.from('documents').delete().eq('id', id);
    } catch (e) {
      debugPrint('Error deleting document: $e');
    }
  }

  void _updateDashboardPendingDocs() {
     // Pending documents concept removed per user request
     DashboardProvider().updatePendingDocsCount(0);
  }
  
  // Removed _addNewCategory as requested
  // Method logic removed
  
  // Removed _toggleDocumentStatus as Verified/Pending status is removed
  
  Future<void> _archiveDocument(DocumentItem doc) async {
    doc.isArchived = true;
    await _saveToDatabase(doc);
    setState(() {});
    _updateDashboardPendingDocs();
    
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${doc.title} moved to Archive'),
          backgroundColor: Colors.orange,
          behavior: SnackBarBehavior.floating,
          action: SnackBarAction(
            label: 'Undo',
            textColor: Colors.white,
            onPressed: () async {
              doc.isArchived = false;
              await _saveToDatabase(doc);
              setState(() {});
              _updateDashboardPendingDocs();
            },
          ),
        ),
      );
    }
  }

  Future<void> _restoreDocument(DocumentItem doc) async {
    doc.isArchived = false;
    await _saveToDatabase(doc);
    setState(() {});
    _updateDashboardPendingDocs();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('${doc.title} restored'), behavior: SnackBarBehavior.floating),
    );
  }

  Future<void> _permanentDelete(DocumentItem doc) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Permanently'),
        content: Text('Are you sure you want to permanently delete "${doc.title}"? This action cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      if (doc.id != null) {
        await _deleteFromDatabase(doc.id!);
      }
      setState(() {
        _documents.remove(doc);
      });
      _updateDashboardPendingDocs();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Document deleted permanently'), backgroundColor: Colors.red, behavior: SnackBarBehavior.floating),
        );
      }
    }
  }

  List<DocumentItem> get _filteredDocs {
    var result = _documents.where((doc) {
      final isArchiveView = _selectedCategory == 'Archive';
      if (isArchiveView && !doc.isArchived) return false;
      if (!isArchiveView && doc.isArchived) return false;

      final matchesCategory = _selectedCategory == 'All Documents' || _selectedCategory == 'Archive' || doc.category == _selectedCategory;
      final matchesSearch = doc.title.toLowerCase().contains(_searchQuery.toLowerCase()) || 
                            doc.uploadedBy.toLowerCase().contains(_searchQuery.toLowerCase());
      
      // Date Filter
      bool matchesDate = true;
      final now = DateTime.now();
      if (_dateFilter == 'Today') {
        matchesDate = doc.date.year == now.year && doc.date.month == now.month && doc.date.day == now.day;
      } else if (_dateFilter == 'This Week') {
        final weekAgo = now.subtract(const Duration(days: 7));
        matchesDate = doc.date.isAfter(weekAgo);
      } else if (_dateFilter == 'This Month') {
        matchesDate = doc.date.year == now.year && doc.date.month == now.month;
      }

      return matchesCategory && matchesSearch && matchesDate;
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
    
    if (excelBytes != null) {
      final now = DateTime.now();
      final fileName = 'WeeklyReport_${DateFormat('yyyyMMdd_HHmmss').format(now)}.xlsx';
      final doc = DocumentItem(
        title: fileName,
        type: 'excel',
        size: '${(excelBytes.length / 1024).toStringAsFixed(1)} KB',
        category: 'Weekly Report',
        uploadedBy: AppState.currentUserName,
        date: now,
        tags: ['Weekly Report', 'Generated', 'Excel'],
        fileBytes: excelBytes,
      );

      final docId = await _saveToDatabase(doc);
      final docWithId = DocumentItem(
        id: docId,
        title: doc.title,
        type: doc.type,
        size: doc.size,
        category: doc.category,
        uploadedBy: doc.uploadedBy,
        date: doc.date,
        tags: doc.tags,
        fileBytes: doc.fileBytes,
      );

      setState(() {
        _documents.insert(0, docWithId);
      });
      _updateDashboardPendingDocs();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✓ $fileName generated and saved'),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  Future<void> _generateDefermentForm() async {
    final pdfBytes = await showModalBottomSheet<Uint8List>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => const GenerateDefermentDialog(),
    );

    if (pdfBytes != null) {
      await Printing.layoutPdf(
        onLayout: (format) async => pdfBytes,
        name: 'Deferment_Form_${DateFormat('yyyyMMdd_HHmmss').format(DateTime.now())}.pdf',
      );

      final now = DateTime.now();
      final fileName = 'Deferment_${DateFormat('yyyyMMdd_HHmmss').format(now)}.pdf';
      final doc = DocumentItem(
        title: fileName,
        type: 'pdf',
        size: '${(pdfBytes.length / 1024).toStringAsFixed(1)} KB',
        category: 'Deferment Form',
        uploadedBy: AppState.currentUserName,
        date: now,
        tags: ['Deferment', 'Generated', 'PDF'],
        fileBytes: pdfBytes,
      );

      final docId = await _saveToDatabase(doc);
      final docWithId = DocumentItem(
        id: docId,
        title: doc.title,
        type: doc.type,
        size: doc.size,
        category: doc.category,
        uploadedBy: doc.uploadedBy,
        date: doc.date,
        tags: doc.tags,
        fileBytes: doc.fileBytes,
      );

      setState(() {
        _documents.insert(0, docWithId);
      });
      _updateDashboardPendingDocs();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✓ $fileName generated and saved'),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  Future<void> _generateSOA() async {
    final pdfBytes = await showModalBottomSheet<Uint8List>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => const GenerateSOADialog(),
    );

    if (pdfBytes != null) {
      await Printing.layoutPdf(
        onLayout: (format) async => pdfBytes,
        name: 'SOA_${DateFormat('yyyyMMdd_HHmmss').format(DateTime.now())}.pdf',
      );

      final now = DateTime.now();
      final fileName = 'SOA_${DateFormat('yyyyMMdd_HHmmss').format(now)}.pdf';
      final doc = DocumentItem(
        title: fileName,
        type: 'pdf',
        size: '${(pdfBytes.length / 1024).toStringAsFixed(1)} KB',
        category: 'Statement of Account',
        uploadedBy: AppState.currentUserName,
        date: now,
        tags: ['SOA', 'Generated', 'PDF'],
        fileBytes: pdfBytes,
      );

      final docId = await _saveToDatabase(doc);
      final docWithId = DocumentItem(
        id: docId,
        title: doc.title,
        type: doc.type,
        size: doc.size,
        category: doc.category,
        uploadedBy: doc.uploadedBy,
        date: doc.date,
        tags: doc.tags,
        fileBytes: doc.fileBytes,
      );

      setState(() {
        _documents.insert(0, docWithId);
      });
      _updateDashboardPendingDocs();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✓ $fileName generated and saved'),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
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
                        const SizedBox(height: 12),
                        _buildDateFilter(),
                      ],
                    )
                    : Row(
                      children: [
                        const Text(
                          'Document Management',
                          style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: kTextPrimary, letterSpacing: -0.5),
                        ),
                        const Spacer(),
                        _buildDateFilter(),
                        const SizedBox(width: 16),
                        SizedBox(
                          width: 250,
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
                                Padding(
                                  padding: const EdgeInsets.only(right: 8),
                                  child: _buildMobileCategoryChip('Archive', Icons.archive_outlined),
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
                        
                        // Removed Stats Row as per request

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
                            // Removed Stats Row as per request

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
                                        )
                                      else ...[
                                        if (_isGridView)
                                          _buildGrid(_filteredDocs)
                                        else
                                          _buildList(_filteredDocs),
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
      'Archive': Icons.archive,
    };
    
    final categories = [
      {'name': 'All Documents', 'icon': Icons.folder_open},
      ..._categories.map((cat) => {
        'name': cat,
        'icon': categoryIcons[cat] ?? Icons.folder,
      }),
      {'name': 'Archive', 'icon': Icons.archive_outlined},
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
            
            int count;
            if (name == 'Archive') {
              count = _documents.where((d) => d.isArchived).length;
            } else if (name == 'All Documents') {
              count = _documents.where((d) => !d.isArchived).length;
            } else {
              count = _documents.where((d) => !d.isArchived && d.category == name).length;
            }
                
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
        ],
      ),
    );
  }

  Widget _buildMobileCategoryChip(String name, IconData icon) {
    final isSelected = _selectedCategory == name;
    
    int count;
    if (name == 'Archive') {
      count = _documents.where((d) => d.isArchived).length;
    } else if (name == 'All Documents') {
      count = _documents.where((d) => !d.isArchived).length;
    } else {
      count = _documents.where((d) => !d.isArchived && d.category == name).length;
    }
    
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

  // Removed unused _buildStatsRow

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
              onArchive: _archiveDocument,
              onRestore: _restoreDocument,
              onDeletePermanently: _permanentDelete,
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
                  const Spacer(),
                  PopupMenuButton<String>(
                    icon: const Icon(Icons.more_vert, size: 18, color: kTextSecondary),
                    itemBuilder: (context) => [
                      if (entry.value.fileBytes != null) ...[
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
                      if (!entry.value.isArchived)
                      const PopupMenuItem(
                        value: 'archive',
                        child: Row(
                          children: [
                            Icon(Icons.archive, size: 18, color: Colors.orange),
                            SizedBox(width: 8),
                            Text('Archive'),
                          ],
                        ),
                      )
                      else ...[
                        const PopupMenuItem(
                          value: 'restore',
                          child: Row(
                            children: [
                              Icon(Icons.unarchive, size: 18, color: Colors.blue),
                              SizedBox(width: 8),
                              Text('Restore'),
                            ],
                          ),
                        ),
                        const PopupMenuItem(
                          value: 'delete',
                          child: Row(
                            children: [
                              Icon(Icons.delete_forever, size: 18, color: Colors.red),
                              SizedBox(width: 8),
                              Text('Delete Permanently'),
                            ],
                          ),
                        ),
                      ],
                    ],
                    onSelected: (value) async {
                      if (value == 'download') {
                        await Printing.sharePdf(
                          bytes: entry.value.fileBytes!,
                          filename: entry.value.title,
                        );
                      } else if (value == 'archive') {
                        _archiveDocument(entry.value);
                      } else if (value == 'restore') {
                        _restoreDocument(entry.value);
                      } else if (value == 'delete') {
                        _permanentDelete(entry.value);
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
                    SizedBox(
                      width: 40,
                      child: PopupMenuButton<String>(
                        icon: const Icon(Icons.more_vert, size: 18, color: kTextSecondary),
                        itemBuilder: (context) => [
                          if (doc.fileBytes != null) ...[
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
                          if (!doc.isArchived)
                          const PopupMenuItem(
                            value: 'archive',
                            child: Row(
                              children: [
                                Icon(Icons.archive, size: 18, color: Colors.orange),
                                SizedBox(width: 8),
                                Text('Archive'),
                              ],
                            ),
                          )
                          else ...[
                            const PopupMenuItem(
                              value: 'restore',
                              child: Row(
                                children: [
                                  Icon(Icons.unarchive, size: 18, color: Colors.blue),
                                  SizedBox(width: 8),
                                  Text('Restore'),
                                ],
                              ),
                            ),
                            const PopupMenuItem(
                              value: 'delete',
                              child: Row(
                                children: [
                                  Icon(Icons.delete_forever, size: 18, color: Colors.red),
                                  SizedBox(width: 8),
                                  Text('Delete Permanently'),
                                ],
                              ),
                            ),
                          ],
                        ],
                        onSelected: (value) async {
                          if (value == 'download') {
                            await Printing.sharePdf(
                              bytes: doc.fileBytes!,
                              filename: doc.title,
                            );
                          } else if (value == 'archive') {
                            _archiveDocument(doc);
                          } else if (value == 'restore') {
                            _restoreDocument(doc);
                          } else if (value == 'delete') {
                            _permanentDelete(doc);
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

  Widget _buildDateFilter() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: kBorderColor),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: ['All Time', 'Today', 'This Week', 'This Month'].map((range) {
          final isSelected = _dateFilter == range;
          return GestureDetector(
            onTap: () => setState(() => _dateFilter = range),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: isSelected ? Colors.white : Colors.transparent,
                borderRadius: BorderRadius.circular(6),
                boxShadow: isSelected ? [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 2, offset: const Offset(0, 1))] : null,
              ),
              child: Text(
                range,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                  color: isSelected ? kPrimaryColor : kTextSecondary,
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
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
  final Function(DocumentItem) onArchive;
  final Function(DocumentItem) onRestore;
  final Function(DocumentItem) onDeletePermanently;
  const _DocumentGridCard({
    required this.doc,
    required this.onArchive,
    required this.onRestore,
    required this.onDeletePermanently,
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
              PopupMenuButton<String>(
                icon: const Icon(Icons.more_vert, size: 16, color: kTextSecondary),
                padding: EdgeInsets.zero,
                itemBuilder: (context) => [
                  if (doc.fileBytes != null) ...[
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
                  if (!doc.isArchived)
                  const PopupMenuItem(
                    value: 'archive',
                    child: Row(
                      children: [
                        Icon(Icons.archive, size: 16, color: Colors.orange),
                        SizedBox(width: 8),
                        Text('Archive', style: TextStyle(fontSize: 13)),
                      ],
                    ),
                  )
                  else ...[
                    const PopupMenuItem(
                      value: 'restore',
                      child: Row(
                        children: [
                          Icon(Icons.unarchive, size: 16, color: Colors.blue),
                          SizedBox(width: 8),
                          Text('Restore', style: TextStyle(fontSize: 13)),
                        ],
                      ),
                    ),
                    const PopupMenuItem(
                      value: 'delete',
                      child: Row(
                        children: [
                          Icon(Icons.delete_forever, size: 16, color: Colors.red),
                          SizedBox(width: 8),
                          Text('Delete Permanently', style: TextStyle(fontSize: 13)),
                        ],
                      ),
                    ),
                  ],
                ],
                onSelected: (value) async {
                  if (value == 'download') {
                    await Printing.sharePdf(
                      bytes: doc.fileBytes!,
                      filename: doc.title,
                    );
                  } else if (value == 'archive') {
                    onArchive(doc);
                  } else if (value == 'restore') {
                    onRestore(doc);
                  } else if (value == 'delete') {
                    onDeletePermanently(doc);
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