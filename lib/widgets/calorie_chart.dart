import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';

class CalorieChart extends StatelessWidget {
  final int consumed;
  final int target;

  const CalorieChart({super.key, required this.consumed, required this.target});

  @override
  Widget build(BuildContext context) {
    final percentage = target > 0
        ? (consumed / target * 100).clamp(0, 100)
        : 0.0;

    return SizedBox(
      height: 120,
      child: Stack(
        children: [
          PieChart(
            PieChartData(
              sectionsSpace: 0,
              centerSpaceRadius: 40,
              sections: [
                PieChartSectionData(
                  value: percentage.toDouble(),
                  color: _getColorForPercentage(percentage.toDouble()),
                  radius: 20.0,
                  title: '',
                ),
                PieChartSectionData(
                  value: 100 - percentage.toDouble(),
                  color: Colors.grey.shade300,
                  radius: 20,
                  title: '',
                ),
              ],
            ),
          ),
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  '${percentage.toInt()}%',
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  '$consumed / $target kcal',
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Color _getColorForPercentage(double percentage) {
    if (percentage >= 100) {
      return Colors.red;
    } else if (percentage >= 80) {
      return Colors.orange;
    } else {
      return Colors.green;
    }
  }
}
