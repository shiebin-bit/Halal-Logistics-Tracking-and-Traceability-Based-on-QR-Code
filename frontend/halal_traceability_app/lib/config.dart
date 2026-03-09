// --- CENTRAL API CONFIGURATION ---
// Change this ONE place when switching between:
//   - Android Emulator: 'http://10.0.2.2:8000'
//   - Physical Device:  'http://YOUR_PC_IP:8000' (e.g., 'http://192.168.1.100:8000')
//   - iOS Simulator:    'http://localhost:8000'

/// Base API URL used by all authenticated and public requests.
const String baseUrl = 'http://10.0.2.2:8000/api';

/// Backward-compatible alias kept for screens using legacy naming.
const String apiBaseUrl = baseUrl;

/// Public storage URL used to resolve uploaded media (e.g. profile images).
const String storageUrl = 'http://10.0.2.2:8000/storage/';
