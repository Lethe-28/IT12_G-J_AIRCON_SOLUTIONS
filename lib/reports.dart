import 'package:flutter/material.dart';
import 'ui_app_shell.dart';

class ReportsScreen extends StatelessWidget {
  const ReportsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return AppShell(
      selectedIndex: 4,
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Text('Reports & Analytics',
                    style: TextStyle(fontSize: 24, fontWeight: FontWeight.w700)),
                const Spacer(),
                ElevatedButton.icon(
                  onPressed: () {},
                  icon: const Icon(Icons.file_download_outlined),
                  label: const Text('Export All Reports'),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                _tab('Service Summary', true),
                const SizedBox(width: 10),
                _tab('Expense Report', false),
                const SizedBox(width: 10),
                _tab('Technician Productivity', false),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(child: _miniStat('Total Jobs', '285', '+ 12% from last month', Colors.blue)),
                const SizedBox(width: 12),
                Expanded(child: _miniStat('Installations', '112', '+ 8% from last month', Colors.green)),
                const SizedBox(width: 12),
                Expanded(child: _miniStat('Maintenance', '143', '+ 15% from last month', Colors.teal)),
                const SizedBox(width: 12),
                Expanded(child: _miniStat('Repairs', '83', '− 5% from last month', Colors.orange)),
              ],
            ),
            const SizedBox(height: 18),
            _barChartCard(),
          ],
        ),
      ),
    );
  }

  Widget _tab(String label, bool selected) {
    return Container(
      decoration: BoxDecoration(
        color: selected ? const Color(0xFFEAF2FF) : Colors.white,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Text(label,
          style: TextStyle(
              color: selected ? const Color(0xFF2563EB) : Colors.black87,
              fontWeight: FontWeight.w600)),
    );
  }

  Widget _miniStat(String title, String value, String note, Color color) {
    return Container(
      decoration: _cardDeco(),
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Container(
            decoration: BoxDecoration(color: color.withOpacity(.1), borderRadius: BorderRadius.circular(10)),
            padding: const EdgeInsets.all(10),
            child: Icon(Icons.auto_graph, color: color),
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
          ),
        ],
      ),
    );
  }

  Widget _barChartCard() {
    final months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun'];
    final installs = [12.0, 16.0, 18.0, 20.0, 22.0, 25.0];
    final maintenance = [17.0, 22.0, 19.0, 25.0, 30.0, 33.0];
    final repairs = [8.0, 12.0, 10.0, 15.0, 18.0, 20.0];
    return Container(
      decoration: _cardDeco(),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text('Service Summary (Last 6 Months)',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
              const Spacer(),
              OutlinedButton(onPressed: () {}, child: const Text('6 Months')),
              const SizedBox(width: 8),
              OutlinedButton(onPressed: () {}, child: const Text('1 Year')),
              const SizedBox(width: 8),
              ElevatedButton.icon(
                onPressed: () {},
                icon: const Icon(Icons.picture_as_pdf_outlined),
                label: const Text('Export PDF'),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 260,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: List.generate(months.length, (i) {
                return Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      _barGroup(installs[i], maintenance[i], repairs[i]),
                      const SizedBox(height: 6),
                      Text(months[i]),
                    ],
                  ),
                );
              }),
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: const [
              _Legend(color: Colors.blue, text: 'Installations'),
              SizedBox(width: 16),
              _Legend(color: Colors.green, text: 'Maintenance'),
              SizedBox(width: 16),
              _Legend(color: Colors.orange, text: 'Repairs'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _barGroup(double a, double b, double c) {
    double scale = 8; // simple scale to fit height
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        _bar(a * scale, Colors.blue),
        const SizedBox(width: 4),
        _bar(b * scale, Colors.green),
        const SizedBox(width: 4),
        _bar(c * scale, Colors.orange),
      ],
    );
  }

  Widget _bar(double height, Color color) {
    return Expanded(
      child: Container(
        height: height,
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(6),
        ),
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

class _Legend extends StatelessWidget {
  final Color color;
  final String text;
  const _Legend({required this.color, required this.text});
  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(width: 12, height: 12, color: color),
        const SizedBox(width: 6),
        Text(text, style: const TextStyle(color: Colors.black54)),
      ],
    );
  }
}


