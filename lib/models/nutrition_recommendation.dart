import 'package:hoseo/models/user.dart';

class NutritionRecommendation {
  final double recommendedCarbs;
  final double recommendedProtein;
  final double recommendedFat;
  final double recommendedSodium;
  final double recommendedCholesterol;
  final double recommendedSugar;
  final double _tdee;

  const NutritionRecommendation({
    required this.recommendedCarbs,
    required this.recommendedProtein,
    required this.recommendedFat,
    required this.recommendedSodium,
    required this.recommendedCholesterol,
    required this.recommendedSugar,
    required double tdee,
  }) : _tdee = tdee;

  // Getters
  double get carbs => recommendedCarbs;
  double get protein => recommendedProtein;
  double get fat => recommendedFat;
  double get sodium => recommendedSodium;
  double get cholesterol => recommendedCholesterol;
  double get sugar => recommendedSugar;
  double get tdee => _tdee;
  double get recommendedCalories => _tdee;

  factory NutritionRecommendation.fromUser(User user) {
    // 기초 대사량 (BMR) 계산 - 해리스-베네딕트 공식 사용
    double bmr;
    if (user.gender == '남성') {
      bmr = (10 * user.weight) + (6.25 * user.height) - (5 * user.age) + 5;
    } else {
      bmr = (10 * user.weight) + (6.25 * user.height) - (5 * user.age) - 161;
    }

    // 활동 레벨에 따른 계수
    double activityFactor;
    switch (user.activityLevel) {
      case 1:
        activityFactor = 1.2; // 비활동적
        break;
      case 2:
        activityFactor = 1.375; // 가벼운 활동
        break;
      case 3:
        activityFactor = 1.55; // 중간 활동
        break;
      case 4:
        activityFactor = 1.725; // 활동적
        break;
      case 5:
        activityFactor = 1.9; // 매우 활동적
        break;
      default:
        activityFactor = 1.375;
    }

    // 일일 필요 칼로리
    final tdee = bmr * activityFactor;

    // 건강 상태에 따른 조정
    double carbsRatio = 0.5; // 기본 탄수화물 비율 (50%)
    double proteinRatio = 0.3; // 기본 단백질 비율 (30%)
    double fatRatio = 0.2; // 기본 지방 비율 (20%)
    double sodiumFactor = 1.0;
    double cholesterolFactor = 1.0;
    double sugarFactor = 1.0;

    switch (user.medicalCondition) {
      case '당뇨':
        carbsRatio = 0.45; // 탄수화물 비율 감소
        proteinRatio = 0.35;
        fatRatio = 0.2;
        sugarFactor = 0.7; // 당류 섭취 제한
        break;
      case '고혈압':
        sodiumFactor = 0.7; // 나트륨 섭취 제한
        break;
      case '고지혈증':
        fatRatio = 0.15; // 지방 비율 감소
        proteinRatio = 0.35;
        carbsRatio = 0.5;
        cholesterolFactor = 0.7; // 콜레스테롤 섭취 제한
        break;
    }

    // 영양소별 권장량 계산
    final recommendedCarbs = (tdee * carbsRatio) / 4; // 탄수화물 1g = 4kcal
    final recommendedProtein = (tdee * proteinRatio) / 4; // 단백질 1g = 4kcal
    final recommendedFat = (tdee * fatRatio) / 9; // 지방 1g = 9kcal

    // 기타 영양소 권장량
    final recommendedSodium = 2000 * sodiumFactor; // 기본 2000mg/일
    final recommendedCholesterol = 300 * cholesterolFactor; // 기본 300mg/일
    final recommendedSugar =
        (tdee * 0.1) / 4 * sugarFactor; // 총 칼로리의 10%를 당류로 제한

    return NutritionRecommendation(
      recommendedCarbs: recommendedCarbs,
      recommendedProtein: recommendedProtein,
      recommendedFat: recommendedFat,
      recommendedSodium: recommendedSodium,
      recommendedCholesterol: recommendedCholesterol,
      recommendedSugar: recommendedSugar,
      tdee: tdee,
    );
  }

  // 영양소 상태 확인 메서드
  String getNutrientStatus(String nutrient, double current) {
    double target;
    switch (nutrient) {
      case 'carbs':
        target = recommendedCarbs;
        break;
      case 'protein':
        target = recommendedProtein;
        break;
      case 'fat':
        target = recommendedFat;
        break;
      case 'sodium':
        target = recommendedSodium;
        break;
      case 'cholesterol':
        target = recommendedCholesterol;
        break;
      case 'sugar':
        target = recommendedSugar;
        break;
      default:
        return '알 수 없음';
    }

    final ratio = current / target;
    if (ratio < 0.8) return '부족';
    if (ratio <= 1.2) return '적당';
    return '과다';
  }
}
