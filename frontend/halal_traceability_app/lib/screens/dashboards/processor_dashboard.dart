import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:qr_flutter/qr_flutter.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import '../audit_log_screen.dart';
import 'package:path_provider/path_provider.dart';
import 'package:open_file/open_file.dart';

import '../../config.dart';
import '../../services/auth_session_service.dart';
import '../../services/profile_image_service.dart';
import 'widgets/dashboard_widgets.dart';

/// Processor workspace for inventory management, batch creation, and reports.
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
  final _certificateAuthorityController =
      TextEditingController(text: 'JAKIM');
  final _certificateNoController = TextEditingController();

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
  DateTime _certificateValidUntil = DateTime.now().add(const Duration(days: 30));
  String? _generatedQRData;
  PlatformFile? _batchCertificateFile;
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
  int _profileImageVersion = DateTime.now().millisecondsSinceEpoch;

  @override
  void initState() {
    super.initState();
    _fetchInventory();
    _fetchProfile();
  }

  // --- ALL API ACTIONS (UNCHANGED) ---

  Future<String?> _getToken() async {
    return AuthSessionService.getToken();
  }

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
        final nextUserData = (data['user'] as Map).cast<String, dynamic>();
        if (nextUserData['processor_profile'] == null) {
          nextUserData['processor_profile'] = {};
        }
        final nextVersion = DateTime.now().millisecondsSinceEpoch;
        await ProfileImageService.evict(
          previousPath: _userData['profile_image'],
          nextPath: nextUserData['profile_image'],
          currentVersion: _profileImageVersion,
          nextVersion: nextVersion,
        );
        final factoryAddress = _factoryAddressFrom(nextUserData);
        setState(() {
          _profileImageVersion = nextVersion;
          _userData = nextUserData;
          final certNo =
              (nextUserData['processor_profile']?['halal_cert_no'] ?? '')
                  .toString();
          if (_certificateNoController.text.trim().isEmpty && certNo.isNotEmpty) {
            _certificateNoController.text = certNo;
          }
          if (_locationController.text.trim().isEmpty &&
              factoryAddress != null) {
            _locationController.text = factoryAddress;
          }
        });
      }
    } catch (e) {
      print("Profile Load Error: $e");
    }
  }

  String? _factoryAddressFrom(Map<String, dynamic> source) {
    final profile = source['processor_profile'];
    if (profile is! Map) return null;

    final value = profile['factory_address']?.toString().trim();
    if (value == null || value.isEmpty) return null;
    return value;
  }

  void _useFactoryAddress() {
    final factoryAddress = _factoryAddressFrom(_userData);
    if (factoryAddress == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Set your factory address in Profile Settings first.'),
        ),
      );
      return;
    }

    setState(() {
      _locationController.text = factoryAddress;
    });
  }

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

  Future<void> _saveBatchToInventory() async {
    setState(() => _isSavingBatch = true);

    try {
      final resolvedLocation = _locationController.text.trim().isNotEmpty
          ? _locationController.text.trim()
          : _factoryAddressFrom(_userData);

      if (resolvedLocation == null || resolvedLocation.isEmpty) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content:
                Text('Factory address is required before creating a batch.'),
          ),
        );
        return;
      }

      final token = await _getToken();
      final request =
          http.MultipartRequest('POST', Uri.parse('$baseUrl/batches'));
      request.headers.addAll({
        'Accept': 'application/json',
        'Authorization': 'Bearer $token',
      });
      request.fields.addAll({
        'batch_id': _batchIdController.text.trim(),
        'product_type': _selectedProductType ?? '',
        'weight': _weightController.text.trim(),
        'origin_farm': _originController.text.trim(),
        'processing_factory': _factoryController.text.trim(),
        'current_location': resolvedLocation,
        'certificate_authority': _certificateAuthorityController.text.trim(),
        'certificate_no': _certificateNoController.text.trim(),
        'certificate_valid_until':
            DateFormat('yyyy-MM-dd').format(_certificateValidUntil),
        'slaughter_date': DateFormat('yyyy-MM-dd').format(_selectedDate),
        'processing_date': DateFormat('yyyy-MM-dd').format(_selectedDate),
        'generate_qr': _generatedQRData != null ? '1' : '0',
      });

      if (_batchCertificateFile?.path != null) {
        request.files.add(await http.MultipartFile.fromPath(
          'certificate_document',
          _batchCertificateFile!.path!,
          filename: _batchCertificateFile!.name,
        ));
      }

      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);

      if (!mounted) return;
      if (response.statusCode == 201) {
        final payload = jsonDecode(response.body) as Map<String, dynamic>;
        final data = (payload['data'] as Map?)?.cast<String, dynamic>();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text("Batch Saved to Inventory successfully!")),
        );
        if (data != null && data['qr_code_payload'] != null) {
          setState(() {
            _generatedQRData = data['qr_code_payload'].toString();
          });
        }
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

  Future<void> _pickBatchCertificate() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf', 'jpg', 'jpeg', 'png'],
      );

      if (result == null || result.files.isEmpty) {
        return;
      }

      final file = result.files.first;
      if (file.size > 5 * 1024 * 1024) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Certificate file must be 5MB or smaller.')),
        );
        return;
      }

      if (!mounted) return;
      setState(() => _batchCertificateFile = file);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Certificate selected: ${file.name}')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Unable to pick certificate: $e')),
      );
    }
  }

  Future<void> _logout() async {
    await AuthSessionService.clearAuthSession();
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
    _useFactoryAddress();
    if (mounted) {
      setState(() => _isGettingLocation = false);
    }
  }

  Future<void> _downloadManifest() async {
    setState(() => _isDownloadingPdf = true);

    try {
      final token = await _getToken();

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

  void _resetCreateForm() {
    _batchIdController.clear();
    _weightController.clear();
    _originController.clear();
    _factoryController.clear();
    _locationController.clear();
    setState(() {
      _batchCertificateFile = null;
      _selectedProductType = null;
      _generatedQRData = null;
      _selectedDate = DateTime.now();
      _certificateValidUntil = DateTime.now().add(const Duration(days: 30));
    });
  }

  @override
  void dispose() {
    _batchIdController.dispose();
    _weightController.dispose();
    _originController.dispose();
    _factoryController.dispose();
    _locationController.dispose();
    _certificateAuthorityController.dispose();
    _certificateNoController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  // --- REDESIGNED UI BUILDERS ---

  Widget _buildDrawer() {
    final drawerImageUrl = ProfileImageService.buildUrl(
      _userData['profile_image'],
      version: _profileImageVersion,
    );
    final ImageProvider? drawerImage =
        drawerImageUrl != null ? NetworkImage(drawerImageUrl) : null;

    String companyReg =
        _userData['processor_profile']?['company_reg_no'] ?? 'Pending';

    return Drawer(
      child: Container(
        color: const Color(0xFFF8F9FA),
        child: Column(
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.only(
                  top: 60, bottom: 24, left: 24, right: 24),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Color(0xFF1B5E20),
                    Color(0xFF2E7D32),
                    Color(0xFF43A047)
                  ],
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  CircleAvatar(
                    radius: 32,
                    backgroundColor: Colors.white.withValues(alpha: 0.2),
                    backgroundImage: drawerImage,
                    onBackgroundImageError: drawerImage != null
                        ? (e, s) => debugPrint('Drawer image load error: $e')
                        : null,
                    child: drawerImage == null
                        ? const Text("AP",
                            style: TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.w700,
                                color: Colors.white))
                        : null,
                  ),
                  const SizedBox(height: 14),
                  Text(_userData['name'] ?? "Loading...",
                      style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 18,
                          color: Colors.white)),
                  const SizedBox(height: 4),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text("Reg: $companyReg",
                        style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.9),
                            fontSize: 12)),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            _buildDrawerItem(Icons.list_alt_rounded, "Batch Inventory", 0),
            _buildDrawerItem(
                Icons.add_circle_outline_rounded, "Create New Batch", 1),
            _buildDrawerItem(
                Icons.analytics_outlined, "Reports & Manifests", 2),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Divider(color: Colors.grey[200]),
            ),
            ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 24),
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(Icons.person_rounded,
                    color: Colors.grey[600], size: 22),
              ),
              title: Text("Profile Settings",
                  style: TextStyle(
                      fontWeight: FontWeight.w500, color: Colors.grey[700])),
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
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Divider(color: Colors.grey[200]),
            ),
            ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 24),
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.red.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.logout_rounded,
                    color: Colors.red, size: 20),
              ),
              title: const Text("Secure Logout",
                  style: TextStyle(
                      color: Colors.red, fontWeight: FontWeight.w600)),
              onTap: _logout,
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildDrawerItem(IconData icon, String title, int index) {
    final isSelected = _selectedIndex == index;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
      child: ListTile(
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: isSelected
                ? const Color(0xFF1B5E20).withValues(alpha: 0.1)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon,
              color: isSelected ? const Color(0xFF1B5E20) : Colors.grey[600],
              size: 22),
        ),
        title: Text(title,
            style: TextStyle(
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                color:
                    isSelected ? const Color(0xFF1B5E20) : Colors.grey[700])),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        selected: isSelected,
        selectedTileColor: const Color(0xFF1B5E20).withValues(alpha: 0.04),
        onTap: () {
          setState(() => _selectedIndex = index);
          Navigator.pop(context);
        },
      ),
    );
  }

  Widget _buildInventoryView() {
    if (_isLoadingInventory && _apiBatches.isEmpty) {
      return const ShimmerLoader(itemCount: 5);
    }

    if (_apiBatches.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.inbox_rounded, size: 70, color: Colors.grey[300]),
            const SizedBox(height: 14),
            Text("No batches found.",
                style: TextStyle(
                    color: Colors.grey[400],
                    fontSize: 16,
                    fontWeight: FontWeight.w500)),
            const SizedBox(height: 8),
            TextButton.icon(
              onPressed: _handleRefresh,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text("Refresh"),
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
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Stats row
            StaggeredListItem(
              index: 0,
              child: Row(
                children: [
                  AnimatedStatCard(
                      title: "Total Batches",
                      value: "$totalItems",
                      color: const Color(0xFF1B5E20),
                      icon: Icons.inventory_2_rounded),
                  const SizedBox(width: 12),
                  AnimatedStatCard(
                      title: "Active",
                      value: "$totalItems",
                      color: const Color(0xFFFF9800),
                      icon: Icons.trending_up_rounded),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Search bar
            TextField(
              controller: _searchController,
              onChanged: (val) => setState(() => _currentPage = 1),
              decoration: InputDecoration(
                hintText: "Search Batch ID...",
                hintStyle: TextStyle(color: Colors.grey[400]),
                prefixIcon: Icon(Icons.search_rounded, color: Colors.grey[400]),
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide.none),
                enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide.none),
              ),
            ),
            const SizedBox(height: 12),

            // Filter chips
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: ["All", ..._productTypes].map((filter) {
                  final isSelected = _filterType == filter;
                  return Padding(
                    padding: const EdgeInsets.only(right: 8.0),
                    child: ChoiceChip(
                      label: Text(filter,
                          style: TextStyle(
                              fontSize: 12,
                              fontWeight: isSelected
                                  ? FontWeight.w700
                                  : FontWeight.w500,
                              color: isSelected
                                  ? const Color(0xFF1B5E20)
                                  : Colors.grey[600])),
                      selected: isSelected,
                      selectedColor:
                          const Color(0xFF1B5E20).withValues(alpha: 0.12),
                      backgroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20)),
                      side: BorderSide(
                          color: isSelected
                              ? const Color(0xFF1B5E20).withValues(alpha: 0.3)
                              : Colors.grey[200]!),
                      onSelected: (selected) => setState(() {
                        _filterType = filter;
                        _currentPage = 1;
                      }),
                    ),
                  );
                }).toList(),
              ),
            ),
            const SizedBox(height: 18),

            const SectionTitle(
                title: "Active Inventory", accentColor: Color(0xFF1B5E20)),
            const SizedBox(height: 12),

            // Batch list
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
                  double freshnessValue =
                      (double.tryParse(freshness) ?? 100) / 100;

                  return StaggeredListItem(
                    index: index,
                    child: GlassCard(
                      padding: const EdgeInsets.all(16),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(20),
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
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                  color: const Color(0xFF1B5E20)
                                      .withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(14)),
                              child: const Icon(Icons.inventory_2_rounded,
                                  color: Color(0xFF1B5E20)),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(id,
                                      style: const TextStyle(
                                          fontWeight: FontWeight.w700,
                                          fontSize: 15)),
                                  const SizedBox(height: 2),
                                  Text("$type • $weight",
                                      style: TextStyle(
                                          color: Colors.grey[500],
                                          fontSize: 12)),
                                  Text("Date: $date",
                                      style: TextStyle(
                                          fontSize: 11,
                                          color: Colors.grey[400])),
                                  const SizedBox(height: 6),
                                  // Freshness indicator
                                  Row(
                                    children: [
                                      Expanded(
                                        child: ClipRRect(
                                          borderRadius:
                                              BorderRadius.circular(4),
                                          child: TweenAnimationBuilder<double>(
                                            tween: Tween(
                                                begin: 0, end: freshnessValue),
                                            duration: const Duration(
                                                milliseconds: 1200),
                                            curve: Curves.easeOutCubic,
                                            builder: (context, value, _) =>
                                                LinearProgressIndicator(
                                              value: value,
                                              backgroundColor: Colors.grey[200],
                                              color: freshnessValue > 0.7
                                                  ? const Color(0xFF4CAF50)
                                                  : freshnessValue > 0.4
                                                      ? const Color(0xFFFF9800)
                                                      : const Color(0xFFEF5350),
                                              minHeight: 5,
                                            ),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Text("$freshness%",
                                          style: const TextStyle(
                                              fontSize: 11,
                                              color: Color(0xFF4CAF50),
                                              fontWeight: FontWeight.w700)),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 10, vertical: 5),
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      colors: status == "Ready"
                                          ? [
                                              const Color(0xFF4CAF50),
                                              const Color(0xFF66BB6A)
                                            ]
                                          : [
                                              const Color(0xFFFF9800),
                                              const Color(0xFFFFA726)
                                            ],
                                    ),
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: Text(status,
                                      style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 10,
                                          fontWeight: FontWeight.w700)),
                                ),
                                const SizedBox(height: 10),
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.location_on_rounded,
                                        size: 14, color: Colors.blue[400]),
                                    Text("Track",
                                        style: TextStyle(
                                            color: Colors.blue[400],
                                            fontSize: 12,
                                            fontWeight: FontWeight.w600)),
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

            // Pagination
            Container(
              margin: const EdgeInsets.only(top: 10),
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 20),
              decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(30),
                  boxShadow: [
                    BoxShadow(
                        color: Colors.black.withValues(alpha: 0.04),
                        blurRadius: 10)
                  ]),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  IconButton(
                      icon: const Icon(Icons.arrow_back_ios_rounded, size: 16),
                      onPressed: _currentPage > 1
                          ? () => setState(() => _currentPage--)
                          : null),
                  Text("Page $_currentPage of $totalPages",
                      style: const TextStyle(fontWeight: FontWeight.w700)),
                  IconButton(
                      icon:
                          const Icon(Icons.arrow_forward_ios_rounded, size: 16),
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
            StaggeredListItem(
              index: 0,
              child: Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [
                      Color(0xFF1B5E20),
                      Color(0xFF2E7D32),
                      Color(0xFF43A047)
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF1B5E20).withValues(alpha: 0.3),
                      blurRadius: 20,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: const Icon(Icons.fingerprint_rounded,
                          color: Colors.white, size: 28),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text("Create Digital Passport",
                              style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 20,
                                  fontWeight: FontWeight.w700)),
                          const SizedBox(height: 4),
                          Text("Server-signed QR traceability release",
                              style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.7),
                                  fontSize: 12)),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.refresh_rounded,
                          color: Colors.white),
                      tooltip: "Clear Form",
                      onPressed: _resetCreateForm,
                    )
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Form card
            GlassCard(
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  TextFormField(
                    controller: _batchIdController,
                    decoration: const InputDecoration(
                        labelText: "Batch ID",
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.qr_code_rounded)),
                    validator: (v) => v!.isEmpty ? "Batch ID Required" : null,
                  ),
                  const SizedBox(height: 15),
                  DropdownButtonFormField<String>(
                    value: _selectedProductType,
                    decoration: const InputDecoration(
                        labelText: "Product Type",
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.fastfood_rounded)),
                    items: _productTypes
                        .map((type) =>
                            DropdownMenuItem(value: type, child: Text(type)))
                        .toList(),
                    onChanged: (val) =>
                        setState(() => _selectedProductType = val),
                    validator: (v) => v == null ? "Select Product Type" : null,
                  ),
                  const SizedBox(height: 15),
                  TextFormField(
                    controller: _weightController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                        labelText: "Weight (kg)",
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.scale_rounded)),
                    validator: (v) => v!.isEmpty ? "Required" : null,
                  ),
                  const SizedBox(height: 15),
                  TextFormField(
                    controller: _originController,
                    decoration: const InputDecoration(
                        labelText: "Farm Origin",
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.agriculture_rounded)),
                    validator: (v) => v!.isEmpty ? "Required" : null,
                  ),
                  const SizedBox(height: 15),
                  TextFormField(
                    controller: _factoryController,
                    decoration: const InputDecoration(
                        labelText: "Processing Factory",
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.factory_rounded)),
                    validator: (v) => v!.isEmpty ? "Required" : null,
                  ),
                  const SizedBox(height: 15),
                  TextFormField(
                    controller: _certificateAuthorityController,
                    decoration: const InputDecoration(
                        labelText: "Certificate Authority",
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.verified_user_rounded)),
                    validator: (v) =>
                        v!.trim().isEmpty ? "Certificate authority required" : null,
                  ),
                  const SizedBox(height: 15),
                  TextFormField(
                    controller: _certificateNoController,
                    decoration: const InputDecoration(
                        labelText: "Batch Certificate No",
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.badge_rounded)),
                    validator: (v) =>
                        v!.trim().isEmpty ? "Certificate number required" : null,
                  ),
                  const SizedBox(height: 15),
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _locationController,
                          readOnly: true,
                          decoration: const InputDecoration(
                              labelText: "Current Factory Address",
                              border: OutlineInputBorder(),
                              prefixIcon: Icon(Icons.location_on_rounded)),
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
                            backgroundColor: const Color(0xFF1565C0),
                            foregroundColor: Colors.white),
                        child: _isGettingLocation
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(
                                    color: Colors.white, strokeWidth: 2))
                            : const Icon(Icons.factory_rounded),
                      ),
                    ],
                  ),
                  const SizedBox(height: 15),
                  InkWell(
                    onTap: () async {
                      final picked = await showDatePicker(
                          context: context,
                          initialDate: _certificateValidUntil,
                          firstDate: DateTime.now().subtract(
                            const Duration(days: 365),
                          ),
                          lastDate: DateTime(2035));
                      if (picked != null) {
                        setState(() => _certificateValidUntil = picked);
                      }
                    },
                    child: InputDecorator(
                      decoration: const InputDecoration(
                          labelText: "Certificate Valid Until",
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.verified_rounded)),
                      child: Text(
                          DateFormat('yyyy-MM-dd')
                              .format(_certificateValidUntil)),
                    ),
                  ),
                  const SizedBox(height: 15),
                  InkWell(
                    onTap: () async {
                      final picked = await showDatePicker(
                          context: context,
                          initialDate: _selectedDate,
                          firstDate: DateTime(2020),
                          lastDate: DateTime(2030));
                      if (picked != null) {
                        setState(() => _selectedDate = picked);
                      }
                    },
                    child: InputDecorator(
                      decoration: const InputDecoration(
                          labelText: "Slaughter Date",
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.calendar_month_rounded)),
                      child:
                          Text(DateFormat('yyyy-MM-dd').format(_selectedDate)),
                    ),
                  ),
                  const SizedBox(height: 15),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1565C0).withValues(alpha: 0.06),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: const Color(0xFF1565C0).withValues(alpha: 0.18),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          "Batch Certificate Document",
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF2C3E50),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          _batchCertificateFile == null
                              ? "No batch-specific file selected. The verified processor certificate on your profile will be used."
                              : "Selected: ${_batchCertificateFile!.name}",
                          style: TextStyle(
                            color: Colors.grey[700],
                            fontSize: 13,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: _pickBatchCertificate,
                                icon: const Icon(Icons.upload_file_rounded),
                                label: Text(_batchCertificateFile == null
                                    ? "UPLOAD CERTIFICATE"
                                    : "REPLACE FILE"),
                              ),
                            ),
                            if (_batchCertificateFile != null) ...[
                              const SizedBox(width: 10),
                              IconButton(
                                onPressed: () {
                                  setState(() => _batchCertificateFile = null);
                                },
                                tooltip: 'Use profile certificate instead',
                                icon: const Icon(Icons.clear_rounded),
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Generate button
            SizedBox(
              width: double.infinity,
              height: 54,
              child: ElevatedButton.icon(
                onPressed: () {
                  if (_formKey.currentState!.validate()) {
                    setState(() {
                      _generatedQRData =
                          "BATCH:${_batchIdController.text}|SIG:SERVER_PENDING";
                    });
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                        content: Text("Batch prepared. Secure QR will be signed by the server when saved.")));
                  }
                },
                icon: const Icon(Icons.fingerprint_rounded),
                label: const Text("PREPARE SERVER QR"),
                style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1B5E20),
                    foregroundColor: Colors.white),
              ),
            ),

            // QR Code result (with scale animation)
            if (_generatedQRData != null) ...[
              const SizedBox(height: 30),
              TweenAnimationBuilder<double>(
                tween: Tween(begin: 0.0, end: 1.0),
                duration: const Duration(milliseconds: 600),
                curve: Curves.easeOutBack,
                builder: (context, value, child) {
                  return Transform.scale(
                    scale: value,
                    child: Opacity(opacity: value, child: child),
                  );
                },
                child: Center(
                  child: Column(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          border: Border.all(
                              color: const Color(0xFF1B5E20)
                                  .withValues(alpha: 0.3)),
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF1B5E20)
                                  .withValues(alpha: 0.1),
                              blurRadius: 20,
                              offset: const Offset(0, 8),
                            ),
                          ],
                        ),
                        child: QrImageView(
                            data: _generatedQRData!,
                            version: QrVersions.auto,
                            size: 200.0),
                      ),
                      const SizedBox(height: 24),
                      SizedBox(
                        width: double.infinity,
                        height: 54,
                        child: ElevatedButton.icon(
                          onPressed:
                              _isSavingBatch ? null : _saveBatchToInventory,
                          icon: const Icon(Icons.save_rounded),
                          label: _isSavingBatch
                              ? const CircularProgressIndicator(
                                  color: Colors.white)
                              : const Text("SAVE TO INVENTORY"),
                          style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF1565C0),
                              foregroundColor: Colors.white),
                        ),
                      ),
                    ],
                  ),
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
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(32),
              decoration: BoxDecoration(
                color: const Color(0xFF1B5E20).withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(30),
              ),
              child: Icon(Icons.description_rounded,
                  size: 72,
                  color: const Color(0xFF1B5E20).withValues(alpha: 0.4)),
            ),
            const SizedBox(height: 24),
            const Text("Export Manifests",
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            Text("Download production reports and audit logs.",
                style: TextStyle(color: Colors.grey[500])),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              height: 54,
              child: ElevatedButton.icon(
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
                    : const Icon(Icons.download_rounded),
                label: Text(_isDownloadingPdf
                    ? "Downloading..."
                    : "Download Weekly Report (PDF)"),
                style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1B5E20),
                    foregroundColor: Colors.white),
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              height: 54,
              child: OutlinedButton.icon(
                onPressed: () {
                  Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (context) => const AuditLogScreen()));
                },
                icon: const Icon(Icons.history_rounded),
                label: const Text("View Audit Logs"),
                style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF1B5E20),
                    side: const BorderSide(color: Color(0xFF1B5E20))),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final titles = ["Dashboard", "Create Batch", "Reports"];

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: GradientAppBar(
        title: titles[_selectedIndex],
        gradientColors: const [
          Color(0xFF1B5E20),
          Color(0xFF2E7D32),
          Color(0xFF43A047),
        ],
      ),
      drawer: _buildDrawer(),
      body: GradientBackground(
        colors: GradientBackground.processor,
        child: AnimatedViewSwitcher(
          child: KeyedSubtree(
            key: ValueKey<int>(_selectedIndex),
            child: _selectedIndex == 0
                ? _buildInventoryView()
                : _selectedIndex == 1
                    ? _buildCreateBatchView()
                    : _buildReportsView(),
          ),
        ),
      ),
    );
  }
}

// --- BATCH DETAIL SCREEN (UNCHANGED) ---
/// Detailed processor view for a single batch timeline and metadata.
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
      final token = await AuthSessionService.getToken();
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
            Center(
              child: QrImageView(
                data: (widget.batchData['qr_code_payload'] ??
                        widget.batchData['batch_id'] ??
                        widget.batchData.toString())
                    .toString(),
                size: 150,
                version: QrVersions.auto,
              ),
            ),
            const SizedBox(height: 20),
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
                    Builder(builder: (context) {
                      List<String> allowedOptions = [];

                      if (_status == 'Processing') {
                        allowedOptions = ['Processing', 'Ready'];
                      } else {
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
                                      color: allowedOptions.length > 1
                                          ? Colors.green
                                          : Colors.grey),
                                  underline: Container(
                                      height: 2,
                                      color: allowedOptions.length > 1
                                          ? Colors.green
                                          : Colors.grey[300]),
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

// --- PROFILE SCREEN (UNCHANGED) ---
/// Profile editing screen for processor account and company details.
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
  bool _hasChanges = false;
  int _profileImageVersion = DateTime.now().millisecondsSinceEpoch;

  late TextEditingController _nameController;
  late TextEditingController _phoneController;
  late TextEditingController _companyRegController;
  late TextEditingController _halalCertController;
  late TextEditingController _addressController;

  @override
  void initState() {
    super.initState();
    _userData = widget.userData;
    _nameController = TextEditingController(text: _userData['name']);
    _phoneController = TextEditingController(
        text: _userData['phone_number'] ?? _userData['phone']);
    _companyRegController = TextEditingController(
        text: _userData['processor_profile']?['company_reg_no'] ?? '');
    _halalCertController = TextEditingController(
        text: _userData['processor_profile']?['halal_cert_no'] ?? '');
    _addressController = TextEditingController(
        text: _userData['processor_profile']?['factory_address'] ?? '');
    _nameController.addListener(_markDirty);
    _phoneController.addListener(_markDirty);
    _companyRegController.addListener(_markDirty);
    _halalCertController.addListener(_markDirty);
    _addressController.addListener(_markDirty);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _companyRegController.dispose();
    _halalCertController.dispose();
    _addressController.dispose();
    super.dispose();
  }

  void _markDirty() {
    if (!_isEditing || _hasChanges) return;
    setState(() => _hasChanges = true);
  }

  void _resetDraft() {
    _nameController.text = _userData['name'] ?? "";
    _phoneController.text =
        _userData['phone_number'] ?? _userData['phone'] ?? "";
    _companyRegController.text =
        _userData['processor_profile']?['company_reg_no'] ?? '';
    _halalCertController.text =
        _userData['processor_profile']?['halal_cert_no'] ?? '';
    _addressController.text =
        _userData['processor_profile']?['factory_address'] ?? '';
    _profileImage = null;
    _hasChanges = false;
  }

  void _toggleEditing() {
    setState(() {
      _isEditing = !_isEditing;
      if (!_isEditing) _resetDraft();
    });
  }

  Future<void> _pickImage() async {
    if (!_isEditing) return;
    final ImagePicker picker = ImagePicker();
    final XFile? image = await picker.pickImage(source: ImageSource.gallery);
    if (image != null) {
      setState(() {
        _profileImage = File(image.path);
        _hasChanges = true;
      });
    }
  }

  Future<void> _updateProfile() async {
    setState(() => _isSaving = true);
    try {
      final token = await AuthSessionService.getToken();

      var request =
          http.MultipartRequest('POST', Uri.parse('$baseUrl/user/update'));
      request.headers['Authorization'] = 'Bearer $token';
      request.headers['Accept'] = 'application/json';
      request.fields['name'] = _nameController.text;
      request.fields['phone_number'] = _phoneController.text;
      request.fields['company_reg_no'] = _companyRegController.text;
      request.fields['halal_cert_no'] = _halalCertController.text;
      request.fields['factory_address'] = _addressController.text;

      if (_profileImage != null) {
        request.files.add(await http.MultipartFile.fromPath(
            'profile_image', _profileImage!.path));
      }

      var streamedResponse = await request.send();
      var response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200) {
        final updatedData =
            (jsonDecode(response.body)['user'] as Map).cast<String, dynamic>();
        final nextVersion = DateTime.now().millisecondsSinceEpoch;
        await ProfileImageService.evict(
          previousPath: _userData['profile_image'],
          nextPath: updatedData['profile_image'],
          currentVersion: _profileImageVersion,
          nextVersion: nextVersion,
        );
        if (!mounted) return;
        setState(() {
          _profileImageVersion = nextVersion;
          _userData = updatedData;
          _isEditing = false;
          _profileImage = null;
          _hasChanges = false;
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
        String message = "Update Failed";
        try {
          final body = jsonDecode(response.body);
          if (body is Map && body['message'] != null) {
            message = body['message'].toString();
          }
        } catch (_) {}
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(message), backgroundColor: Colors.red));
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
      final imageUrl = ProfileImageService.buildUrl(
        _userData['profile_image'],
        version: _profileImageVersion,
      );
      if (imageUrl != null) {
        backgroundImage = NetworkImage(imageUrl);
      }
    }

    String companyReg =
        _userData['processor_profile']?['company_reg_no'] ?? 'N/A';
    String halalCert =
        _userData['processor_profile']?['halal_cert_no'] ?? 'N/A';
    String address =
        _userData['processor_profile']?['factory_address'] ?? 'N/A';

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: GradientAppBar(
        title: "Company Profile",
        gradientColors: const [
          Color(0xFF2E7D32),
          Color(0xFF388E3C),
          Color(0xFF43A047),
        ],
        actions: [
          IconButton(
            icon: AnimatedSwitcher(
              duration: const Duration(milliseconds: 180),
              transitionBuilder: (child, animation) => RotationTransition(
                turns: Tween<double>(begin: 0.85, end: 1).animate(animation),
                child: FadeTransition(opacity: animation, child: child),
              ),
              child: Icon(
                _isEditing ? Icons.close_rounded : Icons.edit_rounded,
                key: ValueKey(_isEditing),
                color: Colors.white,
              ),
            ),
            onPressed: _toggleEditing,
          ),
          const SizedBox(width: 10),
        ],
      ),
      body: GradientBackground(
        colors: GradientBackground.processor,
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Column(
            children: [
              const SizedBox(height: 30),
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 250),
                transitionBuilder: (child, animation) => FadeTransition(
                  opacity: animation,
                  child: SizeTransition(sizeFactor: animation, child: child),
                ),
                child: _isEditing
                    ? Container(
                        key: const ValueKey('editing-banner'),
                        margin: const EdgeInsets.only(bottom: 14),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 8),
                        decoration: BoxDecoration(
                          color: const Color(0xFF2E7D32).withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color:
                                const Color(0xFF2E7D32).withValues(alpha: 0.35),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.edit_note_rounded,
                                size: 18, color: Color(0xFF2E7D32)),
                            const SizedBox(width: 8),
                            Text(
                              _hasChanges
                                  ? "Unsaved changes"
                                  : "Editing mode enabled",
                              style: const TextStyle(
                                  color: Color(0xFF1B5E20),
                                  fontWeight: FontWeight.w600),
                            ),
                          ],
                        ),
                      )
                    : const SizedBox.shrink(key: ValueKey('view-banner')),
              ),
              GlassCard(
                child: Padding(
                  padding: const EdgeInsets.all(25.0),
                  child: Column(
                    children: [
                      GestureDetector(
                        onTap: _pickImage,
                        child: Stack(
                          alignment: Alignment.bottomRight,
                          children: [
                            AnimatedContainer(
                              duration: const Duration(milliseconds: 220),
                              curve: Curves.easeOutCubic,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(
                                    color: const Color(0xFF2E7D32).withValues(
                                        alpha: _isEditing ? 0.65 : 0.3),
                                    width: _isEditing ? 4 : 3),
                                boxShadow: _isEditing
                                    ? [
                                        BoxShadow(
                                          color: const Color(0xFF2E7D32)
                                              .withValues(alpha: 0.25),
                                          blurRadius: 18,
                                          spreadRadius: 1,
                                        )
                                      ]
                                    : null,
                              ),
                              child: CircleAvatar(
                                radius: 50,
                                backgroundColor: const Color(0xFF2E7D32)
                                    .withValues(alpha: 0.1),
                                backgroundImage: backgroundImage,
                                onBackgroundImageError: backgroundImage != null
                                    ? (e, s) => debugPrint(
                                        'Profile image load error: $e')
                                    : null,
                                child: backgroundImage == null
                                    ? const Text("AP",
                                        style: TextStyle(
                                            fontSize: 30,
                                            fontWeight: FontWeight.bold,
                                            color: Color(0xFF2E7D32)))
                                    : null,
                              ),
                            ),
                            if (_isEditing)
                              AnimatedScale(
                                duration: const Duration(milliseconds: 180),
                                scale: _hasChanges ? 1.08 : 1,
                                child: Container(
                                  padding: const EdgeInsets.all(6),
                                  decoration: const BoxDecoration(
                                    color: Color(0xFF2E7D32),
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(Icons.camera_alt,
                                      size: 16, color: Colors.white),
                                ),
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
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF37474F)),
                          decoration: InputDecoration(
                            isDense: true,
                            enabledBorder: UnderlineInputBorder(
                                borderSide: BorderSide(
                                    color: const Color(0xFF2E7D32)
                                        .withValues(alpha: 0.3))),
                            focusedBorder: const UnderlineInputBorder(
                                borderSide:
                                    BorderSide(color: Color(0xFF2E7D32))),
                          ),
                        )
                      else
                        Text(
                          _userData['name'] ?? "Company Name",
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF37474F)),
                        ),
                      const SizedBox(height: 5),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xFF2E7D32).withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                              color: const Color(0xFF2E7D32)
                                  .withValues(alpha: 0.4)),
                        ),
                        child: Text("License: $companyReg",
                            style: const TextStyle(
                                fontSize: 12,
                                color: Color(0xFF2E7D32),
                                fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 25),
              _buildSectionLabel("Contact Information"),
              GlassCard(
                child: Column(
                  children: [
                    _buildInfoTile(
                        icon: Icons.email_outlined,
                        label: "Email",
                        value: _userData['email'] ?? "N/A"),
                    Divider(
                        height: 1, color: Colors.grey.withValues(alpha: 0.2)),
                    _buildInfoTile(
                        icon: Icons.phone_outlined,
                        label: "Phone",
                        value: _userData['phone_number'] ??
                            _userData['phone'] ??
                            "N/A",
                        isEditable: _isEditing,
                        controller: _phoneController),
                  ],
                ),
              ),
              const SizedBox(height: 25),
              _buildSectionLabel("Factory Details"),
              GlassCard(
                child: Column(
                  children: [
                    _buildInfoTile(
                        icon: Icons.business_outlined,
                        label: "Company Reg No",
                        value: companyReg,
                        isEditable: _isEditing,
                        controller: _companyRegController),
                    Divider(
                        height: 1, color: Colors.grey.withValues(alpha: 0.2)),
                    _buildInfoTile(
                        icon: Icons.location_on_outlined,
                        label: "Address",
                        value: address,
                        isEditable: _isEditing,
                        controller: _addressController),
                    Divider(
                        height: 1, color: Colors.grey.withValues(alpha: 0.2)),
                    _buildInfoTile(
                        icon: Icons.verified_user_outlined,
                        label: "Halal Cert No",
                        value: halalCert,
                        isEditable: _isEditing,
                        controller: _halalCertController),
                  ],
                ),
              ),
              const SizedBox(height: 100),
            ],
          ),
        ),
      ),
      floatingActionButton: AnimatedSaveFab(
        isVisible: _isEditing,
        isSaving: _isSaving,
        hasChanges: _hasChanges,
        color: const Color(0xFF2E7D32),
        heroTag: 'processor-profile-save',
        onPressed: _updateProfile,
      ),
    );
  }

  Widget _buildSectionLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(left: 10, bottom: 10),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Text(text,
            style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: Color(0xFF1B5E20),
                letterSpacing: 0.5)),
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
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
      leading: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: const Color(0xFF2E7D32).withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(icon, color: const Color(0xFF2E7D32), size: 22),
      ),
      title:
          Text(label, style: TextStyle(fontSize: 12, color: Colors.grey[600])),
      subtitle: isEditable && controller != null
          ? TextField(
              controller: controller,
              style: const TextStyle(
                  fontWeight: FontWeight.bold, color: Color(0xFF37474F)),
              decoration: InputDecoration(
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(vertical: 8),
                enabledBorder: UnderlineInputBorder(
                    borderSide: BorderSide(
                        color: const Color(0xFF2E7D32).withValues(alpha: 0.3))),
                focusedBorder: const UnderlineInputBorder(
                    borderSide: BorderSide(color: Color(0xFF2E7D32))),
              ),
            )
          : Text(value,
              style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                  color: Color(0xFF37474F))),
    );
  }
}
