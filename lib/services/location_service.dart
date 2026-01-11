import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';

class LocationService {
  // Cached location to avoid repeated GPS requests
  static Position? _cachedLocation;
  static DateTime? _lastLocationUpdate;
  static const Duration _cacheValidDuration = Duration(minutes: 5);

  /// Request location permission from the user
  static Future<bool> requestLocationPermission() async {
    final permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      return await Geolocator.requestPermission() ==
          LocationPermission.whileInUse;
    }
    return permission == LocationPermission.whileInUse ||
        permission == LocationPermission.always;
  }

  /// Get current user location with caching
  static Future<Position?> getCurrentLocation(
      {bool forceRefresh = false}) async {
    try {
      // Check if we have a valid cached location
      if (!forceRefresh &&
          _cachedLocation != null &&
          _lastLocationUpdate != null) {
        final timeSinceLastUpdate =
            DateTime.now().difference(_lastLocationUpdate!);
        if (timeSinceLastUpdate < _cacheValidDuration) {
          return _cachedLocation;
        }
      }

      final hasPermission = await requestLocationPermission();
      if (!hasPermission) {
        return _cachedLocation; // Return cached if available
      }

      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      // Cache the new location
      _cachedLocation = position;
      _lastLocationUpdate = DateTime.now();

      return position;
    } catch (e) {
      print('Error getting location: $e');
      return _cachedLocation; // Return cached if available
    }
  }

  /// Get cached location if available
  static Position? getCachedLocation() {
    return _cachedLocation;
  }

  /// Manually cache a location (useful for real-time updates)
  static void cacheLocation(Position position) {
    _cachedLocation = position;
    _lastLocationUpdate = DateTime.now();
  }

  /// Clear cached location
  static void clearCache() {
    _cachedLocation = null;
    _lastLocationUpdate = null;
  }

  /// Check if cached location is still valid
  static bool isCacheValid() {
    if (_cachedLocation == null || _lastLocationUpdate == null) {
      return false;
    }
    final timeSinceLastUpdate = DateTime.now().difference(_lastLocationUpdate!);
    return timeSinceLastUpdate < _cacheValidDuration;
  }

  /// Get place name from coordinates
  static Future<String?> getPlaceName(double lat, double lng) async {
    try {
      final placemarks = await placemarkFromCoordinates(lat, lng);
      if (placemarks.isNotEmpty) {
        final place = placemarks.first;
        return '${place.street}, ${place.locality}, ${place.administrativeArea}';
      }
      return null;
    } catch (e) {
      print('Error getting place name: $e');
      return null;
    }
  }

  /// Calculate distance between two coordinates in kilometers
  static double calculateDistance(
      double lat1, double lng1, double lat2, double lng2) {
    return Geolocator.distanceBetween(lat1, lng1, lat2, lng2) / 1000;
  }

  /// Check if location services are enabled
  static Future<bool> isLocationServiceEnabled() async {
    return await Geolocator.isLocationServiceEnabled();
  }
}
