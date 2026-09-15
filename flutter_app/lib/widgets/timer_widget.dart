import 'package:flutter/material.dart';

import '../utils/app_theme.dart';

class TimerWidget extends StatelessWidget {
  final int remainingSeconds;

  const TimerWidget({super.key, required this.remainingSeconds});

  static const _dangerThreshold = 60; // seconds — turns red once under a minute left

  @override
  Widget build(BuildContext context) {
    final isLow = remainingSeconds <= _dangerThreshold;
    final minutes = (remainingSeconds ~/ 60).toString().padLeft(2, '0');
    final seconds = (remainingSeconds % 60).toString().padLeft(2, '0');
    final color = isLow ? AppColors.danger : AppColors.primary;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.timer_outlined, size: 18, color: color),
          const SizedBox(width: 6),
          Text(
            '$minutes:$seconds',
            style: TextStyle(color: color, fontWeight: FontWeight.w700, fontFeatures: const [FontFeature.tabularFigures()]),
          ),
        ],
      ),
    );
  }
}
