import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../models/exam_model.dart';
import '../../providers/exam_provider.dart';
import '../../utils/app_theme.dart';
import 'exam_screen.dart';
import 'result_screen.dart';

class ExamListScreen extends StatefulWidget {
  const ExamListScreen({super.key});

  @override
  State<ExamListScreen> createState() => _ExamListScreenState();
}

class _ExamListScreenState extends State<ExamListScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => context.read<ExamProvider>().fetchStudentExams());
  }

  Future<void> _startExam(ExamModel exam) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(exam.title),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Duration: ${exam.duration} minutes • ${exam.totalQuestions} questions • ${exam.totalMarks} marks'),
              if (exam.negativeMarkingEnabled) Text('Negative marking: ${exam.negativeMarking} per wrong answer'),
              if (exam.instructions.isNotEmpty) ...[
                const SizedBox(height: AppSpacing.sm),
                Text(exam.instructions),
              ],
              const SizedBox(height: AppSpacing.sm),
              const Text('Once started, the timer cannot be paused. Ready?', style: TextStyle(fontWeight: FontWeight.w600)),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Start')),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    final data = await context.read<ExamProvider>().startExam(exam.id);
    if (!mounted) return;

    if (data == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.read<ExamProvider>().attemptError ?? 'Could not start exam.'), backgroundColor: AppColors.danger),
      );
      return;
    }

    final result = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => ExamScreen(examId: exam.id, data: data)),
    );

    if (result == true && mounted) {
      context.read<ExamProvider>().fetchStudentExams();
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ExamProvider>();

    return Scaffold(
      appBar: AppBar(title: const Text('My Exams')),
      body: RefreshIndicator(
        onRefresh: () => provider.fetchStudentExams(),
        child: provider.isLoadingExams
            ? const Center(child: CircularProgressIndicator())
            : provider.exams.isEmpty
                ? ListView(
                    children: [
                      const SizedBox(height: 120),
                      Icon(
                        provider.listError != null ? Icons.error_outline : Icons.assignment_outlined,
                        size: 56,
                        color: provider.listError != null ? AppColors.danger : AppColors.neutral.withValues(alpha: 0.5),
                      ),
                      const SizedBox(height: AppSpacing.md),
                      Center(child: Text(provider.listError ?? 'No exams available yet.', textAlign: TextAlign.center)),
                    ],
                  )
                : ListView.separated(
                    padding: const EdgeInsets.all(AppSpacing.md),
                    itemCount: provider.exams.length,
                    separatorBuilder: (context, index) => const SizedBox(height: AppSpacing.sm),
                    itemBuilder: (context, i) => _ExamTile(
                      exam: provider.exams[i],
                      onStart: () => _startExam(provider.exams[i]),
                    ),
                  ),
      ),
    );
  }
}

class _ExamTile extends StatelessWidget {
  final ExamModel exam;
  final VoidCallback onStart;
  const _ExamTile({required this.exam, required this.onStart});

  @override
  Widget build(BuildContext context) {
    final dateFmt = DateFormat('MMM d, y • h:mm a');

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(child: Text(exam.title, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700))),
                _statusChip(),
              ],
            ),
            const SizedBox(height: 2),
            Text(exam.subject, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.neutral)),
            const SizedBox(height: AppSpacing.sm),
            Wrap(spacing: AppSpacing.md, runSpacing: 4, children: [
              _meta(context, Icons.quiz_outlined, '${exam.totalQuestions} Qs'),
              _meta(context, Icons.timer_outlined, '${exam.duration} min'),
              _meta(context, Icons.grade_outlined, '${exam.totalMarks} marks'),
            ]),
            const SizedBox(height: AppSpacing.xs),
            Text('Ends ${dateFmt.format(exam.endDate)}', style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.neutral)),
            const SizedBox(height: AppSpacing.md),
            SizedBox(width: double.infinity, child: _actionButton(context)),
          ],
        ),
      ),
    );
  }

  Widget _meta(BuildContext context, IconData icon, String label) {
    return Row(mainAxisSize: MainAxisSize.min, children: [
      Icon(icon, size: 14, color: AppColors.neutral),
      const SizedBox(width: 4),
      Text(label, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.neutral)),
    ]);
  }

  Widget _statusChip() {
    final (label, color) = exam.attempted
        ? ('Completed', AppColors.success)
        : exam.hasEnded
            ? ('Ended', AppColors.neutral)
            : exam.isActive
                ? ('Active', AppColors.success)
                : ('Upcoming', AppColors.warning);
    return Chip(label: Text(label), backgroundColor: color.withValues(alpha: 0.15), labelStyle: TextStyle(color: color, fontWeight: FontWeight.w700));
  }

  Widget _actionButton(BuildContext context) {
    if (exam.attempted) {
      return OutlinedButton.icon(
        icon: const Icon(Icons.bar_chart_rounded, size: 18),
        label: const Text('View result'),
        onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => ResultScreen(examId: exam.id))),
      );
    }
    if (exam.isActive) {
      return ElevatedButton.icon(icon: const Icon(Icons.play_arrow_rounded), label: const Text('Start exam'), onPressed: onStart);
    }
    if (exam.isUpcoming) {
      return OutlinedButton(onPressed: null, child: Text('Starts ${DateFormat('MMM d, h:mm a').format(exam.startDate)}'));
    }
    return const OutlinedButton(onPressed: null, child: Text('Missed'));
  }
}
