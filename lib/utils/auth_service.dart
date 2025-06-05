// ignore_for_file: unused_import, strict_top_level_inference, avoid_print

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
// import 'package:google_sign_in/google_sign_in.dart';
import 'package:hoseo/models/user.dart' as app_user;
import 'package:hoseo/providers/user_provider.dart';
import 'package:hoseo/utils/database_helper.dart';

class AuthService {
  final firebase_auth.FirebaseAuth _firebaseAuth =
      firebase_auth.FirebaseAuth.instance;
  // final GoogleSignIn _googleSignIn = GoogleSignIn();

  // 현재 로그인된 사용자 가져오기
  firebase_auth.User? get currentUser => _firebaseAuth.currentUser;

  // Firebase 오류 메시지 변환
  String _getErrorMessage(e) {
    if (e is firebase_auth.FirebaseAuthException) {
      switch (e.code) {
        case 'email-already-in-use':
          return '이미 가입된 이메일입니다.';
        case 'invalid-email':
          return '유효하지 않은 이메일 형식입니다.';
        case 'user-disabled':
          return '비활성화된 계정입니다.';
        case 'user-not-found':
          return '이메일이나 비밀번호가 존재하지 않습니다.';
        case 'wrong-password':
          return '이메일이나 비밀번호가 존재하지 않습니다.';
        case 'weak-password':
          return '비밀번호가 너무 약합니다.';
        case 'operation-not-allowed':
          return '이 작업은 허용되지 않습니다.';
        case 'too-many-requests':
          return '너무 많은 요청이 있었습니다. 잠시 후 다시 시도해주세요.';
        default:
          return '인증 오류가 발생했습니다: ${e.message}';
      }
    }
    return '오류가 발생했습니다: $e';
  }

  // 회원가입 - 이메일과 비밀번호만 사용
  Future<app_user.User?> signUp({
    required String email,
    required String password,
  }) async {
    try {
      final userCredential = await _firebaseAuth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      if (userCredential.user != null) {
        // 기본 사용자 정보로 User 모델 생성
        return app_user.User(
          name: '사용자', // 기본값
          age: 30, // 기본값
          weight: 65.0, // 기본값
          height: 170.0, // 기본값
          gender: '남성', // 기본값
          activityLevel: 2, // 기본값
          targetCalories: 2000, // 기본값
          email: email,
          photoUrl: userCredential.user!.photoURL,
          uid: userCredential.user!.uid,
          medicalCondition: '정상', // 기본값
        );
      }
    } catch (e) {
      throw _getErrorMessage(e);
    }
    return null;
  }

  // 로그인
  Future<app_user.User?> signIn({
    required String email,
    required String password,
  }) async {
    try {
      final userCredential = await _firebaseAuth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      if (userCredential.user != null) {
        final dbHelper = DatabaseHelper();
        final userData = await dbHelper.getUser();

        // 이미 저장된 사용자 정보가 있는지 확인
        if (userData.isNotEmpty) {
          for (var data in userData) {
            if (data['uid'] == userCredential.user!.uid) {
              return app_user.User.fromMap(data);
            }
          }
        }

        // 저장된 정보가 없으면 기본 정보로 생성
        return app_user.User(
          name: userCredential.user!.displayName ?? '사용자',
          age: 30, // 기본값
          weight: 65.0, // 기본값
          height: 170.0, // 기본값
          gender: '남성', // 기본값
          activityLevel: 2, // 기본값
          targetCalories: 2000, // 기본값
          email: email,
          photoUrl: userCredential.user!.photoURL,
          uid: userCredential.user!.uid,
          medicalCondition: '정상', // 기본값
        );
      }
    } catch (e) {
      print('로그인 오류: $e');
      throw _getErrorMessage(e);
    }
    return null;
  }

  // 로그아웃
  Future<void> signOut() async {
    await _firebaseAuth.signOut();
  }

  // 비밀번호 재설정 이메일 전송
  Future<void> sendPasswordResetEmail(String email) async {
    try {
      await _firebaseAuth.sendPasswordResetEmail(email: email);
    } catch (e) {
      throw _getErrorMessage(e);
    }
  }

  // 이메일 인증 상태 확인
  bool isEmailVerified() {
    return _firebaseAuth.currentUser?.emailVerified ?? false;
  }

  // 이메일 인증 메일 전송
  Future<void> sendEmailVerification() async {
    try {
      await _firebaseAuth.currentUser?.sendEmailVerification();
    } catch (e) {
      throw _getErrorMessage(e);
    }
  }
}
