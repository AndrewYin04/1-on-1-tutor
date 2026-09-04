#!/usr/bin/env node
// Helpers over tutor-sessions/ in the current directory (or --dir <path>).
//
//   node tutor.js list          one line per session: slug, status, updated, position
//   node tutor.js learn-later   every "# Learn Later" bullet across sessions
//   node tutor.js active        the slug in tutor-sessions/.active, if any
//   node tutor.js check         lint every plan.md against the template; exit 1 on problems
//
// Plans are plain markdown with fixed headings (see references/plan-template.md),
// so this parser only needs to find a heading and read until the next "# ".

'use strict';
const fs = require('fs');
const path = require('path');
const { lintPlan } = require('./plan-lint.js');

function parseArgs(argv) {
  const out = { cmd: 'list', dir: process.cwd() };
  for (let i = 0; i < argv.length; i++) {
    if (argv[i] === '--dir') out.dir = path.resolve(argv[++i] || '.');
    else out.cmd = argv[i];
  }
  return out;
}

function sessionsRoot(dir) {
  return path.join(dir, 'tutor-sessions');
}

function readPlans(dir) {
  const root = sessionsRoot(dir);
  if (!fs.existsSync(root)) return [];
  return fs.readdirSync(root, { withFileTypes: true })
    .filter((d) => d.isDirectory())
    .map((d) => ({ slug: d.name, file: path.join(root, d.name, 'plan.md') }))
    .filter((p) => fs.existsSync(p.file))
    .map((p) => ({ ...p, text: fs.readFileSync(p.file, 'utf8') }));
}

function section(text, heading) {
  const lines = text.split(/\r?\n/);
  const start = lines.findIndex((l) => l.trim() === `# ${heading}`);
  if (start === -1) return [];
  const body = [];
  for (let i = start + 1; i < lines.length; i++) {
    if (/^# /.test(lines[i])) break;
    body.push(lines[i]);
  }
  return body;
}

// Header fields are "key: value" at line start per the template; a leading
// "- " is tolerated so a slightly drifted plan still lists sensibly.
function field(text, key) {
  const m = text.match(new RegExp(`^(?:- )?${key}:\\s*(.*)$`, 'm'));
  return m ? m[1].trim() : '';
}

// Bullets in a section, with wrapped continuation lines joined into one item.
function bullets(lines) {
  const items = [];
  for (const raw of lines) {
    if (/^\s*[-*] /.test(raw)) items.push(raw.replace(/^\s*[-*] /, '').trim());
    else if (/^\s+\S/.test(raw) && items.length > 0) items[items.length - 1] += ' ' + raw.trim();
  }
  return items;
}

function cmdList(dir) {
  const plans = readPlans(dir);
  if (plans.length === 0) {
    console.log('no sessions in ' + sessionsRoot(dir));
    return;
  }
  for (const p of plans) {
    const pos = section(p.text, 'Position').map((l) => l.trim()).filter(Boolean)[0] || '(no position)';
    console.log(`${p.slug}\t${field(p.text, 'status') || '?'}\tupdated ${field(p.text, 'updated') || '?'}\t${pos}`);
  }
}

function cmdLearnLater(dir) {
  const plans = readPlans(dir);
  let count = 0;
  for (const p of plans) {
    const items = bullets(section(p.text, 'Learn Later')).filter((i) => !/^<topic>/.test(i));
    for (const item of items) {
      console.log(`${p.slug}\t${item}`);
      count++;
    }
  }
  if (count === 0) console.log('(no Learn Later items)');
}

function cmdActive(dir) {
  const marker = path.join(sessionsRoot(dir), '.active');
  if (!fs.existsSync(marker)) {
    console.log('(no active session)');
    return;
  }
  console.log(fs.readFileSync(marker, 'utf8').trim());
}

function cmdCheck(dir) {
  const plans = readPlans(dir);
  if (plans.length === 0) {
    console.log('no sessions in ' + sessionsRoot(dir));
    return 0;
  }
  let bad = 0;
  for (const p of plans) {
    const problems = lintPlan(p.text);
    if (problems.length === 0) {
      console.log(`OK\t${p.slug}`);
    } else {
      bad++;
      console.log(`DRIFT\t${p.slug}`);
      for (const pr of problems) console.log(`\t- ${pr}`);
    }
  }
  return bad === 0 ? 0 : 1;
}

const { cmd, dir } = parseArgs(process.argv.slice(2));
if (cmd === 'list') cmdList(dir);
else if (cmd === 'learn-later') cmdLearnLater(dir);
else if (cmd === 'active') cmdActive(dir);
else if (cmd === 'check') process.exit(cmdCheck(dir));
else {
  console.error('usage: node tutor.js [list|learn-later|active|check] [--dir <path>]');
  process.exit(1);
}
