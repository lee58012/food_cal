// ignore_for_file: unused_import

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' as auth;
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:hoseo/models/food.dart';
import 'package:hoseo/utils/database_helper.dart';
import 'package:hoseo/utils/firestore_service.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';

class FoodProvider with ChangeNotifier {
  List<Food> _foods = [];
  DateTime _selectedDate = DateTime.now();
  final FirestoreService _firestoreService = FirestoreService();
  final auth.FirebaseAuth _auth = auth.FirebaseAuth.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;
  final String _apiBaseUrl = 'https://api.example.com'; // API 서버 URL
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

      // 웹 환경이 아닐 때만 로컬 DB 동기화 수행
      if (!kIsWeb) {
        // 로컬 DB와 동기화 - 중복 확인 로직 추가
        final dbHelper = DatabaseHelper();

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

        // 로컬 DB에서 최신 데이터 다시 로드
        final foodsData = await dbHelper.getFoods();
        _foods = foodsData.map((map) => Food.fromMap(map)).toList();
      } else {}

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

  // 데이터 강제 새로고침
  Future<void> refreshData() async {
    final dateFormat = DateFormat('yyyy-MM-dd');
    final selectedDateStr = dateFormat.format(_selectedDate);

    // 선택된 날짜의 캐시 삭제
    _cachedFoodsByDate.remove(selectedDateStr);
    _cachedCaloriesByDate.remove(selectedDateStr);

    // 데이터 다시 로드
    await loadFoodsByDate(_selectedDate);

    // UI 갱신
    notifyListeners();
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

    // 캐시된 날짜 및 데이터 수 로그
    _cachedFoodsByDate.forEach((date, foods) {});
  }

  // 음식 추가 - 성능 최적화
  Future<void> addFood(Food food) async {
    final currentUser = _auth.currentUser;
    if (currentUser == null) return;

    _isLoading = true;
    notifyListeners();

    try {
      // 메모리 캐시에 먼저 추가 (UI 즉시 업데이트)
      final tempFood = Food(
        id: DateTime.now().millisecondsSinceEpoch.toString(), // 임시 ID
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

      _foods.add(tempFood);

      // 캐시 업데이트 (UI 즉시 업데이트)
      final dateFormat = DateFormat('yyyy-MM-dd');
      final foodDateStr = dateFormat.format(food.dateTime);
      final selectedDateStr = dateFormat.format(_selectedDate);

      if (foodDateStr == selectedDateStr) {
        // 캐시가 있으면 업데이트
        if (_cachedFoodsByDate.containsKey(selectedDateStr)) {
          _cachedFoodsByDate[selectedDateStr]!.add(tempFood);
        } else {
          _cachedFoodsByDate[selectedDateStr] = [tempFood];
        }

        // 칼로리 캐시 업데이트
        _cachedCaloriesByDate[selectedDateStr] =
            (_cachedCaloriesByDate[selectedDateStr] ?? 0) + food.calories;
      }

      // UI 업데이트를 위해 로딩 상태 해제
      _isLoading = false;
      notifyListeners();

      // 백그라운드에서 Firestore 저장 및 로컬 DB 저장
      // Firestore에 저장하고 문서 ID 받기
      final docId = await _firestoreService.addFood(currentUser.uid, food);

      // 로컬 DB에도 저장 (웹이 아닌 경우)
      if (!kIsWeb) {
        final dbHelper = DatabaseHelper();
        final foodMap = food.toMap();
        // Firestore 문서 ID 추가
        foodMap['firestore_id'] = docId;
        await dbHelper.insertFood(foodMap);
      }

      // 임시 ID를 실제 ID로 교체
      final index = _foods.indexWhere((f) => f.id == tempFood.id);
      if (index != -1) {
        final updatedFood = Food(
          id: docId,
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

        _foods[index] = updatedFood;

        // 캐시도 업데이트
        if (foodDateStr == selectedDateStr &&
            _cachedFoodsByDate.containsKey(selectedDateStr)) {
          final cacheIndex = _cachedFoodsByDate[selectedDateStr]!.indexWhere(
            (f) => f.id == tempFood.id,
          );
          if (cacheIndex != -1) {
            _cachedFoodsByDate[selectedDateStr]![cacheIndex] = updatedFood;
          }
        }
      }
    } catch (e) {
      print('음식 추가 오류: $e');
      // 오류 발생 시 UI 업데이트
      _isLoading = false;
      notifyListeners();
    }
  }

  // 음식 삭제 - 성능 최적화
  Future<void> deleteFood(dynamic id) async {
    final currentUser = _auth.currentUser;
    if (currentUser == null) return;

    try {
      // 삭제할 음식 찾기
      final foodIndex = _foods.indexWhere((food) => food.id == id);
      if (foodIndex == -1) return; // 음식을 찾을 수 없음

      final food = _foods[foodIndex];
      final dateTime = food.dateTime;
      final dateFormat = DateFormat('yyyy-MM-dd');
      final dateStr = dateFormat.format(dateTime);

      // 1. 먼저 메모리와 캐시에서 제거 (UI 즉시 업데이트)
      _foods.removeAt(foodIndex);

      // 캐시 업데이트
      if (_cachedFoodsByDate.containsKey(dateStr)) {
        _cachedFoodsByDate[dateStr]!.removeWhere((f) => f.id == id);

        // 칼로리 캐시에서 삭제된 음식의 칼로리 빼기
        final currentCachedCalories = _cachedCaloriesByDate[dateStr] ?? 0;
        _cachedCaloriesByDate[dateStr] = (currentCachedCalories - food.calories)
            .clamp(0, double.infinity)
            .toInt();
      }

      // UI 즉시 업데이트
      notifyListeners();

      // 2. 백그라운드에서 Firestore와 로컬 DB에서 삭제
      // 웹 환경이 아닐 때만 로컬 DB에서 삭제
      if (!kIsWeb && id is int) {
        final dbHelper = DatabaseHelper();
        await dbHelper.deleteFood(id);
      }

      // Firestore에서 삭제 (이미지도 함께 삭제)
      await _firestoreService.deleteFood(
        currentUser.uid,
        id, // ID를 그대로 전달
        food.calories,
        food.dateTime,
        food.imageUrl, // 이미지 URL 전달
      );
    } catch (e) {
      print('음식 삭제 오류: $e');
      // 오류 발생 시 데이터 다시 로드
      await loadFoodsByDate(_selectedDate);
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

      // 기존 해당 날짜 음식들을 메모리에서 제거
      _foods.removeWhere((food) {
        final foodDateStr = dateFormat.format(food.dateTime);
        return foodDateStr == dateStr;
      });

      // 새로운 음식들 추가
      _foods.addAll(foodsForDate);

      // 캐시 업데이트
      _cachedFoodsByDate[dateStr] = List<Food>.from(foodsForDate);

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
        for (var food in foodsForDate) {
          // 중복 확인 로직은 insertFood 메서드 내에서 처리
          await dbHelper.insertFood(food.toMap());
        }
      } else {}
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

          _cachedFoodsByDate[dateStr] = List<Food>.from(localFoods);
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

  // 음식 이미지 분석 - XFile 지원
  Future<Map<String, dynamic>?> analyzeFoodImage(XFile imageFile) async {
    try {
      final bytes = await imageFile.readAsBytes();

      // 이미지 분석 API 호출
      final response = await http.post(
        Uri.parse('$_apiBaseUrl/analyze-food'),
        headers: {'Content-Type': 'application/octet-stream'},
        body: bytes,
      );

      if (response.statusCode == 200) {
        final result = jsonDecode(response.body);
        return result;
      } else {
        print('API 오류: ${response.statusCode}, ${response.body}');
        return null;
      }
    } catch (e) {
      print('음식 이미지 분석 오류: $e');
      return null;
    }
  }

  // 음식 이미지 업로드 - XFile 지원
  Future<String?> uploadFoodImage(XFile imageFile) async {
    final currentUser = _auth.currentUser;
    if (currentUser == null) return null;

    try {
      final file = File(imageFile.path);
      final fileName =
          '${currentUser.uid}_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final ref = _storage.ref().child('food_images/$fileName');

      // 이미지 업로드
      final uploadTask = ref.putFile(
        file,
        SettableMetadata(contentType: 'image/jpeg'),
      );

      // 업로드 완료 대기
      final snapshot = await uploadTask;

      // 다운로드 URL 가져오기
      final downloadUrl = await snapshot.ref.getDownloadURL();
      return downloadUrl;
    } catch (e) {
      print('이미지 업로드 오류: $e');
      return null;
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
