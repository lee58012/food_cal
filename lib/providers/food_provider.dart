// ignore_for_file: unused_import

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:hoseo/models/food.dart';
import 'package:hoseo/utils/database_helper.dart';
import 'package:hoseo/utils/firestore_service.dart';
import 'package:intl/intl.dart';
import 'dart:convert';
import 'package:firebase_auth/firebase_auth.dart' as auth;
import 'package:uuid/uuid.dart';

class FoodProvider with ChangeNotifier {
  List<Food> _foods = [];
  DateTime _selectedDate = DateTime.now();
  final FirestoreService _firestoreService = FirestoreService();
  final auth.FirebaseAuth _auth = auth.FirebaseAuth.instance;
  bool _isLoading = false;

  // 캐싱을 위한 변수들
  final Map<String, List<Food>> _cachedFoodsByDate = {};
  final Map<String, int> _cachedCaloriesByDate = {};
  bool _isInitialized = false;

  List<Food> get foods => _foods;
  DateTime get selectedDate => _selectedDate;
  bool get isLoading => _isLoading;

  // 선택한 날짜의 음식만 필터링 (캐시 우선 사용)
  List<Food> get foodsForSelectedDate {
    final dateFormat = DateFormat('yyyy-MM-dd');
    final selectedDateStr = dateFormat.format(_selectedDate);

    // 캐시된 데이터가 있으면 사용
    if (_cachedFoodsByDate.containsKey(selectedDateStr)) {
      return _cachedFoodsByDate[selectedDateStr] ?? [];
    }

    // 캐시된 데이터가 없으면 필터링
    final filteredFoods = _foods.where((food) {
      final foodDateStr = dateFormat.format(food.dateTime);
      return foodDateStr == selectedDateStr;
    }).toList();

    // 결과 캐싱
    _cachedFoodsByDate[selectedDateStr] = filteredFoods;
    return filteredFoods;
  }

  // 선택한 날짜의 총 칼로리 (캐시 우선 사용)
  double get totalCaloriesForSelectedDate {
    final dateFormat = DateFormat('yyyy-MM-dd');
    final selectedDateStr = dateFormat.format(_selectedDate);

    // 캐시된 칼로리 데이터가 있으면 사용
    if (_cachedCaloriesByDate.containsKey(selectedDateStr)) {
      final cachedCalories = _cachedCaloriesByDate[selectedDateStr] ?? 0;
      return cachedCalories.toDouble();
    }

    // 없으면 실시간 계산
    final filteredFoods = _foods.where((food) {
      final foodDateStr = dateFormat.format(food.dateTime);
      return foodDateStr == selectedDateStr;
    }).toList();

    final total = filteredFoods.fold(0, (sum, food) {
      return sum + food.calories;
    });

    // 결과 캐싱
    _cachedCaloriesByDate[selectedDateStr] = total;

    return total.toDouble();
  }

  // 선택한 날짜의 총 탄수화물
  double get totalCarbsForSelectedDate {
    return foodsForSelectedDate.fold(0.0, (sum, food) => sum + food.carbs);
  }

  // 선택한 날짜의 총 단백질
  double get totalProteinForSelectedDate {
    return foodsForSelectedDate.fold(0.0, (sum, food) => sum + food.protein);
  }

  // 선택한 날짜의 총 지방
  double get totalFatForSelectedDate {
    return foodsForSelectedDate.fold(0.0, (sum, food) => sum + food.fat);
  }

  // 선택한 날짜의 총 나트륨
  double get totalSodiumForSelectedDate {
    return foodsForSelectedDate.fold(0.0, (sum, food) => sum + food.sodium);
  }

  // 선택한 날짜의 총 콜레스테롤
  double get totalCholesterolForSelectedDate {
    return foodsForSelectedDate.fold(
      0.0,
      (sum, food) => sum + food.cholesterol,
    );
  }

  // 선택한 날짜의 총 당류
  double get totalSugarForSelectedDate {
    return foodsForSelectedDate.fold(0.0, (sum, food) => sum + food.sugar);
  }

  // 날짜 선택 및 해당 날짜의 음식 데이터 로드
  Future<void> selectDate(DateTime date) async {
    // 이전 날짜와 동일하면 불필요한 로드 방지
    if (DateFormat('yyyy-MM-dd').format(_selectedDate) ==
        DateFormat('yyyy-MM-dd').format(date)) {
      return;
    }

    _selectedDate = date;

    // 날짜 변경 시 해당 날짜의 식단 데이터 로드
    await loadFoodsByDate(date);

    // 데이터 로드 완료 후 UI 업데이트
    notifyListeners();
  }

  // 초기 데이터 로드 및 초기화
  Future<void> initialize() async {
    if (_isInitialized) return;

    await loadFoods();
    _isInitialized = true;
  }

  // 모든 음식 로드 (Firestore 사용)
  Future<void> loadFoods() async {
    final currentUser = _auth.currentUser;
    if (currentUser == null) return;

    _isLoading = true;
    notifyListeners();

    try {
      // Firestore에서 음식 데이터 로드 (날짜 제한 없이 전체 데이터)
      _foods = await _firestoreService.getFoods(currentUser.uid);

      // 캐시 초기화
      _clearCache();

      // 로컬 DB와 동기화
      final dbHelper = DatabaseHelper();

      // 기존 데이터 삭제 전에 최대 ID 값 확인
      final maxId = await dbHelper.getMaxFoodId();

      // 기존 데이터 삭제
      await dbHelper.clearFoods();

      // Firestore 데이터를 로컬 DB에 저장 (새로운 ID 할당)
      int newId = maxId + 1;
      for (var food in _foods) {
        final foodMap = food.toMap();
        foodMap['id'] = newId++; // 새로운 ID 할당
        await dbHelper.insertFood(foodMap);
      }

      // 로컬 DB에서 새로 저장된 데이터 다시 로드
      final foodsData = await dbHelper.getFoods();
      _foods = foodsData.map((map) => Food.fromMap(map)).toList();

      // 날짜별로 캐시 업데이트
      _updateCacheFromLocalData();
    } catch (e) {
      // 오류 발생 시 로컬 DB에서 로드 시도
      try {
        final dbHelper = DatabaseHelper();
        final foodsData = await dbHelper.getFoods();
        _foods = foodsData.map((map) => Food.fromMap(map)).toList();

        // 로컬 데이터로 캐시 업데이트
        _updateCacheFromLocalData();
      } catch (dbError) {
        _foods = [];
        _clearCache();
      }
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // 캐시 초기화
  void _clearCache() {
    _cachedFoodsByDate.clear();
    _cachedCaloriesByDate.clear();
  }

  // 로컬 데이터로 캐시 업데이트
  void _updateCacheFromLocalData() {
    final dateFormat = DateFormat('yyyy-MM-dd');
    _clearCache();

    // 날짜별로 음식 분류
    for (var food in _foods) {
      final dateStr = dateFormat.format(food.dateTime);

      // 음식 목록 캐시 업데이트
      if (!_cachedFoodsByDate.containsKey(dateStr)) {
        _cachedFoodsByDate[dateStr] = [];
      }
      _cachedFoodsByDate[dateStr]!.add(food);

      // 칼로리 캐시 업데이트
      _cachedCaloriesByDate[dateStr] =
          (_cachedCaloriesByDate[dateStr] ?? 0) + food.calories;
    }

    _cachedFoodsByDate.forEach((date, foods) {});
  }

  // 음식 추가 - 캐시 업데이트 수정
  Future<void> addFood(Food food) async {
    final currentUser = _auth.currentUser;
    if (currentUser == null) {
      throw Exception('사용자가 로그인되지 않았습니다.');
    }

    _isLoading = true;
    notifyListeners();

    try {
      // 1. 먼저 로컬 DB에 저장하여 ID 생성
      final dbHelper = DatabaseHelper();
      final localId = await dbHelper.insertFood(food.toMap());

      final newFood = Food(
        id: localId,
        name: food.name,
        calories: food.calories,
        carbs: food.carbs,
        protein: food.protein,
        fat: food.fat,
        sodium: food.sodium,
        cholesterol: food.cholesterol,
        sugar: food.sugar,
        imageUrl: food.imageUrl,
        dateTime: food.dateTime,
      );

      // 2. Firestore에 저장 (트랜잭션 없이 단순 저장)
      await _firestoreService.addFood(currentUser.uid, newFood);

      // 3. 메모리에 추가
      _foods.add(newFood);

      // 4. 캐시 업데이트 - 수정된 부분
      final dateFormat = DateFormat('yyyy-MM-dd');
      final dateStr = dateFormat.format(food.dateTime);

      // 음식 목록 캐시 업데이트
      if (!_cachedFoodsByDate.containsKey(dateStr)) {
        _cachedFoodsByDate[dateStr] = [];
      }
      _cachedFoodsByDate[dateStr]!.add(newFood);

      // 칼로리 캐시 업데이트 - 기존 값에 더하기
      final currentCachedCalories = _cachedCaloriesByDate[dateStr] ?? 0;
      _cachedCaloriesByDate[dateStr] = currentCachedCalories + food.calories;
    } catch (e) {
      // Firestore 저장 실패 시 로컬 데이터도 롤백
      try {
        final dbHelper = DatabaseHelper();
        if (_foods.isNotEmpty && _foods.last.name == food.name) {
          await dbHelper.deleteFood(_foods.last.id!);
          _foods.removeLast();
        }
      } catch (rollbackError) {}

      rethrow; // 오류를 상위로 전파
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // 음식 삭제 - 캐시 업데이트 수정
  Future<void> deleteFood(int id) async {
    final currentUser = _auth.currentUser;
    if (currentUser == null) return;

    _isLoading = true;
    notifyListeners();

    try {
      // 삭제할 음식 찾기
      final food = _foods.firstWhere((food) => food.id == id);
      final dateTime = food.dateTime;
      final dateFormat = DateFormat('yyyy-MM-dd');
      final dateStr = dateFormat.format(dateTime);

      // 1. 로컬 DB에서 먼저 삭제
      final dbHelper = DatabaseHelper();
      await dbHelper.deleteFood(id);

      // 2. Firestore에서 삭제 (이미지도 함께 삭제)
      await _firestoreService.deleteFood(
        currentUser.uid,
        id.toString(),
        food.calories,
        food.dateTime,
        food.imageUrl, // 이미지 URL 전달
      );

      // 3. 메모리에서 제거
      _foods.removeWhere((food) => food.id == id);

      // 4. 캐시 업데이트 - 수정된 부분
      if (_cachedFoodsByDate.containsKey(dateStr)) {
        _cachedFoodsByDate[dateStr]!.removeWhere((f) => f.id == id);

        // 칼로리 캐시에서 삭제된 음식의 칼로리 빼기
        final currentCachedCalories = _cachedCaloriesByDate[dateStr] ?? 0;
        _cachedCaloriesByDate[dateStr] = (currentCachedCalories - food.calories)
            .clamp(0, double.infinity)
            .toInt();
      }
    } catch (e) {
      // 오류 발생 시 데이터 다시 로드
      await loadFoodsByDate(_selectedDate);
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // 날짜별 음식 로드 - 캐시 업데이트 수정
  Future<void> loadFoodsByDate(DateTime date) async {
    final currentUser = _auth.currentUser;
    if (currentUser == null) return;

    final dateFormat = DateFormat('yyyy-MM-dd');
    final dateStr = dateFormat.format(date);

    if (_isLoading) return;

    _isLoading = true;

    try {
      final foodsForDate = await _firestoreService.getFoodsByDate(
        currentUser.uid,
        date,
      );

      if (foodsForDate.isNotEmpty) {
        // 기존 해당 날짜 음식들을 메모리에서 제거
        _foods.removeWhere((food) {
          final foodDateStr = dateFormat.format(food.dateTime);
          return foodDateStr == dateStr;
        });

        // 새로운 음식들 추가
        _foods.addAll(foodsForDate);

        // 캐시 업데이트
        _cachedFoodsByDate[dateStr] = foodsForDate;

        // 칼로리 다시 계산
        final totalCalories = foodsForDate.fold(
          0,
          (sum, food) => sum + food.calories,
        );
        _cachedCaloriesByDate[dateStr] = totalCalories;

        // 로컬 DB 동기화
        final dbHelper = DatabaseHelper();
        await dbHelper.deleteFoodsByDate(dateStr);

        for (var food in foodsForDate) {
          await dbHelper.insertFood(food.toMap());
        }
      } else {
        // 데이터가 없는 경우 캐시 초기화
        _cachedFoodsByDate[dateStr] = [];
        _cachedCaloriesByDate[dateStr] = 0;
      }
    } catch (e) {
      try {
        final dbHelper = DatabaseHelper();
        final foodsData = await dbHelper.getFoodsByDate(dateStr);

        if (foodsData.isNotEmpty) {
          final localFoods = foodsData.map((map) => Food.fromMap(map)).toList();

          _foods.removeWhere((food) {
            final foodDateStr = dateFormat.format(food.dateTime);
            return foodDateStr == dateStr;
          });

          _foods.addAll(localFoods);

          _cachedFoodsByDate[dateStr] = localFoods;
          _cachedCaloriesByDate[dateStr] = localFoods.fold(
            0,
            (sum, food) => sum + food.calories,
          );
        } else {
          _cachedFoodsByDate[dateStr] = [];
          _cachedCaloriesByDate[dateStr] = 0;
        }
      } catch (dbError) {
        _cachedFoodsByDate[dateStr] = [];
        _cachedCaloriesByDate[dateStr] = 0;
      }
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<String?> uploadFoodImage(File imageFile) async {
    final currentUser = _auth.currentUser;
    if (currentUser == null) return null;

    try {
      final bytes = await imageFile.readAsBytes();

      if (bytes.length > 1024 * 1024) {
        return null;
      }

      final base64String = base64Encode(bytes);
      final dataUrl = 'data:image/jpeg;base64,$base64String';

      return dataUrl;
    } catch (e) {
      return null;
    }
  }

  Future<Map<String, dynamic>> analyzeFoodImage(File imageFile) async {
    _isLoading = true;
    notifyListeners();

    try {
      final imageUrl = await uploadFoodImage(imageFile);

      await Future.delayed(const Duration(seconds: 2));

      return {
        'name': '비빔밥',
        'calories': 560,
        'carbs': 82.5,
        'protein': 15.3,
        'fat': 12.8,
        'sodium': 100,
        'cholesterol': 100,
        'sugar': 10,
        'imageUrl': imageUrl,
      };
    } catch (e) {
      return {
        'name': '알 수 없는 음식',
        'calories': 0,
        'carbs': 0.0,
        'protein': 0.0,
        'fat': 0.0,
        'sodium': 0.0,
        'cholesterol': 0.0,
        'sugar': 0.0,
        'imageUrl': null,
      };
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<int> getDailyCalorieIntake(DateTime date) async {
    final dateFormat = DateFormat('yyyy-MM-dd');
    final dateStr = dateFormat.format(date);

    if (_cachedCaloriesByDate.containsKey(dateStr)) {
      return _cachedCaloriesByDate[dateStr] ?? 0;
    }

    final currentUser = _auth.currentUser;
    if (currentUser == null) return 0;

    try {
      final calories = await _firestoreService.getDailyCalorieIntake(
        currentUser.uid,
        date,
      );

      _cachedCaloriesByDate[dateStr] = calories;
      return calories;
    } catch (e) {
      final localCalories = foodsForSelectedDate.fold(
        0,
        (sum, food) => sum + food.calories,
      );
      _cachedCaloriesByDate[dateStr] = localCalories;
      return localCalories;
    }
  }
}
