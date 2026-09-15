import 'package:flutter/foundation.dart';

import '../models/result_model.dart';
import '../services/api_service.dart';
import '../services/exam_service.dart';

class ResultProvider extends ChangeNotifier {
  final ExamService _examService;
  ResultProvider({ExamService? examService}) : _examService = examService ?? ExamService();

  ResultModel? currentResult;
  bool isLoadingResult = false;
  String? resultError;

  Future<void> fetchResult(String examId) async {
    isLoadingResult = true;
    resultError = null;
    notifyListeners();
    try {
      currentResult = await _examService.getResult(examId);
    } on ApiException catch (e) {
      resultError = e.message;
    } finally {
      isLoadingResult = false;
      notifyListeners();
    }
  }

  void setResult(ResultModel result) {
    currentResult = result;
    notifyListeners();
  }

  List<ResultModel> history = [];
  bool isLoadingHistory = false;
  String? historyError;

  Future<void> fetchHistory() async {
    isLoadingHistory = true;
    historyError = null;
    notifyListeners();
    try {
      history = await _examService.getHistory();
    } on ApiException catch (e) {
      historyError = e.message;
    } finally {
      isLoadingHistory = false;
      notifyListeners();
    }
  }

  bool isGeneratingPdf = false;

  Future<String?> generatePdf(String attemptId) async {
    isGeneratingPdf = true;
    notifyListeners();
    try {
      return await _examService.generateResultPdf(attemptId);
    } on ApiException catch (e) {
      resultError = e.message;
      return null;
    } finally {
      isGeneratingPdf = false;
      notifyListeners();
    }
  }
}
