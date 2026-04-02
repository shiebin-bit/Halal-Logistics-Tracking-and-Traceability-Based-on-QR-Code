import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../config.dart';
import '../services/auth_session_service.dart';

class EmailVerificationScreen extends StatefulWidget {
  const EmailVerificationScreen({super.key});

  @override
  State<EmailVerificationScreen> createState() => _EmailVerificationScreenState();
}

class _EmailVerificationScreenState extends State<EmailVerificationScreen> {
  final _codeController = TextEditingController();
  final _emailController = TextEditingController();
  bool _isSubmitting = false;
  bool _isResending = false;
  String? _debugCode;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final args =
        ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
    if (args == null) return;

    final email = (args['email'] ?? '').toString();
    if (email.isNotEmpty && _emailController.text.isEmpty) {
      _emailController.text = email;
    }

    final debugCode = args['debug_code']?.toString();
    if (debugCode != null && debugCode.isNotEmpty && _debugCode == null) {
      _debugCode = debugCode;
    }
  }

  @override
  void dispose() {
    _codeController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _verifyCode() async {
    if (_emailController.text.trim().isEmpty || _codeController.text.trim().length != 6) {
      _showMessage('Enter your email and the 6-digit code.', isError: true);
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final response = await http.post(
        Uri.parse('$apiBaseUrl/verify-email-code'),
        headers: {'Accept': 'application/json'},
        body: {
          'email': _emailController.text.trim(),
          'code': _codeController.text.trim(),
        },
      );

      final Map<String, dynamic> data = jsonDecode(response.body);
      if (!mounted) return;

      if (response.statusCode == 200) {
        final token = (data['token'] ?? '').toString();
        final user = (data['user'] as Map?)?.cast<String, dynamic>();

        if (token.isNotEmpty && user != null) {
          await AuthSessionService.saveLoginSession(token: token, user: user);
        }

        _showMessage((data['message'] ?? 'Email verified successfully.').toString());

        await Future.delayed(const Duration(milliseconds: 800));
        if (!mounted) return;

        if (token.isNotEmpty && user != null) {
          Navigator.pushNamedAndRemoveUntil(
            context,
            _routeForRole((user['role'] ?? '').toString()),
            (route) => false,
          );
          return;
        }

        Navigator.pushNamedAndRemoveUntil(context, '/login', (route) => false);
        return;
      }

      _showMessage((data['message'] ?? 'Verification failed.').toString(), isError: true);
    } catch (_) {
      _showMessage('Connection error. Please try again.', isError: true);
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  Future<void> _resendCode() async {
    if (_emailController.text.trim().isEmpty) {
      _showMessage('Enter your email first.', isError: true);
      return;
    }

    setState(() => _isResending = true);
    try {
      final response = await http.post(
        Uri.parse('$apiBaseUrl/resend-email-code'),
        headers: {'Accept': 'application/json'},
        body: {'email': _emailController.text.trim()},
      );

      final Map<String, dynamic> data = jsonDecode(response.body);
      if (!mounted) return;

      setState(() {
        final code = data['verification_code_debug']?.toString();
        if (code != null && code.isNotEmpty) {
          _debugCode = code;
        }
      });

      _showMessage((data['message'] ?? 'A new code was issued.').toString());
    } catch (_) {
      _showMessage('Unable to resend the code right now.', isError: true);
    } finally {
      if (mounted) setState(() => _isResending = false);
    }
  }

  String _routeForRole(String role) {
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
        return '/dashboard/consumer';
    }
  }

  void _showMessage(String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red[700] : Colors.green,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          Container(
            height: double.infinity,
            width: double.infinity,
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF1B5E20), Color(0xFF43A047)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
          ),
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Card(
                  elevation: 10,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const Icon(Icons.mark_email_read_rounded,
                            size: 64, color: Color(0xFF1B5E20)),
                        const SizedBox(height: 16),
                        const Text(
                          'Verify Your Email',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Enter the 6-digit code sent to your email address.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.grey[600]),
                        ),
                        const SizedBox(height: 24),
                        TextField(
                          controller: _emailController,
                          keyboardType: TextInputType.emailAddress,
                          decoration: const InputDecoration(
                            labelText: 'Email Address',
                            prefixIcon: Icon(Icons.alternate_email_rounded),
                          ),
                        ),
                        const SizedBox(height: 16),
                        TextField(
                          controller: _codeController,
                          keyboardType: TextInputType.number,
                          maxLength: 6,
                          decoration: const InputDecoration(
                            labelText: 'Verification Code',
                            prefixIcon: Icon(Icons.pin_rounded),
                            counterText: '',
                          ),
                        ),
                        if (_debugCode != null) ...[
                          const SizedBox(height: 16),
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.orange[50],
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.orange.shade200),
                            ),
                            child: Text(
                              'Local testing code: $_debugCode',
                              style: TextStyle(
                                color: Colors.orange[900],
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                        const SizedBox(height: 24),
                        ElevatedButton.icon(
                          onPressed: _isSubmitting ? null : _verifyCode,
                          icon: _isSubmitting
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Icon(Icons.verified_rounded),
                          label: Text(_isSubmitting ? 'Verifying...' : 'VERIFY EMAIL'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF1B5E20),
                            foregroundColor: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextButton(
                          onPressed: _isResending ? null : _resendCode,
                          child: Text(_isResending ? 'Resending...' : 'Resend Code'),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
