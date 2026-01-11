import 'package:http/http.dart' as http;
import 'dart:convert';
import '../models/church_model.dart';
import '../constants/app_constants.dart';

class ChurchService {
  /// Fetch churches near a specific location using Google Places API
  static Future<List<Church>> getChurchesNear(
    double latitude,
    double longitude, {
    double radiusKm = 5.0,
  }) async {
    try {
      // Convert km to meters for Google Places API
      final radiusMeters = (radiusKm * 1000).round();

      final url = Uri.parse(
        '${AppConstants.googlePlacesApiUrl}/nearbysearch/json'
        '?location=$latitude,$longitude'
        '&radius=$radiusMeters'
        '&type=place_of_worship'
        '&keyword=church%20OR%20cathedral%20OR%20chapel%20OR%20parish%20OR%20basilica%20OR%20presbyterian%20OR%20methodist%20OR%20baptist%20OR%20anglican%20OR%20pentecostal%20OR%20pcea'
        '&key=${AppConstants.googleMapsApiKey}',
      );

      final response = await http.get(url).timeout(AppConstants.apiTimeout);

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = jsonDecode(response.body);

        if (data['status'] == 'OK') {
          final List<dynamic> results = data['results'];

          // Convert Google Places results to Church objects
          return results.map((place) {
            final location = place['geometry']['location'];
            return Church(
              id: place['place_id'],
              name: place['name'],
              address: place['vicinity'] ??
                  place['formatted_address'] ??
                  'Address not available',
              latitude: location['lat'].toDouble(),
              longitude: location['lng'].toDouble(),
              rating: place['rating']?.toDouble(),
              reviewCount: place['user_ratings_total']?.toInt(),
              denomination: _extractDenomination(place['name'], place['types']),
              isOpen: _getOpenStatus(place['opening_hours']),
            );
          }).toList();
        } else {
          throw Exception('Google Places API error: ${data['status']}');
        }
      } else {
        throw Exception('Failed to load churches: ${response.statusCode}');
      }
    } catch (e) {
      print('Error fetching churches: $e');
      return [];
    }
  }

  /// Search churches by text query (for denominational names like PCEA, Presbyterian, etc.)
  static Future<List<Church>> searchChurchesByText(
    double latitude,
    double longitude,
    String query, {
    double radiusKm = 5.0,
  }) async {
    try {
      // Convert km to meters for Google Places API
      final radiusMeters = (radiusKm * 1000).round();

      final url = Uri.parse(
        '${AppConstants.googlePlacesApiUrl}/textsearch/json'
        '?query=$query church'
        '&location=$latitude,$longitude'
        '&radius=$radiusMeters'
        '&key=${AppConstants.googleMapsApiKey}',
      );

      final response = await http.get(url).timeout(AppConstants.apiTimeout);

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = jsonDecode(response.body);

        if (data['status'] == 'OK') {
          final List<dynamic> results = data['results'];

          // Convert Google Places results to Church objects
          return results.map((place) {
            final location = place['geometry']['location'];
            return Church(
              id: place['place_id'],
              name: place['name'],
              address: place['vicinity'] ??
                  place['formatted_address'] ??
                  'Address not available',
              latitude: location['lat'].toDouble(),
              longitude: location['lng'].toDouble(),
              rating: place['rating']?.toDouble(),
              reviewCount: place['user_ratings_total']?.toInt(),
              denomination: _extractDenomination(place['name'], place['types']),
              isOpen: _getOpenStatus(place['opening_hours']),
            );
          }).where((church) {
            // Filter to only include results that are actually churches
            final name = church.name.toLowerCase();
            return name.contains('church') ||
                name.contains('cathedral') ||
                name.contains('chapel') ||
                name.contains('parish') ||
                name.contains('basilica') ||
                name.contains('presbyterian') ||
                name.contains('pcea') ||
                name.contains('methodist') ||
                name.contains('baptist') ||
                name.contains('anglican') ||
                name.contains('pentecostal');
          }).toList();
        }
      }

      return [];
    } catch (e) {
      print('Error searching churches by text: $e');
      return [];
    }
  }

  /// Search churches by name and location
  static Future<List<Church>> searchChurches(
    String query,
    double latitude,
    double longitude,
  ) async {
    try {
      final url = Uri.parse(
        '${AppConstants.googlePlacesApiUrl}/textsearch/json'
        '?query=$query church'
        '&location=$latitude,$longitude'
        '&radius=10000' // 10km radius
        '&key=${AppConstants.googleMapsApiKey}',
      );

      final response = await http.get(url).timeout(AppConstants.apiTimeout);

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = jsonDecode(response.body);

        if (data['status'] == 'OK') {
          final List<dynamic> results = data['results'];

          return results.map((place) {
            final location = place['geometry']['location'];
            return Church(
              id: place['place_id'],
              name: place['name'],
              address: place['formatted_address'] ?? 'Address not available',
              latitude: location['lat'].toDouble(),
              longitude: location['lng'].toDouble(),
              rating: place['rating']?.toDouble(),
              reviewCount: place['user_ratings_total']?.toInt(),
              denomination: _extractDenomination(place['name'], place['types']),
              isOpen: _getOpenStatus(place['opening_hours']),
            );
          }).toList();
        }
      }
      return [];
    } catch (e) {
      print('Error searching churches: $e');
      return [];
    }
  }

  // Helper method to extract denomination from church name
  static String? _extractDenomination(String name, List<dynamic> types) {
    final lowerName = name.toLowerCase();

    // Common Catholic identifiers
    if (lowerName.contains('catholic') ||
        lowerName.contains('st.') ||
        lowerName.contains('saint') ||
        lowerName.contains('our lady')) {
      return 'Catholic';
    }

    // Protestant denominations
    if (lowerName.contains('baptist')) return 'Baptist';
    if (lowerName.contains('methodist')) return 'Methodist';
    if (lowerName.contains('presbyterian')) return 'Presbyterian';
    if (lowerName.contains('pentecostal')) return 'Pentecostal';
    if (lowerName.contains('assembly of god')) return 'Assembly of God';
    if (lowerName.contains('episcopal')) return 'Episcopal';
    if (lowerName.contains('lutheran')) return 'Lutheran';
    if (lowerName.contains('anglican')) return 'Anglican';

    return 'Christian'; // Generic fallback
  }

  // Helper method to parse opening hours
  static List<String>? _parseOpeningHours(Map<String, dynamic>? openingHours) {
    if (openingHours == null) return null;

    final weekdayText = openingHours['weekday_text'] as List<dynamic>?;
    return weekdayText?.cast<String>();
  }

  // Helper method to get current open status
  static bool? _getOpenStatus(Map<String, dynamic>? openingHours) {
    if (openingHours == null) return null;
    return openingHours['open_now'] as bool?;
  }
}
