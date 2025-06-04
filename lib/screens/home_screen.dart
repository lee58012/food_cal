import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:hoseo/providers/user_provider.dart';
import 'package:hoseo/providers/food_provider.dart';
import 'package:hoseo/widgets/calorie_chart.dart';
import 'package:hoseo/widgets/nutrient_card.dart';
import 'package:hoseo/widgets/food_list_item.dart';
import 'package:intl/intl.dart';
import 'package:hoseo/main.dart';
import 'dart:convert';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  int _currentCalories = 0;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadData();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // 화면이 포커스를 받을 때마다 데이터 갱신
    _updateCalorieData();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // 앱이 포그라운드로 돌아올 때 데이터 갱신
      _loadData();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
    });

    try {
      await Provider.of<UserProvider>(context, listen: false).loadUser();
      await Provider.of<FoodProvider>(context, listen: false).loadFoods();
      await _updateCalorieData();
    } catch (e) {
      print('데이터 로드 오류: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _updateCalorieData() async {
    final foodProvider = Provider.of<FoodProvider>(context, listen: false);
    final selectedDate = foodProvider.selectedDate;

    try {
      final calories = await foodProvider.getDailyCalorieIntake(selectedDate);
      if (mounted) {
        setState(() {
          _currentCalories = calories;
        });
      }
    } catch (e) {
      print('칼로리 데이터 업데이트 오류: $e');
      // 오류 발생 시 로컬 계산값 사용
      if (mounted) {
        setState(() {
          _currentCalories = foodProvider.totalCaloriesForSelectedDate;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final foodProvider = Provider.of<FoodProvider>(context);
    final userProvider = Provider.of<UserProvider>(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Hoseo Food'),
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
                _updateCalorieData(); // 날짜 변경 시 칼로리 데이터 업데이트
              }
            },
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _isLoading ? null : _loadData,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : userProvider.isFirstTime
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
              // 전역 키를 사용하여 프로필 탭으로 이동
              mainScreenKey.currentState?.navigateToTab(2);
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
    // Firestore에서 가져온 실시간 칼로리 데이터 사용
    final totalCalories = _currentCalories;
    final targetCalories = userProvider.user?.targetCalories ?? 2000;
    final remainingCalories = targetCalories - totalCalories;

    // 사용자 프로필 데이터
    final userName = userProvider.user?.name ?? '사용자';
    final userWeight = userProvider.user?.weight ?? 0;
    final userHeight = userProvider.user?.height ?? 0;
    final userAge = userProvider.user?.age ?? 0;
    final userGender = userProvider.user?.gender ?? '남성';
    final userActivityLevel = userProvider.user?.activityLevel ?? 2;
    final userMedicalCondition = userProvider.user?.medicalCondition ?? '정상';
    final userPhotoUrl = userProvider.user?.photoUrl;

    // 칼로리 비율 계산 (목표 대비 섭취량)
    final caloriePercentage = totalCalories / targetCalories * 100;
    final calorieStatus = _getCalorieStatus(caloriePercentage);

    return RefreshIndicator(
      onRefresh: _loadData,
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 사용자 인사말
              Row(
                children: [
                  CircleAvatar(
                    radius: 24,
                    backgroundImage: _getProfileImage(userPhotoUrl),
                    child: userPhotoUrl == null
                        ? const Icon(Icons.person)
                        : null,
                  ),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '$userName님, 안녕하세요!',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        DateFormat(
                          'yyyy년 MM월 dd일',
                        ).format(foodProvider.selectedDate),
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // 칼로리 요약 카드
              Card(
                elevation: 4,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            '오늘의 칼로리',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: calorieStatus.color.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              calorieStatus.message,
                              style: TextStyle(
                                color: calorieStatus.color,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      CalorieChart(
                        consumed: totalCalories,
                        target: targetCalories,
                      ),
                      const SizedBox(height: 16),
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
                      if (userMedicalCondition != '정상') ...[
                        const SizedBox(height: 16),
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.blue.shade50,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            '$userMedicalCondition 상태를 고려한 칼로리입니다',
                            style: TextStyle(
                              color: Colors.blue.shade700,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 20),

              // 사용자 프로필 요약
              Card(
                elevation: 2,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        '내 프로필 정보',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          _buildProfileInfo(
                            Icons.monitor_weight,
                            '${userWeight.toStringAsFixed(1)} kg',
                          ),
                          _buildProfileInfo(
                            Icons.height,
                            '${userHeight.toStringAsFixed(1)} cm',
                          ),
                          _buildProfileInfo(Icons.cake, '$userAge세'),
                          _buildProfileInfo(
                            userGender == '남성' ? Icons.male : Icons.female,
                            userGender,
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Center(
                        child: TextButton(
                          onPressed: () {
                            mainScreenKey.currentState?.navigateToTab(2);
                          },
                          child: const Text('프로필 수정하기'),
                        ),
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
                  TextButton.icon(
                    onPressed: () {
                      mainScreenKey.currentState?.navigateToTab(1);
                    },
                    icon: const Icon(Icons.add_a_photo),
                    label: const Text('식단 추가'),
                  ),
                ],
              ),
              const SizedBox(height: 10),

              // 식단 목록
              foodProvider.foodsForSelectedDate.isEmpty
                  ? Center(
                      child: Container(
                        padding: const EdgeInsets.all(32),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Column(
                          children: [
                            Icon(
                              Icons.no_food,
                              size: 48,
                              color: Colors.grey.shade400,
                            ),
                            const SizedBox(height: 16),
                            const Text(
                              '오늘 등록된 식단이 없습니다.\n카메라로 식단을 기록해보세요!',
                              textAlign: TextAlign.center,
                              style: TextStyle(color: Colors.grey),
                            ),
                          ],
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
                          onDelete: () async {
                            if (food.id != null) {
                              await foodProvider.deleteFood(food.id!);
                              // 음식 삭제 후 칼로리 데이터 업데이트
                              _updateCalorieData();
                            }
                          },
                        );
                      },
                    ),
            ],
          ),
        ),
      ),
    );
  }

  // Base64 이미지 또는 네트워크 이미지를 처리하는 메서드
  ImageProvider? _getProfileImage(String? photoUrl) {
    if (photoUrl == null) {
      return null;
    }

    if (photoUrl.startsWith('data:image')) {
      try {
        // Base64 이미지 처리
        final base64Str = photoUrl.split(',')[1];
        return MemoryImage(base64Decode(base64Str));
      } catch (e) {
        print('Base64 이미지 처리 오류: $e');
        return null;
      }
    } else if (photoUrl.startsWith('http')) {
      // 네트워크 이미지 처리
      return NetworkImage(photoUrl);
    }

    return null;
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

  Widget _buildProfileInfo(IconData icon, String text) {
    return Column(
      children: [
        Icon(icon, color: Colors.green),
        const SizedBox(height: 4),
        Text(text, style: const TextStyle(fontSize: 12)),
      ],
    );
  }

  CalorieStatus _getCalorieStatus(double percentage) {
    if (percentage < 50) {
      return CalorieStatus('부족', Colors.red);
    } else if (percentage < 80) {
      return CalorieStatus('양호', Colors.orange);
    } else if (percentage < 100) {
      return CalorieStatus('좋음', Colors.green);
    } else if (percentage < 120) {
      return CalorieStatus('초과', Colors.orange);
    } else {
      return CalorieStatus('과다', Colors.red);
    }
  }
}

class CalorieStatus {
  final String message;
  final Color color;

  CalorieStatus(this.message, this.color);
}
