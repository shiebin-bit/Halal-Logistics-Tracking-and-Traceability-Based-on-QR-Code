import 'package:geolocator/geolocator.dart';

/// Lightweight value object for GPS coordinates used across dashboards.
class AppLocation {
  const AppLocation({
    required this.latitude,
    required this.longitude,
  });

  final double latitude;
  final double longitude;

  String get displayLabel =>
      'Lat: ${latitude.toStringAsFixed(6)}, Long: ${longitude.toStringAsFixed(6)}';

  String get apiLocation =>
      '${latitude.toStringAsFixed(6)}, ${longitude.toStringAsFixed(6)}';
}

/// Typed exception so the UI can show location-specific guidance.
class AppLocationException implements Exception {
  const AppLocationException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// Centralized GPS helper for permission and position access.
class LocationService {
  LocationService._();

  static Future<AppLocation> getCurrentLocation() async {
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      throw const AppLocationException(
        'Location services are disabled. Please enable GPS and try again.',
      );
    }

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }

    if (permission == LocationPermission.denied) {
      throw const AppLocationException(
        'Location permission was denied. Please allow access to continue.',
      );
    }

    if (permission == LocationPermission.deniedForever) {
      throw const AppLocationException(
        'Location permission is permanently denied. Open app settings to allow GPS access.',
      );
    }

    final position = await Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        timeLimit: Duration(seconds: 15),
      ),
    );

    return AppLocation(
      latitude: position.latitude,
      longitude: position.longitude,
    );
  }
}
