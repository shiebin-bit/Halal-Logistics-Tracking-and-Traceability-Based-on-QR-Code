import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:math'; // For random data simulation

class RetailerDashboard extends StatefulWidget {
  const RetailerDashboard({super.key});

  @override
  State<RetailerDashboard> createState() => _RetailerDashboardState();
}

class _RetailerDashboardState extends State<RetailerDashboard> {
  int _selectedIndex = 0; // 0: Incoming, 1: Scan & Verify, 2: Inventory

  // --- STATE DATA ---
  bool _isScanning = false;
  Map<String, dynamic>? _scannedBatch;

  // Quality Check State
  bool _checkPackaging = false;
  bool _checkSeal = false;
  bool _checkTemp = false;

  // Mock Incoming Shipments
  final List<Map<String, dynamic>> _incomingShipments = [
    {
      "id": "TRK-8821",
      "supplier": "Ali Processing Sdn Bhd",
      "eta": "10 Mins",
      "items": "Whole Chicken (500kg)",
      "status": "Arriving",
      "risk_level": "Low"
    },
    {
      "id": "TRK-9920",
      "supplier": "Nuggets Factory",
      "eta": "2 Hours",
      "items": "Frozen Nuggets (200kg)",
      "status": "In Transit",
      "risk_level": "Medium"
    },
  ];

  // --- ACTIONS ---
  Future<void> _logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
    if (mounted)
      Navigator.pushNamedAndRemoveUntil(context, '/login', (route) => false);
  }

  void _simulateScan() async {
    setState(() => _isScanning = true);
    await Future.delayed(const Duration(seconds: 2));
    setState(() {
      _isScanning = false;
      // Mock data fetched from "Blockchain"
      _scannedBatch = {
        "id": "B-2025-${1000 + Random().nextInt(900)}",
        "product": "Premium Whole Chicken",
        "origin": "Ali Processing Sdn Bhd",
        "slaughter_date": "2025-10-12",
        "avg_temp": "-18.2°C",
        "freshness_score": 96, // High score
        "violations": 0,
      };
    });
  }

  void _processAcceptance() {
    if (!_checkPackaging || !_checkSeal || !_checkTemp) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text("Error: All Physical Checks must be passed.")),
      );
      return;
    }

    // Show Digital Signature Dialog
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Digital Custody Transfer"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
                "I certify that these goods have been received in Halal-compliant condition."),
            const SizedBox(height: 20),
            Container(
              height: 100,
              width: double.infinity,
              decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey),
                  color: Colors.grey[50]),
              child: const Center(
                  child: Text("Tap to Sign (Simulation)",
                      style: TextStyle(color: Colors.grey))),
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text("Cancel")),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFE65100),
                foregroundColor: Colors.white),
            onPressed: () {
              Navigator.pop(ctx);
              setState(() {
                _scannedBatch = null;
                _checkPackaging = false;
                _checkSeal = false;
                _checkTemp = false;
              });
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                    content: Text("Ownership Transferred. Inventory Updated.")),
              );
            },
            child: const Text("CONFIRM RECEIPT"),
          )
        ],
      ),
    );
  }

  // --- UI BUILDERS ---

  Widget _buildDrawer() {
    return Drawer(
      child: Column(
        children: [
          UserAccountsDrawerHeader(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Color(0xFFE65100),
                  Color(0xFFEF6C00)
                ], // Orange for Retailer
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            accountName: const Text("Fresh Mart KL (Manager)",
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
            accountEmail: const Text("Store ID: STR-001"),
            currentAccountPicture: const CircleAvatar(
              backgroundColor: Colors.white,
              child: Icon(Icons.store, size: 35, color: Color(0xFFE65100)),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.local_shipping, color: Colors.orange),
            title: const Text("Incoming Shipments"),
            selected: _selectedIndex == 0,
            selectedColor: Colors.orange,
            onTap: () {
              setState(() => _selectedIndex = 0);
              Navigator.pop(context);
            },
          ),
          ListTile(
            leading: const Icon(Icons.qr_code_scanner, color: Colors.orange),
            title: const Text("Scan & Verify"),
            selected: _selectedIndex == 1,
            selectedColor: Colors.orange,
            onTap: () {
              setState(() => _selectedIndex = 1);
              Navigator.pop(context);
            },
          ),
          ListTile(
            leading: const Icon(Icons.inventory, color: Colors.orange),
            title: const Text("Store Inventory"),
            selected: _selectedIndex == 2,
            selectedColor: Colors.orange,
            onTap: () {
              setState(() => _selectedIndex = 2);
              Navigator.pop(context);
            },
          ),
          const Spacer(),
          ListTile(
            leading: const Icon(Icons.logout, color: Colors.red),
            title: const Text("Logout", style: TextStyle(color: Colors.red)),
            onTap: _logout,
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildIncomingView() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildStatCard("Pending Arrival", "2 Trucks", Colors.orange),
          const SizedBox(height: 20),
          const Text("Expected Today",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 10),
          ..._incomingShipments
              .map((shipment) => Card(
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
                      title: Text(shipment['supplier'],
                          style: const TextStyle(fontWeight: FontWeight.bold)),
                      subtitle:
                          Text("${shipment['items']}\nETA: ${shipment['eta']}"),
                      isThreeLine: true,
                      trailing: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
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
                        ],
                      ),
                    ),
                  ))
              .toList(),
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
          // 1. Scanner Button
          if (_scannedBatch == null)
            GestureDetector(
              onTap: _isScanning ? null : _simulateScan,
              child: Container(
                height: 200,
                decoration: BoxDecoration(
                  color: Colors.black87,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.orange, width: 2),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _isScanning
                        ? const CircularProgressIndicator(color: Colors.orange)
                        : const Icon(Icons.qr_code_scanner,
                            size: 60, color: Colors.white),
                    const SizedBox(height: 15),
                    Text(
                        _isScanning
                            ? "Verifying Blockchain..."
                            : "Tap to Scan Shipment",
                        style: const TextStyle(color: Colors.white70)),
                  ],
                ),
              ),
            ),

          // 2. Verification Results
          if (_scannedBatch != null) ...[
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 10)],
                border: Border.all(color: Colors.green.withOpacity(0.5)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.verified, color: Colors.green),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text("Batch ${_scannedBatch!['id']} Verified",
                            style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Colors.green)),
                      ),
                    ],
                  ),
                  const Divider(height: 30),
                  _buildDetailRow("Product", _scannedBatch!['product']),
                  _buildDetailRow("Supplier", _scannedBatch!['origin']),
                  _buildDetailRow(
                      "Avg Transit Temp", _scannedBatch!['avg_temp']),
                  const SizedBox(height: 15),

                  // AI Freshness Score
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                        color: Colors.green[50],
                        borderRadius: BorderRadius.circular(10)),
                    child: Row(
                      children: [
                        const Icon(Icons.auto_awesome, color: Colors.green),
                        const SizedBox(width: 10),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text("AI Freshness Prediction",
                                style: TextStyle(
                                    fontSize: 12, color: Colors.green)),
                            Text(
                                "${_scannedBatch!['freshness_score']}% Shelf Life Remaining",
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: Colors.green)),
                          ],
                        )
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 25),

            // 3. Physical Check Checklist
            const Text("Physical Inspection Checklist",
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            CheckboxListTile(
              title: const Text("Packaging is intact (No leaks)"),
              value: _checkPackaging,
              activeColor: Colors.orange,
              onChanged: (val) => setState(() => _checkPackaging = val!),
            ),
            CheckboxListTile(
              title: const Text("Halal Seal is unbroken"),
              value: _checkSeal,
              activeColor: Colors.orange,
              onChanged: (val) => setState(() => _checkSeal = val!),
            ),
            CheckboxListTile(
              title: const Text("Arrival Temperature below -12°C"),
              value: _checkTemp,
              activeColor: Colors.orange,
              onChanged: (val) => setState(() => _checkTemp = val!),
            ),
            const SizedBox(height: 20),

            // 4. Action Buttons
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () {
                      setState(() => _scannedBatch = null); // Cancel
                    },
                    style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.red,
                        padding: const EdgeInsets.symmetric(vertical: 15)),
                    child: const Text("REJECT STOCK"),
                  ),
                ),
                const SizedBox(width: 15),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _processAcceptance,
                    style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFE65100),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 15)),
                    child: const Text("ACCEPT & SIGN"),
                  ),
                ),
              ],
            ),
          ]
        ],
      ),
    );
  }

  Widget _buildInventoryView() {
    return const Center(child: Text("Inventory Module Placeholder"));
  }

  Widget _buildStatCard(String title, String value, Color color) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(16)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(value,
              style: TextStyle(
                  fontSize: 28, fontWeight: FontWeight.bold, color: color)),
          Text(title, style: TextStyle(color: color.withOpacity(0.8))),
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
                ? "Verification"
                : "Inventory"),
        backgroundColor: const Color(0xFFE65100), // Retailer Orange
        foregroundColor: Colors.white,
        centerTitle: true,
      ),
      drawer: _buildDrawer(),
      body: _selectedIndex == 0
          ? _buildIncomingView()
          : _selectedIndex == 1
              ? _buildScannerView()
              : _buildInventoryView(),
    );
  }
}
