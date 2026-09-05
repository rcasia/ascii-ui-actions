## 1. Data layer — gh runner

- [ ] 1.1 Create `lua/ascii-ui-actions/github/runner.lua`: async `run(args, on_done)` via `vim.system` + `vim.schedule_wrap`, JSON decode, typed error mapping (`gh_missing`, `auth`, `api`, `network`, `parse`)
- [ ] 1.2 Unit-test runner error kinds with a stubbed system call seam (specs: structured error reporting)
- [ ] 1.3 Extend `config.lua`: `repo`, `refresh_interval` (default 30, 0 disables), keep `title`; merge in `setup()`

## 2. Data layer — GitHub client

- [ ] 2.1 Create `github/client.lua` accepting an injectable runner; implement read endpoints: list workflows, list runs (per repo/workflow, `page`/`per_page`), run jobs
- [ ] 2.2 Implement action endpoints: `dispatch_workflow`, `rerun_run`, `rerun_failed_jobs`, `cancel_run`
- [ ] 2.3 Unit-test client against a stub runner asserting exact argv and decoded fixtures (one fixture per endpoint)

## 3. Pure logic layer

- [ ] 3.1 Create `logic/repo_id.lua`: `git remote get-url origin` output → `owner/repo` (ssh/https, nested paths, `.git` suffix) + tests
- [ ] 3.2 Create `logic/nav.lua`: pure navigation reducer (open_repo/open_workflows/open_runs/open_run_detail/back/refresh + stale-`seq` drop rule) + tests
- [ ] 3.3 Create `logic/view_model.lua`: pure formatters — run status/conclusion → color+glyph, duration, relative time, action availability (`can_re_run`, `can_cancel`, conclusion gating), stale flag + tests

## 4. Pure render layer

- [ ] 4.1 Create `ui/render/common.lua`: shared rows (header, loading, empty, error-with-hint, status-line)
- [ ] 4.2 Create `ui/render/{workflows,runs,run_detail}.lua`: view model → `BufferLine[]`, including 50-row cap + "load more" row; snapshot-test with `toLines()`

## 5. Components and wiring

- [ ] 5.1 Replace demo `ui/app.lua` with `Dashboard`: single `useReducer` (view, status, data, error, pending_action, seq), route renderers per view kind
- [ ] 5.2 Wire fetch effects: dispatch `FETCH_START/FETCH_DONE(seq)` from client callbacks; navigation triggers fetches; ignore stale `seq`
- [ ] 5.3 Repo resolution flow on mount: option → origin detection → picker (`Input` + search via client); keymaps `<CR>`/`h`/`<BS>`/`r`/`q`
- [ ] 5.4 Update `init.lua` `open()` to mount `Dashboard` with resolved config; update `tests/unit/app_spec.lua` for the new root view

## 6. Workflow control actions

- [ ] 6.1 Workflows view: "run workflow" action with ref `Input` + confirm row (dispatch on confirm only)
- [ ] 6.2 Runs/run-detail views: `R` rerun, `F` rerun-failed (failed only), `c` cancel (queued/in_progress only) gated by availability from `view_model`, with confirm step
- [ ] 6.3 `pending_action` state: in-flight indicator, block double-trigger, status line on success/failure, refresh on completion

## 7. Refresh, health, docs

- [ ] 7.1 Auto-refresh via `useInterval(fetch_tick, refresh_interval)`; `0` disables; `r` forces immediate refresh
- [ ] 7.2 Cache-last-payload on refresh errors with stale marker in view models
- [ ] 7.3 Update `health.lua`: check `gh` executable + `gh auth status`
- [ ] 7.4 Update README (usage, views, keys, options) and `:checkhealth` note

## 8. Verification

- [ ] 8.1 `make test` green (unit tests for logic/client/render/components)
- [ ] 8.2 `make validate` (stylua) clean
- [ ] 8.3 Manual smoke via `require("ascii-ui").debug(...)` or real session: browse a real repo, view runs, run/cancel a dispatchable workflow; `q` closes cleanly
