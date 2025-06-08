// ignore_for_file: avoid_print

import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

class DatabaseHelper {
  static final DatabaseHelper _instance = DatabaseHelper._internal();
  static Database? _database;

  factory DatabaseHelper() => _instance;

  DatabaseHelper._internal();

  Future<Database> get database async {
    if (_database != null) return _database!;

    // 웹 환경인 경우 예외 처리
    if (kIsWeb) {
      throw UnsupportedError('웹 환경에서는 SQLite를 사용할 수 없습니다.');
    }

    // 데이터베이스 초기화
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    try {
      final path = join(await getDatabasesPath(), 'hoseo_diet.db');

      // 데이터베이스 파일이 있는지 확인
      bool exists = await databaseExists(path);

      // 데이터베이스가 있으면 삭제 (스키마 변경 문제 해결을 위해)
      if (exists) {
        print('기존 데이터베이스 파일 삭제');
        await deleteDatabase(path);
      }

      return await openDatabase(
        path,
        version: 6, // 버전 6으로 업데이트
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

    if (oldVersion < 5) {
      try {
        // 기존 foods 테이블 백업
        await db.execute('ALTER TABLE foods RENAME TO foods_old');
        print('foods 테이블 백업 완료');

        // 새로운 컬럼명으로 foods 테이블 재생성
        await db.execute('''
          CREATE TABLE foods(
            food_id INTEGER PRIMARY KEY AUTOINCREMENT,
            food_name TEXT,
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
        print('새로운 컬럼명으로 foods 테이블 재생성 완료');

        // 데이터 마이그레이션
        await db.execute('''
          INSERT INTO foods(food_id, food_name, calories, carbs, protein, fat, sodium, cholesterol, sugar, imageUrl, dateTime)
          SELECT id, name, calories, carbs, protein, fat, sodium, cholesterol, sugar, imageUrl, dateTime
          FROM foods_old
        ''');
        print('foods 테이블 데이터 마이그레이션 완료');

        // 백업 테이블 삭제
        await db.execute('DROP TABLE foods_old');
        print('foods_old 테이블 삭제 완료');
      } catch (e) {
        print('데이터베이스 업그레이드 오류 (버전 5): $e');
      }
    }

    if (oldVersion < 6) {
      try {
        // foods 테이블이 존재하는지 확인
        final tables = await db.rawQuery(
          "SELECT name FROM sqlite_master WHERE type='table' AND name='foods'",
        );

        // foods 테이블이 존재하면 삭제
        if (tables.isNotEmpty) {
          await db.execute('DROP TABLE IF EXISTS foods');
          print('기존 foods 테이블 삭제 완료 (버전 6)');
        }

        // foods 테이블 재생성
        await db.execute('''
          CREATE TABLE foods(
            food_id INTEGER PRIMARY KEY AUTOINCREMENT,
            food_name TEXT,
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
        print('foods 테이블 재생성 완료 (버전 6)');
      } catch (e) {
        print('데이터베이스 업그레이드 오류 (버전 6): $e');
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
          food_id INTEGER PRIMARY KEY AUTOINCREMENT,
          food_name TEXT,
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

    final Map<String, dynamic> updatedFood = Map.from(food);
    if (updatedFood.containsKey('name')) {
      updatedFood['food_name'] = updatedFood['name'];
      updatedFood.remove('name');
    }
    if (updatedFood.containsKey('id')) {
      updatedFood['food_id'] = updatedFood['id'];
      updatedFood.remove('id');
    }

    // 중복 체크 로직 제거 - 같은 이름의 음식도 모두 저장
    print('새로운 음식 데이터 삽입: ${updatedFood['food_name']}');
    return await db.insert(
      'foods',
      updatedFood,
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
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

    // 필드명 변환 (name -> food_name)
    final Map<String, dynamic> updatedFood = Map.from(food);
    if (updatedFood.containsKey('name')) {
      updatedFood['food_name'] = updatedFood['name'];
      updatedFood.remove('name');
    }
    if (updatedFood.containsKey('id')) {
      updatedFood['food_id'] = updatedFood['id'];
      updatedFood.remove('id');
    }

    return await db.update(
      'foods',
      updatedFood,
      where: 'food_id = ?',
      whereArgs: [updatedFood['food_id']],
    );
  }

  Future<int> deleteFood(int id) async {
    final db = await database;
    return await db.delete('foods', where: 'food_id = ?', whereArgs: [id]);
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

  // 특정 날짜의 음식 데이터 삭제 전 조회
  Future<List<Map<String, dynamic>>> getFoodsAndDeleteByDate(
    String date,
  ) async {
    final db = await database;

    // 먼저 해당 날짜의 음식 데이터 조회
    final foods = await db.query(
      'foods',
      where: 'dateTime LIKE ?',
      whereArgs: ['$date%'],
    );

    // 조회 후 삭제
    await db.delete('foods', where: 'dateTime LIKE ?', whereArgs: ['$date%']);

    print('날짜 $date의 ${foods.length}개 음식 데이터 삭제');
    return foods;
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
    final result = await db.rawQuery('SELECT MAX(food_id) as maxId FROM foods');
    return (result.first['maxId'] as int?) ?? 0;
  }
}
