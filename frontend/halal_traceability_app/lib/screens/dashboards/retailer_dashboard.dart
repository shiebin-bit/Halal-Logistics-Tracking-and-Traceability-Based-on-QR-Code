import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:image_picker/image_picker.dart';
import 'package:url_launcher/url_launcher.dart';
import 'logistics_dashboard.dart'; // Imports SimpleScannerPage

import '../../config.dart';

class RetailerDashboard extends StatefulWidget {
  const RetailerDashboard({super.key});

  @override
  State<RetailerDashboard> createState() => _RetailerDashboardState();
}

class _RetailerDashboardState extends State<RetailerDashboard> {
  int _selectedIndex = 0; // 0: Incoming, 1: Scan, 2: Inventory, 3: Reports

  // --- STATE DATA ---
  bool _isLoading = false;
  Map<String, dynamic>? _scannedBatch;
  List<dynamic> _inventory = [];
  List<dynamic> _incomingShipments = [];

  // --- USER DATA ---
  Map<String, dynamic> _userData = {
    "name": "Loading...",
    "email": "...",
    "phone": "...",
    "profile_image": null,
    "retailer_profile": {
      "store_name": "Loading...",
      "business_reg_no": "...",
      "outlet_address": "..."
    }
  };

  // Quality Check State
  bool _checkPackaging = false;
  bool _checkSeal = false;
  bool _checkTemp = false;

  @override
  void initState() {
    super.initState();
    _fetchInventory();
    _fetchIncoming();
    _fetchUserProfile();
  }

  // --- API FUNCTIONS ---
  Future<void> _fetchUserProfile() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('auth_token');
      final response = await http.get(
        Uri.parse('$baseUrl/user'),
        headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'application/json'
        },
      );
      if (!mounted) return;
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() {
          _userData = data['user'] ?? {};
          if (_userData['retailer_profile'] == null) {
            _userData['retailer_profile'] = {};
          }
        });
      }
    } catch (e) {
      debugPrint("Error fetching profile: $e");
    }
  }

  Future<void> _fetchInventory() async {
    setState(() => _isLoading = true);
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('auth_token');
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/batches'),
        headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'application/json'
        },
      );
      if (!mounted) return;
      if (response.statusCode == 200) {
        setState(() {
          _inventory = jsonDecode(response.body)['data'];
          _isLoading = false;
        });
      } else {
        setState(() => _isLoading = false);
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _fetchIncoming() async {
    // Don't show loading spinner for this background fetch if main list is loaded
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('auth_token');
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/batches?status=incoming'),
        headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'application/json'
        },
      );
      if (!mounted) return;
      if (response.statusCode == 200) {
        setState(() {
          _incomingShipments = jsonDecode(response.body)['data'];
        });
      }
    } catch (e) {
      debugPrint("Error fetching incoming: $e");
    }
  }

  Future<void> _processAcceptance() async {
    if (!_checkPackaging || !_checkSeal || !_checkTemp) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text("Error: All Physical Checks must be passed.")));
      return;
    }
    setState(() => _isLoading = true);
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('auth_token');
      final response = await http.post(
        Uri.parse('$baseUrl/logistics/checkpoint'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
          'Accept': 'application/json'
        },
        body: jsonEncode({
          'batch_id': _scannedBatch!['batch_id'],
          'temperature': '-18.0',
          'location': _userData['retailer_profile']?['outlet_address'] ??
              "Retail Outlet",
          'notes': "Accepted by Retailer. Quality Checks Passed."
        }),
      );
      if (!mounted) return;
      if (response.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text("Success: Ownership Transferred to Store!"),
            backgroundColor: Colors.green));
        setState(() {
          _scannedBatch = null;
          _checkPackaging = false;
          _checkSeal = false;
          _checkTemp = false;
          _selectedIndex = 2; // Move to Inventory
        });
        _fetchInventory();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text("Failed to accept batch"),
            backgroundColor: Colors.red));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text("Connection Error")));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // --- REPORTING LOGIC ---
  void _showIncidentDialog({String? prefillBatchId}) {
    final descriptionController = TextEditingController();
    final batchIdController = TextEditingController(text: prefillBatchId ?? "");
    String issueType = 'Spoilage';

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Report Issue", style: TextStyle(color: Colors.red)),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text("Report damaged or non-halal goods to Admin."),
              const SizedBox(height: 15),
              // If we are scanning, this is read-only. If from drawer, it's editable.
              TextField(
                controller: batchIdController,
                readOnly: prefillBatchId != null,
                decoration: const InputDecoration(
                  labelText: "Batch ID",
                  border: OutlineInputBorder(),
                  filled: true,
                ),
              ),
              const SizedBox(height: 10),
              DropdownButtonFormField<String>(
                value: issueType,
                items: ['Spoilage', 'Broken Seal', 'Wrong Item', 'Other']
                    .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                    .toList(),
                onChanged: (v) => issueType = v!,
                decoration: const InputDecoration(
                    labelText: "Issue Type", border: OutlineInputBorder()),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: descriptionController,
                maxLines: 3,
                decoration: const InputDecoration(
                    labelText: "Details / Notes", border: OutlineInputBorder()),
              )
            ],
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Cancel")),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () {
              Navigator.pop(context);
              if (batchIdController.text.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text("Batch ID is required")));
                return;
              }
              _submitIncident(batchIdController.text, issueType,
                  descriptionController.text);
            },
            child: const Text("SUBMIT REPORT",
                style: TextStyle(color: Colors.white)),
          )
        ],
      ),
    );
  }

  Future<void> _submitIncident(
      String batchId, String type, String description) async {
    setState(() => _isLoading = true);
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('auth_token');

      await http.post(
        Uri.parse('$baseUrl/logistics/incident'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
          'Accept': 'application/json'
        },
        body: jsonEncode({
          "batch_id": batchId,
          "issue_type": type,
          "description": description,
          "location":
              _userData['retailer_profile']?['outlet_address'] ?? "Retail Store"
        }),
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Incident Reported to Admin")));
        // Clear scan state if we were scanning
        if (_scannedBatch != null) {
          setState(() => _scannedBatch = null);
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text("Connection Error")));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _makePhoneCall(String phoneNumber) async {
    final Uri launchUri = Uri(scheme: 'tel', path: phoneNumber);
    if (await canLaunchUrl(launchUri)) {
      await launchUrl(launchUri);
    }
  }

  // --- ACTIONS ---
  Future<void> _logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
    if (mounted) {
      Navigator.pushNamedAndRemoveUntil(context, '/login', (route) => false);
    }
  }

  Future<void> _scanQR() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const SimpleScannerPage()),
    );

    if (result != null) {
      setState(() {
        _scannedBatch = {
          "batch_id": result,
          "product": "Incoming Shipment",
          "origin": "Processing Factory",
          "avg_temp": "-18.5°C",
          "freshness_score": 98,
        };
      });
    }
  }

  // --- UI BUILDERS ---

  Widget _buildDrawer() {
    ImageProvider? drawerImage;
    if (_userData['profile_image'] != null) {
      drawerImage = NetworkImage("$storageUrl${_userData['profile_image']}");
    }
    String storeName =
        _userData['retailer_profile']?['store_name'] ?? 'Fresh Mart';

    return Drawer(
      child: Column(
        children: [
          UserAccountsDrawerHeader(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFFE65100), Color(0xFFEF6C00)],
              ),
            ),
            accountName: Text(storeName,
                style:
                    const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
            accountEmail: Text(_userData['name'] ?? "Manager"),
            currentAccountPicture: CircleAvatar(
              backgroundColor: Colors.white,
              backgroundImage: drawerImage,
              child: drawerImage == null
                  ? const Icon(Icons.store, size: 35, color: Color(0xFFE65100))
                  : null,
            ),
          ),
          ListTile(
            leading: const Icon(Icons.local_shipping, color: Colors.orange),
            title: const Text("Incoming Shipments"),
            selected: _selectedIndex == 0,
            onTap: () {
              setState(() => _selectedIndex = 0);
              Navigator.pop(context);
            },
          ),
          ListTile(
            leading: const Icon(Icons.qr_code_scanner, color: Colors.orange),
            title: const Text("Scan & Verify"),
            selected: _selectedIndex == 1,
            onTap: () {
              setState(() => _selectedIndex = 1);
              Navigator.pop(context);
            },
          ),
          ListTile(
            leading: const Icon(Icons.inventory, color: Colors.orange),
            title: const Text("Store Inventory"),
            selected: _selectedIndex == 2,
            onTap: () {
              setState(() => _selectedIndex = 2);
              Navigator.pop(context);
            },
          ),
          // --- NEW: REPORT ISSUE IN DRAWER ---
          ListTile(
            leading: const Icon(Icons.report_problem, color: Colors.red),
            title: const Text("Report Issue"),
            selected: _selectedIndex == 3,
            onTap: () {
              setState(() => _selectedIndex = 3);
              Navigator.pop(context);
            },
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.person, color: Colors.black),
            title: const Text("Store Profile"),
            onTap: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => RetailerProfileScreen(
                      userData: _userData, onProfileUpdate: _fetchUserProfile),
                ),
              );
            },
          ),
          const Spacer(),
          ListTile(
            leading: const Icon(Icons.logout, color: Colors.red),
            title: const Text("Secure Logout",
                style: TextStyle(color: Colors.red)),
            onTap: _logout,
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  // --- 1. INCOMING VIEW ---
  Widget _buildIncomingView() {
    if (_isLoading) return const Center(child: CircularProgressIndicator());
    if (_incomingShipments.isEmpty) {
      return const Center(child: Text("No shipments currently on the way."));
    }
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildStatCard("Pending Arrival",
              "${_incomingShipments.length} Batches", Colors.orange),
          const SizedBox(height: 20),
          const Text("In Transit",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 10),
          Expanded(
            child: ListView.builder(
              itemCount: _incomingShipments.length,
              itemBuilder: (context, index) {
                final shipment = _incomingShipments[index];
                return Card(
                  elevation: 2,
                  margin: const EdgeInsets.only(bottom: 12),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                  child: ListTile(
                    leading: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                          color: Colors.orange[50],
                          borderRadius: BorderRadius.circular(8)),
                      child: const Icon(Icons.local_shipping,
                          color: Colors.orange),
                    ),
                    title: Text("Batch: ${shipment['batch_id']}",
                        style: const TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: Text(
                        "${shipment['product_type']} (${shipment['weight']})\nFarm: ${shipment['origin_farm']}"),
                    trailing: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.blue[50],
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(shipment['status'],
                          style: const TextStyle(
                              color: Colors.blue,
                              fontWeight: FontWeight.bold,
                              fontSize: 10)),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  // --- 2. SCANNER VIEW ---
  Widget _buildScannerView() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (_scannedBatch == null)
            GestureDetector(
              onTap: _scanQR,
              child: Container(
                height: 200,
                decoration: BoxDecoration(
                  color: Colors.black87,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.orange, width: 2),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: const [
                    Icon(Icons.qr_code_scanner, size: 60, color: Colors.white),
                    SizedBox(height: 15),
                    Text("Tap to Scan Incoming Box",
                        style: TextStyle(color: Colors.white70)),
                  ],
                ),
              ),
            ),
          if (_scannedBatch != null) ...[
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: const [
                  BoxShadow(color: Colors.black12, blurRadius: 10)
                ],
                border:
                    Border.all(color: const Color.fromRGBO(76, 175, 80, 0.5)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    const Icon(Icons.verified, color: Colors.green),
                    const SizedBox(width: 10),
                    Expanded(
                        child: Text("Batch ${_scannedBatch!['batch_id']}",
                            style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Colors.green))),
                  ]),
                  const Divider(height: 30),
                  _buildDetailRow("Product", _scannedBatch!['product']),
                  _buildDetailRow("Origin", _scannedBatch!['origin']),
                  _buildDetailRow("Transit Temp", _scannedBatch!['avg_temp']),
                ],
              ),
            ),
            const SizedBox(height: 25),
            const Text("Quality Checklist",
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            CheckboxListTile(
              title: const Text("Packaging intact"),
              value: _checkPackaging,
              activeColor: Colors.orange,
              onChanged: (val) => setState(() => _checkPackaging = val!),
            ),
            CheckboxListTile(
              title: const Text("Halal Seal unbroken"),
              value: _checkSeal,
              activeColor: Colors.orange,
              onChanged: (val) => setState(() => _checkSeal = val!),
            ),
            CheckboxListTile(
              title: const Text("Temp check passed (-12°C or lower)"),
              value: _checkTemp,
              activeColor: Colors.orange,
              onChanged: (val) => setState(() => _checkTemp = val!),
            ),
            const SizedBox(height: 20),
            Row(children: [
              Expanded(
                  child: OutlinedButton(
                      onPressed: () => _showIncidentDialog(
                          prefillBatchId: _scannedBatch!['batch_id']),
                      style:
                          OutlinedButton.styleFrom(foregroundColor: Colors.red),
                      child: const Text("REJECT / REPORT"))),
              const SizedBox(width: 15),
              Expanded(
                  child: ElevatedButton(
                      onPressed: _isLoading ? null : _processAcceptance,
                      style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFE65100),
                          foregroundColor: Colors.white),
                      child: _isLoading
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator())
                          : const Text("ACCEPT & SIGN"))),
            ]),
          ]
        ],
      ),
    );
  }

  // --- 3. INVENTORY VIEW ---
  Widget _buildInventoryView() {
    if (_isLoading) return const Center(child: CircularProgressIndicator());
    return RefreshIndicator(
      onRefresh: _fetchInventory,
      child: _inventory.isEmpty
          ? ListView(
              children: const [
                SizedBox(height: 200),
                Center(
                    child: Text("Inventory is empty.\nScan items to add them.",
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.grey)))
              ],
            )
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _inventory.length,
              itemBuilder: (context, index) {
                final item = _inventory[index];
                return Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: Colors.green[50],
                      child: const Icon(Icons.inventory_2, color: Colors.green),
                    ),
                    title: Text(item['batch_id'],
                        style: const TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: Text(
                        "${item['product_type']}\nWeight: ${item['weight']}"),
                    trailing: const Chip(
                      label: Text("In Stock",
                          style: TextStyle(color: Colors.white, fontSize: 10)),
                      backgroundColor: Colors.green,
                    ),
                    isThreeLine: true,
                  ),
                );
              },
            ),
    );
  }

  // --- 4. NEW REPORTS VIEW (Linked to Drawer) ---
  Widget _buildReportsView() {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.report_gmailerrorred, size: 80, color: Colors.red),
          const SizedBox(height: 20),
          const Text("Report Critical Issue",
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
          const Text(
              "Report spoilage, broken seals, or missing items to the Admin.",
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey)),
          const SizedBox(height: 30),
          ElevatedButton.icon(
            onPressed: () => _makePhoneCall('999'),
            style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
                padding:
                    const EdgeInsets.symmetric(horizontal: 30, vertical: 15)),
            icon: const Icon(Icons.call),
            label: const Text("Call Admin / HQ"),
          ),
          const SizedBox(height: 15),
          OutlinedButton.icon(
            onPressed: () => _showIncidentDialog(), // Opens blank dialog
            style: OutlinedButton.styleFrom(
                foregroundColor: Colors.red,
                side: const BorderSide(color: Colors.red),
                padding:
                    const EdgeInsets.symmetric(horizontal: 30, vertical: 15)),
            icon: const Icon(Icons.edit_document),
            label: const Text("Fill Incident Form"),
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(String title, String value, Color color) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(16)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(value,
              style: TextStyle(
                  fontSize: 28, fontWeight: FontWeight.bold, color: color)),
          Text(title, style: TextStyle(color: color.withAlpha(204))),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Colors.grey)),
          Text(value, style: const TextStyle(fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: Text(_selectedIndex == 0
            ? "Retailer Dashboard"
            : _selectedIndex == 1
                ? "Receive Shipment"
                : _selectedIndex == 2
                    ? "Current Inventory"
                    : "Reports"), // Updated Title
        backgroundColor: const Color(0xFFE65100),
        foregroundColor: Colors.white,
        centerTitle: true,
      ),
      drawer: _buildDrawer(),
      body: _selectedIndex == 0
          ? _buildIncomingView()
          : _selectedIndex == 1
              ? _buildScannerView()
              : _selectedIndex == 2
                  ? _buildInventoryView()
                  : _buildReportsView(), // Show Report View
    );
  }
}

// --- RETAILER PROFILE SCREEN (Same as before) ---
class RetailerProfileScreen extends StatefulWidget {
  final Map<String, dynamic> userData;
  final VoidCallback onProfileUpdate;

  const RetailerProfileScreen(
      {super.key, required this.userData, required this.onProfileUpdate});

  @override
  State<RetailerProfileScreen> createState() => _RetailerProfileScreenState();
}

class _RetailerProfileScreenState extends State<RetailerProfileScreen> {
  late Map<String, dynamic> _userData;
  File? _profileImage;
  bool _isEditing = false;
  bool _isSaving = false;

  late TextEditingController _nameController;
  late TextEditingController _phoneController;
  late TextEditingController _storeNameController;
  late TextEditingController _regNoController;
  late TextEditingController _addressController;

  @override
  void initState() {
    super.initState();
    _userData = widget.userData;
    _nameController = TextEditingController(text: _userData['name']);
    _phoneController = TextEditingController(
        text: _userData['phone_number'] ?? _userData['phone']);

    // Retailer Specific Fields
    _storeNameController = TextEditingController(
        text: _userData['retailer_profile']?['store_name'] ?? '');
    _regNoController = TextEditingController(
        text: _userData['retailer_profile']?['business_reg_no'] ?? '');
    _addressController = TextEditingController(
        text: _userData['retailer_profile']?['outlet_address'] ?? '');
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _storeNameController.dispose();
    _regNoController.dispose();
    _addressController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    if (!_isEditing) return;
    final ImagePicker picker = ImagePicker();
    final XFile? image = await picker.pickImage(source: ImageSource.gallery);
    if (image != null) {
      setState(() => _profileImage = File(image.path));
    }
  }

  Future<void> _updateProfile() async {
    setState(() => _isSaving = true);
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('auth_token');

      var request =
          http.MultipartRequest('POST', Uri.parse('$baseUrl/user/update'));
      request.headers['Authorization'] = 'Bearer $token';

      // Common Fields
      request.fields['name'] = _nameController.text;
      request.fields['phone'] = _phoneController.text;

      // Retailer Specific Fields
      request.fields['store_name'] = _storeNameController.text;
      request.fields['business_reg_no'] = _regNoController.text;
      request.fields['outlet_address'] = _addressController.text;

      if (_profileImage != null) {
        request.files.add(await http.MultipartFile.fromPath(
            'profile_image', _profileImage!.path));
      }

      var streamedResponse = await request.send();
      var response = await http.Response.fromStream(streamedResponse);

      if (!mounted) return;

      if (response.statusCode == 200) {
        final updatedData = jsonDecode(response.body)['user'];
        setState(() {
          _userData = updatedData;
          _isEditing = false;
          _profileImage = null;
        });
        widget.onProfileUpdate();

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text("Profile Updated Successfully!"),
              backgroundColor: Colors.green),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text("Update Failed"), backgroundColor: Colors.red));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text("Connection Error"), backgroundColor: Colors.red));
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    ImageProvider? backgroundImage;
    if (_profileImage != null) {
      backgroundImage = FileImage(_profileImage!);
    } else if (_userData['profile_image'] != null) {
      backgroundImage =
          NetworkImage("$storageUrl${_userData['profile_image']}");
    }

    String storeName = _userData['retailer_profile']?['store_name'] ?? 'N/A';
    String regNo = _userData['retailer_profile']?['business_reg_no'] ?? 'N/A';
    String address = _userData['retailer_profile']?['outlet_address'] ?? 'N/A';

    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: const Text("Store Profile",
            style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
        backgroundColor: const Color(0xFFE65100),
        centerTitle: true,
        actions: [
          IconButton(
            icon: Icon(_isEditing ? Icons.close : Icons.edit,
                color: Colors.white),
            onPressed: () {
              setState(() {
                _isEditing = !_isEditing;
                if (!_isEditing) {
                  _nameController.text = _userData['name'] ?? "";
                  _storeNameController.text = storeName;
                  _regNoController.text = regNo;
                  _addressController.text = address;
                  _profileImage = null;
                }
              });
            },
          ),
          const SizedBox(width: 10),
        ],
      ),
      body: Stack(
        children: [
          Container(
            height: 180,
            width: double.infinity,
            decoration: const BoxDecoration(
              color: Color(0xFFE65100),
              borderRadius: BorderRadius.only(
                bottomLeft: Radius.circular(30),
                bottomRight: Radius.circular(30),
              ),
            ),
          ),
          SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Column(
              children: [
                const SizedBox(height: 40),
                Card(
                  elevation: 5,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20)),
                  child: Padding(
                    padding: const EdgeInsets.all(25.0),
                    child: Column(
                      children: [
                        GestureDetector(
                          onTap: _pickImage,
                          child: Stack(
                            alignment: Alignment.bottomRight,
                            children: [
                              CircleAvatar(
                                radius: 50,
                                backgroundColor: Colors.grey[200],
                                backgroundImage: backgroundImage,
                                child: backgroundImage == null
                                    ? const Icon(Icons.store,
                                        size: 50, color: Color(0xFFE65100))
                                    : null,
                              ),
                              if (_isEditing)
                                const CircleAvatar(
                                  radius: 15,
                                  backgroundColor: Colors.orange,
                                  child: Icon(Icons.camera_alt,
                                      size: 15, color: Colors.white),
                                ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 15),
                        if (_isEditing)
                          TextField(
                            controller: _nameController,
                            textAlign: TextAlign.center,
                            decoration: const InputDecoration(
                                labelText: "Manager Name"),
                            style: const TextStyle(
                                fontSize: 18, fontWeight: FontWeight.bold),
                          )
                        else
                          Text(
                            _userData['name'] ?? "Manager Name",
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                                fontSize: 22, fontWeight: FontWeight.bold),
                          ),
                        const SizedBox(height: 5),
                        Text("Retail Partner",
                            style: TextStyle(color: Colors.grey[600])),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                _buildSectionLabel("Store Details"),
                Card(
                  child: Column(
                    children: [
                      _buildInfoTile(
                          icon: Icons.store_mall_directory,
                          label: "Store Name",
                          value: storeName,
                          isEditable: _isEditing,
                          controller: _storeNameController),
                      const Divider(height: 1),
                      _buildInfoTile(
                          icon: Icons.confirmation_number,
                          label: "Business Reg No (SSM)",
                          value: regNo,
                          isEditable: _isEditing,
                          controller: _regNoController),
                      const Divider(height: 1),
                      _buildInfoTile(
                          icon: Icons.location_on,
                          label: "Outlet Address",
                          value: address,
                          isEditable: _isEditing,
                          controller: _addressController),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                _buildSectionLabel("Contact Info"),
                Card(
                  child: Column(
                    children: [
                      _buildInfoTile(
                          icon: Icons.phone,
                          label: "Phone",
                          value: _userData['phone_number'] ?? "N/A",
                          isEditable: _isEditing,
                          controller: _phoneController),
                      const Divider(height: 1),
                      _buildInfoTile(
                          icon: Icons.email,
                          label: "Email",
                          value: _userData['email'] ?? "N/A"),
                    ],
                  ),
                ),
                const SizedBox(height: 100),
              ],
            ),
          ),
        ],
      ),
      floatingActionButton: _isEditing
          ? FloatingActionButton.extended(
              onPressed: _isSaving ? null : _updateProfile,
              backgroundColor: const Color(0xFFE65100),
              icon: _isSaving
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(color: Colors.white))
                  : const Icon(Icons.save),
              label: Text(_isSaving ? "Saving..." : "Save Changes"),
            )
          : null,
    );
  }

  Widget _buildSectionLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(left: 10, bottom: 8),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Text(text,
            style: const TextStyle(
                fontSize: 14, fontWeight: FontWeight.bold, color: Colors.grey)),
      ),
    );
  }

  Widget _buildInfoTile(
      {required IconData icon,
      required String label,
      required String value,
      bool isEditable = false,
      TextEditingController? controller}) {
    return ListTile(
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
            color: Colors.orange[50], borderRadius: BorderRadius.circular(8)),
        child: Icon(icon, color: const Color(0xFFE65100)),
      ),
      title:
          Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
      subtitle: isEditable && controller != null
          ? TextField(
              controller: controller,
              style: const TextStyle(fontWeight: FontWeight.bold))
          : Text(value, style: const TextStyle(fontWeight: FontWeight.bold)),
    );
  }
}
