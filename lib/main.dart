import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart'; // NEW IMPORT

import 'login.dart';
import 'dashboard.dart';
import 'scheduling.dart';
import 'expenses.dart';
import 'payments.dart';
import 'documents.dart';
import 'reports.dart';
import 'usermanage.dart';
import 'settings.dart';
import 'customers.dart';
import 'technicians.dart';
import 'aircons.dart';
import 'service_items.dart';
import 'master_data.dart';

Future<void> main() async {
  // 1. Ensure Flutter is ready before we start the backend
  WidgetsFlutterBinding.ensureInitialized();

  // 2. Connect to Supabase
  // GO TO YOUR SUPABASE DASHBOARD -> SETTINGS -> API to find these keys.
  await Supabase.initialize(
    url: 'https://tuwiauhnstzocrbcfono.supabase.co',
    anonKey: 'sb_publishable_lRaDnJO0YkZCNwJS-6jBEA_LNXLRQ5S',
  );

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

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
      // We keep your existing routes exactly as they were
      routes: {
        '/login': (_) => const LoginScreen(),
        '/dashboard': (_) => const DashboardScreen(),
        '/scheduling': (_) => const SchedulingScreen(),
        '/expenses': (_) => const ExpensesScreen(),
        '/payments': (_) => const PaymentsScreen(),
        '/documents': (_) => const DocumentsScreen(),
        '/reports': (_) => const ReportsScreen(),
        '/customers': (_) => const CustomersScreen(),
        '/technicians': (_) => const TechniciansScreen(),
        '/aircons': (_) => const AirconsScreen(),
        '/service-items': (_) => const ServiceItemsScreen(),
        '/master-data': (_) => const MasterDataScreen(),
        '/users': (_) => const UserManagementScreen(),
        '/settings': (_) => const SettingsScreen(),
      },
      initialRoute: '/login',
    );
  }
}
