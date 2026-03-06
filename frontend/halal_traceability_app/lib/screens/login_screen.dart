import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:local_auth/local_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../config.dart';
import '../services/auth_session_service.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final LocalAuthentication _localAuth = LocalAuthentication();

  // Controllers
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  // State
  bool _isPasswordVisible = false;
  bool _isLoading = false;
  bool _rememberMe = false;
  bool _biometricEnabled = false;
  bool _biometricAvailable = false;

  static const int _maxFailedAttempts = 5;
  static const Duration _lockoutDuration = Duration(minutes: 5);
  int _failedAttempts = 0;
  DateTime? _lockoutUntil;
  Timer? _lockoutTimer;

  @override
  void dispose() {
    _lockoutTimer?.cancel();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _initializeLoginState();
  }

  Future<void> _initializeLoginState() async {
    await _loadSavedEmail();
    await _loadBiometricState();
    await _loadLockoutState();
  }

  Future<void> _loadSavedEmail() async {
    final rememberMe = await AuthSessionService.getRememberMe();
    final savedEmail = await AuthSessionService.getSavedEmail();

    if (!mounted) return;

    setState(() {
      _rememberMe = rememberMe;
      if (rememberMe && savedEmail != null) {
        _emailController.text = savedEmail;
      }
    });
  }

  Future<void> _loadBiometricState() async {
    bool isAvailable = false;
    try {
      final canCheck = await _localAuth.canCheckBiometrics;
      final isSupported = await _localAuth.isDeviceSupported();
      final enrolled = await _localAuth.getAvailableBiometrics();
      isAvailable = (canCheck || isSupported) && enrolled.isNotEmpty;
    } catch (_) {
      isAvailable = false;
    }

    final isEnabled = await AuthSessionService.isBiometricEnabled();

    if (!mounted) return;

    setState(() {
      _biometricAvailable = isAvailable;
      _biometricEnabled = isAvailable && isEnabled;
    });
  }

  Future<void> _loadLockoutState() async {
    final attempts = await AuthSessionService.getFailedAttempts();
    final lockoutUntil = await AuthSessionService.getLockoutUntil();

    if (!mounted) return;

    setState(() {
      _failedAttempts = attempts;
      _lockoutUntil = lockoutUntil;
    });

    if (_isLockedOut) {
      _startLockoutTicker();
    } else {
      await AuthSessionService.clearLockout();
    }
  }

  bool get _isLockedOut {
    if (_lockoutUntil == null) {
      return false;
    }
    return DateTime.now().isBefore(_lockoutUntil!);
  }

  String get _lockoutRemainingLabel {
    if (!_isLockedOut) return '';
    final diff = _lockoutUntil!.difference(DateTime.now());
    final minutes = diff.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = diff.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  void _startLockoutTicker() {
    _lockoutTimer?.cancel();
    _lockoutTimer = Timer.periodic(const Duration(seconds: 1), (_) async {
      if (!mounted) return;

      if (!_isLockedOut) {
        _lockoutTimer?.cancel();
        await AuthSessionService.clearLockout();
        if (mounted) {
          setState(() {
            _failedAttempts = 0;
            _lockoutUntil = null;
          });
        }
        return;
      }

      setState(() {});
    });
  }

  Future<void> _recordFailedAttempt() async {
    final attempts = _failedAttempts + 1;
    await AuthSessionService.setFailedAttempts(attempts);

    if (attempts >= _maxFailedAttempts) {
      final lockoutUntil = DateTime.now().add(_lockoutDuration);
      await AuthSessionService.setLockoutUntil(lockoutUntil);
      if (mounted) {
        setState(() {
          _failedAttempts = attempts;
          _lockoutUntil = lockoutUntil;
        });
      }
      _startLockoutTicker();
      return;
    }

    if (mounted) {
      setState(() => _failedAttempts = attempts);
    }
  }

  Future<void> _clearFailedAttempts() async {
    await AuthSessionService.clearLockout();
    if (mounted) {
      setState(() {
        _failedAttempts = 0;
        _lockoutUntil = null;
      });
    }
  }

  Future<void> _handleLogin() async {
    if (_isLockedOut) {
      _showError(
        'Too many failed attempts. Try again in $_lockoutRemainingLabel.',
      );
      return;
    }

    if (!_formKey.currentState!.validate()) {
      return;
    }

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
        final user = (data['user'] as Map).cast<String, dynamic>();
        final token = data['token'].toString();

        await AuthSessionService.saveLoginSession(token: token, user: user);
        await _saveRoleSpecificData(user);
        await AuthSessionService.setRememberMe(
          rememberMe: _rememberMe,
          email: _emailController.text,
        );

        if (_biometricAvailable) {
          await AuthSessionService.setBiometricEnabled(_biometricEnabled);
        } else {
          await AuthSessionService.setBiometricEnabled(false);
        }

        await _clearFailedAttempts();

        if (!mounted) return;

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Login Successful!'),
            backgroundColor: Colors.green,
          ),
        );

        await Future.delayed(const Duration(milliseconds: 500));
        if (!mounted) return;

        Navigator.pushReplacementNamed(
          context,
          _routeForRole((user['role'] ?? '').toString()),
        );
      } else {
        final errorData = jsonDecode(response.body);
        final message = (errorData['message'] ?? 'Login failed').toString();
        await _recordFailedAttempt();

        if (_isLockedOut) {
          _showError(
            'Account temporarily locked for $_lockoutRemainingLabel.',
          );
        } else {
          _showError(message);
        }
      }
    } catch (_) {
      _showError('Connection failed. Check server or internet.');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _saveRoleSpecificData(Map<String, dynamic> user) async {
    final prefs = await SharedPreferences.getInstance();
    final role = (user['role'] ?? '').toString();

    if (role == 'logistics' && user['logistics_profile'] != null) {
      final profile = (user['logistics_profile'] as Map).cast<String, dynamic>();
      await prefs.setString(
        'vehicle_plate',
        (profile['vehicle_plate_no'] ?? '').toString(),
      );
      await prefs.setString(
        'license_no',
        (profile['driver_license_no'] ?? '').toString(),
      );
      return;
    }

    if (role == 'processor' && user['processor_profile'] != null) {
      final profile = (user['processor_profile'] as Map).cast<String, dynamic>();
      await prefs.setString(
        'company_reg',
        (profile['company_reg_no'] ?? '').toString(),
      );
      await prefs.setString(
        'halal_cert',
        (profile['halal_cert_no'] ?? '').toString(),
      );
      return;
    }

    if (role == 'retailer' && user['retailer_profile'] != null) {
      final profile = (user['retailer_profile'] as Map).cast<String, dynamic>();
      await prefs.setString('store_name', (profile['store_name'] ?? '').toString());
    }
  }

  String _routeForRole(String role) {
    if (role == 'processor') {
      return '/dashboard/processor';
    }
    if (role == 'logistics') {
      return '/dashboard/logistics';
    }
    if (role == 'retailer') {
      return '/dashboard/retailer';
    }
    if (role == 'admin') {
      return '/dashboard/admin';
    }
    if (role == 'consumer') {
      return '/dashboard/consumer';
    }
    return '/login';
  }

  Future<Map<String, dynamic>?> _fetchUserWithToken(String token) async {
    final response = await http.get(
      Uri.parse('$baseUrl/user'),
      headers: {'Authorization': 'Bearer $token', 'Accept': 'application/json'},
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      final user = (data['user'] as Map?)?.cast<String, dynamic>();
      return user;
    }

    if (response.statusCode == 401 || response.statusCode == 403) {
      await AuthSessionService.clearAuthSession();
      await AuthSessionService.setBiometricEnabled(false);
    }

    return null;
  }

  Future<void> _handleBiometricLogin() async {
    if (_isLockedOut) {
      _showError(
        'Account temporarily locked for $_lockoutRemainingLabel.',
      );
      return;
    }

    if (!_biometricAvailable) {
      _showError('Biometric authentication is not available on this device.');
      return;
    }

    try {
      final didAuthenticate = await _localAuth.authenticate(
        localizedReason: 'Authenticate to sign in securely',
        biometricOnly: true,
        persistAcrossBackgrounding: true,
      );

      if (!didAuthenticate) {
        return;
      }

      if (mounted) {
        setState(() => _isLoading = true);
      }

      final token = await AuthSessionService.getSecureToken();
      if (token == null) {
        _showError('Please login with password once before using biometrics.');
        return;
      }

      final user = await _fetchUserWithToken(token);
      if (user == null) {
        _showError('Saved session expired. Please sign in with password.');
        return;
      }

      await AuthSessionService.saveLoginSession(token: token, user: user);
      await _saveRoleSpecificData(user);
      await _clearFailedAttempts();

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Biometric login successful.'),
          backgroundColor: Colors.green,
        ),
      );
      Navigator.pushReplacementNamed(
        context,
        _routeForRole((user['role'] ?? '').toString()),
      );
    } on LocalAuthException catch (e) {
      _showError('Biometric error: ${e.description ?? e.code.name}');
    } catch (_) {
      _showError('Biometric login failed. Please try password login.');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _requestPasswordReset(String email) async {
    final response = await http.post(
      Uri.parse('$apiBaseUrl/forgot-password'),
      headers: {'Accept': 'application/json'},
      body: {'email': email.trim()},
    );

    String message = 'If this email exists, a reset link has been sent.';
    try {
      final data = jsonDecode(response.body);
      if (data['message'] != null) {
        message = data['message'].toString();
      }
    } catch (_) {}

    if (!mounted) return;

    if (response.statusCode == 200) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } else {
      _showError(message);
    }
  }

  void _showForgotPasswordDialog() {
    final controller = TextEditingController(text: _emailController.text.trim());

    showDialog<void>(
      context: context,
      builder: (context) {
        bool submitting = false;

        return StatefulBuilder(
          builder: (context, setStateDialog) {
            return AlertDialog(
              title: const Text('Reset Password'),
              content: TextField(
                controller: controller,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(
                  labelText: 'Corporate Email',
                  hintText: 'name@company.com',
                ),
              ),
              actions: [
                TextButton(
                  onPressed: submitting ? null : () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: submitting
                      ? null
                      : () async {
                          final email = controller.text.trim();
                          if (!email.contains('@')) {
                            _showError('Please enter a valid email address.');
                            return;
                          }

                          setStateDialog(() => submitting = true);
                          try {
                            await _requestPasswordReset(email);
                            if (context.mounted) {
                              Navigator.pop(context);
                            }
                          } catch (_) {
                            _showError(
                              'Unable to process reset now. Please contact Admin.',
                            );
                          } finally {
                            if (mounted) {
                              setStateDialog(() => submitting = false);
                            }
                          }
                        },
                  child: submitting
                      ? const SizedBox(
                          height: 16,
                          width: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Send Link'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _onBiometricToggle(bool value) {
    if (!_biometricAvailable) {
      _showError('Biometric authentication is not available on this device.');
      return;
    }
    setState(() => _biometricEnabled = value);
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
                color: Colors.white
                    .withValues(alpha: 0.05), // Subtle transparent white
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

                            if (_isLockedOut)
                              Container(
                                width: double.infinity,
                                margin: const EdgeInsets.only(bottom: 8),
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: Colors.orange[50],
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(color: Colors.orange),
                                ),
                                child: Text(
                                  'Too many failed attempts. Try again in '
                                  '$_lockoutRemainingLabel.',
                                  style: TextStyle(
                                    color: Colors.orange[900],
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),

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
                                  onPressed: _showForgotPasswordDialog,
                                  child: Text(
                                    "Forgot Password?",
                                    style: TextStyle(
                                        color: Colors.grey[600], fontSize: 13),
                                  ),
                                ),
                              ],
                            ),
                            if (_biometricAvailable)
                              SwitchListTile(
                                dense: true,
                                contentPadding: EdgeInsets.zero,
                                activeThumbColor: const Color(0xFF1B5E20),
                                title: Text(
                                  'Enable Biometric Login',
                                  style: TextStyle(
                                    color: Colors.grey[700],
                                    fontSize: 13,
                                  ),
                                ),
                                value: _biometricEnabled,
                                onChanged: _onBiometricToggle,
                              ),
                            const SizedBox(height: 25),

                            // Login Button
                            SizedBox(
                              width: double.infinity,
                              height: 50,
                              child: ElevatedButton(
                                onPressed: (_isLoading || _isLockedOut)
                                    ? null
                                    : _handleLogin,
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
                                    : Text(
                                        _isLockedOut
                                            ? "LOCKED ($_lockoutRemainingLabel)"
                                            : "SECURE LOGIN",
                                        style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 16),
                                      ),
                              ),
                            ),
                            if (_biometricAvailable && _biometricEnabled) ...[
                              const SizedBox(height: 12),
                              SizedBox(
                                width: double.infinity,
                                height: 48,
                                child: OutlinedButton.icon(
                                  onPressed: _isLoading ? null : _handleBiometricLogin,
                                  icon: const Icon(Icons.fingerprint),
                                  label: const Text('LOGIN WITH BIOMETRICS'),
                                ),
                              ),
                            ],
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
                            color: Colors.white.withValues(alpha: 0.3),
                            width: 1),
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
