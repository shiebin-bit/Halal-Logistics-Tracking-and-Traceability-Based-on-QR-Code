import 'package:flutter/material.dart';

import 'role_assistant_sheet.dart';

class RoleAssistantPage extends StatelessWidget {
  const RoleAssistantPage({
    super.key,
    required this.role,
    required this.screen,
    required this.title,
    required this.accentColor,
    required this.contextBuilder,
  });

  final String role;
  final String screen;
  final String title;
  final Color accentColor;
  final Map<String, dynamic> Function() contextBuilder;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF2F5FA),
      appBar: AppBar(
        title: Text(title),
        backgroundColor: accentColor,
        foregroundColor: Colors.white,
      ),
      body: RoleAssistantSheet(
        role: role,
        screen: screen,
        title: title,
        accentColor: accentColor,
        contextBuilder: contextBuilder,
        showCloseButton: false,
      ),
    );
  }
}
