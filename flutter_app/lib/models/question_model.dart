class QuestionModel {
  final String id;
  final int questionNo;
  final String question;
  final String? imageUrl;
  final List<String> options;
  final int marks;

  /// Null whenever this model is built from the student-facing `/exam/:id/start`
  /// payload — the backend strips correct answers before sending questions,
  /// so this must never be relied on client-side during an active attempt.
  final String? correctAnswer;

  const QuestionModel({
    required this.id,
    required this.questionNo,
    required this.question,
    this.imageUrl,
    required this.options,
    required this.marks,
    this.correctAnswer,
  });

  factory QuestionModel.fromMap(String id, Map<String, dynamic> map) {
    return QuestionModel(
      id: id,
      questionNo: (map['questionNo'] as num?)?.toInt() ?? 0,
      question: map['question'] as String? ?? '',
      imageUrl: map['imageUrl'] as String?,
      options: (map['options'] as List?)?.map((e) => e.toString()).toList() ?? const [],
      marks: (map['marks'] as num?)?.toInt() ?? 1,
      correctAnswer: map['correctAnswer'] as String?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'questionNo': questionNo,
      'question': question,
      'imageUrl': imageUrl,
      'options': options,
      'marks': marks,
      'correctAnswer': correctAnswer,
    };
  }
}
