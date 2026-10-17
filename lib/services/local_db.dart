import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

/// The app's local (on-phone) SQLite database. Used for offline support:
///  - establishments       : saved copy so "nearest evacuation/medical" works offline
///  - hazard_types         : saved copy so the report form works offline
///  - pending_reports      : reports written while offline, waiting to be sent
class LocalDb {
  LocalDb._();
  static final LocalDb instance = LocalDb._();

  static const String _dbName = 'masid.db';
  static const int _version = 1;

  Future<Database>? _opening;

  Future<Database> get database => _opening ??= _open();

  Future<Database> _open() async {
    final path = p.join(await getDatabasesPath(), _dbName);
    return openDatabase(
      path,
      version: _version,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE establishments (
            establishment_id INTEGER PRIMARY KEY,
            name TEXT NOT NULL,
            type TEXT NOT NULL,
            category TEXT NOT NULL,
            latitude REAL NOT NULL,
            longitude REAL NOT NULL,
            is_evacuation_center INTEGER NOT NULL DEFAULT 0,
            evac_type TEXT
          )
        ''');
        await db.execute('''
          CREATE TABLE hazard_types (
            hazard_id INTEGER PRIMARY KEY,
            hazard_name TEXT NOT NULL
          )
        ''');
        await db.execute('''
          CREATE TABLE pending_reports (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            hazard_id INTEGER NOT NULL,
            severity INTEGER NOT NULL,
            description TEXT NOT NULL,
            latitude REAL NOT NULL,
            longitude REAL NOT NULL,
            photo_path TEXT,
            image_url TEXT,
            created_at TEXT NOT NULL,
            attempts INTEGER NOT NULL DEFAULT 0,
            last_error TEXT
          )
        ''');
      },
    );
  }
}
