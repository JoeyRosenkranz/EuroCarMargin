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
      version: 4,
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
    if (oldVersion < 4) {
      const columns = <String, String>{
        'first_registration_month': 'INTEGER DEFAULT 1',
        'mileage': 'INTEGER',
        'seats': 'INTEGER DEFAULT 5',
        'electric_range_km': 'INTEGER',
        'source_fiscal': "TEXT DEFAULT 'Manquant'",
        'source_co2': "TEXT DEFAULT 'Manquant'",
        'source_weight': "TEXT DEFAULT 'Manquant'",
        'raw_description': 'TEXT',
        'cash_malus_co2': 'REAL DEFAULT 0',
        'cash_malus_poids': 'REAL DEFAULT 0',
        'family_refund': 'REAL DEFAULT 0',
        'cash_carte_grise': 'REAL DEFAULT 0',
        'cash_required': 'REAL DEFAULT 0',
        'pro_costs': 'REAL DEFAULT 1500',
        'vat_on_margin': 'INTEGER DEFAULT 1',
        'family_co2_deduction': 'INTEGER DEFAULT 0',
        'family_weight_deduction': 'INTEGER DEFAULT 0',
        'age_reduction_pct': 'INTEGER DEFAULT 0',
        'calculation_reliable': 'INTEGER DEFAULT 0',
        'comparable_count': 'INTEGER DEFAULT 0',
      };
      for (final entry in columns.entries) {
        await db.execute(
          'ALTER TABLE searches ADD COLUMN ${entry.key} ${entry.value}',
        );
      }
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
        first_registration_month INTEGER DEFAULT 1,
        mileage INTEGER,
        power_din INTEGER NOT NULL,
        power_fiscal INTEGER NOT NULL,
        weight_g1 INTEGER NOT NULL,
        co2_wltp INTEGER NOT NULL,
        fuel_type TEXT,
        seats INTEGER DEFAULT 5,
        electric_range_km INTEGER,
        purchase_price REAL NOT NULL,
        transport_cost REAL DEFAULT 0,
        prep_cost REAL DEFAULT 0,
        region TEXT NOT NULL,
        source_fiscal TEXT,
        source_co2 TEXT,
        source_weight TEXT,
        raw_description TEXT,
        taxe_regionale REAL,
        malus_co2 REAL,
        malus_co2_before_vetuste REAL,
        malus_poids REAL,
        cash_malus_co2 REAL,
        cash_malus_poids REAL,
        family_refund REAL,
        total_carte_grise REAL,
        cash_carte_grise REAL,
        total_invested REAL,
        cash_required REAL,
        resale_quick REAL,
        resale_market REAL,
        resale_fr_quick REAL,
        resale_fr_market REAL,
        profit_quick REAL,
        profit_market REAL,
        pro_costs REAL,
        vat_on_margin INTEGER,
        risk_level TEXT,
        vetust_years INTEGER,
        family_co2_deduction INTEGER,
        family_weight_deduction INTEGER,
        age_reduction_pct INTEGER,
        calculation_reliable INTEGER,
        comparable_count INTEGER,
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
