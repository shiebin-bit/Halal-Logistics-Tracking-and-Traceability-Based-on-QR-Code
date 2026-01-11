import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:signature/signature.dart';
import 'package:image_picker/image_picker.dart';
import 'package:url_launcher/url_launcher.dart';

// API Config
const String baseUrl = 'http://10.0.2.2:8000/api';
const String storageUrl = 'http://10.0.2.2:8000/storage/';

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
    // Default nested structure to prevent null errors before load
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

  // --- API: FETCH USER PROFILE ---
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

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() {
          _userData = data['user'] ?? {};
          // Ensure sub-profile exists
          if (_userData['logistics_profile'] == null) {
            _userData['logistics_profile'] = {};
          }
        });
      }
    } catch (e) {
      print("Error fetching profile: $e");
    }
  }

  // --- API: FETCH ROUTES ---
  Future<void> _fetchAssignedRoutes() async {
    setState(() => _isLoadingRoutes = true);
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('auth_token');

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
        // Fallback Mock Data
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

  // --- API: SUBMIT CHECKPOINT ---
  Future<void> _submitCheckpoint() async {
    if (_tempController.text.isEmpty || _signatureController.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text("Temperature & Signature are required!")));
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('auth_token');

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
          "location": "3.140853, 101.693207", // Mock GPS for now
          "notes": _notesController.text,
          "signature": signatureBase64,
          "status": "Delivered"
        }),
      );

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

  // --- ACTION: SCAN QR ---
  Future<void> _scanQR() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const SimpleScannerPage()),
    );

    if (result != null) {
      setState(() {
        _scannedBatchId = result;
        _locationController.text = "Lat: 3.1408, Long: 101.6932";
        _selectedIndex = 1; // Auto switch to scanner view
      });
    }
  }

  // --- INCIDENT LOGIC ---
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

                  // 1. Select Batch
                  DropdownButtonFormField<String>(
                    decoration: const InputDecoration(
                        labelText: "Affected Batch",
                        border: OutlineInputBorder()),
                    value: selectedBatchForIncident,
                    items: _assignedShipments.map((batch) {
                      // We use the raw ID we added to the backend
                      String id = batch['batch_id_raw'] ?? 'Unknown';
                      return DropdownMenuItem(value: id, child: Text(id));
                    }).toList(),
                    onChanged: (val) =>
                        setState(() => selectedBatchForIncident = val),
                  ),
                  const SizedBox(height: 10),

                  // 2. Select Issue Type
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

                  // 3. Description
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

                  // Call API
                  Navigator.pop(context); // Close dialog
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
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('auth_token');

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
          "location": "GPS: 3.140853, 101.693207" // Mock for now
        }),
      );

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
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
    if (mounted)
      Navigator.pushNamedAndRemoveUntil(context, '/login', (route) => false);
  }

  // --- DRAWER (NAVIGATION) ---
  Widget _buildDrawer() {
    ImageProvider? drawerImage;
    if (_userData['profile_image'] != null) {
      drawerImage = NetworkImage("$storageUrl${_userData['profile_image']}");
    }

    // Safely get vehicle plate
    String vehiclePlate =
        _userData['logistics_profile']?['vehicle_plate_no'] ?? 'No Vehicle';

    return Drawer(
      child: Column(
        children: [
          UserAccountsDrawerHeader(
            decoration: const BoxDecoration(color: Color(0xFF1565C0)),
            accountName: Text(_userData['name'] ?? "Driver",
                style:
                    const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
            accountEmail: Text("Vehicle: $vehiclePlate"),
            currentAccountPicture: CircleAvatar(
                backgroundColor: Colors.white,
                backgroundImage: drawerImage,
                child: drawerImage == null
                    ? const Icon(Icons.person,
                        size: 35, color: Color(0xFF1565C0))
                    : null),
          ),
          ListTile(
              leading: const Icon(Icons.map, color: Colors.blue),
              title: const Text("Active Routes & Map"),
              selected: _selectedIndex == 0,
              onTap: () {
                setState(() => _selectedIndex = 0);
                Navigator.pop(context);
              }),
          ListTile(
              leading: const Icon(Icons.qr_code_scanner, color: Colors.blue),
              title: const Text("Scan Checkpoint"),
              selected: _selectedIndex == 1,
              onTap: () {
                setState(() => _selectedIndex = 1);
                Navigator.pop(context);
              }),
          ListTile(
              leading:
                  const Icon(Icons.warning_amber_rounded, color: Colors.blue),
              title: const Text("Report Incident"),
              selected: _selectedIndex == 2,
              onTap: () {
                setState(() => _selectedIndex = 2);
                Navigator.pop(context);
              }),
          const Divider(),
          ListTile(
              leading: const Icon(Icons.person, color: Colors.blue),
              title: const Text("Profile Settings"),
              selected: _selectedIndex == 3,
              onTap: () {
                // Close drawer and navigate to profile
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => ProfileScreen(
                        userData: _userData,
                        onProfileUpdate: _fetchUserProfile),
                  ),
                );
              }),
          const Spacer(),
          ListTile(
              leading: const Icon(Icons.logout, color: Colors.red),
              title: const Text("Secure Logout",
                  style: TextStyle(color: Colors.red)),
              onTap: _logout),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  // --- UI BUILDERS ---

  Widget _buildRoutesView() {
    if (_isLoadingRoutes)
      return const Center(child: CircularProgressIndicator());

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            height: 200,
            width: double.infinity,
            decoration: BoxDecoration(
              color: Colors.blue[50],
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.blue.withOpacity(0.3)),
            ),
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: const [
                  Icon(Icons.map, size: 50, color: Colors.blue),
                  SizedBox(height: 10),
                  Text("Live GPS Tracking Active",
                      style: TextStyle(
                          color: Colors.blue, fontWeight: FontWeight.bold)),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              _buildStatCard(
                  "Deliveries", "${_assignedShipments.length}", Colors.blue),
              const SizedBox(width: 10),
              _buildStatCard("Avg Temp", "-18°C", Colors.lightBlue),
            ],
          ),
          const SizedBox(height: 25),
          const Text("Assigned Shipments",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 10),
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _assignedShipments.length,
            itemBuilder: (context, index) {
              final route = _assignedShipments[index];
              return Card(
                elevation: 3,
                margin: const EdgeInsets.only(bottom: 12),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(children: [
                            const Icon(Icons.local_shipping_outlined,
                                color: Colors.black87),
                            const SizedBox(width: 10),
                            Text(route['truckId'],
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold, fontSize: 16)),
                          ]),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: route['status'] == "On Route"
                                  ? Colors.green[100]
                                  : Colors.orange[100],
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(route['status'],
                                style: TextStyle(
                                    color: route['status'] == "On Route"
                                        ? Colors.green[800]
                                        : Colors.orange[800],
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12)),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(children: [
                        const Icon(Icons.location_on,
                            size: 16, color: Colors.grey),
                        const SizedBox(width: 5),
                        Text("Dest: ${route['destination']}",
                            style: TextStyle(color: Colors.grey[700]))
                      ]),
                      const SizedBox(height: 5),
                      Row(children: [
                        const Icon(Icons.access_time,
                            size: 16, color: Colors.grey),
                        const SizedBox(width: 5),
                        Text("ETA: ${route['eta']} • Temp: ${route['temp']}",
                            style: TextStyle(color: Colors.grey[700]))
                      ]),
                      const SizedBox(height: 15),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                            value: (route['progress'] as num).toDouble(),
                            backgroundColor: Colors.grey[200],
                            color: Colors.blue,
                            minHeight: 6),
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
            InkWell(
              onTap: _scanQR,
              child: Container(
                height: 150,
                decoration: BoxDecoration(
                  color: const Color(0xFF1565C0),
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                        color: Colors.blue.withOpacity(0.3),
                        blurRadius: 10,
                        offset: const Offset(0, 5))
                  ],
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: const [
                    Icon(Icons.qr_code_scanner, size: 60, color: Colors.white),
                    SizedBox(height: 10),
                    Text("TAP TO SCAN BATCH",
                        style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 16)),
                  ],
                ),
              ),
            )
          else
            Container(
              padding: const EdgeInsets.all(15),
              decoration: BoxDecoration(
                  color: Colors.green[50],
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.green)),
              child: Row(
                children: [
                  const Icon(Icons.check_circle, color: Colors.green, size: 30),
                  const SizedBox(width: 10),
                  Expanded(
                      child: Text("Batch $_scannedBatchId Locked",
                          style: const TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 16))),
                  IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => setState(() => _scannedBatchId = null)),
                ],
              ),
            ),
          const SizedBox(height: 25),
          if (_scannedBatchId != null) ...[
            const Text("Delivery Conditions",
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 15),
            TextFormField(
              controller: _tempController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                  labelText: "Temperature (°C)",
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.thermostat)),
            ),
            const SizedBox(height: 15),
            TextFormField(
              controller: _locationController,
              readOnly: true,
              decoration: const InputDecoration(
                  labelText: "GPS Location",
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.my_location),
                  filled: true,
                  fillColor: Color(0xFFE3F2FD)),
            ),
            const SizedBox(height: 15),
            TextFormField(
              controller: _notesController,
              maxLines: 2,
              decoration: const InputDecoration(
                  labelText: "Condition Notes (Optional)",
                  prefixIcon: Icon(Icons.note),
                  border: OutlineInputBorder()),
            ),
            const SizedBox(height: 20),
            const Text("Receiver Signature",
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 5),
            Container(
              decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey),
                  borderRadius: BorderRadius.circular(10)),
              child: Signature(
                controller: _signatureController,
                height: 150,
                backgroundColor: Colors.grey[100]!,
              ),
            ),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                  onPressed: () => _signatureController.clear(),
                  child: const Text("Clear Signature")),
            ),
            const SizedBox(height: 20),
            SizedBox(
              height: 50,
              child: ElevatedButton.icon(
                onPressed: _isSubmitting ? null : _submitCheckpoint,
                icon: const Icon(Icons.cloud_upload),
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
      padding: const EdgeInsets.all(20),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.warning_amber_rounded,
              size: 80, color: Colors.orange[700]),
          const SizedBox(height: 20),
          const Text("Report Critical Issue",
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
          const Text("Notify admins immediately about delays or spoilage.",
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey)),
          const SizedBox(height: 30),

          // --- CALL BUTTON ---
          ElevatedButton.icon(
            onPressed: () => _makePhoneCall('999'), // Or your HQ Number
            style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
                padding:
                    const EdgeInsets.symmetric(horizontal: 30, vertical: 15)),
            icon: const Icon(Icons.call),
            label: const Text("Emergency Call Center"),
          ),

          const SizedBox(height: 15),

          // --- FORM BUTTON ---
          OutlinedButton.icon(
            onPressed: _showIncidentForm, // Opens the dialog
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
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(value,
              style: TextStyle(
                  fontSize: 24, fontWeight: FontWeight.bold, color: color)),
          Text(title,
              style: TextStyle(color: color.withOpacity(0.8), fontSize: 12)),
        ]),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text(_selectedIndex == 0
            ? "Logistics Hub"
            : _selectedIndex == 1
                ? "Checkpoint Scanner"
                : "Incidents"),
        backgroundColor: const Color(0xFF1565C0),
        foregroundColor: Colors.white,
        centerTitle: true,
        // Hide edit button if on profile (it has its own FAB)
        actions: _selectedIndex == 3 ? [] : null,
      ),
      drawer: _buildDrawer(),
      body: _selectedIndex == 0
          ? _buildRoutesView()
          : _selectedIndex == 1
              ? _buildScannerView()
              : _buildIncidentsView(),
    );
  }
}

// --- PROFESSIONAL SCANNER (FIXED OVERLAY) ---
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
class ScannerOverlayPainter extends CustomPainter {
  final Rect scanWindow;
  final double borderRadius;

  ScannerOverlayPainter(this.scanWindow, {this.borderRadius = 20.0});

  @override
  void paint(Canvas canvas, Size size) {
    // 1. Define the paint for the dark background
    final backgroundPaint = Paint()
      ..color = const Color.fromRGBO(0, 0, 0, 0.5) // Semi-transparent black
      ..style = PaintingStyle.fill;

    // 2. Define the full screen rectangle
    final backgroundPath = Path()
      ..addRect(Rect.fromLTWH(0, 0, size.width, size.height));

    // 3. Define the cutout (scan window)
    final cutoutPath = Path()
      ..addRRect(
          RRect.fromRectAndRadius(scanWindow, Radius.circular(borderRadius)));

    // 4. Subtract the cutout from the background
    final backgroundWithHole = Path.combine(
      PathOperation.difference,
      backgroundPath,
      cutoutPath,
    );

    // 5. Draw the dark background (using the variable we defined!)
    canvas.drawPath(backgroundWithHole, backgroundPaint);

    // 6. Draw the white border
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
  late TextEditingController _vehiclePlateController; // NEW

  @override
  void initState() {
    super.initState();
    _userData = widget.userData;
    _nameController = TextEditingController(text: _userData['name']);
    _phoneController = TextEditingController(
        text: _userData['phone_number'] ?? _userData['phone']);
    // Load logistics specific data
    _vehiclePlateController = TextEditingController(
        text: _userData['logistics_profile']?['vehicle_plate_no'] ?? '');
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _vehiclePlateController.dispose();
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

      // Update specific logistics fields
      request.fields['vehicle_plate_no'] = _vehiclePlateController.text;

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
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text("Update Failed"), backgroundColor: Colors.red));
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text("Connection Error"), backgroundColor: Colors.red));
    } finally {
      setState(() => _isSaving = false);
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

    // Safely Access Logistics Data
    String vehiclePlate =
        _userData['logistics_profile']?['vehicle_plate_no'] ?? 'N/A';
    String licenseNo =
        _userData['logistics_profile']?['driver_license_no'] ?? 'N/A';
    String vehicleType =
        _userData['logistics_profile']?['vehicle_type'] ?? 'N/A';

    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: const Text("Driver Profile",
            style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
        backgroundColor: const Color(0xFF1565C0), // Blue for Logistics
        centerTitle: true,
        actions: [
          IconButton(
            icon: Icon(_isEditing ? Icons.close : Icons.edit,
                color: Colors.white),
            onPressed: () {
              setState(() {
                _isEditing = !_isEditing;
                if (!_isEditing) {
                  // Reset if cancelled
                  _nameController.text = _userData['name'] ?? "";
                  _vehiclePlateController.text = vehiclePlate;
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
              color: Color(0xFF1565C0),
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
                                    ? const Icon(Icons.person,
                                        size: 50, color: Color(0xFF1565C0))
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
                            _userData['name'] ?? "Driver Name",
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                                fontSize: 22, fontWeight: FontWeight.bold),
                          ),
                        const SizedBox(height: 5),
                        Text("Logistics Partner",
                            style: TextStyle(color: Colors.grey[600])),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                _buildSectionLabel("Vehicle Details"),
                Card(
                  child: Column(
                    children: [
                      _buildInfoTile(
                          icon: Icons.local_shipping,
                          label: "Vehicle Plate No",
                          value: vehiclePlate,
                          isEditable: _isEditing,
                          controller: _vehiclePlateController), // Editable
                      const Divider(height: 1),
                      _buildInfoTile(
                          icon: Icons.category,
                          label: "Vehicle Type",
                          value: vehicleType),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                _buildSectionLabel("Contact & License"),
                Card(
                  child: Column(
                    children: [
                      _buildInfoTile(
                          icon: Icons.card_membership,
                          label: "Driver License",
                          value: licenseNo),
                      const Divider(height: 1),
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
              backgroundColor: const Color(0xFF1565C0),
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
            color: Colors.blue[50], borderRadius: BorderRadius.circular(8)),
        child: Icon(icon, color: const Color(0xFF1565C0)),
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
