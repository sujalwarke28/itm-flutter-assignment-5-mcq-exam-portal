import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/result_provider.dart';
import '../../utils/app_theme.dart';
import '../../widgets/result_card.dart';
import 'result_screen.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => context.read<ResultProvider>().fetchHistory());
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ResultProvider>();

    return Scaffold(
      appBar: AppBar(title: const Text('Exam History')),
      body: RefreshIndicator(
        onRefresh: () => provider.fetchHistory(),
        child: provider.isLoadingHistory
            ? const Center(child: CircularProgressIndicator())
            : provider.history.isEmpty
                ? ListView(
                    children: [
                      const SizedBox(height: 120),
                      Icon(
                        provider.historyError != null ? Icons.error_outline : Icons.history_rounded,
                        size: 56,
                        color: provider.historyError != null ? AppColors.danger : AppColors.neutral.withValues(alpha: 0.5),
                      ),
                      const SizedBox(height: AppSpacing.md),
                      Center(child: Text(provider.historyError ?? 'No completed exams yet.', textAlign: TextAlign.center)),
                    ],
                  )
                : ListView.separated(
                    padding: const EdgeInsets.all(AppSpacing.md),
                    itemCount: provider.history.length,
                    separatorBuilder: (context, index) => const SizedBox(height: AppSpacing.sm),
                    itemBuilder: (context, i) {
                      final result = provider.history[i];
                      return ResultCard(
                        result: result,
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute(builder: (_) => ResultScreen(examId: result.examId)),
                        ),
                      );
                    },
                  ),
      ),
    );
  }
}
