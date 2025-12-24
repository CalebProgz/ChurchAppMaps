import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';

class LocationService {
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

  /// Get current user location
  static Future<Position?> getCurrentLocation() async {
    try {
      final hasPermission = await requestLocationPermission();
      if (!hasPermission) {
        return null;
      }
      return await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
    } catch (e) {
      print('Error getting location: $e');
      return null;
    }
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
  static double calculateDistance(double lat1, double lng1, double lat2, double lng2) {
    return Geolocator.distanceBetween(lat1, lng1, lat2, lng2) / 1000;
  }

  /// Check if location services are enabled
  static Future<bool> isLocationServiceEnabled() async {
    return await Geolocator.isLocationServiceEnabled();
  }
}
