import 'package:sqflite/sqflite.dart';
import '../api/dio_client.dart';
import 'local_db.dart';

// A single establishment (school, health facility, church, hall, etc.)
class Establishment {
  final int establishmentID;
  final String name;
  final String type;
  final String category;
  final double latitude;
  final double longitude;
  final bool isEvacuationCenter;
  final String? evacType;

  Establishment({
    required this.establishmentID,
    required this.name,
    required this.type,
    required this.category,
    required this.latitude,
    required this.longitude,
    this.isEvacuationCenter = false,
    this.evacType,
  });

  factory Establishment.fromJson(Map<String, dynamic> json) {
    return Establishment(
      establishmentID: json['establishmentID'] ?? 0,
      name: json['name'] ?? '',
      type: json['type'] ?? 'Other',
      category: json['category'] ?? 'Other',
      latitude: (json['latitude'] as num?)?.toDouble() ?? 0.0,
      longitude: (json['longitude'] as num?)?.toDouble() ?? 0.0,
      // Jackson serializes boolean isEvacuationCenter as "evacuationCenter".
      isEvacuationCenter:
          json['evacuationCenter'] ?? json['isEvacuationCenter'] ?? false,
      evacType: json['evacType'],
    );
  }

  // ── Local database (offline copy) ──
  Map<String, Object?> toDb() => {
    'establishment_id': establishmentID,
    'name': name,
    'type': type,
    'category': category,
    'latitude': latitude,
    'longitude': longitude,
    'is_evacuation_center': isEvacuationCenter ? 1 : 0,
    'evac_type': evacType,
  };

  factory Establishment.fromDb(Map<String, Object?> row) {
    return Establishment(
      establishmentID: (row['establishment_id'] as num?)?.toInt() ?? 0,
      name: (row['name'] as String?) ?? '',
      type: (row['type'] as String?) ?? 'Other',
      category: (row['category'] as String?) ?? 'Other',
      latitude: (row['latitude'] as num?)?.toDouble() ?? 0.0,
      longitude: (row['longitude'] as num?)?.toDouble() ?? 0.0,
      isEvacuationCenter:
          ((row['is_evacuation_center'] as num?)?.toInt() ?? 0) == 1,
      evacType: row['evac_type'] as String?,
    );
  }
}

class EstablishmentService {
  final _dio = DioClient.instance;

  // Fetch active establishments (same endpoint the admin manages).
  // Online: returns the fresh list and saves a copy on the phone.
  // Offline / server unreachable: returns the saved copy instead.
  Future<List<Establishment>> getEstablishments() async {
    try {
      final res = await _dio.get('/api/establishments');
      final list = (res.data as List)
          .map((j) => Establishment.fromJson(j))
          .toList();
      await _saveToCache(list);
      return list;
    } catch (e) {
      final cached = await _loadFromCache();
      if (cached.isNotEmpty) return cached;
      rethrow; // nothing saved yet — let the caller handle it
    }
  }

  Future<void> _saveToCache(List<Establishment> list) async {
    try {
      final db = await LocalDb.instance.database;
      await db.transaction((txn) async {
        await txn.delete('establishments');
        final batch = txn.batch();
        for (final e in list) {
          batch.insert(
            'establishments',
            e.toDb(),
            conflictAlgorithm: ConflictAlgorithm.replace,
          );
        }
        await batch.commit(noResult: true);
      });
    } catch (_) {
      // caching is best-effort
    }
  }

  Future<List<Establishment>> _loadFromCache() async {
    try {
      final db = await LocalDb.instance.database;
      final rows = await db.query('establishments');
      return rows.map(Establishment.fromDb).toList();
    } catch (_) {
      return [];
    }
  }
}
