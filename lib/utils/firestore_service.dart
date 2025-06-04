import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:hoseo/models/user.dart';
import 'package:hoseo/models/food.dart';

class FirestoreService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

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
      final docRef = _firestore
          .collection('users')
          .doc(uid)
          .collection('foods')
          .doc();

      await docRef.set({
        'name': food.name,
        'calories': food.calories,
        'carbs': food.carbs,
        'protein': food.protein,
        'fat': food.fat,
        'imageUrl': food.imageUrl,
        'dateTime': food.dateTime.toIso8601String(),
        'createdAt': FieldValue.serverTimestamp(),
      });

      // 사용자의 일일 칼로리 섭취량 업데이트
      await updateDailyCalorieIntake(uid, food.dateTime, food.calories);

      return docRef.id;
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
          imageUrl: data['imageUrl'],
          dateTime: DateTime.parse(data['dateTime']),
        );
      }).toList();
    } catch (e) {
      print('Firestore 음식 데이터 조회 오류: $e');
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
      await _firestore
          .collection('users')
          .doc(uid)
          .collection('foods')
          .doc(foodId)
          .delete();

      // 일일 칼로리 섭취량에서 삭제된 음식의 칼로리 차감
      await updateDailyCalorieIntake(uid, dateTime, -calories);
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
}
