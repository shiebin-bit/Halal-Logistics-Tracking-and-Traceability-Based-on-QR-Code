import 'package:flutter/material.dart';

import 'role_assistant_sheet.dart';

class RoleAssistantLauncher extends StatelessWidget {
  const RoleAssistantLauncher({
    super.key,
    required this.role,
    required this.screen,
    required this.title,
    required this.accentColor,
    required this.contextBuilder,
    this.label = 'Ask Assistant',
  });

  final String role;
  final String screen;
  final String title;
  final Color accentColor;
  final String label;
  final Map<String, dynamic> Function() contextBuilder;

  @override
  Widget build(BuildContext context) {
    return FloatingActionButton.extended(
      heroTag: '$role-$screen-assistant',
      onPressed: () {
        showModalBottomSheet<void>(
          context: context,
          isScrollControlled: true,
          backgroundColor: Colors.transparent,
          builder: (_) => FractionallySizedBox(
            heightFactor: 0.93,
            child: RoleAssistantSheet(
              role: role,
              screen: screen,
              title: title,
              accentColor: accentColor,
              contextBuilder: contextBuilder,
            ),
          ),
        );
      },
      backgroundColor: accentColor,
      foregroundColor: Colors.white,
      icon: const Icon(Icons.auto_awesome_rounded),
      label: Text(
        label,
        style: const TextStyle(fontWeight: FontWeight.w700),
      ),
    );
  }
}
