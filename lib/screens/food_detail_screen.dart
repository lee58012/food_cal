// ignore_for_file: use_build_context_synchronously, unused_import

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:hoseo/models/food.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:hoseo/providers/food_provider.dart';
import 'package:hoseo/utils/image_helper.dart';

class FoodDetailScreen extends StatefulWidget {
  const FoodDetailScreen({super.key});

  @override
  State<FoodDetailScreen> createState() => _FoodDetailScreenState();
}

class _FoodDetailScreenState extends State<FoodDetailScreen> {
  @override
  Widget build(BuildContext context) {
    final food = ModalRoute.of(context)!.settings.arguments as Food;

    return Scaffold(
      appBar: AppBar(
        title: const Text('음식 상세 정보'),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.delete, color: Colors.red),
            onPressed: () => _deleteFood(context, food),
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 음식 이미지
            if (food.imageUrl != null)
              SizedBox(
                width: double.infinity,
                height: 250,
                child: ImageHelper.buildImage(
                  food.imageUrl,
                  width: double.infinity,
                  height: 250,
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
                  const Divider(),

                  _buildNutrientInfo('총당류', '${food.sugar} g'),
                  const Divider(),

                  _buildNutrientInfo('나트륨', '${food.sodium} mg'),
                  const Divider(),

                  _buildNutrientInfo('콜레스테롤', '${food.cholesterol} mg'),

                  const SizedBox(height: 30),
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

  void _deleteFood(BuildContext context, Food food) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('식단 삭제'),
        content: const Text('이 식단을 삭제하시겠습니까?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('취소'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('삭제', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed == true && food.id != null) {
      try {
        final foodProvider = Provider.of<FoodProvider>(context, listen: false);
        await foodProvider.deleteFood(food.id!);

        // 삭제 후 데이터 갱신을 위해 잠시 대기
        await Future.delayed(const Duration(milliseconds: 300));

        // 홈 화면으로 이동 전에 현재 날짜의 데이터 갱신 확인
        await foodProvider.loadFoodsByDate(foodProvider.selectedDate);

        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('식단이 삭제되었습니다')));
          Navigator.of(context).pop(); // 상세 화면 닫기
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('식단 삭제 중 오류가 발생했습니다: $e')));
        }
      }
    }
  }
}
