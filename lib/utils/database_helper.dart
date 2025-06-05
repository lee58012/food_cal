// ignore_for_file: avoid_print

import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

class DatabaseHelper {
  static final DatabaseHelper _instance = DatabaseHelper._internal();
  static Database? _database;

  factory DatabaseHelper() => _instance;

  DatabaseHelper._internal();

  Future<Database> get database async {
    if (_database != null) return _database!;

    // 데이터베이스 초기화
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    try {
      final path = join(await getDatabasesPath(), 'hoseo_diet.db');
      return await openDatabase(
        path,
        version: 4,
        onCreate: _createDb,
        onUpgrade: _upgradeDb,
      );
    } catch (e) {
      print('데이터베이스 초기화 오류: $e');
      rethrow;
    }
  }

  Future<void> _upgradeDb(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      try {
        // 컬럼이 이미 존재하는지 확인
        var columns = await db.rawQuery('PRAGMA table_info(users)');
        bool hasMedicalCondition = false;
        bool hasEmail = false;
        bool hasPhotoUrl = false;

        for (var col in columns) {
          if (col['name'] == 'medicalCondition') {
            hasMedicalCondition = true;
          }
          if (col['name'] == 'email') {
            hasEmail = true;
          }
          if (col['name'] == 'photoUrl') {
            hasPhotoUrl = true;
          }
        }

        if (!hasMedicalCondition) {
          await db.execute(
            'ALTER TABLE users ADD COLUMN medicalCondition TEXT DEFAULT "정상"',
          );
          print('medicalCondition 컬럼 추가 완료');
        }

        if (!hasEmail) {
          await db.execute('ALTER TABLE users ADD COLUMN email TEXT');
          print('email 컬럼 추가 완료');
        }

        if (!hasPhotoUrl) {
          await db.execute('ALTER TABLE users ADD COLUMN photoUrl TEXT');
          print('photoUrl 컬럼 추가 완료');
        }
      } catch (e) {
        print('데이터베이스 업그레이드 오류 (버전 2): $e');
      }
    }

    if (oldVersion < 3) {
      try {
        // foods 테이블이 존재하는지 확인
        final tables = await db.rawQuery(
          "SELECT name FROM sqlite_master WHERE type='table' AND name='foods'",
        );

        // foods 테이블이 존재하면 삭제
        if (tables.isNotEmpty) {
          await db.execute('DROP TABLE IF EXISTS foods');
          print('기존 foods 테이블 삭제 완료');
        }

        // foods 테이블 재생성
        await db.execute('''
          CREATE TABLE foods(
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            name TEXT,
            calories INTEGER,
            carbs REAL,
            protein REAL,
            fat REAL,
            sodium REAL,
            cholesterol REAL,
            sugar REAL,
            imageUrl TEXT,
            dateTime TEXT
          )
        ''');
        print('foods 테이블 재생성 완료');
      } catch (e) {
        print('데이터베이스 업그레이드 오류 (버전 3): $e');
      }
    }

    if (oldVersion < 4) {
      try {
        // foods 테이블의 컬럼 존재 여부 확인
        var columns = await db.rawQuery('PRAGMA table_info(foods)');
        bool hasSodium = false;
        bool hasCholesterol = false;
        bool hasSugar = false;

        for (var col in columns) {
          if (col['name'] == 'sodium') {
            hasSodium = true;
          }
          if (col['name'] == 'cholesterol') {
            hasCholesterol = true;
          }
          if (col['name'] == 'sugar') {
            hasSugar = true;
          }
        }

        // 누락된 컬럼 추가
        if (!hasSodium) {
          await db.execute(
            'ALTER TABLE foods ADD COLUMN sodium REAL DEFAULT 0',
          );
          print('sodium 컬럼 추가 완료');
        }
        if (!hasCholesterol) {
          await db.execute(
            'ALTER TABLE foods ADD COLUMN cholesterol REAL DEFAULT 0',
          );
          print('cholesterol 컬럼 추가 완료');
        }
        if (!hasSugar) {
          await db.execute('ALTER TABLE foods ADD COLUMN sugar REAL DEFAULT 0');
          print('sugar 컬럼 추가 완료');
        }
      } catch (e) {
        print('데이터베이스 업그레이드 오류 (버전 4): $e');
      }
    }
  }

  Future<void> _createDb(Database db, int version) async {
    try {
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
          uid TEXT,
          medicalCondition TEXT DEFAULT "정상"
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
          sodium REAL DEFAULT 0,
          cholesterol REAL DEFAULT 0,
          sugar REAL DEFAULT 0,
          imageUrl TEXT,
          dateTime TEXT
        )
      ''');

      print('데이터베이스 테이블 생성 완료');
    } catch (e) {
      print('데이터베이스 테이블 생성 오류: $e');
      rethrow;
    }
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

  // 특정 날짜의 음식 데이터 삭제
  Future<int> deleteFoodsByDate(String date) async {
    final db = await database;
    return await db.delete(
      'foods',
      where: 'dateTime LIKE ?',
      whereArgs: ['$date%'],
    );
  }

  // 모든 음식 데이터 삭제
  Future<int> clearFoods() async {
    final db = await database;
    return await db.delete('foods');
  }

  // 데이터베이스 초기화 (테스트 용도)
  Future<void> resetDatabase() async {
    try {
      final path = join(await getDatabasesPath(), 'hoseo_diet.db');
      await deleteDatabase(path);
      _database = null;
      await database;
      print('데이터베이스 초기화 완료');
    } catch (e) {
      print('데이터베이스 초기화 오류: $e');
      rethrow;
    }
  }

  // 현재 저장된 음식 데이터의 최대 ID 값을 가져오는 메서드
  Future<int> getMaxFoodId() async {
    final db = await database;
    final result = await db.rawQuery('SELECT MAX(id) as maxId FROM foods');
    return (result.first['maxId'] as int?) ?? 0;
  }
}
