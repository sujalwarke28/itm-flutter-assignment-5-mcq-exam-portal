import '../models/exam_model.dart';
import '../models/question_model.dart';
import '../models/result_model.dart';
import 'api_service.dart';

class ExcelPreview {
  final String excelUrl;
  final String excelPublicId;
  final int totalQuestions;
  final List<QuestionModel> questions;

  const ExcelPreview({
    required this.excelUrl,
    required this.excelPublicId,
    required this.totalQuestions,
    required this.questions,
  });

  factory ExcelPreview.fromJson(Map<String, dynamic> json) {
    final rawQuestions = (json['questions'] as List).cast<Map<String, dynamic>>();
    return ExcelPreview(
      excelUrl: json['excelUrl'] as String,
      excelPublicId: json['excelPublicId'] as String,
      totalQuestions: json['totalQuestions'] as int,
      questions: rawQuestions
          .map((q) => QuestionModel(
                id: '',
                questionNo: q['questionNo'] as int,
                question: q['question'] as String,
                options: (q['options'] as List).map((e) => e.toString()).toList(),
                marks: 1,
                correctAnswer: q['correctAnswer'] as String,
              ))
          .toList(),
    );
  }
}

class StartExamData {
  final String attemptId;
  final bool resumed;
  final Map<String, String> savedAnswers;
  final DateTime startedAt;
  final String examTitle;
  final int duration; // minutes
  final int totalMarks;
  final double negativeMarking;
  final String instructions;
  final List<QuestionModel> questions;

  const StartExamData({
    required this.attemptId,
    required this.resumed,
    required this.savedAnswers,
    required this.startedAt,
    required this.examTitle,
    required this.duration,
    required this.totalMarks,
    required this.negativeMarking,
    required this.instructions,
    required this.questions,
  });

  factory StartExamData.fromJson(Map<String, dynamic> json) {
    final exam = json['exam'] as Map<String, dynamic>;
    final rawQuestions = (json['questions'] as List).cast<Map<String, dynamic>>();
    return StartExamData(
      attemptId: json['attemptId'] as String,
      resumed: json['resumed'] as bool? ?? false,
      savedAnswers: Map<String, String>.from(json['savedAnswers'] as Map? ?? {}),
      startedAt: DateTime.fromMillisecondsSinceEpoch(json['startedAtMs'] as int),
      examTitle: exam['title'] as String,
      duration: exam['duration'] as int,
      totalMarks: exam['totalMarks'] as int,
      negativeMarking: (exam['negativeMarking'] as num?)?.toDouble() ?? 0,
      instructions: exam['instructions'] as String? ?? '',
      questions: rawQuestions.map((q) => QuestionModel.fromMap(q['id'] as String, q)).toList(),
    );
  }
}

class ReportTopper {
  final String studentName;
  final double score;
  final double percentage;
  const ReportTopper({required this.studentName, required this.score, required this.percentage});

  factory ReportTopper.fromJson(Map<String, dynamic> json) => ReportTopper(
        studentName: json['studentName'] as String,
        score: (json['score'] as num).toDouble(),
        percentage: (json['percentage'] as num).toDouble(),
      );
}

class ReportData {
  final String examTitle;
  final String subject;
  final int totalMarks;
  final int passingMarks;
  final int totalAttempts;
  final int passCount;
  final int failCount;
  final double passPercentage;
  final double averageScore;
  final double averagePercentage;
  final ReportTopper? topper;
  final List<ResultModel> attempts;

  const ReportData({
    required this.examTitle,
    required this.subject,
    required this.totalMarks,
    required this.passingMarks,
    required this.totalAttempts,
    required this.passCount,
    required this.failCount,
    required this.passPercentage,
    required this.averageScore,
    required this.averagePercentage,
    required this.topper,
    required this.attempts,
  });

  factory ReportData.fromJson(Map<String, dynamic> json) {
    final exam = json['exam'] as Map<String, dynamic>;
    return ReportData(
      examTitle: exam['title'] as String,
      subject: exam['subject'] as String,
      totalMarks: exam['totalMarks'] as int,
      passingMarks: exam['passingMarks'] as int,
      totalAttempts: json['totalAttempts'] as int,
      passCount: json['passCount'] as int,
      failCount: json['failCount'] as int,
      passPercentage: (json['passPercentage'] as num).toDouble(),
      averageScore: (json['averageScore'] as num).toDouble(),
      averagePercentage: (json['averagePercentage'] as num).toDouble(),
      topper: json['topper'] != null ? ReportTopper.fromJson(json['topper'] as Map<String, dynamic>) : null,
      attempts: (json['attempts'] as List).cast<Map<String, dynamic>>().map((a) => ResultModel.fromMap(a['id'] as String, a)).toList(),
    );
  }
}

/// Exam CRUD (admin), the two-step Excel-based creation flow (admin), and
/// exam browsing + attempt lifecycle (student) — one REST client for
/// everything exam-shaped, matching the spec's single exam_service.dart file.
class ExamService {
  final ApiService _api;
  ExamService({ApiService? api}) : _api = api ?? ApiService();

  Future<ExcelPreview> previewExcel(String filePath) async {
    final data = await _api.postMultipart('/admin/upload-excel/preview', fileField: 'file', filePath: filePath);
    return ExcelPreview.fromJson(data as Map<String, dynamic>);
  }

  Future<String> publishExam({
    required String title,
    required String subject,
    required int duration,
    required int totalMarks,
    required int passingMarks,
    required double negativeMarking,
    required DateTime startDate,
    required DateTime endDate,
    required String instructions,
    required ExcelPreview preview,
  }) async {
    final data = await _api.post('/admin/upload-excel', body: {
      'title': title,
      'subject': subject,
      'duration': duration,
      'totalMarks': totalMarks,
      'passingMarks': passingMarks,
      'negativeMarking': negativeMarking,
      'startDate': startDate.toIso8601String(),
      'endDate': endDate.toIso8601String(),
      'instructions': instructions,
      'excelUrl': preview.excelUrl,
      'excelPublicId': preview.excelPublicId,
      'questions': preview.questions
          .map((q) => {
                'questionNo': q.questionNo,
                'question': q.question,
                'options': q.options,
                'correctAnswer': q.correctAnswer,
              })
          .toList(),
    });
    return data['examId'] as String;
  }

  Future<List<ExamModel>> listExams() async {
    final data = await _api.get('/admin/exams');
    return (data['exams'] as List).cast<Map<String, dynamic>>().map((e) => ExamModel.fromMap(e['id'] as String, e)).toList();
  }

  Future<ExamModel> getExam(String id) async {
    final data = await _api.get('/admin/exam/$id');
    return ExamModel.fromMap(data['id'] as String, data as Map<String, dynamic>);
  }

  Future<void> updateExam(String id, Map<String, dynamic> updates) {
    return _api.put('/admin/exam/$id', body: updates);
  }

  Future<void> deleteExam(String id) {
    return _api.delete('/admin/exam/$id');
  }

  Future<ReportData> getExamReport(String examId) async {
    final data = await _api.get('/admin/report/$examId');
    return ReportData.fromJson(data as Map<String, dynamic>);
  }

  Future<String> exportReport(String examId, {required String format}) async {
    final data = await _api.post('/admin/report/$examId/export', body: {'format': format});
    return data['url'] as String;
  }

  Future<List<Map<String, dynamic>>> listStudents() async {
    final data = await _api.get('/admin/students');
    return (data['students'] as List).cast<Map<String, dynamic>>();
  }

  // --- Student ---

  Future<List<ExamModel>> listStudentExams() async {
    final data = await _api.get('/student/exams');
    return (data['exams'] as List).cast<Map<String, dynamic>>().map((e) => ExamModel.fromMap(e['id'] as String, e)).toList();
  }

  Future<StartExamData> startExam(String examId) async {
    final data = await _api.get('/student/exam/$examId/start');
    return StartExamData.fromJson(data as Map<String, dynamic>);
  }

  Future<ResultModel> submitExam(
    String examId, {
    required String attemptId,
    required Map<String, String> answers,
    required int timeTakenSeconds,
  }) async {
    final data = await _api.post('/student/exam/$examId/submit', body: {
      'attemptId': attemptId,
      'answers': answers,
      'timeTaken': timeTakenSeconds,
    });
    // The submit response carries the same result fields as a stored
    // attempt doc, minus studentName/examTitle/answers/startedAt context
    // the UI doesn't need immediately after submitting.
    return ResultModel.fromMap(attemptId, {
      ...data,
      'examId': examId,
      'answers': answers,
    });
  }

  Future<ResultModel> getResult(String examId) async {
    final data = await _api.get('/student/result/$examId');
    return ResultModel.fromMap(data['id'] as String, data as Map<String, dynamic>);
  }

  Future<List<ResultModel>> getHistory() async {
    final data = await _api.get('/student/history');
    return (data['attempts'] as List).cast<Map<String, dynamic>>().map((a) => ResultModel.fromMap(a['id'] as String, a)).toList();
  }

  Future<String> generateResultPdf(String attemptId) async {
    final data = await _api.post('/student/result/$attemptId/pdf');
    return data['resultPdfUrl'] as String;
  }
}
