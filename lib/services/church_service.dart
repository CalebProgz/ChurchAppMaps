import 'package:http/http.dart' as http;
import 'dart:convert';
import '../models/church_model.dart';
import '../constants/app_constants.dart';

class ChurchService {
  /// Fetch churches near a specific location
  static Future<List<Church>> getChurchesNear(
    double latitude,
    double longitude, {
    double radiusKm = 10.0,
  }) async {
    try {
      final response = await http
          .get(
            Uri.parse(
              '${AppConstants.apiBaseUrl}/churches/near'
              '?lat=$latitude&lng=$longitude&radius=$radiusKm',
            ),
          )
          .timeout(AppConstants.apiTimeout);

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        return data.map((json) => Church.fromJson(json)).toList();
      } else {
        throw Exception('Failed to load churches');
      }
    } catch (e) {
      print('Error fetching churches: $e');
      return [];
    }
  }

  /// Search churches by name
  static Future<List<Church>> searchChurches(String query) async {
    try {
      final response = await http
          .get(
            Uri.parse('${AppConstants.apiBaseUrl}/churches/search?q=$query'),
          )
          .timeout(AppConstants.apiTimeout);

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        return data.map((json) => Church.fromJson(json)).toList();
      } else {
        throw Exception('Failed to search churches');
      }
    } catch (e) {
      print('Error searching churches: $e');
      return [];
    }
  }

  /// Get church details by ID
  static Future<Church?> getChurchDetails(String churchId) async {
    try {
      final response = await http
          .get(
            Uri.parse('${AppConstants.apiBaseUrl}/churches/$churchId'),
          )
          .timeout(AppConstants.apiTimeout);

      if (response.statusCode == 200) {
        return Church.fromJson(jsonDecode(response.body));
      } else {
        return null;
      }
    } catch (e) {
      print('Error fetching church details: $e');
      return null;
    }
  }
}
