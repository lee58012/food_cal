// ignore_for_file: avoid_print, use_rethrow_when_possible, depend_on_referenced_packages

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:hoseo/models/user.dart';
import 'package:hoseo/utils/database_helper.dart';
import 'package:hoseo/utils/firestore_service.dart';
import 'package:firebase_auth/firebase_auth.dart' as auth;
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class UserProvider with ChangeNotifier {
  User? _user;
  bool _isFirstTime = false;
  bool _isLoggedIn = false;
  final FirestoreService _firestoreService = FirestoreService();

  User? get user => _user;
  bool get isFirstTime => _isFirstTime;
  bool get isLoggedIn => _isLoggedIn;

  // 앱 시작 시 사용자 정보 로드
  Future<void> loadUser() async {
    try {
      final currentUser = auth.FirebaseAuth.instance.currentUser;
      if (currentUser != null) {
        final doc = await FirebaseFirestore.instance
            .collection('users')
            .doc(currentUser.uid)
            .get();

        if (doc.exists) {
          final userData = doc.data()!;
          _user = User(
            uid: currentUser.uid,
            email: currentUser.email,
            name: userData['name'] ?? '사용자',
            photoUrl: userData['photoUrl'] ?? currentUser.photoURL,
            age: userData['age'] ?? 25,
            gender: userData['gender'] ?? '남성',
            height: (userData['height'] ?? 170).toDouble(),
            weight: (userData['weight'] ?? 65).toDouble(),
            activityLevel: userData['activityLevel'] ?? 2,
            medicalCondition: userData['medicalCondition'] ?? '정상',
            targetCalories: userData['targetCalories']?.toDouble(),
          );
          notifyListeners();
        } else {
          // 새 사용자인 경우
          _isFirstTime = true;
          _user = User(
            uid: currentUser.uid,
            email: currentUser.email,
            name: currentUser.displayName ?? '사용자',
            photoUrl: currentUser.photoURL,
            age: 25,
            gender: '남성',
            height: 170,
            weight: 65,
            activityLevel: 2,
            medicalCondition: '정상',
          );
          notifyListeners();
        }
      }
    } catch (e) {
      print('사용자 정보 로드 오류: $e');
    }
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
    required double targetCalories,
  }) async {
    if (_user == null) return;

    final targetCalories = _calculateTargetCalories(
      gender: gender,
      age: age,
      weight: weight,
      height: height,
      activityLevel: activityLevel,
      medicalCondition: medicalCondition,
    );

    final updatedUser = User(
      id: _user!.id,
      name: name,
      age: age,
      weight: weight,
      height: height,
      gender: gender,
      activityLevel: activityLevel,
      targetCalories: targetCalories.toDouble(),
      email: _user!.email,
      photoUrl: photoUrl ?? _user!.photoUrl,
      uid: _user!.uid,
      medicalCondition: medicalCondition,
    );

    await saveUser(updatedUser);

    // 프로필 업데이트 후 알림
    notifyListeners();
  }

  int _calculateTargetCalories({
    required String gender,
    required int age,
    required double weight,
    required double height,
    required int activityLevel,
    required String medicalCondition,
  }) {
    double bmr;
    if (gender == '남성') {
      bmr = (10 * weight) + (6.25 * height) - (5 * age) + 5;
    } else {
      bmr = (10 * weight) + (6.25 * height) - (5 * age) - 161;
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

    // 건강 상태에 따른 조정
    double medicalFactor = 1.0;
    if (medicalCondition == '당뇨') {
      medicalFactor = 0.9; // 당뇨 환자는 일반적으로 10% 정도 칼로리 제한
    } else if (medicalCondition == '고혈압') {
      medicalFactor = 0.95; // 고혈압 환자는 5% 정도 칼로리 제한
    } else if (medicalCondition == '고지혈증') {
      medicalFactor = 0.9; // 고지혈증 환자는 10% 정도 칼로리 제한
    }

    return (bmr * activityFactor * medicalFactor).round();
  }
}
