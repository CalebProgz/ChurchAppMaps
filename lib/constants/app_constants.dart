class AppConstants {
  // API Configuration
  static const String apiBaseUrl = 'https://api.example.com';
  static const String googleMapsApiKey = 'AIzaSyCaxdsihSb9imS2V4DNtqXCYij0hI9PRIE';
  
  // App Configuration
  static const String appName = 'Church Finder';
  static const String appVersion = '1.0.0';
  
  // Default Location (Falls back to this if user denies location)
  static const double defaultLat = 37.7749;
  static const double defaultLng = -122.4194;
  
  // Map Configuration
  static const double mapDefaultZoom = 15.0;
  static const double mapSearchRadiusKm = 10.0;
  
  // Timeouts
  static const Duration apiTimeout = Duration(seconds: 30);
  static const Duration locationTimeout = Duration(seconds: 10);
}
