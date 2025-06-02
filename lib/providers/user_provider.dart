import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:hoseo/models/user.dart';
import 'package:hoseo/utils/database_helper.dart';

class UserProvider with ChangeNotifier {
  User? _user;
  bool _isFirstTime = true;
  bool _isLoggedIn = false;

  User? get user => _user;
  bool get isFirstTime => _isFirstTime;
  bool get isLoggedIn => _isLoggedIn;

  // 앱 시작 시 사용자 정보 로드
  Future<void> loadUser() async {
    final dbHelper = DatabaseHelper();
    final userData = await dbHelper.getUser();

    if (userData.isNotEmpty) {
      _user = User.fromMap(userData.first);
      _isFirstTime = false;
      _isLoggedIn = _user?.uid != null;
    } else {
      // 저장된 사용자 정보가 없을 경우
      final prefs = await SharedPreferences.getInstance();
      _isFirstTime = prefs.getBool('is_first_time') ?? true;
      _isLoggedIn = false;
    }

    notifyListeners();
  }

  // 사용자 정보 저장
  Future<void> saveUser(User user) async {
    final dbHelper = DatabaseHelper();

    if (_user == null) {
      // 새 사용자 등록
      final id = await dbHelper.insertUser(user.toMap());
      _user = User(
        id: id,
        name: user.name,
        age: user.age,
        weight: user.weight,
        height: user.height,
        gender: user.gender,
        activityLevel: user.activityLevel,
        targetCalories: user.targetCalories,
      );

      // 첫 실행 여부 업데이트
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('is_first_time', false);
      _isFirstTime = false;
    } else {
      // 기존 사용자 정보 업데이트
      final updatedUser = User(
        id: _user!.id,
        name: user.name,
        age: user.age,
        weight: user.weight,
        height: user.height,
        gender: user.gender,
        activityLevel: user.activityLevel,
        targetCalories: user.targetCalories,
      );

      await dbHelper.updateUser(updatedUser.toMap());
      _user = updatedUser;
    }

    notifyListeners();
  }

  // 사용자 운동량 업데이트 (활동 레벨)
  Future<void> updateActivityLevel(int activityLevel) async {
    if (_user != null) {
      final updatedUser = User(
        id: _user!.id,
        name: _user!.name,
        age: _user!.age,
        weight: _user!.weight,
        height: _user!.height,
        gender: _user!.gender,
        activityLevel: activityLevel,
        targetCalories: _user!.targetCalories,
      );

      final dbHelper = DatabaseHelper();
      await dbHelper.updateUser(updatedUser.toMap());
      _user = updatedUser;

      notifyListeners();
    }
  }
}
