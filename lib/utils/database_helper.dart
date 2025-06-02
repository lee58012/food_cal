import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

class DatabaseHelper {
  static final DatabaseHelper _instance = DatabaseHelper._internal();
  static Database? _database;

  factory DatabaseHelper() => _instance;

  DatabaseHelper._internal();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    final path = join(await getDatabasesPath(), 'hoseo_diet.db');
    return await openDatabase(path, version: 1, onCreate: _createDb);
  }

  Future<void> _createDb(Database db, int version) async {
    await db.execute('''
      CREATE TABLE users(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT,
        age INTEGER,
        weight REAL,
        height REAL,
        gender TEXT,
        activityLevel INTEGER,
        targetCalories INTEGER,
        email TEXT,
        photoUrl TEXT,
        uid TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE foods(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT,
        calories INTEGER,
        carbs REAL,
        protein REAL,
        fat REAL,
        imageUrl TEXT,
        dateTime TEXT
      )
    ''');
  }

  // 사용자 CRUD 메서드
  Future<int> insertUser(Map<String, dynamic> user) async {
    final db = await database;
    return await db.insert('users', user);
  }

  Future<List<Map<String, dynamic>>> getUser() async {
    final db = await database;
    return await db.query('users');
  }

  Future<int> updateUser(Map<String, dynamic> user) async {
    final db = await database;
    return await db.update(
      'users',
      user,
      where: 'id = ?',
      whereArgs: [user['id']],
    );
  }

  Future<int> deleteUser(int id) async {
    final db = await database;
    return await db.delete('users', where: 'id = ?', whereArgs: [id]);
  }

  // 음식 CRUD 메서드
  Future<int> insertFood(Map<String, dynamic> food) async {
    final db = await database;
    return await db.insert('foods', food);
  }

  Future<List<Map<String, dynamic>>> getFoods() async {
    final db = await database;
    return await db.query('foods', orderBy: 'dateTime DESC');
  }

  Future<List<Map<String, dynamic>>> getFoodsByDate(String date) async {
    final db = await database;
    return await db.query(
      'foods',
      where: 'dateTime LIKE ?',
      whereArgs: ['$date%'],
      orderBy: 'dateTime DESC',
    );
  }

  Future<int> updateFood(Map<String, dynamic> food) async {
    final db = await database;
    return await db.update(
      'foods',
      food,
      where: 'id = ?',
      whereArgs: [food['id']],
    );
  }

  Future<int> deleteFood(int id) async {
    final db = await database;
    return await db.delete('foods', where: 'id = ?', whereArgs: [id]);
  }
}
