import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:hoseo/providers/user_provider.dart';

class DietPlanScreen extends StatelessWidget {
  const DietPlanScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final userProvider = Provider.of<UserProvider>(context);
    final targetCalories = userProvider.user?.targetCalories ?? 2000;

    return Scaffold(
      appBar: AppBar(title: const Text('식단 추천'), centerTitle: true),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 마스코트 이미지
            Center(child: Image.asset('assets/images/mascot.png', height: 120)),

            const SizedBox(height: 20),

            // 타이틀
            const Text(
              '오늘의 추천 식단',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),

            Text(
              '목표 칼로리: $targetCalories kcal',
              style: TextStyle(color: Colors.grey.shade600, fontSize: 16),
            ),

            const SizedBox(height: 30),

            // 아침
            _buildMealSection(
              title: '아침',
              calories: (targetCalories * 0.3).round(),
              foods: const [
                {'name': '통곡물 식빵', 'calories': 180, 'amount': '2장'},
                {'name': '계란', 'calories': 140, 'amount': '2개'},
                {'name': '아보카도', 'calories': 160, 'amount': '1/2개'},
                {'name': '우유', 'calories': 120, 'amount': '1잔'},
              ],
            ),

            const SizedBox(height: 20),

            // 점심
            _buildMealSection(
              title: '점심',
              calories: (targetCalories * 0.4).round(),
              foods: const [
                {'name': '현미밥', 'calories': 300, 'amount': '1공기'},
                {'name': '닭가슴살', 'calories': 200, 'amount': '100g'},
                {'name': '샐러드', 'calories': 100, 'amount': '1접시'},
                {'name': '된장국', 'calories': 80, 'amount': '1그릇'},
                {'name': '김치', 'calories': 30, 'amount': '1접시'},
              ],
            ),

            const SizedBox(height: 20),

            // 저녁
            _buildMealSection(
              title: '저녁',
              calories: (targetCalories * 0.3).round(),
              foods: const [
                {'name': '연어구이', 'calories': 250, 'amount': '100g'},
                {'name': '고구마', 'calories': 150, 'amount': '1개'},
                {'name': '브로콜리', 'calories': 50, 'amount': '1접시'},
                {'name': '요거트', 'calories': 100, 'amount': '1컵'},
              ],
            ),

            const SizedBox(height: 30),

            // 주의사항
            const Card(
              elevation: 2,
              child: Padding(
                padding: EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '식단 주의사항',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 10),
                    Text('• 물을 충분히 마시는 것을 잊지 마세요 (하루 2L 이상)'),
                    Text('• 식사 시간은 20분 이상 천천히 먹는 것이 좋습니다'),
                    Text('• 과식을 피하고 배고픔이 해소되면 식사를 멈추세요'),
                    Text('• 저녁 식사는 취침 3시간 전에 마치는 것이 좋습니다'),
                    Text('• 개인 건강 상태에 따라 식단을 조절하세요'),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMealSection({
    required String title,
    required int calories,
    required List<Map<String, dynamic>> foods,
  }) {
    return Card(
      elevation: 3,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  '$calories kcal',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.green,
                  ),
                ),
              ],
            ),
            const Divider(),
            ...foods.map(
              (food) => _buildFoodItem(
                name: food['name'],
                calories: food['calories'],
                amount: food['amount'],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFoodItem({
    required String name,
    required int calories,
    required String amount,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(child: Text(name)),
          Text(amount),
          const SizedBox(width: 20),
          Text(
            '$calories kcal',
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }
}
