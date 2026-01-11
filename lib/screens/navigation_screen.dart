import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'dart:async';
import 'dart:math' as math;
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/church_model.dart';
import '../services/location_service.dart';
import '../constants/app_constants.dart';

class NavigationScreen extends StatefulWidget {
  final Church destination;
  final Position currentPosition;

  const NavigationScreen({
    Key? key,
    required this.destination,
    required this.currentPosition,
  }) : super(key: key);

  @override
  State<NavigationScreen> createState() => _NavigationScreenState();
}

class _NavigationScreenState extends State<NavigationScreen> {
  GoogleMapController? _mapController;
  Position? _currentPosition;
  StreamSubscription<Position>? _positionStreamSubscription;
  final Set<Marker> _markers = {};
  final Set<Polyline> _polylines = {};

  double? _distanceRemaining;
  double? _estimatedTimeMinutes;
  bool _hasArrived = false;
  bool _isNavigationStarted = false;
  String _navigationStatus = 'Ready to navigate';

  @override
  void initState() {
    super.initState();
    _currentPosition = widget.currentPosition;
    _setupNavigation();
    _startLocationTracking();
  }

  void _setupNavigation() {
    _updateMarkers();
    _updatePolyline();
    _calculateNavigationInfo();
  }

  void _startLocationTracking() {
    const LocationSettings locationSettings = LocationSettings(
      accuracy: LocationAccuracy.bestForNavigation,
      distanceFilter: 5, // Update every 5 meters
    );

    _positionStreamSubscription = Geolocator.getPositionStream(
      locationSettings: locationSettings,
    ).listen((Position position) {
      setState(() {
        _currentPosition = position;
        _updateMarkers();
        _updatePolyline();
        _calculateNavigationInfo();
      });

      // Update camera to follow user
      _mapController?.animateCamera(
        CameraUpdate.newLatLng(
          LatLng(position.latitude, position.longitude),
        ),
      );

      // Cache the updated location
      LocationService.cacheLocation(position);
    });
  }

  void _updateMarkers() {
    _markers.clear();

    if (_currentPosition != null) {
      // Current position marker
      _markers.add(
        Marker(
          markerId: const MarkerId('current_position'),
          position: LatLng(
            _currentPosition!.latitude,
            _currentPosition!.longitude,
          ),
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue),
          infoWindow: const InfoWindow(
            title: 'Your Location',
          ),
        ),
      );
    }

    // Destination marker
    _markers.add(
      Marker(
        markerId: MarkerId('destination_${widget.destination.id}'),
        position: LatLng(
          widget.destination.latitude,
          widget.destination.longitude,
        ),
        icon: BitmapDescriptor.defaultMarkerWithHue(
          widget.destination.denomination?.toLowerCase().contains('catholic') ==
                  true
              ? BitmapDescriptor.hueRed
              : BitmapDescriptor.hueOrange,
        ),
        infoWindow: InfoWindow(
          title: widget.destination.name,
          snippet: widget.destination.denomination,
        ),
      ),
    );
  }

  void _updatePolyline() async {
    _polylines.clear();

    if (_currentPosition != null) {
      try {
        final route = await _getDirectionsRoute();
        if (route.isNotEmpty) {
          _polylines.add(
            Polyline(
              polylineId: const PolylineId('navigation_route'),
              points: route,
              color: Colors.blue,
              width: 5,
              patterns: [PatternItem.dash(20), PatternItem.gap(10)],
            ),
          );
        }
        setState(() {}); // Update UI with new polyline
      } catch (e) {
        // Fallback to straight line if directions fail
        _polylines.add(
          Polyline(
            polylineId: const PolylineId('navigation_route'),
            points: [
              LatLng(_currentPosition!.latitude, _currentPosition!.longitude),
              LatLng(widget.destination.latitude, widget.destination.longitude),
            ],
            color: Colors.blue,
            width: 5,
            patterns: [PatternItem.dash(20), PatternItem.gap(10)],
          ),
        );
        setState(() {}); // Update UI with fallback polyline
      }
    }
  }

  Future<List<LatLng>> _getDirectionsRoute() async {
    final origin =
        '${_currentPosition!.latitude},${_currentPosition!.longitude}';
    final destination =
        '${widget.destination.latitude},${widget.destination.longitude}';

    final url = Uri.parse(
        '${AppConstants.googleDirectionsApiUrl}/json?origin=$origin&destination=$destination&mode=walking&key=${AppConstants.googleMapsApiKey}');

    final response = await http.get(url).timeout(AppConstants.apiTimeout);

    if (response.statusCode == 200) {
      final data = json.decode(response.body);

      if (data['status'] == 'OK' && data['routes'].isNotEmpty) {
        final route = data['routes'][0];
        final polylinePoints = route['overview_polyline']['points'];

        return _decodePolyline(polylinePoints);
      }
    }

    throw Exception('Failed to get directions');
  }

  List<LatLng> _decodePolyline(String polyline) {
    List<LatLng> coordinates = [];
    int index = 0;
    int lat = 0;
    int lng = 0;

    while (index < polyline.length) {
      int shift = 0;
      int result = 0;

      while (true) {
        int b = polyline.codeUnitAt(index++) - 63;
        result |= (b & 0x1f) << shift;
        shift += 5;
        if (b < 0x20) break;
      }

      int deltaLat = ((result & 1) != 0 ? ~(result >> 1) : (result >> 1));
      lat += deltaLat;

      shift = 0;
      result = 0;

      while (true) {
        int b = polyline.codeUnitAt(index++) - 63;
        result |= (b & 0x1f) << shift;
        shift += 5;
        if (b < 0x20) break;
      }

      int deltaLng = ((result & 1) != 0 ? ~(result >> 1) : (result >> 1));
      lng += deltaLng;

      coordinates.add(LatLng(lat / 1e5, lng / 1e5));
    }

    return coordinates;
  }

  void _calculateNavigationInfo() {
    if (_currentPosition != null) {
      // Calculate distance using Haversine formula
      _distanceRemaining = _calculateDistance(
        _currentPosition!.latitude,
        _currentPosition!.longitude,
        widget.destination.latitude,
        widget.destination.longitude,
      );

      // Estimate time (assuming average walking speed of 5 km/h)
      _estimatedTimeMinutes = (_distanceRemaining! / 5) * 60;

      // Check if arrived (within 50 meters)
      if (_distanceRemaining! < 0.05) {
        _hasArrived = true;
        _navigationStatus = 'You have arrived!';
      } else if (_isNavigationStarted) {
        _navigationStatus = 'Navigating to destination';
      } else {
        _navigationStatus = 'Ready to navigate';
      }
    }
  }

  double _calculateDistance(
      double lat1, double lon1, double lat2, double lon2) {
    const double earthRadius = 6371; // Earth's radius in kilometers

    final double dLat = _toRadians(lat2 - lat1);
    final double dLon = _toRadians(lon2 - lon1);

    final double a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(_toRadians(lat1)) *
            math.cos(_toRadians(lat2)) *
            math.sin(dLon / 2) *
            math.sin(dLon / 2);

    final double c = 2 * math.asin(math.sqrt(a));
    return earthRadius * c;
  }

  double _toRadians(double degree) {
    return degree * (math.pi / 180);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Navigation'),
        elevation: 0,
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.my_location),
            onPressed: () {
              if (_currentPosition != null && _mapController != null) {
                _mapController!.animateCamera(
                  CameraUpdate.newCameraPosition(
                    CameraPosition(
                      target: LatLng(
                        _currentPosition!.latitude,
                        _currentPosition!.longitude,
                      ),
                      zoom: 17,
                    ),
                  ),
                );
              }
            },
          ),
        ],
      ),
      body: Stack(
        children: [
          // Map
          GoogleMap(
            onMapCreated: (GoogleMapController controller) {
              _mapController = controller;

              // Initially focus on current position
              if (_currentPosition != null) {
                controller.animateCamera(
                  CameraUpdate.newCameraPosition(
                    CameraPosition(
                      target: LatLng(
                        _currentPosition!.latitude,
                        _currentPosition!.longitude,
                      ),
                      zoom: 16,
                    ),
                  ),
                );
              }
            },
            initialCameraPosition: CameraPosition(
              target: LatLng(
                _currentPosition?.latitude ?? widget.destination.latitude,
                _currentPosition?.longitude ?? widget.destination.longitude,
              ),
              zoom: 15,
            ),
            markers: _markers,
            polylines: _polylines,
            myLocationEnabled: false, // We're handling this manually
            myLocationButtonEnabled: false,
            zoomControlsEnabled: false,
            mapToolbarEnabled: false,
            compassEnabled: true,
            trafficEnabled: false,
            buildingsEnabled: true,
            padding:
                const EdgeInsets.only(bottom: 200), // Space for navigation info
          ),

          // Navigation info panel
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Container(
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(20),
                  topRight: Radius.circular(20),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black26,
                    blurRadius: 10,
                    offset: Offset(0, -2),
                  ),
                ],
              ),
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Status indicator
                    Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.grey[300],
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Destination info
                    Row(
                      children: [
                        CircleAvatar(
                          backgroundColor: widget.destination.denomination
                                      ?.toLowerCase()
                                      .contains('catholic') ==
                                  true
                              ? Colors.red.shade100
                              : Colors.orange.shade100,
                          child: Icon(
                            Icons.church,
                            color: widget.destination.denomination
                                        ?.toLowerCase()
                                        .contains('catholic') ==
                                    true
                                ? Colors.red
                                : Colors.orange,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                widget.destination.name,
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              Text(
                                widget.destination.address,
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.grey[600],
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),

                    // Navigation stats
                    Row(
                      children: [
                        Expanded(
                          child: _buildStatCard(
                            'Distance',
                            _distanceRemaining != null
                                ? '${(_distanceRemaining! * 1000).round()} m'
                                : '--',
                            Icons.straighten,
                            Colors.blue,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildStatCard(
                            'ETA',
                            _estimatedTimeMinutes != null
                                ? '${_estimatedTimeMinutes!.round()} min'
                                : '--',
                            Icons.access_time,
                            Colors.green,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    
                    // Start Navigation Button (shown when not started)
                    if (!_isNavigationStarted && !_hasArrived) ...[
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: () {
                            setState(() {
                              _isNavigationStarted = true;
                              _navigationStatus = 'Navigating to destination';
                            });
                          },
                          icon: const Icon(Icons.navigation),
                          label: const Text('Start Navigation'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blue,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],

                    // Navigation status
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                        vertical: 12,
                        horizontal: 16,
                      ),
                      decoration: BoxDecoration(
                        color: _hasArrived
                            ? Colors.green.shade100
                            : _isNavigationStarted 
                              ? Colors.blue.shade100
                              : Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            _hasArrived 
                              ? Icons.check_circle 
                              : _isNavigationStarted 
                                ? Icons.navigation 
                                : Icons.location_on,
                            color: _hasArrived 
                              ? Colors.green 
                              : _isNavigationStarted 
                                ? Colors.blue
                                : Colors.grey,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            _navigationStatus,
                            style: TextStyle(
                              color: _hasArrived
                                  ? Colors.green.shade700
                                  : _isNavigationStarted 
                                    ? Colors.blue.shade700
                                    : Colors.grey.shade700,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Stop Navigation Button (only shown when navigation is started)
                    if (_isNavigationStarted && !_hasArrived) ...[
                      const SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          onPressed: () {
                            Navigator.of(context).pop();
                          },
                          icon: const Icon(Icons.stop),
                          label: const Text('Stop Navigation'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.red,
                            side: const BorderSide(color: Colors.red),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                        ),
                      ),
                    ],

                    if (_hasArrived) ...[
                      const SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: () {
                            Navigator.of(context).pop();
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                          child: const Text('Finish Navigation'),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(
      String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey[600],
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _positionStreamSubscription?.cancel();
    _mapController?.dispose();
    super.dispose();
  }
}
