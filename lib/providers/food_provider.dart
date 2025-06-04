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

  List<Food> get foods => _foods;
  DateTime get selectedDate => _selectedDate;
  bool get isLoading => _isLoading;

  // 선택한 날짜의 음식만 필터링
  List<Food> get foodsForSelectedDate {
    final dateFormat = DateFormat('yyyy-MM-dd');
    final selectedDateStr = dateFormat.format(_selectedDate);

    return _foods.where((food) {
      final foodDateStr = dateFormat.format(food.dateTime);
      return foodDateStr == selectedDateStr;
    }).toList();
  }

  // 선택한 날짜의 총 칼로리
  int get totalCaloriesForSelectedDate {
    return foodsForSelectedDate.fold(0, (sum, food) => sum + food.calories);
  }

  // 선택한 날짜의 총 탄수화물
  double get totalCarbsForSelectedDate {
    return foodsForSelectedDate.fold(0, (sum, food) => sum + food.carbs);
  }

  // 선택한 날짜의 총 단백질
  double get totalProteinForSelectedDate {
    return foodsForSelectedDate.fold(0, (sum, food) => sum + food.protein);
  }

  // 선택한 날짜의 총 지방
  double get totalFatForSelectedDate {
    return foodsForSelectedDate.fold(0, (sum, food) => sum + food.fat);
  }

  // 날짜 선택
  void selectDate(DateTime date) {
    _selectedDate = date;
    notifyListeners();
  }

  // 모든 음식 로드 (Firestore 사용)
  Future<void> loadFoods() async {
    final currentUser = _auth.currentUser;
    if (currentUser == null) return;

    _isLoading = true;
    notifyListeners();

    try {
      // Firestore에서 음식 데이터 로드
      _foods = await _firestoreService.getFoods(currentUser.uid);

      // 로컬 DB와 동기화 (필요한 경우)
      final dbHelper = DatabaseHelper();
      await dbHelper.clearFoods(); // 기존 데이터 삭제

      for (var food in _foods) {
        await dbHelper.insertFood(food.toMap());
      }
    } catch (e) {
      print('음식 데이터 로드 오류: $e');

      // 오류 발생 시 로컬 DB에서 로드 시도
      final dbHelper = DatabaseHelper();
      final foodsData = await dbHelper.getFoods();
      _foods = foodsData.map((map) => Food.fromMap(map)).toList();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // 음식 추가 (Firestore 사용)
  Future<void> addFood(Food food) async {
    final currentUser = _auth.currentUser;
    if (currentUser == null) return;

    _isLoading = true;
    notifyListeners();

    try {
      // 이미지가 있는 경우 Firebase Storage에 업로드
      String? imageUrl = food.imageUrl;

      // Firestore에 음식 데이터 저장
      final foodId = await _firestoreService.addFood(currentUser.uid, food);

      // 로컬 DB에도 저장
      final dbHelper = DatabaseHelper();
      final id = await dbHelper.insertFood(food.toMap());

      final newFood = Food(
        id: id,
        name: food.name,
        calories: food.calories,
        carbs: food.carbs,
        protein: food.protein,
        fat: food.fat,
        imageUrl: imageUrl,
        dateTime: food.dateTime,
      );

      _foods.add(newFood);
    } catch (e) {
      print('음식 추가 오류: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // 음식 삭제 (Firestore 사용)
  Future<void> deleteFood(int id) async {
    final currentUser = _auth.currentUser;
    if (currentUser == null) return;

    _isLoading = true;
    notifyListeners();

    try {
      // 삭제할 음식 찾기
      final food = _foods.firstWhere((food) => food.id == id);

      // Firestore에서 삭제
      await _firestoreService.deleteFood(
        currentUser.uid,
        id.toString(),
        food.calories,
        food.dateTime,
      );

      // 로컬 DB에서도 삭제
      final dbHelper = DatabaseHelper();
      await dbHelper.deleteFood(id);

      _foods.removeWhere((food) => food.id == id);
    } catch (e) {
      print('음식 삭제 오류: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // 이미지 업로드 (Base64 인코딩으로 변경)
  Future<String?> uploadFoodImage(File imageFile) async {
    final currentUser = _auth.currentUser;
    if (currentUser == null) return null;

    try {
      // 이미지 파일을 바이트로 읽기
      final bytes = await imageFile.readAsBytes();

      // 이미지 크기 확인 (1MB 제한)
      if (bytes.length > 1024 * 1024) {
        print('이미지 크기가 너무 큽니다: ${bytes.length} bytes');
        return null;
      }

      // 바이트를 Base64 문자열로 인코딩
      final base64String = base64Encode(bytes);

      // Base64 문자열 앞에 데이터 형식 추가
      final dataUrl = 'data:image/jpeg;base64,$base64String';

      print('음식 이미지 인코딩 완료: ${dataUrl.length} 문자');
      return dataUrl;
    } catch (e) {
      print('이미지 인코딩 오류: $e');
      return null;
    }
  }

  // 사진에서 음식 인식 및 분석 (서버에 요청하는 부분)
  Future<Map<String, dynamic>> analyzeFoodImage(File imageFile) async {
    _isLoading = true;
    notifyListeners();

    try {
      // 이미지 업로드
      final imageUrl = await uploadFoodImage(imageFile);

      // 실제 서버 통신 구현
      // 여기서는 테스트를 위해 가상의 데이터를 반환
      await Future.delayed(const Duration(seconds: 2)); // 분석 시간 시뮬레이션

      return {
        'name': '비빔밥',
        'calories': 560,
        'carbs': 82.5,
        'protein': 15.3,
        'fat': 12.8,
        'imageUrl': imageUrl,
      };
    } catch (e) {
      print('음식 분석 오류: $e');
      return {
        'name': '알 수 없는 음식',
        'calories': 0,
        'carbs': 0.0,
        'protein': 0.0,
        'fat': 0.0,
      };
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // 특정 날짜의 칼로리 섭취량 가져오기
  Future<int> getDailyCalorieIntake(DateTime date) async {
    final currentUser = _auth.currentUser;
    if (currentUser == null) return 0;

    try {
      return await _firestoreService.getDailyCalorieIntake(
        currentUser.uid,
        date,
      );
    } catch (e) {
      print('칼로리 섭취량 조회 오류: $e');
      return totalCaloriesForSelectedDate; // 로컬 데이터로 대체
    }
  }
}
