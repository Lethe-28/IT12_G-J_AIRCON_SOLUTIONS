import 'package:flutter/material.dart';

class LoginScreen extends StatelessWidget {
  const LoginScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final inputBorder = OutlineInputBorder(
      borderRadius: BorderRadius.circular(10),
      borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
    );

    return Scaffold(
      backgroundColor: const Color(0xFFEFF5FF),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(vertical: 40),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 920),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(Icons.apartment_rounded,
                    size: 40, color: Colors.white),
              ),
              const SizedBox(height: 16),
              const Text('G & J System',
                  style: TextStyle(fontSize: 28, fontWeight: FontWeight.w700)),
              const SizedBox(height: 6),
              const Text('Scheduling and Expense Management',
                  style: TextStyle(color: Colors.black54)),
              const SizedBox(height: 26),
              Container(
                width: 560,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x11000000),
                      blurRadius: 24,
                      offset: Offset(0, 10),
                    ),
                  ],
                ),
                padding: const EdgeInsets.fromLTRB(28, 24, 28, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Center(
                      child: Text('Login to Your Account',
                          style: TextStyle(
                              fontSize: 18, fontWeight: FontWeight.w700)),
                    ),
                    const SizedBox(height: 18),
                    const Text('Username / Email',
                        style: TextStyle(fontWeight: FontWeight.w600)),
                    const SizedBox(height: 8),
                    TextField(
                      decoration: InputDecoration(
                        hintText: 'Enter your email',
                        prefixIcon: const Icon(Icons.person_outline),
                        border: inputBorder,
                        enabledBorder: inputBorder,
                        focusedBorder: inputBorder.copyWith(
                          borderSide: BorderSide(
                              color: theme.colorScheme.primary, width: 1.5),
                        ),
                        filled: true,
                        fillColor: const Color(0xFFF8FAFC),
                      ),
                    ),
                    const SizedBox(height: 14),
                    const Text('Password',
                        style: TextStyle(fontWeight: FontWeight.w600)),
                    const SizedBox(height: 8),
                    TextField(
                      obscureText: true,
                      decoration: InputDecoration(
                        hintText: 'Enter your password',
                        prefixIcon: const Icon(Icons.lock_outline),
                        border: inputBorder,
                        enabledBorder: inputBorder,
                        focusedBorder: inputBorder.copyWith(
                          borderSide: BorderSide(
                              color: theme.colorScheme.primary, width: 1.5),
                        ),
                        filled: true,
                        fillColor: const Color(0xFFF8FAFC),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Checkbox(value: true, onChanged: (_) {}),
                        const Text('Remember me'),
                        const Spacer(),
                        TextButton(
                          onPressed: () {},
                          child: const Text('Forgot Password?'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    SizedBox(
                      height: 48,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: theme.colorScheme.primary,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        onPressed: () {
                          Navigator.of(context)
                              .pushReplacementNamed('/dashboard');
                        },
                        child: const Text('Login'),
                      ),
                    ),
                    const SizedBox(height: 18),
                    const Divider(),
                    const SizedBox(height: 8),
                    const Text('Demo Credentials:',
                        style: TextStyle(color: Colors.black54)),
                    const SizedBox(height: 8),
                    _demoRow('Admin:', 'admin@gj.com'),
                    _demoRow('Manager:', 'manager@gj.com'),
                    _demoRow('Technician:', 'tech@gj.com'),
                  ],
                ),
              ),
                const SizedBox(height: 22),
                const Text('© 2025 G & J Air Conditioning Services',
                    style: TextStyle(color: Colors.black54, fontSize: 12)),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _demoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          SizedBox(width: 90, child: Text(label)),
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Text(value, style: const TextStyle(color: Colors.black87)),
            ),
          ),
        ],
      ),
    );
  }
}


