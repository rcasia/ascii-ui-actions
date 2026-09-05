## Why

The GitHub Actions dashboard (`add-github-actions-dashboard`) is about to be
implemented. Without an explicit UI structure and visual language, its four
views will drift: inconsistent headers, ad-hoc colors, uneven spacing, and
noise from decorations. The stated requirement is a **minimalist, clear
hierarchy, consistent, keyboard-oriented interface with little visual
noise** — the structure must be described and agreed **before** it is
implemented. This change produces that contract: a documented UI structure
plus the small foundation code (tokens, keymap, regions) that later view
work must build on.

## What Changes

- Define (in design.md, normative for future work) the dashboard's UI
  structure: window regions, per-view information hierarchy, column
  alignment model, spacing rhythm, and density rules.
- Define the visual language: a small glyph vocabulary, one accent color,
  semantic highlight groups (theme-aware, not hex), and a "noise budget"
  (decoration must carry meaning).
- Define a complete keyboard map (navigation, context actions, help) —
  every action reachable without the mouse; add a `?` help overlay.
- Implement the foundation modules: `ui/tokens.lua` (single source of
  truth for glyphs/colors/spacing), `ui/keymap.lua`, and region/row builders
  (`ui/render/frame.lua`) used by all views.
- Retroactively constrain `add-github-actions-dashboard` view work to this
  structure (its render layer is specified against these tokens).

## Capabilities

### New Capabilities

- `ui-visual-language`: the minimal design system — region layout, view
  hierarchy, tokens (glyphs/colors/spacing), keyboard-first interaction
  model, help overlay, and noise/density rules every view must satisfy.

### Modified Capabilities

<!-- none — no archived specs exist yet -->

## Impact

- New `lua/ascii-ui-actions/ui/{tokens,keymap}.lua` and `ui/render/frame.lua`;
  `README.md` gains a documented structure + keymap section.
- Design contract for `add-github-actions-dashboard` (its `ui/render/*` and
  views implement this spec); recommended order: this change first.
- Tests: `toLines()` snapshot specs pin the frame structure; keymap table
  completeness assertions.
- No new runtime dependencies.
