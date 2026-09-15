/**
 * Server-side auto-grading. Per question: correct -> +marks; wrong ->
 * -negativeMarking*marks (only if negativeMarking > 0); unattempted -> 0.
 * `status` compares percentage against passingMarks expressed as a
 * percentage of totalMarks, so admins can set passingMarks in absolute
 * marks on the exam form while grading stays percentage-based.
 */
function calculateResult({ questions, answers, totalMarks, passingMarks, negativeMarking }) {
  let correct = 0;
  let wrong = 0;
  let score = 0;

  questions.forEach((q) => {
    const given = answers[q.id];
    if (!given) return;

    if (String(given).toUpperCase() === q.correctAnswer) {
      correct += 1;
      score += q.marks;
    } else {
      wrong += 1;
      if (negativeMarking > 0) score -= negativeMarking * q.marks;
    }
  });

  const attempted = correct + wrong;
  const unattempted = questions.length - attempted;
  const percentage = totalMarks > 0 ? (score / totalMarks) * 100 : 0;
  const passingPercentage = totalMarks > 0 ? (passingMarks / totalMarks) * 100 : 0;
  const status = percentage >= passingPercentage ? 'PASS' : 'FAIL';

  return {
    attempted,
    correct,
    wrong,
    unattempted,
    score: Number(score.toFixed(2)),
    percentage: Number(percentage.toFixed(2)),
    status,
  };
}

module.exports = { calculateResult };
