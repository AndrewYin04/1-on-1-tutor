#!/usr/bin/env bash
# End-to-end test for the 1-on-1 tutor skill.
#
# Drives the REAL entry point: `claude -p`, resumed turn by turn, from a scratch
# project outside this repo. The skill therefore has to resolve through
# ~/.claude/skills/1-on-1-tutor-mode (the junction or symlink install.sh made),
# the Stop hook has to fire from there on the invoking turn, and the plan file
# has to land in the scratch project's tutor-sessions/. Every turn's reply is
# saved as turn-N.md for inspection.
#
# Two things this harness does to stand in for an interactive user:
#   - Read is pre-allowed (the user would approve the prompt to read the skill's
#     reference files, which live outside the working directory).
#   - The Artifact tool is denied, because publishing needs an approval that a
#     print-mode run cannot give; this exercises visual rung 3 (local HTML).
# Skill-declared hooks live in the process that invoked the skill, and each
# resumed print-mode turn is a new process, so the hook is asserted on the
# invoking turn only. Every reply is run through the same filler linter the
# hook uses (block tier), so filler is caught on the resumed turns too. There
# is no length assertion: a concept takes the words clarity needs.
#
# Usage:  tests/e2e.sh [--scenario jackson|materials|dense|all] [--keep]
# Env:    E2E_WORKDIR  scratch directory (default: mktemp -d)
#         CLAUDE_BIN   claude binary (default: claude on PATH)
#         E2E_MODEL    optional --model override for the runs
#         E2E_TURN_TIMEOUT  seconds per turn before it is killed (default 420)
set -uo pipefail

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
repo="$(dirname "$here")"
scripts="$repo/skills/1-on-1-tutor-mode/scripts"
claude_bin="${CLAUDE_BIN:-claude}"
turn_timeout="${E2E_TURN_TIMEOUT:-420}"
scenario="all"
keep=0
while [ $# -gt 0 ]; do
  case "$1" in
    --scenario) scenario="$2"; shift ;;
    --keep) keep=1 ;;
    *) echo "unknown arg: $1" >&2; exit 2 ;;
  esac
  shift
done

work="${E2E_WORKDIR:-$(mktemp -d)}"
mkdir -p "$work"
export TUTOR_HOOK_DEBUG=1
pass=0; fail=0; turn=0; SID=""; RESULT=""
log() { printf '%s\n' "$*"; }
ok()  { pass=$((pass + 1)); log "  PASS  $1"; }
bad() { fail=$((fail + 1)); log "  FAIL  $1"; }

# ---- driving claude -------------------------------------------------------

json_field() { node -e 'try{const j=JSON.parse(require("fs").readFileSync(0,"utf8"));const v=j[process.argv[1]];process.stdout.write(v==null?"":String(v))}catch(e){}' "$1"; }

# run "<prompt>" [extra claude args...]  -> sets RESULT and SID, saves transcript
plan_mtime() { local f; f="$(ls tutor-sessions/*/plan.md 2>/dev/null | head -n 1)"; [ -n "$f" ] && stat -c %Y "$f" 2>/dev/null; }

run() {
  turn=$((turn + 1))
  PLAN_MTIME_BEFORE="$(plan_mtime)"
  local prompt="$1"; shift
  # The prompt goes first: --allowedTools is variadic and would swallow a
  # trailing positional argument as another tool name.
  local args=(-p "$prompt" --output-format json --permission-mode acceptEdits
              --allowedTools "Bash(ls *)" Read --disallowedTools Artifact)
  [ -n "${E2E_MODEL:-}" ] && args+=(--model "$E2E_MODEL")
  [ -n "$SID" ] && args+=(--resume "$SID")
  args+=("$@")
  log ""
  log "turn $turn > $prompt"
  local raw
  # MSYS_NO_PATHCONV keeps Git Bash from rewriting the leading "/" of the slash
  # command into a Windows path; it is scoped to this call so the harness's own
  # /c/... paths still convert for Node.
  raw="$(MSYS_NO_PATHCONV=1 timeout "$turn_timeout" "$claude_bin" "${args[@]}" 2>"$PWD/turn-$turn.stderr")" || true
  printf '%s' "$raw" > "$PWD/turn-$turn.json"
  SID="$(printf '%s' "$raw" | json_field session_id)"
  RESULT="$(printf '%s' "$raw" | json_field result)"
  printf '%s\n' "$RESULT" > "$PWD/turn-$turn.md"
  printf '%s\n' "$RESULT" | sed 's/^/    | /'
  [ -n "$SID" ] || bad "turn $turn produced no session_id (see turn-$turn.stderr)"
}

# ---- assertions -----------------------------------------------------------

last_line()  { printf '%s\n' "$1" | sed '/^[[:space:]]*$/d' | tail -n 1; }
has_footer() { last_line "$1" | grep -qE '^[[:space:]*_`]*Tutor Mode: ON'; }
filler_hits() { # block-tier filler patterns in the reply, footer excluded
  printf '%s\n' "$1" | sed '/^[[:space:]*_`]*Tutor Mode: ON/d' | node "$scripts/filler-lint.js" - 2>/dev/null | grep -v '^no filler found$' | sed -E 's/^stdin:[0-9]+: //; s/ -> .*//' | tr '\n' ';'
}
contains_i()   { printf '%s' "$1" | grep -qiE -- "$2"; }
plan_file()    { ls tutor-sessions/*/plan.md 2>/dev/null | head -n 1; }

assert_footer()     { if has_footer "$RESULT"; then ok "footer present ($(last_line "$RESULT"))"; else bad "footer missing; last line: $(last_line "$RESULT")"; fi; }
assert_no_footer()  { if has_footer "$RESULT"; then bad "footer present after exit"; else ok "no footer after exit"; fi; }
assert_clean()      { local h; h="$(filler_hits "$RESULT")"; if [ -z "$h" ]; then ok "no block-tier filler"; else bad "filler: $h"; fi; }
assert_contains()   { if contains_i "$RESULT" "$1"; then ok "reply mentions /$1/"; else bad "reply lacks /$1/"; fi; }
assert_lacks()      { if contains_i "$RESULT" "$1"; then bad "reply contains forbidden /$1/"; else ok "reply avoids /$1/"; fi; }
assert_file()       { if compgen -G "$1" > /dev/null; then ok "file exists: $1"; else bad "file missing: $1"; fi; }
assert_no_file()    { if compgen -G "$1" > /dev/null; then bad "file should not exist: $1"; else ok "file absent: $1"; fi; }
assert_plan_has()   { local f; f="$(plan_file)"; if [ -n "$f" ] && grep -qiE -- "$2" "$f"; then ok "plan has $1"; else bad "plan lacks $1 (/$2/)"; fi; }
assert_plan_touched() { # the contract says the plan is updated before the reply on these turns
  local now; now="$(plan_mtime)"
  if [ -n "$now" ] && [ "$now" != "${PLAN_MTIME_BEFORE:-}" ]; then ok "plan file updated on this turn ($1)"; else bad "plan file not updated on this turn ($1)"; fi
}
assert_plan_lint()  {
  local f out; f="$(plan_file)"
  if [ -z "$f" ]; then bad "plan lint: no plan file"; return; fi
  if out="$(node "$scripts/plan-lint.js" "$f" 2>&1)"; then ok "plan matches the template shape"; else bad "plan drifted from the template: $(printf '%s' "$out" | tr '\n' ' ')"; fi
}
assert_hook_ran()   {
  if [ -f tutor-sessions/.hook.log ] && grep -qE "inactive|footer=" tutor-sessions/.hook.log; then
    ok "Stop hook ran inside Claude Code on the invoking turn ($(wc -l < tutor-sessions/.hook.log) log lines)"
  else
    bad "Stop hook left no trace in tutor-sessions/.hook.log on the invoking turn"
  fi
}

# The template's own legend line ("Status markers: `[ ]` todo ... `[x]` done")
# contains every marker, so it is excluded from both counts.
no_legend()     { grep -v 'Status markers'; }
plan_x_count()  { local f; f="$(plan_file)"; if [ -n "$f" ]; then no_legend < "$f" | grep -c '\[x\]'; else echo 0; fi; }
outline_done()  { local f; f="$(plan_file)"; if [ -n "$f" ]; then section_lines "$f" Outline | no_legend | grep -c '\[x\]'; else echo 0; fi; }
words_of()      { printf '%s\n' "$1" | wc -w; }

section_lines() { # section_lines <plan> <heading>  -> prints the section body
  awk -v h="# $2" 'BEGIN{p=0} { if ($0==h) {p=1; next} if (p && $0 ~ /^# /) exit; if (p) print }' "$1"
}
first_match_line() { printf '%s\n' "$1" | grep -niE -- "$2" | head -n 1 | cut -d: -f1; }

# ---- scenario 1: no materials, misconception, rabbit hole, toggles, exit ---

scenario_jackson() {
  log "=== scenario: jackson (no materials) ==="
  local dir="$work/jackson"; rm -rf "$dir"; mkdir -p "$dir/tutor-sessions"; cd "$dir"; SID=""
  run "/1-on-1-tutor-mode Michael Jackson"
  assert_footer; assert_clean; assert_hook_ran

  run "Goal: a solid overview of his life and why he mattered culturally. No deadline. I know basically nothing about him. Standard depth. Plan it and show me the outline."
  assert_footer; assert_clean
  assert_file "tutor-sessions/*/plan.md"; assert_file "tutor-sessions/.active"
  for h in "Goal" "Student Profile" "Materials" "Outline" "Current Unit" "Position" "Learn Later" "Misconceptions Caught" "Session Log"; do
    assert_plan_has "heading '# $h'" "^# $h\$"
  done
  assert_plan_lint

  run "looks good, go"
  assert_footer; assert_clean; assert_contains "Unit 1/"
  local chunk1="$RESULT"

  run "yeah"
  assert_footer; assert_clean; assert_plan_touched "step marked done"
  if [ "$RESULT" != "$chunk1" ]; then ok "second chunk differs from first"; else bad "second chunk repeats the first"; fi

  run "got it. so when jackson won his rings with the bulls, was that before or after thriller?"
  assert_footer; assert_clean; assert_contains "Jordan"
  assert_lacks "great (question|observation|connection|point)"
  assert_lacks "you're (absolutely )?right"
  assert_plan_touched "misconception logged"
  if [ -n "$(plan_file)" ] && section_lines "$(plan_file)" "Misconceptions Caught" | grep -qi "Jordan"; then ok "plan logs the misconception under '# Misconceptions Caught'"; else bad "plan's '# Misconceptions Caught' section lacks the Jordan entry"; fi

  run "ok makes sense. unrelated but how do vinyl records physically store sound? i want to go deep on that"
  assert_footer; assert_clean; assert_contains "learn later"
  assert_contains "goal|mattered|overview|won't help|will not help"   # reminds them what they came for
  assert_contains "Unit 1/"                                          # still on the Jackson unit, not teaching vinyl

  run "leave it for later, keep going"
  assert_footer; assert_clean
  assert_plan_has "a vinyl item under Learn Later" "vinyl"
  if node "$scripts/tutor.js" learn-later | grep -qi vinyl; then ok "tutor.js learn-later extracts the item"; else bad "tutor.js learn-later did not find the item"; fi

  run "skip quizzes"
  assert_footer; assert_clean; assert_contains "quizzes off"; assert_plan_has "quizzes: off" "^quizzes: *off"

  run "where are we"
  assert_footer; assert_clean

  run "exit tutor mode"
  assert_no_footer; assert_no_file "tutor-sessions/.active"
  assert_plan_has "a Session Log entry" "^- 20[0-9]{2}-[0-9]{2}-[0-9]{2}"
  assert_contains "resume"
  assert_plan_lint
  if node "$scripts/tutor.js" list | grep -qE "^[a-z0-9-]+\s+(active|paused|done)\s+updated 20[0-9]{2}"; then ok "tutor.js list shows status and date"; else bad "tutor.js list could not read status/date: $(node "$scripts/tutor.js" list | head -n 1)"; fi
}

# ---- scenario 2: lecture materials, deadline ordering, visual rung 3 --------

scenario_materials() {
  log "=== scenario: materials (lecture order, homework goal, visual) ==="
  local dir="$work/materials-case"; rm -rf "$dir"; mkdir -p "$dir/materials" "$dir/tutor-sessions"; cd "$dir"; SID=""
  cp "$here/fixtures/lecture-02-convex-sets.md" "$here/fixtures/hw2.md" materials/

  run "/1-on-1-tutor-mode materials/ I need to finish HW2 (materials/hw2.md) by tomorrow with real understanding. I know basic linear algebra. Standard depth. Plan it and show me the outline."
  assert_footer; assert_clean; assert_hook_ran
  assert_file "tutor-sessions/*/plan.md"
  assert_plan_has "the lecture file in Materials" "lecture-02-convex-sets"
  assert_plan_has "the homework file in Materials" "hw2"
  assert_plan_lint
  local plan; plan="$(plan_file)"
  local outline later
  outline="$(section_lines "$plan" Outline)"
  later="$(section_lines "$plan" "Learn Later")"
  local l_cone l_aff l_conv l_sep
  l_cone="$(first_match_line "$outline" 'cone')"
  l_aff="$(first_match_line "$outline" 'affine')"
  l_conv="$(first_match_line "$outline" 'convex set|segment test')"
  l_sep="$(first_match_line "$outline" 'separat')"
  if [ -n "$l_cone" ] && [ -n "$l_aff" ] && [ -n "$l_conv" ] && [ -n "$l_sep" ]; then
    ok "all four lecture topics are outline units (cones $l_cone, affine $l_aff, convex sets $l_conv, separating $l_sep)"
  else
    bad "a lecture topic is missing from the outline (cones=$l_cone affine=$l_aff convex=$l_conv separating=$l_sep)"
  fi
  if [ -n "$l_cone" ] && [ -n "$l_aff" ] && [ "$l_cone" -lt "$l_aff" ]; then ok "cones precede affine sets (lecture order kept within the non-homework group)"; else bad "cones/affine order broken (cones=$l_cone affine=$l_aff)"; fi
  if [ -n "$l_conv" ] && [ -n "$l_sep" ] && [ "$l_conv" -lt "$l_sep" ]; then ok "convex sets precede separating hyperplanes"; else bad "convex/separating order broken (convex=$l_conv separating=$l_sep)"; fi
  if printf '%s\n' "$later" | grep -qiE 'cone|affine'; then bad "lecture material was moved to Learn Later"; else ok "no lecture material under Learn Later"; fi
  assert_plan_has "the deadline recorded" "tomorrow|due"

  run "go"
  assert_footer; assert_clean

  run "can you show me a picture of a convex set next to a non-convex one?"
  assert_footer; assert_clean
  assert_file "tutor-sessions/*/viz/*.html"
  assert_contains "\\.html"

  run "exit tutor mode"
  assert_no_footer; assert_no_file "tutor-sessions/.active"
  assert_plan_lint
}

# ---- scenario 3: dense pace ------------------------------------------------
#
# The student asks for speed. Dense replies must cover several steps at once
# and still carry the footer, the plan update, and no filler. Then the student
# asks to go back, and the pace field must return to default.

scenario_dense() {
  log "=== scenario: dense (pace switch, several concepts per reply) ==="
  local dir="$work/dense"; rm -rf "$dir"; mkdir -p "$dir/tutor-sessions"; cd "$dir"; SID=""
  run "/1-on-1-tutor-mode Michael Jackson. Goal: an overview of his life and why he mattered culturally. No deadline. I know basically nothing. Standard depth. Plan it and show me the outline."
  assert_footer; assert_clean
  assert_plan_has "pace: default" "^pace: *default"

  run "looks good, go"
  assert_footer; assert_clean
  local chunked_words chunked_x outline_before
  chunked_words="$(words_of "$RESULT")"; chunked_x="$(plan_x_count)"; outline_before="$(outline_done)"
  log "chunked reply: $chunked_words words, $chunked_x done markers in the plan"

  run "this is too slow, just explain it, cover more at once"
  assert_footer; assert_clean
  assert_plan_has "pace: dense" "^pace: *dense"
  assert_plan_touched "steps closed by the dense reply"
  local dense_words dense_x
  dense_words="$(words_of "$RESULT")"; dense_x="$(plan_x_count)"
  log "dense reply: $dense_words words, $dense_x done markers in the plan"
  if [ "$dense_words" -gt "$chunked_words" ]; then ok "dense reply covers more than the chunked one ($dense_words vs $chunked_words words)"; else bad "dense reply is not longer than the chunked one ($dense_words vs $chunked_words words)"; fi
  # Either several steps closed inside the unit, or a whole unit finished.
  if [ $((dense_x - chunked_x)) -ge 2 ] || [ "$(outline_done)" -gt "$outline_before" ]; then
    ok "dense reply closed several steps at once ($chunked_x -> $dense_x done markers)"
  else
    bad "dense reply closed too little ($chunked_x -> $dense_x done markers, outline units done $outline_before -> $(outline_done))"
  fi
  assert_plan_lint

  run "one at a time"
  assert_footer; assert_clean
  assert_plan_has "pace back to default" "^pace: *default"
  assert_plan_lint
}

# ---- main -----------------------------------------------------------------

log "workdir: $work"
log "claude:  $("$claude_bin" --version 2>/dev/null || echo unknown)"
case "$scenario" in
  jackson) scenario_jackson ;;
  materials) scenario_materials ;;
  dense) scenario_dense ;;
  all) scenario_jackson; scenario_materials; scenario_dense ;;
  *) echo "unknown scenario: $scenario" >&2; exit 2 ;;
esac
log ""
log "=== result: $pass passed, $fail failed ==="
log "transcripts: $work/*/turn-*.md"
if [ "$keep" -eq 0 ] && [ "$fail" -eq 0 ] && [ -z "${E2E_WORKDIR:-}" ]; then rm -rf "$work"; fi
[ "$fail" -eq 0 ]
