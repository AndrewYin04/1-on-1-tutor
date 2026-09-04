# 1-on-1 Tutor: repo constitution

Read `README.md` before working here and keep it current (it says so itself).

## Tech stack and system overview

- A Claude Code skill: markdown instructions plus small Node.js helpers. No
  build step, no dependencies to install.
- `skills/1-on-1-tutor-mode/` is the unit that gets linked into
  `~/.claude/skills/`; everything else in the repo supports it.
- The skill's behavior is enforced two ways: the written contract in
  `SKILL.md`, and a Stop hook (`scripts/stop-check.js`) declared in the skill
  frontmatter that blocks replies missing the footer, over 300 prose words, or
  leaving `plan.md` off the template shape (`scripts/plan-lint.js`) while
  `tutor-sessions/.active` exists in the working directory. Skill hooks live in
  the invoking process, so `claude -p --resume` turns run without the hook;
  the e2e test therefore checks the hook on the invoking turn only.

## Essential commands

```bash
./install.sh                 # or .\install.ps1 on Windows; --uninstall / -Uninstall to remove
node skills/1-on-1-tutor-mode/scripts/tutor.js list --dir <project>
node skills/1-on-1-tutor-mode/scripts/tutor.js check --dir <project>   # lint plans
tests/unit.sh                # seconds; hook, linter, helpers, template sync; no Claude
tests/e2e.sh                 # real claude -p sessions; needs the skill installed
tests/e2e.sh --scenario jackson --keep
```

## Invariants

1. `SKILL.md` stays front-loaded and under about 20 KB: Claude Code keeps
   only the first 5,000 tokens of an invoked skill after context compaction,
   and never re-reads the file mid-session, so the contract must be standing
   instructions near the top. The embedded plan template is last on purpose;
   it is the part compaction may drop once the plan file exists. Detail goes
   in `references/`. `tests/unit.sh` checks the size.
2. Plan headings and header fields are fixed and exact; `scripts/plan-lint.js`
   is the single definition of that shape, used by the hook, `tutor.js check`,
   and the tests. Change the template and the linter together.
3. The footer format is `Tutor Mode: ON · Unit k/N <title> · step s` (optionally
   `· quizzes off`) or `Tutor Mode: ON · planning`. The hook regex, the tests,
   and `examples.md` all encode it; change all of them together.
4. The Stop hook must be inert without `tutor-sessions/.active` and on the
   retry pass (`stop_hook_active`), so it can never trap a session.
5. Frontmatter uses only fields Claude Code documents, plus `triggers` and
   `metadata` for the agent memory standard. Verify any new field against the
   current docs before adding it.
6. The plan template is embedded in `SKILL.md` (so creating a session needs no
   file read outside the project) and must stay byte-identical to
   `references/plan-template.md`; `tests/unit.sh` diffs them. Never inject
   files into `SKILL.md` with `` !`cat ...` ``: an injected command that fails
   its permission check aborts the whole skill load.
7. The skill must work in the terminal and the desktop app; visuals degrade
   down the ladder in `references/visualization.md` rather than assuming a tool.

## Directory layout

```
skills/1-on-1-tutor-mode/   SKILL.md, references/, assets/viz/, scripts/, evals/
tests/                      unit.sh, e2e.sh, fixtures/
install.sh, install.ps1     link creation (symlink, or junction on Windows)
```
