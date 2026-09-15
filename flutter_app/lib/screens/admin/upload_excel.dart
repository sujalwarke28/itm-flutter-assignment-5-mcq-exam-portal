import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../providers/exam_provider.dart';
import '../../utils/app_theme.dart';

class UploadExcelScreen extends StatefulWidget {
  const UploadExcelScreen({super.key});

  @override
  State<UploadExcelScreen> createState() => _UploadExcelScreenState();
}

class _UploadExcelScreenState extends State<UploadExcelScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleCtrl = TextEditingController();
  final _subjectCtrl = TextEditingController();
  final _durationCtrl = TextEditingController();
  final _totalMarksCtrl = TextEditingController();
  final _passingMarksCtrl = TextEditingController();
  final _negativeMarkingCtrl = TextEditingController(text: '0');
  final _instructionsCtrl = TextEditingController();

  String? _pickedFileName;
  String? _pickedFilePath;
  DateTime? _startDate;
  DateTime? _endDate;

  @override
  void dispose() {
    _titleCtrl.dispose();
    _subjectCtrl.dispose();
    _durationCtrl.dispose();
    _totalMarksCtrl.dispose();
    _passingMarksCtrl.dispose();
    _negativeMarkingCtrl.dispose();
    _instructionsCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['xlsx', 'csv'],
    );
    if (result == null || result.files.single.path == null) return;

    setState(() {
      _pickedFileName = result.files.single.name;
      _pickedFilePath = result.files.single.path;
    });

    if (!mounted) return;
    final provider = context.read<ExamProvider>();
    provider.resetCreationFlow();
    final ok = await provider.previewExcel(_pickedFilePath!);
    if (!ok && mounted) {
      _showError(provider.creationError);
    }
  }

  void _showError(String? message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message ?? 'Something went wrong.'), backgroundColor: AppColors.danger),
    );
  }

  Future<DateTime?> _pickDateTime(DateTime? initial) async {
    final date = await showDatePicker(
      context: context,
      initialDate: initial ?? DateTime.now(),
      firstDate: DateTime.now().subtract(const Duration(days: 1)),
      lastDate: DateTime.now().add(const Duration(days: 365 * 2)),
    );
    if (date == null || !mounted) return null;

    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(initial ?? DateTime.now()),
    );
    if (time == null) return null;

    return DateTime(date.year, date.month, date.day, time.hour, time.minute);
  }

  Future<void> _publish() async {
    final provider = context.read<ExamProvider>();

    if (provider.preview == null) {
      _showError('Upload and preview a question sheet first.');
      return;
    }
    if (!_formKey.currentState!.validate()) return;
    if (_startDate == null || _endDate == null) {
      _showError('Pick a start and end date/time.');
      return;
    }
    if (!_endDate!.isAfter(_startDate!)) {
      _showError('End date must be after the start date.');
      return;
    }

    final examId = await provider.publishExam(
      title: _titleCtrl.text.trim(),
      subject: _subjectCtrl.text.trim(),
      duration: int.parse(_durationCtrl.text),
      totalMarks: int.parse(_totalMarksCtrl.text),
      passingMarks: int.parse(_passingMarksCtrl.text),
      negativeMarking: double.tryParse(_negativeMarkingCtrl.text) ?? 0,
      startDate: _startDate!,
      endDate: _endDate!,
      instructions: _instructionsCtrl.text.trim(),
    );

    if (!mounted) return;
    if (examId != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Exam published successfully.')),
      );
      Navigator.of(context).pop(true);
    } else {
      _showError(provider.creationError);
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ExamProvider>();
    final dateFmt = DateFormat('MMM d, y • h:mm a');

    return Scaffold(
      appBar: AppBar(title: const Text('Upload Exam')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.md),
          children: [
            _SectionLabel('1. Question sheet'),
            const SizedBox(height: AppSpacing.sm),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.md),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Expected columns: Question No., Question, Option A-D, Correct Answer (A/B/C/D). .xlsx or .csv.',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.neutral),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    OutlinedButton.icon(
                      onPressed: provider.isPreviewing ? null : _pickFile,
                      icon: const Icon(Icons.upload_file_rounded),
                      label: Text(_pickedFileName ?? 'Choose file'),
                    ),
                    if (provider.isPreviewing) ...[
                      const SizedBox(height: AppSpacing.md),
                      const Center(child: CircularProgressIndicator()),
                    ],
                  ],
                ),
              ),
            ),
            if (provider.preview != null) ...[
              const SizedBox(height: AppSpacing.lg),
              _SectionLabel('2. Preview (${provider.preview!.totalQuestions} questions)'),
              const SizedBox(height: AppSpacing.sm),
              ...provider.preview!.questions.map((q) => Card(
                    margin: const EdgeInsets.only(bottom: AppSpacing.sm),
                    child: Padding(
                      padding: const EdgeInsets.all(AppSpacing.md),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Q${q.questionNo}. ${q.question}', style: const TextStyle(fontWeight: FontWeight.w600)),
                          const SizedBox(height: AppSpacing.sm),
                          Wrap(
                            spacing: AppSpacing.sm,
                            runSpacing: AppSpacing.xs,
                            children: List.generate(q.options.length, (i) {
                              final letter = String.fromCharCode(65 + i);
                              final isCorrect = letter == q.correctAnswer;
                              return Chip(
                                label: Text('$letter. ${q.options[i]}'),
                                backgroundColor: isCorrect ? AppColors.success.withValues(alpha: 0.15) : null,
                                labelStyle: TextStyle(color: isCorrect ? AppColors.success : null, fontWeight: isCorrect ? FontWeight.w700 : null),
                              );
                            }),
                          ),
                        ],
                      ),
                    ),
                  )),
              const SizedBox(height: AppSpacing.lg),
              _SectionLabel('3. Exam details'),
              const SizedBox(height: AppSpacing.sm),
              Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    TextFormField(
                      controller: _titleCtrl,
                      decoration: const InputDecoration(labelText: 'Exam title'),
                      validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    TextFormField(
                      controller: _subjectCtrl,
                      decoration: const InputDecoration(labelText: 'Subject'),
                      validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Row(children: [
                      Expanded(
                        child: TextFormField(
                          controller: _durationCtrl,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(labelText: 'Duration (min)'),
                          validator: _requiredPositiveInt,
                        ),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: TextFormField(
                          controller: _totalMarksCtrl,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(labelText: 'Total marks'),
                          validator: _requiredPositiveInt,
                        ),
                      ),
                    ]),
                    const SizedBox(height: AppSpacing.sm),
                    Row(children: [
                      Expanded(
                        child: TextFormField(
                          controller: _passingMarksCtrl,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(labelText: 'Passing marks'),
                          validator: _requiredPositiveInt,
                        ),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: TextFormField(
                          controller: _negativeMarkingCtrl,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          decoration: const InputDecoration(labelText: 'Negative marking', helperText: '0 = disabled, e.g. 0.25'),
                        ),
                      ),
                    ]),
                    const SizedBox(height: AppSpacing.sm),
                    TextFormField(
                      controller: _instructionsCtrl,
                      maxLines: 3,
                      decoration: const InputDecoration(labelText: 'Instructions (optional)', alignLabelWithHint: true),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    Row(children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          icon: const Icon(Icons.calendar_today_rounded, size: 18),
                          label: Text(_startDate == null ? 'Start date' : dateFmt.format(_startDate!)),
                          onPressed: () async {
                            final picked = await _pickDateTime(_startDate);
                            if (picked != null) setState(() => _startDate = picked);
                          },
                        ),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: OutlinedButton.icon(
                          icon: const Icon(Icons.calendar_today_rounded, size: 18),
                          label: Text(_endDate == null ? 'End date' : dateFmt.format(_endDate!)),
                          onPressed: () async {
                            final picked = await _pickDateTime(_endDate);
                            if (picked != null) setState(() => _endDate = picked);
                          },
                        ),
                      ),
                    ]),
                    const SizedBox(height: AppSpacing.xl),
                    ElevatedButton(
                      onPressed: provider.isPublishing ? null : _publish,
                      child: provider.isPublishing
                          ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                          : const Text('Publish exam'),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: AppSpacing.xl),
          ],
        ),
      ),
    );
  }

  String? _requiredPositiveInt(String? v) {
    if (v == null || v.trim().isEmpty) return 'Required';
    final n = int.tryParse(v);
    if (n == null || n <= 0) return 'Enter a positive number';
    return null;
  }
}

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(text, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700));
  }
}
