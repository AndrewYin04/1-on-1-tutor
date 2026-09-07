# 1-on-1 Tutor

A Claude Code skill that turns Claude into a one-on-one tutor: it teaches one
concept per reply, written plainly for a smart high schooler with the
foundation that concept needs and not one filler sentence, stops after each
reply so you can confirm or ask, keeps a living lesson plan in a file,
corrects you bluntly when you have something wrong, and ends every reply with
a `Tutor Mode: ON` progress footer so you always know where you are without
scrolling.

Works for course material (lecture slides, syllabi, homework), research topics
with no materials at all, papers you add mid-way, and codebases.

## Install

Clone anywhere, then link the skill into your personal Claude Code skills
directory. The link means `git pull` updates the skill in place.

Windows (PowerShell or Git Bash):

```powershell
git clone https://github.com/AndrewYin04/1-on-1-tutor.git
cd 1-on-1-tutor
.\install.ps1
```

macOS or Linux:

```bash
git clone https://github.com/AndrewYin04/1-on-1-tutor.git
cd 1-on-1-tutor
./install.sh
```

The installer creates `~/.claude/skills/1-on-1-tutor-mode` pointing at
`skills/1-on-1-tutor-mode` in the clone. On Windows it tries a real symlink
(needs Developer Mode or an elevated shell) and otherwise creates a directory
junction, which needs neither; Claude Code follows both. Uninstall with
`./install.sh --uninstall` or `.\install.ps1 -Uninstall`; only the link is
removed.

Requirements: Claude Code (tested on 2.1.237; skill-frontmatter hooks and the
`${CLAUDE_PROJECT_DIR}` substitution the hook uses need a 2026 release), Node.js
on PATH (for the Stop hook and the helper script), and on Windows, Git Bash.

## Use

Start Claude Code in the folder where you want the lesson plan to live (next to
your course materials is a good place), then:

```
/1-on-1-tutor-mode convex optimization, lecture 2
/1-on-1-tutor-mode ./slides/           (reads the folder first)
/1-on-1-tutor-mode diffusion policies for robot manipulation
/1-on-1-tutor-mode this codebase, starting from the CLI entry point
/1-on-1-tutor-mode resume ee381v-convex-sets
/1-on-1-tutor-mode off
```

The mode only starts when you invoke it. Claude never switches into it on its
own.

Scripting it with `claude -p "/1-on-1-tutor-mode ..."` from Git Bash on Windows
needs `MSYS_NO_PATHCONV=1` in front, or Git Bash rewrites the leading slash
into a Windows path before Claude sees the command. Typing the command inside
an interactive Claude Code session needs nothing special.

The skill's guides live in the skill directory, outside your project, so Claude
may ask permission the first time it reads one of them in a session (the plan
template itself is embedded in the skill, so no read is needed for it). To
never see that prompt, add this rule to `permissions.allow` in
`~/.claude/settings.json`:

```json
"Read(~/.claude/skills/1-on-1-tutor-mode/**)"
```

What happens:

1. Intake: at most three questions (goal, deadline, what you know, depth).
2. Planning: Claude reads any materials, writes
   `tutor-sessions/<slug>/plan.md`, and shows you the outline to confirm.
3. Teaching: one concept per reply, as long as clarity needs and no longer,
   ending with "make sense?" or a micro-question. You say "yeah", ask a
   follow-up, or push back; the next chunk builds on what you confirmed. Say
   "faster" or "just explain it" and it switches to dense replies instead.

Things you can say at any point:

| You say | Claude does |
| --- | --- |
| "yeah", "ok", "next" | marks the step done, delivers the next chunk |
| "I don't get it" | re-explains from a different angle, never the same words |
| "I already know this" | asks one probing question, skips the unit if you pass |
| "faster", "go dense", "just explain it" | switches to dense replies, several concepts at once |
| "one at a time", "slower" | back to one concept per reply, then to smaller steps |
| "skip quizzes" / "quizzes on" | toggles the end-of-concept micro-questions |
| "where are we" | three lines: goal, position, what comes next |
| "show me the plan" | the outline with status markers |
| "add materials <path>" | reads them and merges them into the plan |
| "learn later: X" | parks X under `# Learn Later` |
| "exit tutor mode" | saves position, tells you how to resume |

## How it works

- **The contract.** Every reply teaches one new concept together with the
  foundation it rests on, ends with a check, and ends with the footer
  `Tutor Mode: ON · Unit k/N <title> · step s`. There is no sentence or word
  limit; a concept gets the length clarity needs. What is limited is filler:
  no sentence that only announces the next one ("this is the subtle part"),
  no empty clause before a colon, no slogan after a dash, no praise opener, no
  em-dashes inside a sentence. Dense pace lifts the one-concept limit and
  changes nothing else. The rules and rewrites of real replies are in
  `skills/1-on-1-tutor-mode/references/writing.md`.
- **The plan file.** `tutor-sessions/<slug>/plan.md` has fixed headings: goal,
  student profile, materials, outline (coarse units with "done when" tests),
  current unit (only that unit expanded into steps), position, Learn Later,
  misconceptions caught, session log. It is the source of truth; the chat is
  disposable. That is what keeps the conversation from turning into an ocean of
  text you have to search: nothing important lives only in the scrollback.
- **Pace.** `pace:` in the plan is `default` (one concept per reply), `dense`,
  or `slow`. In dense mode Claude answers your question directly first, then
  teaches several steps at a time as continuous prose, up to one unit per
  reply, with one check at the end instead of one per idea. Corrections, the
  Learn Later offer, the plan updates, the footer, and the no-filler rules all
  still apply, so speed costs you the per-idea stop and nothing else. Say
  "one at a time" to go back.
- **Two-tier plan.** A stable coarse outline plus a detailed expansion of only
  the current unit. A fully detailed plan goes stale as soon as a gap appears;
  a broad-only plan loses the thread of what to build on next.
- **Materials.** Lecture slides set the must-cover set and the default order;
  homework sets the "done when" tests; textbooks and papers are supplementary.
  With a deadline, the units it depends on move to the front and the rest of
  the lecture follows marked "(after deadline)" instead of being dropped.
  Sources added later are merged into existing units or inserted as new ones.
- **Correction.** If you ask about Michael Jackson's basketball career, Claude
  says you have confused him with Michael Jordan, not "great connection".
- **Prioritization.** With a goal and deadline recorded, tangents get a
  load-bearing check; unrelated ones get a reminder of the goal and an offer to
  park them under `# Learn Later`. You decide.
- **Stop hook.** A hook declared in the skill runs `scripts/stop-check.js`
  after every reply while a session is active and blocks a reply that lacks the
  footer, contains a filler pattern from `scripts/filler-lint.js` (the same
  linter the [no-filler](https://github.com/AndrewYin04/no-filler) skill
  ships), or left the plan file in a shape the tools cannot parse
  (`scripts/plan-lint.js`), handing Claude the reason so it fixes it. It is
  inert when no session is active. The hook lives in the Claude Code
  process that invoked the skill, so it covers a whole interactive session;
  a scripted `claude -p --resume` turn is a new process and runs without it.
- **Visuals.** When a picture helps (a set in the plane, a function's shape, a
  graph, a request's path through code), Claude uses the best rung available:
  inline widgets in the desktop app, a hosted Artifact, a local HTML file opened
  in your browser (templates in `assets/viz/`), Mermaid, or Unicode and ASCII.

## Repository layout

```
1-on-1-tutor/
├── skills/1-on-1-tutor-mode/     the skill (this is what gets linked)
│   ├── SKILL.md                  the contract and procedures
│   ├── references/               plan template, planning guide, visuals guide, examples
│   ├── assets/viz/               HTML figure templates (JSXGraph, function-plot, Mermaid)
│   ├── scripts/                  stop-check.js (Stop hook), plan-lint.js, filler-lint.js, tutor.js (list, learn-later, active, check)
│   └── evals/evals.json          test prompts and assertions in skill-creator format
├── tests/e2e.sh                  drives the real `claude -p` entry point end to end
├── tests/fixtures/               a small fake lecture and homework
├── install.sh / install.ps1      link the skill into ~/.claude/skills
└── CLAUDE.md                     repo constitution for agents working on this repo
```

## Helpers

From any folder with a `tutor-sessions/` directory:

```bash
node ~/.claude/skills/1-on-1-tutor-mode/scripts/tutor.js list
node ~/.claude/skills/1-on-1-tutor-mode/scripts/tutor.js learn-later
node ~/.claude/skills/1-on-1-tutor-mode/scripts/tutor.js active
node ~/.claude/skills/1-on-1-tutor-mode/scripts/tutor.js check
```

`learn-later` prints every parked topic across sessions, one per line, so you
can plan a follow-up session from it. `check` lints each plan against the
template shape. The filler linter the hook uses also runs on any file:

```bash
node ~/.claude/skills/1-on-1-tutor-mode/scripts/filler-lint.js --all notes.md
```

## Test

Fast deterministic checks (hook decisions, filler linter, plan linter,
helpers, template sync) need only Node:

```bash
tests/unit.sh
```

The end-to-end test runs real `claude -p` sessions from a scratch folder, so
the skill must be installed first. It takes ten to twenty minutes and uses your
Claude account.

```bash
tests/e2e.sh                       # both scenarios
tests/e2e.sh --scenario jackson    # no materials, misconception, rabbit hole, toggles, exit
tests/e2e.sh --scenario materials  # lecture order, homework goal, visual file
```

Each turn's reply is saved as `turn-N.md` in the scratch folder for reading.

## Update

```bash
git pull
```

Nothing else: the link points at the clone. Claude Code picks up skill changes
within a running session.

## Maintaining this README

This file is the user-facing description of the skill. Whenever the skill's
behavior, commands, install steps, file layout, or test procedure changes,
update the matching section here in the same change, without being asked.
