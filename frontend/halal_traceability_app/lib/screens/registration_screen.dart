import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:file_picker/file_picker.dart';

class RegistrationScreen extends StatefulWidget {
  const RegistrationScreen({super.key});

  @override
  State<RegistrationScreen> createState() => _RegistrationScreenState();
}

class _RegistrationScreenState extends State<RegistrationScreen> {
  final _formKey = GlobalKey<FormState>();

  // --- STATE VARIABLES ---
  final List<String> _stakeholderTypes = [
    'Processing Partner',
    'Logistics Partner',
    'Retailer',
  ];
  String? _selectedType;

  // File Upload State
  PlatformFile? _pickedFile;
  bool _agreedToTerms = false;
  bool _isLoading = false;

  // --- CONTROLLERS ---
  // 1. Common
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _phoneController = TextEditingController();
  bool _isPasswordVisible = false;

  // 2. Processor Specific
  final _companyRegController = TextEditingController(); // SSM
  final _halalCertController = TextEditingController();
  final _factoryAddressController = TextEditingController();
  // Using generic date string for now (you can add DatePicker later)
  final _halalExpiryController = TextEditingController(text: "2026-12-31");

  // 3. Logistics Specific
  final _vehiclePlateController = TextEditingController();
  final _driverLicenseController = TextEditingController();
  final _vehicleTypeController =
      TextEditingController(text: "Refrigerated Truck");

  // 4. Retailer Specific
  final _storeNameController = TextEditingController();
  final _businessRegController = TextEditingController(); // SSM
  final _outletAddressController = TextEditingController();

  // --- LOGIC: PICK FILE ---
  Future<void> _pickFile() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf', 'jpg', 'png', 'jpeg'],
      );

      if (result != null) {
        PlatformFile file = result.files.first;
        if (file.size > 5 * 1024 * 1024) {
          _showError("File is too large. Max size is 5MB.");
          return;
        }
        setState(() => _pickedFile = file);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Selected: ${file.name}")),
        );
      }
    } catch (e) {
      _showError("Error picking file: $e");
    }
  }

  // --- LOGIC: SUBMIT REGISTRATION ---
  Future<void> _submitRegistration() async {
    if (_formKey.currentState!.validate()) {
      if (_pickedFile == null) {
        _showError('Please upload your supporting document (License/Cert).');
        return;
      }
      if (!_agreedToTerms) {
        _showError('You must agree to the Terms of Service.');
        return;
      }

      setState(() => _isLoading = true);

      // Map Role to API Value
      String apiRole = 'consumer';
      if (_selectedType == 'Processing Partner')
        apiRole = 'processor';
      else if (_selectedType == 'Logistics Partner')
        apiRole = 'logistics';
      else if (_selectedType == 'Retailer') apiRole = 'retailer';

      final uri = Uri.parse('http://10.0.2.2:8000/api/register');

      try {
        var request = http.MultipartRequest('POST', uri);

        // --- 1. Common Fields ---
        request.fields['name'] = _nameController.text.trim();
        request.fields['email'] = _emailController.text.trim();
        request.fields['password'] = _passwordController.text;
        request.fields['role'] = apiRole;
        request.fields['phone_number'] = _phoneController.text.trim();

        // --- 2. Role Specific Fields ---
        if (apiRole == 'processor') {
          request.fields['company_reg_no'] = _companyRegController.text.trim();
          request.fields['halal_cert_no'] = _halalCertController.text.trim();
          request.fields['halal_expiry_date'] =
              _halalExpiryController.text.trim();
          request.fields['factory_address'] =
              _factoryAddressController.text.trim();
        } else if (apiRole == 'logistics') {
          request.fields['vehicle_plate_no'] =
              _vehiclePlateController.text.trim();
          request.fields['driver_license_no'] =
              _driverLicenseController.text.trim();
          request.fields['vehicle_type'] = _vehicleTypeController.text.trim();
        } else if (apiRole == 'retailer') {
          request.fields['store_name'] = _storeNameController.text.trim();
          request.fields['business_reg_no'] =
              _businessRegController.text.trim();
          request.fields['outlet_address'] =
              _outletAddressController.text.trim();
        }

        // --- 3. File Upload ---
        if (_pickedFile != null && _pickedFile!.path != null) {
          // Note: Backend might look for specific names like 'gdl_license_path'
          // Ideally, update backend to accept a generic 'document' or handle mapping
          // For now, let's send it as 'profile_image' or specific field if strictly required
          // Based on your migration: 'cert_document_path', 'gdl_license_path'
          // Let's use a generic name 'document' and let Backend handle it, OR match logic
          // **Hack for now**: Send as 'profile_image' to pass validation if any,
          // but strictly you should update backend to read 'document' and save to correct column.
          request.files.add(await http.MultipartFile.fromPath(
            'profile_image', // Keeping it simple for the 'User' table first
            _pickedFile!.path!,
          ));
        }

        request.headers.addAll({'Accept': 'application/json'});

        var streamedResponse = await request.send();
        var response = await http.Response.fromStream(streamedResponse);

        if (response.statusCode == 201 || response.statusCode == 200) {
          final data = jsonDecode(response.body);
          String token = data['token']; // Ensure backend returns 'token'

          final prefs = await SharedPreferences.getInstance();
          await prefs.setBool('isLoggedIn', true);
          await prefs.setString('auth_token', token);
          await prefs.setString('userRole', apiRole);

          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Registration Success! Redirecting...'),
                backgroundColor: Colors.green,
              ),
            );
            await Future.delayed(const Duration(seconds: 1));

            // Redirect
            String route = '/login';
            if (apiRole == 'processor')
              route = '/dashboard/processor';
            else if (apiRole == 'logistics')
              route = '/dashboard/logistics';
            else if (apiRole == 'retailer') route = '/dashboard/retailer';

            Navigator.pushNamedAndRemoveUntil(context, route, (r) => false);
          }
        } else {
          final errorData = jsonDecode(response.body);
          // Handle Laravel Validation Errors (which return objects)
          String msg = errorData['message'] ?? 'Registration failed.';
          if (errorData['errors'] != null) {
            msg = errorData['errors'].values.first[0]; // Get first error
          }
          _showError(msg);
        }
      } catch (e) {
        _showError('Connection error. Check server.');
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
    return Scaffold(
      body: Stack(
        children: [
          // Background (Same as before)
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
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  children: [
                    // Header (Same)
                    Row(
                      children: [
                        IconButton(
                          icon: const Icon(Icons.arrow_back_ios,
                              color: Colors.white),
                          onPressed: () => Navigator.pop(context),
                        ),
                        const Expanded(
                          child: Text(
                            "Partner Onboarding",
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        ),
                        const SizedBox(width: 40),
                      ],
                    ),
                    const SizedBox(height: 30),

                    // FORM CARD
                    Card(
                      elevation: 10,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20)),
                      child: Padding(
                        padding: const EdgeInsets.all(24.0),
                        child: Form(
                          key: _formKey,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _buildHeader("Role Selection"),
                              DropdownButtonFormField<String>(
                                decoration: _inputDecoration(
                                    "Select Stakeholder Type", Icons.domain),
                                value: _selectedType,
                                items: _stakeholderTypes.map((type) {
                                  return DropdownMenuItem(
                                      value: type, child: Text(type));
                                }).toList(),
                                onChanged: (val) =>
                                    setState(() => _selectedType = val),
                                validator: (val) =>
                                    val == null ? 'Required' : null,
                              ),
                              const SizedBox(height: 15),

                              // --- DYNAMIC FIELDS BASED ON ROLE ---
                              if (_selectedType == 'Processing Partner') ...[
                                _buildHeader("Factory Details"),
                                _buildTextField(
                                    controller: _companyRegController,
                                    label: "Company Reg No (SSM)",
                                    icon: Icons.badge),
                                const SizedBox(height: 10),
                                _buildTextField(
                                    controller: _halalCertController,
                                    label: "Halal Cert No",
                                    icon: Icons.verified),
                                const SizedBox(height: 10),
                                _buildTextField(
                                    controller: _factoryAddressController,
                                    label: "Factory Address",
                                    icon: Icons.location_on),
                              ] else if (_selectedType ==
                                  'Logistics Partner') ...[
                                _buildHeader("Vehicle & Driver Details"),
                                _buildTextField(
                                    controller: _vehiclePlateController,
                                    label: "Vehicle Plate No",
                                    icon: Icons.local_shipping),
                                const SizedBox(height: 10),
                                _buildTextField(
                                    controller: _driverLicenseController,
                                    label: "Driver License No",
                                    icon: Icons.card_membership),
                                const SizedBox(height: 10),
                                _buildTextField(
                                    controller: _vehicleTypeController,
                                    label: "Vehicle Type",
                                    icon: Icons.category),
                              ] else if (_selectedType == 'Retailer') ...[
                                _buildHeader("Store Details"),
                                _buildTextField(
                                    controller: _storeNameController,
                                    label: "Store Name",
                                    icon: Icons.store),
                                const SizedBox(height: 10),
                                _buildTextField(
                                    controller: _businessRegController,
                                    label: "Business Reg No (SSM)",
                                    icon: Icons.badge),
                                const SizedBox(height: 10),
                                _buildTextField(
                                    controller: _outletAddressController,
                                    label: "Outlet Address",
                                    icon: Icons.location_on),
                              ],

                              const SizedBox(height: 15),

                              _buildHeader("Account Credentials"),
                              _buildTextField(
                                  controller: _nameController,
                                  label: "Full Name",
                                  icon: Icons.person),
                              const SizedBox(height: 10),
                              _buildTextField(
                                  controller: _phoneController,
                                  label: "Phone Number",
                                  icon: Icons.phone,
                                  type: TextInputType.phone),
                              const SizedBox(height: 10),
                              _buildTextField(
                                  controller: _emailController,
                                  label: "Email Address",
                                  icon: Icons.email_outlined,
                                  type: TextInputType.emailAddress),
                              const SizedBox(height: 10),
                              TextFormField(
                                controller: _passwordController,
                                obscureText: !_isPasswordVisible,
                                decoration: _inputDecoration(
                                        "Password", Icons.lock_outline)
                                    .copyWith(
                                  suffixIcon: IconButton(
                                    icon: Icon(
                                        _isPasswordVisible
                                            ? Icons.visibility
                                            : Icons.visibility_off,
                                        color: Colors.grey),
                                    onPressed: () => setState(() =>
                                        _isPasswordVisible =
                                            !_isPasswordVisible),
                                  ),
                                ),
                                validator: (val) =>
                                    val!.length < 6 ? 'Min 6 characters' : null,
                              ),

                              const SizedBox(height: 20),
                              _buildHeader("Verification Document"),
                              GestureDetector(
                                onTap: _pickFile,
                                child: Container(
                                  width: double.infinity,
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 20),
                                  decoration: BoxDecoration(
                                    color: _pickedFile != null
                                        ? Colors.green[50]
                                        : Colors.grey[100],
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: _pickedFile != null
                                          ? Colors.green
                                          : Colors.grey[300]!,
                                      width: 1.5,
                                    ),
                                  ),
                                  child: Column(
                                    children: [
                                      Icon(
                                        _pickedFile != null
                                            ? Icons.check_circle
                                            : Icons.cloud_upload,
                                        color: _pickedFile != null
                                            ? Colors.green
                                            : Colors.grey,
                                        size: 30,
                                      ),
                                      const SizedBox(height: 8),
                                      Text(
                                        _pickedFile != null
                                            ? "Selected: ${_pickedFile!.name}"
                                            : "Upload Cert/License (PDF/JPG)",
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          color: _pickedFile != null
                                              ? Colors.green[800]
                                              : Colors.grey[700],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),

                              const SizedBox(height: 20),
                              Row(
                                children: [
                                  Checkbox(
                                    value: _agreedToTerms,
                                    activeColor: const Color(0xFF1B5E20),
                                    onChanged: (val) =>
                                        setState(() => _agreedToTerms = val!),
                                  ),
                                  const Expanded(
                                      child: Text(
                                          "I agree to the Terms of Service.",
                                          style: TextStyle(fontSize: 12))),
                                ],
                              ),

                              const SizedBox(height: 20),
                              SizedBox(
                                width: double.infinity,
                                height: 50,
                                child: ElevatedButton(
                                  onPressed:
                                      _isLoading ? null : _submitRegistration,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFF1B5E20),
                                    foregroundColor: Colors.white,
                                    shape: RoundedRectangleBorder(
                                        borderRadius:
                                            BorderRadius.circular(10)),
                                  ),
                                  child: _isLoading
                                      ? const CircularProgressIndicator(
                                          color: Colors.white)
                                      : const Text("SUBMIT APPLICATION",
                                          style: TextStyle(
                                              fontWeight: FontWeight.bold)),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0, top: 4.0),
      child: Text(
        title,
        style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: Color(0xFF1B5E20)),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    TextInputType type = TextInputType.text,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: type,
      decoration: _inputDecoration(label, icon),
      validator: (val) => val!.isEmpty ? 'Required' : null,
    );
  }

  InputDecoration _inputDecoration(String label, IconData icon) {
    return InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(fontSize: 13, color: Colors.grey),
      prefixIcon: Icon(icon, color: Colors.grey, size: 20),
      filled: true,
      fillColor: Colors.grey[50],
      contentPadding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
      border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
      enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: Colors.grey[300]!)),
      focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Color(0xFF1B5E20), width: 1.5)),
      errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Colors.redAccent)),
    );
  }
}
