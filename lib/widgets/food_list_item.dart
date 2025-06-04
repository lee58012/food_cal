import 'package:flutter/material.dart';
import 'package:hoseo/models/food.dart';
import 'package:intl/intl.dart';
import 'dart:convert';

class FoodListItem extends StatelessWidget {
  final Food food;
  final VoidCallback? onTap;
  final VoidCallback? onDelete;

  const FoodListItem({
    super.key,
    required this.food,
    this.onTap,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: ListTile(
        leading: food.imageUrl != null
            ? ClipRRect(
                borderRadius: BorderRadius.circular(5),
                child: _buildFoodImage(food.imageUrl!),
              )
            : Container(
                width: 60,
                height: 60,
                color: Colors.grey.shade300,
                child: const Icon(Icons.restaurant, color: Colors.grey),
              ),
        title: Text(
          food.name,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('${food.calories} kcal'),
            Text(
              DateFormat('yyyy-MM-dd HH:mm').format(food.dateTime),
              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
            ),
          ],
        ),
        trailing: onDelete != null
            ? IconButton(
                icon: const Icon(Icons.delete, color: Colors.red),
                onPressed: onDelete,
              )
            : null,
        onTap: onTap,
      ),
    );
  }

  // 이미지 유형에 따라 적절한 위젯 반환
  Widget _buildFoodImage(String imageUrl) {
    if (imageUrl.startsWith('data:image')) {
      try {
        // Base64 이미지 처리
        final base64Str = imageUrl.split(',')[1];
        final imageBytes = base64Decode(base64Str);
        return Image.memory(
          imageBytes,
          width: 60,
          height: 60,
          fit: BoxFit.cover,
          errorBuilder: (ctx, error, _) {
            print('Base64 이미지 로드 오류: $error');
            return _buildErrorImage();
          },
        );
      } catch (e) {
        print('Base64 이미지 처리 오류: $e');
        return _buildErrorImage();
      }
    } else if (imageUrl.startsWith('http')) {
      // 네트워크 이미지 처리
      return Image.network(
        imageUrl,
        width: 60,
        height: 60,
        fit: BoxFit.cover,
        loadingBuilder: (context, child, loadingProgress) {
          if (loadingProgress == null) return child;
          return Center(
            child: CircularProgressIndicator(
              value: loadingProgress.expectedTotalBytes != null
                  ? loadingProgress.cumulativeBytesLoaded /
                        loadingProgress.expectedTotalBytes!
                  : null,
            ),
          );
        },
        errorBuilder: (ctx, error, _) {
          print('네트워크 이미지 로드 오류: $error');
          return _buildErrorImage();
        },
      );
    } else {
      // 기타 케이스 (로컬 파일 등)
      return _buildErrorImage();
    }
  }

  // 이미지 로드 실패 시 표시할 위젯
  Widget _buildErrorImage() {
    return Container(
      width: 60,
      height: 60,
      color: Colors.grey.shade300,
      child: const Icon(Icons.restaurant, color: Colors.grey),
    );
  }
}
