#!/usr/bin/env node
// Stop hook for 1-on-1 tutor mode.
//
// Claude Code runs this when the assistant finishes a turn. It enforces the
// deterministic parts of the tutor contract while a session is active:
//   1. the reply ends with a "Tutor Mode: ON" footer line
//   2. the reply contains none of the block-tier filler patterns from
//      filler-lint.js (announcing sentences, empty clauses before a colon,
//      dash slogans, aphorisms, praise openers, dashes)
//   3. the active session's plan.md still has the template's shape
// There is no length check: a concept takes as many sentences as clarity
// needs. The hook is inert when no session is active (no tutor-sessions/.active
// in cwd), when the input lacks last_assistant_message, or on the retry pass
// (stop_hook_active), so it can never trap a session in a loop.
//
// Exit 2 + stderr = block and hand the reason to the model. Exit 0 = allow.

'use strict';
const fs = require('fs');
const path = require('path');
const { lintPlan } = require('./plan-lint.js');
const { lintText } = require('./filler-lint.js');

const FOOTER_RE = /^[\s*_`]*Tutor Mode: ON\b[^\n]*$/;
const MAX_SHOWN = 5;

function readStdin() {
  try {
    return fs.readFileSync(0, 'utf8');
  } catch (_) {
    return '';
  }
}

function debug(cwd, line) {
  if (!process.env.TUTOR_HOOK_DEBUG) return;
  try {
    fs.appendFileSync(path.join(cwd, 'tutor-sessions', '.hook.log'),
      `${new Date().toISOString()} ${line}\n`);
  } catch (_) { /* ignore */ }
}

function lastNonEmptyLine(text) {
  const lines = text.split(/\r?\n/);
  for (let i = lines.length - 1; i >= 0; i--) {
    if (lines[i].trim() !== '') return lines[i];
  }
  return '';
}

function withoutFooter(text) {
  return text.split(/\r?\n/).filter((l) => !FOOTER_RE.test(l)).join('\n');
}

function main() {
  let input = {};
  try {
    input = JSON.parse(readStdin() || '{}');
  } catch (_) {
    process.exit(0);
  }
  const cwd = input.cwd || process.cwd();
  const active = path.join(cwd, 'tutor-sessions', '.active');
  if (!fs.existsSync(active)) {
    debug(cwd, 'inactive: no .active marker');
    process.exit(0);
  }
  if (input.stop_hook_active) {
    debug(cwd, 'retry pass: allowing');
    process.exit(0);
  }
  const msg = typeof input.last_assistant_message === 'string'
    ? input.last_assistant_message
    : '';
  if (!msg.trim()) {
    debug(cwd, 'no last_assistant_message: allowing');
    process.exit(0);
  }

  const problems = [];
  const hasFooter = FOOTER_RE.test(lastNonEmptyLine(msg));
  if (!hasFooter) {
    problems.push(
      'missing footer: the last line of every tutor-mode reply must be ' +
      '`Tutor Mode: ON · Unit k/N <unit title> · step s` ' +
      '(or `Tutor Mode: ON · planning`). Append it now and stop.'
    );
  }
  let filler = [];
  try { filler = lintText(withoutFooter(msg), { tiers: ['block'] }); } catch (_) { /* ignore */ }
  if (filler.length > 0) {
    const shown = filler.slice(0, MAX_SHOWN)
      .map((h) => `"${h.match}" (${h.name}: ${h.fix})`).join('; ');
    const more = filler.length > MAX_SHOWN ? `; and ${filler.length - MAX_SHOWN} more` : '';
    problems.push(
      `filler: ${shown}${more}. Rewrite those sentences so each states a fact, ` +
      'an example, or the check, keep everything else, then stop.'
    );
  }
  let slug = '';
  try { slug = fs.readFileSync(active, 'utf8').trim(); } catch (_) { /* ignore */ }
  if (slug) {
    const planPath = path.join(cwd, 'tutor-sessions', slug, 'plan.md');
    if (!fs.existsSync(planPath)) {
      problems.push(
        `plan file missing: tutor-sessions/${slug}/plan.md does not exist but ` +
        'tutor-sessions/.active names that session. Write the plan from the ' +
        'template, then reply with only the footer line.'
      );
    } else {
      let planProblems = [];
      try { planProblems = lintPlan(fs.readFileSync(planPath, 'utf8')); } catch (_) { /* ignore */ }
      if (planProblems.length > 0) {
        problems.push(
          `plan file tutor-sessions/${slug}/plan.md drifted from the template: ` +
          planProblems.join('; ') + '. Fix the file (keep the header fields and ' +
          'the exact "# " headings from references/plan-template.md), then reply ' +
          'with only the footer line.'
        );
      }
    }
  }
  debug(cwd, `footer=${hasFooter} filler=${filler.length} problems=${problems.length}`);
  if (problems.length === 0) process.exit(0);
  process.stderr.write('Tutor Mode contract violation. ' + problems.join(' ') + '\n');
  process.exit(2);
}

main();
