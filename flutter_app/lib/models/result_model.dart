import 'package:cloud_firestore/cloud_firestore.dart';

import 'question_model.dart';

/// Grade banding: A+ 90+, A 80-89, B 70-79, C 60-69, D 50-59, F below 50.
/// Percentage is the only value the schema stores, so grade is derived here
/// rather than persisted — keeping it in sync automatically and keeping the
/// Firestore `attempts` doc exactly to the spec's field list.
String gradeForPercentage(double percentage) {
  if (percentage >= 90) return 'A+';
  if (percentage >= 80) return 'A';
  if (percentage >= 70) return 'B';
  if (percentage >= 60) return 'C';
  if (percentage >= 50) return 'D';
  return 'F';
}

class ResultModel {
  final String id;
  final String studentId;
  final String studentName;
  final String examId;
  final String examTitle;
  final Map<String, String> answers; // questionId -> selected option letter
  final int totalQuestions;
  final int attempted;
  final int correct;
  final int wrong;
  final int unattempted;
  final double score;
  final double percentage;
  final String status; // 'IN_PROGRESS' | 'PASS' | 'FAIL'
  final int timeTaken; // seconds
  final String? resultPdfUrl;
  final DateTime? startedAt;
  final DateTime? submittedAt;

  /// Only populated once the attempt is submitted (never during an exam) —
  /// carries correctAnswer for the "question-wise analysis" review UI.
  /// Not part of the Firestore schema; comes from the API response only.
  final List<QuestionModel>? reviewQuestions;

  const ResultModel({
    required this.id,
    required this.studentId,
    required this.studentName,
    required this.examId,
    required this.examTitle,
    required this.answers,
    required this.totalQuestions,
    required this.attempted,
    required this.correct,
    required this.wrong,
    required this.unattempted,
    required this.score,
    required this.percentage,
    required this.status,
    required this.timeTaken,
    this.resultPdfUrl,
    this.startedAt,
    this.submittedAt,
    this.reviewQuestions,
  });

  bool get passed => status == 'PASS';
  String get grade => gradeForPercentage(percentage);

  factory ResultModel.fromMap(String id, Map<String, dynamic> map) {
    return ResultModel(
      id: id,
      studentId: map['studentId'] as String? ?? '',
      studentName: map['studentName'] as String? ?? '',
      examId: map['examId'] as String? ?? '',
      examTitle: map['examTitle'] as String? ?? '',
      answers: Map<String, String>.from(map['answers'] as Map? ?? {}),
      totalQuestions: (map['totalQuestions'] as num?)?.toInt() ?? 0,
      attempted: (map['attempted'] as num?)?.toInt() ?? 0,
      correct: (map['correct'] as num?)?.toInt() ?? 0,
      wrong: (map['wrong'] as num?)?.toInt() ?? 0,
      unattempted: (map['unattempted'] as num?)?.toInt() ?? 0,
      score: (map['score'] as num?)?.toDouble() ?? 0,
      percentage: (map['percentage'] as num?)?.toDouble() ?? 0,
      status: map['status'] as String? ?? 'IN_PROGRESS',
      timeTaken: (map['timeTaken'] as num?)?.toInt() ?? 0,
      resultPdfUrl: map['resultPdfUrl'] as String?,
      startedAt: (map['startedAt'] as Timestamp?)?.toDate(),
      submittedAt: (map['submittedAt'] as Timestamp?)?.toDate(),
      reviewQuestions: (map['questions'] as List?)
          ?.cast<Map<String, dynamic>>()
          .map((q) => QuestionModel.fromMap(q['id'] as String, q))
          .toList(),
    );
  }
}
