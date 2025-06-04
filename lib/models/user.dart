class User {
  final int? id;
  final String name;
  final int age;
  final double weight;
  final double height;
  final String gender;
  final int activityLevel; // 1-5 (낮음-높음)
  final int targetCalories;
  final String? uid; // Firebase 인증용
  final String? email; // 사용자 이메일
  final String? photoUrl; // 프로필 사진 URL
  final String medicalCondition; // 정상, 당뇨, 고혈압, 고지혈증

  User({
    this.id,
    required this.name,
    required this.age,
    required this.weight,
    required this.height,
    required this.gender,
    required this.activityLevel,
    required this.targetCalories,
    this.uid,
    this.email,
    this.photoUrl,
    required this.medicalCondition,
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
      'uid': uid,
      'email': email,
      'photoUrl': photoUrl,
      'medicalCondition': medicalCondition,
    };
  }

  factory User.fromMap(Map<String, dynamic> map) {
    return User(
      id: map['id'] as int?,
      name: map['name'] as String,
      age: map['age'] as int,
      weight: (map['weight'] as num).toDouble(),
      height: (map['height'] as num).toDouble(),
      gender: map['gender'] as String,
      activityLevel: map['activityLevel'] as int,
      targetCalories: map['targetCalories'] as int,
      uid: map['uid'] as String?,
      email: map['email'] as String?,
      photoUrl: map['photoUrl'] as String?,
      medicalCondition: map['medicalCondition'] as String? ?? '정상',
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
