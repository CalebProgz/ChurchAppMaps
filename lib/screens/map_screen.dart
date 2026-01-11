import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:url_launcher/url_launcher.dart';
import '../constants/app_constants.dart';
import '../services/location_service.dart';
import '../services/church_service.dart';
import '../models/church_model.dart';
import 'church_list_screen.dart';
import 'navigation_screen.dart';

class MapScreen extends StatefulWidget {
  const MapScreen({Key? key}) : super(key: key);

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  GoogleMapController? _mapController;
  Position? _currentPosition;
  bool _isLoading = true;
  bool _isLoadingChurches = false;
  String? _errorMessage;
  final Set<Marker> _markers = {};
  List<Church> _nearbyChurches = [];
  Church? _selectedChurch;
  final TextEditingController _searchController = TextEditingController();

  // Default camera position
  static const CameraPosition _defaultPosition = CameraPosition(
    target: LatLng(AppConstants.defaultLat, AppConstants.defaultLng),
    zoom: AppConstants.mapDefaultZoom,
  );

  @override
  void initState() {
    super.initState();
    _initializeLocation();
  }

  Future<void> _initializeLocation() async {
    try {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });

      // Try to get cached location first
      Position? position = LocationService.getCachedLocation();

      if (position == null || !LocationService.isCacheValid()) {
        // Get fresh location if no cache or cache is stale
        position = await LocationService.getCurrentLocation();
      }

      setState(() {
        _currentPosition = position;
        _isLoading = false;
      });

      // Add marker for current location
      _addCurrentLocationMarker();

      // Search for nearby churches
      await _searchNearbyChurches();

      // Move camera to current location
      if (_mapController != null && position != null) {
        _mapController!.animateCamera(
          CameraUpdate.newLatLng(
            LatLng(position.latitude, position.longitude),
          ),
        );
      }
    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
        _isLoading = false;
      });
    }
  }

  void _addCurrentLocationMarker() {
    if (_currentPosition != null) {
      _markers.add(
        Marker(
          markerId: const MarkerId('current_location'),
          position: LatLng(
            _currentPosition!.latitude,
            _currentPosition!.longitude,
          ),
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue),
          infoWindow: const InfoWindow(
            title: 'Your Location',
            snippet: 'You are here',
          ),
        ),
      );
    }
  }

  // Search for nearby churches
  Future<void> _searchNearbyChurches() async {
    if (_currentPosition == null) return;

    setState(() {
      _isLoadingChurches = true;
    });

    try {
      // First search - standard church search
      final churches1 = await ChurchService.getChurchesNear(
        _currentPosition!.latitude,
        _currentPosition!.longitude,
        radiusKm: AppConstants.mapSearchRadiusKm,
      );

      // Second search - specific denominational search
      final churches2 = await ChurchService.searchChurchesByText(
        _currentPosition!.latitude,
        _currentPosition!.longitude,
        'PCEA Presbyterian Methodist Baptist Anglican Pentecostal Catholic',
        radiusKm: AppConstants.mapSearchRadiusKm,
      );

      // Combine and deduplicate churches
      final allChurches = <String, Church>{};
      for (final church in [...churches1, ...churches2]) {
        allChurches[church.id] = church;
      }

      // Calculate distances and sort by proximity
      final churchesWithDistance = allChurches.values
          .map((church) => church.copyWithDistance(
                _currentPosition!.latitude,
                _currentPosition!.longitude,
              ))
          .toList();

      churchesWithDistance.sort((a, b) => (a.distanceKm ?? double.infinity)
          .compareTo(b.distanceKm ?? double.infinity));

      setState(() {
        _nearbyChurches = churchesWithDistance;
        _isLoadingChurches = false;
      });

      _addChurchMarkers();
    } catch (e) {
      setState(() {
        _isLoadingChurches = false;
        _errorMessage = 'Failed to find nearby churches: $e';
      });
    }
  }

  // Add church markers to the map
  void _addChurchMarkers() {
    // Clear existing church markers (keep current location)
    _markers
        .removeWhere((marker) => marker.markerId.value != 'current_location');

    for (final church in _nearbyChurches) {
      _markers.add(
        Marker(
          markerId: MarkerId(church.id),
          position: LatLng(church.latitude, church.longitude),
          icon: BitmapDescriptor.defaultMarkerWithHue(
            church.denomination?.toLowerCase().contains('catholic') == true
                ? BitmapDescriptor.hueRed
                : BitmapDescriptor.hueOrange,
          ),
          onTap: () => _selectChurch(church),
        ),
      );
    }
  }

  // Select a church and show details
  void _selectChurch(Church church) {
    setState(() {
      _selectedChurch = church;
    });

    // Move camera to fit both marker and popup
    if (_mapController != null) {
      // Calculate bounds to include marker and space for popup
      final markerPosition = LatLng(church.latitude, church.longitude);

      // Adjust camera to show marker with space for popup
      _mapController!.animateCamera(
        CameraUpdate.newCameraPosition(
          CameraPosition(
            target: LatLng(
              church.latitude + 0.002, // Offset UP to account for popup below
              church.longitude,
            ),
            zoom: 16.0,
          ),
        ),
      );
    }
  }

// Navigate to selected church using in-app navigation
  Future<void> _navigateToChurch(Church church) async {
    final currentPosition = LocationService.getCachedLocation();
    if (currentPosition != null) {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (context) => NavigationScreen(
            destination: church,
            currentPosition: currentPosition,
          ),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Unable to get current location')),
      );
    }
  }

  // Search churches by name
  Future<void> _searchChurchesByName(String query) async {
    if (_currentPosition == null || query.trim().isEmpty) return;

    setState(() {
      _isLoadingChurches = true;
    });

    try {
      final churches = await ChurchService.searchChurches(
        query,
        _currentPosition!.latitude,
        _currentPosition!.longitude,
      );

      final churchesWithDistance = churches
          .map((church) => church.copyWithDistance(
                _currentPosition!.latitude,
                _currentPosition!.longitude,
              ))
          .toList();

      setState(() {
        _nearbyChurches = churchesWithDistance;
        _isLoadingChurches = false;
      });

      _addChurchMarkers();
    } catch (e) {
      setState(() {
        _isLoadingChurches = false;
        _errorMessage = 'Search failed: $e';
      });
    }
  }

  void _onMapCreated(GoogleMapController controller) {
    _mapController = controller;

    // If we already have position, move camera to it
    if (_currentPosition != null) {
      controller.animateCamera(
        CameraUpdate.newLatLng(
          LatLng(_currentPosition!.latitude, _currentPosition!.longitude),
        ),
      );
    }
  }

  void _onCameraMove(CameraPosition position) {
    // Auto-dismiss popup when user scrolls away from selected church
    if (_selectedChurch != null) {
      final churchLatLng =
          LatLng(_selectedChurch!.latitude, _selectedChurch!.longitude);
      final cameraLatLng = position.target;

      // Calculate distance between camera center and selected church
      const double threshold = 0.01; // Roughly 1km threshold
      final distance = (churchLatLng.latitude - cameraLatLng.latitude).abs() +
          (churchLatLng.longitude - cameraLatLng.longitude).abs();

      if (distance > threshold) {
        setState(() {
          _selectedChurch = null;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Get screen dimensions for responsive design
    final size = MediaQuery.of(context).size;
    final padding = MediaQuery.of(context).padding;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Church Finder'),
        elevation: 0,
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.my_location),
            onPressed: _initializeLocation,
            tooltip: 'Get current location',
          ),
        ],
      ),
      body: SafeArea(
        child: Stack(
          children: [
            // Map takes full screen
            GoogleMap(
              onMapCreated: _onMapCreated,
              onCameraMove: _onCameraMove,
              initialCameraPosition: _defaultPosition,
              myLocationEnabled: true,
              myLocationButtonEnabled: false, // We'll use custom button
              markers: _markers,
              zoomControlsEnabled:
                  false, // Hide default zoom controls for cleaner UI
              mapToolbarEnabled: false, // Hide default toolbar on Android
              compassEnabled: true,
              rotateGesturesEnabled: true,
              scrollGesturesEnabled: true,
              tiltGesturesEnabled: true,
              zoomGesturesEnabled: true,
              padding: EdgeInsets.only(
                bottom: 16, // Reduced padding since no bottom bar
                right: 16,
                left: 16,
              ),
            ),

            // Loading overlay
            if (_isLoading)
              Container(
                color: Colors.black54,
                child: Center(
                  child: Card(
                    margin: const EdgeInsets.all(24),
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const CircularProgressIndicator(),
                          const SizedBox(height: 16),
                          Text(
                            'Getting your location...',
                            style: Theme.of(context).textTheme.titleMedium,
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),

            // Search bar at the top
            Positioned(
              top: 16,
              left: 16,
              right: 16,
              child: SafeArea(
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      hintText: 'Search for churches...',
                      prefixIcon: const Icon(Icons.search),
                      suffixIcon: _searchController.text.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear),
                              onPressed: () {
                                _searchController.clear();
                                setState(() {});
                              },
                            )
                          : null,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                      filled: true,
                      fillColor: Colors.white,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                    ),
                    onChanged: (value) => setState(() {}),
                    onSubmitted: _searchChurchesByName,
                  ),
                ),
              ),
            ),

            // Selected church details panel
            if (_selectedChurch != null)
              Positioned(
                left: 16,
                right: 16,
                bottom: 180, // Position to allow upward pointer to reach marker
                child: SafeArea(
                  child: Stack(
                    children: [
                      // Popup with pointer
                      Container(
                        margin: const EdgeInsets.only(
                            top: 15), // More space for visible pointer
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.15),
                              blurRadius: 12,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: _buildChurchDetailsCard(_selectedChurch!),
                      ),
                      // Pointer triangle pointing UP to marker - more visible
                      Positioned(
                        top:
                            -5, // Slightly outside the container for better visibility
                        left: 0,
                        right: 0,
                        child: Center(
                          child: Container(
                            decoration: BoxDecoration(
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.2),
                                  blurRadius: 4,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: CustomPaint(
                              painter: TrianglePainter(pointingUp: true),
                              size: const Size(
                                  24, 12), // Larger for better visibility
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

            // Error message at top with SafeArea
            if (_errorMessage != null && !_isLoading)
              Positioned(
                top: 8,
                left: 8,
                right: 8,
                child: SafeArea(
                  child: Material(
                    elevation: 4,
                    borderRadius: BorderRadius.circular(8),
                    color: Colors.red[50],
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.error_outline,
                              color: Colors.red, size: 20),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              _errorMessage!,
                              style: const TextStyle(
                                color: Colors.red,
                                fontSize: 13,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.close,
                                color: Colors.red, size: 20),
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                            onPressed: () {
                              setState(() {
                                _errorMessage = null;
                              });
                            },
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),

            // Circular Floating Action Buttons
            Positioned(
              left: 16,
              bottom: 100,
              child: Column(
                children: [
                  // Location Button
                  FloatingActionButton(
                    onPressed: _initializeLocation,
                    backgroundColor: Colors.white,
                    foregroundColor: Theme.of(context).primaryColor,
                    elevation: 4,
                    child: _isLoading
                        ? SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                Theme.of(context).primaryColor,
                              ),
                            ),
                          )
                        : const Icon(Icons.my_location),
                  ),
                  const SizedBox(height: 16),
                  // Church Button
                  FloatingActionButton(
                    onPressed: () async {
                      if (_currentPosition != null) {
                        if (_nearbyChurches.isEmpty) {
                          await _searchNearbyChurches();
                        }
                        if (_nearbyChurches.isNotEmpty) {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (context) => ChurchListScreen(
                                churches: _nearbyChurches,
                                onChurchSelected: _selectChurch,
                              ),
                            ),
                          );
                        } else {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('No churches found in your area'),
                              duration: Duration(seconds: 2),
                            ),
                          );
                        }
                      } else {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Please enable location first'),
                            duration: Duration(seconds: 2),
                          ),
                        );
                      }
                    },
                    backgroundColor: Colors.white,
                    foregroundColor: Theme.of(context).primaryColor,
                    elevation: 4,
                    child: Stack(
                      children: [
                        const Icon(Icons.church),
                        if (_nearbyChurches.isNotEmpty)
                          Positioned(
                            right: 0,
                            top: 0,
                            child: Container(
                              padding: const EdgeInsets.all(2),
                              decoration: BoxDecoration(
                                color: Colors.red,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              constraints: const BoxConstraints(
                                minWidth: 16,
                                minHeight: 16,
                              ),
                              child: Text(
                                '${_nearbyChurches.length}',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ),
                          ),
                        if (_isLoadingChurches)
                          Positioned(
                            right: -2,
                            top: -2,
                            child: SizedBox(
                              width: 12,
                              height: 12,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  Theme.of(context).primaryColor,
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // Zoom controls - Right side
            Positioned(
              right: 16,
              bottom: 100,
              child: SafeArea(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Material(
                      elevation: 4,
                      shape: const CircleBorder(),
                      color: Colors.white,
                      child: InkWell(
                        onTap: () {
                          _mapController?.animateCamera(
                            CameraUpdate.zoomIn(),
                          );
                        },
                        customBorder: const CircleBorder(),
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          child: const Icon(Icons.add, size: 24),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Material(
                      elevation: 4,
                      shape: const CircleBorder(),
                      color: Colors.white,
                      child: InkWell(
                        onTap: () {
                          _mapController?.animateCamera(
                            CameraUpdate.zoomOut(),
                          );
                        },
                        customBorder: const CircleBorder(),
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          child: const Icon(Icons.remove, size: 24),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _mapController?.dispose();
    _searchController.dispose();
    super.dispose();
  }

  // Build church details card
  Widget _buildChurchDetailsCard(Church church) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header with close button
          Row(
            children: [
              Expanded(
                child: Text(
                  church.name,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close),
                onPressed: () {
                  setState(() {
                    _selectedChurch = null;
                  });
                },
                constraints: const BoxConstraints(),
                padding: EdgeInsets.zero,
              ),
            ],
          ),
          const SizedBox(height: 8),

          // Denomination and distance
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color:
                      church.denomination?.toLowerCase().contains('catholic') ==
                              true
                          ? Colors.red.shade100
                          : Colors.orange.shade100,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  church.denomination ?? 'Church',
                  style: TextStyle(
                    color: church.denomination
                                ?.toLowerCase()
                                .contains('catholic') ==
                            true
                        ? Colors.red.shade700
                        : Colors.orange.shade700,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '${church.distanceKm?.toStringAsFixed(1) ?? '?'} km away',
                style: TextStyle(
                  color: Colors.grey[600],
                  fontSize: 14,
                ),
              ),
              if (church.rating != null) ...[
                const Spacer(),
                Icon(Icons.star, size: 16, color: Colors.amber),
                const SizedBox(width: 4),
                Text(
                  church.rating!.toStringAsFixed(1),
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                if (church.reviewCount != null)
                  Text(
                    ' (${church.reviewCount})',
                    style: TextStyle(
                      color: Colors.grey[600],
                      fontSize: 12,
                    ),
                  ),
              ],
            ],
          ),
          const SizedBox(height: 8),

          // Address
          Text(
            church.address,
            style: TextStyle(
              color: Colors.grey[700],
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 12),

          // Action buttons
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () => _navigateToChurch(church),
                  icon: const Icon(Icons.directions, size: 18),
                  label: const Text('Directions'),
                  style: ElevatedButton.styleFrom(
                    foregroundColor: Colors.white,
                    backgroundColor: Theme.of(context).primaryColor,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              if (church.phone != null)
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () async {
                      final url = Uri.parse('tel:${church.phone}');
                      if (await canLaunchUrl(url)) {
                        await launchUrl(url);
                      }
                    },
                    icon: const Icon(Icons.phone, size: 18),
                    label: const Text('Call'),
                  ),
                ),
              if (church.website != null) ...[
                const SizedBox(width: 8),
                IconButton(
                  onPressed: () async {
                    final url = Uri.parse(church.website!);
                    if (await canLaunchUrl(url)) {
                      await launchUrl(url);
                    }
                  },
                  icon: const Icon(Icons.language),
                  tooltip: 'Visit website',
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

// Custom painter for triangle pointer
class TrianglePainter extends CustomPainter {
  final bool pointingUp;

  const TrianglePainter({this.pointingUp = false});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;

    final path = Path();

    if (pointingUp) {
      // Triangle pointing up
      path.moveTo(size.width / 2, 0); // Top point
      path.lineTo(0, size.height); // Bottom left
      path.lineTo(size.width, size.height); // Bottom right
    } else {
      // Triangle pointing down (original)
      path.moveTo(size.width / 2, size.height); // Bottom point
      path.lineTo(0, 0); // Top left
      path.lineTo(size.width, 0); // Top right
    }
    path.close();

    // Add shadow
    canvas.drawShadow(path, Colors.black.withOpacity(0.15), 4, true);
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) => false;
}
