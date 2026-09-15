import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/result_model.dart';
import '../utils/app_theme.dart';

/// Compact summary tile for a single attempt — used in the history list.
class ResultCard extends StatelessWidget {
  final ResultModel result;
  final VoidCallback? onTap;

  const ResultCard({super.key, required this.result, this.onTap});

  @override
  Widget build(BuildContext context) {
    final passColor = result.passed ? AppColors.success : AppColors.danger;
    final dateFmt = DateFormat('MMM d, y');

    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Row(
            children: [
              CircleAvatar(
                radius: 22,
                backgroundColor: passColor.withValues(alpha: 0.12),
                child: Text(result.grade, style: TextStyle(color: passColor, fontWeight: FontWeight.w800)),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(result.examTitle, style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
                    const SizedBox(height: 2),
                    Text(
                      '${result.score.toStringAsFixed(1)} pts • ${result.percentage.toStringAsFixed(1)}%'
                      '${result.submittedAt != null ? ' • ${dateFmt.format(result.submittedAt!)}' : ''}',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.neutral),
                    ),
                  ],
                ),
              ),
              Chip(
                label: Text(result.status),
                backgroundColor: passColor.withValues(alpha: 0.15),
                labelStyle: TextStyle(color: passColor, fontWeight: FontWeight.w700),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
