const { db } = require('../config/firebase');
const { destroyAsset } = require('../utils/cloudinaryHelper');

/**
 * Persists a profile photo that the Flutter client already uploaded directly
 * to Cloudinary via the unsigned preset. Keeping the Firestore write here
 * (rather than letting the client write photoUrl itself) keeps user-doc
 * mutations server-authoritative and lets us clean up the previous image.
 */
async function saveProfileImage(req, res) {
  const { imageUrl, publicId } = req.body;

  if (!imageUrl || !publicId) {
    return res.status(400).json({ error: 'imageUrl and publicId are required' });
  }

  try {
    const userRef = db.collection('users').doc(req.user.uid);
    const userDoc = await userRef.get();
    const previousPublicId = userDoc.exists ? userDoc.data().photoPublicId : null;

    await userRef.update({ photoUrl: imageUrl, photoPublicId: publicId });

    if (previousPublicId && previousPublicId !== publicId) {
      await destroyAsset(previousPublicId, 'image').catch((err) =>
        console.error('Failed to clean up previous profile image:', err)
      );
    }

    return res.json({ photoUrl: imageUrl });
  } catch (err) {
    return res.status(500).json({ error: 'Failed to save profile image' });
  }
}

module.exports = { saveProfileImage };
