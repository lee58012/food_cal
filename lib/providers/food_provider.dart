import 'dart:io';
import 'package:flutter/material.dart';
import 'package:hoseo/models/food.dart';
import 'package:hoseo/utils/database_helper.dart';
import 'package:intl/intl.dart';

class FoodProvider with ChangeNotifier {
  List<Food> _foods = [];
  DateTime _selectedDate = DateTime.now();

  List<Food> get foods => _foods;
  DateTime get selectedDate => _selectedDate;

  // 선택한 날짜의 음식만 필터링
  List<Food> get foodsForSelectedDate {
    return _foods.where((food) {
      return DateFormat('yyyy-MM-dd').format(food.dateTime) ==
          DateFormat('yyyy-MM-dd').format(_selectedDate);
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

  // 모든 음식 로드
  Future<void> loadFoods() async {
    final dbHelper = DatabaseHelper();
    final foodsData = await dbHelper.getFoods();
    _foods = foodsData.map((map) => Food.fromMap(map)).toList();
    notifyListeners();
  }

  // 음식 추가
  Future<void> addFood(Food food) async {
    final dbHelper = DatabaseHelper();
    final id = await dbHelper.insertFood(food.toMap());

    final newFood = Food(
      id: id,
      name: food.name,
      calories: food.calories,
      carbs: food.carbs,
      protein: food.protein,
      fat: food.fat,
      imageUrl: food.imageUrl,
      dateTime: food.dateTime,
    );

    _foods.add(newFood);
    notifyListeners();
  }

  // 음식 삭제
  Future<void> deleteFood(int id) async {
    final dbHelper = DatabaseHelper();
    await dbHelper.deleteFood(id);

    _foods.removeWhere((food) => food.id == id);
    notifyListeners();
  }

  // 사진에서 음식 인식 및 분석 (서버에 요청하는 부분)
  Future<Map<String, dynamic>> analyzeFoodImage(File imageFile) async {
    // TODO: 실제 서버 통신 구현
    // 여기서는 테스트를 위해 가상의 데이터를 반환
    await Future.delayed(const Duration(seconds: 2)); // 분석 시간 시뮬레이션

    return {
      'name': '비빔밥',
      'calories': 560,
      'carbs': 82.5,
      'protein': 15.3,
      'fat': 12.8,
    };
  }
}
