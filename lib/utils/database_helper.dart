// ignore_for_file: avoid_print, depend_on_referenced_packages

import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:intl/intl.dart';
import 'dart:io';

class DatabaseHelper {
  static final DatabaseHelper _instance = DatabaseHelper._internal();
  static Database? _database;
  static bool _initialized = false;

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
    if (_initialized) return _database!;

    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'hoseo_diet.db');

    // 기존 데이터베이스 삭제 (스키마 변경으로 인한 문제 해결)
    try {
      final dbFile = File(path);
      if (await dbFile.exists()) {
        print('기존 데이터베이스 삭제 중...');
        await deleteDatabase(path);
        print('기존 데이터베이스 삭제 완료');
      }
    } catch (e) {
      print('데이터베이스 삭제 오류: $e');
    }

    final db = await openDatabase(
      path,
      version: 2,
      onCreate: _createDB,
      onUpgrade: _upgradeDB,
    );

    _initialized = true;
    return db;
  }

  Future<void> _createDB(Database db, int version) async {
    print('새 데이터베이스 생성 중...');

    await db.execute('''
      CREATE TABLE users(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT,
        email TEXT,
        photoUrl TEXT,
        uid TEXT,
        age INTEGER,
        gender TEXT,
        height REAL,
        weight REAL,
        activityLevel INTEGER,
        medicalCondition TEXT,
        targetCalories REAL
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
        sodium REAL,
        cholesterol REAL,
        sugar REAL,
        imageUrl TEXT,
        dateTime TEXT,
        firestore_id TEXT
      )
    ''');

    // 인덱스 생성으로 조회 성능 개선
    await db.execute('CREATE INDEX idx_foods_datetime ON foods(dateTime)');
    await db.execute(
      'CREATE INDEX idx_foods_firestore_id ON foods(firestore_id)',
    );

    print('새 데이터베이스 생성 완료');
  }

  Future<void> _upgradeDB(Database db, int oldVersion, int newVersion) async {
    print('데이터베이스 업그레이드: $oldVersion -> $newVersion');

    if (oldVersion < 2) {
      // 버전 1에서 2로 업그레이드
      try {
        // firestore_id 컬럼 추가
        await db.execute('ALTER TABLE foods ADD COLUMN firestore_id TEXT');
        print('foods 테이블에 firestore_id 컬럼 추가 완료');

        // 인덱스 생성
        await db.execute('CREATE INDEX idx_foods_datetime ON foods(dateTime)');
        await db.execute(
          'CREATE INDEX idx_foods_firestore_id ON foods(firestore_id)',
        );
        print('인덱스 생성 완료');
      } catch (e) {
        print('업그레이드 오류: $e');
      }
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

  // 음식 데이터 삽입 (중복 확인 포함)
  Future<int> insertFood(Map<String, dynamic> food) async {
    final db = await database;

    try {
      // id가 문자열인 경우 처리
      dynamic originalId = food['id'];
      if (originalId is String) {
        // firestore_id 필드에 원본 ID 저장
        food['firestore_id'] = originalId;
        // 로컬 DB는 int 타입의 ID를 사용하므로 null로 설정하여 자동 생성되게 함
        food.remove('id');
      }

      // 트랜잭션으로 처리하여 성능 개선
      return await db.transaction((txn) async {
        // firestore_id로 중복 확인
        if (food.containsKey('firestore_id')) {
          final List<Map<String, dynamic>> existingFoods = await txn.query(
            'foods',
            where: 'firestore_id = ?',
            whereArgs: [food['firestore_id']],
            limit: 1,
          );

          if (existingFoods.isNotEmpty) {
            return existingFoods.first['id'] as int;
          }
        }

        // 새 음식 삽입
        return await txn.insert('foods', food);
      });
    } catch (e) {
      print('음식 삽입 오류: $e');
      // 오류 발생 시 기본 방식으로 삽입 시도
      return await db.insert('foods', food);
    }
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

  // 모든 음식 가져오기 - 성능 최적화
  Future<List<Map<String, dynamic>>> getFoods() async {
    final db = await database;
    return await db.query(
      'foods',
      orderBy: 'dateTime DESC',
      limit: 100, // 최근 100개만 가져오기
    );
  }

  // 특정 날짜의 음식 가져오기 - 성능 최적화
  Future<List<Map<String, dynamic>>> getFoodsByDate(String dateStr) async {
    final db = await database;
    return await db.query(
      'foods',
      where: 'dateTime LIKE ?',
      whereArgs: ['$dateStr%'],
      orderBy: 'dateTime DESC',
    );
  }

  // 음식 삭제 - 성능 최적화
  Future<int> deleteFood(int id) async {
    final db = await database;
    return await db.delete('foods', where: 'id = ?', whereArgs: [id]);
  }
}
