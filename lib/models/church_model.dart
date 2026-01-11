import 'dart:math' as math;

class Church {
  final String id;
  final String name;
  final String address;
  final double latitude;
  final double longitude;
  final String? phone;
  final String? email;
  final String? website;
  final String? denomination;
  final String? serviceTime;
  final double? rating;
  final int? reviewCount;
  final List<String>? openingHours;
  final bool? isOpen;
  final String? photoUrl;
  final double? distanceKm; // Distance from user location

  Church({
    required this.id,
    required this.name,
    required this.address,
    required this.latitude,
    required this.longitude,
    this.phone,
    this.email,
    this.website,
    this.denomination,
    this.serviceTime,
    this.rating,
    this.reviewCount,
    this.openingHours,
    this.isOpen,
    this.photoUrl,
    this.distanceKm,
  });

  factory Church.fromJson(Map<String, dynamic> json) {
    return Church(
      id: json['id'] as String,
      name: json['name'] as String,
      address: json['address'] as String,
      latitude: json['latitude'] as double,
      longitude: json['longitude'] as double,
      phone: json['phone'] as String?,
      email: json['email'] as String?,
      website: json['website'] as String?,
      denomination: json['denomination'] as String?,
      serviceTime: json['serviceTime'] as String?,
      rating: json['rating'] as double?,
      reviewCount: json['reviewCount'] as int?,
      openingHours: json['openingHours'] != null
          ? List<String>.from(json['openingHours'])
          : null,
      isOpen: json['isOpen'] as bool?,
      photoUrl: json['photoUrl'] as String?,
      distanceKm: json['distanceKm'] as double?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'address': address,
      'latitude': latitude,
      'longitude': longitude,
      'phone': phone,
      'email': email,
      'website': website,
      'denomination': denomination,
      'serviceTime': serviceTime,
      'rating': rating,
      'reviewCount': reviewCount,
      'openingHours': openingHours,
      'isOpen': isOpen,
      'photoUrl': photoUrl,
      'distanceKm': distanceKm,
    };
  }

  // Calculate distance from a given location using Haversine formula
  Church copyWithDistance(double fromLat, double fromLng) {
    const double earthRadius = 6371; // Earth's radius in kilometers

    final double dLat = _toRadians(latitude - fromLat);
    final double dLng = _toRadians(longitude - fromLng);

    final double a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(_toRadians(fromLat)) *
            math.cos(_toRadians(latitude)) *
            math.sin(dLng / 2) *
            math.sin(dLng / 2);

    final double c = 2 * math.asin(math.sqrt(a));
    final double distance = earthRadius * c;

    return Church(
      id: id,
      name: name,
      address: address,
      latitude: latitude,
      longitude: longitude,
      phone: phone,
      email: email,
      website: website,
      denomination: denomination,
      serviceTime: serviceTime,
      rating: rating,
      reviewCount: reviewCount,
      openingHours: openingHours,
      isOpen: isOpen,
      photoUrl: photoUrl,
      distanceKm: double.parse(distance.toStringAsFixed(2)),
    );
  }

  double _toRadians(double degree) {
    return degree * (3.141592653589793 / 180);
  }
}
