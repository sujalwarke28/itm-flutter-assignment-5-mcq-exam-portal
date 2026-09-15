import 'package:cloud_firestore/cloud_firestore.dart';

class ExamModel {
  final String id;
  final String title;
  final String subject;
  final int duration; // minutes
  final int totalMarks;
  final int passingMarks;
  final double negativeMarking; // fraction of a question's marks deducted per wrong answer; 0 = disabled
  final int totalQuestions;
  final String instructions;
  final DateTime startDate;
  final DateTime endDate;
  final String? excelUrl;
  final String? excelPublicId;
  final String createdBy;
  final DateTime? createdAt;

  /// Only populated by the student-facing exam list; irrelevant for admin views.
  final bool attempted;

  const ExamModel({
    required this.id,
    required this.title,
    required this.subject,
    required this.duration,
    required this.totalMarks,
    required this.passingMarks,
    required this.negativeMarking,
    required this.totalQuestions,
    required this.instructions,
    required this.startDate,
    required this.endDate,
    this.excelUrl,
    this.excelPublicId,
    required this.createdBy,
    this.createdAt,
    this.attempted = false,
  });

  bool get negativeMarkingEnabled => negativeMarking > 0;

  bool get isActive {
    final now = DateTime.now();
    return now.isAfter(startDate) && now.isBefore(endDate);
  }

  bool get isUpcoming => DateTime.now().isBefore(startDate);
  bool get hasEnded => DateTime.now().isAfter(endDate);

  factory ExamModel.fromMap(String id, Map<String, dynamic> map) {
    return ExamModel(
      id: id,
      title: map['title'] as String? ?? '',
      subject: map['subject'] as String? ?? '',
      duration: (map['duration'] as num?)?.toInt() ?? 0,
      totalMarks: (map['totalMarks'] as num?)?.toInt() ?? 0,
      passingMarks: (map['passingMarks'] as num?)?.toInt() ?? 0,
      negativeMarking: (map['negativeMarking'] as num?)?.toDouble() ?? 0,
      totalQuestions: (map['totalQuestions'] as num?)?.toInt() ?? 0,
      instructions: map['instructions'] as String? ?? '',
      startDate: (map['startDate'] as Timestamp).toDate(),
      endDate: (map['endDate'] as Timestamp).toDate(),
      excelUrl: map['excelUrl'] as String?,
      excelPublicId: map['excelPublicId'] as String?,
      createdBy: map['createdBy'] as String? ?? '',
      createdAt: (map['createdAt'] as Timestamp?)?.toDate(),
      attempted: map['attempted'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'title': title,
      'subject': subject,
      'duration': duration,
      'totalMarks': totalMarks,
      'passingMarks': passingMarks,
      'negativeMarking': negativeMarking,
      'totalQuestions': totalQuestions,
      'instructions': instructions,
      'startDate': Timestamp.fromDate(startDate),
      'endDate': Timestamp.fromDate(endDate),
      'excelUrl': excelUrl,
      'excelPublicId': excelPublicId,
      'createdBy': createdBy,
      'createdAt': createdAt != null ? Timestamp.fromDate(createdAt!) : FieldValue.serverTimestamp(),
    };
  }
}
