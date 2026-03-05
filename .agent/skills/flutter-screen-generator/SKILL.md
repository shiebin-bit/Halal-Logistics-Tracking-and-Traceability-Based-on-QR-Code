---
name: flutter-screen-generator
description: "Generate complete Flutter screens including UI layout, state management, API calls, and navigation."
risk: low
source: project
date_added: "2026-03-05"
---

# Flutter Screen Generator

## Overview

This skill generates complete, production-ready Flutter screens for the Halal Traceability app. Each generated screen includes layout, API integration, loading/error states, and navigation wiring.

## When to Use

- User asks to build a new screen (e.g., "create a batch detail page").
- Adding a new role-specific dashboard.
- Building feature screens like QR scanner, incident report form, or audit log viewer.

---

## Project Context

Before generating any screen, understand the existing project structure:

```
lib/
├── config.dart              # API base URL constants
├── main.dart                # MaterialApp with named routes & theme
└── screens/
    ├── splash_screen.dart
    ├── login_screen.dart
    ├── registration_screen.dart
    ├── audit_log_screen.dart
    └── dashboards/
        ├── admin_dashboard.dart
        ├── processor_dashboard.dart
        ├── logistics_dashboard.dart
        ├── retailer_dashboard.dart
        └── consumer_dashboard.dart
```

**Key conventions already established:**
- API base URL imported from `config.dart` (`baseUrl`, `apiBaseUrl`, `storageUrl`).
- Named routes defined in `main.dart` `routes:` map.
- Theme: Material 3, seed color `0xFF1B5E20` (Forest Green).
- Screens are `StatefulWidget` with direct `http` calls.

---

## Screen Generation Workflow

### Step 1: Define Screen Purpose
- **Role**: Which user role sees this screen?
- **Data source**: Which API endpoint(s) does it call?
- **Actions**: Read-only, or does the user submit data?

### Step 2: Create the File
Place the file according to this convention:
- Dashboards → `lib/screens/dashboards/<role>_dashboard.dart`
- Feature screens → `lib/screens/<feature_name>_screen.dart`
- Shared widgets → `lib/widgets/<widget_name>.dart` (create this directory if needed)

### Step 3: Implement the Widget Structure

Every generated screen must follow this template:

```dart
import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config.dart'; // Adjust relative path as needed

class ExampleScreen extends StatefulWidget {
  const ExampleScreen({super.key});

  @override
  State<ExampleScreen> createState() => _ExampleScreenState();
}

class _ExampleScreenState extends State<ExampleScreen> {
  bool _isLoading = true;
  String? _error;
  // ... data variables

  @override
  void initState() {
    super.initState();
    _fetchData();
  }

  Future<void> _fetchData() async {
    try {
      setState(() { _isLoading = true; _error = null; });
      final response = await http.get(
        Uri.parse('$apiBaseUrl/endpoint'),
        headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'application/json',
        },
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() { /* parse data */ _isLoading = false; });
      } else {
        setState(() { _error = 'Failed to load data'; _isLoading = false; });
      }
    } catch (e) {
      setState(() { _error = e.toString(); _isLoading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Screen Title')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Text(_error!, style: TextStyle(color: Colors.red)))
              : _buildContent(),
    );
  }

  Widget _buildContent() {
    // Main screen content here
    return const Placeholder();
  }
}
```

### Step 4: Handle All Three States
Every screen **must** handle:

| State | Widget |
|---|---|
| Loading | `Center(child: CircularProgressIndicator())` |
| Error | `Center` with error text + optional retry button |
| Success | Actual content via `_buildContent()` |

### Step 5: Wire Navigation
After creating the screen, register it in `main.dart`:

```dart
routes: {
  // ...existing routes...
  '/new-route': (context) => const NewScreen(),
},
```

Navigate to it using:
```dart
Navigator.pushNamed(context, '/new-route');
```

### Step 6: Apply the Theme
- Use `Theme.of(context).colorScheme` — never hardcode colors.
- Use `Theme.of(context).textTheme` — never use raw `TextStyle(fontSize: ...)`.
- Use the existing `InputDecorationTheme` for all form fields.

---

## API Integration Patterns

### GET (fetch data)
```dart
final response = await http.get(
  Uri.parse('$apiBaseUrl/batches'),
  headers: {'Authorization': 'Bearer $token', 'Accept': 'application/json'},
);
```

### POST (submit data)
```dart
final response = await http.post(
  Uri.parse('$apiBaseUrl/batches'),
  headers: {'Authorization': 'Bearer $token', 'Content-Type': 'application/json'},
  body: jsonEncode({'product_name': name, 'quantity': qty}),
);
```

### Multipart (file upload)
```dart
final request = http.MultipartRequest('POST', Uri.parse('$apiBaseUrl/user/update'));
request.headers['Authorization'] = 'Bearer $token';
request.files.add(await http.MultipartFile.fromPath('profile_image', filePath));
final response = await request.send();
```

---

## Security Checks

- [ ] Auth token is retrieved from secure storage — never hardcoded.
- [ ] Token is passed via `Authorization: Bearer` header on every authenticated request.
- [ ] Error responses don't expose raw server messages to the user — sanitize before displaying.
- [ ] Form inputs are validated client-side with `TextFormField` validators before API submission.
- [ ] Sensitive screens (admin, reports) check the user role before rendering content.
- [ ] Image/file uploads validate file size and type before sending.
