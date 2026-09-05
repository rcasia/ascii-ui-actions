## 1. Tokens and keymap foundations

- [ ] 1.1 Create `ui/tokens.lua`: glyph/highlight table per state
    (success/failure/running/queued/cancelled/neutral), spacing constants
    (left pad, column gap, blank-line rule), truncation marker
- [ ] 1.2 Create `ui/keymap.lua`: declarative `{key, desc, when}` entries
    covering every view; expose lookup by view kind; unit-test completeness
    (each action bound where applicable)
- [ ] 1.3 `make test` + `make validate` checkpoint for the two modules

## 2. Frame (region layout) renderer

- [ ] 2.1 Create `ui/render/frame.lua`: pure builders —
    `title(...)`, `breadcrumb(...)`, `status(...)`, `hint(view_kind)`, and
    `frame.compose({regions, content})` enforcing the fixed region order,
    blank-line rhythm, right margin, and tiny-window breadcrumb merge
- [ ] 2.2 Pure unit tests with `toLines`-style assertions on composed
    frames (loading one-liner, empty one-liner, error-with-hint wrapping)

## 3. Row hierarchy builder

- [ ] 3.1 Create `ui/render/row.lua`: three-tier row builder
    (glyph/primary/secondary/metadata) taking column widths computed in the
    logic layer; fixed alignment + `…` truncation
- [ ] 3.2 Unit tests: varying-length names keep identical column indexes

## 4. Help overlay

- [ ] 4.1 Create `ui/views/help.lua`: content-region keymap listing
    rendered from `ui/keymap.lua` for the current view (grouped: navigate /
    view / act), `<ESC>` restore handled in Dashboard reducer
- [ ] 4.2 Component test: `?` toggles listing in place, no extra float
    opened (assert via testing harness output)

## 5. Docs and contract

- [ ] 5.1 Add README section "UI structure": regions diagram, hierarchy
    grammar, palette table, full keymap table (generated to match
    `ui/keymap.lua`)
- [ ] 5.2 Record the structure as a note in
    `openspec/changes/add-github-actions-dashboard/tasks.md` header so its
    render/view tasks implement against `frame`/`row`/`tokens`

## 6. Verification

- [ ] 6.1 Add snapshot spec `tests/unit/frame_snapshot_spec.lua` pinning
    the region layout for a fake runs payload
- [ ] 6.2 `make test` and `make validate` green
- [ ] 6.3 Mount the frame demo via `require("ascii-ui").debug(...)` with
    stubbed data: verify renders, `?` overlay, `q` quits cleanly
