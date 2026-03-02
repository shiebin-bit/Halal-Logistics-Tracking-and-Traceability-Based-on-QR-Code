import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import '../audit_log_screen.dart';
import 'package:path_provider/path_provider.dart';
import 'package:open_file/open_file.dart';

import '../../config.dart';

class ProcessorDashboard extends StatefulWidget {
  const ProcessorDashboard({super.key});

  @override
  State<ProcessorDashboard> createState() => _ProcessorDashboardState();
}

class _ProcessorDashboardState extends State<ProcessorDashboard> {
  // --- STATE VARIABLES ---
  int _selectedIndex = 0; // 0: Inventory, 1: Create Batch, 2: Reports

  // --- GLOBAL DATA ---
  Map<String, dynamic> _userData = {
    "name": "Loading...",
    "email": "...",
    "phone": "...",
    "profile_image": null,
    // Add nested profile defaults to avoid null errors
    "processor_profile": {
      "company_reg_no": "...",
      "halal_cert_no": "...",
      "factory_address": "..."
    }
  };

  // --- CREATE BATCH FORM DATA ---
  final _formKey = GlobalKey<FormState>();
  final _batchIdController = TextEditingController();
  final _weightController = TextEditingController();
  final _originController = TextEditingController();
  final _factoryController = TextEditingController();
  final _locationController = TextEditingController();

  String? _selectedProductType;
  final List<String> _productTypes = [
    'Whole Chicken',
    'Chicken Wings',
    'Drumsticks',
    'Chicken Breast',
    'Chicken Feet',
    'Nuggets (Processed)'
  ];

  DateTime _selectedDate = DateTime.now();
  String? _generatedQRData;
  String? _blockchainHash;
  bool _isGettingLocation = false;
  bool _isSavingBatch = false;
  bool _isDownloadingPdf = false;

  // --- INVENTORY DATA ---
  final TextEditingController _searchController = TextEditingController();
  String _filterType = "All";
  int _currentPage = 1;
  final int _itemsPerPage = 5;
  List<dynamic> _apiBatches = [];
  bool _isLoadingInventory = true;

  @override
  void initState() {
    super.initState();
    _fetchInventory();
    _fetchProfile();
  }

  // --- API ACTIONS ---

  Future<String?> _getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('auth_token');
  }

  // FETCH PROFILE
  Future<void> _fetchProfile() async {
    try {
      final token = await _getToken();
      final response = await http.get(
        Uri.parse('$baseUrl/user'),
        headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'application/json'
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() {
          _userData = data['user'];
          // Ensure profile exists to prevent crashes
          if (_userData['processor_profile'] == null) {
            _userData['processor_profile'] = {};
          }
        });
      }
    } catch (e) {
      print("Profile Load Error: $e");
    }
  }

  // 1. FETCH INVENTORY
  Future<void> _fetchInventory() async {
    setState(() => _isLoadingInventory = true);
    try {
      final token = await _getToken();
      final response = await http.get(
        Uri.parse('$baseUrl/batches'),
        headers: {
          'Accept': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() {
          _apiBatches = data['data'] ?? [];
          _isLoadingInventory = false;
        });
      } else {
        setState(() => _isLoadingInventory = false);
        if (response.statusCode == 401) _logout();
      }
    } catch (e) {
      setState(() => _isLoadingInventory = false);
    }
  }

  // 2. CREATE BATCH
  Future<void> _saveBatchToInventory() async {
    setState(() => _isSavingBatch = true);

    try {
      final token = await _getToken();
      final response = await http.post(
        Uri.parse('$baseUrl/batches'),
        headers: {
          'Accept': 'application/json',
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          "batch_id": _batchIdController.text,
          "product_type": _selectedProductType,
          "weight": _weightController.text,
          "origin_farm": _originController.text,
          "processing_factory": _factoryController.text,
          "current_location": _locationController.text,
          "slaughter_date": DateFormat('yyyy-MM-dd').format(_selectedDate),
          "status": "Processing",
          "qr_code_hash": _blockchainHash,
        }),
      );
      if (!mounted) return;
      if (response.statusCode == 201) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text("Batch Saved to Inventory successfully!")),
        );
        _resetCreateForm();
        _fetchInventory();
        setState(() => _selectedIndex = 0);
      } else {
        final err = jsonDecode(response.body);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(err['message'] ?? "Failed to save batch")),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Connection Error")),
      );
    } finally {
      setState(() => _isSavingBatch = false);
    }
  }

  Future<void> _logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
    if (mounted) {
      Navigator.pushNamedAndRemoveUntil(context, '/login', (route) => false);
    }
  }

  Future<void> _handleRefresh() async {
    await _fetchInventory();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Inventory Updated")),
      );
    }
  }

  Future<void> _getCurrentLocation() async {
    setState(() => _isGettingLocation = true);
    // Simulate GPS fetch
    await Future.delayed(const Duration(seconds: 1));
    setState(() {
      _isGettingLocation = false;
      // You can replace this with actual Geolocator logic later
      _locationController.text = _userData['processor_profile']
              ['factory_address'] ??
          "Factory Default Location";
    });
  }

  // --- PDF DOWNLOAD FUNCTION ---
  Future<void> _downloadManifest() async {
    setState(() => _isDownloadingPdf = true);

    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('auth_token');

      final response = await http.get(
        Uri.parse('$baseUrl/reports/manifest'),
        headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'application/pdf',
        },
      );

      if (response.statusCode == 200) {
        final dir = await getTemporaryDirectory();
        final file = File('${dir.path}/manifest_report.pdf');
        await file.writeAsBytes(response.bodyBytes);
        await OpenFile.open(file.path);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("PDF Downloaded & Opened!")),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("Server Error: ${response.statusCode}")),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Download Failed: $e")),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isDownloadingPdf = false);
      }
    }
  }

  String _generateBlockchainHash(String input) {
    return "0x${(input.hashCode ^ DateTime.now().millisecondsSinceEpoch).toRadixString(16).padLeft(64, '0')}";
  }

  void _resetCreateForm() {
    _batchIdController.clear();
    _weightController.clear();
    _originController.clear();
    _factoryController.clear();
    _locationController.clear();
    setState(() {
      _selectedProductType = null;
      _generatedQRData = null;
      _blockchainHash = null;
      _selectedDate = DateTime.now();
    });
  }

  // --- UI BUILDERS ---

  Widget _buildDrawer() {
    ImageProvider? drawerImage;
    if (_userData['profile_image'] != null) {
      drawerImage = NetworkImage("$storageUrl${_userData['profile_image']}");
    }

    // Access nested profile safely
    String companyReg =
        _userData['processor_profile']?['company_reg_no'] ?? 'Pending';

    return Drawer(
      child: Column(
        children: [
          UserAccountsDrawerHeader(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF1B5E20), Color(0xFF43A047)],
              ),
            ),
            accountName: Text(_userData['name'] ?? "Loading...",
                style:
                    const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
            accountEmail: Text("Reg No: $companyReg"),
            currentAccountPicture: CircleAvatar(
              backgroundColor: Colors.white,
              backgroundImage: drawerImage,
              child: drawerImage == null
                  ? const Text("AP",
                      style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF1B5E20)))
                  : null,
            ),
          ),
          ListTile(
            leading: const Icon(Icons.list_alt, color: Colors.green),
            title: const Text("Batch Inventory"),
            selected: _selectedIndex == 0,
            onTap: () {
              setState(() => _selectedIndex = 0);
              Navigator.pop(context);
            },
          ),
          ListTile(
            leading: const Icon(Icons.add_circle_outline, color: Colors.green),
            title: const Text("Create New Batch"),
            selected: _selectedIndex == 1,
            onTap: () {
              setState(() => _selectedIndex = 1);
              Navigator.pop(context);
            },
          ),
          ListTile(
            leading: const Icon(Icons.analytics_outlined, color: Colors.green),
            title: const Text("Reports & Manifests"),
            selected: _selectedIndex == 2,
            onTap: () {
              setState(() => _selectedIndex = 2);
              Navigator.pop(context);
            },
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.person, color: Colors.black),
            title: const Text("Profile Settings"),
            onTap: () {
              Navigator.pop(context);
              Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (context) => ProfileScreen(
                          userData: _userData,
                          onProfileUpdate: _fetchProfile)));
            },
          ),
          const Spacer(),
          ListTile(
            leading: const Icon(Icons.logout, color: Colors.red),
            title: const Text("Secure Logout",
                style:
                    TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
            onTap: _logout,
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildInventoryView() {
    if (_isLoadingInventory && _apiBatches.isEmpty) {
      return const Center(
          child: CircularProgressIndicator(color: Color(0xFF1B5E20)));
    }

    if (_apiBatches.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.inbox, size: 60, color: Colors.grey),
            const SizedBox(height: 10),
            const Text("No batches found.",
                style: TextStyle(color: Colors.grey)),
            TextButton(
              onPressed: _handleRefresh,
              child: const Text("Refresh"),
            )
          ],
        ),
      );
    }

    List<dynamic> filteredList = _apiBatches.where((batch) {
      String id = batch["batch_id"]?.toString().toLowerCase() ?? "";
      String type = batch["product_type"]?.toString().toLowerCase() ?? "";
      String search = _searchController.text.toLowerCase();

      bool matchesSearch = id.contains(search) || type.contains(search);
      bool matchesFilter =
          _filterType == "All" || batch["product_type"] == _filterType;

      return matchesSearch && matchesFilter;
    }).toList();

    int totalItems = filteredList.length;
    int totalPages = (totalItems / _itemsPerPage).ceil();
    if (totalPages == 0) totalPages = 1;
    if (_currentPage > totalPages) _currentPage = totalPages;
    int startIndex = (_currentPage - 1) * _itemsPerPage;
    int endIndex = min(startIndex + _itemsPerPage, totalItems);

    List<dynamic> currentDisplayList = [];
    if (startIndex < totalItems) {
      currentDisplayList = filteredList.sublist(startIndex, endIndex);
    }

    return RefreshIndicator(
      onRefresh: _handleRefresh,
      color: const Color(0xFF1B5E20),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                _buildStatCard("Total Batches", "$totalItems", Colors.blue),
                const SizedBox(width: 10),
                _buildStatCard("Active", "$totalItems", Colors.orange),
              ],
            ),
            const SizedBox(height: 20),
            TextField(
              controller: _searchController,
              onChanged: (val) => setState(() => _currentPage = 1),
              decoration: InputDecoration(
                hintText: "Search Batch ID...",
                prefixIcon: const Icon(Icons.search),
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none),
              ),
            ),
            const SizedBox(height: 10),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: ["All", ..._productTypes].map((filter) {
                  return Padding(
                    padding: const EdgeInsets.only(right: 8.0),
                    child: ChoiceChip(
                      label: Text(filter),
                      selected: _filterType == filter,
                      selectedColor: Colors.green[100],
                      onSelected: (selected) => setState(() {
                        _filterType = filter;
                        _currentPage = 1;
                      }),
                    ),
                  );
                }).toList(),
              ),
            ),
            const SizedBox(height: 15),
            const Text("Active Inventory",
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            Expanded(
              child: ListView.builder(
                itemCount: currentDisplayList.length,
                itemBuilder: (context, index) {
                  final item = currentDisplayList[index];
                  String id = item['batch_id'] ?? 'Unknown';
                  String type = item['product_type'] ?? 'N/A';
                  String weight = item['weight'] ?? '0kg';
                  String status = item['status'] ?? 'Processing';
                  String date = item['slaughter_date'] ?? '';
                  String freshness =
                      item['freshness_score']?.toString() ?? '100';

                  return Card(
                    elevation: 2,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(12),
                      onTap: () async {
                        final result = await Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (context) =>
                                  BatchDetailScreen(batchData: item)),
                        );
                        if (!mounted) return;
                        if (result == true) {
                          _fetchInventory();
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                                content: Text("Inventory list refreshed")),
                          );
                        }
                      },
                      child: Padding(
                        padding: const EdgeInsets.all(12.0),
                        child: Column(
                          children: [
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                      color: Colors.green[50],
                                      borderRadius: BorderRadius.circular(8)),
                                  child: const Icon(Icons.inventory_2,
                                      color: Colors.green),
                                ),
                                const SizedBox(width: 15),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(id,
                                          style: const TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 16)),
                                      Text("$type • $weight",
                                          style: TextStyle(
                                              color: Colors.grey[600],
                                              fontSize: 12)),
                                      Text("Date: $date",
                                          style: const TextStyle(
                                              fontSize: 11,
                                              color: Colors.grey)),
                                      Row(
                                        children: [
                                          const Icon(Icons.health_and_safety,
                                              size: 12, color: Colors.green),
                                          const SizedBox(width: 4),
                                          Text("AI Freshness: $freshness%",
                                              style: const TextStyle(
                                                  fontSize: 12,
                                                  color: Colors.green,
                                                  fontWeight: FontWeight.bold)),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 8, vertical: 4),
                                      decoration: BoxDecoration(
                                          color: status == "Ready"
                                              ? Colors.green
                                              : Colors.orange,
                                          borderRadius:
                                              BorderRadius.circular(12)),
                                      child: Text(status,
                                          style: const TextStyle(
                                              color: Colors.white,
                                              fontSize: 10,
                                              fontWeight: FontWeight.bold)),
                                    ),
                                    const SizedBox(height: 8),
                                    const Row(
                                      children: [
                                        Icon(Icons.location_on,
                                            size: 14, color: Colors.blue),
                                        Text("Track",
                                            style: TextStyle(
                                                color: Colors.blue,
                                                fontSize: 12)),
                                      ],
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
            Container(
              margin: const EdgeInsets.only(top: 10),
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 20),
              decoration: BoxDecoration(
                  color: Colors.white, borderRadius: BorderRadius.circular(30)),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  IconButton(
                      icon: const Icon(Icons.arrow_back_ios, size: 16),
                      onPressed: _currentPage > 1
                          ? () => setState(() => _currentPage--)
                          : null),
                  Text("Page $_currentPage of $totalPages",
                      style: const TextStyle(fontWeight: FontWeight.bold)),
                  IconButton(
                      icon: const Icon(Icons.arrow_forward_ios, size: 16),
                      onPressed: _currentPage < totalPages
                          ? () => setState(() => _currentPage++)
                          : null),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }


  Widget _buildCreateBatchView() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text("Create Digital Passport",
                    style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1B5E20))),
                IconButton(
                  icon: const Icon(Icons.refresh),
                  tooltip: "Clear Form",
                  onPressed: _resetCreateForm,
                )
              ],
            ),
            const Text("Register batch on the Halal Blockchain.",
                style: TextStyle(color: Colors.grey)),
            const SizedBox(height: 20),
            Card(
              elevation: 4,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16)),
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    TextFormField(
                      controller: _batchIdController,
                      decoration: const InputDecoration(
                          labelText: "Batch ID",
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.qr_code)),
                      validator: (v) => v!.isEmpty ? "Batch ID Required" : null,
                    ),
                    const SizedBox(height: 15),
                    DropdownButtonFormField<String>(
                      value: _selectedProductType,
                      decoration: const InputDecoration(
                          labelText: "Product Type",
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.fastfood)),
                      items: _productTypes
                          .map((type) =>
                              DropdownMenuItem(value: type, child: Text(type)))
                          .toList(),
                      onChanged: (val) =>
                          setState(() => _selectedProductType = val),
                      validator: (v) =>
                          v == null ? "Select Product Type" : null,
                    ),
                    const SizedBox(height: 15),
                    TextFormField(
                      controller: _weightController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                          labelText: "Weight (kg)",
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.scale)),
                      validator: (v) => v!.isEmpty ? "Required" : null,
                    ),
                    const SizedBox(height: 15),
                    TextFormField(
                      controller: _originController,
                      decoration: const InputDecoration(
                          labelText: "Farm Origin",
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.agriculture)),
                      validator: (v) => v!.isEmpty ? "Required" : null,
                    ),
                    const SizedBox(height: 15),
                    TextFormField(
                      controller: _factoryController,
                      decoration: const InputDecoration(
                          labelText: "Processing Factory",
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.factory)),
                      validator: (v) => v!.isEmpty ? "Required" : null,
                    ),
                    const SizedBox(height: 15),
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _locationController,
                            readOnly: true,
                            decoration: const InputDecoration(
                                labelText: "Current Location",
                                border: OutlineInputBorder(),
                                prefixIcon: Icon(Icons.location_on)),
                            validator: (v) =>
                                v!.isEmpty ? "Location Required" : null,
                          ),
                        ),
                        const SizedBox(width: 10),
                        ElevatedButton(
                          onPressed:
                              _isGettingLocation ? null : _getCurrentLocation,
                          style: ElevatedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              backgroundColor: Colors.blue[700],
                              foregroundColor: Colors.white),
                          child: _isGettingLocation
                              ? const SizedBox(
                                  height: 20,
                                  width: 20,
                                  child: CircularProgressIndicator(
                                      color: Colors.white, strokeWidth: 2))
                              : const Icon(Icons.my_location),
                        ),
                      ],
                    ),
                    const SizedBox(height: 15),
                    InkWell(
                      onTap: () async {
                        final picked = await showDatePicker(
                            context: context,
                            initialDate: _selectedDate,
                            firstDate: DateTime(2020),
                            lastDate: DateTime(2030));
                        if (picked != null)
                          setState(() => _selectedDate = picked);
                      },
                      child: InputDecorator(
                        decoration: const InputDecoration(
                            labelText: "Slaughter Date",
                            border: OutlineInputBorder(),
                            prefixIcon: Icon(Icons.calendar_month)),
                        child: Text(
                            DateFormat('yyyy-MM-dd').format(_selectedDate)),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 25),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton.icon(
                onPressed: () {
                  if (_formKey.currentState!.validate()) {
                    setState(() {
                      String rawData =
                          "BATCH:${_batchIdController.text}|TYPE:$_selectedProductType|LOC:${_locationController.text}";
                      _blockchainHash = _generateBlockchainHash(rawData);
                      _generatedQRData = "$rawData|HASH:$_blockchainHash";
                    });
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                        content: Text("Batch Generated! Ready to Save.")));
                  }
                },
                icon: const Icon(Icons.fingerprint),
                label: const Text("GENERATE SECURE BATCH"),
                style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1B5E20),
                    foregroundColor: Colors.white),
              ),
            ),
            if (_generatedQRData != null) ...[
              const SizedBox(height: 30),
              Center(
                child: Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(15),
                      decoration: BoxDecoration(
                          color: Colors.white,
                          border: Border.all(color: Colors.green),
                          borderRadius: BorderRadius.circular(12)),
                      child: QrImageView(
                          data: _generatedQRData!,
                          version: QrVersions.auto,
                          size: 200.0),
                    ),
                    const SizedBox(height: 20),
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton.icon(
                        onPressed:
                            _isSavingBatch ? null : _saveBatchToInventory,
                        icon: const Icon(Icons.save),
                        label: _isSavingBatch
                            ? const CircularProgressIndicator(
                                color: Colors.white)
                            : const Text("2. SAVE TO INVENTORY"),
                        style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blue[800],
                            foregroundColor: Colors.white),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildReportsView() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.description, size: 100, color: Colors.green[100]),
          const SizedBox(height: 20),
          const Text("Export Manifests",
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
          const SizedBox(height: 10),
          ElevatedButton.icon(
            onPressed: _isDownloadingPdf ? null : _downloadManifest,
            icon: _isDownloadingPdf
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 2,
                    ),
                  )
                : const Icon(Icons.download),
            label: Text(_isDownloadingPdf
                ? "Downloading..."
                : "Download Weekly Report (PDF)"),
            style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1B5E20),
                foregroundColor: Colors.white,
                padding:
                    const EdgeInsets.symmetric(horizontal: 30, vertical: 15)),
          ),
          const SizedBox(height: 20),
          TextButton.icon(
            onPressed: () {
              Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (context) => const AuditLogScreen()));
            },
            icon: const Icon(Icons.history),
            label: const Text("View Audit Logs"),
            style:
                TextButton.styleFrom(foregroundColor: const Color(0xFF1B5E20)),
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(String title, String value, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(value,
              style: TextStyle(
                  fontSize: 24, fontWeight: FontWeight.bold, color: color)),
          Text(title,
              style: TextStyle(color: color.withValues(alpha: 0.8), fontSize: 12)),
        ]),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: Text(_selectedIndex == 0
            ? "Dashboard"
            : _selectedIndex == 1
                ? "Create Batch"
                : "Reports"),
        backgroundColor: const Color(0xFF1B5E20),
        foregroundColor: Colors.white,
        centerTitle: true,
      ),
      drawer: _buildDrawer(),
      body: _selectedIndex == 0
          ? _buildInventoryView()
          : _selectedIndex == 1
              ? _buildCreateBatchView()
              : _buildReportsView(),
    );
  }
}

// --- UPDATED BATCH DETAIL SCREEN (No Changes needed here) ---
class BatchDetailScreen extends StatefulWidget {
  final Map<String, dynamic> batchData;
  const BatchDetailScreen({super.key, required this.batchData});

  @override
  State<BatchDetailScreen> createState() => _BatchDetailScreenState();
}

class _BatchDetailScreenState extends State<BatchDetailScreen> {
  late String _status;
  bool _isUpdating = false;

  @override
  void initState() {
    super.initState();
    _status = widget.batchData['status'] ?? 'Processing';
  }

  Future<void> _updateStatusInBackend(String newStatus) async {
    setState(() => _isUpdating = true);
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('auth_token');
      final String batchId = widget.batchData['batch_id'];

      final response = await http.post(
        Uri.parse('$baseUrl/batches/update-status'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: jsonEncode({
          'batch_id': batchId,
          'status': newStatus,
        }),
      );
      if (!mounted) return;
      if (response.statusCode == 200) {
        setState(() => _status = newStatus);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text("Status Updated in Database!"),
              backgroundColor: Colors.green),
        );
        Navigator.pop(context, true);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text("Failed to update status"),
              backgroundColor: Colors.red),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text("Connection Error"), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) setState(() => _isUpdating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Batch ${widget.batchData['batch_id'] ?? 'Details'}"),
        backgroundColor: const Color(0xFF1B5E20),
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            // QR Code Section
            Center(
              child: QrImageView(
                data: widget.batchData.toString(), // In real app, use the hash
                size: 150,
                version: QrVersions.auto,
              ),
            ),
            const SizedBox(height: 20),

            // Details Card
            Card(
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
              elevation: 4,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    _detailRow("Product Type",
                        widget.batchData['product_type'] ?? 'N/A'),
                    const Divider(),
                    _detailRow("Weight", widget.batchData['weight'] ?? 'N/A'),
                    const Divider(),

                    // --- STATUS ROW WITH RESTRICTED LOGIC ---
                    Builder(builder: (context) {
                      // LOGIC: Processor can ONLY move from 'Processing' -> 'Ready'.
                      // All other statuses are controlled by scanning (Driver/Retailer).
                      List<String> allowedOptions = [];

                      if (_status == 'Processing') {
                        allowedOptions = ['Processing', 'Ready'];
                      } else {
                        // If Ready, In Transit, or Delivered, Processor cannot manually change it.
                        allowedOptions = [_status];
                      }

                      return Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text("Current Status",
                              style: TextStyle(color: Colors.grey)),
                          _isUpdating
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child:
                                      CircularProgressIndicator(strokeWidth: 2))
                              : DropdownButton<String>(
                                  value: _status,
                                  style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      // Grey out text if disabled
                                      color: allowedOptions.length > 1
                                          ? Colors.green
                                          : Colors.grey),
                                  underline: Container(
                                      height: 2,
                                      color: allowedOptions.length > 1
                                          ? Colors.green
                                          : Colors.grey[300]),
                                  // Disable dropdown if only 1 option exists
                                  onChanged: allowedOptions.length > 1
                                      ? (val) {
                                          if (val != null && val != _status) {
                                            _updateStatusInBackend(val);
                                          }
                                        }
                                      : null,
                                  items: allowedOptions.map((String value) {
                                    return DropdownMenuItem<String>(
                                      value: value,
                                      child: Text(value),
                                    );
                                  }).toList(),
                                ),
                        ],
                      );
                    }),
                    // ----------------------------------------

                    const Divider(),
                    _detailRow(
                        "Freshness",
                        widget.batchData['freshness_score']?.toString() ??
                            '100%'),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _detailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Colors.grey)),
          Text(value,
              style:
                  const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        ],
      ),
    );
  }
}

// --- UPDATED PROFILE SCREEN (Connects to ProcessorProfile) ---
class ProfileScreen extends StatefulWidget {
  final Map<String, dynamic> userData;
  final VoidCallback onProfileUpdate;

  const ProfileScreen(
      {super.key, required this.userData, required this.onProfileUpdate});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {


  late Map<String, dynamic> _userData;
  File? _profileImage;
  bool _isEditing = false;
  bool _isSaving = false;

  late TextEditingController _nameController;
  late TextEditingController _phoneController;

  @override
  void initState() {
    super.initState();
    _userData = widget.userData;
    _nameController = TextEditingController(text: _userData['name']);
    _phoneController = TextEditingController(
        text: _userData['phone_number'] ?? _userData['phone']);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
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
      request.fields['name'] = _nameController.text;
      request.fields['phone'] = _phoneController.text;

      if (_profileImage != null) {
        request.files.add(await http.MultipartFile.fromPath(
            'profile_image', _profileImage!.path));
      }

      var streamedResponse = await request.send();
      var response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200) {
        final updatedData = jsonDecode(response.body)['user'];
        setState(() {
          _userData = updatedData;
          _isEditing = false;
          _profileImage = null;
        });
        widget.onProfileUpdate();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
                content: Text("Profile Updated Successfully!"),
                backgroundColor: Colors.green),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
              content: Text("Update Failed"), backgroundColor: Colors.red));
        }
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

    // Safely get Processor details
    String companyReg =
        _userData['processor_profile']?['company_reg_no'] ?? 'N/A';
    String halalCert =
        _userData['processor_profile']?['halal_cert_no'] ?? 'N/A';
    String address =
        _userData['processor_profile']?['factory_address'] ?? 'N/A';

    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: const Text("Company Profile",
            style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
        backgroundColor: const Color(0xFF1B5E20),
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
                  _phoneController.text =
                      _userData['phone_number'] ?? _userData['phone'] ?? "";
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
              color: Color(0xFF1B5E20),
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
                                    ? const Text("AP",
                                        style: TextStyle(
                                            fontSize: 30,
                                            fontWeight: FontWeight.bold,
                                            color: Color(0xFF1B5E20)))
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
                            style: const TextStyle(
                                fontSize: 22, fontWeight: FontWeight.bold),
                          )
                        else
                          Text(
                            _userData['name'] ?? "Company Name",
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                                fontSize: 22, fontWeight: FontWeight.bold),
                          ),
                        const SizedBox(height: 5),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.green[50],
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: Colors.green.shade200),
                          ),
                          child: Text("License: $companyReg",
                              style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.green[800],
                                  fontWeight: FontWeight.w600)),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                _buildSectionLabel("Contact Information"),
                Card(
                  child: Column(
                    children: [
                      _buildInfoTile(
                          icon: Icons.email_outlined,
                          label: "Email",
                          value: _userData['email'] ?? "N/A"),
                      const Divider(height: 1),
                      _buildInfoTile(
                          icon: Icons.phone_outlined,
                          label: "Phone",
                          value: _userData['phone_number'] ?? "N/A",
                          isEditable: _isEditing,
                          controller: _phoneController),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                _buildSectionLabel("Factory Details"),
                Card(
                  child: Column(
                    children: [
                      _buildInfoTile(
                          icon: Icons.location_on_outlined,
                          label: "Address",
                          value: address),
                      const Divider(height: 1),
                      _buildInfoTile(
                          icon: Icons.verified_user_outlined,
                          label: "Halal Cert No",
                          value: halalCert),
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
              backgroundColor: const Color(0xFF1B5E20),
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
            color: Colors.green[50], borderRadius: BorderRadius.circular(8)),
        child: Icon(icon, color: const Color(0xFF1B5E20)),
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
