import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:hoseo/models/user.dart';
import 'package:hoseo/utils/database_helper.dart';
import 'package:hoseo/utils/firestore_service.dart';
import 'package:firebase_auth/firebase_auth.dart' as auth;

class UserProvider with ChangeNotifier {
  User? _user;
  bool _isFirstTime = true;
  bool _isLoggedIn = false;
  final FirestoreService _firestoreService = FirestoreService();

  User? get user => _user;
  bool get isFirstTime => _isFirstTime;
  bool get isLoggedIn => _isLoggedIn;

  // 앱 시작 시 사용자 정보 로드
  Future<void> loadUser() async {
    print('사용자 정보 로드 시작');
    final dbHelper = DatabaseHelper();
    final userData = await dbHelper.getUser();

    // Firebase 인증 상태 확인
    final currentUser = auth.FirebaseAuth.instance.currentUser;
    if (currentUser == null) {
      print('Firebase 인증 사용자 없음');
      _isLoggedIn = false;
      notifyListeners();
      return;
    }

    print('Firebase 인증 사용자 발견: ${currentUser.uid}');
    _isLoggedIn = true;

    try {
      // Firestore에서 최신 데이터 로드 시도
      final firestoreData = await _firestoreService.getUserProfile(
        currentUser.uid,
      );

      if (firestoreData != null) {
        print('Firestore에서 사용자 데이터 로드 성공');
        // Firestore 데이터가 있으면 로컬 DB 업데이트
        final updatedUser = User(
          id: userData.isNotEmpty ? userData.first['id'] : 0,
          name: firestoreData['name'] ?? '사용자',
          age: firestoreData['age'] ?? 30,
          weight: firestoreData['weight'] ?? 65.0,
          height: firestoreData['height'] ?? 170.0,
          gender: firestoreData['gender'] ?? '남성',
          activityLevel: firestoreData['activityLevel'] ?? 2,
          targetCalories: firestoreData['targetCalories'] ?? 2000,
          email: firestoreData['email'] ?? currentUser.email,
          photoUrl: firestoreData['photoUrl'],
          uid: currentUser.uid,
          medicalCondition: firestoreData['medicalCondition'] ?? '정상',
        );

        _user = updatedUser;
        _isFirstTime = false;

        // 로컬 DB 업데이트
        if (userData.isEmpty) {
          await dbHelper.insertUser(updatedUser.toMap());
        } else {
          await dbHelper.updateUser(updatedUser.toMap());
        }
      } else if (userData.isNotEmpty) {
        print('로컬 DB에서 사용자 데이터 로드');
        // Firestore에 데이터가 없지만 로컬 DB에 있는 경우
        _user = User.fromMap(userData.first);
        _isFirstTime = false;

        // 로컬 데이터를 Firestore에 동기화
        if (_user!.uid == currentUser.uid) {
          await _firestoreService.saveUserProfile(_user!);
          print('로컬 데이터를 Firestore에 동기화 완료');
        }
      } else {
        print('새 사용자 생성');
        // 둘 다 없는 경우 기본 사용자 생성
        final newUser = User(
          name: currentUser.displayName ?? '사용자',
          age: 30,
          weight: 65.0,
          height: 170.0,
          gender: '남성',
          activityLevel: 2,
          targetCalories: 2000,
          email: currentUser.email,
          photoUrl: currentUser.photoURL,
          uid: currentUser.uid,
          medicalCondition: '정상',
        );

        await saveUser(newUser);
        _isFirstTime = true;
      }
    } catch (e) {
      print('사용자 정보 로드 오류: $e');

      if (userData.isNotEmpty) {
        // 오류 발생 시 로컬 데이터 사용
        _user = User.fromMap(userData.first);
        _isFirstTime = false;
      }
    }

    notifyListeners();
  }

  // 사용자 정보 저장
  Future<void> saveUser(User user) async {
    try {
      print('사용자 정보 저장 시작: ${user.name}');
      final dbHelper = DatabaseHelper();

      // 기존 사용자 정보 확인
      final existingUsers = await dbHelper.getUser();
      bool userExists = false;

      if (existingUsers.isNotEmpty && user.uid != null) {
        for (var existingUser in existingUsers) {
          if (existingUser['uid'] == user.uid) {
            // 기존 사용자 정보 업데이트
            user = User(
              id: existingUser['id'],
              name: user.name,
              age: user.age,
              weight: user.weight,
              height: user.height,
              gender: user.gender,
              activityLevel: user.activityLevel,
              targetCalories: user.targetCalories,
              email: user.email,
              photoUrl: user.photoUrl,
              uid: user.uid,
              medicalCondition: user.medicalCondition,
            );
            await dbHelper.updateUser(user.toMap());
            userExists = true;
            print('기존 사용자 정보 업데이트');
            break;
          }
        }
      }

      if (!userExists) {
        // 새 사용자 등록
        final id = await dbHelper.insertUser(user.toMap());
        user = User(
          id: id,
          name: user.name,
          age: user.age,
          weight: user.weight,
          height: user.height,
          gender: user.gender,
          activityLevel: user.activityLevel,
          targetCalories: user.targetCalories,
          email: user.email,
          photoUrl: user.photoUrl,
          uid: user.uid,
          medicalCondition: user.medicalCondition,
        );

        // 첫 실행 여부 업데이트
        final prefs = await SharedPreferences.getInstance();
        await prefs.setBool('is_first_time', false);
        _isFirstTime = false;
        print('새 사용자 등록 완료');
      }

      _user = user;
      _isLoggedIn = user.uid != null;

      // Firestore에도 저장
      if (user.uid != null) {
        try {
          print('Firestore에 사용자 정보 저장 시도');
          await _firestoreService.saveUserProfile(user);
          print('Firestore에 사용자 정보 저장 성공');
        } catch (e) {
          print('Firestore 저장 오류: $e');
          // Firestore 저장 실패해도 로컬 데이터는 유지
        }
      }

      notifyListeners();
    } catch (e) {
      print('사용자 정보 저장 오류: $e');
      throw e; // 오류를 상위로 전파하여 UI에서 처리할 수 있도록 함
    }
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
        email: _user!.email,
        photoUrl: _user!.photoUrl,
        uid: _user!.uid,
        medicalCondition: _user!.medicalCondition,
      );

      await saveUser(updatedUser);
    }
  }

  Future<void> updateUser({
    required String name,
    required int age,
    required double weight,
    required double height,
    required String gender,
    required int activityLevel,
    String? photoUrl,
    required String medicalCondition,
  }) async {
    if (_user == null) return;

    final targetCalories = _calculateTargetCalories(
      gender: gender,
      age: age,
      weight: weight,
      height: height,
      activityLevel: activityLevel,
    );

    final updatedUser = User(
      id: _user!.id,
      name: name,
      age: age,
      weight: weight,
      height: height,
      gender: gender,
      activityLevel: activityLevel,
      targetCalories: targetCalories,
      email: _user!.email,
      photoUrl: photoUrl ?? _user!.photoUrl,
      uid: _user!.uid,
      medicalCondition: medicalCondition,
    );

    await saveUser(updatedUser);
  }

  int _calculateTargetCalories({
    required String gender,
    required int age,
    required double weight,
    required double height,
    required int activityLevel,
  }) {
    double bmr;
    if (gender == '남성') {
      bmr = 88.362 + (13.397 * weight) + (4.799 * height) - (5.677 * age);
    } else {
      bmr = 447.593 + (9.247 * weight) + (3.098 * height) - (4.330 * age);
    }

    // 활동 레벨에 따른 계수
    double activityFactor;
    switch (activityLevel) {
      case 1:
        activityFactor = 1.2;
        break; // 비활동적
      case 2:
        activityFactor = 1.375;
        break; // 가벼운 활동
      case 3:
        activityFactor = 1.55;
        break; // 중간 활동
      case 4:
        activityFactor = 1.725;
        break; // 활동적
      case 5:
        activityFactor = 1.9;
        break; // 매우 활동적
      default:
        activityFactor = 1.375;
    }

    return (bmr * activityFactor).round();
  }
}
