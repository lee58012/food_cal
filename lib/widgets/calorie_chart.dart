// ignore_for_file: use_super_parameters

import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';

class CalorieChart extends StatelessWidget {
  final double currentCalories;
  final double targetCalories;

  const CalorieChart({
    Key? key,
    required this.currentCalories,
    required this.targetCalories,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final percentage = (currentCalories / targetCalories * 100).clamp(
      0.0,
      100.0,
    );

    return AspectRatio(
      aspectRatio: 2,
      child: PieChart(
        PieChartData(
          sections: [
            PieChartSectionData(
              value: percentage,
              color: Colors.orange,
              radius: 40,
              title: '${percentage.toStringAsFixed(1)}%',
              titleStyle: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            if (percentage < 100)
              PieChartSectionData(
                value: 100 - percentage,
                color: Colors.grey.shade300,
                radius: 40,
              ),
          ],
          sectionsSpace: 0,
          centerSpaceRadius: 30,
        ),
      ),
    );
  }
}
