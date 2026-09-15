const express = require('express');
const authMiddleware = require('../middlewares/authMiddleware');
const { saveProfileImage } = require('../controllers/uploadController');
const { listExamsForStudent } = require('../controllers/examController');
const { startExam, submitExam, getResult, getHistory, generateResultPdf } = require('../controllers/attemptController');

const router = express.Router();

router.use(authMiddleware);

router.post('/upload-profile', saveProfileImage);
router.get('/exams', listExamsForStudent);
router.get('/exam/:id/start', startExam);
router.post('/exam/:id/submit', submitExam);
router.get('/result/:examId', getResult);
router.post('/result/:attemptId/pdf', generateResultPdf);
router.get('/history', getHistory);

module.exports = router;
