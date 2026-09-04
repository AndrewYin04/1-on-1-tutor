# Planning a tutor session

The plan is the tutor's map. The conversation is a stream of small chunks that
scrolls away; the plan is the one thing that always says where the student is,
what they have confirmed, and what comes next. Read this file when starting a
session, when materials arrive, and whenever the plan needs restructuring.

## Two tiers, and why not one

The plan has a coarse tier and a fine tier.

- **Outline** (coarse, stable): the units in teaching order, each with a
  one-line "done when" test and its source. Five to ten units is typical.
- **Current Unit** (fine, disposable): only the unit in progress, expanded into
  steps, where each step is exactly one chunk's idea. Three to eight steps.

A fully detailed plan written up front goes stale the first time the student
reveals a gap or turns out to already know something, and then either the tutor
follows a wrong plan or spends a turn rewriting a long document. A broad-only
plan has the opposite problem: when the student says "yeah", the tutor has to
invent the next idea on the spot, and chunks stop building on each other. The
two-tier shape gives a stable spine plus a precise "next" that is cheap to
regenerate. Expand a unit into steps only when you enter it.

## Building the outline with materials

Read the materials before writing anything. Then:

1. **Lecture slides and lecture notes set the must-cover set and the default
   order.** Every lecture topic becomes a unit; none is dropped. Each lecture is
   usually one unit; split a lecture that would need more than ten steps, merge
   two thin ones. Keep the lecturer's order even if you would teach it
   differently, because the student's homework and exams follow it. The one
   reason to reorder is a deadline: when a homework due tomorrow needs units 3
   and 5 of a lecture, put those first, keep units 1, 2, and 4 after them in
   that order (the lecturer's, not a pedagogically nicer one) marked
   `(after deadline)`, and say so when presenting the outline. Lecture
   material never goes to `# Learn Later`; that list is for things outside the
   sources.
2. **Record ranges.** Every unit's source column names the deck and slide range
   (or page range), so the student can cross-check and so a later session can
   pick up the same place.
3. **Syllabus** gives the goal and the dates. Put exam and homework dates into
   `# Goal` as the deadline when the student has not stated one.
4. **Homework and problem sets** give the "done when" tests. If problem 3 needs
   the separating hyperplane theorem, the unit covering it is done when the
   student can state the theorem and apply it to a small case.
5. **Textbooks are supplementary.** Map chapters to the units they support in
   the `# Materials` table with coverage rule `supplementary`. Do not create
   units for textbook-only material unless a lecture depends on it or the
   student asks for it.
6. **Papers** (when the student is learning a research area): the paper's own
   structure is rarely the right teaching order. Extract the ideas the paper
   depends on, put those first, then the paper's contribution, then its
   evaluation and limitations.

If a file cannot be read (a scanned PDF, a binary), say so, plan that part from
expertise, and mark those units `(unverified against source)`.

## Building the outline without materials

The student may just ask about something: a research direction, a tool, a
theorem, a codebase. Still write a plan. Work backwards from the goal:

1. Name the goal precisely. "Understand diffusion policies for manipulation"
   becomes "be able to read a diffusion-policy paper and explain what the
   network predicts, how it is trained, and why it beats behavior cloning".
2. List what the goal depends on, then what those depend on, until you reach
   things the student already knows. That chain, reversed, is the outline.
3. Cut to depth. At `overview` depth keep definitions and intuition; at
   `standard` add one derivation or proof sketch and one worked example per key
   result; at `deep` keep full derivations, edge cases, and failure modes.
4. Mark prerequisite units you assumed with `(assumed prerequisite, verify)`
   and verify the first one with a probing question before teaching it, so you
   do not spend three chunks on something they already know.
5. Give every unit a source of `expertise` and a "done when" test anyway.

## Expanding a unit into steps

Each step is one idea that a 3-5 sentence chunk can carry. Good steps:

- one definition, or one property, or one example, or one contrast;
- one line of a derivation, when the derivation matters;
- one function or one file, when teaching code.

Bad steps: "explain convex sets" (a unit, not a step), or "definition and
examples and properties" (three steps). Write the quiz question for the unit's
end at expansion time, so the steps lead toward it.

## "Done when" tests

Make them observable. "Understands convexity" is not a test. These are:

- can state the definition and give one example and one non-example;
- can compute the gradient of a small quadratic by hand;
- can say which function in the codebase would change to add a new command;
- can explain in two sentences why the dual gives a lower bound.

The last step of a unit is the quiz built from its "done when" test.

## Revising the plan during the session

- **Gap found** (a chunk fails twice for lack of a foundation): insert a `[+]`
  unit immediately before the current one with the minimum needed, expand it,
  teach it, then return. Tell the student in one sentence what you inserted.
- **Already known** (the student answers a probe correctly): mark `[s]` and
  move on. Do not delete the unit; the marker records that it was checked.
- **Tangent worth keeping**: add to `# Learn Later` with why and where it fits.
- **Reorder**: allowed for units not yet started. Never reorder done units.
- **Depth or pace change**: update the header fields and re-expand the current
  unit at the new granularity.
- Every revision updates `updated:` and, if the position moved, `# Position`.

## Adding materials later

The student may start with nothing and add a paper or a textbook chapter
mid-session. When they do:

1. Read the new source fully.
2. For each of its sections, decide: it enriches an existing unit (add it to
   that unit's source column and to the `# Materials` table), or it needs a new
   unit (insert it where its prerequisites are satisfied, marked `[+]`), or it
   is out of scope for the goal (list it under `# Learn Later` with the source).
3. If the new source is lecture material, it becomes must-cover and may
   override the order of units not yet started.
4. Tell the student in two sentences what changed, then continue from the
   current step. Do not restart.

## Depth, pace, and quizzes fields

- `depth`: `overview`, `standard`, `deep`. Set at intake; the student can
  change it for a single unit ("go deep on this one").
- `pace`: `default`, `fast`, `slow`. `fast` means skip examples the student
  did not ask for and probe before teaching; `slow` means split steps further.
- `quizzes`: `on` or `off`. Off means checks are "make sense?" only. Still
  correct misconceptions and still write the "done when" tests.

## Slug and file rules

- Slug: kebab-case of the topic, ASCII only, at most 40 characters, no dates.
  "EE 381V lecture 3, convex sets" becomes `ee381v-convex-sets`.
- Path: `tutor-sessions/<slug>/plan.md` under the directory Claude was started
  in. Visuals go in `tutor-sessions/<slug>/viz/`.
- `tutor-sessions/.active` holds the active slug and nothing else. Create it at
  start and on resume; delete it on exit. The Stop hook uses it to know whether
  to enforce the contract.
- Headings are fixed and exact (`# Goal`, `# Outline`, `# Current Unit`,
  `# Position`, `# Learn Later`, `# Misconceptions Caught`, `# Session Log`),
  because `scripts/tutor.js` and the student's own tooling parse them.

## Worked outline: lecture-based

Goal: finish homework 2 of a convex optimization course by tomorrow with real
understanding; materials are lecture decks 2 and 3 and the homework PDF.

```
1. [x] Affine sets and hulls — done when: can write the affine hull of three points — source: deck 2, slides 3-9
2. [~] Convex sets and the segment test — done when: gives an example and a non-example with the witnessing points — source: deck 2, slides 10-18
3. [ ] Convex hulls and cones — done when: can draw the conic hull of two vectors — source: deck 2, slides 19-27
4. [ ] Operations preserving convexity — done when: can justify why an intersection of halfspaces is convex — source: deck 3, slides 1-12
5. [ ] Separating hyperplane theorem — done when: can apply it to HW2 problem 3 — source: deck 3, slides 13-22
```

Deck 3 slides 23-30 (dual cones) are lecture material not needed for homework
2, so they stay in the outline as unit 6 marked `(after deadline)`, and the
student hears that when the outline is presented. A tangent the student raised
about simplex pivoting, which is in neither deck, is what goes to
`# Learn Later`.

## Worked outline: no materials

Goal: understand diffusion policies for robot manipulation well enough to read
the papers; no deadline; student knows supervised learning and basic
probability but not diffusion models.

```
1. [ ] Behavior cloning and why it fails on multimodal demos — done when: can describe a task where averaging actions is wrong — source: expertise
2. [ ] Denoising diffusion in one dimension — done when: can state what the network predicts at each step — source: expertise (assumed prerequisite, verify)
3. [ ] Conditioning: observations to actions — done when: can name what is conditioned on and what is denoised — source: expertise
4. [ ] Action chunking and receding horizon — done when: can explain why predicting a sequence helps — source: expertise
5. [ ] Reading the paper's results and limitations — done when: can list two failure modes the authors report — source: to be added when the student supplies the paper
```

When the student later adds the paper, unit 5 gets its source and page ranges,
and any section the paper spends time on that the outline lacks becomes an
inserted unit.
