// --- CENTRAL API CONFIGURATION ---
// Override with:
// flutter run --dart-define=API_ORIGIN=https://api.example.com

/// Base API URL used by all authenticated and public requests.
const String _apiOrigin = String.fromEnvironment(
  'API_ORIGIN',
  defaultValue: 'http://10.0.2.2:8000',
);

const String baseUrl = '$_apiOrigin/api';

/// Backward-compatible alias kept for screens using legacy naming.
const String apiBaseUrl = baseUrl;

/// Public storage URL used to resolve uploaded media (e.g. profile images).
const String storageUrl = '$_apiOrigin/storage/';
