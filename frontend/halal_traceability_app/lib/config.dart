import 'package:flutter/foundation.dart';

// --- CENTRAL API CONFIGURATION ---
// Override with:
// flutter run --dart-define=API_ORIGIN=https://api.example.com

const String _apiOriginOverride = String.fromEnvironment(
  'API_ORIGIN',
  defaultValue: '',
);

/// Base API origin used by all authenticated and public requests.
final String apiOrigin =
    _apiOriginOverride.isNotEmpty ? _apiOriginOverride : _defaultApiOrigin();

final String baseUrl = '$apiOrigin/api';

/// Backward-compatible alias kept for screens using legacy naming.
final String apiBaseUrl = baseUrl;

/// Public storage URL used to resolve uploaded media (e.g. profile images).
final String storageUrl = '$apiOrigin/storage/';

String _defaultApiOrigin() {
  if (kIsWeb) {
    return 'http://127.0.0.1:8000';
  }

  switch (defaultTargetPlatform) {
    case TargetPlatform.android:
      // Android emulators cannot reach the host machine via 127.0.0.1.
      return 'http://10.0.2.2:8000';
    default:
      return 'http://127.0.0.1:8000';
  }
}
