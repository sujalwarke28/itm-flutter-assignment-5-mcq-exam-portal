const ExcelJS = require('exceljs');
const PDFDocument = require('pdfkit');
const { db } = require('../config/firebase');
const cloudinary = require('../config/cloudinary');
const { FOLDERS } = require('../utils/cloudinaryHelper');

async function fetchSubmittedAttempts(examId) {
  const snap = await db.collection('attempts').where('examId', '==', examId).get();
  return snap.docs
    .map((doc) => ({ id: doc.id, ...doc.data() }))
    .filter((a) => a.status !== 'IN_PROGRESS')
    .sort((a, b) => b.score - a.score);
}

/** Exam-wise report: stats + a ranked attempt list the admin UI sorts client-side (by score/date/name). */
async function getExamReport(req, res) {
  const { examId } = req.params;

  try {
    const examDoc = await db.collection('exams').doc(examId).get();
    if (!examDoc.exists) return res.status(404).json({ error: 'Exam not found' });
    const exam = examDoc.data();

    const attempts = await fetchSubmittedAttempts(examId);
    const totalAttempts = attempts.length;
    const passCount = attempts.filter((a) => a.status === 'PASS').length;
    const averageScore = totalAttempts ? attempts.reduce((sum, a) => sum + a.score, 0) / totalAttempts : 0;
    const averagePercentage = totalAttempts ? attempts.reduce((sum, a) => sum + a.percentage, 0) / totalAttempts : 0;

    return res.json({
      exam: { id: examId, title: exam.title, subject: exam.subject, totalMarks: exam.totalMarks, passingMarks: exam.passingMarks },
      totalAttempts,
      passCount,
      failCount: totalAttempts - passCount,
      passPercentage: totalAttempts ? Number(((passCount / totalAttempts) * 100).toFixed(2)) : 0,
      averageScore: Number(averageScore.toFixed(2)),
      averagePercentage: Number(averagePercentage.toFixed(2)),
      topper: attempts[0]
        ? { studentName: attempts[0].studentName, score: attempts[0].score, percentage: attempts[0].percentage }
        : null,
      attempts,
    });
  } catch (err) {
    console.error(err);
    return res.status(500).json({ error: 'Failed to build report' });
  }
}

async function buildReportExcelBuffer(exam, attempts) {
  const workbook = new ExcelJS.Workbook();
  const sheet = workbook.addWorksheet('Report');
  sheet.columns = [
    { header: 'Rank', key: 'rank', width: 8 },
    { header: 'Student', key: 'studentName', width: 26 },
    { header: 'Score', key: 'score', width: 10 },
    { header: 'Percentage', key: 'percentage', width: 12 },
    { header: 'Status', key: 'status', width: 10 },
    { header: 'Correct', key: 'correct', width: 10 },
    { header: 'Wrong', key: 'wrong', width: 10 },
    { header: 'Unattempted', key: 'unattempted', width: 12 },
  ];
  sheet.getRow(1).font = { bold: true };

  attempts.forEach((a, i) =>
    sheet.addRow({
      rank: i + 1,
      studentName: a.studentName,
      score: a.score,
      percentage: a.percentage,
      status: a.status,
      correct: a.correct,
      wrong: a.wrong,
      unattempted: a.unattempted,
    })
  );

  return workbook.xlsx.writeBuffer();
}

function buildReportPdfBuffer(exam, attempts) {
  return new Promise((resolve, reject) => {
    const doc = new PDFDocument({ margin: 40 });
    const chunks = [];
    doc.on('data', (c) => chunks.push(c));
    doc.on('end', () => resolve(Buffer.concat(chunks)));
    doc.on('error', reject);

    doc.fontSize(18).text(`Report — ${exam.title}`, { align: 'center' });
    doc.fontSize(10).fillColor('#555555').text(exam.subject, { align: 'center' });
    doc.moveDown();

    doc.fillColor('#000000').fontSize(10);
    attempts.forEach((a, i) => {
      doc.text(`${i + 1}. ${a.studentName} — ${a.score} pts (${a.percentage}%) — ${a.status}`);
    });

    if (attempts.length === 0) doc.text('No submitted attempts yet.');
    doc.end();
  });
}

async function exportReport(req, res) {
  const { examId } = req.params;
  const format = String(req.body.format || req.query.format || 'excel').toLowerCase();

  try {
    const examDoc = await db.collection('exams').doc(examId).get();
    if (!examDoc.exists) return res.status(404).json({ error: 'Exam not found' });
    const exam = examDoc.data();

    const attempts = await fetchSubmittedAttempts(examId);
    const isPdf = format === 'pdf';
    const buffer = isPdf ? await buildReportPdfBuffer(exam, attempts) : await buildReportExcelBuffer(exam, attempts);

    const uploadResult = await new Promise((resolve, reject) => {
      const stream = cloudinary.uploader.upload_stream(
        { folder: FOLDERS.reports, resource_type: 'raw', public_id: `report_${examId}_${Date.now()}` },
        (err, result) => (err ? reject(err) : resolve(result))
      );
      stream.end(buffer);
    });

    return res.json({ url: uploadResult.secure_url, format: isPdf ? 'pdf' : 'excel' });
  } catch (err) {
    console.error(err);
    return res.status(500).json({ error: 'Failed to export report' });
  }
}

module.exports = { getExamReport, exportReport };
