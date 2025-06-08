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
    final percentage = targetCalories > 0
        ? (currentCalories / targetCalories * 100)
        : 0.0;
    final displayPercentage = percentage.clamp(0.0, 100.0);

    return SizedBox(
      width: 200,
      height: 200,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // 파이 차트
          AspectRatio(
            aspectRatio: 1,
            child: PieChart(
              PieChartData(
                sections: [
                  PieChartSectionData(
                    value: displayPercentage,
                    color: percentage > 100 ? Colors.red : Colors.orange,
                    radius: 60,
                    title: '', // 섹션 타이틀 제거
                    titleStyle: const TextStyle(fontSize: 0), // 크기를 0으로 설정
                  ),
                  if (displayPercentage < 100)
                    PieChartSectionData(
                      value: 100 - displayPercentage,
                      color: Colors.grey.shade300,
                      radius: 60,
                      title: '', // 섹션 타이틀 제거
                      titleStyle: const TextStyle(fontSize: 0),
                    ),
                ],
                sectionsSpace: 2,
                centerSpaceRadius: 50, // 중앙 공간 확대
                startDegreeOffset: -90, // 12시 방향부터 시작
              ),
            ),
          ),
          // 중앙 텍스트
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                '${percentage.toStringAsFixed(1)}%',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: percentage > 100 ? Colors.red : Colors.orange,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '${currentCalories.toStringAsFixed(0)} kcal',
                style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
