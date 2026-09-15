import 'package:flutter/material.dart';

import '../utils/app_theme.dart';

enum QuestionStatus { notVisited, notAnswered, answered, markedForReview }

class QuestionPalette extends StatelessWidget {
  final int totalQuestions;
  final int currentIndex;
  final List<QuestionStatus> statuses; // length == totalQuestions
  final ValueChanged<int> onSelect;

  const QuestionPalette({
    super.key,
    required this.totalQuestions,
    required this.currentIndex,
    required this.statuses,
    required this.onSelect,
  });

  Color _colorFor(QuestionStatus status) {
    switch (status) {
      case QuestionStatus.answered:
        return AppColors.success;
      case QuestionStatus.notAnswered:
        return AppColors.danger;
      case QuestionStatus.markedForReview:
        return AppColors.warning;
      case QuestionStatus.notVisited:
        return AppColors.neutral.withValues(alpha: 0.35);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.xs,
          children: const [
            _LegendDot(color: AppColors.success, label: 'Answered'),
            _LegendDot(color: AppColors.danger, label: 'Not answered'),
            _LegendDot(color: AppColors.warning, label: 'Marked for review'),
            _LegendDot(color: AppColors.neutral, label: 'Not visited'),
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: totalQuestions,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 5,
            mainAxisSpacing: AppSpacing.sm,
            crossAxisSpacing: AppSpacing.sm,
            childAspectRatio: 1,
          ),
          itemBuilder: (context, index) {
            final isCurrent = index == currentIndex;
            final color = _colorFor(statuses[index]);
            return InkWell(
              borderRadius: BorderRadius.circular(10),
              onTap: () => onSelect(index),
              child: Container(
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: isCurrent ? Theme.of(context).colorScheme.primary : color, width: isCurrent ? 2 : 1),
                ),
                alignment: Alignment.center,
                child: Text('${index + 1}', style: TextStyle(color: color, fontWeight: FontWeight.w700)),
              ),
            );
          },
        ),
      ],
    );
  }
}

class _LegendDot extends StatelessWidget {
  final Color color;
  final String label;
  const _LegendDot({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(mainAxisSize: MainAxisSize.min, children: [
      Container(width: 10, height: 10, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
      const SizedBox(width: 4),
      Text(label, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.neutral)),
    ]);
  }
}
