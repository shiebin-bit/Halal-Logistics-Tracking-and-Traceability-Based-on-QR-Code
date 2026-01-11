import 'package:flutter/material.dart';
// 1. Auth & Entry Screens
import 'screens/splash_screen.dart';
import 'screens/login_screen.dart';
import 'screens/registration_screen.dart';

// 2. Dashboards (Note the /dashboards/ path)
import 'screens/dashboards/processor_dashboard.dart';
import 'screens/dashboards/logistics_dashboard.dart';
import 'screens/dashboards/retailer_dashboard.dart';
import 'screens/dashboards/admin_dashboard.dart';
import 'screens/dashboards/consumer_dashboard.dart'; // We will create this next

void main() {
  runApp(const HalalLogisticsApp());
}

class HalalLogisticsApp extends StatelessWidget {
  const HalalLogisticsApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Halal Logistics Tracking',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        // Global Theme: Forest Green (Matches your new UI)
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF1B5E20),
          primary: const Color(0xFF1B5E20),
        ),
        useMaterial3: true,
        scaffoldBackgroundColor: Colors.grey[50],
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),

      // The Starting Route
      initialRoute: '/',

      // The Route Map
      routes: {
        '/': (context) => const SplashScreen(),
        '/login': (context) => const LoginScreen(),
        '/register': (context) => const RegistrationScreen(),

        // Dashboard Routes
        '/dashboard/processor': (context) => const ProcessorDashboard(),
        '/dashboard/logistics': (context) => const LogisticsDashboard(),
        '/dashboard/retailer': (context) => const RetailerDashboard(),
        '/dashboard/admin': (context) => const AdminDashboard(),
        '/dashboard/consumer': (context) => const ConsumerDashboard(),
      },
    );
  }
}
