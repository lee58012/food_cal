// ignore_for_file: deprecated_member_use, use_build_context_synchronously, duplicate_ignore, unused_import, sized_box_for_whitespace, use_super_parameters

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:hoseo/providers/user_provider.dart';
import 'package:hoseo/providers/food_provider.dart';
import 'package:hoseo/widgets/calorie_chart.dart';
import 'package:hoseo/widgets/food_list_item.dart';
import 'package:intl/intl.dart';
import 'package:hoseo/main.dart';
import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:async';
import 'package:hoseo/utils/image_helper.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  double _currentCalories = 0.0;
  bool _isLoading = false;
  StreamSubscription? _foodsSubscription;
  StreamSubscription? _userSubscription;
  DateTime _lastSelectedDate = DateTime.now();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    // 데이터 로드 후 구독 설정
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _loadData().then((_) {
          _setupSubscriptions();
        });
      }
    });
  }

  // didChangeDependencies에서 불필요한 호출 제거 - 깜빡임 방지
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // _updateCalorieData(); // 이 줄 삭제 - 깜빡임 원인
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _loadData();
    }
  }

  void _setupSubscriptions() {
    final user = Provider.of<UserProvider>(context, listen: false).user;
    if (user?.uid != null) {
      // 이미 구독이 활성화되어 있으면 중복 생성 방지
      if (_foodsSubscription != null) return;

      // 전체 음식 데이터에 대한 구독
      _foodsSubscription = FirebaseFirestore.instance
          .collection('users')
          .doc(user!.uid)
          .collection('foods')
          .snapshots()
          .listen(
            (snapshot) async {
              if (mounted) {
                // 디바운싱을 위한 지연 추가
                await Future.delayed(const Duration(milliseconds: 200));

                if (mounted) {
                  final foodProvider = Provider.of<FoodProvider>(
                    context,
                    listen: false,
                  );
                  await foodProvider.loadFoods();
                  await foodProvider.loadFoodsByDate(foodProvider.selectedDate);
                  await _updateCalorieData();
                }
              }
            },
            onError: (error) {},
            cancelOnError: false,
          );
    }
  }

  @override
  void dispose() {
    _foodsSubscription?.cancel();
    _userSubscription?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  Future<void> _loadData() async {
    if (!mounted) return;

    setState(() {
      _isLoading = true;
    });

    try {
      await Provider.of<UserProvider>(context, listen: false).loadUser();

      // 전체 데이터를 로드하도록 수정
      final foodProvider = Provider.of<FoodProvider>(context, listen: false);
      await foodProvider.loadFoods();

      // 현재 선택된 날짜의 데이터도 함께 로드
      await foodProvider.loadFoodsByDate(foodProvider.selectedDate);

      await _updateCalorieData();
    } catch (e) {
      debugPrint('데이터 로드 오류: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  // 수정된 _updateCalorieData 메서드
  Future<void> _updateCalorieData() async {
    if (!mounted) return;

    final foodProvider = Provider.of<FoodProvider>(context, listen: false);

    try {
      // 선택된 날짜가 변경된 경우에만 데이터 로드
      if (_lastSelectedDate != foodProvider.selectedDate) {
        await foodProvider.loadFoodsByDate(foodProvider.selectedDate);
        _lastSelectedDate = foodProvider.selectedDate;
      }

      // 캐시된 칼로리 데이터 사용 - double 타입으로 변경
      final localCalories = foodProvider.totalCaloriesForSelectedDate;

      // 값이 실제로 변경된 경우에만 setState 호출
      if (_currentCalories != localCalories) {
        if (mounted) {
          setState(() {
            _currentCalories = localCalories;
          });
        }
      }
    } catch (e) {
      // 오류 발생 시에도 값이 다른 경우에만 setState
      if (mounted && _currentCalories != 0.0) {
        setState(() {
          _currentCalories = 0.0;
        });
      }
    }
  }

  // 목표량 계산 메서드들
  double _getTargetCarbs(UserProvider userProvider) {
    final targetCalories = userProvider.user?.targetCalories ?? 2000;
    // 탄수화물은 총 칼로리의 45-65% (평균 55%)
    return (targetCalories * 0.55) / 4.0; // 탄수화물 1g = 4kcal
  }

  double _getTargetProtein(UserProvider userProvider) {
    final weight = userProvider.user?.weight ?? 70.0;
    // 단백질은 체중 1kg당 0.8-1.2g (평균 1.0g)
    return weight * 1.0;
  }

  double _getTargetFat(UserProvider userProvider) {
    final targetCalories = userProvider.user?.targetCalories ?? 2000;
    // 지방은 총 칼로리의 20-35% (평균 30%)
    return (targetCalories * 0.30) / 9.0; // 지방 1g = 9kcal
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
                await foodProvider.selectDate(selectedDate);
                await _updateCalorieData();
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
    final totalCalories = _currentCalories;
    final targetCalories = (userProvider.user?.targetCalories ?? 2000)
        .toDouble();
    final remainingCalories = targetCalories - totalCalories;

    final userName = userProvider.user?.name?.isNotEmpty == true
        ? userProvider.user!.name!
        : '사용자';
    final userWeight = (userProvider.user?.weight ?? 0.0).toDouble();
    final userHeight = (userProvider.user?.height ?? 0.0).toDouble();
    final userAge = userProvider.user?.age ?? 0;
    final userGender = userProvider.user?.gender ?? '남성';
    final userMedicalCondition = userProvider.user?.medicalCondition ?? '정상';
    final userPhotoUrl = userProvider.user?.photoUrl;

    final caloriePercentage = targetCalories > 0
        ? (totalCalories / targetCalories * 100)
        : 0.0;
    final calorieStatus = _getCalorieStatus(caloriePercentage);

    return RefreshIndicator(
      onRefresh: _loadData,
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 사용자 인사말 - RepaintBoundary로 감싸기
              RepaintBoundary(
                child: Row(
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
              ),
              const SizedBox(height: 24),

              // 칼로리 요약 카드 - 수정된 부분
              RepaintBoundary(
                child: Card(
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
                          currentCalories: totalCalories,
                          targetCalories: targetCalories,
                        ),
                        const SizedBox(height: 16),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceAround,
                          children: [
                            _buildCalorieInfo(
                              '목표',
                              targetCalories,
                              Colors.blue,
                            ),
                            _buildCalorieInfo(
                              '섭취',
                              totalCalories,
                              Colors.orange,
                            ),
                            Column(
                              children: [
                                Text(
                                  '남음',
                                  style: TextStyle(
                                    color: remainingCalories < 0
                                        ? Colors.red
                                        : Colors.green,
                                  ),
                                ),
                                const SizedBox(height: 5),
                                Text(
                                  '${remainingCalories.toStringAsFixed(1)} kcal',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: remainingCalories < 0
                                        ? Colors.red
                                        : Colors.green,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ],
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
              ),

              const SizedBox(height: 20),

              // 사용자 프로필 요약
              RepaintBoundary(
                child: Card(
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
              ),

              const SizedBox(height: 20),

              // 영양소 정보 - 간단한 카드로 교체
              RepaintBoundary(
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          '영양소 정보',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.blue.shade50,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.info_outline,
                                size: 16,
                                color: Colors.blue.shade700,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                '목표량 대비',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.blue.shade700,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // 영양소 카드들을 간단한 Card로 교체
                    Column(
                      children: [
                        // 첫 번째 행: 탄수화물, 단백질
                        Row(
                          children: [
                            Expanded(
                              child: _buildSimpleNutrientCard(
                                '탄수화물',
                                foodProvider.totalCarbsForSelectedDate,
                                'g',
                                Colors.orange.shade100,
                                Colors.orange,
                                _getTargetCarbs(userProvider),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: _buildSimpleNutrientCard(
                                '단백질',
                                foodProvider.totalProteinForSelectedDate,
                                'g',
                                Colors.red.shade100,
                                Colors.red,
                                _getTargetProtein(userProvider),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),

                        // 두 번째 행: 지방, 당류
                        Row(
                          children: [
                            Expanded(
                              child: _buildSimpleNutrientCard(
                                '지방',
                                foodProvider.totalFatForSelectedDate,
                                'g',
                                Colors.blue.shade100,
                                Colors.blue,
                                _getTargetFat(userProvider),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: _buildSimpleNutrientCard(
                                '당류',
                                foodProvider.totalSugarForSelectedDate,
                                'g',
                                Colors.purple.shade100,
                                Colors.purple,
                                50.0,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),

                        // 세 번째 행: 나트륨, 콜레스테롤
                        Row(
                          children: [
                            Expanded(
                              child: _buildSimpleNutrientCard(
                                '나트륨',
                                foodProvider.totalSodiumForSelectedDate,
                                'mg',
                                Colors.green.shade100,
                                Colors.green,
                                2300.0,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: _buildSimpleNutrientCard(
                                '콜레스테롤',
                                foodProvider.totalCholesterolForSelectedDate,
                                'mg',
                                Colors.teal.shade100,
                                Colors.teal,
                                300.0,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
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
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '총 ${foodProvider.foodsForSelectedDate.length}개의 식단',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey.shade600,
                          ),
                        ),
                        const SizedBox(height: 8),
                        ListView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: foodProvider.foodsForSelectedDate.length,
                          itemBuilder: (context, index) {
                            final food =
                                foodProvider.foodsForSelectedDate[index];
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
                                  try {
                                    await foodProvider.deleteFood(food.id!);

                                    // 삭제 후 즉시 칼로리 업데이트
                                    if (mounted) {
                                      final newCalories = foodProvider
                                          .totalCaloriesForSelectedDate;
                                      setState(() {
                                        _currentCalories = newCalories;
                                      });
                                    }

                                    if (mounted) {
                                      ScaffoldMessenger.of(
                                        context,
                                      ).showSnackBar(
                                        SnackBar(
                                          content: Text(
                                            '${food.name}이(가) 삭제되었습니다.',
                                          ),
                                          backgroundColor: Colors.green,
                                        ),
                                      );
                                    }
                                  } catch (e) {
                                    if (mounted) {
                                      ScaffoldMessenger.of(
                                        context,
                                      ).showSnackBar(
                                        SnackBar(
                                          content: Text('삭제 중 오류가 발생했습니다: $e'),
                                          backgroundColor: Colors.red,
                                        ),
                                      );
                                    }
                                  }
                                }
                              },
                            );
                          },
                        ),
                      ],
                    ),
            ],
          ),
        ),
      ),
    );
  }

  ImageProvider? _getProfileImage(String? photoUrl) {
    return ImageHelper.getImageProvider(photoUrl);
  }

  // 수정된 _buildCalorieInfo 메서드
  Widget _buildCalorieInfo(String label, double value, Color color) {
    return Column(
      children: [
        Text(label, style: TextStyle(color: color)),
        const SizedBox(height: 5),
        Text(
          '${value.toStringAsFixed(1)} kcal',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: color,
          ),
          textAlign: TextAlign.center,
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

  // 간단한 영양소 카드 위젯
  Widget _buildSimpleNutrientCard(
    String title,
    double value,
    String unit,
    Color backgroundColor,
    Color iconColor,
    double targetValue,
  ) {
    final percentage = targetValue > 0 ? (value / targetValue * 100) : 0.0;

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Container(
        decoration: BoxDecoration(
          color: backgroundColor,
          borderRadius: BorderRadius.circular(12),
        ),
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.circle, size: 12, color: iconColor),
                const SizedBox(width: 4),
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              '${value.toStringAsFixed(1)} $unit',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: iconColor,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '목표: ${targetValue.toStringAsFixed(1)} $unit',
              style: TextStyle(fontSize: 10, color: Colors.grey.shade600),
            ),
            const SizedBox(height: 8),
            LinearProgressIndicator(
              value: (percentage / 100).clamp(0.0, 1.0),
              backgroundColor: Colors.grey.shade300,
              valueColor: AlwaysStoppedAnimation<Color>(iconColor),
            ),
            const SizedBox(height: 4),
            Text(
              '${percentage.toStringAsFixed(1)}%',
              style: TextStyle(
                fontSize: 10,
                color: iconColor,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
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
