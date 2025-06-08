class Food {
  final int? food_id;
  final String food_name;
  final int calories;
  final double carbs;
  final double protein;
  final double fat;
  final double sodium; // 나트륨 (mg)
  final double cholesterol; // 콜레스테롤 (mg)
  final double sugar; // 총당류 (g)
  final String? imageUrl;
  final DateTime dateTime;

  Food({
    this.food_id,
    required this.food_name,
    required this.calories,
    required this.carbs,
    required this.protein,
    required this.fat,
    this.sodium = 0,
    this.cholesterol = 0,
    this.sugar = 0,
    this.imageUrl,
    required this.dateTime,
  });

  Map<String, dynamic> toMap() {
    return {
      'food_id': food_id,
      'food_name': food_name,
      'calories': calories,
      'carbs': carbs,
      'protein': protein,
      'fat': fat,
      'sodium': sodium,
      'cholesterol': cholesterol,
      'sugar': sugar,
      'imageUrl': imageUrl,
      'dateTime': dateTime.toIso8601String(),
    };
  }

  factory Food.fromMap(Map<String, dynamic> map) {
    return Food(
      food_id: map['food_id'] as int?,
      food_name: map['food_name'] as String,
      calories: map['calories'] as int,
      carbs: (map['carbs'] as num).toDouble(),
      protein: (map['protein'] as num).toDouble(),
      fat: (map['fat'] as num).toDouble(),
      sodium: map['sodium'] != null ? (map['sodium'] as num).toDouble() : 0,
      cholesterol: map['cholesterol'] != null
          ? (map['cholesterol'] as num).toDouble()
          : 0,
      sugar: map['sugar'] != null ? (map['sugar'] as num).toDouble() : 0,
      imageUrl: map['imageUrl'] as String?,
      dateTime: DateTime.parse(map['dateTime'] as String),
    );
  }

  // 총 칼로리 검증 (계산된 값과 저장된 값 비교)
  bool get isCaloriesValid {
    int calculatedCalories = ((carbs * 4) + (protein * 4) + (fat * 9)).round();
    return (calculatedCalories - calories).abs() <= 5; // 5칼로리 오차 허용
  }

  // 영양소 비율 계산
  Map<String, double> get macroRatios {
    double totalCalories = calories.toDouble();
    return {
      'carbs': (carbs * 4) / totalCalories * 100,
      'protein': (protein * 4) / totalCalories * 100,
      'fat': (fat * 9) / totalCalories * 100,
      'sugar': (sugar * 4) / totalCalories * 100,
    };
  }
}
