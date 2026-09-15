import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../models/exam_model.dart';
import '../../providers/exam_provider.dart';
import '../../utils/app_theme.dart';
import 'upload_excel.dart';

class ManageExamsScreen extends StatefulWidget {
  const ManageExamsScreen({super.key});

  @override
  State<ManageExamsScreen> createState() => _ManageExamsScreenState();
}

class _ManageExamsScreenState extends State<ManageExamsScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => context.read<ExamProvider>().fetchAdminExams());
  }

  Future<void> _openUpload() async {
    final created = await Navigator.of(context).push<bool>(MaterialPageRoute(builder: (_) => const UploadExcelScreen()));
    if (created == true && mounted) context.read<ExamProvider>().fetchAdminExams();
  }

  Future<void> _confirmDelete(ExamModel exam) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete exam?'),
        content: Text('This permanently deletes "${exam.title}" and all its questions and results.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('Delete', style: TextStyle(color: AppColors.danger)),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      final ok = await context.read<ExamProvider>().deleteExam(exam.id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(ok ? 'Exam deleted.' : 'Failed to delete exam.')),
        );
      }
    }
  }

  Future<void> _editExam(ExamModel exam) async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => _EditExamSheet(exam: exam),
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ExamProvider>();

    return Scaffold(
      appBar: AppBar(title: const Text('Manage Exams')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openUpload,
        icon: const Icon(Icons.add_rounded),
        label: const Text('New exam'),
      ),
      body: RefreshIndicator(
        onRefresh: () => provider.fetchAdminExams(),
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
                      Center(child: Text(provider.listError ?? 'No exams yet — tap "New exam" to create one.', textAlign: TextAlign.center)),
                    ],
                  )
                : ListView.separated(
                    padding: const EdgeInsets.fromLTRB(AppSpacing.md, AppSpacing.md, AppSpacing.md, 96),
                    itemCount: provider.exams.length,
                    separatorBuilder: (context, index) => const SizedBox(height: AppSpacing.sm),
                    itemBuilder: (context, i) {
                      final exam = provider.exams[i];
                      return _ExamCard(exam: exam, onEdit: () => _editExam(exam), onDelete: () => _confirmDelete(exam));
                    },
                  ),
      ),
    );
  }
}

class _ExamCard extends StatelessWidget {
  final ExamModel exam;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  const _ExamCard({required this.exam, required this.onEdit, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    final dateFmt = DateFormat('MMM d, y • h:mm a');
    final (label, color) = exam.hasEnded
        ? ('Ended', AppColors.neutral)
        : exam.isActive
            ? ('Active', AppColors.success)
            : ('Upcoming', AppColors.warning);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(exam.title, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
                ),
                Chip(label: Text(label), backgroundColor: color.withValues(alpha: 0.15), labelStyle: TextStyle(color: color, fontWeight: FontWeight.w700)),
              ],
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(exam.subject, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.neutral)),
            const SizedBox(height: AppSpacing.sm),
            Wrap(spacing: AppSpacing.md, runSpacing: AppSpacing.xs, children: [
              _MetaChip(icon: Icons.quiz_outlined, label: '${exam.totalQuestions} Qs'),
              _MetaChip(icon: Icons.timer_outlined, label: '${exam.duration} min'),
              _MetaChip(icon: Icons.grade_outlined, label: '${exam.totalMarks} marks'),
            ]),
            const SizedBox(height: AppSpacing.sm),
            Text('${dateFmt.format(exam.startDate)}  →  ${dateFmt.format(exam.endDate)}', style: Theme.of(context).textTheme.bodySmall),
            const Divider(height: AppSpacing.lg),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton.icon(onPressed: onEdit, icon: const Icon(Icons.edit_outlined, size: 18), label: const Text('Edit')),
                TextButton.icon(
                  onPressed: onDelete,
                  icon: Icon(Icons.delete_outline, size: 18, color: AppColors.danger),
                  label: Text('Delete', style: TextStyle(color: AppColors.danger)),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _MetaChip extends StatelessWidget {
  final IconData icon;
  final String label;
  const _MetaChip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(mainAxisSize: MainAxisSize.min, children: [
      Icon(icon, size: 14, color: AppColors.neutral),
      const SizedBox(width: 4),
      Text(label, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.neutral)),
    ]);
  }
}

class _EditExamSheet extends StatefulWidget {
  final ExamModel exam;
  const _EditExamSheet({required this.exam});

  @override
  State<_EditExamSheet> createState() => _EditExamSheetState();
}

class _EditExamSheetState extends State<_EditExamSheet> {
  late final _titleCtrl = TextEditingController(text: widget.exam.title);
  late final _subjectCtrl = TextEditingController(text: widget.exam.subject);
  late final _durationCtrl = TextEditingController(text: widget.exam.duration.toString());
  late final _totalMarksCtrl = TextEditingController(text: widget.exam.totalMarks.toString());
  late final _passingMarksCtrl = TextEditingController(text: widget.exam.passingMarks.toString());
  bool _saving = false;

  Future<void> _save() async {
    setState(() => _saving = true);
    final ok = await context.read<ExamProvider>().updateExam(widget.exam.id, {
      'title': _titleCtrl.text.trim(),
      'subject': _subjectCtrl.text.trim(),
      'duration': int.tryParse(_durationCtrl.text) ?? widget.exam.duration,
      'totalMarks': int.tryParse(_totalMarksCtrl.text) ?? widget.exam.totalMarks,
      'passingMarks': int.tryParse(_passingMarksCtrl.text) ?? widget.exam.passingMarks,
    });
    if (!mounted) return;
    setState(() => _saving = false);
    Navigator.of(context).pop();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(ok ? 'Exam updated.' : 'Failed to update exam.')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.lg, AppSpacing.lg, MediaQuery.of(context).viewInsets.bottom + AppSpacing.lg),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Edit exam', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700)),
          const SizedBox(height: AppSpacing.md),
          TextField(controller: _titleCtrl, decoration: const InputDecoration(labelText: 'Title')),
          const SizedBox(height: AppSpacing.sm),
          TextField(controller: _subjectCtrl, decoration: const InputDecoration(labelText: 'Subject')),
          const SizedBox(height: AppSpacing.sm),
          Row(children: [
            Expanded(child: TextField(controller: _durationCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Duration (min)'))),
            const SizedBox(width: AppSpacing.sm),
            Expanded(child: TextField(controller: _totalMarksCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Total marks'))),
          ]),
          const SizedBox(height: AppSpacing.sm),
          TextField(controller: _passingMarksCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Passing marks')),
          const SizedBox(height: AppSpacing.lg),
          ElevatedButton(
            onPressed: _saving ? null : _save,
            child: _saving
                ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Text('Save changes'),
          ),
        ],
      ),
    );
  }
}
