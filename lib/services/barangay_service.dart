import '../api/dio_client.dart';

// A barangay (for the registration dropdown)
class Barangay {
  final int id;
  final String name;

  Barangay({required this.id, required this.name});

  factory Barangay.fromJson(Map<String, dynamic> json) {
    return Barangay(id: json['brgyID'] ?? 0, name: json['brgyName'] ?? '');
  }
}

class BarangayService {
  final _dio = DioClient.instance;

  // Fetch all barangays (same endpoint the web admin uses)
  Future<List<Barangay>> getBarangays() async {
    final res = await _dio.get('/getBarangays');
    final list = (res.data as List).map((j) => Barangay.fromJson(j)).toList();
    // Sort alphabetically for the dropdown
    list.sort((a, b) => a.name.compareTo(b.name));
    return list;
  }
}
