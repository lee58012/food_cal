import 'dart:io';
import 'package:flutter/material.dart';
import 'package:hoseo/models/food.dart';
import 'package:intl/intl.dart';

class FoodDetailScreen extends StatelessWidget {
  const FoodDetailScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final food = ModalRoute.of(context)!.settings.arguments as Food;

    return Scaffold(
      appBar: AppBar(title: const Text('음식 상세 정보'), centerTitle: true),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 음식 이미지
            if (food.imageUrl != null)
              SizedBox(
                width: double.infinity,
                height: 250,
                child: food.imageUrl!.startsWith('http')
                    ? Image.network(
                        food.imageUrl!,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) =>
                            const Center(child: Text('이미지를 불러올 수 없습니다')),
                      )
                    : Image.file(
                        File(food.imageUrl!),
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) =>
                            const Center(child: Text('이미지를 불러올 수 없습니다')),
                      ),
              ),

            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 음식 이름 및 섭취 시간
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          food.name,
                          style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      Text(
                        DateFormat('yyyy-MM-dd HH:mm').format(food.dateTime),
                        style: TextStyle(color: Colors.grey.shade600),
                      ),
                    ],
                  ),

                  const SizedBox(height: 20),

                  // 칼로리
                  const Text(
                    '영양 정보',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 10),

                  _buildNutrientInfo('칼로리', '${food.calories} kcal'),
                  const Divider(),

                  _buildNutrientInfo('탄수화물', '${food.carbs} g'),
                  const Divider(),

                  _buildNutrientInfo('단백질', '${food.protein} g'),
                  const Divider(),

                  _buildNutrientInfo('지방', '${food.fat} g'),

                  const SizedBox(height: 30),

                  // 운동 권장
                  _buildExerciseRecommendation(food.calories),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNutrientInfo(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 16)),
          Text(
            value,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  Widget _buildExerciseRecommendation(int calories) {
    return Card(
      elevation: 3,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '소모하려면 필요한 운동량',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            _buildExerciseItem(
              icon: Icons.directions_walk,
              activity: '걷기',
              duration: _calculateExerciseTime(calories, 5),
            ),
            _buildExerciseItem(
              icon: Icons.directions_run,
              activity: '조깅',
              duration: _calculateExerciseTime(calories, 8),
            ),
            _buildExerciseItem(
              icon: Icons.directions_bike,
              activity: '자전거',
              duration: _calculateExerciseTime(calories, 7),
            ),
            _buildExerciseItem(
              icon: Icons.pool,
              activity: '수영',
              duration: _calculateExerciseTime(calories, 10),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildExerciseItem({
    required IconData icon,
    required String activity,
    required int duration,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        children: [
          Icon(icon, color: Colors.green),
          const SizedBox(width: 10),
          Text(activity),
          const Spacer(),
          Text('$duration분'),
        ],
      ),
    );
  }

  int _calculateExerciseTime(int calories, int caloriesPerMinute) {
    return (calories / caloriesPerMinute).ceil();
  }
}
