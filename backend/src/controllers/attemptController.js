const PDFDocument = require('pdfkit');
const { db, admin } = require('../config/firebase');
const cloudinary = require('../config/cloudinary');
const { FOLDERS } = require('../utils/cloudinaryHelper');
const { getQuestionsForExam } = require('./questionController');
const { calculateResult } = require('../utils/resultCalculator');

/**
 * Starts an attempt: validates the exam window, enforces one attempt per
 * student per exam, records a server-timestamped `startedAt` (the backup
 * for the client-side countdown), and returns questions with correctAnswer
 * stripped — the critical rule that answers never reach the client early.
 */
async function startExam(req, res) {
  const examId = req.params.id;

  try {
    const examDoc = await db.collection('exams').doc(examId).get();
    if (!examDoc.exists) return res.status(404).json({ error: 'Exam not found' });
    const exam = examDoc.data();

    const now = new Date();
    if (now < exam.startDate.toDate() || now > exam.endDate.toDate()) {
      return res.status(403).json({ error: 'This exam is not currently active' });
    }

    const questions = await getQuestionsForExam(examId, { includeAnswers: false });
    const examSummary = {
      id: examId,
      title: exam.title,
      duration: exam.duration,
      totalMarks: exam.totalMarks,
      negativeMarking: exam.negativeMarking,
      instructions: exam.instructions,
    };

    const existing = await db
      .collection('attempts')
      .where('studentId', '==', req.user.uid)
      .where('examId', '==', examId)
      .limit(1)
      .get();

    if (!existing.empty) {
      const doc = existing.docs[0];
      const data = doc.data();

      if (data.status !== 'IN_PROGRESS') {
        return res.status(409).json({ error: 'You have already attempted this exam', attemptId: doc.id });
      }

      // Crash/refresh recovery: same attempt, same server-anchored start time.
      return res.json({
        attemptId: doc.id,
        resumed: true,
        savedAnswers: data.answers || {},
        startedAtMs: data.startedAt.toMillis(),
        exam: examSummary,
        questions,
      });
    }

    const studentDoc = await db.collection('users').doc(req.user.uid).get();
    const startedAt = new Date();

    const attemptRef = db.collection('attempts').doc();
    await attemptRef.set({
      studentId: req.user.uid,
      studentName: studentDoc.data()?.name || '',
      examId,
      examTitle: exam.title,
      answers: {},
      totalQuestions: exam.totalQuestions,
      attempted: 0,
      correct: 0,
      wrong: 0,
      unattempted: exam.totalQuestions,
      score: 0,
      percentage: 0,
      status: 'IN_PROGRESS',
      timeTaken: 0,
      resultPdfUrl: null,
      startedAt: admin.firestore.Timestamp.fromDate(startedAt),
      submittedAt: null,
    });

    return res.json({
      attemptId: attemptRef.id,
      resumed: false,
      savedAnswers: {},
      startedAtMs: startedAt.getTime(),
      exam: examSummary,
      questions,
    });
  } catch (err) {
    console.error(err);
    return res.status(500).json({ error: 'Failed to start exam' });
  }
}

/** Grades server-side against Firestore's correctAnswer values — never trusts the client's own scoring. */
async function submitExam(req, res) {
  const examId = req.params.id;
  const { attemptId, answers, timeTaken } = req.body;

  if (!attemptId || typeof answers !== 'object' || answers === null) {
    return res.status(400).json({ error: 'attemptId and answers are required' });
  }

  try {
    const attemptRef = db.collection('attempts').doc(attemptId);
    const attemptDoc = await attemptRef.get();

    if (!attemptDoc.exists || attemptDoc.data().studentId !== req.user.uid || attemptDoc.data().examId !== examId) {
      return res.status(404).json({ error: 'Attempt not found' });
    }
    if (attemptDoc.data().status !== 'IN_PROGRESS') {
      return res.status(409).json({ error: 'This attempt has already been submitted' });
    }

    const examDoc = await db.collection('exams').doc(examId).get();
    const exam = examDoc.data();
    const questions = await getQuestionsForExam(examId, { includeAnswers: true });

    // Server-side timer backup: the client auto-submits at 0 and this is the
    // grace window for that request's own network latency. The client-side
    // timer is what students actually experience; this is a backstop against
    // a tampered client that skips auto-submit and submits much later — we
    // can't reconstruct answers "as of the deadline" from a single snapshot,
    // so a submission this late is forfeited (graded as 0/FAIL) rather than
    // silently scored as if it were on time.
    const TIMER_GRACE_SECONDS = 120;
    const elapsedSeconds = (Date.now() - attemptDoc.data().startedAt.toMillis()) / 1000;

    if (elapsedSeconds > exam.duration * 60 + TIMER_GRACE_SECONDS) {
      const forfeited = {
        answers: {},
        attempted: 0,
        correct: 0,
        wrong: 0,
        unattempted: questions.length,
        score: 0,
        percentage: 0,
        status: 'FAIL',
        timeTaken: exam.duration * 60,
        submittedAt: admin.firestore.FieldValue.serverTimestamp(),
      };
      await attemptRef.update(forfeited);
      return res.status(409).json({
        error: `Submitted too long after the ${exam.duration}-minute time limit and was forfeited.`,
        attemptId,
        ...forfeited,
      });
    }

    const result = calculateResult({
      questions,
      answers,
      totalMarks: exam.totalMarks,
      passingMarks: exam.passingMarks,
      negativeMarking: exam.negativeMarking,
    });

    await attemptRef.update({
      answers,
      ...result,
      timeTaken: Number(timeTaken) || 0,
      submittedAt: admin.firestore.FieldValue.serverTimestamp(),
    });

    // Safe to reveal correctAnswer now — the exam is submitted, not in progress.
    return res.json({ attemptId, ...result, questions });
  } catch (err) {
    console.error(err);
    return res.status(500).json({ error: 'Failed to submit exam' });
  }
}

async function getResult(req, res) {
  try {
    const snap = await db
      .collection('attempts')
      .where('studentId', '==', req.user.uid)
      .where('examId', '==', req.params.examId)
      .limit(1)
      .get();

    if (snap.empty) return res.status(404).json({ error: 'No attempt found for this exam' });

    const doc = snap.docs[0];
    const attempt = doc.data();

    // Only reveal correctAnswer once the attempt is no longer in progress.
    const questions = attempt.status === 'IN_PROGRESS' ? [] : await getQuestionsForExam(attempt.examId, { includeAnswers: true });

    return res.json({ id: doc.id, ...attempt, questions });
  } catch (err) {
    return res.status(500).json({ error: 'Failed to fetch result' });
  }
}

async function getHistory(req, res) {
  try {
    const snap = await db.collection('attempts').where('studentId', '==', req.user.uid).get();
    const attempts = snap.docs
      .map((doc) => ({ id: doc.id, ...doc.data() }))
      .sort((a, b) => (b.submittedAt?.toMillis() || 0) - (a.submittedAt?.toMillis() || 0));
    return res.json({ attempts });
  } catch (err) {
    return res.status(500).json({ error: 'Failed to fetch history' });
  }
}

function buildResultPdfBuffer({ attempt, exam, questions }) {
  return new Promise((resolve, reject) => {
    const doc = new PDFDocument({ margin: 50 });
    const chunks = [];
    doc.on('data', (chunk) => chunks.push(chunk));
    doc.on('end', () => resolve(Buffer.concat(chunks)));
    doc.on('error', reject);

    doc.fontSize(20).text('MCQ Exam Portal — Result', { align: 'center' });
    doc.moveDown();
    doc.fontSize(14).text(exam.title);
    doc.fontSize(10).fillColor('#555555').text(exam.subject);
    doc.moveDown();

    doc.fillColor('#000000').fontSize(11);
    doc.text(`Student: ${attempt.studentName}`);
    doc.text(`Status: ${attempt.status}`);
    doc.text(`Score: ${attempt.score} / ${exam.totalMarks}`);
    doc.text(`Percentage: ${attempt.percentage}%`);
    doc.text(`Correct: ${attempt.correct}   Wrong: ${attempt.wrong}   Unattempted: ${attempt.unattempted}`);
    doc.text(`Time taken: ${Math.round(attempt.timeTaken / 60)} min ${attempt.timeTaken % 60}s`);
    doc.moveDown();

    doc.fontSize(13).text('Question-wise analysis', { underline: true });
    doc.moveDown(0.5);

    questions.forEach((q) => {
      const given = attempt.answers[q.id];
      const isCorrect = given === q.correctAnswer;

      doc.fontSize(10).fillColor('#000000').text(`Q${q.questionNo}. ${q.question}`);
      doc
        .fillColor(given ? (isCorrect ? '#10B981' : '#EF4444') : '#888888')
        .text(`Your answer: ${given || '(not attempted)'}    Correct answer: ${q.correctAnswer}`);
      doc.moveDown(0.5);
    });

    doc.end();
  });
}

/** Generates the result PDF once and caches its Cloudinary URL on the attempt — re-requests just return the cached link. */
async function generateResultPdf(req, res) {
  const { attemptId } = req.params;

  try {
    const attemptRef = db.collection('attempts').doc(attemptId);
    const attemptDoc = await attemptRef.get();

    if (!attemptDoc.exists || attemptDoc.data().studentId !== req.user.uid) {
      return res.status(404).json({ error: 'Attempt not found' });
    }

    const attempt = attemptDoc.data();
    if (attempt.status === 'IN_PROGRESS') {
      return res.status(400).json({ error: 'This exam has not been submitted yet' });
    }
    if (attempt.resultPdfUrl) {
      return res.json({ resultPdfUrl: attempt.resultPdfUrl });
    }

    const examDoc = await db.collection('exams').doc(attempt.examId).get();
    const exam = examDoc.data();
    const questions = await getQuestionsForExam(attempt.examId, { includeAnswers: true });

    const pdfBuffer = await buildResultPdfBuffer({ attempt, exam, questions });

    const uploadResult = await new Promise((resolve, reject) => {
      const stream = cloudinary.uploader.upload_stream(
        { folder: FOLDERS.results, resource_type: 'raw', public_id: `result_${attemptId}`, overwrite: true },
        (err, result) => (err ? reject(err) : resolve(result))
      );
      stream.end(pdfBuffer);
    });

    await attemptRef.update({ resultPdfUrl: uploadResult.secure_url });
    return res.json({ resultPdfUrl: uploadResult.secure_url });
  } catch (err) {
    console.error(err);
    return res.status(500).json({ error: 'Failed to generate result PDF' });
  }
}

module.exports = { startExam, submitExam, getResult, getHistory, generateResultPdf };
