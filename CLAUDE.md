# 1-on-1 Tutor: repo constitution

Read `README.md` before working here and keep it current (it says so itself).

## Tech stack and system overview

- A Claude Code skill: markdown instructions plus small Node.js helpers. No
  build step, no dependencies to install.
- `skills/1-on-1-tutor-mode/` is the unit that gets linked into
  `~/.claude/skills/`; everything else in the repo supports it.
- The skill's behavior is enforced two ways: the written contract in
  `SKILL.md`, and a Stop hook (`scripts/stop-check.js`) declared in the skill
  frontmatter that blocks replies missing the footer, containing a block-tier
  filler pattern (`scripts/filler-lint.js`), or leaving `plan.md` off the
  template shape (`scripts/plan-lint.js`) while `tutor-sessions/.active`
  exists in the working directory. There is no length rule anywhere: a reply
  is as long as its one concept needs. Skill hooks live in the invoking
  process, so `claude -p --resume` turns run without the hook; the e2e test
  checks the hook on the invoking turn only and lints every reply itself.
- `scripts/filler-lint.js` is a verbatim copy of the same file in the
  `no-filler` repo (https://github.com/AndrewYin04/no-filler), which is the
  canonical one. Change it there and copy it here; `tests/unit.sh` exercises
  the copy.

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

1. `SKILL.md` stays front-loaded: Claude Code keeps only the first 5,000
   tokens of an invoked skill after context compaction and never re-reads the
   file mid-session, so the contract must be standing instructions near the
   top. Everything before `## Plan template` must fit in that window (under
   about 19.5 KB); the embedded template is last on purpose, the part
   compaction may drop once the plan file exists. Detail goes in
   `references/`. `tests/unit.sh` checks both the boundary and the total.
2. Plan headings and header fields are fixed and exact; `scripts/plan-lint.js`
   is the single definition of that shape, used by the hook, `tutor.js check`,
   and the tests. Change the template and the linter together. The linter
   validates the values of `status`, `quizzes`, `updated`, and `pace`
   (`default`, `dense`, `slow`, plus `fast` as the old name for `dense`), so a
   new field value needs a linter case and a `tests/unit.sh` case in the same
   change.
3. The footer format is `Tutor Mode: ON · Unit k/N <title> · step s` (optionally
   `· quizzes off`) or `Tutor Mode: ON · planning`. The hook regex, the tests,
   and `examples.md` all encode it; change all of them together.
4. The Stop hook must be inert without `tutor-sessions/.active` and on the
   retry pass (`stop_hook_active`), so it can never trap a session.
5. Frontmatter uses only fields the Claude Code docs define; `tests/unit.sh`
   checks every key against that list. An unknown key is ignored with no
   error, so a skill written with one looks configured and is not. `triggers:`
   was carried here until 2026-09-07 for exactly that reason and did nothing.
   Verify any new field against the current docs before adding it.
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
