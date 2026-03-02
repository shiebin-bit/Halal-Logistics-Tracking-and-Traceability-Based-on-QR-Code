import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:image_picker/image_picker.dart';

import '../../config.dart';

class ConsumerDashboard extends StatefulWidget {
  const ConsumerDashboard({super.key});

  @override
  State<ConsumerDashboard> createState() => _ConsumerDashboardState();
}

class _ConsumerDashboardState extends State<ConsumerDashboard> {
  // --- CONTROLLERS ---
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  // --- STATE VARIABLES ---
  List<dynamic> _batches = [];
  bool _isLoading = false;
  bool _hasMore = true;
  int _page = 1;
  String _searchQuery = "";

  @override
  void initState() {
    super.initState();
    _fetchBatches();

    // Pagination Listener
    _scrollController.addListener(() {
      if (_scrollController.position.pixels ==
          _scrollController.position.maxScrollExtent) {
        _fetchBatches();
      }
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  // --- FETCH DATA ---
  Future<void> _fetchBatches({bool refresh = false}) async {
    if (_isLoading) return;
    if (refresh) {
      setState(() {
        _page = 1;
        _hasMore = true;
        _batches.clear();
      });
    }

    if (!_hasMore) return;

    setState(() => _isLoading = true);

    try {
      final uri =
          Uri.parse('$baseUrl/public/batches?page=$_page&search=$_searchQuery');
      final response =
          await http.get(uri, headers: {'Accept': 'application/json'});

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final List newItems = data['data'];

        setState(() {
          _batches.addAll(newItems);
          _page++;
          if (newItems.length < 10) _hasMore = false;
          _isLoading = false;
        });
      } else {
        setState(() => _isLoading = false);
      }
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  // --- ACTIONS ---
  void _onSearchChanged(String value) {
    setState(() => _searchQuery = value);
    _fetchBatches(refresh: true);
  }

  Future<void> _scanQR() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const QRScannerPage()),
    );

    if (result != null) {
      _searchController.text = result;
      _onSearchChanged(result);
    }
  }

  void _openBatchDetails(Map<String, dynamic> batch) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ConsumerBatchDetailScreen(batchData: batch),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text("Public Verification",
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white),
            onPressed: () => _fetchBatches(refresh: true),
          )
        ],
      ),
      body: Stack(
        children: [
          // 1. GREEN GRADIENT BACKGROUND
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
          Positioned(
              top: -50,
              right: -50,
              child: Container(
                  height: 200,
                  width: 200,
                  decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.05),
                      shape: BoxShape.circle))),
          Positioned(
              bottom: 100,
              left: -30,
              child: Container(
                  height: 150,
                  width: 150,
                  decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.05),
                      shape: BoxShape.circle))),

          // 2. MAIN CONTENT
          SafeArea(
            child: Column(
              children: [
                const SizedBox(height: 10),
                const Icon(Icons.verified_user_outlined,
                    size: 80, color: Colors.white),
                const SizedBox(height: 10),
                const Text("Trace Your Food Journey",
                    style: TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.bold,
                        color: Colors.white)),
                const Text("Verify Halal Authenticity & Logistics Safety",
                    style: TextStyle(color: Colors.white70, fontSize: 14)),
                const SizedBox(height: 30),

                // --- SEARCH BAR ---
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24.0),
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(15),
                      boxShadow: [
                        BoxShadow(
                            color: Colors.black.withValues(alpha: 0.2),
                            blurRadius: 15,
                            offset: const Offset(0, 5))
                      ],
                    ),
                    child: TextField(
                      controller: _searchController,
                      onChanged: _onSearchChanged,
                      decoration: InputDecoration(
                        hintText: "Enter Batch ID (e.g., B-2025-001)",
                        hintStyle: TextStyle(color: Colors.grey[400]),
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.all(20),
                        suffixIcon: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.qr_code_scanner,
                                  color: Color(0xFF1B5E20)),
                              onPressed: _scanQR,
                            ),
                            Container(
                                height: 30, width: 1, color: Colors.grey[300]),
                            IconButton(
                              icon: const Icon(Icons.search,
                                  color: Color(0xFF1B5E20)),
                              onPressed: () => _fetchBatches(refresh: true),
                            ),
                            const SizedBox(width: 8),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 20),

                // --- LIVE BATCH LIST ---
                Expanded(
                  child: Container(
                    margin: const EdgeInsets.only(top: 10),
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.only(
                          topLeft: Radius.circular(30),
                          topRight: Radius.circular(30)),
                    ),
                    child: _batches.isEmpty && !_isLoading
                        ? Center(
                            child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                Icon(Icons.search_off,
                                    size: 60, color: Colors.grey[300]),
                                const SizedBox(height: 10),
                                Text("No batches found.",
                                    style: TextStyle(color: Colors.grey[500]))
                              ]))
                        : ListView.builder(
                            controller: _scrollController,
                            padding: const EdgeInsets.all(20),
                            itemCount: _batches.length + (_hasMore ? 1 : 0),
                            itemBuilder: (context, index) {
                              if (index == _batches.length) {
                                return const Center(
                                    child: Padding(
                                        padding: EdgeInsets.all(10),
                                        child: CircularProgressIndicator()));
                              }
                              return _buildBatchCard(_batches[index]);
                            },
                          ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // --- WIDGET: BATCH CARD ---
  Widget _buildBatchCard(Map<String, dynamic> item) {
    Color statusColor = Colors.orange;
    if (item['status'] == 'Ready') statusColor = Colors.green;
    if (item['status'] == 'In Transit') statusColor = Colors.blue;

    return Card(
      elevation: 2,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      child: InkWell(
        borderRadius: BorderRadius.circular(15),
        onTap: () => _openBatchDetails(item), // OPEN DETAILS ON TAP
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12)),
                child: Icon(Icons.inventory_2, color: statusColor),
              ),
              const SizedBox(width: 15),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(item['batch_id'] ?? 'Unknown ID',
                        style: const TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 16)),
                    Text("${item['product_type'] ?? ''}",
                        style:
                            TextStyle(color: Colors.grey[600], fontSize: 12)),
                    const SizedBox(height: 5),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                          color: statusColor.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(4)),
                      child: Text((item['status'] ?? '').toUpperCase(),
                          style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: statusColor)),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.arrow_forward_ios, size: 14, color: Colors.grey),
            ],
          ),
        ),
      ),
    );
  }
}

// --- NEW PAGE: BATCH DETAILS (WITH TABS) ---
class ConsumerBatchDetailScreen extends StatelessWidget {
  final Map<String, dynamic> batchData;

  const ConsumerBatchDetailScreen({super.key, required this.batchData});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: Text(batchData['batch_id'] ?? "Batch Details"),
          backgroundColor: const Color(0xFF1B5E20),
          foregroundColor: Colors.white,
          bottom: const TabBar(
            indicatorColor: Colors.white,
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white70,
            tabs: [
              Tab(icon: Icon(Icons.info_outline), text: "Product Details"),
              Tab(icon: Icon(Icons.timeline), text: "Supply Chain"),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _buildDetailsTab(),
            _buildTimelineTab(),
          ],
        ),
      ),
    );
  }

  // --- TAB 1: PRODUCT DETAILS ---
  Widget _buildDetailsTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          Card(
            elevation: 3,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  const Icon(Icons.check_circle, color: Colors.green, size: 50),
                  const SizedBox(height: 10),
                  const Text("OFFICIALLY VERIFIED",
                      style: TextStyle(
                          color: Colors.green,
                          fontWeight: FontWeight.bold,
                          fontSize: 16)),
                  const Divider(height: 30),
                  _buildDetailRow(
                      "Product", batchData['product_type'] ?? "N/A"),
                  const Divider(),
                  _buildDetailRow("Weight", batchData['weight'] ?? "N/A"),
                  const Divider(),
                  _buildDetailRow(
                      "Farm Origin", batchData['origin_farm'] ?? "N/A"),
                  const Divider(),
                  _buildDetailRow(
                      "Processor", batchData['processing_factory'] ?? "N/A"),
                  const Divider(),
                  _buildDetailRow(
                      "Current Status", batchData['status'] ?? "N/A"),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String title, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(title, style: const TextStyle(color: Colors.grey)),
          Text(value,
              style:
                  const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        ],
      ),
    );
  }

  // --- TAB 2: ROUTE TIMELINE ---
  Widget _buildTimelineTab() {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        const Text("Traceability Journey",
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 20),
        _buildTimelineItem(
          title: "Farm Production",
          desc: batchData['origin_farm'] ?? "Registered Farm",
          date: "10 Oct 2025, 08:00 AM", // Mock Data
          isCompleted: true,
          isFirst: true,
        ),
        _buildTimelineItem(
          title: "Slaughter & Processing",
          desc: batchData['processing_factory'] ?? "Halal Factory",
          date: "10 Oct 2025, 02:00 PM",
          isCompleted: true,
        ),
        _buildTimelineItem(
          title: "Logistics (Cold Chain)",
          desc: "Temperature: -18°C",
          date: "11 Oct 2025, 09:00 AM",
          isCompleted: batchData['status'] == 'In Transit' ||
              batchData['status'] == 'Ready',
        ),
        _buildTimelineItem(
          title: "Retailer Received",
          desc: "Ready for Sale",
          date: "Pending",
          isCompleted: batchData['status'] == 'Ready',
          isLast: true,
        ),
      ],
    );
  }

  Widget _buildTimelineItem(
      {required String title,
      required String desc,
      required String date,
      bool isCompleted = false,
      bool isFirst = false,
      bool isLast = false}) {
    Color color = isCompleted ? const Color(0xFF1B5E20) : Colors.grey;
    return IntrinsicHeight(
      child: Row(
        children: [
          SizedBox(
            width: 40,
            child: Column(
              children: [
                if (!isFirst)
                  Expanded(child: Container(width: 2, color: color)),
                Icon(
                    isCompleted
                        ? Icons.check_circle
                        : Icons.radio_button_unchecked,
                    color: color),
                if (!isLast)
                  Expanded(
                      child: Container(
                          width: 2,
                          color: isCompleted ? color : Colors.grey[300])),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 30),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          color: isCompleted ? Colors.black : Colors.grey)),
                  Text(desc,
                      style: TextStyle(color: Colors.grey[700], fontSize: 14)),
                  Text(date,
                      style: TextStyle(color: Colors.grey[500], fontSize: 12)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// QR Scanner page with camera scanning and gallery upload support.
class QRScannerPage extends StatefulWidget {
  const QRScannerPage({super.key});

  @override
  State<QRScannerPage> createState() => _QRScannerPageState();
}

class _QRScannerPageState extends State<QRScannerPage> {
  final MobileScannerController controller = MobileScannerController();

  Future<void> _pickImageFromGallery() async {
    final ImagePicker picker = ImagePicker();
    final XFile? image = await picker.pickImage(source: ImageSource.gallery);

    if (image != null) {
      final BarcodeCapture? capture = await controller.analyzeImage(image.path);
      if (capture != null && capture.barcodes.isNotEmpty) {
        final String? code = capture.barcodes.first.rawValue;
        if (code != null) {
          if (!mounted) return;
          controller.dispose();
          Navigator.pop(context, code);
        }
      } else {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("No QR code found in image")),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Define the size of the scanning area
    final double scanArea = (MediaQuery.of(context).size.width < 400 ||
            MediaQuery.of(context).size.height < 400)
        ? 250.0
        : 300.0;

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: const Text("Scan QR Code",
            style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          // Gallery Button
          Container(
            margin: const EdgeInsets.only(right: 10),
            decoration: const BoxDecoration(
                color: Colors.black45, shape: BoxShape.circle),
            child: IconButton(
              icon: const Icon(Icons.image, color: Colors.white),
              tooltip: "Upload from Gallery",
              onPressed: _pickImageFromGallery,
            ),
          ),
          // Flashlight Button (FIXED)
          Container(
            margin: const EdgeInsets.only(right: 16),
            decoration: const BoxDecoration(
                color: Colors.black45, shape: BoxShape.circle),
            child: IconButton(
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
            size: Size.infinite,
            painter: ScannerOverlayPainter(
              borderColor: Colors.white,
              borderRadius: 10,
              borderLength: 30,
              borderWidth: 10,
              cutoutSize: scanArea,
            ),
          ),
          Positioned(
            bottom: 100,
            left: 0,
            right: 0,
            child: Center(
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                    color: Colors.black54,
                    borderRadius: BorderRadius.circular(20)),
                child: const Text("Align QR code within the frame",
                    style: TextStyle(color: Colors.white, fontSize: 14)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Custom painter for the QR scanner overlay frame with corner brackets.
class ScannerOverlayPainter extends CustomPainter {
  final Color borderColor;
  final double borderRadius;
  final double borderLength;
  final double borderWidth;
  final double cutoutSize;

  ScannerOverlayPainter({
    required this.borderColor,
    required this.borderRadius,
    required this.borderLength,
    required this.borderWidth,
    required this.cutoutSize,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final double scanAreaSize = cutoutSize;
    final double left = (size.width - scanAreaSize) / 2;
    final double top = (size.height - scanAreaSize) / 2;
    final Rect cutoutRect =
        Rect.fromLTWH(left, top, scanAreaSize, scanAreaSize);

    // 1. Draw Semi-Transparent Background (Darkens everything except the hole)
    final Paint backgroundPaint = Paint()
      ..color = Colors.black.withValues(alpha: 0.6);
    final Path backgroundPath = Path()
      ..addRect(Rect.fromLTWH(0, 0, size.width, size.height))
      ..addRect(cutoutRect)
      ..fillType = PathFillType.evenOdd;

    canvas.drawPath(backgroundPath, backgroundPaint);

    // 2. Draw the White Corners (Bracket Look)
    final Paint borderPaint = Paint()
      ..color = borderColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 5 // Thickness of the white line
      ..strokeCap = StrokeCap.round; // Rounded line ends

    // Top-Left Corner
    canvas.drawPath(
      Path()
        ..moveTo(left, top + borderLength)
        ..lineTo(left, top + borderRadius)
        ..quadraticBezierTo(left, top, left + borderRadius, top)
        ..lineTo(left + borderLength, top),
      borderPaint,
    );

    // Top-Right Corner
    canvas.drawPath(
      Path()
        ..moveTo(left + scanAreaSize - borderLength, top)
        ..lineTo(left + scanAreaSize - borderRadius, top)
        ..quadraticBezierTo(
            left + scanAreaSize, top, left + scanAreaSize, top + borderRadius)
        ..lineTo(left + scanAreaSize, top + borderLength),
      borderPaint,
    );

    // Bottom-Right Corner
    canvas.drawPath(
      Path()
        ..moveTo(left + scanAreaSize, top + scanAreaSize - borderLength)
        ..lineTo(left + scanAreaSize, top + scanAreaSize - borderRadius)
        ..quadraticBezierTo(left + scanAreaSize, top + scanAreaSize,
            left + scanAreaSize - borderRadius, top + scanAreaSize)
        ..lineTo(left + scanAreaSize - borderLength, top + scanAreaSize),
      borderPaint,
    );

    // Bottom-Left Corner
    canvas.drawPath(
      Path()
        ..moveTo(left + borderLength, top + scanAreaSize)
        ..lineTo(left + borderRadius, top + scanAreaSize)
        ..quadraticBezierTo(
            left, top + scanAreaSize, left, top + scanAreaSize - borderRadius)
        ..lineTo(left, top + scanAreaSize - borderLength),
      borderPaint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
