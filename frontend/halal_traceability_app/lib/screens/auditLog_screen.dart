import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

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
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('auth_token');

      // NOTE: Use 10.0.2.2 for Android Emulator
      final response = await http.get(
        Uri.parse('http://10.0.2.2:8000/api/reports/audit-logs'),
        headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'application/json' // Good practice
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() {
          // Handle both { "data": [...] } and direct [...] formats
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
        // Handle Server Error
        setState(() {
          _errorMessage = "Server Error: ${response.statusCode}";
          _isLoading = false;
          _useMockData(); // Fallback for testing
        });
      }
    } catch (e) {
      // Handle Connection Error
      setState(() {
        _errorMessage = "Connection Failed";
        _isLoading = false;
        _useMockData(); // Fallback for testing
      });
    }
  }

  // Fallback Data so you can see the UI working
  void _useMockData() {
    _logs = [
      {
        "batch_id": "B-2025-001",
        "action": "Batch Created",
        "timestamp": "2026-01-10 08:30 AM"
      },
      {
        "batch_id": "B-2025-001",
        "action": "Handover to Logistics",
        "timestamp": "2026-01-10 10:15 AM"
      },
      {
        "batch_id": "B-2025-002",
        "action": "Temperature Check (Pass)",
        "timestamp": "2026-01-11 02:45 PM"
      },
    ];
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
