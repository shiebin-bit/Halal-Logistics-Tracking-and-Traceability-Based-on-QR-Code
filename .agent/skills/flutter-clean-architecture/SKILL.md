---
name: flutter-clean-architecture
description: "Guides Flutter development for this project using clean architecture principles: separation of data, domain, and presentation layers, with role-aware UI patterns."
risk: low
source: project
date_added: "2026-03-05"
---

# Flutter Clean Architecture

## Overview

This skill enforces clean architecture and consistent patterns throughout the Flutter frontend of the Halal Traceability app. Apply it when building new screens, refactoring existing widgets, or reviewing Dart code.

## Project Roles & Screens

The app serves 5 roles: `admin`, `processor`, `logistics`, `retailer`, `consumer`. Each role has dedicated screens and must only see their relevant data. Shared screens (login, profile) are role-aware.

## Layer Structure

```
lib/
├── data/
│   ├── models/          # JSON serialization/deserialization (fromJson, toJson)
│   ├── repositories/    # Concrete API call implementations
│   └── services/        # HTTP client, token storage (e.g. ApiService, AuthService)
├── domain/
│   ├── entities/        # Pure Dart business objects (no Flutter/JSON coupling)
│   └── repositories/    # Abstract repository interfaces
├── presentation/
│   ├── screens/         # One folder per role (admin/, processor/, logistics/, etc.)
│   ├── widgets/         # Reusable shared widgets
│   └── providers/       # State management (Provider / Riverpod / Bloc)
└── core/
    ├── constants/        # API base URL, role strings, color tokens
    ├── utils/            # Date formatters, validators
    └── router/           # Named route definitions and role-based routing
```

## Step-by-Step Workflow

### Step 1: Define the Entity
- Create a pure Dart class in `lib/domain/entities/`.
- No `fromJson` / `toJson` here — keep it free of external dependencies.

### Step 2: Define the Repository Interface
- Create an abstract class in `lib/domain/repositories/`.
- Methods mirror the API endpoints (e.g., `Future<List<Batch>> getBatches()`).

### Step 3: Implement the Data Model
- Create a model class in `lib/data/models/` that **extends or maps to** the entity.
- Implement `fromJson(Map<String, dynamic> json)` and `toJson()`.

### Step 4: Implement the Repository
- Create a concrete class in `lib/data/repositories/` that extends the interface.
- Inject `ApiService` to make HTTP calls.
- Handle `DioException` / `HttpException` and wrap in domain-level exceptions.

### Step 5: Build the Screen
- Screens live in `lib/presentation/screens/<role>/`.
- Screens **must not** call API services directly; only communicate through providers/state.
- Use `Consumer` / `ref.watch` (Riverpod) to read state.
- Show loading indicators (`CircularProgressIndicator`) and error states explicitly.

### Step 6: Routing & Role Guard
- All routes must be defined in `lib/core/router/`.
- On app launch, after login check, route to the role-specific home screen.
- Prevent navigation to other roles' screens by checking the stored user role.

## Security Checks
- [ ] Store auth token **only** in `flutter_secure_storage`, not `SharedPreferences`.
- [ ] Never hardcode `baseUrl` or secrets in source code; use environment configs.
- [ ] Clear secure storage on logout.
- [ ] Add `Authorization: Bearer <token>` header to all authenticated API calls via an HTTP interceptor, not per-request.
- [ ] Validate all user inputs with `Form` and `TextFormField` validators before submission.
