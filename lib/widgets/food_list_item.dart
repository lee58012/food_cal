import 'package:flutter/material.dart';
import 'package:hoseo/models/food.dart';
import 'package:intl/intl.dart';
import 'package:hoseo/utils/image_helper.dart';

class FoodListItem extends StatelessWidget {
  final Food food;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  const FoodListItem({
    super.key,
    required this.food,
    required this.onTap,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(12.0),
          child: Row(
            children: [
              // 음식 이미지
              Container(
                width: 70,
                height: 70,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  image: food.imageUrl != null
                      ? _getImageProvider(food.imageUrl!)
                      : null,
                  color: Colors.grey.shade200,
                ),
                child: food.imageUrl == null
                    ? const Icon(Icons.fastfood, color: Colors.grey)
                    : null,
              ),
              const SizedBox(width: 16),
              // 음식 정보
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      food.food_name,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${food.calories} kcal',
                      style: const TextStyle(
                        fontSize: 14,
                        color: Colors.orange,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // 첫 번째 줄: 탄수화물, 단백질, 지방
                        Text(
                          '탄수화물: ${food.carbs.toStringAsFixed(1)}g · 단백질: ${food.protein.toStringAsFixed(1)}g · 지방: ${food.fat.toStringAsFixed(1)}g',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade600,
                          ),
                        ),
                        const SizedBox(height: 2),
                        // 두 번째 줄: 당류, 나트륨, 콜레스테롤
                        Text(
                          '당류: ${food.sugar.toStringAsFixed(1)}g · 나트륨: ${food.sodium.toStringAsFixed(0)}mg · 콜레스테롤: ${food.cholesterol.toStringAsFixed(0)}mg',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      DateFormat('HH:mm').format(food.dateTime),
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade500,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ],
                ),
              ),
              // 삭제 버튼
              IconButton(
                icon: const Icon(Icons.delete_outline, color: Colors.red),
                onPressed: onDelete,
              ),
            ],
          ),
        ),
      ),
    );
  }

  DecorationImage? _getImageProvider(String imageUrl) {
    return ImageHelper.getDecorationImage(imageUrl);
  }
}
