#!/usr/bin/env node
// Lint a tutor-session plan file against references/plan-template.md.
//
// Used by stop-check.js (blocks a reply while the plan drifts from the shape),
// by tutor.js check, and by the tests. Exported for require(); also a CLI:
//   node plan-lint.js <path/to/plan.md>     prints problems, exit 1 if any
//
// The shape matters because the headings and header fields are what every
// tool (and the tutor itself after a context compaction) parses to resume.

'use strict';
const fs = require('fs');

const REQUIRED_FIELDS = ['slug', 'created', 'updated', 'status', 'quizzes', 'depth', 'pace'];
const REQUIRED_HEADINGS = [
  'Goal', 'Student Profile', 'Materials', 'Outline', 'Current Unit',
  'Position', 'Learn Later', 'Misconceptions Caught', 'Session Log',
];
const PLACEHOLDERS = ['<kebab-case-slug>', '<YYYY-MM-DD>', '<topic title>', '<Unit title>'];

function sectionBody(lines, heading) {
  const start = lines.findIndex((l) => l.trim() === `# ${heading}`);
  if (start === -1) return null;
  const body = [];
  for (let i = start + 1; i < lines.length; i++) {
    if (/^# /.test(lines[i])) break;
    body.push(lines[i]);
  }
  return body;
}

function lintPlan(text) {
  const problems = [];
  const lines = text.split(/\r?\n/);
  const headings = lines.filter((l) => /^# /.test(l)).map((l) => l.slice(2).trim());

  for (const h of REQUIRED_HEADINGS) {
    if (!headings.includes(h)) problems.push(`missing heading "# ${h}"`);
  }
  for (const h of headings) {
    if (!REQUIRED_HEADINGS.includes(h) && !/^Tutor Session:/.test(h)) {
      problems.push(`unexpected top-level heading "# ${h}" (use "## ${h}" inside a section instead)`);
    }
  }
  for (const f of REQUIRED_FIELDS) {
    if (!lines.some((l) => new RegExp(`^${f}:\\s*\\S`).test(l))) {
      problems.push(`missing header field "${f}: <value>" at the start of a line near the top`);
    }
  }
  const quizzes = lines.find((l) => /^quizzes:/.test(l));
  if (quizzes && !/^quizzes:\s*(on|off)\s*$/.test(quizzes)) problems.push('quizzes must be exactly "on" or "off"');
  const status = lines.find((l) => /^status:/.test(l));
  if (status && !/^status:\s*(active|paused|done)\s*$/.test(status)) problems.push('status must be active, paused, or done');
  // "fast" is the old name for "dense"; accepted so an older plan still resumes.
  const pace = lines.find((l) => /^pace:/.test(l));
  if (pace && !/^pace:\s*(default|dense|slow|fast)\s*$/.test(pace)) problems.push('pace must be default, dense, or slow');
  const updated = lines.find((l) => /^updated:/.test(l));
  if (updated && !/^updated:\s*\d{4}-\d{2}-\d{2}\s*$/.test(updated)) problems.push('updated must be a YYYY-MM-DD date');

  const position = sectionBody(lines, 'Position');
  if (position && position.join('').trim() === '') problems.push('"# Position" is empty; it must say the unit, step, last confirmed idea, and next idea');
  const outline = sectionBody(lines, 'Outline');
  if (outline && !outline.some((l) => /\[( |~|x|s|\+)\]/.test(l))) problems.push('"# Outline" has no units with status markers like "[ ]" or "[~]"');

  for (const p of PLACEHOLDERS) {
    if (text.includes(p)) problems.push(`template placeholder "${p}" was left in the file`);
  }
  return problems;
}

module.exports = { lintPlan, REQUIRED_FIELDS, REQUIRED_HEADINGS };

if (require.main === module) {
  const file = process.argv[2];
  if (!file) {
    console.error('usage: node plan-lint.js <plan.md>');
    process.exit(2);
  }
  const problems = lintPlan(fs.readFileSync(file, 'utf8'));
  if (problems.length === 0) {
    console.log('OK ' + file);
    process.exit(0);
  }
  for (const p of problems) console.log('- ' + p);
  process.exit(1);
}
