const { db } = require('../config/firebase');

/**
 * Shared question fetch/format used by both the admin exam-detail view
 * (includeAnswers: true) and the student start-exam view (includeAnswers:
 * false — correct answers must never reach the client before submission).
 */
async function getQuestionsForExam(examId, { includeAnswers = false } = {}) {
  const snap = await db.collection('exams').doc(examId).collection('questions').orderBy('questionNo').get();

  return snap.docs.map((doc) => {
    const data = doc.data();
    const question = {
      id: doc.id,
      questionNo: data.questionNo,
      question: data.question,
      imageUrl: data.imageUrl || null,
      options: data.options,
      marks: data.marks,
    };
    if (includeAnswers) question.correctAnswer = data.correctAnswer;
    return question;
  });
}

module.exports = { getQuestionsForExam };
