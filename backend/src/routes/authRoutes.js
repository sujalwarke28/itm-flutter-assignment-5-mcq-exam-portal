const express = require('express');
const authMiddleware = require('../middlewares/authMiddleware');
const { getMe } = require('../controllers/authController');

const router = express.Router();

router.get('/me', authMiddleware, getMe);

module.exports = router;
