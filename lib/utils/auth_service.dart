import 'package:flutter/material.dart';
// import 'package:firebase_auth/firebase_auth.dart';
// import 'package:google_sign_in/google_sign_in.dart';
import 'package:hoseo/models/user.dart';
import 'package:hoseo/providers/user_provider.dart';

class AuthService {
  // final FirebaseAuth _auth = FirebaseAuth.instance;
  // final GoogleSignIn _googleSignIn = GoogleSignIn();

  // Firebase 없이 사용자 생성
  Future<User?> signInWithGoogleAndSaveUser(UserProvider userProvider) async {
    try {
      // 임시 사용자 생성
      final user = User(
        name: '사용자',
        email: 'user@example.com',
        height: 170.0,
        weight: 65.0,
        targetCalories: 2000,
        gender: '남성',
        age: 30,
        activityLevel: 2,
      );

      await userProvider.saveUser(user);
      return user;
    } catch (e) {
      print('로그인 오류: $e');
      return null;
    }
  }

  // 로그아웃
  Future<void> signOut() async {
    try {
      // await _googleSignIn.signOut();
      // await _auth.signOut();
    } catch (e) {
      print('로그아웃 오류: $e');
    }
  }
}
