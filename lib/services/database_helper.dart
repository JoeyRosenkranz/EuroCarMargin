import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/calculation_result.dart';

/// Helper pour la base SQLite locale
class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._init();
  static Database? _database;

  DatabaseHelper._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('eurocar_margin.db');
    return _database!;
  }

  Future<Database> _initDB(String fileName) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, fileName);
    return await openDatabase(
      path, 
      version: 3, 
      onCreate: _createDB,
      onUpgrade: _upgradeDB,
    );
  }

  Future<void> _upgradeDB(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await db.execute('ALTER TABLE searches ADD COLUMN fuel_type TEXT');
    }
    if (oldVersion < 3) {
      await db.execute('ALTER TABLE searches ADD COLUMN resale_fr_quick REAL');
      await db.execute('ALTER TABLE searches ADD COLUMN resale_fr_market REAL');
    }
  }

  Future<void> _createDB(Database db, int version) async {
    await db.execute('''
      CREATE TABLE searches (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        brand TEXT NOT NULL,
        model TEXT NOT NULL,
        trim TEXT,
        year INTEGER NOT NULL,
        power_din INTEGER NOT NULL,
        power_fiscal INTEGER NOT NULL,
        weight_g1 INTEGER NOT NULL,
        co2_wltp INTEGER NOT NULL,
        fuel_type TEXT,
        purchase_price REAL NOT NULL,
        transport_cost REAL DEFAULT 0,
        prep_cost REAL DEFAULT 0,
        region TEXT NOT NULL,
        taxe_regionale REAL,
        malus_co2 REAL,
        malus_co2_before_vetuste REAL,
        malus_poids REAL,
        total_carte_grise REAL,
        total_invested REAL,
        resale_quick REAL,
        resale_market REAL,
        resale_fr_quick REAL,
        resale_fr_market REAL,
        profit_quick REAL,
        profit_market REAL,
        risk_level TEXT,
        vetust_years INTEGER,
        created_at TEXT NOT NULL
      )
    ''');
  }

  /// Sauvegarder un résultat de calcul
  Future<int> insertSearch(CalculationResult result) async {
    final db = await database;
    return await db.insert('searches', result.toMap());
  }

  /// Récupérer toutes les recherches (les plus récentes d'abord)
  Future<List<Map<String, dynamic>>> getAllSearches() async {
    final db = await database;
    return await db.query('searches', orderBy: 'created_at DESC');
  }

  /// Supprimer une recherche
  Future<int> deleteSearch(int id) async {
    final db = await database;
    return await db.delete('searches', where: 'id = ?', whereArgs: [id]);
  }

  /// Supprimer toutes les recherches
  Future<int> deleteAllSearches() async {
    final db = await database;
    return await db.delete('searches');
  }

  /// Fermer la base
  Future<void> close() async {
    final db = await database;
    db.close();
    _database = null;
  }
}
