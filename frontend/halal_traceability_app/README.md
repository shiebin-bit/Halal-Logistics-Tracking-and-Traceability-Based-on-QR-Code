# HalalTrack Frontend

Flutter mobile client for the HalalTrack platform.

This app is used by `admin`, `processor`, `logistics`, `retailer`, and public `consumer` flows. It connects to the Laravel backend, supports QR-based traceability, and provides role-specific dashboards for supply chain operations.

## Main Capabilities

- login and session handling
- role-based dashboard routing
- processor batch creation flow
- logistics QR scan and checkpoint submission
- retailer shipment acceptance workflow
- public consumer traceability lookup
- profile image and document-related UI flows

## Stack

- Flutter
- Dart
- `http`
- `mobile_scanner`
- `geolocator`
- `flutter_secure_storage`

## Run Locally

From this directory:

```powershell
flutter pub get
flutter run
```

## API Configuration

The app reads its API origin from `lib/config.dart`.

Default behavior:

- Android emulator uses `http://10.0.2.2:8000`
- web and non-Android targets use `http://127.0.0.1:8000`

Override it when needed:

```powershell
flutter run --dart-define=API_ORIGIN=https://api.example.com
```

## Quality Checks

Analyze:

```powershell
flutter analyze
```

Run tests:

```powershell
flutter test
```

## Project Structure

```text
lib/
├── config.dart
├── main.dart
├── screens/
│   ├── dashboards/
│   └── ...
└── services/
    ├── auth_session_service.dart
    ├── location_service.dart
    ├── profile_image_service.dart
    └── qr_payload_service.dart
```

## Notes

- This app expects the backend API to be reachable and seeded for local demo flows.
- Public consumer traceability does not require login.
- Production builds should point to the real backend origin with `--dart-define=API_ORIGIN=...`.

For broader project context, see the root [README](../../README.md).
