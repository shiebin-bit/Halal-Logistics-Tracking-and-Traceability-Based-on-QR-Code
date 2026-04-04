import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:qr_flutter/qr_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../config.dart';
import '../../services/auth_session_service.dart';
import '../../services/batch_route_mapper.dart';
import '../../widgets/route_map_card.dart';
import 'widgets/dashboard_widgets.dart';

/// Admin workspace for approvals, monitoring, and system-level oversight.
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
  String _selectedBatchStatusFilter = 'all';

  // --- DATA LISTS ---
  Map<String, dynamic> _stats = {
    "total_batches": 0,
    "pending_users": 0,
    "active_issues": 0,
    "status_breakdown": {},
    "certificate_summary": {},
  };
  List<dynamic> _pendingUsers = [];
  List<dynamic> _batches = [];
  List<dynamic> _incidents = [];

  Map<String, dynamic> get _statusBreakdown =>
      (_stats['status_breakdown'] as Map?)?.cast<String, dynamic>() ??
      const <String, dynamic>{};

  Map<String, dynamic> get _certificateSummary =>
      (_stats['certificate_summary'] as Map?)?.cast<String, dynamic>() ??
      const <String, dynamic>{};

  List<dynamic> get _visibleBatches {
    if (_selectedBatchStatusFilter == 'all') {
      return _batches;
    }

    return _batches.where((batch) {
      return (batch['status'] ?? '').toString() == _selectedBatchStatusFilter;
    }).toList(growable: false);
  }

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

  // --- API CALLS (UNCHANGED) ---

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

  void _onSearchChanged(String query) {
    setState(() {});
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
    return AuthSessionService.getToken();
  }

  Map<String, String> _headers(String? token) {
    return {'Authorization': 'Bearer $token', 'Accept': 'application/json'};
  }

  void _showMessage(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  String _metricLabel(dynamic value) => (value ?? 0).toString();

  List<Map<String, String>> get _batchStatusFilters => const [
        {'label': 'All', 'value': 'all'},
        {'label': 'Ready', 'value': 'Ready for QR Generation'},
        {'label': 'QR', 'value': 'QR Generated'},
        {'label': 'Transit', 'value': 'In Transit'},
        {'label': 'Delivered', 'value': 'Delivered'},
        {'label': 'Revoked', 'value': 'Invalid - Certificate Revoked'},
      ];

  Map<String, dynamic>? _roleProfileFor(Map<String, dynamic> user) {
    final role = (user['role'] ?? '').toString();
    if (role == 'processor') {
      return (user['processor_profile'] as Map?)?.cast<String, dynamic>();
    }
    if (role == 'logistics') {
      return (user['logistics_profile'] as Map?)?.cast<String, dynamic>();
    }
    if (role == 'retailer') {
      return (user['retailer_profile'] as Map?)?.cast<String, dynamic>();
    }
    return null;
  }

  String? _documentUrlFor(Map<String, dynamic> user) {
    final role = (user['role'] ?? '').toString();
    final profile = _roleProfileFor(user);
    if (profile == null) return null;

    final path = role == 'processor'
        ? profile['cert_document_path']
        : role == 'logistics'
            ? profile['gdl_license_path']
            : null;

    if (path == null || path.toString().isEmpty) return null;
    return '$storageUrl${path.toString()}';
  }

  Future<void> _openVerificationDocument(Map<String, dynamic> user) async {
    final url = _documentUrlFor(user);
    if (url == null) {
      _showMessage('No verification document uploaded.');
      return;
    }

    final uri = Uri.parse(url);
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      _showMessage('Unable to open verification document.');
    }
  }

  List<Widget> _buildApprovalDetails(Map<String, dynamic> user) {
    final role = (user['role'] ?? '').toString();
    final profile = _roleProfileFor(user);
    final widgets = <Widget>[];

    if (profile == null) {
      return widgets;
    }

    if (role == 'processor') {
      widgets.addAll([
        _buildApprovalInfoRow(
            'Company Reg No', profile['company_reg_no']?.toString() ?? 'N/A'),
        _buildApprovalInfoRow(
            'Halal Cert No', profile['halal_cert_no']?.toString() ?? 'N/A'),
        _buildApprovalInfoRow(
            'Factory Address', profile['factory_address']?.toString() ?? 'N/A'),
      ]);
    } else if (role == 'logistics') {
      widgets.addAll([
        _buildApprovalInfoRow(
            'Vehicle Plate', profile['vehicle_plate_no']?.toString() ?? 'N/A'),
        _buildApprovalInfoRow('Driver License',
            profile['driver_license_no']?.toString() ?? 'N/A'),
        _buildApprovalInfoRow(
            'Vehicle Type', profile['vehicle_type']?.toString() ?? 'N/A'),
      ]);
    } else if (role == 'retailer') {
      widgets.addAll([
        _buildApprovalInfoRow(
            'Store Name', profile['store_name']?.toString() ?? 'N/A'),
        _buildApprovalInfoRow(
            'Business Reg No', profile['business_reg_no']?.toString() ?? 'N/A'),
        _buildApprovalInfoRow(
            'Outlet Address', profile['outlet_address']?.toString() ?? 'N/A'),
      ]);
    }

    return widgets;
  }

  Widget _buildApprovalInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: TextStyle(
                color: Colors.grey[600],
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                color: Color(0xFF2C3E50),
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _submittedAtLabel(Map<String, dynamic> user) {
    final raw = user['created_at']?.toString();
    if (raw == null || raw.isEmpty) {
      return 'Unknown';
    }

    final parsed = DateTime.tryParse(raw);
    if (parsed == null) {
      return raw;
    }

    final local = parsed.toLocal();
    final month = local.month.toString().padLeft(2, '0');
    final day = local.day.toString().padLeft(2, '0');
    final hour = local.hour.toString().padLeft(2, '0');
    final minute = local.minute.toString().padLeft(2, '0');
    return '${local.year}-$month-$day $hour:$minute';
  }

  bool _hasVerificationDocument(Map<String, dynamic> user) {
    return _documentUrlFor(user) != null;
  }

  Widget _buildApprovalStatusChip({
    required String label,
    required Color color,
    required IconData icon,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 10,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _showApprovalReviewDialog(Map<String, dynamic> user) async {
    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        final hasDocument = _hasVerificationDocument(user);
        return Dialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              user['name'] ?? 'Unknown Name',
                              style: const TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF2C3E50),
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              (user['email'] ?? 'N/A').toString(),
                              style: TextStyle(
                                color: Colors.grey[600],
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.pop(dialogContext),
                        icon: const Icon(Icons.close_rounded),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _buildApprovalStatusChip(
                        label: (user['role'] ?? 'unknown')
                            .toString()
                            .toUpperCase(),
                        color: const Color(0xFF6C63FF),
                        icon: Icons.badge_outlined,
                      ),
                      _buildApprovalStatusChip(
                        label: hasDocument ? 'DOCUMENT READY' : 'NO DOCUMENT',
                        color: hasDocument
                            ? const Color(0xFF2E7D32)
                            : const Color(0xFFEF6C00),
                        icon: hasDocument
                            ? Icons.verified_outlined
                            : Icons.warning_amber_rounded,
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  _buildApprovalInfoRow(
                      'Phone', user['phone_number']?.toString() ?? 'N/A'),
                  _buildApprovalInfoRow(
                      'Submitted At', _submittedAtLabel(user)),
                  const SizedBox(height: 8),
                  const Text(
                    'Application Details',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                      color: Color(0xFF2C3E50),
                    ),
                  ),
                  const SizedBox(height: 10),
                  ..._buildApprovalDetails(user),
                  if (hasDocument) ...[
                    const SizedBox(height: 12),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: OutlinedButton.icon(
                        onPressed: () => _openVerificationDocument(user),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFF1565C0),
                          side: const BorderSide(color: Color(0xFF1565C0)),
                        ),
                        icon: const Icon(Icons.description_outlined, size: 18),
                        label: const Text('OPEN VERIFICATION DOCUMENT'),
                      ),
                    ),
                  ],
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () {
                            Navigator.pop(dialogContext);
                            _rejectUser(user['id']);
                          },
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.red,
                            side: const BorderSide(color: Colors.red),
                          ),
                          icon: const Icon(Icons.close_rounded, size: 18),
                          label: const Text('REJECT'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () {
                            Navigator.pop(dialogContext);
                            _approveUser(user['id']);
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF4CAF50),
                            foregroundColor: Colors.white,
                          ),
                          icon: const Icon(Icons.check_rounded, size: 18),
                          label: const Text('APPROVE'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Future<void> _logout() async {
    await AuthSessionService.clearAuthSession();
    if (mounted) {
      Navigator.pushNamedAndRemoveUntil(context, '/login', (route) => false);
    }
  }

  // --- UI BUILDERS (REDESIGNED) ---

  Widget _buildOverview() {
    return RefreshIndicator(
      onRefresh: _refreshAllData,
      color: const Color(0xFF6C63FF),
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Welcome header
            StaggeredListItem(
              index: 0,
              child: Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF1A1A2E), Color(0xFF16213E)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF1A1A2E).withValues(alpha: 0.3),
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
                      child: const Icon(Icons.admin_panel_settings,
                          color: Colors.white, size: 32),
                    ),
                    const SizedBox(width: 16),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text("System Health",
                              style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 22,
                                  fontWeight: FontWeight.w700)),
                          SizedBox(height: 4),
                          Text("All systems operational",
                              style: TextStyle(
                                  color: Colors.white70, fontSize: 13)),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.green.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                            color: Colors.green.withValues(alpha: 0.5)),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.circle,
                              color: Colors.greenAccent, size: 8),
                          SizedBox(width: 6),
                          Text("Online",
                              style: TextStyle(
                                  color: Colors.greenAccent,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),

            // Stat cards row 1
            StaggeredListItem(
              index: 1,
              child: Row(children: [
                AnimatedStatCard(
                    title: "Total Batches",
                    value: "${_stats['total_batches']}",
                    color: const Color(0xFF6C63FF),
                    icon: Icons.qr_code_rounded),
                const SizedBox(width: 12),
                AnimatedStatCard(
                    title: "Pending Users",
                    value: "${_stats['pending_users']}",
                    color: const Color(0xFFFF9800),
                    icon: Icons.person_add_rounded),
              ]),
            ),
            const SizedBox(height: 12),

            // Stat cards row 2
            StaggeredListItem(
              index: 2,
              child: Row(children: [
                AnimatedStatCard(
                    title: "Active Issues",
                    value: "${_stats['active_issues']}",
                    color: const Color(0xFFEF5350),
                    icon: Icons.warning_rounded),
                const SizedBox(width: 12),
                AnimatedStatCard(
                    title: "System Status",
                    value: "Online",
                    color: const Color(0xFF4CAF50),
                    icon: Icons.check_circle_rounded),
              ]),
            ),
            const SizedBox(height: 28),

            StaggeredListItem(
              index: 3,
              child: const SectionTitle(
                  title: "Reporting Snapshot",
                  accentColor: Color(0xFF6C63FF)),
            ),
            const SizedBox(height: 12),
            StaggeredListItem(
              index: 4,
              child: _buildReportingSnapshotCard(),
            ),
            const SizedBox(height: 24),

            // Recent batches
            StaggeredListItem(
              index: 5,
              child: const SectionTitle(
                  title: "Recent Batches", accentColor: Color(0xFF6C63FF)),
            ),
            const SizedBox(height: 12),
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _batches.take(5).length,
              itemBuilder: (ctx, i) {
                final batch = _batches[i];
                return StaggeredListItem(
                  index: 6 + i,
                  child: GestureDetector(
                    onTap: () async {
                      await Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => AdminBatchDetailScreen(
                            batchId: batch['id'].toString(),
                          ),
                        ),
                      );
                      if (mounted) {
                        _refreshAllData();
                      }
                    },
                    child: GlassCard(
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: const Color(0xFF6C63FF)
                                  .withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(Icons.inventory_2_rounded,
                                color: Color(0xFF6C63FF), size: 22),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text("Batch ${batch['batch_id']}",
                                    style: const TextStyle(
                                        fontWeight: FontWeight.w700,
                                        fontSize: 15)),
                                const SizedBox(height: 3),
                                Text(
                                    "${batch['product_type']} • ${batch['status']}",
                                    style: TextStyle(
                                        color: Colors.grey[500], fontSize: 12)),
                              ],
                            ),
                          ),
                          const Icon(Icons.chevron_right_rounded,
                              color: Colors.grey),
                        ],
                      ),
                    ),
                  ),
                );
              },
            )
          ],
        ),
      ),
    );
  }

  Widget _buildReportingSnapshotCard() {
    return GlassCard(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "A lightweight management report from the current batch and certificate state.",
            style: TextStyle(color: Colors.grey[600], height: 1.4),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _buildOverviewInsightTile(
                icon: Icons.local_shipping_rounded,
                label: "In Transit",
                value: _metricLabel(_statusBreakdown['in_transit']),
                color: const Color(0xFF1565C0),
              ),
              _buildOverviewInsightTile(
                icon: Icons.inventory_2_rounded,
                label: "Delivered",
                value: _metricLabel(_statusBreakdown['delivered']),
                color: const Color(0xFF2E7D32),
              ),
              _buildOverviewInsightTile(
                icon: Icons.verified_rounded,
                label: "Active Certs",
                value: _metricLabel(_certificateSummary['active']),
                color: const Color(0xFF6C63FF),
              ),
              _buildOverviewInsightTile(
                icon: Icons.gpp_bad_rounded,
                label: "Revoked Certs",
                value: _metricLabel(_certificateSummary['revoked']),
                color: const Color(0xFFC62828),
              ),
              _buildOverviewInsightTile(
                icon: Icons.schedule_rounded,
                label: "Expiring Soon",
                value: _metricLabel(_certificateSummary['expiring_soon']),
                color: const Color(0xFFFF9800),
              ),
              _buildOverviewInsightTile(
                icon: Icons.event_busy_rounded,
                label: "Expired Certs",
                value: _metricLabel(_certificateSummary['expired']),
                color: const Color(0xFF8D6E63),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildOverviewInsightTile({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Container(
      width: 150,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: color.withValues(alpha: 0.16)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 18),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(color: Colors.grey[600], fontSize: 12),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF2C3E50),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUserApprovals() {
    if (_pendingUsers.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.check_circle_outline_rounded,
                size: 80, color: Colors.green[200]),
            const SizedBox(height: 16),
            Text("All Clear!",
                style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    color: Colors.grey[700])),
            const SizedBox(height: 8),
            Text("No pending applications at this time.",
                style: TextStyle(color: Colors.grey[400])),
          ],
        ),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.all(20),
      itemCount: _pendingUsers.length,
      itemBuilder: (context, index) {
        final user = _pendingUsers[index];
        return StaggeredListItem(
          index: index,
          child: GlassCard(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: const Color(0xFF6C63FF).withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text("${user['role']}",
                          style: const TextStyle(
                              color: Color(0xFF6C63FF),
                              fontWeight: FontWeight.w700,
                              fontSize: 12)),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                            colors: [Color(0xFFFF9800), Color(0xFFFFA726)]),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Text("Pending",
                          style: TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.w700)),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Text(user['name'] ?? 'Unknown Name',
                    style: const TextStyle(
                        fontSize: 18, fontWeight: FontWeight.w700)),
                const SizedBox(height: 4),
                Text(user['email'],
                    style: TextStyle(color: Colors.grey[500], fontSize: 13)),
                const SizedBox(height: 4),
                Text("Phone: ${user['phone_number'] ?? 'N/A'}",
                    style: TextStyle(color: Colors.grey[500], fontSize: 13)),
                const SizedBox(height: 4),
                Text("Submitted: ${_submittedAtLabel(user)}",
                    style: TextStyle(color: Colors.grey[500], fontSize: 13)),
                const SizedBox(height: 12),
                ..._buildApprovalDetails(user),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _buildApprovalStatusChip(
                      label:
                          (user['registration_status'] ?? 'pending').toString().toUpperCase(),
                      color: (user['registration_status'] ?? 'pending') == 'rejected'
                          ? const Color(0xFFC62828)
                          : (user['registration_status'] ?? 'pending') == 'approved'
                              ? const Color(0xFF2E7D32)
                              : const Color(0xFFEF6C00),
                      icon: (user['registration_status'] ?? 'pending') == 'approved'
                          ? Icons.verified_rounded
                          : Icons.pending_actions_rounded,
                    ),
                    _buildApprovalStatusChip(
                      label: _hasVerificationDocument(user)
                          ? 'DOCUMENT READY'
                          : 'NO DOCUMENT',
                      color: _hasVerificationDocument(user)
                          ? const Color(0xFF2E7D32)
                          : const Color(0xFFEF6C00),
                      icon: _hasVerificationDocument(user)
                          ? Icons.verified_outlined
                          : Icons.warning_amber_rounded,
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                Row(children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _showApprovalReviewDialog(user),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFF1565C0),
                        side: const BorderSide(color: Color(0xFF1565C0)),
                      ),
                      icon: const Icon(Icons.visibility_outlined, size: 18),
                      label: const Text("REVIEW"),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () => _approveUser(user['id']),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF4CAF50),
                        foregroundColor: Colors.white,
                      ),
                      icon: const Icon(Icons.check_rounded, size: 18),
                      label: const Text("APPROVE"),
                    ),
                  ),
                ]),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildBatchOversight() {
    final visibleBatches = _visibleBatches;

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            children: [
              TextField(
                controller: _searchController,
                onChanged: _onSearchChanged,
                decoration: InputDecoration(
                  hintText: "Search Batch ID or Product...",
                  hintStyle: TextStyle(color: Colors.grey[400]),
                  prefixIcon:
                      Icon(Icons.search_rounded, color: Colors.grey[400]),
                  suffixIcon: _searchController.text.isNotEmpty
                      ? IconButton(
                          icon:
                              Icon(Icons.clear_rounded, color: Colors.grey[400]),
                          onPressed: () {
                            _searchController.clear();
                            _onSearchChanged('');
                          },
                        )
                      : null,
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
              const SizedBox(height: 14),
              Align(
                alignment: Alignment.centerLeft,
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _batchStatusFilters.map((filter) {
                    final isSelected =
                        _selectedBatchStatusFilter == filter['value'];
                    return ChoiceChip(
                      label: Text(filter['label']!),
                      selected: isSelected,
                      onSelected: (_) {
                        setState(() {
                          _selectedBatchStatusFilter = filter['value']!;
                        });
                      },
                      selectedColor:
                          const Color(0xFF6C63FF).withValues(alpha: 0.15),
                      labelStyle: TextStyle(
                        color: isSelected
                            ? const Color(0xFF6C63FF)
                            : Colors.grey[700],
                        fontWeight: FontWeight.w600,
                      ),
                      side: BorderSide(
                        color: isSelected
                            ? const Color(0xFF6C63FF).withValues(alpha: 0.35)
                            : Colors.grey.withValues(alpha: 0.18),
                      ),
                      backgroundColor: Colors.white,
                    );
                  }).toList(growable: false),
                ),
              ),
              const SizedBox(height: 12),
              GlassCard(
                padding: const EdgeInsets.all(14),
                child: Row(
                  children: [
                    _buildBatchOversightSummary(
                      label: 'Visible',
                      value: '${visibleBatches.length}',
                    ),
                    const SizedBox(width: 10),
                    _buildBatchOversightSummary(
                      label: 'Search',
                      value: _searchController.text.isEmpty ? 'Off' : 'On',
                    ),
                    const SizedBox(width: 10),
                    _buildBatchOversightSummary(
                      label: 'Filter',
                      value: _batchStatusFilters.firstWhere(
                        (filter) => filter['value'] == _selectedBatchStatusFilter,
                        orElse: () => const {'label': 'All', 'value': 'all'},
                      )['label']!,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: visibleBatches.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.search_off_rounded,
                          size: 60, color: Colors.grey[300]),
                      const SizedBox(height: 12),
                      Text("No batches found.",
                          style: TextStyle(color: Colors.grey[400])),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  itemCount: visibleBatches.length,
                  itemBuilder: (context, index) {
                    final batch = visibleBatches[index];
                    return StaggeredListItem(
                      index: index,
                      child: GestureDetector(
                        onTap: () async {
                          await Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => AdminBatchDetailScreen(
                                batchId: batch['id'].toString(),
                              ),
                            ),
                          );
                          if (mounted) {
                            _refreshAllData();
                          }
                        },
                        child: GlassCard(
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF6C63FF)
                                      .withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(14),
                                ),
                                child: const Icon(Icons.qr_code_rounded,
                                    color: Color(0xFF6C63FF)),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text("Batch ${batch['batch_id']}",
                                        style: const TextStyle(
                                            fontWeight: FontWeight.w700)),
                                    const SizedBox(height: 3),
                                    Text(
                                        "${batch['product_type']} (${batch['weight']})",
                                        style: TextStyle(
                                            color: Colors.grey[500],
                                            fontSize: 12)),
                                  ],
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 10, vertical: 5),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF6C63FF)
                                      .withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Text(batch['status'],
                                    style: const TextStyle(
                                        color: Color(0xFF6C63FF),
                                        fontWeight: FontWeight.w700,
                                        fontSize: 11)),
                              ),
                            ],
                          ),
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
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.shield_rounded, size: 80, color: Colors.green[200]),
            const SizedBox(height: 16),
            Text("No Incidents",
                style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    color: Colors.grey[700])),
            const SizedBox(height: 8),
            Text("Everything is running smoothly.",
                style: TextStyle(color: Colors.grey[400])),
          ],
        ),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.all(20),
      itemCount: _incidents.length,
      itemBuilder: (context, index) {
        final item = _incidents[index];
        return StaggeredListItem(
          index: index,
          child: Container(
            margin: const EdgeInsets.only(bottom: 16),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.9),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                  color: Colors.red.withValues(alpha: 0.15), width: 1),
              boxShadow: [
                BoxShadow(
                  color: Colors.red.withValues(alpha: 0.06),
                  blurRadius: 15,
                  offset: const Offset(0, 5),
                ),
              ],
            ),
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                              colors: [Color(0xFFEF5350), Color(0xFFE53935)]),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.warning_rounded,
                                color: Colors.white, size: 12),
                            const SizedBox(width: 4),
                            Text(item['issue_type'] ?? 'INCIDENT',
                                style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 10,
                                    fontWeight: FontWeight.w700)),
                          ],
                        ),
                      ),
                      Text(item['created_at'].toString().substring(0, 10),
                          style:
                              TextStyle(color: Colors.grey[400], fontSize: 12)),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Text("Batch: ${item['batch_id']}",
                      style: const TextStyle(
                          fontSize: 16, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 6),
                  Text(item['description'] ?? 'No details provided',
                      style: TextStyle(color: Colors.grey[600], fontSize: 13)),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Icon(Icons.location_on_rounded,
                          size: 14, color: Colors.grey[400]),
                      const SizedBox(width: 4),
                      Text("${item['location']}",
                          style:
                              TextStyle(color: Colors.grey[400], fontSize: 12)),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildBatchOversightSummary({
    required String label,
    required String value,
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0xFF6C63FF).withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: TextStyle(color: Colors.grey[600], fontSize: 12),
            ),
            const SizedBox(height: 4),
            Text(
              value,
              style: const TextStyle(
                fontWeight: FontWeight.w700,
                color: Color(0xFF2C3E50),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDrawer() {
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
                    Color(0xFF1A1A2E),
                    Color(0xFF16213E),
                    Color(0xFF0F3460)
                  ],
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: const Icon(Icons.admin_panel_settings,
                        size: 32, color: Colors.white),
                  ),
                  const SizedBox(height: 16),
                  const Text("System Administrator",
                      style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                          fontSize: 18)),
                  const SizedBox(height: 4),
                  Text("admin@halalchain.my",
                      style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.7),
                          fontSize: 13)),
                ],
              ),
            ),
            const SizedBox(height: 8),
            _buildDrawerItem(Icons.dashboard_rounded, "System Overview", 0),
            _buildDrawerItem(Icons.verified_user_rounded, "User Approvals", 1,
                badge: _pendingUsers.isNotEmpty ? _pendingUsers.length : null),
            _buildDrawerItem(Icons.view_list_rounded, "Master Batch List", 2),
            _buildDrawerItem(Icons.warning_rounded, "Incident Center", 3),
            const Spacer(),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Divider(color: Colors.grey[200]),
            ),
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.red.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.logout_rounded,
                    color: Colors.red, size: 20),
              ),
              title: const Text("Admin Logout",
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

  Widget _buildDrawerItem(IconData icon, String title, int index,
      {int? badge}) {
    final isSelected = _selectedIndex == index;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
      child: ListTile(
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: isSelected
                ? const Color(0xFF6C63FF).withValues(alpha: 0.1)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon,
              color: isSelected ? const Color(0xFF6C63FF) : Colors.grey[600],
              size: 22),
        ),
        title: Text(title,
            style: TextStyle(
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                color:
                    isSelected ? const Color(0xFF6C63FF) : Colors.grey[700])),
        trailing: badge != null
            ? Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                      colors: [Color(0xFFEF5350), Color(0xFFE53935)]),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text("$badge",
                    style: const TextStyle(
                        fontSize: 11,
                        color: Colors.white,
                        fontWeight: FontWeight.w700)),
              )
            : null,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        selected: isSelected,
        selectedTileColor: const Color(0xFF6C63FF).withValues(alpha: 0.04),
        onTap: () {
          setState(() => _selectedIndex = index);
          Navigator.pop(context);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final titles = [
      "Admin Dashboard",
      "Pending Approvals",
      "Batch Oversight",
      "Incident Logs"
    ];

    return Scaffold(
      backgroundColor: Colors.transparent,
      extendBodyBehindAppBar: false,
      appBar: GradientAppBar(
        title: titles[_selectedIndex],
        gradientColors: const [
          Color(0xFF1A1A2E),
          Color(0xFF16213E),
          Color(0xFF0F3460),
        ],
      ),
      drawer: _buildDrawer(),
      body: GradientBackground(
        colors: const [Color(0xFFF0F0F5), Color(0xFFE8EAF6), Color(0xFFF5F5FA)],
        child: _isLoading
            ? const ShimmerLoader(itemCount: 5)
            : AnimatedViewSwitcher(
                child: KeyedSubtree(
                  key: ValueKey<int>(_selectedIndex),
                  child: _selectedIndex == 0
                      ? _buildOverview()
                      : _selectedIndex == 1
                          ? _buildUserApprovals()
                          : _selectedIndex == 2
                              ? _buildBatchOversight()
                              : _buildIncidentReports(),
                ),
              ),
      ),
    );
  }
}

/// Read-only detail page for inspecting batch traceability as an admin.
class AdminBatchDetailScreen extends StatefulWidget {
  final String batchId;
  const AdminBatchDetailScreen({super.key, required this.batchId});

  @override
  State<AdminBatchDetailScreen> createState() => _AdminBatchDetailScreenState();
}

class _AdminBatchDetailScreenState extends State<AdminBatchDetailScreen> {
  bool _isLoading = true;
  bool _isRevoking = false;
  Map<String, dynamic>? _batchData;

  @override
  void initState() {
    super.initState();
    _fetchBatchDetails();
  }

  Future<void> _fetchBatchDetails() async {
    try {
      final token = await AuthSessionService.getToken();
      final response = await http.get(
        Uri.parse('$baseUrl/batches/${widget.batchId}'),
        headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'application/json'
        },
      );

      if (response.statusCode == 200) {
        setState(() {
          _batchData = jsonDecode(response.body)['batch'];
          _isLoading = false;
        });
      } else {
        setState(() => _isLoading = false);
      }
    } catch (e) {
      debugPrint("Error fetching detail: $e");
      setState(() => _isLoading = false);
    }
  }

  Future<void> _revokeCertificate() async {
    if (_batchData == null || _isRevoking) return;
    if ((_batchData!['qr_revoked_at'] ?? '').toString().isNotEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('This certificate has already been revoked.')),
      );
      return;
    }

    setState(() => _isRevoking = true);
    try {
      final token = await AuthSessionService.getToken();
      final response = await http.post(
        Uri.parse('$baseUrl/admin/batches/${widget.batchId}/revoke-certificate'),
        headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'application/json',
        },
      );

      if (!mounted) return;

      if (response.statusCode == 200) {
        setState(() {
          _batchData = {
            ...?_batchData,
            'qr_revoked_at': DateTime.now().toIso8601String(),
            'status': 'Invalid - Certificate Revoked',
            'halal_status': 'breached',
          };
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Certificate revoked successfully.')),
        );
        await _fetchBatchDetails();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Unable to revoke certificate.')),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Connection error while revoking certificate.')),
      );
    } finally {
      if (mounted) setState(() => _isRevoking = false);
    }
  }

  bool get _isCertificateRevoked =>
      (_batchData?['qr_revoked_at'] ?? '').toString().isNotEmpty;

  String _certificateStatusLabel() {
    if (_batchData == null) return 'Unknown';
    if (_isCertificateRevoked) return 'Revoked';

    final raw = (_batchData!['certificate_valid_until'] ?? '').toString();
    final expiresAt = DateTime.tryParse(raw);
    if (expiresAt == null) return 'Missing expiry';
    if (expiresAt.isBefore(DateTime.now())) return 'Expired';
    return 'Active';
  }

  String _qrStatusLabel() {
    if (_batchData == null) return 'Unavailable';
    if (_isCertificateRevoked) return 'Revoked';
    return (_batchData!['qr_generated_at'] ?? '').toString().isNotEmpty
        ? 'Signed'
        : 'Not generated';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        title: const Text("Batch Details",
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF6C63FF),
        elevation: 0,
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xFF6C63FF)))
          : _batchData == null
              ? Center(
                  child: Text("Error loading details.",
                      style: TextStyle(color: Colors.grey[600])))
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildHeaderCard(),
                      const SizedBox(height: 24),
                      const SectionTitle(
                          title: "Product Information",
                          accentColor: Color(0xFF6C63FF)),
                      const SizedBox(height: 12),
                      _buildInfoCard(),
                      const SizedBox(height: 24),
                      const SectionTitle(
                          title: "Certificate Governance",
                          accentColor: Color(0xFF6C63FF)),
                      const SizedBox(height: 12),
                      _buildCertificateGovernanceCard(),
                      const SizedBox(height: 24),
                      const SectionTitle(
                          title: "Transit & Timeline",
                          accentColor: Color(0xFF6C63FF)),
                      const SizedBox(height: 12),
                      _buildTimeline(),
                    ],
                  ),
                ),
    );
  }

  Widget _buildHeaderCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF6C63FF), Color(0xFF5A52D5)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
              color: const Color(0xFF6C63FF).withValues(alpha: 0.3),
              blurRadius: 15,
              offset: const Offset(0, 8))
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(_batchData!['status'],
                    style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 12)),
              ),
              GestureDetector(
                onTap: () {
                  showDialog(
                    context: context,
                    builder: (context) => Dialog(
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20)),
                      child: Container(
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Text("Batch QR Code",
                                style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF2C3E50))),
                            const SizedBox(height: 20),
                            QrImageView(
                              data: (_batchData!['qr_code_payload'] ??
                                      _batchData!['qr_code_hash'] ??
                                      _batchData!['batch_id'])
                                  .toString(),
                              version: QrVersions.auto,
                              size: 200.0,
                            ),
                            const SizedBox(height: 20),
                            Text(_batchData!['batch_id'],
                                style: TextStyle(
                                    fontSize: 14,
                                    color: Colors.grey[600],
                                    fontWeight: FontWeight.w500)),
                            const SizedBox(height: 20),
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton(
                                onPressed: () => Navigator.pop(context),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF6C63FF),
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12)),
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 12),
                                ),
                                child: const Text("Close"),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.qr_code, color: Colors.white),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(_batchData!['batch_id'],
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          Text(
              "Held by: ${_batchData!['current_holder']?['name'] ?? 'Unknown'}",
              style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.8), fontSize: 13)),
          const SizedBox(height: 16),
          if ((_batchData!['certificate_no'] ?? '').toString().isNotEmpty)
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed:
                    _isRevoking || _isCertificateRevoked ? null : _revokeCertificate,
                icon: _isRevoking
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.block_rounded),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFC62828),
                  foregroundColor: Colors.white,
                ),
                label: Text(_isRevoking
                    ? 'Revoking...'
                    : _isCertificateRevoked
                        ? 'CERTIFICATE REVOKED'
                        : 'REVOKE CERTIFICATE'),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildInfoCard() {
    return GlassCard(
      child: Column(
        children: [
          _buildDetailRow("Product Type", _batchData!['product_type']),
          const Divider(height: 24),
          _buildDetailRow("Weight", _batchData!['weight']),
          const Divider(height: 24),
          _buildDetailRow("Slaughter Date", _batchData!['slaughter_date']),
          const Divider(height: 24),
          _buildDetailRow("Certificate No",
              (_batchData!['certificate_no'] ?? 'N/A').toString()),
          const Divider(height: 24),
          _buildDetailRow("Authority",
              (_batchData!['certificate_authority'] ?? 'N/A').toString()),
          const Divider(height: 24),
          _buildDetailRow("Certificate Valid Until",
              (_batchData!['certificate_valid_until'] ?? 'N/A').toString()),
          const Divider(height: 24),
          _buildDetailRow("Certificate Status", _certificateStatusLabel()),
          const Divider(height: 24),
          _buildDetailRow("QR Status", _qrStatusLabel()),
          const Divider(height: 24),
          _buildDetailRow(
              "Halal Status", (_batchData!['halal_status'] ?? 'unknown').toString()),
          const Divider(height: 24),
          _buildDetailRow("Origin Farm", _batchData!['origin_farm']),
          const Divider(height: 24),
          _buildDetailRow(
              "Freshness Score", "${_batchData!['freshness_score']}/100"),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          flex: 3,
          child: Text(label, style: TextStyle(color: Colors.grey[600], fontSize: 13)),
        ),
        const SizedBox(width: 16),
        Expanded(
          flex: 5,
          child: Text(
            value,
            textAlign: TextAlign.right,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
                fontWeight: FontWeight.bold, color: Color(0xFF2C3E50)),
          ),
        ),
      ],
    );
  }

  List<Map<String, dynamic>> _certificateGovernanceEvents() {
    final events = <Map<String, dynamic>>[];
    if (_batchData == null) {
      return events;
    }

    final createdAt = (_batchData!['created_at'] ?? '').toString();
    final validUntil = (_batchData!['certificate_valid_until'] ?? '').toString();
    final qrGeneratedAt = (_batchData!['qr_generated_at'] ?? '').toString();
    final qrRevokedAt = (_batchData!['qr_revoked_at'] ?? '').toString();

    events.add({
      'title': 'Certificate Snapshot Attached',
      'detail': (_batchData!['certificate_no'] ?? 'No certificate number')
          .toString(),
      'date': _formatGovernanceDate(createdAt),
      'icon': Icons.assignment_turned_in_rounded,
      'color': const Color(0xFF6C63FF),
    });

    if (validUntil.isNotEmpty) {
      events.add({
        'title': _certificateStatusLabel() == 'Expired'
            ? 'Certificate Expired'
            : 'Certificate Valid Until',
        'detail': validUntil,
        'date': _formatGovernanceDate(validUntil),
        'icon': _certificateStatusLabel() == 'Expired'
            ? Icons.event_busy_rounded
            : Icons.event_available_rounded,
        'color': _certificateStatusLabel() == 'Expired'
            ? const Color(0xFFC62828)
            : const Color(0xFF2E7D32),
      });
    }

    if (qrGeneratedAt.isNotEmpty) {
      events.add({
        'title': 'Traceability QR Activated',
        'detail': _qrStatusLabel(),
        'date': _formatGovernanceDate(qrGeneratedAt),
        'icon': Icons.qr_code_2_rounded,
        'color': const Color(0xFF1565C0),
      });
    }

    if (qrRevokedAt.isNotEmpty) {
      events.add({
        'title': 'Certificate Revoked',
        'detail': 'Batch public verification disabled',
        'date': _formatGovernanceDate(qrRevokedAt),
        'icon': Icons.gpp_bad_rounded,
        'color': const Color(0xFFC62828),
      });
    }

    return events;
  }

  Widget _buildCertificateGovernanceCard() {
    final events = _certificateGovernanceEvents();

    return GlassCard(
      child: Column(
        children: List.generate(events.length, (index) {
          final event = events[index];
          final isLast = index == events.length - 1;
          return Padding(
            padding: EdgeInsets.only(bottom: isLast ? 0 : 16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Column(
                  children: [
                    Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        color: (event['color'] as Color).withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Icon(
                        event['icon'] as IconData,
                        color: event['color'] as Color,
                      ),
                    ),
                    if (!isLast)
                      Container(
                        width: 2,
                        height: 34,
                        margin: const EdgeInsets.symmetric(vertical: 6),
                        color:
                            (event['color'] as Color).withValues(alpha: 0.20),
                      ),
                  ],
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        event['title'].toString(),
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF2C3E50),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        event['detail'].toString(),
                        style: TextStyle(
                          color: Colors.grey[700],
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        event['date'].toString(),
                        style: TextStyle(
                          color: Colors.grey[500],
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        }),
      ),
    );
  }

  String _formatGovernanceDate(String raw) {
    if (raw.isEmpty) {
      return 'Unknown date';
    }

    final parsed = DateTime.tryParse(raw);
    if (parsed == null) {
      return raw;
    }

    final local = parsed.toLocal();
    final month = local.month.toString().padLeft(2, '0');
    final day = local.day.toString().padLeft(2, '0');
    return '${local.year}-$month-$day';
  }

  Widget _buildTimeline() {
    final checkpoints = _batchData!['checkpoints'] as List<dynamic>? ?? [];
    final routePoints = BatchRouteMapper.toMapPoints(checkpoints);

    if (checkpoints.isEmpty) {
      return Column(
        children: [
          RouteMapCard(
            title: 'Transit Route',
            points: routePoints,
            totalCheckpoints: checkpoints.length,
          ),
          GlassCard(
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: Center(
                  child: Text("No checkpoints recorded yet.",
                      style: TextStyle(color: Colors.grey[500]))),
            ),
          ),
        ],
      );
    }

    return Column(
      children: [
        RouteMapCard(
          title: 'Transit Route',
          points: routePoints,
          totalCheckpoints: checkpoints.length,
        ),
        GlassCard(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: List.generate(checkpoints.length, (index) {
              final cp = checkpoints[index];
              final isLast = index == checkpoints.length - 1;
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Column(
                    children: [
                      Container(
                        width: 14,
                        height: 14,
                        decoration: const BoxDecoration(
                            color: Color(0xFF6C63FF), shape: BoxShape.circle),
                      ),
                      if (!isLast)
                        Container(
                            width: 2,
                            height: 50,
                            color:
                                const Color(0xFF6C63FF).withValues(alpha: 0.3)),
                    ],
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(cp['location_name'],
                            style: const TextStyle(fontWeight: FontWeight.bold)),
                        const SizedBox(height: 4),
                        Text(
                            "${cp['action_type'].toString().toUpperCase()} • Temp: ${cp['temperature']}°C",
                            style: TextStyle(
                                color: Colors.grey[600], fontSize: 12)),
                        if (cp['notes'] != null) ...[
                          const SizedBox(height: 4),
                          Text('"${cp['notes']}"',
                              style: TextStyle(
                                  color: Colors.grey[500],
                                  fontSize: 12,
                                  fontStyle: FontStyle.italic)),
                        ],
                        const SizedBox(height: 16),
                      ],
                    ),
                  ),
                ],
              );
            }),
          ),
        ),
      ],
    );
  }
}
