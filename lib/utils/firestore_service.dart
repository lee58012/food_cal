// ignore_for_file: avoid_print, use_rethrow_when_possible

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:hoseo/models/user.dart';
import 'package:hoseo/models/food.dart';
import 'package:intl/intl.dart';
import 'dart:io';
import 'dart:convert';

class FirestoreService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // 사용자 데이터 저장
  Future<void> saveUserData(User user) async {
    try {
      if (user.uid == null) {
        throw Exception('User UID is required');
      }

      await _firestore.collection('users').doc(user.uid).set({
        'name': user.name,
        'email': user.email,
        'photoUrl': user.photoUrl,
        'age': user.age,
        'gender': user.gender,
        'height': user.height,
        'weight': user.weight,
        'activityLevel': user.activityLevel,
        'medicalCondition': user.medicalCondition,
        'targetCalories': user.targetCalories,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      print('Error saving user data: $e');
      rethrow;
    }
  }

  // 사용자 데이터 가져오기
  Future<User?> getUserData(String uid) async {
    try {
      final doc = await _firestore.collection('users').doc(uid).get();
      if (doc.exists && doc.data() != null) {
        final data = doc.data()!;
        data['uid'] = uid; // uid 추가
        return User.fromMap(data);
      }
      return null;
    } catch (e) {
      print('Error getting user data: $e');
      rethrow;
    }
  }

  // 사용자 프로필 저장
  Future<void> saveUserProfile(User user) async {
    if (user.uid == null) return;

    try {
      await _firestore.collection('users').doc(user.uid).set({
        'name': user.name,
        'age': user.age,
        'weight': user.weight,
        'height': user.height,
        'gender': user.gender,
        'activityLevel': user.activityLevel,
        'targetCalories': user.targetCalories,
        'email': user.email,
        'photoUrl': user.photoUrl,
        'medicalCondition': user.medicalCondition,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (e) {
      print('Firestore 사용자 프로필 저장 오류: $e');
      throw e;
    }
  }

  // 사용자 프로필 가져오기
  Future<Map<String, dynamic>?> getUserProfile(String uid) async {
    try {
      final doc = await _firestore.collection('users').doc(uid).get();
      if (doc.exists) {
        return doc.data();
      }
      return null;
    } catch (e) {
      print('Firestore 사용자 프로필 조회 오류: $e');
      throw e;
    }
  }

  // 사용자 프로필 업데이트
  Future<void> updateUserProfile(String uid, Map<String, dynamic> data) async {
    try {
      await _firestore.collection('users').doc(uid).update({
        ...data,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      print('Firestore 사용자 프로필 업데이트 오류: $e');
      throw e;
    }
  }

  // 음식 데이터 저장
  Future<String> addFood(String uid, Food food) async {
    try {
      String docId = '';
      await _firestore.runTransaction((transaction) async {
        // 1. 먼저 모든 읽기 작업 수행
        final dateString = DateFormat('yyyy-MM-dd').format(food.dateTime);
        final calorieDocRef = _firestore
            .collection('users')
            .doc(uid)
            .collection('dailyCalories')
            .doc(dateString);

        // 읽기 작업을 먼저 실행
        final calorieDoc = await transaction.get(calorieDocRef);

        // 2. 그 다음 모든 쓰기 작업 수행
        // 음식 문서 생성 및 저장
        final docRef = _firestore
            .collection('users')
            .doc(uid)
            .collection('foods')
            .doc();

        docId = docRef.id;

        transaction.set(docRef, {
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

        // 일일 칼로리 업데이트
        if (calorieDoc.exists) {
          final currentCalories = calorieDoc.data()?['calories'] ?? 0;
          transaction.update(calorieDocRef, {
            'calories': currentCalories + food.calories,
            'updatedAt': FieldValue.serverTimestamp(),
          });
        } else {
          transaction.set(calorieDocRef, {
            'date': dateString,
            'calories': food.calories,
            'createdAt': FieldValue.serverTimestamp(),
            'updatedAt': FieldValue.serverTimestamp(),
          });
        }
      });

      print('Firestore에 음식 데이터 저장 완료: $docId');
      return docId;
    } catch (e) {
      print('Firestore 음식 데이터 저장 오류: $e');
      throw e;
    }
  }

  // 음식 데이터 가져오기
  Future<List<Food>> getFoods(String uid) async {
    try {
      print('Firestore에서 전체 음식 데이터 로드 시작');

      // 전체 데이터를 한 번에 가져오기
      final snapshot = await _firestore
          .collection('users')
          .doc(uid)
          .collection('foods')
          .orderBy('dateTime', descending: true)
          .get();

      final foods = snapshot.docs.map((doc) {
        final data = doc.data();
        return Food(
          food_id: int.tryParse(doc.id) ?? 0,
          food_name: data['food_name'] ?? data['name'] ?? '', // 이전 데이터와의 호환성 유지
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
      }).toList();

      print('Firestore 데이터 로드 완료: ${foods.length}개');
      return foods;
    } catch (e) {
      print('Firestore 음식 데이터 로드 오류: $e');
      throw e;
    }
  }

  // 특정 날짜의 음식 데이터 가져오기
  Future<List<Food>> getFoodsByDate(String uid, DateTime date) async {
    try {
      final dateStr = DateFormat('yyyy-MM-dd').format(date);
      final startOfDay = DateTime.parse('${dateStr}T00:00:00');
      final endOfDay = DateTime.parse('${dateStr}T23:59:59');

      final snapshot = await _firestore
          .collection('users')
          .doc(uid)
          .collection('foods')
          .where(
            'dateTime',
            isGreaterThanOrEqualTo: startOfDay.toIso8601String(),
          )
          .where('dateTime', isLessThanOrEqualTo: endOfDay.toIso8601String())
          .get();

      final foods = snapshot.docs.map((doc) {
        final data = doc.data();
        return Food(
          food_id: int.tryParse(doc.id) ?? 0,
          food_name: data['food_name'] ?? data['name'] ?? '', // 이전 데이터와의 호환성 유지
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
      }).toList();

      return foods;
    } catch (e) {
      print('Firestore 날짜별 음식 데이터 로드 오류: $e');
      throw e;
    }
  }

  // 음식 데이터 삭제
  Future<void> deleteFood(
    String uid,
    String foodId,
    int calories,
    DateTime dateTime,
  ) async {
    try {
      await _firestore.runTransaction((transaction) async {
        // 1. 먼저 모든 읽기 작업 수행
        final dateString = DateFormat('yyyy-MM-dd').format(dateTime);
        final foodDocRef = _firestore
            .collection('users')
            .doc(uid)
            .collection('foods')
            .doc(foodId);
        final calorieDocRef = _firestore
            .collection('users')
            .doc(uid)
            .collection('dailyCalories')
            .doc(dateString);

        // 읽기 작업을 먼저 실행
        final calorieDoc = await transaction.get(calorieDocRef);

        // 2. 그 다음 모든 쓰기 작업 수행
        // 음식 문서 삭제
        transaction.delete(foodDocRef);

        // 일일 칼로리 업데이트
        if (calorieDoc.exists) {
          final currentCalories = calorieDoc.data()?['calories'] ?? 0;
          final newCalories = (currentCalories - calories)
              .clamp(0, double.infinity)
              .toInt();
          transaction.update(calorieDocRef, {
            'calories': newCalories,
            'updatedAt': FieldValue.serverTimestamp(),
          });
        }
      });

      print('Firestore에서 음식 데이터 삭제 완료: $foodId');
    } catch (e) {
      print('Firestore 음식 데이터 삭제 오류: $e');
      throw e;
    }
  }

  // 일일 칼로리 섭취량 가져오기
  Future<int> getDailyCalorieIntake(String uid, DateTime date) async {
    try {
      final dateString = DateFormat('yyyy-MM-dd').format(date);
      final doc = await _firestore
          .collection('users')
          .doc(uid)
          .collection('dailyCalories')
          .doc(dateString)
          .get();

      if (doc.exists) {
        return doc.data()?['calories'] ?? 0;
      }
      return 0;
    } catch (e) {
      print('Firestore 일일 칼로리 조회 오류: $e');
      throw e;
    }
  }

  // 이미지 분석 요청 (실제 구현은 백엔드에서 처리)
  Future<Map<String, dynamic>> analyzeFoodImage(String uid, File image) async {
    try {
      // 실제 구현에서는 이미지를 서버로 전송하여 분석
      // 여기서는 더미 데이터 반환
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
      };
    } catch (e) {
      print('이미지 분석 요청 오류: $e');
      throw e;
    }
  }

  // 이미지를 Base64로 인코딩하여 반환
  Future<String?> uploadFoodImage(String uid, File image) async {
    try {
      // 파일 크기 확인
      final bytes = await image.readAsBytes();
      if (bytes.length > 2 * 1024 * 1024) {
        // 2MB 제한
        throw Exception('이미지 크기가 너무 큽니다 (최대 2MB)');
      }

      // Base64로 인코딩하여 반환
      final base64String = base64Encode(bytes);
      return 'data:image/jpeg;base64,$base64String';
    } catch (e) {
      print('이미지 처리 오류: $e');
      return null;
    }
  }
}
