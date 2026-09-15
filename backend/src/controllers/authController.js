const { db } = require('../config/firebase');

async function getMe(req, res) {
  try {
    const userDoc = await db.collection('users').doc(req.user.uid).get();

    if (!userDoc.exists) {
      return res.status(404).json({ error: 'User profile not found. Complete signup first.' });
    }

    return res.json({ uid: req.user.uid, ...userDoc.data() });
  } catch (err) {
    return res.status(500).json({ error: 'Failed to fetch user profile' });
  }
}

async function listStudents(req, res) {
  try {
    const snap = await db.collection('users').where('role', '==', 'student').get();
    const students = snap.docs
      .map((doc) => ({ uid: doc.id, ...doc.data() }))
      .sort((a, b) => (a.name || '').localeCompare(b.name || ''));
    return res.json({ students });
  } catch (err) {
    return res.status(500).json({ error: 'Failed to fetch students' });
  }
}

module.exports = { getMe, listStudents };
