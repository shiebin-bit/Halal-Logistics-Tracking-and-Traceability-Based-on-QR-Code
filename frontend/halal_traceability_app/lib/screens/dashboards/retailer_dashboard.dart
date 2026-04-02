import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:image_picker/image_picker.dart';

import '../../config.dart';
import '../../services/auth_session_service.dart';
import '../../services/profile_image_service.dart';
import '../../services/qr_payload_service.dart';
import 'widgets/dashboard_widgets.dart';

/// Retailer workspace for incoming shipments, scanning, and inventory control.
class RetailerDashboard extends StatefulWidget {
  const RetailerDashboard({super.key});

  @override
  State<RetailerDashboard> createState() => _RetailerDashboardState();
}

class _RetailerDashboardState extends State<RetailerDashboard> {
  int _selectedIndex =
      0; // 0: Incoming, 1: Scanner, 2: My Inventory, 3: Reports

  // --- GLOBAL DATA ---
  Map<String, dynamic> _userData = {
    "name": "Loading...",
    "email": "...",
    "phone": "...",
    "profile_image": null,
    "retailer_profile": {
      "store_name": "...",
      "business_reg_no": "...",
      "outlet_address": "..."
    }
  };

  // --- STATE DATA ---
  List<dynamic> _incomingShipments = [];
  List<dynamic> _myInventory = [];
  bool _isLoading = true;
  bool _isSubmitting = false;
  int _profileImageVersion = DateTime.now().millisecondsSinceEpoch;

  // --- Quality Check ---
  String? _scannedBatchId;
  final TextEditingController _arrivalTemperatureController =
      TextEditingController();
  final TextEditingController _rejectionReasonController =
      TextEditingController();
  final Map<String, bool> _qualityChecks = {
    "packaging_intact": false,
    "temperature_check": false,
    "halal_cert_present": false,
    "quantity_match": false,
    "expiry_valid": false,
  };

  @override
  void initState() {
    super.initState();
    _fetchProfile();
    _fetchIncomingShipments();
    _fetchMyInventory();
  }

  // --- ALL API CALLS (UNCHANGED) ---

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
        if (nextUserData['retailer_profile'] == null) {
          nextUserData['retailer_profile'] = {};
        }
        final nextVersion = DateTime.now().millisecondsSinceEpoch;
        await ProfileImageService.evict(
          previousPath: _userData['profile_image'],
          nextPath: nextUserData['profile_image'],
          currentVersion: _profileImageVersion,
          nextVersion: nextVersion,
        );
        setState(() {
          _profileImageVersion = nextVersion;
          _userData = nextUserData;
        });
      }
    } catch (e) {
      debugPrint("Profile Error: $e");
    }
  }

  Future<void> _fetchIncomingShipments() async {
    setState(() => _isLoading = true);
    try {
      final token = await _getToken();
      final response = await http.get(
        Uri.parse('$baseUrl/retailer/incoming'),
        headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'application/json'
        },
      );

      if (response.statusCode == 200) {
        setState(() {
          _incomingShipments = jsonDecode(response.body)['data'] ?? [];
          _isLoading = false;
        });
      } else {
        setState(() {
          _incomingShipments = [
            {
              "batch_id": "HT-DEMO-001",
              "product_type": "Whole Chicken",
              "weight": "500kg",
              "origin": "Ayam Fresh Farm",
              "status": "In Transit",
              "driver": "Ahmad",
              "phone": "+60123456789"
            },
            {
              "batch_id": "HT-DEMO-002",
              "product_type": "Wings",
              "weight": "200kg",
              "origin": "AgroMas",
              "status": "Ready for Pickup",
              "driver": "Ali",
              "phone": "+60198765432"
            }
          ];
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _fetchMyInventory() async {
    try {
      final token = await _getToken();
      final response = await http.get(
        Uri.parse('$baseUrl/retailer/inventory'),
        headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'application/json'
        },
      );
      if (response.statusCode == 200) {
        setState(() {
          _myInventory = jsonDecode(response.body)['data'] ?? [];
        });
      }
    } catch (e) {
      debugPrint("Inventory Error: $e");
    }
  }

  Future<void> _scanQR() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const RetailerScannerPage()),
    );

    final batchId = QrPayloadService.extractBatchId(result?.toString());
    if (batchId == null) {
      if (!mounted || result == null) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Invalid batch QR code format.')),
      );
      return;
    }

    if (!mounted) return;
    setState(() {
      _scannedBatchId = batchId;
      _selectedIndex = 1;
    });
  }

  Future<void> _acceptShipment() async {
    if (_scannedBatchId == null) return;
    if (!_qualityChecks.values.every((v) => v)) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text("Complete all quality checks before accepting!")));
      return;
    }
    if (_arrivalTemperatureController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text("Arrival temperature is required before accepting.")));
      return;
    }

    setState(() => _isSubmitting = true);
    try {
      final token = await _getToken();
      final response = await http.post(
        Uri.parse('$baseUrl/retailer/accept'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: jsonEncode({
          "batch_id": _scannedBatchId,
          "quality_checks": _qualityChecks,
          "arrival_temperature": _arrivalTemperatureController.text.trim(),
        }),
      );
      if (!mounted) return;
      if (response.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Shipment Accepted Successfully!")));
        _resetScanData();
        _fetchIncomingShipments();
        _fetchMyInventory();
      } else {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text("Failed to accept")));
      }
    } catch (e) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text("Connection Error")));
    } finally {
      setState(() => _isSubmitting = false);
    }
  }

  Future<void> _rejectShipment() async {
    if (_scannedBatchId == null) return;
    if (_arrivalTemperatureController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text("Arrival temperature is required before rejecting.")));
      return;
    }
    if (_rejectionReasonController.text.trim().length < 5) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text("Enter a rejection reason with a few details.")));
      return;
    }

    setState(() => _isSubmitting = true);
    try {
      final token = await _getToken();
      final response = await http.post(
        Uri.parse('$baseUrl/retailer/reject'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: jsonEncode({
          "batch_id": _scannedBatchId,
          "arrival_temperature": _arrivalTemperatureController.text.trim(),
          "reason": _rejectionReasonController.text.trim(),
          "severity": "moderate",
        }),
      );
      if (!mounted) return;
      if (response.statusCode == 200) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text("Shipment Rejected!")));
        _resetScanData();
        _fetchIncomingShipments();
      } else {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text("Failed to reject")));
      }
    } catch (e) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text("Connection Error")));
    } finally {
      setState(() => _isSubmitting = false);
    }
  }

  void _resetScanData() {
    setState(() {
      _scannedBatchId = null;
      _qualityChecks.updateAll((key, value) => false);
      _arrivalTemperatureController.clear();
      _rejectionReasonController.clear();
    });
  }

  @override
  void dispose() {
    _arrivalTemperatureController.dispose();
    _rejectionReasonController.dispose();
    super.dispose();
  }

  Future<void> _logout() async {
    await AuthSessionService.clearAuthSession();
    if (mounted) {
      Navigator.pushNamedAndRemoveUntil(context, '/login', (route) => false);
    }
  }

  // --- REDESIGNED UI BUILDERS ---

  Widget _buildDrawer() {
    final drawerImageUrl = ProfileImageService.buildUrl(
      _userData['profile_image'],
      version: _profileImageVersion,
    );
    final ImageProvider? drawerImage =
        drawerImageUrl != null ? NetworkImage(drawerImageUrl) : null;

    String storeName = _userData['retailer_profile']?['store_name'] ?? 'Store';

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
                    Color(0xFFBF360C),
                    Color(0xFFE65100),
                    Color(0xFFFF6D00)
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
                        ? const Icon(Icons.store_rounded,
                            size: 32, color: Colors.white)
                        : null,
                  ),
                  const SizedBox(height: 14),
                  Text(_userData['name'] ?? "Manager",
                      style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                          fontSize: 18)),
                  const SizedBox(height: 2),
                  Text(storeName,
                      style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.8),
                          fontSize: 13)),
                ],
              ),
            ),
            const SizedBox(height: 8),
            _buildDrawerItem(
                Icons.local_shipping_rounded, "Incoming Shipments", 0),
            _buildDrawerItem(
                Icons.qr_code_scanner_rounded, "Receive / Inspect", 1),
            _buildDrawerItem(Icons.inventory_rounded, "My Inventory", 2),
            _buildDrawerItem(Icons.analytics_outlined, "Reports", 3),
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
                ? const Color(0xFFE65100).withValues(alpha: 0.1)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon,
              color: isSelected ? const Color(0xFFE65100) : Colors.grey[600],
              size: 22),
        ),
        title: Text(title,
            style: TextStyle(
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                color:
                    isSelected ? const Color(0xFFE65100) : Colors.grey[700])),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        selected: isSelected,
        selectedTileColor: const Color(0xFFE65100).withValues(alpha: 0.04),
        onTap: () {
          setState(() => _selectedIndex = index);
          Navigator.pop(context);
        },
      ),
    );
  }

  Widget _buildIncomingView() {
    if (_isLoading) return const ShimmerLoader(itemCount: 4);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      physics: const AlwaysScrollableScrollPhysics(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header banner
          StaggeredListItem(
            index: 0,
            child: Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [
                    Color(0xFFBF360C),
                    Color(0xFFE65100),
                    Color(0xFFFF6D00)
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFFE65100).withValues(alpha: 0.3),
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
                    child: const Icon(Icons.local_shipping_rounded,
                        color: Colors.white, size: 28),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text("Receiving Dock",
                            style: TextStyle(
                                color: Colors.white,
                                fontSize: 20,
                                fontWeight: FontWeight.w700)),
                        Text("${_incomingShipments.length} shipments pending",
                            style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.7),
                                fontSize: 13)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),

          // Stat cards
          StaggeredListItem(
            index: 1,
            child: Row(
              children: [
                AnimatedStatCard(
                    title: "Pending Receipt",
                    value: "${_incomingShipments.length}",
                    color: const Color(0xFFE65100),
                    icon: Icons.hourglass_top_rounded),
                const SizedBox(width: 12),
                AnimatedStatCard(
                    title: "Inventory",
                    value: "${_myInventory.length}",
                    color: const Color(0xFF4CAF50),
                    icon: Icons.check_circle_rounded),
              ],
            ),
          ),
          const SizedBox(height: 28),

          const SectionTitle(
              title: "Incoming Shipments", accentColor: Color(0xFFE65100)),
          const SizedBox(height: 12),

          if (_incomingShipments.isEmpty)
            Center(
              child: Padding(
                padding: const EdgeInsets.all(40),
                child: Column(
                  children: [
                    Icon(Icons.inbox_rounded,
                        size: 80, color: Colors.grey[300]),
                    const SizedBox(height: 16),
                    Text("No incoming shipments",
                        style: TextStyle(
                            color: Colors.grey[400],
                            fontWeight: FontWeight.w600)),
                  ],
                ),
              ),
            )
          else
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _incomingShipments.length,
              itemBuilder: (context, index) {
                final shipment = _incomingShipments[index];
                return StaggeredListItem(
                  index: 2 + index,
                  child: GlassCard(
                    padding: const EdgeInsets.all(18),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(children: [
                              Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFE65100)
                                      .withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: const Icon(Icons.inventory_2_rounded,
                                    color: Color(0xFFE65100), size: 22),
                              ),
                              const SizedBox(width: 12),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(shipment['batch_id'],
                                      style: const TextStyle(
                                          fontWeight: FontWeight.w700,
                                          fontSize: 16)),
                                  Text(
                                      "${shipment['product_type']} • ${shipment['weight']}",
                                      style: TextStyle(
                                          color: Colors.grey[500],
                                          fontSize: 12)),
                                ],
                              ),
                            ]),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 5),
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: shipment['status'] == "In Transit"
                                      ? [
                                          const Color(0xFF1565C0),
                                          const Color(0xFF42A5F5)
                                        ]
                                      : [
                                          const Color(0xFF4CAF50),
                                          const Color(0xFF66BB6A)
                                        ],
                                ),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(shipment['status'],
                                  style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 10,
                                      fontWeight: FontWeight.w700)),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Icon(Icons.agriculture_rounded,
                                size: 14, color: Colors.grey[400]),
                            const SizedBox(width: 4),
                            Text("From: ${shipment['origin']}",
                                style: TextStyle(
                                    color: Colors.grey[500], fontSize: 12)),
                            const SizedBox(width: 16),
                            Icon(Icons.person_rounded,
                                size: 14, color: Colors.grey[400]),
                            const SizedBox(width: 4),
                            Text("Driver: ${shipment['driver']}",
                                style: TextStyle(
                                    color: Colors.grey[500], fontSize: 12)),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
        ],
      ),
    );
  }

  Widget _buildScannerView() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (_scannedBatchId == null)
            PulseWidget(
              child: InkWell(
                onTap: _scanQR,
                borderRadius: BorderRadius.circular(24),
                child: Container(
                  height: 160,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [
                        Color(0xFFBF360C),
                        Color(0xFFE65100),
                        Color(0xFFFF6D00)
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [
                      BoxShadow(
                          color: const Color(0xFFE65100).withValues(alpha: 0.3),
                          blurRadius: 20,
                          offset: const Offset(0, 8)),
                    ],
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: const Icon(Icons.qr_code_scanner_rounded,
                            size: 44, color: Colors.white),
                      ),
                      const SizedBox(height: 14),
                      const Text("TAP TO SCAN & INSPECT",
                          style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                              fontSize: 16,
                              letterSpacing: 1)),
                    ],
                  ),
                ),
              ),
            )
          else
            GlassCard(
              borderColor: Colors.green.withValues(alpha: 0.3),
              padding: const EdgeInsets.all(18),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.green.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.check_circle_rounded,
                        color: Colors.green, size: 28),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text("Batch Scanned",
                            style: TextStyle(
                                color: Colors.green,
                                fontWeight: FontWeight.w700,
                                fontSize: 12)),
                        Text(_scannedBatchId!,
                            style: const TextStyle(
                                fontWeight: FontWeight.w700, fontSize: 16)),
                      ],
                    ),
                  ),
                  IconButton(
                      icon: Icon(Icons.close_rounded, color: Colors.grey[400]),
                      onPressed: _resetScanData),
                ],
              ),
            ),
          const SizedBox(height: 24),
          if (_scannedBatchId != null) ...[
            const SectionTitle(
                title: "Quality Inspection", accentColor: Color(0xFFE65100)),
            const SizedBox(height: 16),
            GlassCard(
              padding: const EdgeInsets.all(8),
              child: Column(
                children: _qualityChecks.entries.map((entry) {
                  String label = entry.key
                      .replaceAll('_', ' ')
                      .split(' ')
                      .map((w) => "${w[0].toUpperCase()}${w.substring(1)}")
                      .join(' ');
                  return CheckboxListTile(
                    value: entry.value,
                    onChanged: (val) {
                      setState(() => _qualityChecks[entry.key] = val!);
                    },
                    title: Text(label,
                        style: const TextStyle(
                            fontSize: 14, fontWeight: FontWeight.w500)),
                    controlAffinity: ListTileControlAffinity.leading,
                    activeColor: const Color(0xFF4CAF50),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 8),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  );
                }).toList(),
              ),
            ),
            const SizedBox(height: 24),
            TextField(
              controller: _arrivalTemperatureController,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                labelText: "Arrival Temperature (°C)",
                prefixIcon: Icon(Icons.thermostat_rounded),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _rejectionReasonController,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: "Rejection Reason",
                prefixIcon: Icon(Icons.report_problem_rounded),
                alignLabelWithHint: true,
              ),
            ),
            const SizedBox(height: 24),

            // Accept button
            SizedBox(
              height: 54,
              child: ElevatedButton.icon(
                onPressed: _isSubmitting ? null : _acceptShipment,
                icon: const Icon(Icons.check_circle_rounded),
                label: _isSubmitting
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text("ACCEPT SHIPMENT"),
                style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF4CAF50),
                    foregroundColor: Colors.white),
              ),
            ),
            const SizedBox(height: 12),

            // Reject button
            SizedBox(
              height: 54,
              child: OutlinedButton.icon(
                onPressed: _isSubmitting ? null : _rejectShipment,
                icon: const Icon(Icons.cancel_rounded),
                label: const Text("REJECT SHIPMENT"),
                style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFFEF5350),
                    side: const BorderSide(color: Color(0xFFEF5350))),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildInventoryView() {
    if (_myInventory.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.inventory_rounded, size: 80, color: Colors.grey[300]),
            const SizedBox(height: 16),
            Text("No items in inventory",
                style: TextStyle(
                    color: Colors.grey[400],
                    fontSize: 16,
                    fontWeight: FontWeight.w500)),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(20),
      itemCount: _myInventory.length,
      itemBuilder: (context, index) {
        final item = _myInventory[index];
        return StaggeredListItem(
          index: index,
          child: GlassCard(
            padding: const EdgeInsets.all(18),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF4CAF50).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Icon(Icons.check_circle_rounded,
                      color: Color(0xFF4CAF50)),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(item['batch_id'] ?? 'N/A',
                          style: const TextStyle(
                              fontWeight: FontWeight.w700, fontSize: 15)),
                      const SizedBox(height: 2),
                      Text("${item['product_type']} • ${item['weight']}",
                          style:
                              TextStyle(color: Colors.grey[500], fontSize: 12)),
                    ],
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                        colors: [Color(0xFF4CAF50), Color(0xFF66BB6A)]),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Text("Received",
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.w700)),
                ),
              ],
            ),
          ),
        );
      },
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
                color: const Color(0xFFE65100).withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(30),
              ),
              child: Icon(Icons.analytics_rounded,
                  size: 72,
                  color: const Color(0xFFE65100).withValues(alpha: 0.4)),
            ),
            const SizedBox(height: 24),
            const Text("Store Reports",
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            Text("Receiving history and inventory analytics.",
                style: TextStyle(color: Colors.grey[500])),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              height: 54,
              child: ElevatedButton.icon(
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                      content: Text("Report feature coming soon")));
                },
                icon: const Icon(Icons.download_rounded),
                label: const Text("Download Report (PDF)"),
                style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFE65100),
                    foregroundColor: Colors.white),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final titles = [
      "Retailer Hub",
      "Receive & Inspect",
      "My Inventory",
      "Reports"
    ];

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: GradientAppBar(
        title: titles[_selectedIndex],
        gradientColors: const [
          Color(0xFFBF360C),
          Color(0xFFE65100),
          Color(0xFFFF6D00),
        ],
      ),
      drawer: _buildDrawer(),
      body: GradientBackground(
        colors: GradientBackground.retailer,
        child: AnimatedViewSwitcher(
          child: KeyedSubtree(
            key: ValueKey<int>(_selectedIndex),
            child: _selectedIndex == 0
                ? _buildIncomingView()
                : _selectedIndex == 1
                    ? _buildScannerView()
                    : _selectedIndex == 2
                        ? _buildInventoryView()
                        : _buildReportsView(),
          ),
        ),
      ),
    );
  }
}

// --- SCANNER PAGE (UNCHANGED) ---
/// Scanner page that returns decoded batch IDs to the retailer dashboard.
class RetailerScannerPage extends StatefulWidget {
  const RetailerScannerPage({super.key});

  @override
  State<RetailerScannerPage> createState() => _RetailerScannerPageState();
}

class _RetailerScannerPageState extends State<RetailerScannerPage> {
  final MobileScannerController controller = MobileScannerController();

  @override
  Widget build(BuildContext context) {
    final double scanArea = (MediaQuery.of(context).size.width < 400 ||
            MediaQuery.of(context).size.height < 400)
        ? 250.0
        : 300.0;

    return Scaffold(
      appBar: AppBar(
        title: const Text("Scan Delivery QR"),
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: ValueListenableBuilder(
              valueListenable: controller,
              builder: (context, state, child) {
                return Icon(
                  state.torchState == TorchState.on
                      ? Icons.flash_on
                      : Icons.flash_off,
                  color: Colors.white,
                );
              },
            ),
            onPressed: () => controller.toggleTorch(),
          ),
        ],
      ),
      body: Stack(
        children: [
          MobileScanner(
            controller: controller,
            onDetect: (capture) {
              final List<Barcode> barcodes = capture.barcodes;
              for (final barcode in barcodes) {
                if (barcode.rawValue != null) {
                  controller.dispose();
                  Navigator.pop(context, barcode.rawValue);
                  break;
                }
              }
            },
          ),
          CustomPaint(
            painter: _ScannerOverlayPainter(Rect.fromCenter(
              center: Offset(MediaQuery.of(context).size.width / 2,
                  MediaQuery.of(context).size.height / 2),
              width: scanArea,
              height: scanArea,
            )),
            child: Container(),
          ),
          const Positioned(
            bottom: 80,
            left: 0,
            right: 0,
            child: Text(
              "Align Delivery QR within frame",
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white, fontSize: 16),
            ),
          ),
        ],
      ),
    );
  }
}

/// Paints the scanning-frame overlay for the retailer QR camera.
class _ScannerOverlayPainter extends CustomPainter {
  final Rect scanWindow;
  final double borderRadius = 20.0;

  _ScannerOverlayPainter(this.scanWindow);

  @override
  void paint(Canvas canvas, Size size) {
    final backgroundPaint = Paint()
      ..color = const Color.fromRGBO(0, 0, 0, 0.5)
      ..style = PaintingStyle.fill;

    final backgroundPath = Path()
      ..addRect(Rect.fromLTWH(0, 0, size.width, size.height));

    final cutoutPath = Path()
      ..addRRect(
          RRect.fromRectAndRadius(scanWindow, Radius.circular(borderRadius)));

    final backgroundWithHole = Path.combine(
      PathOperation.difference,
      backgroundPath,
      cutoutPath,
    );

    canvas.drawPath(backgroundWithHole, backgroundPaint);

    final borderPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.0;

    canvas.drawRRect(
        RRect.fromRectAndRadius(scanWindow, Radius.circular(borderRadius)),
        borderPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// --- PROFILE SCREEN (UNCHANGED) ---
/// Profile editing screen for retailer store and contact details.
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
    _storeNameController = TextEditingController(
        text: _userData['retailer_profile']?['store_name'] ?? '');
    _regNoController = TextEditingController(
        text: _userData['retailer_profile']?['business_reg_no'] ?? '');
    _addressController = TextEditingController(
        text: _userData['retailer_profile']?['outlet_address'] ?? '');
    _nameController.addListener(_markDirty);
    _phoneController.addListener(_markDirty);
    _storeNameController.addListener(_markDirty);
    _regNoController.addListener(_markDirty);
    _addressController.addListener(_markDirty);
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

  void _markDirty() {
    if (!_isEditing || _hasChanges) return;
    setState(() => _hasChanges = true);
  }

  void _resetDraft() {
    _nameController.text = _userData['name'] ?? "";
    _phoneController.text =
        _userData['phone_number'] ?? _userData['phone'] ?? "";
    _storeNameController.text =
        _userData['retailer_profile']?['store_name'] ?? '';
    _regNoController.text =
        _userData['retailer_profile']?['business_reg_no'] ?? '';
    _addressController.text =
        _userData['retailer_profile']?['outlet_address'] ?? '';
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

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text("Profile Updated Successfully!"),
              backgroundColor: Colors.green),
        );
      } else {
        String message = "Update Failed";
        try {
          final body = jsonDecode(response.body);
          if (body is Map && body['message'] != null) {
            message = body['message'].toString();
          }
        } catch (_) {}
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(message), backgroundColor: Colors.red));
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text("Connection Error"), backgroundColor: Colors.red));
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

    String storeName = _userData['retailer_profile']?['store_name'] ?? 'N/A';
    String regNo = _userData['retailer_profile']?['business_reg_no'] ?? 'N/A';
    String address = _userData['retailer_profile']?['outlet_address'] ?? 'N/A';

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: GradientAppBar(
        title: "Store Profile",
        gradientColors: const [
          Color(0xFFBF360C),
          Color(0xFFE65100),
          Color(0xFFFF6D00),
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
        colors: GradientBackground.retailer,
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
                          color: const Color(0xFFE65100).withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color:
                                const Color(0xFFE65100).withValues(alpha: 0.35),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.edit_note_rounded,
                                size: 18, color: Color(0xFFE65100)),
                            const SizedBox(width: 8),
                            Text(
                              _hasChanges
                                  ? "Unsaved changes"
                                  : "Editing mode enabled",
                              style: const TextStyle(
                                  color: Color(0xFFBF360C),
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
                                    color: const Color(0xFFE65100).withValues(
                                        alpha: _isEditing ? 0.65 : 0.3),
                                    width: _isEditing ? 4 : 3),
                                boxShadow: _isEditing
                                    ? [
                                        BoxShadow(
                                          color: const Color(0xFFE65100)
                                              .withValues(alpha: 0.2),
                                          blurRadius: 18,
                                          spreadRadius: 1,
                                        )
                                      ]
                                    : null,
                              ),
                              child: CircleAvatar(
                                radius: 50,
                                backgroundColor: const Color(0xFFE65100)
                                    .withValues(alpha: 0.1),
                                backgroundImage: backgroundImage,
                                onBackgroundImageError: backgroundImage != null
                                    ? (e, s) => debugPrint(
                                        'Profile image load error: $e')
                                    : null,
                                child: backgroundImage == null
                                    ? const Icon(Icons.store,
                                        size: 50, color: Color(0xFFE65100))
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
                                    color: Color(0xFFE65100),
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
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF37474F)),
                          decoration: InputDecoration(
                            labelText: "Manager Name",
                            labelStyle: TextStyle(color: Colors.grey[600]),
                            enabledBorder: UnderlineInputBorder(
                                borderSide: BorderSide(
                                    color: const Color(0xFFE65100)
                                        .withValues(alpha: 0.3))),
                            focusedBorder: const UnderlineInputBorder(
                                borderSide:
                                    BorderSide(color: Color(0xFFE65100))),
                          ),
                        )
                      else
                        Text(
                          _userData['name'] ?? "Manager Name",
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF37474F)),
                        ),
                      const SizedBox(height: 5),
                      Text("Retail Partner",
                          style: TextStyle(color: Colors.grey[600])),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 25),
              _buildSectionLabel("Store Details"),
              GlassCard(
                child: Column(
                  children: [
                    _buildInfoTile(
                        icon: Icons.store_mall_directory,
                        label: "Store Name",
                        value: storeName,
                        isEditable: _isEditing,
                        controller: _storeNameController),
                    Divider(
                        height: 1, color: Colors.grey.withValues(alpha: 0.2)),
                    _buildInfoTile(
                        icon: Icons.confirmation_number,
                        label: "Business Reg No (SSM)",
                        value: regNo,
                        isEditable: _isEditing,
                        controller: _regNoController),
                    Divider(
                        height: 1, color: Colors.grey.withValues(alpha: 0.2)),
                    _buildInfoTile(
                        icon: Icons.location_on,
                        label: "Outlet Address",
                        value: address,
                        isEditable: _isEditing,
                        controller: _addressController),
                  ],
                ),
              ),
              const SizedBox(height: 25),
              _buildSectionLabel("Contact Info"),
              GlassCard(
                child: Column(
                  children: [
                    _buildInfoTile(
                        icon: Icons.phone,
                        label: "Phone",
                        value: _userData['phone_number'] ?? "N/A",
                        isEditable: _isEditing,
                        controller: _phoneController),
                    Divider(
                        height: 1, color: Colors.grey.withValues(alpha: 0.2)),
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
      ),
      floatingActionButton: AnimatedSaveFab(
        isVisible: _isEditing,
        isSaving: _isSaving,
        hasChanges: _hasChanges,
        color: const Color(0xFFE65100),
        heroTag: 'retailer-profile-save',
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
                color: Color(0xFFBF360C),
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
          color: const Color(0xFFE65100).withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(icon, color: const Color(0xFFE65100), size: 22),
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
                        color: const Color(0xFFE65100).withValues(alpha: 0.3))),
                focusedBorder: const UnderlineInputBorder(
                    borderSide: BorderSide(color: Color(0xFFE65100))),
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
