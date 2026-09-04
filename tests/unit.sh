#!/usr/bin/env bash
# Deterministic checks that need no Claude session (seconds, not minutes):
#   - the Stop hook's decisions on synthetic inputs
#   - the plan linter and the tutor.js helpers on fixture plans
#   - the plan template embedded in SKILL.md matches references/plan-template.md
#   - SKILL.md frontmatter still carries the fields the skill depends on
# Run before tests/e2e.sh; run both before pushing.
set -uo pipefail

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
repo="$(dirname "$here")"
skill="$repo/skills/1-on-1-tutor-mode"
scripts="$skill/scripts"
tmp="${TMPDIR:-/tmp}/tutor-unit-$$"
mkdir -p "$tmp"
trap 'rm -rf "$tmp"' EXIT
pass=0; fail=0
ok()  { pass=$((pass + 1)); echo "  PASS  $1"; }
bad() { fail=$((fail + 1)); echo "  FAIL  $1"; }

# Node on Windows needs a Windows-style path inside the JSON the hook reads.
winpath() { if command -v cygpath >/dev/null 2>&1; then cygpath -m "$1"; else printf '%s' "$1"; fi; }

hook() { # hook <cwd> <message> -> exit code
  printf '{"cwd":"%s","last_assistant_message":%s}' "$(winpath "$1")" "$(node -e 'process.stdout.write(JSON.stringify(process.argv[1]))' "$2")" | node "$scripts/stop-check.js" 2>/dev/null
  echo $?
}
expect() { # expect <label> <actual> <wanted>
  if [ "$2" = "$3" ]; then ok "$1 (exit $2)"; else bad "$1 (exit $2, wanted $3)"; fi
}

echo "=== stop hook ==="
d="$tmp/hook"; mkdir -p "$d/tutor-sessions/demo"
sed -e 's/<kebab-case-slug>/demo/; s/<YYYY-MM-DD>/2026-09-03/g; s/<topic title>/Demo/; s/<Unit title>/Unit/g' "$skill/references/plan-template.md" > "$d/tutor-sessions/demo/plan.md"
expect "inactive session allows anything" "$(hook "$d" "no footer")" 0
echo demo > "$d/tutor-sessions/.active"
expect "missing footer blocks" "$(hook "$d" "A chunk. Make sense?")" 2
expect "good chunk allowed" "$(hook "$d" $'A chunk. Make sense?\n\nTutor Mode: ON · Unit 1/4 Convex sets · step 2')" 0
expect "italic footer allowed" "$(hook "$d" $'A chunk.\n\n_Tutor Mode: ON · planning_')" 0
long="$(node -e 'process.stdout.write(Array(320).fill("word").join(" "))')"
expect "320 prose words blocks" "$(hook "$d" "$long"$'\n\nTutor Mode: ON · planning')" 2
code="$(node -e 'process.stdout.write("```\n"+Array(10).fill("x = "+Array(40).fill("w").join(" ")).join("\n")+"\n```")')"
expect "code fence not counted" "$(hook "$d" $'Here is the function.\n'"$code"$'\nMake sense?\n\nTutor Mode: ON · Unit 2/5 Parser · step 1')" 0
sed -i 's/^status: active/- status: active/' "$d/tutor-sessions/demo/plan.md"
expect "drifted plan blocks" "$(hook "$d" $'A chunk.\n\nTutor Mode: ON · planning')" 2
rm "$d/tutor-sessions/demo/plan.md"
expect "missing plan blocks" "$(hook "$d" $'A chunk.\n\nTutor Mode: ON · planning')" 2
r="$(printf '{"cwd":"%s","stop_hook_active":true,"last_assistant_message":"no footer"}' "$(winpath "$d")" | node "$scripts/stop-check.js" 2>/dev/null; echo $?)"
expect "retry pass never blocks" "$r" 0
r="$(printf 'not json' | node "$scripts/stop-check.js" 2>/dev/null; echo $?)"
expect "garbage input allowed" "$r" 0

echo "=== plan linter and helpers ==="
d="$tmp/plans"; mkdir -p "$d/tutor-sessions/good" "$d/tutor-sessions/drift"
sed -e 's/<kebab-case-slug>/good/; s/<YYYY-MM-DD>/2026-09-03/g; s/<topic title>/Good/; s/<Unit title>/Unit/g' "$skill/references/plan-template.md" > "$d/tutor-sessions/good/plan.md"
cat > "$d/tutor-sessions/drift/plan.md" <<'EOF'
# Goal

- quizzes: on

# Outline

- 1. Something

# Learn Later

- A wrapped item that continues
  on a second line — why deferred: test — fits after: unit 2 — raised: 2026-09-03

# Position

Unit 1/1
EOF
if node "$scripts/plan-lint.js" "$d/tutor-sessions/good/plan.md" >/dev/null; then ok "filled template passes lint"; else bad "filled template fails lint"; fi
if node "$scripts/plan-lint.js" "$d/tutor-sessions/drift/plan.md" >/dev/null; then bad "drifted plan passes lint"; else ok "drifted plan fails lint"; fi
lint_out="$(node "$scripts/plan-lint.js" "$skill/references/plan-template.md" 2>/dev/null)"
if printf '%s' "$lint_out" | grep -q "placeholder"; then ok "linter flags leftover placeholders"; else bad "linter misses leftover placeholders"; fi
out="$(node "$scripts/tutor.js" learn-later --dir "$d")"
if printf '%s' "$out" | grep -q "drift	A wrapped item that continues on a second line"; then ok "learn-later joins wrapped bullets"; else bad "learn-later did not join wrapped bullets: $out"; fi
if printf '%s' "$out" | grep -q "^good	<topic>"; then bad "learn-later leaks the template placeholder bullet"; else ok "learn-later skips the template placeholder bullet"; fi
if node "$scripts/tutor.js" list --dir "$d" | grep -qE "^good	active	updated 2026-09-03"; then ok "list reads header fields"; else bad "list could not read header fields"; fi
if node "$scripts/tutor.js" check --dir "$d" >/dev/null; then bad "check passes with a drifted plan present"; else ok "check exits 1 on a drifted plan"; fi
echo good > "$d/tutor-sessions/.active"
if [ "$(node "$scripts/tutor.js" active --dir "$d")" = "good" ]; then ok "active reads the marker"; else bad "active did not read the marker"; fi

echo "=== SKILL.md consistency ==="
awk '/^## Plan template/{f=1} f&&/^```markdown$/{p=1;next} p&&/^```$/{exit} p' "$skill/SKILL.md" > "$tmp/embedded.md"
if diff -q "$tmp/embedded.md" "$skill/references/plan-template.md" >/dev/null; then ok "embedded plan template matches references/plan-template.md"; else bad "embedded plan template differs from references/plan-template.md:"; diff "$tmp/embedded.md" "$skill/references/plan-template.md" | head -n 10; fi
front="$(awk 'NR==1&&/^---$/{f=1;next} f&&/^---$/{exit} f' "$skill/SKILL.md")"
for key in "name: 1-on-1-tutor-mode" "disable-model-invocation: true" "allowed-tools:" "hooks:" "stop-check.js"; do
  if printf '%s\n' "$front" | grep -q -- "$key"; then ok "frontmatter has $key"; else bad "frontmatter lacks $key"; fi
done
if grep -qE '^\s*!`cat ' "$skill/SKILL.md"; then bad "SKILL.md injects a file with cat (injected commands abort the skill when permission is not pre-granted)"; else ok "no file-injecting commands in SKILL.md"; fi
lines="$(wc -l < "$skill/SKILL.md")"; bytes="$(wc -c < "$skill/SKILL.md")"
if [ "$bytes" -le 20000 ]; then ok "SKILL.md is $lines lines, $bytes bytes (compaction keeps the first ~5,000 tokens)"; else bad "SKILL.md is $bytes bytes; the contract may fall outside the 5,000-token compaction budget"; fi

echo ""
echo "=== result: $pass passed, $fail failed ==="
[ "$fail" -eq 0 ]
