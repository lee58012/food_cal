import 'dart:io';
import 'package:flutter/material.dart';
import 'package:hoseo/models/food.dart';
import 'package:hoseo/utils/database_helper.dart';
import 'package:hoseo/utils/firestore_service.dart';
import 'package:intl/intl.dart';
import 'package:firebase_auth/firebase_auth.dart' as auth;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:cloud_firestore/cloud_firestore.dart';

class FoodProvider with ChangeNotifier {
  List<Food> _foods = [];
  DateTime _selectedDate = DateTime.now();
  final FirestoreService _firestoreService = FirestoreService();
  final auth.FirebaseAuth _auth = auth.FirebaseAuth.instance;
  bool _isLoading = false;
  bool _isDisposed = false; // dispose 상태 추적

  // 캐싱을 위한 변수들
  final Map<String, List<Food>> _cachedFoodsByDate = {};
  final Map<String, int> _cachedCaloriesByDate = {};
  final Map<int, String> _localToFirestoreIdMap = {};
  bool _isInitialized = false;

  List<Food> get foods => _foods;
  DateTime get selectedDate => _selectedDate;
  bool get isLoading => _isLoading;

  @override
  void dispose() {
    _isDisposed = true;
    super.dispose();
  }

  // 안전한 notifyListeners 호출
  void _safeNotifyListeners() {
    if (!_isDisposed) {
      notifyListeners();
    }
  }

  // FoodProvider의 getter 메서드들에 안전장치 추가
  List<Food> get foodsForSelectedDate {
    if (_isDisposed) return [];

    final dateFormat = DateFormat('yyyy-MM-dd');
    final selectedDateStr = dateFormat.format(_selectedDate);

    if (_cachedFoodsByDate.containsKey(selectedDateStr)) {
      final cachedList = _cachedFoodsByDate[selectedDateStr] ?? [];
      print('캐시에서 음식 데이터 가져옴: $selectedDateStr, 개수: ${cachedList.length}');
      return List.from(cachedList); // 복사본 반환으로 안전성 확보
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
    if (_isDisposed) return 0.0;

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
    if (_isDisposed) return 0.0;
    return foodsForSelectedDate.fold(0.0, (sum, food) => sum + food.carbs);
  }

  // 선택한 날짜의 총 단백질
  double get totalProteinForSelectedDate {
    if (_isDisposed) return 0.0;
    return foodsForSelectedDate.fold(0.0, (sum, food) => sum + food.protein);
  }

  // 선택한 날짜의 총 지방
  double get totalFatForSelectedDate {
    if (_isDisposed) return 0.0;
    return foodsForSelectedDate.fold(0.0, (sum, food) => sum + food.fat);
  }

  // 선택한 날짜의 총 나트륨
  double get totalSodiumForSelectedDate {
    if (_isDisposed) return 0.0;
    return foodsForSelectedDate.fold(0.0, (sum, food) => sum + food.sodium);
  }

  // 선택한 날짜의 총 콜레스테롤
  double get totalCholesterolForSelectedDate {
    if (_isDisposed) return 0.0;
    return foodsForSelectedDate.fold(
      0.0,
      (sum, food) => sum + food.cholesterol,
    );
  }

  // 선택한 날짜의 총 당류
  double get totalSugarForSelectedDate {
    if (_isDisposed) return 0.0;
    return foodsForSelectedDate.fold(0.0, (sum, food) => sum + food.sugar);
  }

  // 날짜 선택 및 해당 날짜의 음식 데이터 로드
  Future<void> selectDate(DateTime date) async {
    if (_isDisposed) return;

    // 이전 날짜와 동일하면 불필요한 로드 방지
    if (DateFormat('yyyy-MM-dd').format(_selectedDate) ==
        DateFormat('yyyy-MM-dd').format(date)) {
      return;
    }

    _selectedDate = date;

    // 날짜 변경 시 해당 날짜의 식단 데이터 로드
    await loadFoodsByDate(date);

    // 데이터 로드 완료 후 UI 업데이트
    _safeNotifyListeners();
  }

  // 초기 데이터 로드 및 초기화
  Future<void> initialize() async {
    if (_isInitialized || _isDisposed) return;

    await loadFoods();
    if (!_isDisposed) {
      _isInitialized = true;
    }
  }

  // 모든 음식 로드 (Firestore 사용)
  Future<void> loadFoods() async {
    if (_isDisposed) return;

    final currentUser = _auth.currentUser;
    if (currentUser == null) return;

    _isLoading = true;
    _safeNotifyListeners();

    try {
      print('Firestore에서 전체 음식 데이터 로드 시작');

      final snapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(currentUser.uid)
          .collection('foods')
          .orderBy('dateTime', descending: true)
          .get();

      if (_isDisposed) return; // 작업 중 dispose 확인

      _foods.clear();
      _localToFirestoreIdMap.clear();

      for (var doc in snapshot.docs) {
        if (_isDisposed) return; // 루프 중 dispose 확인

        final data = doc.data();
        final localId = doc.id.hashCode.abs();

        final food = Food(
          food_id: localId,
          food_name: data['food_name'] ?? data['name'] ?? '',
          calories: data['calories'] ?? 0,
          carbs: (data['carbs'] ?? 0).toDouble(),
          protein: (data['protein'] ?? 0).toDouble(),
          fat: (data['fat'] ?? 0).toDouble(),
          sodium: (data['sodium'] ?? 0).toDouble(),
          cholesterol: (data['cholesterol'] ?? 0).toDouble(),
          sugar: (data['sugar'] ?? 0).toDouble(),
          imageUrl: data['imageUrl'],
          dateTime: DateTime.parse(data['dateTime']),
        );

        _foods.add(food);
        _localToFirestoreIdMap[localId] = doc.id;
      }

      if (_isDisposed) return;

      print('Firestore에서 가져온 전체 음식 데이터 수: ${_foods.length}');

      _clearCache();
      _updateCacheFromLocalData();

      final dateFormat = DateFormat('yyyy-MM-dd');
      final selectedDateStr = dateFormat.format(_selectedDate);
      final filteredFoods = _foods.where((food) {
        final foodDateStr = dateFormat.format(food.dateTime);
        return foodDateStr == selectedDateStr;
      }).toList();
      _cachedFoodsByDate[selectedDateStr] = filteredFoods;
      print('현재 선택된 날짜($selectedDateStr)의 데이터 수: ${filteredFoods.length}');
    } catch (e) {
      print('Firestore 데이터 로드 오류: $e');
      if (!_isDisposed) {
        _foods = [];
        _clearCache();
      }
    } finally {
      if (!_isDisposed) {
        _isLoading = false;
        _safeNotifyListeners();
      }
    }
  }

  // 특정 날짜의 음식 데이터 로드
  Future<void> loadFoodsByDate(DateTime date) async {
    if (_isDisposed) return;

    final dateFormat = DateFormat('yyyy-MM-dd');
    final dateStr = dateFormat.format(date);

    // 이미 캐시된 데이터가 있으면 사용
    if (_cachedFoodsByDate.containsKey(dateStr)) {
      print(
        '캐시된 데이터 사용: $dateStr, 개수: ${_cachedFoodsByDate[dateStr]?.length ?? 0}',
      );
      return;
    }

    // 전체 데이터에서 필터링하여 캐시 업데이트
    final filteredFoods = _foods.where((food) {
      final foodDateStr = dateFormat.format(food.dateTime);
      return foodDateStr == dateStr;
    }).toList();

    _cachedFoodsByDate[dateStr] = filteredFoods;

    // 칼로리 캐시도 업데이트
    final totalCalories = filteredFoods.fold(
      0,
      (sum, food) => sum + food.calories,
    );
    _cachedCaloriesByDate[dateStr] = totalCalories;

    print('날짜별 데이터 캐싱 완료: $dateStr, 개수: ${filteredFoods.length}');
  }

  // 캐시 초기화
  void _clearCache() {
    _cachedFoodsByDate.clear();
    _cachedCaloriesByDate.clear();
  }

  // 로컬 데이터로 캐시 업데이트
  void _updateCacheFromLocalData() {
    if (_isDisposed) return;

    final dateFormat = DateFormat('yyyy-MM-dd');
    _clearCache();

    print('로컬 데이터로 캐시 업데이트 시작: ${_foods.length}개 음식');

    // 날짜별로 음식 분류
    for (var food in _foods) {
      if (_isDisposed) return;

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

  // 음식 추가 - 안전한 버전
  Future<void> addFood(Food food) async {
    if (_isDisposed) return;

    final currentUser = _auth.currentUser;
    if (currentUser == null) {
      throw Exception('사용자가 로그인되지 않았습니다.');
    }

    _isLoading = true;
    _safeNotifyListeners();

    try {
      // Firestore에 먼저 저장하여 문서 ID 획득
      final docRef = FirebaseFirestore.instance
          .collection('users')
          .doc(currentUser.uid)
          .collection('foods')
          .doc();

      if (_isDisposed) return;

      final firestoreId = docRef.id;
      final localId = firestoreId.hashCode.abs();

      await docRef.set({
        'food_name': food.food_name,
        'calories': food.calories,
        'carbs': food.carbs,
        'protein': food.protein,
        'fat': food.fat,
        'sodium': food.sodium,
        'cholesterol': food.cholesterol,
        'sugar': food.sugar,
        'imageUrl': food.imageUrl,
        'dateTime': food.dateTime.toIso8601String(),
        'createdAt': FieldValue.serverTimestamp(),
      });

      if (_isDisposed) return;

      print('Firestore에 음식 저장 완료: $firestoreId');

      _localToFirestoreIdMap[localId] = firestoreId;

      final newFood = Food(
        food_id: localId,
        food_name: food.food_name,
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

      // 웹 환경이 아닐 때만 로컬 DB에 저장
      if (!kIsWeb && !_isDisposed) {
        final dbHelper = DatabaseHelper();
        final foodMap = newFood.toMap();
        foodMap.remove('firestore_id');
        await dbHelper.insertFood(foodMap);
        print('로컬 DB에 저장 완료: $localId');
      }

      if (_isDisposed) return;

      _foods.add(newFood);

      // 일일 칼로리 업데이트
      final dateFormat = DateFormat('yyyy-MM-dd');
      final dateStr = dateFormat.format(food.dateTime);

      final calorieDocRef = FirebaseFirestore.instance
          .collection('users')
          .doc(currentUser.uid)
          .collection('dailyCalories')
          .doc(dateStr);

      final calorieDoc = await calorieDocRef.get();

      if (_isDisposed) return;

      if (calorieDoc.exists) {
        final currentCalories = calorieDoc.data()?['calories'] ?? 0;
        await calorieDocRef.update({
          'calories': currentCalories + food.calories,
          'updatedAt': FieldValue.serverTimestamp(),
        });
      } else {
        await calorieDocRef.set({
          'date': dateStr,
          'calories': food.calories,
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }

      if (_isDisposed) return;

      // 캐시 업데이트
      if (!_cachedFoodsByDate.containsKey(dateStr)) {
        _cachedFoodsByDate[dateStr] = [];
      }
      _cachedFoodsByDate[dateStr]!.add(newFood);

      final currentCachedCalories = _cachedCaloriesByDate[dateStr] ?? 0;
      _cachedCaloriesByDate[dateStr] = currentCachedCalories + food.calories;

      print('음식 추가 완료: ${newFood.food_name}');
    } catch (e) {
      print('음식 추가 오류: $e');
      rethrow;
    } finally {
      if (!_isDisposed) {
        _isLoading = false;
        _safeNotifyListeners();
      }
    }
  }

  // 음식 삭제 - 안전한 인덱스 처리
  Future<void> deleteFood(int localId) async {
    if (_isDisposed) return;

    final currentUser = _auth.currentUser;
    if (currentUser == null) return;

    _isLoading = true;
    _safeNotifyListeners();

    try {
      // 삭제할 음식 찾기 - 안전한 인덱스 확인
      final foodIndex = _foods.indexWhere((food) => food.food_id == localId);
      if (foodIndex == -1 || foodIndex >= _foods.length) {
        print(
          '삭제할 음식을 찾을 수 없거나 잘못된 인덱스: $localId, 인덱스: $foodIndex, 리스트 크기: ${_foods.length}',
        );
        return;
      }

      final food = _foods[foodIndex];
      final dateFormat = DateFormat('yyyy-MM-dd');
      final dateStr = dateFormat.format(food.dateTime);

      print('삭제할 음식: ${food.food_name}, 로컬 ID: $localId, 인덱스: $foodIndex');

      // Firestore 문서 ID 찾기
      final firestoreId = _localToFirestoreIdMap[localId];
      if (firestoreId == null) {
        print('Firestore 문서 ID를 찾을 수 없습니다: $localId');
        return;
      }

      // 웹 환경이 아닐 때만 로컬 DB에서 삭제
      if (!kIsWeb && !_isDisposed) {
        final dbHelper = DatabaseHelper();
        await dbHelper.deleteFood(localId);
        print('로컬 DB에서 삭제 완료: $localId');
      }

      if (_isDisposed) return;

      // Firestore에서 삭제
      await FirebaseFirestore.instance
          .collection('users')
          .doc(currentUser.uid)
          .collection('foods')
          .doc(firestoreId)
          .delete();

      print('Firestore에서 음식 삭제: $firestoreId');

      if (_isDisposed) return;

      // 일일 칼로리 업데이트
      final calorieDocRef = FirebaseFirestore.instance
          .collection('users')
          .doc(currentUser.uid)
          .collection('dailyCalories')
          .doc(dateStr);

      final calorieDoc = await calorieDocRef.get();
      if (calorieDoc.exists) {
        final currentCalories = calorieDoc.data()?['calories'] ?? 0;
        final newCalories = (currentCalories - food.calories)
            .clamp(0, double.infinity)
            .toInt();
        await calorieDocRef.update({
          'calories': newCalories,
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }

      if (_isDisposed) return;

      // 메모리에서 안전하게 삭제
      if (foodIndex < _foods.length) {
        _foods.removeAt(foodIndex);
        _localToFirestoreIdMap.remove(localId);
        print('메모리에서 삭제 완료: ${_foods.length}개 남음');
      }

      // 캐시에서 안전하게 삭제
      if (_cachedFoodsByDate.containsKey(dateStr)) {
        final cachedList = _cachedFoodsByDate[dateStr]!;
        final cacheIndex = cachedList.indexWhere((f) => f.food_id == localId);

        if (cacheIndex != -1 && cacheIndex < cachedList.length) {
          cachedList.removeAt(cacheIndex);
          print('캐시에서 삭제 완료: ${cachedList.length}개 남음');
        }

        // 칼로리 캐시 업데이트
        final currentCachedCalories = _cachedCaloriesByDate[dateStr] ?? 0;
        _cachedCaloriesByDate[dateStr] = (currentCachedCalories - food.calories)
            .clamp(0, double.infinity)
            .toInt();
      }

      print('음식 삭제 완료: ${food.food_name}');
    } catch (e) {
      print('음식 삭제 오류: $e');
      // 오류 발생 시에도 UI 상태는 정상적으로 복구
      if (!_isDisposed) {
        await loadFoods(); // 전체 데이터 다시 로드
      }
    } finally {
      if (!_isDisposed) {
        _isLoading = false;
        _safeNotifyListeners();
      }
    }
  }

  // 이미지 분석
  Future<Map<String, dynamic>> analyzeFoodImage(File image) async {
    if (_isDisposed) throw Exception('Provider가 dispose되었습니다.');

    return await _firestoreService.analyzeFoodImage(
      _auth.currentUser?.uid ?? '',
      image,
    );
  }

  // 이미지 업로드
  Future<String?> uploadFoodImage(File image) async {
    if (_isDisposed) throw Exception('Provider가 dispose되었습니다.');

    return await _firestoreService.uploadFoodImage(
      _auth.currentUser?.uid ?? '',
      image,
    );
  }
}
