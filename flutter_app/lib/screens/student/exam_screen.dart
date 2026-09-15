import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../providers/exam_provider.dart';
import '../../services/exam_service.dart';
import '../../utils/app_theme.dart';
import '../../widgets/question_palette.dart';
import '../../widgets/timer_widget.dart';
import 'result_screen.dart';

class ExamScreen extends StatefulWidget {
  final String examId;
  final StartExamData data;
  const ExamScreen({super.key, required this.examId, required this.data});

  @override
  State<ExamScreen> createState() => _ExamScreenState();
}

class _ExamScreenState extends State<ExamScreen> {
  late final int _totalQuestions = widget.data.questions.length;
  late int _remainingSeconds;
  Timer? _ticker;

  int _currentIndex = 0;
  final Map<String, String> _answers = {};
  final Set<int> _markedForReview = {};
  final Set<int> _visited = {};
  bool _submitting = false;

  String get _prefsKey => 'exam_answers_${widget.data.attemptId}';

  @override
  void initState() {
    super.initState();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);

    _answers.addAll(widget.data.savedAnswers);
    _visited.add(0);

    final elapsed = DateTime.now().difference(widget.data.startedAt).inSeconds;
    _remainingSeconds = (widget.data.duration * 60 - elapsed).clamp(0, widget.data.duration * 60);

    _restoreLocalAnswers();
    _startTimer();
  }

  @override
  void dispose() {
    _ticker?.cancel();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    super.dispose();
  }

  Future<void> _restoreLocalAnswers() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_prefsKey);
      if (raw == null) return;
      final cached = Map<String, String>.from(jsonDecode(raw) as Map);
      if (mounted) setState(() => _answers.addAll(cached));
    } catch (_) {
      // Corrupt or missing cache — safe to ignore, server-side savedAnswers still apply.
    }
  }

  Future<void> _persistLocalAnswers() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_prefsKey, jsonEncode(_answers));
    } catch (_) {
      // Best-effort autosave; submission still works without it.
    }
  }

  void _startTimer() {
    _ticker = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_remainingSeconds <= 0) {
        timer.cancel();
        _submit(auto: true);
        return;
      }
      setState(() => _remainingSeconds--);
    });
  }

  void _goTo(int index) {
    setState(() {
      _currentIndex = index;
      _visited.add(index);
    });
  }

  void _selectAnswer(String questionId, String letter) {
    setState(() => _answers[questionId] = letter);
    _persistLocalAnswers();
  }

  void _clearAnswer(String questionId) {
    setState(() => _answers.remove(questionId));
    _persistLocalAnswers();
  }

  void _toggleMarkForReview() {
    setState(() {
      if (_markedForReview.contains(_currentIndex)) {
        _markedForReview.remove(_currentIndex);
      } else {
        _markedForReview.add(_currentIndex);
      }
    });
  }

  Future<void> _confirmSubmit() async {
    final unanswered = _totalQuestions - _answers.length;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Submit exam?'),
        content: Text(unanswered > 0
            ? 'You have $unanswered unanswered question(s). Submit anyway?'
            : 'You have answered all questions. Submit now?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Submit')),
        ],
      ),
    );
    if (confirmed == true) _submit();
  }

  Future<void> _submit({bool auto = false}) async {
    if (_submitting) return;
    setState(() => _submitting = true);
    _ticker?.cancel();

    final timeTaken = widget.data.duration * 60 - _remainingSeconds;
    final result = await context.read<ExamProvider>().submitExam(
          widget.examId,
          attemptId: widget.data.attemptId,
          answers: _answers,
          timeTakenSeconds: timeTaken,
        );

    if (!mounted) return;

    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_prefsKey);
    if (!mounted) return;

    if (result == null) {
      setState(() => _submitting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.read<ExamProvider>().attemptError ?? 'Failed to submit.'), backgroundColor: AppColors.danger),
      );
      return;
    }

    if (auto && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Time's up — exam auto-submitted.")));
    }

    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => ResultScreen(examId: widget.examId, freshResult: result)),
    );
  }

  void _showPalette() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: QuestionPalette(
          totalQuestions: _totalQuestions,
          currentIndex: _currentIndex,
          statuses: _statuses(),
          onSelect: (i) {
            Navigator.pop(ctx);
            _goTo(i);
          },
        ),
      ),
    );
  }

  List<QuestionStatus> _statuses() {
    return List.generate(_totalQuestions, (i) {
      if (_markedForReview.contains(i)) return QuestionStatus.markedForReview;
      final qId = widget.data.questions[i].id;
      if (_answers.containsKey(qId)) return QuestionStatus.answered;
      if (_visited.contains(i)) return QuestionStatus.notAnswered;
      return QuestionStatus.notVisited;
    });
  }

  @override
  Widget build(BuildContext context) {
    final question = widget.data.questions[_currentIndex];
    final selected = _answers[question.id];

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        final leave = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Leave exam?'),
            content: const Text('Your progress is saved locally, but the timer keeps running. Are you sure you want to exit?'),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Stay')),
              TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Exit')),
            ],
          ),
        );
        if (!context.mounted) return;
        if (leave == true) Navigator.of(context).pop();
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(widget.data.examTitle, overflow: TextOverflow.ellipsis),
          actions: [
            Padding(padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm), child: Center(child: TimerWidget(remainingSeconds: _remainingSeconds))),
            IconButton(icon: const Icon(Icons.grid_view_rounded), onPressed: _showPalette),
          ],
        ),
        body: SafeArea(
          child: Column(
            children: [
              LinearProgressIndicator(value: (_currentIndex + 1) / _totalQuestions, minHeight: 3),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Question ${_currentIndex + 1} of $_totalQuestions', style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.neutral)),
                      const SizedBox(height: AppSpacing.sm),
                      Text(question.question, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
                      if (question.imageUrl != null) ...[
                        const SizedBox(height: AppSpacing.md),
                        ClipRRect(borderRadius: BorderRadius.circular(12), child: Image.network(question.imageUrl!)),
                      ],
                      const SizedBox(height: AppSpacing.lg),
                      ...List.generate(question.options.length, (i) {
                        final letter = String.fromCharCode(65 + i);
                        final isSelected = selected == letter;
                        return Padding(
                          padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                          child: InkWell(
                            borderRadius: BorderRadius.circular(12),
                            onTap: () => _selectAnswer(question.id, letter),
                            child: Container(
                              padding: const EdgeInsets.all(AppSpacing.md),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: isSelected ? AppColors.primary : Theme.of(context).colorScheme.outlineVariant, width: isSelected ? 2 : 1),
                                color: isSelected ? AppColors.primary.withValues(alpha: 0.08) : null,
                              ),
                              child: Row(children: [
                                CircleAvatar(
                                  radius: 12,
                                  backgroundColor: isSelected ? AppColors.primary : AppColors.neutral.withValues(alpha: 0.15),
                                  child: Text(letter, style: TextStyle(fontSize: 12, color: isSelected ? Colors.white : AppColors.neutral, fontWeight: FontWeight.w700)),
                                ),
                                const SizedBox(width: AppSpacing.sm),
                                Expanded(child: Text(question.options[i])),
                              ]),
                            ),
                          ),
                        );
                      }),
                      if (selected != null)
                        Align(
                          alignment: Alignment.centerRight,
                          child: TextButton.icon(
                            onPressed: () => _clearAnswer(question.id),
                            icon: const Icon(Icons.clear_rounded, size: 16),
                            label: const Text('Clear response'),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(AppSpacing.md, AppSpacing.sm, AppSpacing.md, AppSpacing.sm),
                  child: Column(
                    children: [
                      Row(children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: _toggleMarkForReview,
                            icon: Icon(_markedForReview.contains(_currentIndex) ? Icons.bookmark : Icons.bookmark_border, size: 18, color: AppColors.warning),
                            label: Text(_markedForReview.contains(_currentIndex) ? 'Unmark' : 'Mark for review'),
                          ),
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: _submitting ? null : _confirmSubmit,
                            style: ElevatedButton.styleFrom(backgroundColor: AppColors.danger),
                            child: _submitting
                                ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                                : const Text('Submit'),
                          ),
                        ),
                      ]),
                      const SizedBox(height: AppSpacing.sm),
                      Row(children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: _currentIndex > 0 ? () => _goTo(_currentIndex - 1) : null,
                            icon: const Icon(Icons.chevron_left_rounded),
                            label: const Text('Previous'),
                          ),
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: _currentIndex < _totalQuestions - 1 ? () => _goTo(_currentIndex + 1) : null,
                            icon: const Icon(Icons.chevron_right_rounded),
                            label: const Text('Next'),
                          ),
                        ),
                      ]),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
