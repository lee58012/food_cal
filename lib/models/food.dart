class Food {
  final int? id;
  final String name;
  final int calories;
  final double carbs;
  final double protein;
  final double fat;
  final String? imageUrl;
  final DateTime dateTime;

  Food({
    this.id,
    required this.name,
    required this.calories,
    required this.carbs,
    required this.protein,
    required this.fat,
    this.imageUrl,
    required this.dateTime,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'calories': calories,
      'carbs': carbs,
      'protein': protein,
      'fat': fat,
      'imageUrl': imageUrl,
      'dateTime': dateTime.toIso8601String(),
    };
  }

  factory Food.fromMap(Map<String, dynamic> map) {
    return Food(
      id: map['id'],
      name: map['name'],
      calories: map['calories'],
      carbs: map['carbs'],
      protein: map['protein'],
      fat: map['fat'],
      imageUrl: map['imageUrl'],
      dateTime: DateTime.parse(map['dateTime']),
    );
  }
}
