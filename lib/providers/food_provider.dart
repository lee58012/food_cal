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
import 'package:flutter/foundation.dart' show kIsWeb;

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
      print(
        '캐시에서 음식 데이터 가져옴: $selectedDateStr, 개수: ${_cachedFoodsByDate[selectedDateStr]?.length ?? 0}',
      );
      return _cachedFoodsByDate[selectedDateStr] ?? [];
    }

    // 캐시된 데이터가 없으면 필터링
    final filteredFoods = _foods.where((food) {
      final foodDateStr = dateFormat.format(food.dateTime);
      return foodDateStr == selectedDateStr;
    }).toList();

    // 결과 캐싱
    _cachedFoodsByDate[selectedDateStr] = filteredFoods;
    print('필터링된 음식 데이터 캐싱: $selectedDateStr, 개수: ${filteredFoods.length}');
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
      print('Firestore에서 전체 음식 데이터 로드 시작');
      _foods = await _firestoreService.getFoods(currentUser.uid);
      print('Firestore에서 가져온 전체 음식 데이터 수: ${_foods.length}');

      // 캐시 초기화
      _clearCache();

      // 웹 환경이 아닐 때만 로컬 DB 동기화 수행
      if (!kIsWeb) {
        // 로컬 DB와 동기화 - 중복 확인 로직 추가
        final dbHelper = DatabaseHelper();
        print('로컬 DB와 전체 데이터 동기화 시작: ${_foods.length}개 음식');

        // 업데이트된 음식 객체를 저장할 새 리스트
        List<Food> updatedFoods = [];

        // 기존 데이터를 모두 삭제하지 않고, 각 음식별로 중복 여부 확인 후 삽입
        for (var food in _foods) {
          final foodMap = food.toMap();
          // 중복 확인 로직은 insertFood 메서드 내에서 처리
          final id = await dbHelper.insertFood(foodMap);

          // 업데이트된 ID로 새 Food 객체 생성하여 리스트에 추가
          updatedFoods.add(
            Food(
              id: id,
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
            ),
          );
        }

        // 업데이트된 리스트로 교체
        _foods = updatedFoods;

        print('로컬 DB 동기화 완료');

        // 로컬 DB에서 최신 데이터 다시 로드
        final foodsData = await dbHelper.getFoods();
        _foods = foodsData.map((map) => Food.fromMap(map)).toList();
        print('로컬 DB에서 다시 로드한 데이터 수: ${_foods.length}');
      } else {
        print('웹 환경에서는 로컬 DB 동기화를 건너뜁니다.');
      }

      // 날짜별로 캐시 업데이트
      _updateCacheFromLocalData();

      // 현재 선택된 날짜의 데이터도 캐시에 추가
      final dateFormat = DateFormat('yyyy-MM-dd');
      final selectedDateStr = dateFormat.format(_selectedDate);
      final filteredFoods = _foods.where((food) {
        final foodDateStr = dateFormat.format(food.dateTime);
        return foodDateStr == selectedDateStr;
      }).toList();
      _cachedFoodsByDate[selectedDateStr] = filteredFoods;
      print('현재 선택된 날짜($selectedDateStr)의 데이터 수: ${filteredFoods.length}');
    } catch (e) {
      // 오류 발생 시 로컬 DB에서 로드 시도
      print('Firestore 데이터 로드 오류: $e');
      try {
        final dbHelper = DatabaseHelper();
        final foodsData = await dbHelper.getFoods();
        _foods = foodsData.map((map) => Food.fromMap(map)).toList();
        print('로컬 DB에서 가져온 데이터 수: ${_foods.length}');

        // 로컬 데이터로 캐시 업데이트
        _updateCacheFromLocalData();
      } catch (dbError) {
        print('로컬 DB 로드 오류: $dbError');
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

    print('로컬 데이터로 캐시 업데이트 시작: ${_foods.length}개 음식');

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

    // 캐시된 날짜 및 데이터 수 로그
    _cachedFoodsByDate.forEach((date, foods) {
      print('캐시된 날짜: $date, 음식 수: ${foods.length}');
    });

    print('캐시 업데이트 완료: ${_cachedFoodsByDate.length}개 날짜');
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
      // 1. 웹 환경이 아닐 때만 로컬 DB에 저장
      int localId = 0;
      if (!kIsWeb) {
        // 로컬 DB에 저장하여 ID 생성 (중복 확인 로직 포함)
        final dbHelper = DatabaseHelper();
        localId = await dbHelper.insertFood(food.toMap());
      } else {
        // 웹 환경에서는 임시 ID 생성
        localId = DateTime.now().millisecondsSinceEpoch;
        print('웹 환경에서는 로컬 DB 저장을 건너뜁니다. 임시 ID: $localId');
      }

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

      // 1. 웹 환경이 아닐 때만 로컬 DB에서 삭제
      if (!kIsWeb) {
        final dbHelper = DatabaseHelper();
        await dbHelper.deleteFood(id);
      } else {
        print('웹 환경에서는 로컬 DB 삭제를 건너뜁니다.');
      }

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
      print('음식 삭제 오류: $e');
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
    print('특정 날짜($dateStr) 음식 데이터 로드 시작...');

    try {
      final foodsForDate = await _firestoreService.getFoodsByDate(
        currentUser.uid,
        date,
      );

      print('Firestore에서 가져온 음식 데이터 수: ${foodsForDate.length}');

      // 기존 해당 날짜 음식들을 메모리에서 제거
      _foods.removeWhere((food) {
        final foodDateStr = dateFormat.format(food.dateTime);
        return foodDateStr == dateStr;
      });

      // 새로운 음식들 추가
      _foods.addAll(foodsForDate);

      // 캐시 업데이트
      _cachedFoodsByDate[dateStr] = List<Food>.from(foodsForDate);
      print(
        '캐시 업데이트 완료: $dateStr, 개수: ${_cachedFoodsByDate[dateStr]?.length ?? 0}',
      );

      // 칼로리 다시 계산
      final totalCalories = foodsForDate.fold(
        0,
        (sum, food) => sum + food.calories,
      );
      _cachedCaloriesByDate[dateStr] = totalCalories;

      // 웹 환경이 아닐 때만 로컬 DB 동기화 수행
      if (!kIsWeb) {
        // 로컬 DB 동기화 - 삭제 대신 중복 확인 후 삽입
        final dbHelper = DatabaseHelper();

        // 날짜별 삭제를 하지 않고 개별 음식마다 중복 확인
        print('로컬 DB와 동기화 시작: ${foodsForDate.length}개 음식');
        for (var food in foodsForDate) {
          // 중복 확인 로직은 insertFood 메서드 내에서 처리
          await dbHelper.insertFood(food.toMap());
        }
        print('로컬 DB 동기화 완료');
      } else {
        print('웹 환경에서는 로컬 DB 동기화를 건너뜁니다.');
      }

      print('특정 날짜($dateStr) 음식 데이터 로드 및 캐시 완료: ${foodsForDate.length}개');
    } catch (e) {
      print('특정 날짜 음식 데이터 로드 오류: $e');
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

          _cachedFoodsByDate[dateStr] = List<Food>.from(localFoods);
          _cachedCaloriesByDate[dateStr] = localFoods.fold(
            0,
            (sum, food) => sum + food.calories,
          );

          print('로컬 DB에서 가져온 음식 데이터: ${localFoods.length}개');
        } else {
          _cachedFoodsByDate[dateStr] = [];
          _cachedCaloriesByDate[dateStr] = 0;
          print('로컬 DB에 음식 데이터 없음');
        }
      } catch (dbError) {
        _cachedFoodsByDate[dateStr] = [];
        _cachedCaloriesByDate[dateStr] = 0;
        print('로컬 DB 조회 오류: $dbError');
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
