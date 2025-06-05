// ignore_for_file: avoid_print, use_rethrow_when_possible

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:hoseo/models/user.dart';
import 'package:hoseo/models/food.dart';
import 'package:intl/intl.dart';
import 'package:firebase_storage/firebase_storage.dart';

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
          'name': food.name,
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
      final snapshot = await _firestore
          .collection('users')
          .doc(uid)
          .collection('foods')
          .orderBy('dateTime', descending: true)
          .get();

      return snapshot.docs.map((doc) {
        final data = doc.data();
        return Food(
          id: int.tryParse(doc.id) ?? 0,
          name: data['name'] ?? '',
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
    } catch (e) {
      print('Firestore 음식 데이터 조회 오류: $e');
      throw e;
    }
  }

  // 음식 데이터 삭제 - 이미지도 함께 삭제
  Future<void> deleteFood(
    String uid,
    String foodId,
    int calories,
    DateTime dateTime,
    String? imageUrl, // 이미지 URL 추가
  ) async {
    try {
      final dateString = DateFormat('yyyy-MM-dd').format(dateTime);

      // 1. 이미지가 있다면 먼저 삭제
      if (imageUrl != null &&
          imageUrl.isNotEmpty &&
          !imageUrl.startsWith('data:')) {
        try {
          // Firebase Storage에서 이미지 삭제
          final ref = FirebaseStorage.instance.refFromURL(imageUrl);
          await ref.delete();
          print('Firebase Storage에서 이미지 삭제 완료: $imageUrl');
        } catch (imageError) {
          print('이미지 삭제 실패 (계속 진행): $imageError');
          // 이미지 삭제 실패해도 문서는 삭제 진행
        }
      }

      // 2. Firestore에서 음식 문서 삭제 및 칼로리 업데이트
      await _firestore.runTransaction((transaction) async {
        // 읽기 작업 먼저
        final calorieDocRef = _firestore
            .collection('users')
            .doc(uid)
            .collection('dailyCalories')
            .doc(dateString);

        final calorieDoc = await transaction.get(calorieDocRef);

        // 쓰기 작업
        // 음식 문서 삭제
        final foodDocRef = _firestore
            .collection('users')
            .doc(uid)
            .collection('foods')
            .doc(foodId);

        transaction.delete(foodDocRef);

        // 일일 칼로리 업데이트
        if (calorieDoc.exists) {
          final currentCalories = calorieDoc.data()?['calories'] ?? 0;
          final newCalories = (currentCalories - calories).clamp(
            0,
            double.infinity,
          );

          if (newCalories > 0) {
            transaction.update(calorieDocRef, {
              'calories': newCalories,
              'updatedAt': FieldValue.serverTimestamp(),
            });
          } else {
            // 칼로리가 0이면 문서 삭제
            transaction.delete(calorieDocRef);
          }
        }
      });

      print('Firestore에서 음식 데이터 삭제 완료');
    } catch (e) {
      print('Firestore 음식 데이터 삭제 오류: $e');
      throw e;
    }
  }

  // 일일 칼로리 섭취량 업데이트
  Future<void> updateDailyCalorieIntake(
    String uid,
    DateTime date,
    int calorieChange,
  ) async {
    final dateString =
        '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

    try {
      // 트랜잭션을 사용하여 원자적으로 업데이트
      await _firestore.runTransaction((transaction) async {
        // 해당 날짜의 칼로리 데이터 문서 참조
        final docRef = _firestore
            .collection('users')
            .doc(uid)
            .collection('dailyCalories')
            .doc(dateString);

        // 문서 스냅샷 가져오기
        final snapshot = await transaction.get(docRef);

        if (snapshot.exists) {
          // 기존 칼로리에 새 칼로리 추가/차감
          final currentCalories = snapshot.data()?['calories'] ?? 0;
          transaction.update(docRef, {
            'calories': currentCalories + calorieChange,
            'updatedAt': FieldValue.serverTimestamp(),
          });
        } else {
          // 새 문서 생성
          transaction.set(docRef, {
            'date': dateString,
            'calories': calorieChange,
            'createdAt': FieldValue.serverTimestamp(),
            'updatedAt': FieldValue.serverTimestamp(),
          });
        }
      });
    } catch (e) {
      print('Firestore 일일 칼로리 업데이트 오류: $e');
      throw e;
    }
  }

  // 특정 날짜의 칼로리 섭취량 가져오기
  Future<int> getDailyCalorieIntake(String uid, DateTime date) async {
    final dateString =
        '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

    try {
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

  // 특정 날짜의 음식 데이터 가져오기
  Future<List<Food>> getFoodsByDate(String uid, DateTime date) async {
    try {
      final dateFormat = DateFormat('yyyy-MM-dd');
      final dateStr = dateFormat.format(date);

      // 해당 날짜의 시작과 끝 설정
      final startDate = DateTime.parse('${dateStr}T00:00:00');
      final endDate = DateTime.parse('${dateStr}T23:59:59');

      final snapshot = await _firestore
          .collection('users')
          .doc(uid)
          .collection('foods')
          .where(
            'dateTime',
            isGreaterThanOrEqualTo: startDate.toIso8601String(),
          )
          .where('dateTime', isLessThanOrEqualTo: endDate.toIso8601String())
          .orderBy('dateTime', descending: true)
          .get();

      return snapshot.docs.map((doc) {
        final data = doc.data();
        return Food(
          id: int.tryParse(doc.id) ?? 0,
          name: data['name'] ?? '',
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
    } catch (e) {
      print('Firestore 특정 날짜 음식 데이터 조회 오류: $e');
      throw e;
    }
  }
}
