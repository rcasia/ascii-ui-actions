## 1. Tokens and keymap foundations

- [x] 1.1 `ui/tokens.lua`: states palette (glyph + theme highlight group),
    `state_for(run)` mapping, raises on unknown state
- [x] 1.2 `ui/keymap.lua`: one declarative entries table; `hint()` renders the
    hint bar and the `?` overlay renders from the same list (spec: adding an
    entry flows into both — no drift)
- [x] 1.3 `make test` + `make validate` checkpoint green

## 2. Frame (region layout)

- [x] 2.1 Regions rendered in fixed order (title, breadcrumb, content, status,
    hint) by the reference component `ui/demo.lua`; error status rendered with
    `│ msg · hint` instead of silence
    (simplification: single demo component first; extract a `frame` builder
    when the dashboard adds its second view)
- [x] 2.2 Region order + visible-error assertions in `tests/unit/demo_spec.lua`

## 3. Row hierarchy

- [x] 3.1 Three-tier row in `ui/demo.lua` (`run_row`): glyph (tokens),
    primary padded to a column, branch, right-aligned duration
- [x] 3.2 Alignment test: branch column starts at the same cell on every row

## 4. Help overlay

- [x] 4.1 Overlay lists every binding from `keymap.entries` (help_row)
- [x] 4.2 Component test: `? keys` toggles the overlay in place (list hidden,
    no extra float in the testing harness) and `? close` restores the frame
    byte-for-byte

## 5. Docs and contract

- [x] 5.1 README "UI structure": regions diagram, tokens/keymap contract,
    demo as reference layout
- [x] 5.2 Contract note added at the top of
    `openspec/changes/add-github-actions-dashboard/tasks.md`

## 6. Verification

- [x] 6.1 Frame layout pinned by `tests/unit/demo_spec.lua` region-order +
    alignment tests (serves as the structure snapshot)
- [x] 6.2 `make test` (11/11) and `make validate` (stylua) green
- [x] 6.3 Demo mounted and inspected (StdoutViewport); live-reload documented:
    `require("ascii-ui").debug("lua/ascii-ui-actions/ui/demo.lua")`
