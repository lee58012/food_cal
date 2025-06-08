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

  // 음식 추가 - 성능 최적화
  Future<String> addFood(String userId, Food food) async {
    try {
      // 배치 작업으로 여러 문서를 한 번에 업데이트
      WriteBatch batch = _firestore.batch();

      // 1. 음식 문서 추가
      final foodRef = _firestore
          .collection('users')
          .doc(userId)
          .collection('foods')
          .doc(); // 자동 ID 생성

      batch.set(foodRef, {
        'name': food.name,
        'calories': food.calories,
        'carbs': food.carbs,
        'protein': food.protein,
        'fat': food.fat,
        'sodium': food.sodium,
        'cholesterol': food.cholesterol,
        'sugar': food.sugar,
        'imageUrl': food.imageUrl,
        'dateTime': food.dateTime,
        'createdAt': FieldValue.serverTimestamp(),
      });

      // 2. 일일 칼로리 업데이트
      final dateStr = DateFormat('yyyy-MM-dd').format(food.dateTime);
      final calorieRef = _firestore
          .collection('users')
          .doc(userId)
          .collection('dailyCalories')
          .doc(dateStr);

      // 트랜잭션 대신 배치 작업으로 처리
      batch.set(calorieRef, {
        'calories': FieldValue.increment(food.calories),
      }, SetOptions(merge: true));

      // 배치 작업 실행
      await batch.commit();

      print('음식 추가 완료: ${foodRef.id}');
      return foodRef.id;
    } catch (e) {
      print('Firestore 음식 추가 오류: $e');
      rethrow;
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
          id: doc.id, // 문서 ID를 그대로 사용
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

      print('Firestore 데이터 로드 완료: ${foods.length}개');
      return foods;
    } catch (e) {
      print('Firestore 음식 데이터 조회 오류: $e');
      throw e;
    }
  }

  // 음식 삭제 - 성능 최적화
  Future<void> deleteFood(
    String userId,
    dynamic foodId,
    int calories,
    DateTime dateTime,
    String? imageUrl,
  ) async {
    try {
      // 배치 작업으로 여러 문서를 한 번에 업데이트
      WriteBatch batch = _firestore.batch();

      // 1. 음식 문서 삭제
      final foodRef = _firestore
          .collection('users')
          .doc(userId)
          .collection('foods')
          .doc(foodId.toString());

      batch.delete(foodRef);

      // 2. 일일 칼로리 업데이트
      final dateStr = DateFormat('yyyy-MM-dd').format(dateTime);
      final calorieRef = _firestore
          .collection('users')
          .doc(userId)
          .collection('dailyCalories')
          .doc(dateStr);

      // 음수 값이 되지 않도록 보호
      batch.set(calorieRef, {
        'calories': FieldValue.increment(-calories),
      }, SetOptions(merge: true));

      // 배치 작업 실행
      await batch.commit();

      // 3. 이미지가 있으면 Storage에서 삭제 (배치 작업 외부에서 처리)
      if (imageUrl != null &&
          imageUrl.isNotEmpty &&
          imageUrl.startsWith('gs://')) {
        try {
          final ref = FirebaseStorage.instance.refFromURL(imageUrl);
          await ref.delete();
          print('이미지 삭제 완료: $imageUrl');
        } catch (e) {
          print('이미지 삭제 오류: $e');
          // 이미지 삭제 실패해도 계속 진행
        }
      }

      print('음식 삭제 완료: $foodId');
    } catch (e) {
      print('Firestore 음식 삭제 오류: $e');
      rethrow;
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
      print('특정 날짜($dateStr) 음식 데이터 로드 시작');

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

      final foods = snapshot.docs.map((doc) {
        final data = doc.data();
        return Food(
          id: doc.id, // 문서 ID를 그대로 사용
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

      print('특정 날짜 데이터 로드 완료: ${foods.length}개');
      return foods;
    } catch (e) {
      print('Firestore 특정 날짜 음식 데이터 조회 오류: $e');
      throw e;
    }
  }
}
