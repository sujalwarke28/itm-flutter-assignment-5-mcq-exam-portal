const fs = require('fs');
const cloudinary = require('../config/cloudinary');

const FOLDERS = {
  profiles: 'mcq-portal/profiles',
  excelSheets: 'mcq-portal/excel-sheets',
  results: 'mcq-portal/results',
  questionImages: 'mcq-portal/question-images',
  // Not in the spec's literal folder list, but exam-report exports need
  // somewhere to live — nesting them under results keeps the sanctioned
  // top-level folder set unchanged while staying next to what they summarize.
  reports: 'mcq-portal/results/reports',
};

/** Uploads a raw (non-image) file — Excel sheets, result PDFs — via signed upload, then deletes the local temp file. */
async function uploadRaw(filePath, folder) {
  try {
    const result = await cloudinary.uploader.upload(filePath, {
      folder,
      resource_type: 'raw',
      use_filename: true,
      unique_filename: true,
    });
    return { url: result.secure_url, publicId: result.public_id };
  } finally {
    safeUnlink(filePath);
  }
}

async function destroyAsset(publicId, resourceType = 'image') {
  if (!publicId) return;
  await cloudinary.uploader.destroy(publicId, { resource_type: resourceType });
}

function safeUnlink(filePath) {
  fs.unlink(filePath, (err) => {
    if (err && err.code !== 'ENOENT') console.error('Failed to remove temp upload:', err);
  });
}

module.exports = { FOLDERS, uploadRaw, destroyAsset };
