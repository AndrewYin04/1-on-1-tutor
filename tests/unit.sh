#!/usr/bin/env bash
# Deterministic checks that need no Claude session (seconds, not minutes):
#   - the Stop hook's decisions on synthetic inputs
#   - the filler linter on known-bad and known-clean sentences, and on the
#     skill's own reference prose
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
hook_stderr() { # hook_stderr <cwd> <message> -> the block reason
  printf '{"cwd":"%s","last_assistant_message":%s}' "$(winpath "$1")" "$(node -e 'process.stdout.write(JSON.stringify(process.argv[1]))' "$2")" | node "$scripts/stop-check.js" 2>&1 >/dev/null
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
long="$(node -e 'process.stdout.write(Array(60).fill("The segment between any two points of the set stays inside the set.").join(" "))')"
expect "a long clean reply is allowed (no length cap)" "$(hook "$d" "$long"$'\n\nMake sense?\n\nTutor Mode: ON · planning')" 0
expect "praise opener blocks" "$(hook "$d" $'Great question! The disk is convex. Make sense?\n\nTutor Mode: ON · planning')" 2
expect "announcing sentence blocks" "$(hook "$d" $'This is the subtle part, and it is where the slide slows down. The disk is convex.\n\nTutor Mode: ON · planning')" 2
expect "empty clause before a colon blocks" "$(hook "$d" $'The answer is genuinely strange the first time you hear it: the Fed creates the money.\n\nTutor Mode: ON · planning')" 2
expect "dash slogan blocks" "$(hook "$d" $'They buy bonds to hit the target — the bond operations are the tool, the rate is the dial.\n\nTutor Mode: ON · planning')" 2
expect "em-dash inside a sentence blocks" "$(hook "$d" $'A disk — the filled circle — is convex.\n\nTutor Mode: ON · planning')" 2
expect "dash after a bold list label is allowed" "$(hook "$d" $'Two sets:\n\n- **Disk** — every segment stays inside.\n- **Crescent** — the segment between the tips leaves it.\n\nMake sense?\n\nTutor Mode: ON · planning')" 0
expect "dash inside a code fence is allowed" "$(hook "$d" $'Run it like this.\n```\ngit log --oneline\n```\nMake sense?\n\nTutor Mode: ON · Unit 2/5 Parser · step 1')" 0
reason="$(hook_stderr "$d" $'Great question! The disk is convex.\n\nTutor Mode: ON · planning')"
if printf '%s' "$reason" | grep -q 'filler: "Great question" (praise-opener'; then ok "block reason quotes the flagged sentence and its pattern"; else bad "block reason unhelpful: $reason"; fi
sed -i 's/^status: active/- status: active/' "$d/tutor-sessions/demo/plan.md"
expect "drifted plan blocks" "$(hook "$d" $'A chunk.\n\nTutor Mode: ON · planning')" 2
rm "$d/tutor-sessions/demo/plan.md"
expect "missing plan blocks" "$(hook "$d" $'A chunk.\n\nTutor Mode: ON · planning')" 2
r="$(printf '{"cwd":"%s","stop_hook_active":true,"last_assistant_message":"no footer"}' "$(winpath "$d")" | node "$scripts/stop-check.js" 2>/dev/null; echo $?)"
expect "retry pass never blocks" "$r" 0
r="$(printf 'not json' | node "$scripts/stop-check.js" 2>/dev/null; echo $?)"
expect "garbage input allowed" "$r" 0

echo "=== filler linter ==="
bad_lines=(
  "This is the subtle part, and it's where the slide slows down."
  "Now the part you actually asked, which I've been asserting without proving: why does the quantity of money move the rate?"
  "It's not about the money; it's about the rate."
  "Let's unpack this."
  "Interestingly, the disk is convex."
  "The easy half was the proof -- the hard half was the intuition."
)
for s in "${bad_lines[@]}"; do
  if printf '%s\n' "$s" | node "$scripts/filler-lint.js" - >/dev/null; then bad "linter missed: $s"; else ok "linter flags: ${s:0:60}"; fi
done
clean_lines=(
  "The Fed sets the overnight rate directly, and banks lend to each other at that rate."
  "A square is convex: the segment between any two of its points stays inside it."
  "Slides 1-5 cover cones; slides 6-11 cover affine sets."
  "> This is the subtle part, quoted as an example inside a blockquote."
)
for s in "${clean_lines[@]}"; do
  if printf '%s\n' "$s" | node "$scripts/filler-lint.js" - >/dev/null; then ok "linter passes: ${s:0:60}"; else bad "linter false positive: $s"; fi
done
for f in references/examples.md references/writing.md references/planning.md references/visualization.md; do
  if node "$scripts/filler-lint.js" "$skill/$f" >/dev/null; then ok "$f has no block-tier filler"; else bad "$f contains block-tier filler:"; node "$scripts/filler-lint.js" "$skill/$f" | head -n 5; fi
done
if node "$scripts/filler-lint.js" "$repo/README.md" >/dev/null; then ok "README.md has no block-tier filler"; else bad "README.md contains block-tier filler:"; node "$scripts/filler-lint.js" "$repo/README.md" | head -n 5; fi

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
  on a second line, why deferred: test, fits after: unit 2, raised: 2026-09-03

# Position

Unit 1/1
EOF
if node "$scripts/plan-lint.js" "$d/tutor-sessions/good/plan.md" >/dev/null; then ok "filled template passes lint"; else bad "filled template fails lint"; fi
if node "$scripts/plan-lint.js" "$d/tutor-sessions/drift/plan.md" >/dev/null; then bad "drifted plan passes lint"; else ok "drifted plan fails lint"; fi
for p in default dense slow fast; do
  sed "s/^pace: .*/pace: $p/" "$d/tutor-sessions/good/plan.md" > "$tmp/pace.md"
  if node "$scripts/plan-lint.js" "$tmp/pace.md" >/dev/null; then ok "plan linter accepts pace: $p"; else bad "plan linter rejects pace: $p"; fi
done
sed 's/^pace: .*/pace: whenever/' "$d/tutor-sessions/good/plan.md" > "$tmp/pace.md"
if node "$scripts/plan-lint.js" "$tmp/pace.md" >/dev/null; then bad "plan linter accepts a bogus pace"; else ok "plan linter rejects a bogus pace value"; fi
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
if grep -qE '3-5 sentences|word cap|prose words' "$skill/SKILL.md" "$skill/references/"*.md "$repo/README.md"; then bad "a length rule survives in the skill or README"; else ok "no length rule in the skill or README"; fi
for f in "$skill/SKILL.md" "$skill/references/planning.md" "$repo/README.md"; do
  if grep -q "dense" "$f"; then ok "$(basename "$f") documents dense pace"; else bad "$(basename "$f") does not mention dense pace"; fi
done
# Compaction keeps the first 5,000 tokens of an invoked skill (about 19,500
# bytes of English markdown). Everything before the embedded plan template
# must fit in that window; the template is the tail that may be dropped.
bytes="$(wc -c < "$skill/SKILL.md")"
head_bytes="$(grep -b '^## Plan template' "$skill/SKILL.md" | head -n 1 | cut -d: -f1)"
if [ -n "$head_bytes" ] && [ "$head_bytes" -le 19500 ]; then ok "SKILL.md contract ends at byte $head_bytes of $bytes (inside the ~5,000-token compaction window)"; else bad "SKILL.md contract runs to byte ${head_bytes:-?} of $bytes; trim so the part before '## Plan template' is under 19,500 bytes"; fi
if [ "$bytes" -le 22500 ]; then ok "SKILL.md total is $bytes bytes"; else bad "SKILL.md total is $bytes bytes; over 22,500, move detail to references/"; fi

echo ""
echo "=== result: $pass passed, $fail failed ==="
[ "$fail" -eq 0 ]
