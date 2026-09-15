import 'dart:io';

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';

import '../../models/exam_model.dart';
import '../../models/result_model.dart';
import '../../providers/exam_provider.dart';
import '../../services/exam_service.dart';
import '../../utils/app_theme.dart';

enum _SortBy { score, date, name }

class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key});

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  String? _selectedExamId;
  _SortBy _sortBy = _SortBy.score;
  bool _descending = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final provider = context.read<ExamProvider>();
      await provider.fetchAdminExams();
      if (provider.exams.isNotEmpty && mounted) {
        setState(() => _selectedExamId = provider.exams.first.id);
        provider.fetchReport(_selectedExamId!);
      }
    });
  }

  void _selectExam(String? examId) {
    if (examId == null) return;
    setState(() => _selectedExamId = examId);
    context.read<ExamProvider>().fetchReport(examId);
  }

  List<ResultModel> _sorted(List<ResultModel> attempts) {
    final list = [...attempts];
    switch (_sortBy) {
      case _SortBy.score:
        list.sort((a, b) => a.score.compareTo(b.score));
        break;
      case _SortBy.date:
        list.sort((a, b) => (a.submittedAt ?? DateTime(0)).compareTo(b.submittedAt ?? DateTime(0)));
        break;
      case _SortBy.name:
        list.sort((a, b) => a.studentName.compareTo(b.studentName));
        break;
    }
    if (_descending) return list.reversed.toList();
    return list;
  }

  Future<void> _export(String format) async {
    if (_selectedExamId == null) return;
    final provider = context.read<ExamProvider>();
    final url = await provider.exportReport(_selectedExamId!, format: format);
    if (!mounted) return;

    if (url == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(provider.reportError ?? 'Export failed.'), backgroundColor: AppColors.danger),
      );
      return;
    }

    try {
      final response = await http.get(Uri.parse(url));
      final dir = await getApplicationDocumentsDirectory();
      final ext = format == 'pdf' ? 'pdf' : 'xlsx';
      final file = File('${dir.path}/report_${_selectedExamId}_${DateTime.now().millisecondsSinceEpoch}.$ext');
      await file.writeAsBytes(response.bodyBytes);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Saved to ${file.path}')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Download failed: $e'), backgroundColor: AppColors.danger));
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ExamProvider>();
    final report = provider.report;

    return Scaffold(
      appBar: AppBar(title: const Text('Reports')),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: DropdownButtonFormField<String>(
                initialValue: _selectedExamId,
                decoration: const InputDecoration(labelText: 'Select exam'),
                items: provider.exams.map((ExamModel e) => DropdownMenuItem(value: e.id, child: Text(e.title, overflow: TextOverflow.ellipsis))).toList(),
                onChanged: _selectExam,
              ),
            ),
            Expanded(
              child: provider.isLoadingReport
                  ? const Center(child: CircularProgressIndicator())
                  : report == null
                      ? Center(child: Text(provider.exams.isEmpty ? 'No exams yet.' : 'Select an exam to view its report.'))
                      : _ReportBody(
                          report: report,
                          sortBy: _sortBy,
                          descending: _descending,
                          onSortChanged: (s) => setState(() => _sortBy = s),
                          onToggleDirection: () => setState(() => _descending = !_descending),
                          sortedAttempts: _sorted(report.attempts),
                          onExport: _export,
                          isExporting: provider.isExportingReport,
                        ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ReportBody extends StatelessWidget {
  final ReportData report;
  final _SortBy sortBy;
  final bool descending;
  final ValueChanged<_SortBy> onSortChanged;
  final VoidCallback onToggleDirection;
  final List<ResultModel> sortedAttempts;
  final ValueChanged<String> onExport;
  final bool isExporting;

  const _ReportBody({
    required this.report,
    required this.sortBy,
    required this.descending,
    required this.onSortChanged,
    required this.onToggleDirection,
    required this.sortedAttempts,
    required this.onExport,
    required this.isExporting,
  });

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(AppSpacing.md, 0, AppSpacing.md, AppSpacing.xl),
      children: [
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          childAspectRatio: 1.8,
          mainAxisSpacing: AppSpacing.sm,
          crossAxisSpacing: AppSpacing.sm,
          children: [
            _StatCard(label: 'Total Attempts', value: '${report.totalAttempts}', color: AppColors.primary),
            _StatCard(label: 'Pass Rate', value: '${report.passPercentage.toStringAsFixed(1)}%', color: AppColors.success),
            _StatCard(label: 'Avg Score', value: report.averageScore.toStringAsFixed(1), color: AppColors.warning),
            _StatCard(label: 'Avg %', value: '${report.averagePercentage.toStringAsFixed(1)}%', color: AppColors.neutral),
          ],
        ),
        const SizedBox(height: AppSpacing.lg),
        if (report.totalAttempts > 0) ...[
          Text('Pass / Fail split', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
          const SizedBox(height: AppSpacing.sm),
          SizedBox(
            height: 180,
            child: Row(children: [
              Expanded(
                child: PieChart(PieChartData(
                  sectionsSpace: 3,
                  centerSpaceRadius: 36,
                  sections: [
                    PieChartSectionData(value: report.passCount.toDouble(), color: AppColors.success, title: '${report.passCount}', radius: 46, titleStyle: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
                    PieChartSectionData(value: report.failCount.toDouble(), color: AppColors.danger, title: '${report.failCount}', radius: 46, titleStyle: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
                  ],
                )),
              ),
              Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.start, children: [
                _LegendRow(color: AppColors.success, label: 'Pass (${report.passCount})'),
                const SizedBox(height: AppSpacing.sm),
                _LegendRow(color: AppColors.danger, label: 'Fail (${report.failCount})'),
              ]),
              const SizedBox(width: AppSpacing.lg),
            ]),
          ),
          const SizedBox(height: AppSpacing.lg),
        ],
        if (report.topper != null) ...[
          Card(
            color: AppColors.warning.withValues(alpha: 0.08),
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Row(children: [
                const Icon(Icons.emoji_events_rounded, color: AppColors.warning, size: 28),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Topper: ${report.topper!.studentName}', style: const TextStyle(fontWeight: FontWeight.w700)),
                      Text('${report.topper!.score.toStringAsFixed(1)} pts • ${report.topper!.percentage.toStringAsFixed(1)}%', style: Theme.of(context).textTheme.bodySmall),
                    ],
                  ),
                ),
              ]),
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
        ],
        Row(children: [
          Expanded(
            child: OutlinedButton.icon(
              onPressed: isExporting ? null : () => onExport('excel'),
              icon: const Icon(Icons.table_chart_outlined, size: 18),
              label: const Text('Export Excel'),
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: OutlinedButton.icon(
              onPressed: isExporting ? null : () => onExport('pdf'),
              icon: const Icon(Icons.picture_as_pdf_outlined, size: 18),
              label: const Text('Export PDF'),
            ),
          ),
        ]),
        const SizedBox(height: AppSpacing.lg),
        Row(
          children: [
            Text('Attempts', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
            const Spacer(),
            DropdownButton<_SortBy>(
              value: sortBy,
              items: const [
                DropdownMenuItem(value: _SortBy.score, child: Text('Score')),
                DropdownMenuItem(value: _SortBy.date, child: Text('Date')),
                DropdownMenuItem(value: _SortBy.name, child: Text('Name')),
              ],
              onChanged: (v) => v != null ? onSortChanged(v) : null,
            ),
            IconButton(
              icon: Icon(descending ? Icons.arrow_downward_rounded : Icons.arrow_upward_rounded, size: 18),
              onPressed: onToggleDirection,
            ),
          ],
        ),
        if (sortedAttempts.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: AppSpacing.lg),
            child: Center(child: Text('No submitted attempts yet.')),
          )
        else
          ...sortedAttempts.map((a) {
            final color = a.passed ? AppColors.success : AppColors.danger;
            return Card(
              margin: const EdgeInsets.only(bottom: AppSpacing.sm),
              child: ListTile(
                leading: CircleAvatar(backgroundColor: color.withValues(alpha: 0.15), child: Text(a.grade, style: TextStyle(color: color, fontWeight: FontWeight.w700))),
                title: Text(a.studentName),
                subtitle: Text('${a.score.toStringAsFixed(1)} pts • ${a.percentage.toStringAsFixed(1)}%'),
                trailing: Chip(label: Text(a.status), backgroundColor: color.withValues(alpha: 0.15), labelStyle: TextStyle(color: color, fontWeight: FontWeight.w700)),
              ),
            );
          }),
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  const _StatCard({required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(16)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(value, style: TextStyle(color: color, fontWeight: FontWeight.w800, fontSize: 20)),
          Text(label, style: TextStyle(color: color, fontSize: 12)),
        ],
      ),
    );
  }
}

class _LegendRow extends StatelessWidget {
  final Color color;
  final String label;
  const _LegendRow({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(mainAxisSize: MainAxisSize.min, children: [
      Container(width: 12, height: 12, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
      const SizedBox(width: 6),
      Text(label, style: Theme.of(context).textTheme.bodySmall),
    ]);
  }
}
