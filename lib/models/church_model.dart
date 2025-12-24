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
    };
  }
}
