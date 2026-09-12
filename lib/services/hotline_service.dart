import '../api/dio_client.dart';

// A single emergency hotline
class Hotline {
  final int hotlineID;
  final String name;
  final String number;
  final String category;
  final String description;
  final String? imageUrl;

  Hotline({
    required this.hotlineID,
    required this.name,
    required this.number,
    required this.category,
    required this.description,
    this.imageUrl,
  });

  factory Hotline.fromJson(Map<String, dynamic> json) {
    return Hotline(
      hotlineID: json['hotlineID'] ?? 0,
      name: json['name'] ?? '',
      number: json['number'] ?? '',
      category: json['category'] ?? 'Other',
      description: json['description'] ?? '',
      imageUrl: json['imageUrl'],
    );
  }
}

class HotlineService {
  final _dio = DioClient.instance;

  // Fetch active hotlines (same endpoint the web admin manages)
  Future<List<Hotline>> getHotlines() async {
    final res = await _dio.get('/api/hotlines');
    return (res.data as List).map((j) => Hotline.fromJson(j)).toList();
  }
}
