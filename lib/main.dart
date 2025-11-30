import 'package:flutter/material.dart';
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

// The rest of the feature screens live in their own files under lib/.
