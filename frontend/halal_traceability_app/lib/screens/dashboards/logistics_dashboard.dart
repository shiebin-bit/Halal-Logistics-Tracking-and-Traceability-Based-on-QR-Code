import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:signature/signature.dart';
import 'package:image_picker/image_picker.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../config.dart';
import '../../services/auth_session_service.dart';
import 'widgets/dashboard_widgets.dart';

/// Logistics workspace for route tracking, checkpoint capture, and incidents.
class LogisticsDashboard extends StatefulWidget {
  const LogisticsDashboard({super.key});

  @override
  State<LogisticsDashboard> createState() => _LogisticsDashboardState();
}

class _LogisticsDashboardState extends State<LogisticsDashboard> {
  int _selectedIndex = 0; // 0: Routes, 1: Scan, 2: Incidents, 3: Profile

  // --- STATE DATA ---
  final _tempController = TextEditingController();
  final _locationController = TextEditingController();
  final _notesController = TextEditingController();

  // Signature Controller
  final SignatureController _signatureController = SignatureController(
    penStrokeWidth: 3,
    penColor: Colors.black,
    exportBackgroundColor: Colors.white,
  );

  String? _scannedBatchId;
  bool _isSubmitting = false;
  List<dynamic> _assignedShipments = [];
  bool _isLoadingRoutes = true;

  // --- GLOBAL USER DATA ---
  Map<String, dynamic> _userData = {
    "name": "Loading...",
    "email": "...",
    "phone": "...",
    "profile_image": null,
    "logistics_profile": {
      "vehicle_plate_no": "...",
      "driver_license_no": "...",
      "vehicle_type": "..."
    }
  };

  @override
  void initState() {
    super.initState();
    _fetchUserProfile();
    _fetchAssignedRoutes();
  }

  // --- ALL API CALLS (UNCHANGED) ---
  Future<String?> _getToken() async {
    return AuthSessionService.getToken();
  }

  Future<void> _fetchUserProfile() async {
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
          _userData = data['user'] ?? {};
          if (_userData['logistics_profile'] == null) {
            _userData['logistics_profile'] = {};
          }
        });
      }
    } catch (e) {
      print("Error fetching profile: $e");
    }
  }

  Future<void> _fetchAssignedRoutes() async {
    setState(() => _isLoadingRoutes = true);
    try {
      final token = await _getToken();

      final response = await http.get(
        Uri.parse('$baseUrl/logistics/routes'),
        headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'application/json'
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() {
          _assignedShipments = data['data'] ?? [];
          _isLoadingRoutes = false;
        });
      } else {
        setState(() {
          _assignedShipments = [
            {
              "truckId": "JPG 8832",
              "destination": "Fresh Mart KL",
              "eta": "2h 15m",
              "temp": "-18.5°C",
              "status": "On Route",
              "progress": 0.7
            },
            {
              "truckId": "BKA 1029",
              "destination": "Tesco Penang",
              "eta": "4h 30m",
              "temp": "-19.0°C",
              "status": "Delayed",
              "progress": 0.4
            },
          ];
          _isLoadingRoutes = false;
        });
      }
    } catch (e) {
      setState(() => _isLoadingRoutes = false);
    }
  }

  Future<void> _submitCheckpoint() async {
    if (_tempController.text.isEmpty || _signatureController.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text("Temperature & Signature are required!")));
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final token = await _getToken();

      final Uint8List? signatureBytes = await _signatureController.toPngBytes();
      String signatureBase64 = base64Encode(signatureBytes!);

      final response = await http.post(
        Uri.parse('$baseUrl/logistics/checkpoint'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: jsonEncode({
          "batch_id": _scannedBatchId,
          "temperature": _tempController.text,
          "location": "3.140853, 101.693207",
          "notes": _notesController.text,
          "signature": signatureBase64,
          "status": "Delivered"
        }),
      );
      if (!mounted) return;
      if (response.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Delivery Verified & Uploaded!")));
        setState(() {
          _scannedBatchId = null;
          _tempController.clear();
          _notesController.clear();
          _signatureController.clear();
        });
        _fetchAssignedRoutes();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Failed to upload data")));
      }
    } catch (e) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text("Connection Error")));
    } finally {
      setState(() => _isSubmitting = false);
    }
  }

  Future<void> _scanQR() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const SimpleScannerPage()),
    );

    if (result != null) {
      setState(() {
        _scannedBatchId = result;
        _locationController.text = "Lat: 3.1408, Long: 101.6932";
        _selectedIndex = 1;
      });
    }
  }

  Future<void> _makePhoneCall(String phoneNumber) async {
    final Uri launchUri = Uri(scheme: 'tel', path: phoneNumber);
    if (await canLaunchUrl(launchUri)) {
      await launchUrl(launchUri);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Could not launch dialer")));
    }
  }

  void _showIncidentForm() {
    final descriptionController = TextEditingController();
    String? selectedBatchForIncident;
    String selectedIssueType = 'Delay';

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(builder: (context, setState) {
          return AlertDialog(
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: const Text("Report Incident",
                style:
                    TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text("Please provide details for the operations team.",
                      style: TextStyle(fontSize: 12, color: Colors.grey)),
                  const SizedBox(height: 15),
                  DropdownButtonFormField<String>(
                    decoration: const InputDecoration(
                        labelText: "Affected Batch",
                        border: OutlineInputBorder()),
                    value: selectedBatchForIncident,
                    items: _assignedShipments.map((batch) {
                      String id = batch['batch_id_raw'] ?? 'Unknown';
                      return DropdownMenuItem(value: id, child: Text(id));
                    }).toList(),
                    onChanged: (val) =>
                        setState(() => selectedBatchForIncident = val),
                  ),
                  const SizedBox(height: 10),
                  DropdownButtonFormField<String>(
                    decoration: const InputDecoration(
                        labelText: "Issue Type", border: OutlineInputBorder()),
                    value: selectedIssueType,
                    items: ['Delay', 'Accident', 'Spoilage', 'Theft', 'Other']
                        .map((t) => DropdownMenuItem(value: t, child: Text(t)))
                        .toList(),
                    onChanged: (val) =>
                        setState(() => selectedIssueType = val!),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: descriptionController,
                    maxLines: 3,
                    decoration: const InputDecoration(
                        labelText: "Description / Notes",
                        border: OutlineInputBorder(),
                        alignLabelWithHint: true),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text("Cancel")),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                onPressed: () async {
                  if (selectedBatchForIncident == null) {
                    ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text("Please select a batch")));
                    return;
                  }
                  Navigator.pop(context);
                  await _submitIncidentToApi(selectedBatchForIncident!,
                      selectedIssueType, descriptionController.text);
                },
                child: const Text("SUBMIT REPORT",
                    style: TextStyle(color: Colors.white)),
              )
            ],
          );
        });
      },
    );
  }

  Future<void> _submitIncidentToApi(
      String batchId, String type, String desc) async {
    setState(() => _isSubmitting = true);
    try {
      final token = await _getToken();

      final response = await http.post(
        Uri.parse('$baseUrl/logistics/incident'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: jsonEncode({
          "batch_id": batchId,
          "issue_type": type,
          "description": desc,
          "location": "GPS: 3.140853, 101.693207"
        }),
      );
      if (!mounted) return;
      if (response.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Incident Reported Successfully!")));
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Failed to report incident")));
      }
    } catch (e) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text("Connection Error")));
    } finally {
      setState(() => _isSubmitting = false);
    }
  }

  Future<void> _logout() async {
    await AuthSessionService.clearAuthSession();
    if (mounted) {
      Navigator.pushNamedAndRemoveUntil(context, '/login', (route) => false);
    }
  }

  // --- REDESIGNED DRAWER ---
  Widget _buildDrawer() {
    ImageProvider? drawerImage;
    if (_userData['profile_image'] != null) {
      drawerImage = NetworkImage("$storageUrl${_userData['profile_image']}");
    }

    String vehiclePlate =
        _userData['logistics_profile']?['vehicle_plate_no'] ?? 'No Vehicle';

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
                    Color(0xFF0D47A1),
                    Color(0xFF1565C0),
                    Color(0xFF1976D2)
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
                        ? const Icon(Icons.person,
                            size: 32, color: Colors.white)
                        : null,
                  ),
                  const SizedBox(height: 14),
                  Text(_userData['name'] ?? "Driver",
                      style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                          fontSize: 18)),
                  const SizedBox(height: 4),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text("🚛 $vehiclePlate",
                        style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.9),
                            fontSize: 12)),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            _buildDrawerItem(Icons.map_rounded, "Active Routes & Map", 0),
            _buildDrawerItem(
                Icons.qr_code_scanner_rounded, "Scan Checkpoint", 1),
            _buildDrawerItem(Icons.warning_amber_rounded, "Report Incident", 2),
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
                        onProfileUpdate: _fetchUserProfile),
                  ),
                );
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
                ? const Color(0xFF1565C0).withValues(alpha: 0.1)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon,
              color: isSelected ? const Color(0xFF1565C0) : Colors.grey[600],
              size: 22),
        ),
        title: Text(title,
            style: TextStyle(
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                color:
                    isSelected ? const Color(0xFF1565C0) : Colors.grey[700])),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        selected: isSelected,
        selectedTileColor: const Color(0xFF1565C0).withValues(alpha: 0.04),
        onTap: () {
          setState(() => _selectedIndex = index);
          Navigator.pop(context);
        },
      ),
    );
  }

  // --- REDESIGNED UI BUILDERS ---

  Widget _buildRoutesView() {
    if (_isLoadingRoutes) return const ShimmerLoader(itemCount: 4);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Live tracking banner
          StaggeredListItem(
            index: 0,
            child: Container(
              height: 180,
              width: double.infinity,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [
                    Color(0xFF0D47A1),
                    Color(0xFF1565C0),
                    Color(0xFF42A5F5)
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF1565C0).withValues(alpha: 0.3),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Stack(
                children: [
                  // Decorative circles
                  Positioned(
                    right: -30,
                    top: -30,
                    child: Container(
                      width: 120,
                      height: 120,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white.withValues(alpha: 0.08),
                      ),
                    ),
                  ),
                  Positioned(
                    right: 30,
                    bottom: -20,
                    child: Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white.withValues(alpha: 0.05),
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Row(
                          children: [
                            PulseWidget(
                              child: Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.2),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: const Icon(Icons.gps_fixed_rounded,
                                    color: Colors.white, size: 24),
                              ),
                            ),
                            const SizedBox(width: 14),
                            const Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text("Live GPS Tracking",
                                    style: TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.w700,
                                        fontSize: 18)),
                                Text("Real-time location monitoring",
                                    style: TextStyle(
                                        color: Colors.white70, fontSize: 12)),
                              ],
                            ),
                          ],
                        ),
                        const Spacer(),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: Colors.greenAccent.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                                color:
                                    Colors.greenAccent.withValues(alpha: 0.5)),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.circle,
                                  color: Colors.greenAccent, size: 8),
                              SizedBox(width: 6),
                              Text("Signal Active",
                                  style: TextStyle(
                                      color: Colors.greenAccent,
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600)),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),

          // Stats row
          StaggeredListItem(
            index: 1,
            child: Row(
              children: [
                AnimatedStatCard(
                    title: "Deliveries",
                    value: "${_assignedShipments.length}",
                    color: const Color(0xFF1565C0),
                    icon: Icons.local_shipping_rounded),
                const SizedBox(width: 12),
                AnimatedStatCard(
                    title: "Avg Temp",
                    value: "-18°C",
                    color: const Color(0xFF00BCD4),
                    icon: Icons.thermostat_rounded),
              ],
            ),
          ),
          const SizedBox(height: 28),

          // Shipments list
          StaggeredListItem(
            index: 2,
            child: const SectionTitle(
                title: "Assigned Shipments", accentColor: Color(0xFF1565C0)),
          ),
          const SizedBox(height: 12),
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _assignedShipments.length,
            itemBuilder: (context, index) {
              final route = _assignedShipments[index];
              final isOnRoute = route['status'] == "On Route";
              return StaggeredListItem(
                index: 3 + index,
                child: GlassCard(
                  padding: const EdgeInsets.all(18),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(children: [
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: const Color(0xFF1565C0)
                                    .withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Icon(Icons.local_shipping_rounded,
                                  color: Color(0xFF1565C0), size: 22),
                            ),
                            const SizedBox(width: 12),
                            Text(route['truckId'],
                                style: const TextStyle(
                                    fontWeight: FontWeight.w700, fontSize: 16)),
                          ]),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 5),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: isOnRoute
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
                            child: Text(route['status'],
                                style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w700,
                                    fontSize: 11)),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Row(children: [
                        Icon(Icons.location_on_rounded,
                            size: 16, color: Colors.grey[400]),
                        const SizedBox(width: 6),
                        Text("Dest: ${route['destination']}",
                            style: TextStyle(color: Colors.grey[600]))
                      ]),
                      const SizedBox(height: 6),
                      Row(children: [
                        Icon(Icons.access_time_rounded,
                            size: 16, color: Colors.grey[400]),
                        const SizedBox(width: 6),
                        Text("ETA: ${route['eta']} • Temp: ${route['temp']}",
                            style: TextStyle(color: Colors.grey[600]))
                      ]),
                      const SizedBox(height: 16),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: LinearProgressIndicator(
                            value: (route['progress'] as num).toDouble(),
                            backgroundColor: Colors.grey[100],
                            color: const Color(0xFF1565C0),
                            minHeight: 8),
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
      padding: const EdgeInsets.all(20.0),
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
                        Color(0xFF0D47A1),
                        Color(0xFF1565C0),
                        Color(0xFF42A5F5)
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [
                      BoxShadow(
                          color: const Color(0xFF1565C0).withValues(alpha: 0.3),
                          blurRadius: 20,
                          offset: const Offset(0, 8))
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
                      const Text("TAP TO SCAN BATCH",
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
                      const Text("Batch Locked",
                          style: TextStyle(
                              color: Colors.green,
                              fontWeight: FontWeight.w700,
                              fontSize: 12)),
                      Text(_scannedBatchId!,
                          style: const TextStyle(
                              fontWeight: FontWeight.w700, fontSize: 16)),
                    ],
                  )),
                  IconButton(
                      icon: Icon(Icons.close_rounded, color: Colors.grey[400]),
                      onPressed: () => setState(() => _scannedBatchId = null)),
                ],
              ),
            ),
          const SizedBox(height: 25),
          if (_scannedBatchId != null) ...[
            const SectionTitle(
                title: "Delivery Conditions", accentColor: Color(0xFF1565C0)),
            const SizedBox(height: 16),
            TextFormField(
              controller: _tempController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                  labelText: "Temperature (°C)",
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.thermostat_rounded)),
            ),
            const SizedBox(height: 15),
            TextFormField(
              controller: _locationController,
              readOnly: true,
              decoration: const InputDecoration(
                  labelText: "GPS Location",
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.my_location_rounded),
                  filled: true,
                  fillColor: Color(0xFFE3F2FD)),
            ),
            const SizedBox(height: 15),
            TextFormField(
              controller: _notesController,
              maxLines: 2,
              decoration: const InputDecoration(
                  labelText: "Condition Notes (Optional)",
                  prefixIcon: Icon(Icons.note_rounded),
                  border: OutlineInputBorder()),
            ),
            const SizedBox(height: 20),
            const SectionTitle(
                title: "Receiver Signature", accentColor: Color(0xFF1565C0)),
            const SizedBox(height: 8),
            Container(
              decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey[300]!),
                  borderRadius: BorderRadius.circular(16)),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Signature(
                  controller: _signatureController,
                  height: 150,
                  backgroundColor: Colors.grey[50]!,
                ),
              ),
            ),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                  onPressed: () => _signatureController.clear(),
                  icon: const Icon(Icons.refresh_rounded, size: 16),
                  label: const Text("Clear Signature")),
            ),
            const SizedBox(height: 20),
            SizedBox(
              height: 54,
              child: ElevatedButton.icon(
                onPressed: _isSubmitting ? null : _submitCheckpoint,
                icon: const Icon(Icons.cloud_upload_rounded),
                label: _isSubmitting
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text("CONFIRM DELIVERY"),
                style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1565C0),
                    foregroundColor: Colors.white),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildIncidentsView() {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.orange.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(30),
            ),
            child: Icon(Icons.warning_amber_rounded,
                size: 64, color: Colors.orange[700]),
          ),
          const SizedBox(height: 24),
          const Text("Report Critical Issue",
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          Text("Notify admins immediately about delays or spoilage.",
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey[500], fontSize: 14)),
          const SizedBox(height: 36),
          SizedBox(
            width: double.infinity,
            height: 54,
            child: ElevatedButton.icon(
              onPressed: () => _makePhoneCall('999'),
              style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFEF5350),
                  foregroundColor: Colors.white),
              icon: const Icon(Icons.call_rounded),
              label: const Text("Emergency Call Center"),
            ),
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            height: 54,
            child: OutlinedButton.icon(
              onPressed: _showIncidentForm,
              style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFFEF5350),
                  side: const BorderSide(color: Color(0xFFEF5350))),
              icon: const Icon(Icons.edit_document),
              label: const Text("Fill Incident Form"),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final titles = ["Logistics Hub", "Checkpoint Scanner", "Incidents"];

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: GradientAppBar(
        title: titles[_selectedIndex],
        gradientColors: const [
          Color(0xFF0D47A1),
          Color(0xFF1565C0),
          Color(0xFF1976D2),
        ],
      ),
      drawer: _buildDrawer(),
      body: GradientBackground(
        colors: GradientBackground.logistics,
        child: AnimatedViewSwitcher(
          child: KeyedSubtree(
            key: ValueKey<int>(_selectedIndex),
            child: _selectedIndex == 0
                ? _buildRoutesView()
                : _selectedIndex == 1
                    ? _buildScannerView()
                    : _buildIncidentsView(),
          ),
        ),
      ),
    );
  }
}

// --- PROFESSIONAL SCANNER (FIXED OVERLAY) ---
/// Scanner screen used to capture a batch QR code during handover.
class SimpleScannerPage extends StatefulWidget {
  const SimpleScannerPage({super.key});

  @override
  State<SimpleScannerPage> createState() => _SimpleScannerPageState();
}

class _SimpleScannerPageState extends State<SimpleScannerPage> {
  final MobileScannerController controller = MobileScannerController();

  @override
  Widget build(BuildContext context) {
    final double scanArea = (MediaQuery.of(context).size.width < 400 ||
            MediaQuery.of(context).size.height < 400)
        ? 250.0
        : 300.0;

    return Scaffold(
      appBar: AppBar(
        title: const Text("Scan Batch QR"),
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
            painter: ScannerOverlayPainter(Rect.fromCenter(
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
              "Align QR Code within frame",
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white, fontSize: 16),
            ),
          ),
        ],
      ),
    );
  }
}

// --- SCANNER PAINTER HELPER (FIXED) ---
/// Draws the scanner bracket overlay around the camera scan area.
class ScannerOverlayPainter extends CustomPainter {
  final Rect scanWindow;
  final double borderRadius;

  ScannerOverlayPainter(this.scanWindow, {this.borderRadius = 20.0});

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

// --- UPDATED PROFILE SCREEN (LOGISTICS SPECIFIC) ---
/// Profile editing screen for logistics identity and vehicle information.
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

  late TextEditingController _nameController;
  late TextEditingController _phoneController;
  late TextEditingController _vehiclePlateController;
  late TextEditingController _vehicleTypeController;
  late TextEditingController _licenseController;

  @override
  void initState() {
    super.initState();
    _userData = widget.userData;
    _nameController = TextEditingController(text: _userData['name']);
    _phoneController = TextEditingController(
        text: _userData['phone_number'] ?? _userData['phone']);
    _vehiclePlateController = TextEditingController(
        text: _userData['logistics_profile']?['vehicle_plate_no'] ?? '');
    _vehicleTypeController = TextEditingController(
        text: _userData['logistics_profile']?['vehicle_type'] ?? '');
    _licenseController = TextEditingController(
        text: _userData['logistics_profile']?['driver_license_no'] ?? '');
    _nameController.addListener(_markDirty);
    _phoneController.addListener(_markDirty);
    _vehiclePlateController.addListener(_markDirty);
    _vehicleTypeController.addListener(_markDirty);
    _licenseController.addListener(_markDirty);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _vehiclePlateController.dispose();
    _vehicleTypeController.dispose();
    _licenseController.dispose();
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
    _vehiclePlateController.text =
        _userData['logistics_profile']?['vehicle_plate_no'] ?? '';
    _vehicleTypeController.text =
        _userData['logistics_profile']?['vehicle_type'] ?? '';
    _licenseController.text =
        _userData['logistics_profile']?['driver_license_no'] ?? '';
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
      request.fields['name'] = _nameController.text;
      request.fields['phone'] = _phoneController.text;

      request.fields['vehicle_plate_no'] = _vehiclePlateController.text;
      request.fields['vehicle_type'] = _vehicleTypeController.text;
      request.fields['driver_license_no'] = _licenseController.text;

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
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text("Update Failed"), backgroundColor: Colors.red));
      }
    } catch (e) {
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
      backgroundImage =
          NetworkImage("$storageUrl${_userData['profile_image']}");
    }

    String vehiclePlate =
        _userData['logistics_profile']?['vehicle_plate_no'] ?? 'N/A';
    String licenseNo =
        _userData['logistics_profile']?['driver_license_no'] ?? 'N/A';
    String vehicleType =
        _userData['logistics_profile']?['vehicle_type'] ?? 'N/A';

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: GradientAppBar(
        title: "Driver Profile",
        gradientColors: const [
          Color(0xFF1565C0),
          Color(0xFF1976D2),
          Color(0xFF1E88E5),
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
        colors: GradientBackground.logistics,
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
                          color: const Color(0xFF1565C0).withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color:
                                const Color(0xFF1565C0).withValues(alpha: 0.35),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.edit_note_rounded,
                                size: 18, color: Color(0xFF1565C0)),
                            const SizedBox(width: 8),
                            Text(
                              _hasChanges
                                  ? "Unsaved changes"
                                  : "Editing mode enabled",
                              style: const TextStyle(
                                  color: Color(0xFF0D47A1),
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
                                    color: const Color(0xFF1565C0).withValues(
                                        alpha: _isEditing ? 0.65 : 0.3),
                                    width: _isEditing ? 4 : 3),
                                boxShadow: _isEditing
                                    ? [
                                        BoxShadow(
                                          color: const Color(0xFF1565C0)
                                              .withValues(alpha: 0.2),
                                          blurRadius: 18,
                                          spreadRadius: 1,
                                        )
                                      ]
                                    : null,
                              ),
                              child: CircleAvatar(
                                radius: 50,
                                backgroundColor: const Color(0xFF1565C0)
                                    .withValues(alpha: 0.1),
                                backgroundImage: backgroundImage,
                                onBackgroundImageError: backgroundImage != null
                                    ? (e, s) => debugPrint(
                                        'Profile image load error: $e')
                                    : null,
                                child: backgroundImage == null
                                    ? const Icon(Icons.person,
                                        size: 50, color: Color(0xFF1565C0))
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
                                    color: Color(0xFF1565C0),
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
                                    color: const Color(0xFF1565C0)
                                        .withValues(alpha: 0.3))),
                            focusedBorder: const UnderlineInputBorder(
                                borderSide:
                                    BorderSide(color: Color(0xFF1565C0))),
                          ),
                        )
                      else
                        Text(
                          _userData['name'] ?? "Driver Name",
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF37474F)),
                        ),
                      const SizedBox(height: 5),
                      Text("Logistics Partner",
                          style: TextStyle(color: Colors.grey[600])),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 25),
              _buildSectionLabel("Vehicle Details"),
              GlassCard(
                child: Column(
                  children: [
                    _buildInfoTile(
                        icon: Icons.local_shipping,
                        label: "Vehicle Plate No",
                        value: vehiclePlate,
                        isEditable: _isEditing,
                        controller: _vehiclePlateController),
                    Divider(
                        height: 1, color: Colors.grey.withValues(alpha: 0.2)),
                    _buildInfoTile(
                        icon: Icons.category,
                        label: "Vehicle Type",
                        value: vehicleType,
                        isEditable: _isEditing,
                        controller: _vehicleTypeController),
                  ],
                ),
              ),
              const SizedBox(height: 25),
              _buildSectionLabel("Contact & License"),
              GlassCard(
                child: Column(
                  children: [
                    _buildInfoTile(
                        icon: Icons.card_membership,
                        label: "Driver License",
                        value: licenseNo,
                        isEditable: _isEditing,
                        controller: _licenseController),
                    Divider(
                        height: 1, color: Colors.grey.withValues(alpha: 0.2)),
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
        color: const Color(0xFF1565C0),
        heroTag: 'logistics-profile-save',
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
                color: Color(0xFF0D47A1),
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
          color: const Color(0xFF1565C0).withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(icon, color: const Color(0xFF1565C0), size: 22),
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
                        color: const Color(0xFF1565C0).withValues(alpha: 0.3))),
                focusedBorder: const UnderlineInputBorder(
                    borderSide: BorderSide(color: Color(0xFF1565C0))),
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
