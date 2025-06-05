// ignore_for_file: use_super_parameters

import 'package:flutter/material.dart';

class NutrientCard extends StatelessWidget {
  final String title;
  final double value;
  final String unit;

  const NutrientCard({
    Key? key,
    required this.title,
    required this.value,
    required this.unit,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              title,
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              '${value.toStringAsFixed(1)}$unit',
              style: const TextStyle(fontSize: 16),
            ),
          ],
        ),
      ),
    );
  }
}
