## Context

Four views are coming (repo picker, workflows, runs, run detail) from
`add-github-actions-dashboard`. The requirement: minimalist, clear visual
hierarchy, consistent, keyboard-oriented, low visual noise. This design
defines the structure those views must implement — before any of them is
built. Constraints from the ascii-ui skill: theme-aware `highlight` groups
preferred over hex for semantic colors; pure render layer (`value →
BufferLine[]`); floating-window keymap model (`h/j/k/l`, `<CR>`, `q`).

## Goals / Non-Goals

**Goals:**

- One window layout contract (regions, fixed order, spacing rhythm).
- Per-view hierarchy: primary → secondary → metadata, identical grammar in
  every view.
- A tiny token vocabulary (glyphs, colors, spacing) in one module.
- 100% keyboard operability + discoverability (`?` overlay).
- A testable noise budget.

**Non-Goals:**

- Themes/skins system, user-configurable colors (v1 uses highlight groups).
- Mouse ergonomics (works, but never required).
- Icons beyond the fixed ASCII-safe glyph set.

## The Structure (normative)

### Window regions

Every view occupies a single floating window (~70×18 default). Regions
appear in this fixed order; each is one line and none are nested:

```
┌──────────────────────────────────────────────────────────┐
│ 1 title      ascii-ui-actions                        ●1r  │  DimFloat / Normal
│ 2 breadcrumb foo/bar › ci.yml                       <BS>  │  Comment
│ ── content ─────────────────────────────────────────────── │  (no border line;
│ 3 <view body: one header row + list rows>                 │   blank-line rhythm)
│ 4 status     fetched 12:04:31 · error text (red)          │  StatusLine-ish
│ 5 hint       j/k move  <CR> open  r refresh  ? keys       │  Comment, one line
└──────────────────────────────────────────────────────────┘
```

- **1 title**: product name + global indicator (auto-refresh dot `●1r`,
  stale `!`); constant text except indicators.
- **2 breadcrumb**: repo › workflow › run — grows with depth; `h`/`<BS>`
  steps back one element.
- **3 content**: exactly one entity list or one detail sheet. Header row
  (column names, dimmed) + data rows. No grouping boxes, no separators.
- **4 status**: last refresh time; errors replace it with `kind + message +
  hint`, wrapped with `│ ` prefix.
- **5 hint**: context keymap bar (see Keys); never more than one line.

### Hierarchy grammar (content rows)

Every list row follows the same three-tier contract:

```
<glyph> <primary>                    <secondary>        <metadata →right-aligned>
  ✓     build                        main               pushed  2m14s  12:04
```

- **primary** (Normal, always present): the entity name (workflow, run
  title, job name). One column position per view — rows align vertically;
  columns are fixed-width per view (computed once per payload, not per
  row).
- **secondary** (Comment): branch/event/driver — context, dimmed.
- **metadata** (NonText, right-aligned): duration, timestamp, counts.
- **glyph** (semantic highlight, 1 char): status; see tokens.

Detail views use `label: value` lines in the same order
identity → state → timeline → jobs.

### Run status glyph/color set (the entire palette)

| state         | glyph | highlight       |
|---------------|-------|-----------------|
| success       | `✓`   | DiagnosticOk    |
| failure       | `✗`   | DiagnosticError |
| running       | `●`   | DiagnosticInfo  |
| queued/pending| `○`   | DiagnosticWarn  (dim) |
| cancelled     | `⊘`   | Comment         |
| neutral       | ` `   | — (no glyph)    |

One accent only: focus is the window's own cursor/highlight; no extra
colors are permitted per screen (≤ 3 semantic colors visible at once).

### Spacing rhythm

- Left pad 1 col; columns separated by ≥ 2 spaces; never trailing spaces.
- Section break = exactly 1 blank line (max); no 2+ consecutive blanks.
- Text truncates to fit with `…`; no wrapping mid-row except status errors.

### Keys (complete map; discoverable via `?`)

| key        | repos/picker     | workflows      | runs            | run detail      |
|------------|------------------|----------------|-----------------|-----------------|
| `j/k` `↑/↓`| move             | move           | move            | move (jobs)     |
| `<CR>`     | select repo      | open runs      | open detail     | —               |
| `l`        | —                | open runs      | open detail     | —               |
| `h`/`<BS>` | quit             | back           | back            | back            |
| `r`        | refresh          | refresh        | refresh         | refresh         |
| `R`        | —                | dispatch…      | rerun…          | rerun…          |
| `F`        | —                | —              | rerun failed…   | rerun failed…   |
| `c`        | —                | —              | cancel…         | cancel…         |
| `o`        | —                | open in browser| open in browser | open in browser |
| `?` / `<ESC>` | help toggle / dismiss | same  | same            | same            |
| `q`        | quit             | quit           | quit            | quit            |

Destructive/action keys always open an inline confirm row (content region,
2 lines: prompt + `[y]/[n]`); `<ESC>`/`n` aborts. Actions unavailable for
the focused entity silently show reason in status line (no disabled menu
noise).

### Noise budget (hard rules)

1. No borders/boxes except ascii-ui focus rendering and the confirm row.
2. Decoration characters must encode state (`●1r`, `!` stale) — otherwise
   they don't ship.
3. No duplicated data (branch appears once per run row, not in glyph +
   secondary + metadata).
4. Empty state = one dimmed line under the breadcrumb; loading = `…` after
   breadcrumb; both never both.
5. Header rows never repeat per group; one per content region.

## Decisions

### D1 — Highlight groups, not hex

All semantic colors use Neovim diagnostic/float groups (see table).
Alternative (fixed hex, truecolor brand look) rejected: clashes with user
themes, violates skill rule 7 (theme-aware first).

### D2 — Fixed column model computed per payload

Column widths derive from data once (pure `logic` layer), passed to the
render layer as strings. Alternative (per-row formatting) rejected: ragged
alignment, and render bodies must stay pure anyway.

### D3 — `ui/tokens.lua` as single source of truth

Glyph table, highlight mapping, spacing constants, region builders
(`frame.rows(...)`). Views compose, never inline a literal `"✓"`. Spec
scenarios pin this: changing a glyph changes every view identically.

### D4 — One keymap table, generated hints

`ui/keymap.lua` declares `{key, desc, when(view_kind)}`; the hint bar (row
5) and the `?` overlay render from the same table — keymap and docs can't
drift. Unit test asserts every action spec has an entry per view.

### D5 — Help as a content-region swap, not a second window

`?` replaces content with the grouped keymap (dim columns, view-scoped);
`<ESC>` restores. Avoids stacking floats and window-management state.

### D6 — Density: data-first lists, 50-row cap kept from dashboard design

Row height 1 everywhere; no padding rows between list items; scannability
comes from alignment, not air. Alternative (generous spacing + separators)
rejected: more scrolling, more lines of noise for the same information.

## Risks / Trade-offs

- [Minimal UI can under-signpost actions] → hint bar + `?` overlay +
  status-line reason messages compensate; discoverability is a spec
  requirement, not optional.
- [Highlight-group colors vary across themes] → acceptable (consistency is
  semantic); `q`-tested glyph shapes still disambiguate in grayscale.
- [One accent/3-color cap may feel austere] → intentional; noise budget is
  the requirement's core.
- [Region line budget eats content on tiny windows] → min 14 rows; when
  shorter, hide breadcrumb (title shows `o/r › …` merged).

## Open Questions

- None blocking. (`o` browser-open adds one key; could fold into `<CR>`
  later if users never ask — decide after first dogfood.)
