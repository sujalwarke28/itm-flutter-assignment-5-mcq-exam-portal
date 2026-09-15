const XLSX = require('xlsx');

const REQUIRED_HEADERS = ['Question No.', 'Question', 'Option A', 'Option B', 'Option C', 'Option D', 'Correct Answer'];
const VALID_ANSWERS = ['A', 'B', 'C', 'D'];

class ExcelValidationError extends Error {
  constructor(message, details = []) {
    super(message);
    this.details = details;
  }
}

/**
 * Parses and validates an uploaded Excel/CSV question sheet. Rejects the
 * whole file on any invalid row (rather than silently dropping rows) so the
 * admin gets one clear list of everything to fix and re-upload.
 */
function parseExcelFile(filePath) {
  const workbook = XLSX.readFile(filePath);
  const sheet = workbook.Sheets[workbook.SheetNames[0]];
  const rows = XLSX.utils.sheet_to_json(sheet, { defval: '' });

  if (rows.length === 0) {
    throw new ExcelValidationError('The uploaded file has no data rows.');
  }

  const headers = Object.keys(rows[0]);
  const missingHeaders = REQUIRED_HEADERS.filter((h) => !headers.includes(h));
  if (missingHeaders.length > 0) {
    throw new ExcelValidationError(`Missing required column(s): ${missingHeaders.join(', ')}`);
  }

  const errors = [];
  const questions = rows.map((row, idx) => {
    const rowNo = idx + 2; // +1 for 0-index, +1 for the header row
    const correctAnswer = String(row['Correct Answer']).trim().toUpperCase();
    const question = String(row['Question'] ?? '').trim();
    const options = [
      String(row['Option A'] ?? '').trim(),
      String(row['Option B'] ?? '').trim(),
      String(row['Option C'] ?? '').trim(),
      String(row['Option D'] ?? '').trim(),
    ];
    const questionNo = Number(row['Question No.']) || idx + 1;

    if (!VALID_ANSWERS.includes(correctAnswer)) {
      errors.push(`Row ${rowNo}: "Correct Answer" must be one of A/B/C/D (got "${row['Correct Answer']}")`);
    }
    if (!question) errors.push(`Row ${rowNo}: "Question" is empty`);
    if (options.some((o) => !o)) errors.push(`Row ${rowNo}: one or more options are empty`);

    return { questionNo, question, options, correctAnswer };
  });

  if (errors.length > 0) {
    throw new ExcelValidationError('The uploaded file has invalid rows.', errors);
  }

  return questions;
}

module.exports = { parseExcelFile, ExcelValidationError };
