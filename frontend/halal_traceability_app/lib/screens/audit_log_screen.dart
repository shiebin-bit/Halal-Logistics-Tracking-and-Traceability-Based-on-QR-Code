import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../config.dart';
import '../services/auth_session_service.dart';

/// Displays recent audit checkpoints from the backend reporting endpoint.
class AuditLogScreen extends StatefulWidget {
  const AuditLogScreen({super.key});

  @override
  State<AuditLogScreen> createState() => _AuditLogScreenState();
}

class _AuditLogScreenState extends State<AuditLogScreen> {
  List<dynamic> _logs = [];
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _fetchLogs();
  }

  Future<void> _fetchLogs() async {
    try {
      final token = await AuthSessionService.getToken();
      if (token == null) {
        setState(() {
          _errorMessage = "Session expired";
          _logs = [];
          _isLoading = false;
        });
        return;
      }

      final response = await http.get(
        Uri.parse('$apiBaseUrl/reports/audit-logs'),
        headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'application/json'
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() {
          // Handle both { "data": [...] } and direct [...] response formats
          if (data is Map && data.containsKey('data')) {
            _logs = data['data'];
          } else if (data is List) {
            _logs = data;
          } else {
            _logs = [];
          }
          _isLoading = false;
        });
      } else {
        setState(() {
          _errorMessage = "Server Error: ${response.statusCode}";
          _logs = [];
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = "Connection Failed";
        _logs = [];
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
          title: const Text("Audit Logs"),
          backgroundColor: const Color(0xFF1B5E20),
          foregroundColor: Colors.white),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _logs.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.history_toggle_off,
                          size: 50, color: Colors.grey),
                      const SizedBox(height: 10),
                      Text(_errorMessage ?? "No logs found"),
                    ],
                  ),
                )
              : ListView.separated(
                  itemCount: _logs.length,
                  separatorBuilder: (c, i) => const Divider(),
                  itemBuilder: (context, index) {
                    final log = _logs[index];
                    return ListTile(
                      leading: CircleAvatar(
                        backgroundColor: Colors.green[50],
                        child:
                            const Icon(Icons.history, color: Color(0xFF1B5E20)),
                      ),
                      title: Text(log['batch_id'] ?? 'Unknown Batch',
                          style: const TextStyle(fontWeight: FontWeight.bold)),
                      subtitle: Text(log['action'] ?? 'Unknown Action'),
                      trailing: Text(log['timestamp'] ?? '',
                          style: const TextStyle(
                              fontSize: 12, color: Colors.grey)),
                    );
                  },
                ),
    );
  }
}
