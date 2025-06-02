class User {
  final int? id;
  final String name;
  final int age;
  final double weight;
  final double height;
  final String gender;
  final int activityLevel; // 1-5 (낮음-높음)
  final int targetCalories;
  final String? email;
  final String? photoUrl;
  final String? uid;

  User({
    this.id,
    required this.name,
    required this.age,
    required this.weight,
    required this.height,
    required this.gender,
    required this.activityLevel,
    required this.targetCalories,
    this.email,
    this.photoUrl,
    this.uid,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'age': age,
      'weight': weight,
      'height': height,
      'gender': gender,
      'activityLevel': activityLevel,
      'targetCalories': targetCalories,
      'email': email,
      'photoUrl': photoUrl,
      'uid': uid,
    };
  }

  factory User.fromMap(Map<String, dynamic> map) {
    return User(
      id: map['id'],
      name: map['name'],
      age: map['age'],
      weight: map['weight'],
      height: map['height'],
      gender: map['gender'],
      activityLevel: map['activityLevel'],
      targetCalories: map['targetCalories'],
      email: map['email'],
      photoUrl: map['photoUrl'],
      uid: map['uid'],
    );
  }

  // 구글 로그인 데이터로 User 객체 생성
  factory User.fromGoogleSignIn(Map<String, dynamic> userData) {
    return User(
      name: userData['displayName'] ?? '사용자',
      age: 30, // 기본값
      weight: 65.0, // 기본값
      height: 170.0, // 기본값
      gender: '남성', // 기본값
      activityLevel: 2, // 기본값
      targetCalories: 2000, // 기본값
      email: userData['email'],
      photoUrl: userData['photoUrl'],
      uid: userData['uid'],
    );
  }

  // BMI 계산
  double get bmi {
    return weight / ((height / 100) * (height / 100));
  }

  // 기초 대사량 계산 (해리스-베네딕트 공식)
  double get bmr {
    if (gender == '남성') {
      return 88.362 + (13.397 * weight) + (4.799 * height) - (5.677 * age);
    } else {
      return 447.593 + (9.247 * weight) + (3.098 * height) - (4.330 * age);
    }
  }

  // 일일 권장 칼로리 계산
  int get recommendedCalories {
    double activityFactor = 1.2;

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
    }

    return (bmr * activityFactor).round();
  }
}
