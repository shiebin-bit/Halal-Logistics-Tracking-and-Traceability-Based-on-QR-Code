import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:async';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();

    // 1. Setup Animation Controller
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    );

    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeIn));

    _scaleAnimation = Tween<double>(
      begin: 0.8,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.elasticOut));

    // Start Animation
    _controller.forward();

    // 2. Start Login Check
    _checkLoginStatus();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _checkLoginStatus() async {
    // Artificial delay to show the logo
    await Future.delayed(const Duration(seconds: 3));

    final prefs = await SharedPreferences.getInstance();
    final bool isLoggedIn = prefs.getBool('isLoggedIn') ?? false;
    final String? savedRole = prefs.getString('userRole');

    if (mounted) {
      if (isLoggedIn && savedRole != null) {
        String route = _getRouteForRole(savedRole);
        Navigator.pushReplacementNamed(context, route);
      } else {
        Navigator.pushReplacementNamed(context, '/login');
      }
    }
  }

  String _getRouteForRole(String role) {
    switch (role) {
      case 'processor':
        return '/dashboard/processor';
      case 'logistics':
        return '/dashboard/logistics';
      case 'retailer':
        return '/dashboard/retailer';
      case 'admin':
        return '/dashboard/admin';
      default:
        return '/login';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          // Advanced Feature: Premium Vertical Gradient
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFF1B5E20), // Deep Forest Green
              Color(0xFF2E7D32),
              Color(0xFF4CAF50), // Standard Green
            ],
          ),
        ),
        child: Stack(
          children: [
            // Center Content (Logo + Text)
            Center(
              child: FadeTransition(
                opacity: _fadeAnimation,
                child: ScaleTransition(
                  scale: _scaleAnimation,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // --- PREMIUM LOGO CONTAINER ---
                      Hero(
                        tag: 'app_logo',
                        child: Container(
                          height: 160,
                          width: 160,
                          // IMPORTANT: White background needed for contrast
                          decoration: BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.3),
                                blurRadius: 25,
                                offset: const Offset(0, 10),
                              ),
                            ],
                          ),
                          // Padding: 20 gives it space, 'contain' ensures full logo shows
                          padding: const EdgeInsets.all(4),
                          child: Image.asset(
                            'assets/images/logo.png',
                            fit: BoxFit.contain,
                            errorBuilder: (c, o, s) => const Icon(
                              Icons.shield,
                              size: 80,
                              color: Color(0xFF1B5E20),
                            ),
                          ),
                        ),
                      ),

                      // -------------------------------
                      const SizedBox(height: 35),

                      // App Title
                      const Text(
                        "HALAL LOGISTICS",
                        style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.w900,
                          color: Colors.white,
                          letterSpacing: 2.0,
                          shadows: [
                            Shadow(
                              color: Colors.black26,
                              offset: Offset(0, 2),
                              blurRadius: 4,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 8),

                      // Slogan
                      const Text(
                        "Integrity from Farm to Fork",
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w300,
                          color: Colors.white70,
                          fontStyle: FontStyle.italic,
                          letterSpacing: 1.0,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // Bottom Content (Loader + Version)
            Positioned(
              bottom: 50,
              left: 0,
              right: 0,
              child: Column(
                children: const [
                  CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    strokeWidth: 2,
                  ),
                  SizedBox(height: 20),
                  Text(
                    "Initializing Secure Chain...",
                    style: TextStyle(
                      color: Colors.white54,
                      fontSize: 10,
                      fontFamily: 'monospace',
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
