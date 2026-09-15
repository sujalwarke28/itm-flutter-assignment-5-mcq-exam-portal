import 'package:flutter/foundation.dart';

import '../models/exam_model.dart';
import '../models/result_model.dart';
import '../services/api_service.dart';
import '../services/exam_service.dart';

class ExamProvider extends ChangeNotifier {
  final ExamService _examService;
  ExamProvider({ExamService? examService}) : _examService = examService ?? ExamService();

  // --- Exam list (admin "manage exams" and student "browse exams") ---
  List<ExamModel> exams = [];
  bool isLoadingExams = false;
  String? listError;

  Future<void> fetchAdminExams() async {
    isLoadingExams = true;
    listError = null;
    notifyListeners();
    try {
      exams = await _examService.listExams();
    } on ApiException catch (e) {
      listError = e.message;
    } finally {
      isLoadingExams = false;
      notifyListeners();
    }
  }

  Future<void> fetchStudentExams() async {
    isLoadingExams = true;
    listError = null;
    notifyListeners();
    try {
      exams = await _examService.listStudentExams();
    } on ApiException catch (e) {
      listError = e.message;
    } finally {
      isLoadingExams = false;
      notifyListeners();
    }
  }

  Future<bool> updateExam(String id, Map<String, dynamic> updates) async {
    try {
      await _examService.updateExam(id, updates);
      await fetchAdminExams();
      return true;
    } on ApiException catch (e) {
      listError = e.message;
      notifyListeners();
      return false;
    }
  }

  Future<bool> deleteExam(String id) async {
    try {
      await _examService.deleteExam(id);
      exams = exams.where((e) => e.id != id).toList();
      notifyListeners();
      return true;
    } on ApiException catch (e) {
      listError = e.message;
      notifyListeners();
      return false;
    }
  }

  // --- Excel upload -> preview -> publish creation flow ---
  ExcelPreview? preview;
  bool isPreviewing = false;
  bool isPublishing = false;
  String? creationError;

  Future<bool> previewExcel(String filePath) async {
    isPreviewing = true;
    creationError = null;
    preview = null;
    notifyListeners();
    try {
      preview = await _examService.previewExcel(filePath);
      return true;
    } on ApiException catch (e) {
      creationError = e.message;
      return false;
    } finally {
      isPreviewing = false;
      notifyListeners();
    }
  }

  Future<String?> publishExam({
    required String title,
    required String subject,
    required int duration,
    required int totalMarks,
    required int passingMarks,
    required double negativeMarking,
    required DateTime startDate,
    required DateTime endDate,
    required String instructions,
  }) async {
    if (preview == null) return null;
    isPublishing = true;
    creationError = null;
    notifyListeners();
    try {
      final examId = await _examService.publishExam(
        title: title,
        subject: subject,
        duration: duration,
        totalMarks: totalMarks,
        passingMarks: passingMarks,
        negativeMarking: negativeMarking,
        startDate: startDate,
        endDate: endDate,
        instructions: instructions,
        preview: preview!,
      );
      resetCreationFlow();
      return examId;
    } on ApiException catch (e) {
      creationError = e.message;
      return null;
    } finally {
      isPublishing = false;
      notifyListeners();
    }
  }

  void resetCreationFlow() {
    preview = null;
    creationError = null;
    notifyListeners();
  }

  // --- Active attempt lifecycle (student exam-taking) ---
  bool isStartingExam = false;
  String? attemptError;

  Future<StartExamData?> startExam(String examId) async {
    isStartingExam = true;
    attemptError = null;
    notifyListeners();
    try {
      return await _examService.startExam(examId);
    } on ApiException catch (e) {
      attemptError = e.message;
      return null;
    } finally {
      isStartingExam = false;
      notifyListeners();
    }
  }

  Future<ResultModel?> submitExam(
    String examId, {
    required String attemptId,
    required Map<String, String> answers,
    required int timeTakenSeconds,
  }) async {
    try {
      return await _examService.submitExam(examId, attemptId: attemptId, answers: answers, timeTakenSeconds: timeTakenSeconds);
    } on ApiException catch (e) {
      attemptError = e.message;
      notifyListeners();
      return null;
    }
  }

  // --- Admin reports ---
  ReportData? report;
  bool isLoadingReport = false;
  String? reportError;
  bool isExportingReport = false;

  Future<void> fetchReport(String examId) async {
    isLoadingReport = true;
    reportError = null;
    notifyListeners();
    try {
      report = await _examService.getExamReport(examId);
    } on ApiException catch (e) {
      reportError = e.message;
    } finally {
      isLoadingReport = false;
      notifyListeners();
    }
  }

  Future<String?> exportReport(String examId, {required String format}) async {
    isExportingReport = true;
    notifyListeners();
    try {
      return await _examService.exportReport(examId, format: format);
    } on ApiException catch (e) {
      reportError = e.message;
      return null;
    } finally {
      isExportingReport = false;
      notifyListeners();
    }
  }
}
