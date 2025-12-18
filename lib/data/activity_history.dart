import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '/ui_app_shell.dart'; // Or wherever your AppShell is

class ActivityHistoryScreen extends StatefulWidget {
  const ActivityHistoryScreen({super.key});

  @override
  State<ActivityHistoryScreen> createState() => _ActivityHistoryScreenState();
}

class _ActivityHistoryScreenState extends State<ActivityHistoryScreen> {
  bool _isLoading = true;
  List<Map<String, dynamic>> _logs = [];

  @override
  void initState() {
    super.initState();
    _fetchAllLogs();
  }

  Future<void> _fetchAllLogs() async {
    try {
      final response = await Supabase.instance.client
          .from('activity_logs')
          .select('*')
          .order('created_at', ascending: false)
          .limit(100); // Fetch top 100 history

      if (mounted) {
        setState(() {
          _logs = List<Map<String, dynamic>>.from(response);
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppShell(
      selectedIndex: 0, // Keeps "Dashboard" highlighted
      body: Scaffold(
        backgroundColor: const Color(0xFFF8FAFC),
        appBar: AppBar(
          title: const Text(
            "Activity History",
            style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black),
          ),
          backgroundColor: Colors.white,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.black),
            onPressed: () =>
                Navigator.of(context).pushReplacementNamed('/dashboard'),
          ),
        ),
        body: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : ListView.separated(
                padding: const EdgeInsets.all(20),
                itemCount: _logs.length,
                separatorBuilder: (ctx, i) => const Divider(height: 1),
                itemBuilder: (ctx, i) {
                  final log = _logs[i];
                  final date = DateTime.parse(log['created_at']).toLocal();
                  final dateStr =
                      "${date.month}/${date.day} ${date.hour}:${date.minute.toString().padLeft(2, '0')}";

                  IconData icon = Icons.info;
                  Color color = Colors.grey;

                  // Simple color coding based on action type
                  final action = log['action_type'] ?? '';
                  if (action == 'Create') {
                    icon = Icons.add_circle;
                    color = Colors.blue;
                  } else if (action == 'Delete') {
                    icon = Icons.delete;
                    color = Colors.red;
                  } else if (action == 'Update') {
                    icon = Icons.edit;
                    color = Colors.orange;
                  } else if (action == 'Payment') {
                    icon = Icons.payments;
                    color = Colors.green;
                  }

                  return Container(
                    decoration: const BoxDecoration(color: Colors.white),
                    child: ListTile(
                      leading: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: color.withOpacity(0.1),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(icon, color: color, size: 16),
                      ),
                      title: Text(
                        log['details'] ?? 'No details',
                        style: const TextStyle(fontSize: 14),
                      ),
                      subtitle: Text(
                        "${log['user_name'] ?? 'System'} • $dateStr",
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.grey,
                        ),
                      ),
                    ),
                  );
                },
              ),
      ),
    );
  }
}
