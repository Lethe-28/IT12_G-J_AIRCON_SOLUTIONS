import 'package:flutter/material.dart';
import 'ui_app_shell.dart';

class UserManagementScreen extends StatelessWidget {
  const UserManagementScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return AppShell(
      selectedIndex: 5,
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Text('User Management',
                    style: TextStyle(fontSize: 24, fontWeight: FontWeight.w700)),
                const Spacer(),
                ElevatedButton.icon(
                  onPressed: () {},
                  icon: const Icon(Icons.person_add_alt_1),
                  label: const Text('Add User'),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Expanded(
              child: Container(
                decoration: _cardDeco(),
                child: const Center(
                  child: Text('User list goes here',
                      style: TextStyle(color: Colors.black54)),
                ),
              ),
            ),
          ],
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




