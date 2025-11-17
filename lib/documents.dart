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
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Text('Document Management',
                    style: TextStyle(fontSize: 24, fontWeight: FontWeight.w700)),
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
            const SizedBox(height: 16),
            Row(
              children: [
                _filterBox(),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
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
                ),
                const SizedBox(width: 12),
                _filterButton('All Status'),
                const SizedBox(width: 12),
                _filterButton(''),
                const SizedBox(width: 12),
                _filterButton(''),
              ],
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 16,
              runSpacing: 16,
              children: cards.map((c) => _docCard(c)).toList(),
            ),
          ],
        ),
      ),
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

  Widget _docCard((String, String, String, String, String) c) {
    final status = c.$5;
    final isVerified = status == 'Verified';
    final badgeColor = isVerified ? const Color(0xFFE8FFF3) : const Color(0xFFFFF4E5);
    final badgeText = Text(status,
        style: TextStyle(
            color: isVerified ? const Color(0xFF059669) : const Color(0xFFB45309),
            fontSize: 12,
            fontWeight: FontWeight.w600));
    return Container(
      width: 360,
      decoration: _cardDeco(),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 48,
                decoration: BoxDecoration(
                  color: const Color(0xFFEFF5FF),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.insert_drive_file, color: Color(0xFF2563EB)),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration:
                    BoxDecoration(color: badgeColor, borderRadius: BorderRadius.circular(999)),
                child: badgeText,
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(c.$1, style: const TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 4),
          Text(c.$2, style: const TextStyle(color: Colors.black54)),
          const SizedBox(height: 10),
          Text(c.$3, style: const TextStyle(color: Colors.blue)),
          const SizedBox(height: 2),
          Text(c.$4, style: const TextStyle(color: Colors.black54)),
          const SizedBox(height: 14),
          Row(
            children: [
              TextButton(onPressed: () {}, child: const Text('View')),
              const SizedBox(width: 8),
              OutlinedButton(onPressed: () {}, child: const Text('Download')),
            ],
          ),
        ],
      ),
    );
  }

  Widget _filterButton(String label) {
    return OutlinedButton(
      onPressed: () {},
      child: label.isEmpty
          ? const Icon(Icons.grid_view_outlined)
          : Row(children: [Text(label), const Icon(Icons.keyboard_arrow_down)]),
      style: OutlinedButton.styleFrom(
        foregroundColor: Colors.black87,
        side: const BorderSide(color: Color(0xFFE2E8F0)),
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  BoxDecoration _cardDeco() => BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: const [
          BoxShadow(color: Color(0x11000000), blurRadius: 16, offset: Offset(0, 10)),
        ],
      );
}




