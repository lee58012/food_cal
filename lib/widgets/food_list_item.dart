import 'package:flutter/material.dart';
import 'package:hoseo/models/food.dart';
import 'package:intl/intl.dart';

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
      margin: const EdgeInsets.only(bottom: 10),
      child: ListTile(
        leading: food.imageUrl != null
            ? ClipRRect(
                borderRadius: BorderRadius.circular(5),
                child: Image.network(
                  food.imageUrl!,
                  width: 60,
                  height: 60,
                  fit: BoxFit.cover,
                  errorBuilder: (ctx, error, _) => Container(
                    width: 60,
                    height: 60,
                    color: Colors.grey.shade300,
                    child: const Icon(Icons.restaurant, color: Colors.grey),
                  ),
                ),
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
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.delete, color: Colors.red),
              onPressed: onDelete,
            ),
          ],
        ),
        onTap: onTap,
      ),
    );
  }
}
