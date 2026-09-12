import '../api/dio_client.dart';

// A single establishment (school, health facility, church, hall, etc.)
class Establishment {
  final int establishmentID;
  final String name;
  final String type;
  final String category;
  final double latitude;
  final double longitude;

  Establishment({
    required this.establishmentID,
    required this.name,
    required this.type,
    required this.category,
    required this.latitude,
    required this.longitude,
  });

  factory Establishment.fromJson(Map<String, dynamic> json) {
    return Establishment(
      establishmentID: json['establishmentID'] ?? 0,
      name: json['name'] ?? '',
      type: json['type'] ?? 'Other',
      category: json['category'] ?? 'Other',
      latitude: (json['latitude'] as num?)?.toDouble() ?? 0.0,
      longitude: (json['longitude'] as num?)?.toDouble() ?? 0.0,
    );
  }
}

class EstablishmentService {
  final _dio = DioClient.instance;

  // Fetch active establishments (same endpoint the admin manages)
  Future<List<Establishment>> getEstablishments() async {
    final res = await _dio.get('/api/establishments');
    return (res.data as List).map((j) => Establishment.fromJson(j)).toList();
  }
}
