import '../api/dio_client.dart';

class Barangay {
  final int brgyID;
  final String brgyName;

  Barangay({required this.brgyID, required this.brgyName});

  factory Barangay.fromJson(Map<String, dynamic> json) {
    return Barangay(brgyID: json['brgyID'], brgyName: json['brgyName']);
  }
}

class BarangayService {
  final _dio = DioClient.instance;

  Future<List<Barangay>> getBarangays() async {
    final res = await _dio.get('/getBarangays');
    return (res.data as List).map((j) => Barangay.fromJson(j)).toList();
  }
}
