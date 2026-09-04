# Visuals in tutor mode

A picture is worth using when the idea is about a relationship the eye reads
faster than a sentence does. Read this file the first time a chunk needs a
visual in a session, then follow the same rung for the rest of the session
unless it fails.

## When a picture earns its place

Use one when the chunk is about:

- a region or set in the plane (convex versus not, feasible regions, level sets,
  a supporting or separating hyperplane);
- the shape of a function and how a parameter changes it;
- a graph, tree, DAG, state machine, or dependency structure;
- a pipeline, data flow, or the sequence of one request through a codebase;
- a comparison of two quantities over a range (a chart);
- a geometric construction the student would otherwise have to imagine.

Do not use one for a definition, a historical fact, a name, or a formula that
reads fine as text. A visual that does not change what the student can see is
noise, and it costs a turn of their attention.

One visual per chunk at most. The chunk's sentences must still stand alone,
because the visual can fail to render on some surfaces.

## The ladder

Pick the highest rung whose tool you actually have. Check your tool list; do not
assume.

| Rung | Surface | How you know | What to do |
| --- | --- | --- | --- |
| 1 | Inline widget (Claude desktop app) | a `show_widget` tool exists | Call its `read_me` first with the module that fits (`interactive`, `diagram`, or `chart`), then render one widget. |
| 2 | Hosted page | an `Artifact` tool exists and no `show_widget` | Load the `artifact-design` skill first, as the tool requires, then publish one page and give the link. |
| 3 | Local HTML file | you have file writes and a shell, no rung 1 or 2 | Build `tutor-sessions/<slug>/viz/NN-<name>.html` from the templates in `assets/viz/`, open it with the OS opener, tell the student the path. |
| 4 | Mermaid | the surface renders fenced ` ```mermaid ` blocks | Draw graphs, sequences, and flows as Mermaid. Good for codebases. |
| 5 | Text | always | Unicode math (∇f, ℝⁿ, ≤, ∈, →), aligned ASCII layout, small tables. |

If a rung fails (the tool errors, the file cannot be opened), drop one rung in
the same reply and say so in a few words.

### Rung 1 notes (desktop app widget)

- The widget tool has its own design rules and a CDN allowlist; its `read_me`
  is the authority. Follow it, not this file, for widget styling.
- Keep prose out of the widget. The chunk's text goes in your reply; the widget
  holds only the picture and its controls.
- Prefer interaction that tests the idea: draggable points that turn a segment
  red when it leaves a set, a slider that moves a hyperplane until it separates,
  a step button that walks a derivation.
- The widget's `sendPrompt` function can put a question into the chat as if the
  student typed it. A single small button like "I don't see why the red part
  breaks convexity" is a good use. Do not add more than two such buttons.

### Rung 2 notes (Artifact)

- Follow the `artifact-design` skill and the tool's CDN allowlist (scripts only
  from cdnjs, jsdelivr npm, tailwind, jquery; stylesheets only from Google
  Fonts). Everything else must be inlined.
- Give the page a stable file path so later visuals in the same session can
  redeploy to the same link rather than creating many links.

### Rung 3 notes (local HTML file)

- Start from `assets/viz/page.html`. It is self-contained apart from CDN
  scripts, follows the system light or dark theme, and has a slot for a
  one-line caption and a slot for the figure. The three sibling files show the
  three most common figures wired up; copy the one that fits and edit.
- Name files `NN-<kebab-name>.html` with `NN` increasing within the session, so
  the folder reads like a figure list.
- Open it and tell the student where it is:
  - Windows (Git Bash): `start "" "tutor-sessions/<slug>/viz/01-convex-set.html"`
  - Windows (PowerShell): `Start-Process "tutor-sessions\<slug>\viz\01-convex-set.html"`
  - macOS: `open tutor-sessions/<slug>/viz/01-convex-set.html`
  - Linux: `xdg-open tutor-sessions/<slug>/viz/01-convex-set.html`
- If the shell command is not permitted in the current session, still write the
  file and give the path; the student can open it.
- A browser can load CDN scripts from any origin here, so any pinned library
  URL works. Pin versions so a template that rendered once keeps rendering.

## Library picks by kind of picture

| Kind of picture | Rung 1 or 2 | Rung 3 (local file) |
| --- | --- | --- |
| Region in the plane, draggable points, hyperplanes, convex hulls | hand-written SVG plus a few lines of JS | JSXGraph (`assets/viz/convex-set.html`) |
| Function of one variable with parameter sliders | inline SVG path recomputed on input, or Chart.js line | function-plot (`assets/viz/function-plot.html`) |
| Graph, tree, DAG, state machine, call graph | SVG boxes and arrows per the widget's diagram rules | Mermaid (`assets/viz/graph.html`) |
| Sequence of a request through code | SVG swimlanes | Mermaid `sequenceDiagram` |
| Bar or line chart of real numbers | Chart.js (allowed on both) | Chart.js |
| Matrix, heatmap, 3-D surface | Plotly from cdnjs | Plotly |
| Typeset math inside a figure | KaTeX from cdnjs, or Unicode | KaTeX (already wired in `page.html`) |
| Sets and Venn diagrams | hand SVG circles with labels | hand SVG in `page.html` |

If a better tool needs installing (a Python plotting stack for a static image
when no browser is available, a Node package for a layout engine), install it.
Tell the student in one sentence what you installed and why.

## Interaction patterns that teach

- **Break the definition**: let the student drag something until the property
  fails, and make the failure visible (the segment turns red, the constraint
  goes infeasible). One drag teaches more than a paragraph.
- **Parameter sweep**: one slider, one curve, one readout. Not three sliders.
- **Step through**: a next button that reveals one line of a derivation or one
  edge of a graph at a time, mirroring the chunk rule.
- **Two panels, same data**: the primal region beside the dual, the code beside
  the sequence diagram, when the point is the correspondence.

Keep controls to what the chunk needs. Every extra control is a thing the
student has to figure out instead of thinking about the idea.
