import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AdminDashboard extends StatefulWidget {
  const AdminDashboard({super.key});

  @override
  State<AdminDashboard> createState() => _AdminDashboardState();
}

class _AdminDashboardState extends State<AdminDashboard> {
  int _selectedIndex =
      0; // 0: Overview, 1: User Approvals, 2: Batch Oversight, 3: Incidents

  // --- MOCK DATA ---

  // Pending Registrations (From Registration Screen)
  final List<Map<String, dynamic>> _pendingUsers = [
    {
      "id": "USR-992",
      "company": "Nordin Cold Chain",
      "role": "Logistics Partner",
      "email": "admin@nordin.com",
      "doc_status": "Uploaded (license.pdf)",
      "date": "2026-01-08",
    },
    {
      "id": "USR-993",
      "company": "Mega Mart Johor",
      "role": "Retailer",
      "email": "purchasing@megamart.my",
      "doc_status": "Uploaded (ssm_cert.jpg)",
      "date": "2026-01-09",
    },
  ];

  // System Incidents
  final List<Map<String, dynamic>> _incidents = [
    {
      "id": "INC-001",
      "severity": "High",
      "type": "Temperature Breach",
      "details": "Truck BKA1029 reported +2°C for 40 mins.",
      "status": "Open",
    },
    {
      "id": "INC-002",
      "severity": "Medium",
      "type": "GPS Signal Lost",
      "details": "Route #8821 signal lost near Border Checkpoint.",
      "status": "Resolved",
    },
  ];

  // --- ACTIONS ---

  Future<void> _logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
    if (mounted)
      Navigator.pushNamedAndRemoveUntil(context, '/login', (route) => false);
  }

  void _approveUser(int index) {
    setState(() {
      _pendingUsers.removeAt(index);
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("User Account Approved & Activated.")),
    );
  }

  void _rejectUser(int index) {
    setState(() {
      _pendingUsers.removeAt(index);
    });
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text("User Application Rejected.")));
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
                  Color(0xFF212121),
                  Color(0xFF424242),
                ], // Dark Grey for Admin
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            accountName: const Text(
              "System Administrator",
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
            ),
            accountEmail: const Text("admin@halalchain.my"),
            currentAccountPicture: const CircleAvatar(
              backgroundColor: Colors.white,
              child: Icon(
                Icons.admin_panel_settings,
                size: 35,
                color: Colors.black87,
              ),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.dashboard, color: Colors.black87),
            title: const Text("System Overview"),
            selected: _selectedIndex == 0,
            onTap: () {
              setState(() => _selectedIndex = 0);
              Navigator.pop(context);
            },
          ),
          ListTile(
            leading: const Icon(Icons.verified_user, color: Colors.black87),
            title: const Text("User Approvals"),
            trailing: _pendingUsers.isNotEmpty
                ? CircleAvatar(
                    radius: 10,
                    backgroundColor: Colors.red,
                    child: Text(
                      "${_pendingUsers.length}",
                      style: const TextStyle(fontSize: 10, color: Colors.white),
                    ),
                  )
                : null,
            selected: _selectedIndex == 1,
            onTap: () {
              setState(() => _selectedIndex = 1);
              Navigator.pop(context);
            },
          ),
          ListTile(
            leading: const Icon(Icons.view_list, color: Colors.black87),
            title: const Text("Master Batch List"),
            selected: _selectedIndex == 2,
            onTap: () {
              setState(() => _selectedIndex = 2);
              Navigator.pop(context);
            },
          ),
          ListTile(
            leading: const Icon(Icons.warning, color: Colors.black87),
            title: const Text("Incident Center"),
            selected: _selectedIndex == 3,
            onTap: () {
              setState(() => _selectedIndex = 3);
              Navigator.pop(context);
            },
          ),
          const Spacer(),
          ListTile(
            leading: const Icon(Icons.logout, color: Colors.red),
            title: const Text(
              "Admin Logout",
              style: TextStyle(color: Colors.red),
            ),
            onTap: _logout,
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  // --- 1. OVERVIEW DASHBOARD ---
  Widget _buildOverview() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "System Health",
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 15),
          Row(
            children: [
              _buildStatCard("Active Users", "142", Colors.blue),
              const SizedBox(width: 10),
              _buildStatCard("Total Batches", "1,204", Colors.green),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              _buildStatCard(
                "Pending KYC",
                "${_pendingUsers.length}",
                Colors.orange,
              ),
              const SizedBox(width: 10),
              _buildStatCard(
                "Open Incidents",
                "${_incidents.where((i) => i['status'] == 'Open').length}",
                Colors.red,
              ),
            ],
          ),
          const SizedBox(height: 30),

          const Text(
            "Recent System Activity",
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 10),
          Card(
            elevation: 2,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            child: ListView(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              children: const [
                ListTile(
                  leading: Icon(Icons.login, color: Colors.grey),
                  title: Text("Retailer 'Fresh Mart' logged in"),
                  subtitle: Text("2 minutes ago"),
                ),
                Divider(height: 1),
                ListTile(
                  leading: Icon(Icons.qr_code, color: Colors.green),
                  title: Text("Batch #B-2025-881 Created"),
                  subtitle: Text("By Ali Processing Sdn Bhd • 15 mins ago"),
                ),
                Divider(height: 1),
                ListTile(
                  leading: Icon(Icons.warning, color: Colors.red),
                  title: Text("Temp Alert: Truck JPG8832"),
                  subtitle: Text("1 hour ago"),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // --- 2. USER APPROVALS (KYC) ---
  Widget _buildUserApprovals() {
    if (_pendingUsers.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.check_circle_outline, size: 80, color: Colors.green),
            SizedBox(height: 20),
            Text("All caught up! No pending applications."),
          ],
        ),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _pendingUsers.length,
      itemBuilder: (context, index) {
        final user = _pendingUsers[index];
        return Card(
          margin: const EdgeInsets.only(bottom: 15),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      "Application #${user['id']}",
                      style: const TextStyle(color: Colors.grey, fontSize: 12),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.orange[100],
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Text(
                        "Pending Review",
                        style: TextStyle(
                          color: Colors.orange,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  user['company'],
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  "Role: ${user['role']}",
                  style: const TextStyle(
                    color: Colors.blue,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 15),
                // Document Preview
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.grey[100],
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.grey[300]!),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.attach_file, color: Colors.grey),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              "Business License (SSM)",
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                              ),
                            ),
                            Text(
                              user['doc_status'],
                              style: const TextStyle(
                                fontSize: 11,
                                color: Colors.blue,
                              ),
                            ),
                          ],
                        ),
                      ),
                      TextButton(onPressed: () {}, child: const Text("VIEW")),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => _rejectUser(index),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.red,
                        ),
                        child: const Text("REJECT"),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () => _approveUser(index),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                          foregroundColor: Colors.white,
                        ),
                        child: const Text("APPROVE"),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // --- 3. MASTER BATCH LIST ---
  Widget _buildBatchOversight() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: TextField(
            decoration: InputDecoration(
              hintText: "Search Global Database...",
              prefixIcon: const Icon(Icons.search),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              filled: true,
              fillColor: Colors.white,
            ),
          ),
        ),
        Expanded(
          child: ListView.builder(
            itemCount: 5,
            itemBuilder: (context, index) {
              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                child: ListTile(
                  leading: const CircleAvatar(
                    backgroundColor: Colors.black12,
                    child: Icon(Icons.qr_code, color: Colors.black),
                  ),
                  title: Text(
                    "Batch #B-2025-00${index + 1}",
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: Text(
                    index == 2
                        ? "Status: Flagged (Temp Breach)"
                        : "Status: Healthy",
                  ),
                  trailing: index == 2
                      ? const Icon(Icons.warning, color: Colors.red)
                      : const Icon(Icons.check_circle, color: Colors.green),
                  onTap: () {},
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  // --- 4. INCIDENT REPORTS ---
  Widget _buildIncidentReports() {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _incidents.length,
      itemBuilder: (context, index) {
        final item = _incidents[index];
        final bool isHigh = item['severity'] == "High";
        return Card(
          elevation: 3,
          margin: const EdgeInsets.only(bottom: 15),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: isHigh
                ? const BorderSide(color: Colors.red, width: 1)
                : BorderSide.none,
          ),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: isHigh ? Colors.red : Colors.orange,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        item['severity'].toUpperCase(),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    Text(
                      item['status'],
                      style: TextStyle(
                        color: item['status'] == "Open"
                            ? Colors.green
                            : Colors.grey,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  item['type'],
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  item['details'],
                  style: const TextStyle(color: Colors.grey),
                ),
                const SizedBox(height: 15),
                if (item['status'] == "Open")
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () {
                        // Resolve Logic
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.black87,
                        foregroundColor: Colors.white,
                      ),
                      child: const Text("MARK AS RESOLVED"),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildStatCard(String title, String value, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              value,
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            Text(
              title,
              style: TextStyle(color: color.withOpacity(0.8), fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: Text(
          _selectedIndex == 0
              ? "Admin Dashboard"
              : _selectedIndex == 1
              ? "Pending Approvals"
              : _selectedIndex == 2
              ? "Batch Oversight"
              : "Incident Logs",
        ),
        backgroundColor: Colors.black87,
        foregroundColor: Colors.white,
        centerTitle: true,
      ),
      drawer: _buildDrawer(),
      body: _selectedIndex == 0
          ? _buildOverview()
          : _selectedIndex == 1
          ? _buildUserApprovals()
          : _selectedIndex == 2
          ? _buildBatchOversight()
          : _buildIncidentReports(),
    );
  }
}
