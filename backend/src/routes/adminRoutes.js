const express = require('express');
const authMiddleware = require('../middlewares/authMiddleware');
const adminMiddleware = require('../middlewares/adminMiddleware');
const { excelUpload } = require('../middlewares/uploadMiddleware');
const examController = require('../controllers/examController');
const { getExamReport, exportReport } = require('../controllers/reportController');
const { listStudents } = require('../controllers/authController');

const router = express.Router();

router.use(authMiddleware, adminMiddleware);

router.post('/upload-excel/preview', excelUpload.single('file'), examController.previewExcel);
router.post('/upload-excel', examController.publishExam);
router.get('/exams', examController.listExams);
router.get('/exam/:id', examController.getExam);
router.put('/exam/:id', examController.updateExam);
router.delete('/exam/:id', examController.deleteExam);
router.get('/students', listStudents);
router.get('/report/:examId', getExamReport);
router.post('/report/:examId/export', exportReport);

module.exports = router;
