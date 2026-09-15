const fs = require('fs');
const { db, admin } = require('../config/firebase');
const { uploadRaw, destroyAsset, FOLDERS } = require('../utils/cloudinaryHelper');
const { parseExcelFile, ExcelValidationError } = require('../utils/excelParser');
const { getQuestionsForExam } = require('./questionController');

const VALID_ANSWERS = ['A', 'B', 'C', 'D'];
const QUESTION_BATCH_SIZE = 450; // margin under Firestore's 500-write batch cap

/**
 * Step 1 of exam creation: parse + validate the sheet and upload it to
 * Cloudinary, but don't touch Firestore yet — the admin UI shows this as a
 * preview and lets the admin fill in exam metadata before publishing.
 */
async function previewExcel(req, res) {
  if (!req.file) return res.status(400).json({ error: 'No file uploaded' });

  let questions;
  try {
    questions = parseExcelFile(req.file.path);
  } catch (err) {
    fs.unlink(req.file.path, () => {});
    if (err instanceof ExcelValidationError) {
      return res.status(400).json({ error: err.message, details: err.details });
    }
    return res.status(400).json({ error: 'Could not parse the uploaded file. Is it a valid .xlsx or .csv?' });
  }

  try {
    const { url, publicId } = await uploadRaw(req.file.path, FOLDERS.excelSheets);
    return res.json({ excelUrl: url, excelPublicId: publicId, totalQuestions: questions.length, questions });
  } catch (err) {
    console.error(err);
    return res.status(500).json({ error: 'Failed to upload the Excel file to Cloudinary' });
  }
}

/** Step 2: admin confirms metadata + reviewed questions, we write everything to Firestore. */
async function publishExam(req, res) {
  const {
    title, subject, duration, totalMarks, passingMarks, negativeMarking,
    startDate, endDate, instructions, excelUrl, excelPublicId, questions,
  } = req.body;

  if (!title || !subject || !duration || !totalMarks || !passingMarks || !startDate || !endDate ||
      !excelUrl || !Array.isArray(questions) || questions.length === 0) {
    return res.status(400).json({ error: 'Missing required exam fields' });
  }

  const invalidRow = questions.find((q) => !VALID_ANSWERS.includes(String(q.correctAnswer).toUpperCase()));
  if (invalidRow) {
    return res.status(400).json({ error: `Invalid correct answer for question ${invalidRow.questionNo}` });
  }

  const parsedStart = new Date(startDate);
  const parsedEnd = new Date(endDate);
  if (Number.isNaN(parsedStart.getTime()) || Number.isNaN(parsedEnd.getTime()) || parsedEnd <= parsedStart) {
    return res.status(400).json({ error: 'endDate must be a valid date after startDate' });
  }

  const numericFields = { duration: Number(duration), totalMarks: Number(totalMarks), passingMarks: Number(passingMarks) };
  const invalidNumeric = Object.entries(numericFields).find(([, v]) => Number.isNaN(v) || v <= 0);
  if (invalidNumeric) {
    return res.status(400).json({ error: `Invalid ${invalidNumeric[0]}` });
  }

  const totalQuestions = questions.length;
  const marksPerQuestion = Number(totalMarks) / totalQuestions;

  try {
    const examRef = db.collection('exams').doc();

    await examRef.set({
      title,
      subject,
      duration: Number(duration),
      totalMarks: Number(totalMarks),
      passingMarks: Number(passingMarks),
      negativeMarking: Number(negativeMarking) || 0,
      totalQuestions,
      instructions: instructions || '',
      startDate: parsedStart,
      endDate: parsedEnd,
      excelUrl,
      excelPublicId: excelPublicId || null,
      createdBy: req.user.uid,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
    });

    for (let i = 0; i < questions.length; i += QUESTION_BATCH_SIZE) {
      const batch = db.batch();
      questions.slice(i, i + QUESTION_BATCH_SIZE).forEach((q, offset) => {
        const questionNo = q.questionNo ?? i + offset + 1;
        const qRef = examRef.collection('questions').doc(`q${questionNo}`);
        batch.set(qRef, {
          questionNo,
          question: q.question,
          imageUrl: q.imageUrl || null,
          options: q.options,
          correctAnswer: String(q.correctAnswer).toUpperCase(),
          marks: marksPerQuestion,
        });
      });
      await batch.commit();
    }

    return res.status(201).json({ examId: examRef.id });
  } catch (err) {
    console.error(err);
    return res.status(500).json({ error: 'Failed to create exam' });
  }
}

async function listExams(req, res) {
  try {
    const snap = await db.collection('exams').orderBy('createdAt', 'desc').get();
    const exams = snap.docs.map((doc) => ({ id: doc.id, ...doc.data() }));
    return res.json({ exams });
  } catch (err) {
    return res.status(500).json({ error: 'Failed to fetch exams' });
  }
}

async function getExam(req, res) {
  try {
    const examDoc = await db.collection('exams').doc(req.params.id).get();
    if (!examDoc.exists) return res.status(404).json({ error: 'Exam not found' });

    const questions = await getQuestionsForExam(req.params.id, { includeAnswers: true });
    return res.json({ id: examDoc.id, ...examDoc.data(), questions });
  } catch (err) {
    return res.status(500).json({ error: 'Failed to fetch exam' });
  }
}

const NUMERIC_FIELDS = ['duration', 'totalMarks', 'passingMarks', 'negativeMarking'];
const DATE_FIELDS = ['startDate', 'endDate'];
const UPDATABLE_FIELDS = ['title', 'subject', 'instructions', ...NUMERIC_FIELDS, ...DATE_FIELDS];

async function updateExam(req, res) {
  const updates = {};
  for (const key of UPDATABLE_FIELDS) {
    if (req.body[key] === undefined) continue;

    if (DATE_FIELDS.includes(key)) {
      const date = new Date(req.body[key]);
      if (Number.isNaN(date.getTime())) return res.status(400).json({ error: `Invalid ${key}` });
      updates[key] = date;
    } else if (NUMERIC_FIELDS.includes(key)) {
      const num = Number(req.body[key]);
      if (Number.isNaN(num) || num < 0) return res.status(400).json({ error: `Invalid ${key}` });
      updates[key] = num;
    } else {
      updates[key] = req.body[key];
    }
  }

  if (updates.startDate && updates.endDate && updates.endDate <= updates.startDate) {
    return res.status(400).json({ error: 'endDate must be after startDate' });
  }

  if (Object.keys(updates).length === 0) {
    return res.status(400).json({ error: 'No valid fields to update' });
  }

  try {
    const examRef = db.collection('exams').doc(req.params.id);
    const examDoc = await examRef.get();
    if (!examDoc.exists) return res.status(404).json({ error: 'Exam not found' });

    await examRef.update(updates);
    return res.json({ id: req.params.id, ...examDoc.data(), ...updates });
  } catch (err) {
    return res.status(500).json({ error: 'Failed to update exam' });
  }
}

async function deleteExam(req, res) {
  try {
    const examRef = db.collection('exams').doc(req.params.id);
    const examDoc = await examRef.get();
    if (!examDoc.exists) return res.status(404).json({ error: 'Exam not found' });

    const { excelPublicId } = examDoc.data();

    const questionsSnap = await examRef.collection('questions').get();
    for (let i = 0; i < questionsSnap.docs.length; i += QUESTION_BATCH_SIZE) {
      const batch = db.batch();
      questionsSnap.docs.slice(i, i + QUESTION_BATCH_SIZE).forEach((doc) => batch.delete(doc.ref));
      await batch.commit();
    }

    if (excelPublicId) {
      await destroyAsset(excelPublicId, 'raw').catch((err) => console.error('Failed to delete excel from Cloudinary:', err));
    }

    await examRef.delete();
    return res.json({ success: true });
  } catch (err) {
    return res.status(500).json({ error: 'Failed to delete exam' });
  }
}

/** Student-facing exam list — flags exams the student has already attempted so the UI can show "View result" instead of "Start". */
async function listExamsForStudent(req, res) {
  try {
    const [examsSnap, attemptsSnap] = await Promise.all([
      db.collection('exams').orderBy('startDate', 'desc').get(),
      db.collection('attempts').where('studentId', '==', req.user.uid).get(),
    ]);

    const attemptedExamIds = new Set(attemptsSnap.docs.map((doc) => doc.data().examId));
    const exams = examsSnap.docs.map((doc) => ({
      id: doc.id,
      ...doc.data(),
      attempted: attemptedExamIds.has(doc.id),
    }));

    return res.json({ exams });
  } catch (err) {
    return res.status(500).json({ error: 'Failed to fetch exams' });
  }
}

module.exports = { previewExcel, publishExam, listExams, getExam, updateExam, deleteExam, listExamsForStudent };
