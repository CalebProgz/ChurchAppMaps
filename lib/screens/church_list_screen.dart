import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/church_model.dart';
import '../services/location_service.dart';
import 'navigation_screen.dart';

class ChurchListScreen extends StatefulWidget {
  final List<Church> churches;
  final Function(Church) onChurchSelected;

  const ChurchListScreen({
    Key? key,
    required this.churches,
    required this.onChurchSelected,
  }) : super(key: key);

  @override
  State<ChurchListScreen> createState() => _ChurchListScreenState();
}

class _ChurchListScreenState extends State<ChurchListScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Churches (${widget.churches.length})'),
        elevation: 0,
        centerTitle: true,
      ),
      body: widget.churches.isEmpty
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.church,
                    size: 64,
                    color: Colors.grey,
                  ),
                  SizedBox(height: 16),
                  Text(
                    'No churches found nearby',
                    style: TextStyle(
                      fontSize: 18,
                      color: Colors.grey,
                    ),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'Try searching in a different area',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey,
                    ),
                  ),
                ],
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: widget.churches.length,
              itemBuilder: (context, index) {
                final church = widget.churches[index];
                return _buildChurchCard(church);
              },
            ),
    );
  }

  Widget _buildChurchCard(Church church) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Church name and denomination
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        church.name,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: church.denomination
                                      ?.toLowerCase()
                                      .contains('catholic') ==
                                  true
                              ? Colors.red.shade100
                              : Colors.orange.shade100,
                          borderRadius: BorderRadius.circular(8),
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
                    ],
                  ),
                ),
                CircleAvatar(
                  backgroundColor:
                      church.denomination?.toLowerCase().contains('catholic') ==
                              true
                          ? Colors.red.shade100
                          : Colors.orange.shade100,
                  child: Icon(
                    Icons.church,
                    color: church.denomination
                                ?.toLowerCase()
                                .contains('catholic') ==
                            true
                        ? Colors.red
                        : Colors.orange,
                    size: 24,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Address
            Row(
              children: [
                Icon(Icons.location_on, size: 16, color: Colors.grey[600]),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    church.address,
                    style: TextStyle(
                      color: Colors.grey[700],
                      fontSize: 14,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),

            // Distance and rating
            Row(
              children: [
                Icon(Icons.directions_walk, size: 16, color: Colors.grey[600]),
                const SizedBox(width: 4),
                Text(
                  '${church.distanceKm?.toStringAsFixed(1) ?? '?'} km away',
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                if (church.rating != null) ...[
                  const Spacer(),
                  Icon(Icons.star, size: 16, color: Colors.amber),
                  const SizedBox(width: 4),
                  Text(
                    church.rating!.toStringAsFixed(1),
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
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
            const SizedBox(height: 16),

            // Action buttons
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () async {
                      // Navigate to the church using in-app navigation
                      final currentPosition =
                          await LocationService.getCachedLocation();
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
                          const SnackBar(
                            content: Text('Unable to get current location'),
                          ),
                        );
                      }
                    },
                    icon: const Icon(Icons.navigation, size: 18),
                    label: const Text('Navigate'),
                    style: ElevatedButton.styleFrom(
                      foregroundColor: Colors.white,
                      backgroundColor: Theme.of(context).primaryColor,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () {
                      widget.onChurchSelected(church);
                      Navigator.of(context).pop();
                    },
                    icon: const Icon(Icons.map, size: 18),
                    label: const Text('View on Map'),
                  ),
                ),
              ],
            ),

            // Additional actions row
            if (church.phone != null || church.website != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Row(
                  children: [
                    if (church.phone != null)
                      Expanded(
                        child: TextButton.icon(
                          onPressed: () async {
                            final url = Uri.parse('tel:${church.phone}');
                            if (await canLaunchUrl(url)) {
                              await launchUrl(url);
                            }
                          },
                          icon: const Icon(Icons.phone, size: 16),
                          label: const Text('Call'),
                        ),
                      ),
                    if (church.website != null)
                      Expanded(
                        child: TextButton.icon(
                          onPressed: () async {
                            final url = Uri.parse(church.website!);
                            if (await canLaunchUrl(url)) {
                              await launchUrl(url);
                            }
                          },
                          icon: const Icon(Icons.language, size: 16),
                          label: const Text('Website'),
                        ),
                      ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}
