import 'package:flutter/material.dart';
import 'ui_app_shell.dart';

class ExpensesScreen extends StatelessWidget {
  const ExpensesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final records = List.generate(
      8,
      (i) => ('Fuel', 'JO-2025-00$i • John Doe', '11/10/2025', i.isEven ? '₱450' : '₱2,500',
          i.isEven ? 'Verified' : 'Pending'),
    );

    return AppShell(
      selectedIndex: 2,
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Text('Expense Tracking',
                    style: TextStyle(fontSize: 24, fontWeight: FontWeight.w700)),
                const Spacer(),
                ElevatedButton.icon(
                  onPressed: () {},
                  icon: const Icon(Icons.add),
                  label: const Text('Add Expense'),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(child: _statCard('Today\'s Total', '₱5,450', '5 transactions', Colors.blue)),
                const SizedBox(width: 14),
                Expanded(child: _statCard('Weekly Total', '₱6,000', '7 transactions', Colors.green)),
                const SizedBox(width: 14),
                Expanded(child: _statCard('Monthly Total', '₱6,000', 'November 2025', Colors.purple)),
              ],
            ),
            const SizedBox(height: 14),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: _spendingChart()),
                const SizedBox(width: 16),
                Expanded(
                  child: _recordsList(records),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _statCard(String title, String value, String note, Color color) {
    return Container(
      decoration: _cardDeco(),
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Container(
            decoration:
                BoxDecoration(color: color.withOpacity(.1), borderRadius: BorderRadius.circular(10)),
            padding: const EdgeInsets.all(10),
            child: Icon(Icons.insights, color: color),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
              const SizedBox(height: 6),
              Text(value, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
              const SizedBox(height: 2),
              Text(note, style: const TextStyle(color: Colors.black54)),
            ],
          )
        ],
      ),
    );
  }

  Widget _spendingChart() {
    final data = [
      ('Fuel', Colors.blue, 16),
      ('Materials', Colors.purple, 72),
      ('Food', Colors.green, 6),
      ('Transportation', Colors.orange, 6),
    ];
    return Container(
      decoration: _cardDeco(),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Spending Distribution',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
          const SizedBox(height: 16),
          // Simple horizontal "pie" with stacked bars (no external deps)
          Container(
            height: 22,
            decoration: BoxDecoration(
              color: const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(999),
            ),
            clipBehavior: Clip.antiAlias,
            child: Row(
              children: data
                  .map((e) => Expanded(
                        flex: e.$3,
                        child: Container(color: e.$2),
                      ))
                  .toList(),
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 16,
            runSpacing: 8,
            children: data
                .map((e) => Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(width: 10, height: 10, color: e.$2),
                        const SizedBox(width: 6),
                        Text('${e.$1} ${e.$3}%'),
                      ],
                    ))
                .toList(),
          ),
          const SizedBox(height: 16),
          const Divider(),
          const SizedBox(height: 6),
          const Text('Fuel  ₱970\nMaterials  ₱4,300\nFood  ₱380\nTransportation  ₱350'),
        ],
      ),
    );
  }

  Widget _recordsList(List<(String, String, String, String, String)> records) {
    return Container(
      decoration: _cardDeco(),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text('Expense Records',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
              const Spacer(),
              OutlinedButton.icon(
                onPressed: () {},
                icon: const Icon(Icons.file_download_outlined),
                label: const Text('Export Report'),
              ),
            ],
          ),
          const SizedBox(height: 12),
          TextField(
            decoration: InputDecoration(
              hintText: 'Search expenses...',
              prefixIcon: const Icon(Icons.search),
              filled: true,
              fillColor: const Color(0xFFF8FAFC),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide.none,
              ),
            ),
          ),
          const SizedBox(height: 12),
          ...records.map((r) => _recordRow(r)),
        ],
      ),
    );
  }

  Widget _recordRow((String, String, String, String, String) r) {
    final status = r.$5;
    final color = status == 'Verified' ? Colors.green : Colors.orange;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration:
          const BoxDecoration(border: Border(bottom: BorderSide(color: Color(0xFFF1F5F9)))),
      child: Row(
        children: [
          const CircleAvatar(
            backgroundColor: Color(0xFFEAF2FF),
            child: Icon(Icons.bolt, color: Color(0xFF2563EB)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(r.$1, style: const TextStyle(fontWeight: FontWeight.w700)),
                Text('${r.$2} • ${r.$3}', style: const TextStyle(color: Colors.black54)),
              ],
            ),
          ),
          Text(r.$4, style: const TextStyle(color: Colors.green, fontWeight: FontWeight.w700)),
          const SizedBox(width: 10),
          Row(
            children: [
              Icon(Icons.verified, color: color, size: 18),
              const SizedBox(width: 6),
              Text(status, style: TextStyle(color: color)),
              const SizedBox(width: 16),
              const Icon(Icons.edit_outlined, color: Colors.indigo, size: 18),
              const SizedBox(width: 12),
              const Icon(Icons.delete_outline, color: Colors.red, size: 18),
            ],
          )
        ],
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




