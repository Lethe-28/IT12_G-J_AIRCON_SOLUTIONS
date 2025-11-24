import 'package:flutter/material.dart';
import 'ui_app_shell.dart';

class DocumentsScreen extends StatelessWidget {
  const DocumentsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final cards = [
      ('Invoice_ABC_Corp_Nov2025.pdf', '245 KB', 'ABC Corporation', 'John Doe • 11/10/2025', 'Verified'),
      ('Job_Report_XYZ_Retail.xlsx', '89 KB', 'XYZ Retail', 'Jane Smith • 11/10/2025', 'Pending'),
      ('Receipt_Fuel_20251110.jpg', '1.2 MB', 'Mike Johnson', '11/10/2025', 'Pending'),
      ('Service_Contract_GlobalMall.docx', '156 KB', 'Global Mall', 'Admin User • 11/9/2025', 'Verified'),
      ('Materials_Receipt_20251109.pdf', '312 KB', 'Sarah Lee', '11/9/2025', 'Verified'),
    ];
    return AppShell(
      selectedIndex: 3,
      body: Column(
        children: [
          
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Text('Document Management',
                          style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
                      const Spacer(),
                      ElevatedButton.icon(
                        onPressed: () {},
                        icon: const Icon(Icons.cloud_upload_outlined),
                        label: const Text('Upload Document'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(child: _summaryTile('Total Documents', '5')),
                      const SizedBox(width: 12),
                      Expanded(child: _summaryTile('Pending Review', '2')),
                      const SizedBox(width: 12),
                      Expanded(child: _summaryTile('Verified', '3')),
                      const SizedBox(width: 12),
                      Expanded(child: _summaryTile('Total Storage', '2.1 MB')),
                    ],
                  ),
                  const SizedBox(height: 12),
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final isSmall = constraints.maxWidth < 700;
                      
                      if (isSmall) {
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _filtersToolbar(),
                            const SizedBox(height: 12),
                            _uploadArea(),
                            const SizedBox(height: 12),
                            _documentGrid(cards),
                          ],
                        );
                      }
                      
                      return Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SizedBox(
                            width: 200,
                            child: _filterBox(),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _filtersToolbar(),
                                const SizedBox(height: 12),
                                _uploadArea(),
                                const SizedBox(height: 12),
                                _documentGrid(cards),
                              ],
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _filtersToolbar() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          decoration: InputDecoration(
            hintText: 'Search documents...',
            prefixIcon: const Icon(Icons.search),
            filled: true,
            fillColor: Colors.white,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide.none,
            ),
          ),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            SizedBox(
              width: 200,
              child: DropdownButtonFormField<String>(
                value: 'All Status',
                decoration: const InputDecoration(
                  labelText: 'Status',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
                items: const [
                  DropdownMenuItem(value: 'All Status', child: Text('All Status')),
                  DropdownMenuItem(value: 'Pending', child: Text('Pending')),
                  DropdownMenuItem(value: 'Verified', child: Text('Verified')),
                ],
                onChanged: (_) {},
              ),
            ),
            SizedBox(
              width: 200,
              child: DropdownButtonFormField<String>(
                value: 'This Month',
                decoration: const InputDecoration(
                  labelText: 'Date Range',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
                items: const [
                  DropdownMenuItem(value: 'This Month', child: Text('This Month')),
                  DropdownMenuItem(value: 'Last Month', child: Text('Last Month')),
                  DropdownMenuItem(value: 'Custom', child: Text('Custom Range')),
                ],
                onChanged: (_) {},
              ),
            )
          ],
        ),
      ],
    );
  }

  Widget _summaryTile(String title, String value) {
    return Container(
      decoration: _cardDeco(),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(color: Colors.black54)),
          const SizedBox(height: 6),
          Text(value, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
        ],
      ),
    );
  }

  Widget _uploadArea() {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: const Color(0xFFE2E8F0), width: 2),
        borderRadius: BorderRadius.circular(12),
        color: const Color(0xFFFAFBFC),
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.blue.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.cloud_upload_outlined, size: 40, color: Colors.blue),
          ),
          const SizedBox(height: 12),
          const Text(
            'Drag files here or click browse',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 12),
          ElevatedButton.icon(
            onPressed: () {},
            icon: const Icon(Icons.folder_open, size: 18),
            label: const Text('Browse'),
          ),
        ],
      ),
    );
  }

  Widget _filterBox() {
    final cats = ['All Documents', 'Invoices', 'Job Reports', 'Receipts', 'Contracts'];
    return Container(
      width: 240,
      decoration: _cardDeco(),
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Filter by Category', style: TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 10),
          ...cats.map((c) => ListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                title: Text(c),
                trailing: const Text('1', style: TextStyle(color: Colors.black45)),
              )),
        ],
      ),
    );
  }

  Widget _documentGrid(List<(String, String, String, String, String)> cards) {
    return LayoutBuilder(
      builder: (context, constraints) {
        int crossAxisCount = 3;
        if (constraints.maxWidth < 900) {
          crossAxisCount = 2;
        }
        if (constraints.maxWidth < 600) {
          crossAxisCount = 1;
        }
        
        return GridView.count(
          crossAxisCount: crossAxisCount,
          mainAxisSpacing: 8,
          crossAxisSpacing: 8,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          childAspectRatio: 0.85,
          children: cards.map((c) => _docCard(c)).toList(),
        );
      },
    );
  }

  Widget _docCard((String, String, String, String, String) c) {
    final status = c.$5;
    final isVerified = status == 'Verified';
    final badgeColor = isVerified ? const Color(0xFFE8FFF3) : const Color(0xFFFFF4E5);
    final badgeText = Text(status,
        style: TextStyle(
            color: isVerified ? const Color(0xFF059669) : const Color(0xFFB45309),
            fontSize: 12,
            fontWeight: FontWeight.w600));
    
    // Extract file extension
    final fileName = c.$1;
    final fileExt = fileName.split('.').last.toLowerCase();
    
    // Determine file type colors and icons
    Color iconBgColor = const Color(0xFFEFF5FF);
    Color iconColor = const Color(0xFF2563EB);
    String fileType = 'Unknown';
    
    if (fileExt == 'pdf') {
      iconBgColor = const Color(0xFFFFEEEE);
      iconColor = Colors.red;
      fileType = 'PDF';
    } else if (fileExt == 'xlsx' || fileExt == 'xls') {
      iconBgColor = const Color(0xFFEEFFEE);
      iconColor = Colors.green;
      fileType = 'Excel';
    } else if (['jpg', 'jpeg', 'png', 'gif'].contains(fileExt)) {
      iconBgColor = const Color(0xFFFFF4E5);
      iconColor = const Color(0xFFEA8C1A);
      fileType = 'Image';
    } else if (fileExt == 'docx' || fileExt == 'doc') {
      iconBgColor = const Color(0xFFEFF5FF);
      iconColor = const Color(0xFF2563EB);
      fileType = 'Document';
    }
    
    return MouseRegion(
      onEnter: (_) {},
      onExit: (_) {},
      child: Container(
        decoration: _cardDeco(),
        padding: const EdgeInsets.all(10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 40,
                  height: 48,
                  decoration: BoxDecoration(
                    color: iconBgColor,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(_getFileIcon(fileExt), color: iconColor, size: 20),
                      const SizedBox(height: 1),
                      Text(fileType, 
                        style: TextStyle(fontSize: 7, color: iconColor, fontWeight: FontWeight.w700),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                  decoration:
                      BoxDecoration(color: badgeColor, borderRadius: BorderRadius.circular(999)),
                  child: badgeText,
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(c.$1, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12), maxLines: 2, overflow: TextOverflow.ellipsis),
            const SizedBox(height: 3),
            Text(c.$2, style: const TextStyle(color: Colors.black54, fontSize: 11)),
            const SizedBox(height: 6),
            Wrap(
              spacing: 4,
              runSpacing: 2,
              children: [
                _tagChip('Document'),
                _tagChip(fileType),
              ],
            ),
            const SizedBox(height: 6),
            Text(c.$3, style: const TextStyle(color: Colors.blue, fontSize: 11)),
            const SizedBox(height: 1),
            Text(c.$4, style: const TextStyle(color: Colors.black54, fontSize: 10)),
            const Spacer(),
            SizedBox(
              height: 32,
              child: Row(
                children: [
                  Expanded(
                    child: TextButton(
                      onPressed: () {},
                      child: const Text('View', style: TextStyle(fontSize: 12)),
                      style: TextButton.styleFrom(
                        padding: EdgeInsets.zero,
                      ),
                    ),
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () {},
                      child: const Text('Download', style: TextStyle(fontSize: 12)),
                      style: OutlinedButton.styleFrom(
                        padding: EdgeInsets.zero,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _tagChip(String tag) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: const Color(0xFFF0F4F8),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(tag, style: const TextStyle(fontSize: 9, color: Colors.black54)),
    );
  }

  IconData _getFileIcon(String ext) {
    switch (ext) {
      case 'pdf':
        return Icons.picture_as_pdf;
      case 'xlsx':
      case 'xls':
        return Icons.table_chart;
      case 'jpg':
      case 'jpeg':
      case 'png':
      case 'gif':
        return Icons.image;
      case 'docx':
      case 'doc':
        return Icons.description;
      default:
        return Icons.insert_drive_file;
    }
  }

  BoxDecoration _cardDeco() => BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      );
}






