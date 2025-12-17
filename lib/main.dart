import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart'; // REQUIRED IMPORT
import 'package:flutter_dotenv/flutter_dotenv.dart';
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
import 'services/notification_service.dart';

Future<void> main() async {
  // 1. Initialize the Flutter engine
  WidgetsFlutterBinding.ensureInitialized();

  // Testing environment
  await dotenv.load(fileName: ".env");

  // 2. Initialize Supabase (THE MISSING PIECE)
  // You MUST replace these strings with your actual Supabase keys
  await Supabase.initialize(
    url: dotenv.env['SUPABASE_URL']!,
    anonKey: dotenv.env['SUPABASE_ANON_KEY']!,
  );

  // 3. Initialize Notifications
  await NotificationService().init();

  // 3. Run the app
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'G&J Aircon Solutions',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF2563EB)),
        useMaterial3: true,
        scaffoldBackgroundColor: const Color(0xFFF3F6FB),
        fontFamily: 'Roboto',
      ),
      // Check if user is already logged in to decide initial route
      initialRoute: Supabase.instance.client.auth.currentSession != null
          ? '/dashboard'
          : '/login',
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
    );
  }
}
