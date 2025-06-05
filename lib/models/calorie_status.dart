import 'package:flutter/material.dart';

class CalorieStatus {
  final String message;
  final Color color;

  const CalorieStatus({required this.message, required this.color});

  factory CalorieStatus.fromPercentage(double percentage) {
    if (percentage >= 100) {
      return const CalorieStatus(message: '목표 초과', color: Colors.red);
    } else if (percentage >= 80) {
      return const CalorieStatus(message: '목표 근접', color: Colors.orange);
    } else if (percentage >= 50) {
      return const CalorieStatus(message: '적정 섭취', color: Colors.green);
    } else {
      return const CalorieStatus(message: '섭취 부족', color: Colors.blue);
    }
  }
}
