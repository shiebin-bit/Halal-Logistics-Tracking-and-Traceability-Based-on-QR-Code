import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../config.dart';
import './dashboards/admin_dashboard.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();

  // Controllers
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  // State
  bool _isPasswordVisible = false;
  bool _isLoading = false;
  bool _rememberMe = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _loadSavedEmail();
  }

  /// Load saved email from SharedPreferences for "Remember Me" feature.
  Future<void> _loadSavedEmail() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _rememberMe = prefs.getBool('remember_me') ?? false;
      if (_rememberMe) {
        _emailController.text = prefs.getString('saved_email') ?? '';
      }
    });
  }

  /// Authenticate user via API and navigate to role-specific dashboard.
  Future<void> _handleLogin() async {
    if (_formKey.currentState!.validate()) {

      setState(() => _isLoading = true);

      final url = Uri.parse('$apiBaseUrl/login');

      try {
        final response = await http.post(
          url,
          headers: {'Accept': 'application/json'},
          body: {
            'email': _emailController.text.trim(),
            'password': _passwordController.text,
          },
        );

        if (response.statusCode == 200) {
          final data = jsonDecode(response.body);
          final user = data['user']; // The full user object from Laravel
          String token = data['token'];
          String role = user['role'];

          // --- SAVE DATA ---
          final prefs = await SharedPreferences.getInstance();
          await prefs.setBool('isLoggedIn', true);
          await prefs.setString('auth_token', token);
          await prefs.setString('userRole', role);
          await prefs.setString('userName', user['name']);
          await prefs.setString('userId', user['id'].toString());

          // --- NEW: SAVE SPECIFIC PROFILE DATA ---
          // We check which profile exists and save relevant details
          if (role == 'logistics' && user['logistics_profile'] != null) {
            await prefs.setString('vehicle_plate',
                user['logistics_profile']['vehicle_plate_no'] ?? '');
            await prefs.setString('license_no',
                user['logistics_profile']['driver_license_no'] ?? '');
          } else if (role == 'processor' && user['processor_profile'] != null) {
            await prefs.setString('company_reg',
                user['processor_profile']['company_reg_no'] ?? '');
            await prefs.setString(
                'halal_cert', user['processor_profile']['halal_cert_no'] ?? '');
          } else if (role == 'retailer' && user['retailer_profile'] != null) {
            await prefs.setString(
                'store_name', user['retailer_profile']['store_name'] ?? '');
          }

          // Handle "Remember Me" (No changes needed here)
          if (_rememberMe) {
            await prefs.setBool('remember_me', true);
            await prefs.setString('saved_email', _emailController.text.trim());
          } else {
            await prefs.remove('remember_me');
            await prefs.remove('saved_email');
          }

          // Route Logic (No changes needed)

          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                  content: Text('Login Successful!'),
                  backgroundColor: Colors.green),
            );
            await Future.delayed(const Duration(milliseconds: 500));

            if (role == 'admin') {
              // Direct navigation to Admin Dashboard
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (context) => const AdminDashboard()),
              );
            } else {
              // Existing logic for other roles
              String route = '/login';
              if (role == 'processor')
                route = '/dashboard/processor';
              else if (role == 'logistics')
                route = '/dashboard/logistics';
              else if (role == 'retailer')
                route = '/dashboard/retailer';
              else if (role == 'consumer') route = '/dashboard/consumer';

              Navigator.pushReplacementNamed(context, route);
            }
          }
        } else {
          final errorData = jsonDecode(response.body);
          _showError(errorData['message'] ?? 'Login failed');
        }
      } catch (e) {
        _showError('Connection failed. Check server or internet.');
      } finally {
        if (mounted) setState(() => _isLoading = false);
      }
    }
  }

  void _showError(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: Colors.red[700],
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    // We use a Stack to layer the Background Texture behind the Content
    return Scaffold(
      body: Stack(
        children: [
          // 1. LAYER ONE: The All-Green Gradient Background
          Container(
            height: double.infinity,
            width: double.infinity,
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Color(0xFF1B5E20), // Deep Green
                  Color(0xFF2E7D32), // Medium Green
                  Color(0xFF43A047), // Lighter Green
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
          ),

          // 2. LAYER TWO: The "Texture" (Geometric Shapes)
          // Top Left Circle
          Positioned(
            top: -50,
            left: -50,
            child: Container(
              height: 200,
              width: 200,
              decoration: BoxDecoration(
                color:
                    Colors.white.withValues(alpha: 0.05), // Subtle transparent white
                shape: BoxShape.circle,
              ),
            ),
          ),
          // Center Right Circle
          Positioned(
            top: 150,
            right: -30,
            child: Container(
              height: 120,
              width: 120,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.05),
                shape: BoxShape.circle,
              ),
            ),
          ),
          // Bottom Left Circle
          Positioned(
            bottom: 50,
            left: -20,
            child: Container(
              height: 300,
              width: 300,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.03),
                shape: BoxShape.circle,
              ),
            ),
          ),

          // 3. LAYER THREE: The Main Content
          Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const SizedBox(height: 40),

                  Container(
                    // 1. REMOVE PADDING: Set to zero so image touches the edge
                    padding: EdgeInsets.zero,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.2),
                          blurRadius: 15,
                          offset: const Offset(0, 5),
                        ),
                      ],
                    ),
                    child: ClipOval(
                      child: SizedBox(
                        // 2. INCREASE SIZE: Bump from 80 to 130
                        height: 160,
                        width: 160,
                        // 3. FORCE ZOOM: Scale zooms in to crop out white space/transparency
                        child: Transform.scale(
                          scale:
                              1.2, // Try 1.2, 1.3, or 1.5 until it fits perfectly
                          child: Image.asset(
                            'assets/images/logo.png',
                            fit: BoxFit
                                .cover, // Forces image to fill the available space
                            errorBuilder: (c, o, s) => const Icon(
                              Icons.shield,
                              size: 60,
                              color: Color(0xFF1B5E20),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    "Halal Logistics Portal",
                    style: TextStyle(
                      fontSize: 26,
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const Text(
                    "Secure Supply Chain Management",
                    style: TextStyle(fontSize: 14, color: Colors.white70),
                  ),
                  const SizedBox(height: 30),

                  // --- White Card Section ---
                  Card(
                    elevation: 10,
                    shadowColor: Colors.black45,
                    color: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(25),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(30.0),
                      child: Form(
                        key: _formKey,
                        child: Column(
                          children: [
                            const Text(
                              "Partner Sign In",
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF1B5E20),
                              ),
                            ),
                            const SizedBox(height: 25),

                            // Email
                            TextFormField(
                              controller: _emailController,
                              decoration: _inputDecoration(
                                "Corporate Email",
                                Icons.email_outlined,
                              ),
                              validator: (val) =>
                                  !val!.contains('@') ? 'Invalid Email' : null,
                            ),
                            const SizedBox(height: 15),

                            // Password
                            TextFormField(
                              controller: _passwordController,
                              obscureText: !_isPasswordVisible,
                              decoration: _inputDecoration(
                                "Password",
                                Icons.lock_outline,
                              ).copyWith(
                                suffixIcon: IconButton(
                                  icon: Icon(
                                    _isPasswordVisible
                                        ? Icons.visibility
                                        : Icons.visibility_off,
                                    color: Colors.grey,
                                  ),
                                  onPressed: () => setState(
                                    () => _isPasswordVisible =
                                        !_isPasswordVisible,
                                  ),
                                ),
                              ),
                              validator: (val) =>
                                  val!.isEmpty ? 'Enter password' : null,
                            ),
                            const SizedBox(height: 10),

                            // Remember Me & Forgot PW
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Row(
                                  children: [
                                    SizedBox(
                                      height: 24,
                                      width: 24,
                                      child: Checkbox(
                                        value: _rememberMe,
                                        activeColor: const Color(0xFF1B5E20),
                                        onChanged: (val) =>
                                            setState(() => _rememberMe = val!),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      "Remember Me",
                                      style: TextStyle(
                                          color: Colors.grey[700],
                                          fontSize: 13),
                                    ),
                                  ],
                                ),
                                TextButton(
                                  onPressed: () {
                                    if (mounted) {
                                      ScaffoldMessenger.of(context)
                                          .showSnackBar(
                                        const SnackBar(
                                          content: Text(
                                              "Feature in progress. Please contact Admin to reset password."),
                                          backgroundColor: Colors.grey,
                                          duration: Duration(seconds: 2),
                                        ),
                                      );
                                    }
                                  },
                                  child: Text(
                                    "Forgot Password?",
                                    style: TextStyle(
                                        color: Colors.grey[600], fontSize: 13),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 25),

                            // Login Button
                            SizedBox(
                              width: double.infinity,
                              height: 50,
                              child: ElevatedButton(
                                onPressed: _isLoading ? null : _handleLogin,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF1B5E20),
                                  foregroundColor: Colors.white,
                                  elevation: 2,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(15),
                                  ),
                                ),
                                child: _isLoading
                                    ? const SizedBox(
                                        height: 24,
                                        width: 24,
                                        child: CircularProgressIndicator(
                                          color: Colors.white,
                                          strokeWidth: 2,
                                        ),
                                      )
                                    : const Text(
                                        "SECURE LOGIN",
                                        style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 16),
                                      ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),

                  // --- Footer Links (Adapted for Green Background) ---
                  const SizedBox(height: 25),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text(
                        "New to the network? ",
                        style: TextStyle(color: Colors.white70),
                      ),
                      GestureDetector(
                        onTap: () => Navigator.pushNamed(context, '/register'),
                        child: const Text(
                          "Apply Here",
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            decoration: TextDecoration.underline,
                            decorationColor: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 15),
                  TextButton.icon(
                    onPressed: () =>
                        Navigator.pushNamed(context, '/dashboard/consumer'),
                    icon: const Icon(Icons.qr_code_scanner,
                        size: 20, color: Colors.white),
                    label: const Text(
                      "Public Traceability Check",
                      style: TextStyle(color: Colors.white),
                    ),
                    style: TextButton.styleFrom(
                      backgroundColor: Colors.white.withValues(alpha: 0.15),
                      padding: const EdgeInsets.symmetric(
                          vertical: 12, horizontal: 25),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(30),
                        side: BorderSide(
                            color: Colors.white.withValues(alpha: 0.3), width: 1),
                      ),
                    ),
                  ),
                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  InputDecoration _inputDecoration(String label, IconData icon) {
    return InputDecoration(
      labelText: label,
      labelStyle: TextStyle(color: Colors.grey[600], fontSize: 14),
      prefixIcon: Icon(icon, color: const Color(0xFF1B5E20), size: 22),
      filled: true,
      fillColor: Colors.grey[50],
      contentPadding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.grey[300]!, width: 1),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFF1B5E20), width: 2),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Colors.redAccent, width: 1),
      ),
    );
  }
}
