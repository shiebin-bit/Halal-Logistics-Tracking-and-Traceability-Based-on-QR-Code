import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
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

/// Application entry point.
void main() {
  runApp(const HalalLogisticsApp());
}

/// Root widget that defines global theme and app navigation routes.
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

        // --- Premium Typography ---
        textTheme: GoogleFonts.poppinsTextTheme().copyWith(
          headlineLarge: GoogleFonts.poppins(fontWeight: FontWeight.w700),
          headlineMedium: GoogleFonts.poppins(fontWeight: FontWeight.w600),
          titleLarge: GoogleFonts.poppins(fontWeight: FontWeight.w600),
          titleMedium: GoogleFonts.poppins(fontWeight: FontWeight.w600),
          bodyLarge: GoogleFonts.inter(),
          bodyMedium: GoogleFonts.inter(),
          bodySmall: GoogleFonts.inter(),
          labelLarge: GoogleFonts.inter(fontWeight: FontWeight.w600),
        ),

        // --- Premium Card Theme ---
        cardTheme: CardThemeData(
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          color: Colors.white,
          surfaceTintColor: Colors.transparent,
        ),

        // --- Enhanced Elevated Button ---
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            elevation: 0,
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
            textStyle: GoogleFonts.poppins(
              fontWeight: FontWeight.w600,
              fontSize: 14,
              letterSpacing: 0.3,
            ),
          ),
        ),

        // --- Enhanced Outlined Button ---
        outlinedButtonTheme: OutlinedButtonThemeData(
          style: OutlinedButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
            textStyle: GoogleFonts.poppins(
              fontWeight: FontWeight.w600,
              fontSize: 14,
            ),
          ),
        ),

        // --- Premium Input Fields ---
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide(color: Colors.grey[200]!),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide(color: Colors.grey[200]!),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: Color(0xFF1B5E20), width: 2),
          ),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
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
