class User {
  final int? id;
  final String? name;
  final String? email;
  final String? photoUrl;
  final String? uid;
  final int age;
  final String gender;
  final double height;
  final double weight;
  final int activityLevel;
  final String medicalCondition;
  final double? targetCalories;

  const User({
    this.id,
    this.name,
    this.email,
    this.photoUrl,
    this.uid,
    required this.age,
    required this.gender,
    required this.height,
    required this.weight,
    required this.activityLevel,
    required this.medicalCondition,
    this.targetCalories,
  });

  factory User.fromMap(Map<String, dynamic> map) {
    return User(
      id: map['id'],
      name: map['name'],
      email: map['email'],
      photoUrl: map['photoUrl'],
      uid: map['uid'],
      age: map['age'] ?? 25,
      gender: map['gender'] ?? '남성',
      height: (map['height'] ?? 170).toDouble(),
      weight: (map['weight'] ?? 70).toDouble(),
      activityLevel: map['activityLevel'] ?? 2,
      medicalCondition: map['medicalCondition'] ?? '없음',
      targetCalories: map['targetCalories']?.toDouble(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'email': email,
      'photoUrl': photoUrl,
      'uid': uid,
      'age': age,
      'gender': gender,
      'height': height,
      'weight': weight,
      'activityLevel': activityLevel,
      'medicalCondition': medicalCondition,
      'targetCalories': targetCalories,
    };
  }

  User copyWith({
    String? name,
    int? age,
    double? weight,
    double? height,
    String? gender,
    int? activityLevel,
    String? photoUrl,
    String? medicalCondition,
    double? targetCalories,
  }) {
    return User(
      name: name ?? this.name,
      age: age ?? this.age,
      weight: weight ?? this.weight,
      height: height ?? this.height,
      gender: gender ?? this.gender,
      activityLevel: activityLevel ?? this.activityLevel,
      photoUrl: photoUrl ?? this.photoUrl,
      medicalCondition: medicalCondition ?? this.medicalCondition,
      targetCalories: targetCalories ?? this.targetCalories,
    );
  }

  // BMI 계산
  double get bmi {
    return weight / ((height / 100) * (height / 100));
  }

  // 기초 대사량 계산 (Mifflin-St Jeor 공식)
  double get bmr {
    if (gender == '남성') {
      return (10 * weight) + (6.25 * height) - (5 * age) + 5;
    } else {
      return (10 * weight) + (6.25 * height) - (5 * age) - 161;
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
