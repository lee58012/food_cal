import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:hoseo/providers/user_provider.dart';
import 'package:hoseo/providers/food_provider.dart';
import 'package:hoseo/widgets/calorie_chart.dart';
import 'package:hoseo/widgets/nutrient_card.dart';
import 'package:hoseo/widgets/food_list_item.dart';
import 'package:intl/intl.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      Provider.of<FoodProvider>(context, listen: false).loadFoods();
      Provider.of<UserProvider>(context, listen: false).loadUser();
    });
  }

  @override
  Widget build(BuildContext context) {
    final foodProvider = Provider.of<FoodProvider>(context);
    final userProvider = Provider.of<UserProvider>(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('다이어트 도우미'),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.calendar_today),
            onPressed: () async {
              final selectedDate = await showDatePicker(
                context: context,
                initialDate: foodProvider.selectedDate,
                firstDate: DateTime(2020),
                lastDate: DateTime(2030),
              );

              if (selectedDate != null) {
                foodProvider.selectDate(selectedDate);
              }
            },
          ),
        ],
      ),
      body: userProvider.isFirstTime
          ? _buildWelcomeScreen()
          : _buildHomeContent(context, foodProvider, userProvider),
    );
  }

  Widget _buildWelcomeScreen() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Image.asset('assets/images/mascot.png', height: 150),
          const SizedBox(height: 20),
          const Text(
            '환영합니다!',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 10),
          const Text('시작하기 전에 프로필을 설정해주세요', style: TextStyle(fontSize: 16)),
          const SizedBox(height: 30),
          ElevatedButton(
            onPressed: () {
              // 네비게이션 바에서 프로필 화면으로 전환
              DefaultTabController.of(context).animateTo(2);
            },
            child: const Text('프로필 설정하기'),
          ),
        ],
      ),
    );
  }

  Widget _buildHomeContent(
    BuildContext context,
    FoodProvider foodProvider,
    UserProvider userProvider,
  ) {
    final totalCalories = foodProvider.totalCaloriesForSelectedDate;
    final targetCalories = userProvider.user?.targetCalories ?? 2000;
    final remainingCalories = targetCalories - totalCalories;

    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 날짜 표시
            Text(
              DateFormat('yyyy년 MM월 dd일').format(foodProvider.selectedDate),
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 20),

            // 칼로리 카드
            Card(
              elevation: 4,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    const Text('오늘의 칼로리', style: TextStyle(fontSize: 16)),
                    const SizedBox(height: 10),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _buildCalorieInfo('목표', targetCalories, Colors.blue),
                        _buildCalorieInfo('섭취', totalCalories, Colors.orange),
                        _buildCalorieInfo(
                          '남음',
                          remainingCalories,
                          remainingCalories < 0 ? Colors.red : Colors.green,
                        ),
                      ],
                    ),
                    const SizedBox(height: 15),
                    CalorieChart(
                      consumed: totalCalories,
                      target: targetCalories,
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 20),

            // 영양소 정보
            const Text(
              '영양소 정보',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                NutrientCard(
                  title: '탄수화물',
                  value: foodProvider.totalCarbsForSelectedDate,
                  unit: 'g',
                  color: Colors.orange,
                ),
                NutrientCard(
                  title: '단백질',
                  value: foodProvider.totalProteinForSelectedDate,
                  unit: 'g',
                  color: Colors.red,
                ),
                NutrientCard(
                  title: '지방',
                  value: foodProvider.totalFatForSelectedDate,
                  unit: 'g',
                  color: Colors.blue,
                ),
              ],
            ),

            const SizedBox(height: 20),

            // 식단 목록
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  '오늘의 식단',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                TextButton(
                  onPressed: () {
                    Navigator.pushNamed(context, '/diet_plan');
                  },
                  child: const Text('식단 추천 보기'),
                ),
              ],
            ),
            const SizedBox(height: 10),

            // 식단 목록
            foodProvider.foodsForSelectedDate.isEmpty
                ? const Center(
                    child: Padding(
                      padding: EdgeInsets.all(20.0),
                      child: Text(
                        '오늘 등록된 식단이 없습니다.\n카메라로 식단을 기록해보세요!',
                        textAlign: TextAlign.center,
                      ),
                    ),
                  )
                : ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: foodProvider.foodsForSelectedDate.length,
                    itemBuilder: (context, index) {
                      final food = foodProvider.foodsForSelectedDate[index];
                      return FoodListItem(
                        food: food,
                        onTap: () {
                          Navigator.pushNamed(
                            context,
                            '/food_detail',
                            arguments: food,
                          );
                        },
                        onDelete: () {
                          if (food.id != null) {
                            foodProvider.deleteFood(food.id!);
                          }
                        },
                      );
                    },
                  ),
          ],
        ),
      ),
    );
  }

  Widget _buildCalorieInfo(String label, int value, Color color) {
    return Column(
      children: [
        Text(label, style: TextStyle(color: color)),
        const SizedBox(height: 5),
        Text(
          '$value kcal',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
      ],
    );
  }
}
