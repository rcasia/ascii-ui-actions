> NOTE: implement all views against the UI-structure contract from
> `define-minimal-ui-structure`: regions/rows per `lua/ascii-ui-actions/ui/demo.lua`,
> glyphs+highlights only via `ui/tokens.lua`, keys only via `ui/keymap.lua`
> (hint bar and `?` overlay render from it). Repeated rows follow the
> ascii-ui skill rule: module-level item component + `ui.map`.

## 1. Data layer — gh runner

- [x] 1.1 Create `lua/ascii-ui-actions/github/runner.lua`: async `run(args, on_done)` via `vim.system` + `vim.schedule_wrap`, JSON decode, typed error mapping (`gh_missing`, `auth`, `api`, `network`, `parse`)
- [x] 1.2 Unit-test runner error kinds with a stubbed system call seam (specs: structured error reporting)
- [x] 1.3 Extend `config.lua`: `repo`, `refresh_interval` (default 30, 0 disables), keep `title`; merge in `setup()`

## 2. Data layer — GitHub client

- [x] 2.1 Create `github/client.lua` accepting an injectable runner; implement read endpoints: list workflows, list runs (per repo/workflow, `page`/`per_page`), run jobs
- [x] 2.2 Implement action endpoints: `dispatch_workflow`, `rerun_run`, `rerun_failed_jobs`, `cancel_run`
- [x] 2.3 Unit-test client against a stub runner asserting exact argv and decoded fixtures (one fixture per endpoint)

## 3. Pure logic layer

- [x] 3.1 Create `logic/repo_id.lua`: `git remote get-url origin` output → `owner/repo` (ssh/https, nested paths, `.git` suffix) + tests
- [x] 3.2 Create `logic/nav.lua`: pure navigation reducer (open_repo/open_workflows/open_runs/open_run_detail/back/refresh + stale-`seq` drop rule) + tests
- [x] 3.3 Create `logic/view_model.lua`: pure formatters — run status/conclusion → color+glyph, duration, relative time, action availability (`can_re_run`, `can_cancel`, conclusion gating), stale flag + tests

## 4. Render layer and views

- [x] 4.1 Create/trim `ui/render/common.lua`: shared one-off row builders (header, loading, empty, error-with-hint, status-line, hint bar, confirm, load-more)
- [x] 4.2 Create `ui/views/{workflows,runs,run_detail,repo_picker,help_overlay}.lua` + `ui/components/{confirm_bar,dispatch_form}.lua`: repeated rows as module-level components (`WorkflowRow`, `RunRow`, `JobRow`, `MetaRow`, `SearchResultRow`, `HelpEntryRow`), list components map them with `ui.map`, including 50-row cap + "load more" row; snapshot-test with `toLines()`

## 5. Components and wiring

- [x] 5.1 Replace demo `ui/app.lua` with `Dashboard`: single `useState` driven by the pure `nav.reduce` via a functional setter (avoids ascii-ui's stale-closure `useReducer`), route renderers per view kind
- [x] 5.2 Wire fetch effects: dispatch `FETCH_START/FETCH_OK/FETCH_ERR(seq)` from client callbacks; navigation triggers fetches; ignore stale `seq`
- [x] 5.3 Repo resolution flow on mount: option → origin detection → picker (`Input` + search via client); buffer-local keymaps `<CR>`/`h`/`<BS>`/`r`/`R`/`F`/`c`/`y`/`n`/`?`/`q`
- [x] 5.4 Update `init.lua` `open()` to mount `Dashboard` with resolved config; rewrite `tests/unit/app_spec.lua` for the new root view

## 6. Workflow control actions

- [x] 6.1 Workflows view: "run workflow" action with ref `Input` + confirm row (dispatch on confirm only)
- [x] 6.2 Runs/run-detail views: `R` rerun, `F` rerun-failed (failed only), `c` cancel (queued/in_progress only) gated by availability from `view_model`, with confirm step
- [x] 6.3 `pending_action` state: in-flight indicator, block double-trigger, status line on success/failure, refresh on completion

## 7. Refresh, health, docs

- [x] 7.1 Auto-refresh via `useInterval(fetch_tick, refresh_interval)`; `0` disables; `r` forces immediate refresh
- [x] 7.2 Cache-last-payload on refresh errors with stale marker in view models
- [x] 7.3 Update `health.lua`: check `gh` executable + `gh auth status`
- [x] 7.4 Update README (usage, views, keys, options) and `:checkhealth` note

## 8. Verification

- [x] 8.1 `make test` green (unit tests for logic/client/render/views/components/app)
- [x] 8.2 `make validate` (stylua) clean
- [ ] 8.3 Manual smoke via `require("ascii-ui").debug(...)` or real session: browse a real repo, view runs, run/cancel a dispatchable workflow; `q` closes cleanly
