import '../api/dio_client.dart';

class HazardType {
  final int hazardID;
  final String hazardName;

  HazardType({required this.hazardID, required this.hazardName});

  factory HazardType.fromJson(Map<String, dynamic> json) {
    return HazardType(
      hazardID: json['hazardID'],
      hazardName: json['hazardName'],
    );
  }
}

class HazardService {
  final _dio = DioClient.instance;

  Future<List<HazardType>> getHazardTypes() async {
    final res = await _dio.get('/api/hazard-types');
    return (res.data as List).map((j) => HazardType.fromJson(j)).toList();
  }
}
