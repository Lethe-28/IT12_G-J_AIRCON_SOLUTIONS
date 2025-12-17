import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

// --- DATA & SERVICES ---
import 'data/app_state.dart';
import 'services/notification_service.dart';

// --- SCREENS ---
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
  WidgetsFlutterBinding.ensureInitialized();

  // Load Environment Variables
  await dotenv.load(fileName: ".env");

  // Initialize Supabase
  await Supabase.initialize(
    url: dotenv.env['SUPABASE_URL']!,
    anonKey: dotenv.env['SUPABASE_ANON_KEY']!,
  );

  // Initialize Notifications
  await NotificationService().init();

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
      home: const AuthInitializer(),
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

class AuthInitializer extends StatefulWidget {
  const AuthInitializer({super.key});

  @override
  State<AuthInitializer> createState() => _AuthInitializerState();
}

class _AuthInitializerState extends State<AuthInitializer> {
  @override
  void initState() {
    super.initState();
    // Run after build to ensure context is valid
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _resolveUserSession();
    });
  }

  Future<void> _resolveUserSession() async {
    final supabase = Supabase.instance.client;
    final session = supabase.auth.currentSession;

    debugPrint("AuthInit: Checking Session...");

    // 1. No Session? -> Go to Login
    if (session == null) {
      debugPrint("AuthInit: No session found. Going to login.");
      _goToLogin();
      return;
    }

    // 2. Validate Email
    final userEmail = session.user.email;
    if (userEmail == null) {
      debugPrint("AuthInit: Email is null. Logging out.");
      await supabase.auth.signOut();
      _goToLogin();
      return;
    }

    // 3. Query DB with TIMEOUT
    try {
      debugPrint("AuthInit: Fetching profile for $userEmail...");

      // --- ADDED TIMEOUT: Forces a fail if it hangs for 10 seconds ---
      final data = await supabase
          .from('app_users')
          .select('*, roles(role_name)')
          .eq('email', userEmail)
          .maybeSingle()
          .timeout(const Duration(seconds: 10)); // <--- CRITICAL FIX

      if (data == null) {
        debugPrint("AuthInit: User profile not found in DB. Going to login.");
        await supabase.auth.signOut();
        _goToLogin();
        return;
      }

      // 4. Update AppState
      final roleData = data['roles'];
      final roleName = roleData != null ? roleData['role_name'] : 'User';
      final roleString = roleName.toString().toLowerCase();

      debugPrint("AuthInit: Success! Role is $roleString");

      if (roleString == 'service manager') {
        AppState.currentRole = UserRole.serviceManager;
      } else {
        AppState.currentRole = UserRole.admin;
      }

      final fullName = data['full_name'];
      if (fullName != null) {
        AppState.currentUserName = fullName;
      }

      // 5. Navigate to Dashboard
      if (mounted) {
        Navigator.of(context).pushReplacementNamed('/dashboard');
      }
    } catch (e) {
      debugPrint("AuthInit CRITICAL ERROR: $e");
      // If ANYTHING goes wrong (Timeout, Network, DB), force Logout.
      await supabase.auth.signOut();
      _goToLogin();
    }
  }

  void _goToLogin() {
    if (mounted) {
      Navigator.of(context).pushReplacementNamed('/login');
    }
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 20),
            Text(
              "Loading G&J System...",
              style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 10),
            Text(
              "Checking user session...",
              style: TextStyle(color: Colors.grey, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }
}
