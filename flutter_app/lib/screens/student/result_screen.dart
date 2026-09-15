import 'dart:io';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';

import '../../models/result_model.dart';
import '../../providers/result_provider.dart';
import '../../utils/app_theme.dart';

class ResultScreen extends StatefulWidget {
  final String examId;
  final ResultModel? freshResult;
  const ResultScreen({super.key, required this.examId, this.freshResult});

  @override
  State<ResultScreen> createState() => _ResultScreenState();
}

class _ResultScreenState extends State<ResultScreen> {
  @override
  void initState() {
    super.initState();
    if (widget.freshResult != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) => context.read<ResultProvider>().setResult(widget.freshResult!));
    } else {
      WidgetsBinding.instance.addPostFrameCallback((_) => context.read<ResultProvider>().fetchResult(widget.examId));
    }
  }

  Future<void> _downloadPdf(ResultModel result) async {
    final provider = context.read<ResultProvider>();
    final url = await provider.generatePdf(result.id);
    if (!mounted) return;

    if (url == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(provider.resultError ?? 'Could not generate PDF.'), backgroundColor: AppColors.danger),
      );
      return;
    }

    try {
      final response = await http.get(Uri.parse(url));
      final dir = await getApplicationDocumentsDirectory();
      final safeTitle = result.examTitle.replaceAll(RegExp(r'[^A-Za-z0-9]+'), '_');
      final file = File('${dir.path}/result_$safeTitle.pdf');
      await file.writeAsBytes(response.bodyBytes);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Saved to ${file.path}')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Download failed: $e'), backgroundColor: AppColors.danger),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ResultProvider>();
    final result = provider.currentResult;

    return Scaffold(
      appBar: AppBar(title: const Text('Result')),
      body: SafeArea(
        child: provider.isLoadingResult || result == null
            ? Center(child: provider.resultError != null ? Text(provider.resultError!) : const CircularProgressIndicator())
            : _ResultBody(result: result, onDownloadPdf: () => _downloadPdf(result), isGeneratingPdf: provider.isGeneratingPdf),
      ),
    );
  }
}

class _ResultBody extends StatelessWidget {
  final ResultModel result;
  final VoidCallback onDownloadPdf;
  final bool isGeneratingPdf;
  const _ResultBody({required this.result, required this.onDownloadPdf, required this.isGeneratingPdf});

  @override
  Widget build(BuildContext context) {
    final passColor = result.passed ? AppColors.success : AppColors.danger;

    return ListView(
      padding: const EdgeInsets.all(AppSpacing.md),
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(AppSpacing.lg),
          decoration: BoxDecoration(
            color: passColor.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Column(
            children: [
              CircleAvatar(
                radius: 36,
                backgroundColor: passColor.withValues(alpha: 0.2),
                child: Text(result.grade, style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: passColor)),
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(result.status, style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: passColor)),
              const SizedBox(height: 4),
              Text(result.examTitle, style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppColors.neutral)),
              const SizedBox(height: AppSpacing.md),
              Text('${result.score.toStringAsFixed(1)} pts  •  ${result.percentage.toStringAsFixed(1)}%',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700)),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          childAspectRatio: 2.4,
          mainAxisSpacing: AppSpacing.sm,
          crossAxisSpacing: AppSpacing.sm,
          children: [
            _StatTile(label: 'Correct', value: '${result.correct}', color: AppColors.success),
            _StatTile(label: 'Wrong', value: '${result.wrong}', color: AppColors.danger),
            _StatTile(label: 'Unattempted', value: '${result.unattempted}', color: AppColors.neutral),
            _StatTile(label: 'Time taken', value: _formatDuration(result.timeTaken), color: AppColors.primary),
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        OutlinedButton.icon(
          onPressed: isGeneratingPdf ? null : onDownloadPdf,
          icon: isGeneratingPdf
              ? const SizedBox(height: 16, width: 16, child: CircularProgressIndicator(strokeWidth: 2))
              : const Icon(Icons.download_rounded),
          label: Text(isGeneratingPdf ? 'Preparing PDF…' : 'Download result PDF'),
        ),
        if (result.reviewQuestions != null && result.reviewQuestions!.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.lg),
          Text('Question-wise analysis', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
          const SizedBox(height: AppSpacing.sm),
          ...result.reviewQuestions!.map((q) {
            final given = result.answers[q.id];
            final isCorrect = given == q.correctAnswer;
            final statusColor = given == null ? AppColors.neutral : (isCorrect ? AppColors.success : AppColors.danger);

            return Card(
              margin: const EdgeInsets.only(bottom: AppSpacing.sm),
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.md),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(child: Text('Q${q.questionNo}. ${q.question}', style: const TextStyle(fontWeight: FontWeight.w600))),
                        Icon(given == null ? Icons.remove_circle_outline : (isCorrect ? Icons.check_circle : Icons.cancel), color: statusColor, size: 20),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Text('Your answer: ${given ?? '(not attempted)'}', style: TextStyle(color: statusColor, fontWeight: FontWeight.w600)),
                    if (!isCorrect) Text('Correct answer: ${q.correctAnswer}', style: TextStyle(color: AppColors.success, fontWeight: FontWeight.w600)),
                  ],
                ),
              ),
            );
          }),
        ],
      ],
    );
  }

  String _formatDuration(int seconds) {
    final m = seconds ~/ 60;
    final s = seconds % 60;
    return '${m}m ${s}s';
  }
}

class _StatTile extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  const _StatTile({required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.sm),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(14)),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(color: color, fontWeight: FontWeight.w600)),
          Text(value, style: TextStyle(color: color, fontWeight: FontWeight.w800, fontSize: 16)),
        ],
      ),
    );
  }
}
