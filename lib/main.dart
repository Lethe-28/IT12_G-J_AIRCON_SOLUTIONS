import 'package:flutter/material.dart';
import 'login.dart';
import 'dashboard.dart';
import 'scheduling.dart';
import 'expenses.dart';
import 'documents.dart';
import 'reports.dart';
import 'usermanage.dart';
import 'settings.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'G & J System',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF2563EB)),
        useMaterial3: true,
        scaffoldBackgroundColor: const Color(0xFFF3F6FB),
        fontFamily: 'Roboto',
      ),
      routes: {
        '/login': (_) => const LoginScreen(),
        '/dashboard': (_) => const DashboardScreen(),
        '/scheduling': (_) => const SchedulingScreen(),
        '/expenses': (_) => const ExpensesScreen(),
        '/documents': (_) => const DocumentsScreen(),
        '/reports': (_) => const ReportsScreen(),
        '/users': (_) => const UserManagementScreen(),
        '/settings': (_) => const SettingsScreen(),
      },
      initialRoute: '/login',
    );
  }
}

// The rest of the feature screens live in their own files under lib/.
