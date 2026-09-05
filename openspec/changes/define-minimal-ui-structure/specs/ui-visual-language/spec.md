## ADDED Requirements

### Requirement: Fixed window region layout

Every dashboard view SHALL render exactly these top-to-bottom regions in
order: title, breadcrumb, content, status, hint. No view may add, nest, or
reorder regions, and no region other than content may contain list data.

#### Scenario: Region contract holds for all views

- **WHEN** any view (picker, workflows, runs, run detail) is rendered via
  `ascii-ui.testing`
- **THEN** line 1 is the title region, line 2 the breadcrumb, the last two
  lines are status and hint (with content between)

#### Scenario: Tiny window degradation

- **WHEN** the available height is below the minimum comfortable size
- **THEN** the breadcrumb is merged into the title line instead of
  truncating content

### Requirement: Single source of truth for visual tokens

All glyphs, semantic highlight groups, and spacing constants SHALL come
from `ui/tokens.lua`; view render code MUST NOT inline literal glyphs or
hex colors for entity state.

#### Scenario: Changing a token propagates everywhere

- **WHEN** a token glyph (e.g. success) is changed in `tokens.lua`
- **THEN** every view's rendered `toLines()` output changes identically,
  with no per-view edits

### Requirement: Three-tier hierarchy grammar for rows

Each list row SHALL present primary (entity name), secondary (context,
dimmed), and metadata (right-aligned) tiers in fixed column positions that
align vertically across all rows of the same view.

#### Scenario: Columns align within a view

- **WHEN** a workflows list of varying-length names is rendered
- **THEN** the primary column starts at the same character index on every
  row and metadata ends at the same right margin

### Requirement: Bounded semantic palette

State colors SHALL use only the specified highlight groups
(DiagnosticOk/Error/Info/Warn, Comment, NonText); at most three semantic
colors MUST be visible on one screen, and the design MUST NOT introduce
custom hex colors for entity state.

#### Scenario: Failure screen palette check

- **WHEN** a runs view containing success, failure, and running entries is
  rendered
- **THEN** messages from `screen:getByHighlight(...)` show only the
  sanctioned highlight groups

### Requirement: Noise budget

Views SHALL obey the noise budget: no decorative borders/boxes (except the
confirm row), no decoration that doesn't encode state, no duplicated data
across tiers, exactly one blank line max as section break, and one empty
state and one loading indicator style shared by all views.

#### Scenario: Loading and empty states are single lines

- **WHEN** a view is loading or has zero items
- **THEN** exactly one dimmed line appears in content and the status/hint
  regions still render

### Requirement: Full keyboard operability and discoverability

Every navigation and action MUST be reachable from the keyboard via the
documented map, rendered from one generated keymap table; a `?` overlay
(escaping with `<ESC>`/`q`) SHALL list the view's current bindings; the
hint bar MUST show the view's active keys in one line.

#### Scenario: Help overlay toggles without extra windows

- **WHEN** the user presses `?` and then `<ESC>`
- **THEN** content is replaced by the keymap listing and restored on
  `<ESC>`, and no additional float was opened

#### Scenario: Keymap completeness test

- **WHEN** the keymap unit spec runs
- **THEN** every action requirement in dashboard-ui and workflow-control
  has at least one key bound in every view where it applies

### Requirement: Inline confirmation for destructive or state-changing actions

Action keys (`R`, `F`, `c`, dispatch) SHALL replace the status region with
a two-line inline confirm (prompt + `[y]/[n]`), aborting on `n`/`<ESC>`,
and never use external `vim.fn.confirm`/input dialogs.

#### Scenario: Abort path performs no API call

- **WHEN** an action prompt is aborted
- **THEN** no client method has been invoked (assert via stub runner)

### Requirement: Structural snapshot coverage

The frame structure and each view's row layout SHALL be pinned by
`toLines()` snapshot tests so visual regressions fail CI.

#### Scenario: Frame snapshot drift caught

- **WHEN** a change adds a border row or shifts the hint region
- **THEN** the corresponding snapshot spec fails with a readable diff
