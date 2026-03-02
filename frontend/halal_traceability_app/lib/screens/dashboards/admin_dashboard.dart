import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../../config.dart';

class AdminDashboard extends StatefulWidget {
  const AdminDashboard({super.key});

  @override
  State<AdminDashboard> createState() => _AdminDashboardState();
}

class _AdminDashboardState extends State<AdminDashboard> {
  final TextEditingController _searchController = TextEditingController();
  Timer? _debounce;
  int _selectedIndex = 0; // 0: Overview, 1: Approvals, 2: Batches, 3: Incidents
  bool _isLoading = false;

  // --- DATA LISTS ---
  Map<String, dynamic> _stats = {
    "total_batches": 0,
    "pending_users": 0,
    "active_issues": 0
  };
  List<dynamic> _pendingUsers = [];
  List<dynamic> _batches = [];
  List<dynamic> _incidents = [];

  @override
  void initState() {
    super.initState();
    _refreshAllData();
  }

  Future<void> _refreshAllData() async {
    setState(() => _isLoading = true);
    await Future.wait([
      _fetchStats(),
      _fetchPendingUsers(),
      _fetchBatches(),
      _fetchIncidents(),
    ]);
    if (mounted) setState(() => _isLoading = false);
  }

  // --- API CALLS ---

  Future<void> _fetchStats() async {
    try {
      final token = await _getToken();
      final response = await http.get(Uri.parse('$baseUrl/admin/stats'),
          headers: _headers(token));
      if (response.statusCode == 200) {
        setState(() => _stats = jsonDecode(response.body));
      }
    } catch (e) {
      debugPrint("Error stats: $e");
    }
  }

  Future<void> _fetchPendingUsers() async {
    try {
      final token = await _getToken();
      final response = await http.get(
          Uri.parse('$baseUrl/admin/users?status=pending'),
          headers: _headers(token));
      if (response.statusCode == 200) {
        setState(() => _pendingUsers = jsonDecode(response.body)['data']);
      }
    } catch (e) {
      debugPrint("Error users: $e");
    }
  }

  Future<void> _fetchBatches({String? query}) async {
    try {
      final token = await _getToken();

      // Build URL with search query if it exists
      String url = '$baseUrl/batches';
      if (query != null && query.isNotEmpty) {
        url += '?search=$query';
      }

      final response = await http.get(Uri.parse(url), headers: _headers(token));

      if (response.statusCode == 200) {
        setState(() => _batches = jsonDecode(response.body)['data']);
      }
    } catch (e) {
      debugPrint("Error batches: $e");
    }
  }

  // Trigger search when user types
  void _onSearchChanged(String query) {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 500), () {
      _fetchBatches(query: query);
    });
  }

  Future<void> _fetchIncidents() async {
    try {
      final token = await _getToken();
      final response = await http.get(Uri.parse('$baseUrl/admin/incidents'),
          headers: _headers(token));
      if (response.statusCode == 200) {
        setState(() => _incidents = jsonDecode(response.body)['data']);
      }
    } catch (e) {
      debugPrint("Error incidents: $e");
    }
  }

  Future<void> _approveUser(int userId) async {
    setState(() => _isLoading = true);
    try {
      final token = await _getToken();
      final response = await http.post(
          Uri.parse('$baseUrl/admin/approve/$userId'),
          headers: _headers(token));
      if (response.statusCode == 200) {
        _showMessage("User Approved");
        _refreshAllData();
      }
    } catch (e) {
      _showMessage("Connection Error");
    }
  }

  Future<void> _rejectUser(int userId) async {
    try {
      final token = await _getToken();
      final response = await http.post(
          Uri.parse('$baseUrl/admin/reject/$userId'),
          headers: _headers(token));
      if (response.statusCode == 200) {
        _showMessage("User Rejected");
        _refreshAllData();
      }
    } catch (e) {
      _showMessage("Connection Error");
    }
  }

  Future<String?> _getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('auth_token');
  }

  Map<String, String> _headers(String? token) {
    return {'Authorization': 'Bearer $token', 'Accept': 'application/json'};
  }

  void _showMessage(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  Future<void> _logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
    if (mounted) {
      Navigator.pushNamedAndRemoveUntil(context, '/login', (route) => false);
    }
  }

  // --- UI BUILDERS ---

  Widget _buildOverview() {
    return RefreshIndicator(
      onRefresh: _refreshAllData,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text("System Health",
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 15),
            Row(children: [
              _buildStatCard("Total Batches", "${_stats['total_batches']}",
                  Colors.blue, Icons.qr_code),
              const SizedBox(width: 10),
              _buildStatCard("Pending Users", "${_stats['pending_users']}",
                  Colors.orange, Icons.person_add),
            ]),
            const SizedBox(height: 10),
            Row(children: [
              _buildStatCard("Active Issues", "${_stats['active_issues']}",
                  Colors.red, Icons.warning),
              const SizedBox(width: 10),
              _buildStatCard(
                  "System Status", "Online", Colors.green, Icons.check_circle),
            ]),
            const SizedBox(height: 30),
            const Text("Recent Batches",
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _batches.take(5).length, // Show only top 5
              itemBuilder: (ctx, i) {
                final batch = _batches[i];
                return ListTile(
                  leading: const Icon(Icons.history, color: Colors.grey),
                  title: Text("Batch ${batch['batch_id']}"),
                  subtitle:
                      Text("${batch['product_type']} • ${batch['status']}"),
                  dense: true,
                );
              },
            )
          ],
        ),
      ),
    );
  }

  Widget _buildUserApprovals() {
    if (_pendingUsers.isEmpty) {
      return const Center(child: Text("No pending applications."));
    }
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _pendingUsers.length,
      itemBuilder: (context, index) {
        final user = _pendingUsers[index];
        return Card(
          margin: const EdgeInsets.only(bottom: 15),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text("Role: ${user['role']}",
                        style: const TextStyle(
                            color: Colors.blue, fontWeight: FontWeight.bold)),
                    const Chip(
                        label: Text("Pending",
                            style:
                                TextStyle(color: Colors.white, fontSize: 10)),
                        backgroundColor: Colors.orange,
                        padding: EdgeInsets.zero)
                  ],
                ),
                Text(user['name'] ?? 'Unknown Name',
                    style: const TextStyle(
                        fontSize: 18, fontWeight: FontWeight.bold)),
                Text(user['email'], style: const TextStyle(color: Colors.grey)),
                const SizedBox(height: 10),
                Text("Phone: ${user['phone_number'] ?? 'N/A'}"),
                const SizedBox(height: 15),
                Row(children: [
                  Expanded(
                      child: OutlinedButton(
                          onPressed: () => _rejectUser(user['id']),
                          style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.red),
                          child: const Text("REJECT"))),
                  const SizedBox(width: 10),
                  Expanded(
                      child: ElevatedButton(
                          onPressed: () => _approveUser(user['id']),
                          style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.green,
                              foregroundColor: Colors.white),
                          child: const Text("APPROVE"))),
                ]),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildBatchOversight() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: TextField(
            controller: _searchController,
            onChanged: _onSearchChanged, // Connects the search logic
            decoration: InputDecoration(
              hintText: "Search Batch ID or Product...",
              prefixIcon: const Icon(Icons.search),
              suffixIcon: _searchController.text.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: () {
                        _searchController.clear();
                        _onSearchChanged('');
                      },
                    )
                  : null,
              border:
                  OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              filled: true,
              fillColor: Colors.white,
            ),
          ),
        ),
        Expanded(
          child: _batches.isEmpty
              ? const Center(child: Text("No batches found."))
              : ListView.builder(
                  itemCount: _batches.length,
                  itemBuilder: (context, index) {
                    final batch = _batches[index];
                    return Card(
                      margin: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 6),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: Colors.blue[50],
                          child: const Icon(Icons.qr_code, color: Colors.blue),
                        ),
                        title: Text("Batch ${batch['batch_id']}",
                            style:
                                const TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: Text(
                            "${batch['product_type']} (${batch['weight']})"),
                        trailing: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                              color: Colors.blue[50],
                              borderRadius: BorderRadius.circular(4)),
                          child: Text(batch['status'],
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
    );
  }

  Widget _buildIncidentReports() {
    if (_incidents.isEmpty) {
      return const Center(child: Text("No incidents reported."));
    }
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _incidents.length,
      itemBuilder: (context, index) {
        final item = _incidents[index];
        return Card(
          elevation: 3,
          margin: const EdgeInsets.only(bottom: 15),
          shape: RoundedRectangleBorder(
              side: const BorderSide(color: Colors.red, width: 1),
              borderRadius: BorderRadius.circular(12)),
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
                            horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                            color: Colors.red,
                            borderRadius: BorderRadius.circular(4)),
                        child: Text(item['issue_type'] ?? 'INCIDENT',
                            style: const TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.bold)),
                      ),
                      Text(item['created_at'].toString().substring(0, 10),
                          style: const TextStyle(
                              color: Colors.grey, fontSize: 12)),
                    ]),
                const SizedBox(height: 10),
                Text("Batch: ${item['batch_id']}",
                    style: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.bold)),
                const SizedBox(height: 5),
                Text(item['description'] ?? 'No details provided',
                    style: const TextStyle(color: Colors.black87)),
                const SizedBox(height: 5),
                Text("Location: ${item['location']}",
                    style: const TextStyle(color: Colors.grey, fontSize: 12)),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildStatCard(
      String title, String value, Color color, IconData icon) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: color, size: 28),
            const SizedBox(height: 10),
            Text(value,
                style: TextStyle(
                    fontSize: 24, fontWeight: FontWeight.bold, color: color)),
            Text(title,
                style: TextStyle(color: color.withAlpha(200), fontSize: 12)),
          ],
        ),
      ),
    );
  }

  Widget _buildDrawer() {
    return Drawer(
      child: Column(
        children: [
          UserAccountsDrawerHeader(
            decoration: const BoxDecoration(
                gradient: LinearGradient(
                    colors: [Color(0xFF212121), Color(0xFF424242)])),
            accountName: const Text("System Administrator",
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
            accountEmail: const Text("admin@halalchain.my"),
            currentAccountPicture: const CircleAvatar(
              backgroundColor: Colors.white,
              child: Icon(Icons.admin_panel_settings,
                  size: 35, color: Colors.black87),
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
                    child: Text("${_pendingUsers.length}",
                        style:
                            const TextStyle(fontSize: 10, color: Colors.white)))
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
            title:
                const Text("Admin Logout", style: TextStyle(color: Colors.red)),
            onTap: _logout,
          ),
          const SizedBox(height: 20),
        ],
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
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _selectedIndex == 0
              ? _buildOverview()
              : _selectedIndex == 1
                  ? _buildUserApprovals()
                  : _selectedIndex == 2
                      ? _buildBatchOversight()
                      : _buildIncidentReports(),
    );
  }
}
