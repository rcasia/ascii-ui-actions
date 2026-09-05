## Context

The plugin currently ships a scaffold: `:AsciiUiActions` mounts a demo counter
component built with ascii-ui.nvim. The goal is a full GitHub Actions
dashboard: explore repos, browse workflows, inspect runs, and re-run/cancel
from the floating window.

Constraints:

- ascii-ui is line-oriented; components render `BufferLine[]`/`FiberNode[]`,
  hooks follow React rules (see project skill `ascii-ui-nvim`).
- Render bodies must be pure — all `vim.*`/`gh` I/O happens in effects or
  callbacks (`useEffect`, `on_press`).
- Test infra is `mini.test` + `ascii-ui.testing` (neotest-java-style
  bootstrap in `scripts/minimal_init.lua`); logic must be injectable to stay
  testable without a real GitHub session.

## Goals / Non-Goals

**Goals:**

- Dashboard views: repo selection → workflow list → run list → run detail.
- Actions: `workflow_dispatch` (run a workflow), rerun / rerun-failed-jobs,
  cancel a queued/in-progress run — all with confirmation.
- Async everything: UI stays responsive during API calls; loading, error,
  and empty states per view.
- Status feedback after actions (toast line + auto refresh).
- Works with whatever account `gh` is authenticated with.

**Non-Goals:**

- Streaming live logs inside Neovim (v1 links to `gh run view <id>` / web).
- PR checks, secrets, environments, artifacts management.
- Multi-account / org-switching UI (inherit `gh` defaults; `GH_TOKEN` honored
  by `gh` itself).
- Pagination beyond "load more" (no infinite scroll).

## Decisions

### D1 — Data access via `gh` CLI, not raw REST

All GitHub access goes through `gh api <endpoint>` spawned with `vim.system`.

- Why: `gh` owns authentication, keyring, `GH_HOST`, enterprise hosts, and
  JSON output (`--jq` avoided; we parse full JSON). No token handling in
  plugin code (PII/secret-safe).
- Alternative: `curl`/`vim.system` + `GH_TOKEN` env — rejected: duplicates
  auth logic, worse error messages, token leaks into our process env.
- Requirements mapping: `GET /repos/{o}/{r}/actions/workflows`,
  `.../workflows/{id}/runs`, `.../runs/{id}/jobs`,
  `POST .../workflows/{id}/dispatches`, `POST .../runs/{id}/rerun`,
  `POST .../runs/{id}/rerun-failed-jobs`, `POST .../runs/{id}/cancel`.

### D2 — Injectable command runner (DI seam)

`lua/ascii-ui-actions/github/runner.lua` exposes `run(args, on_done)`:

- Wraps `vim.system` with JSON decode + typed `Error {kind, message, hint}`
  (`kind = "gh_missing" | "auth" | "api" | "network" | "parse"`).
- `github/client.lua` receives the runner via constructor/optional arg,
  so unit tests stub the runner and assert exact argv + mapping — no Neovim,
  no network (same pattern as neotest-java's `command_executor`).
- Callbacks arrive already wrapped in `vim.schedule_wrap` so reducers can be
  dispatched safely from any completion.

### D3 — Layered components (ascii-ui pattern 8)

```
lua/ascii-ui-actions/
  github/    runner.lua, client.lua        -- data layer (only I/O)
  logic/     nav.lua, view_model.lua       -- pure: state+payload → view data
  ui/        render/*.lua                  -- pure: view data → BufferLine[]
             views/*.lua, app.lua          -- components: hooks + dispatch
```

Components stay thin; most tests hit pure layers, component behavior uses
`ascii-ui.testing`.

### D4 — Single `useReducer` for all dashboard state

The root `Dashboard` component owns one reducer:

```lua
{ view = {kind="repos"|"workflows"|"runs"|"run_detail", params},
  status = "idle"|"loading"|"ready"|"error",
  data, error, pending_action, seq }
```

- Why: coupled transitions (navigation + fetch status + results) across
  sibling views; one owner per value; avoids stale closures.
- Race protection: every fetch stamps an incrementing `seq`;
  `FETCH_DONE` actions carrying a stale `seq` are ignored by the reducer —
  fast navigation can't show wrong data.
- Alternative: per-view `useState` — rejected: shared fetch/navigation state
  would leak into every child (anti-pattern in the skill's rules).

### D5 — Navigation model, not window stack

`logic/nav.lua` is a pure reducer of `(state, action) → next state` for
`open_repo / open_workflows / open_runs / open_run_detail / back / refresh`.
`q` stays quit (ascii-ui default keymap). Back = `<BS>` or `h`. This keeps
routing testable without any UI.

### D6 — Repo discovery heuristic

On open: detect the repo for the current buffer with `git remote
get-url origin` + normalization (pure `logic/repo_id.lua`); on failure show
a `Select`/`Input` to pick the repo (search via `gh search repos`, or type
`owner/repo`). Default repo overridable via `setup({ repo = "o/r" })`.

### D7 — Auto-refresh + manual refresh

`useInterval(fetch_tick, refresh_interval)` at the Dashboard level, default
30s, `0` disables; `r` forces refresh of the current view. Timer cleanup is
automatic on unmount (ascii-ui rule).

### D8 — Actions guarded by confirmation

`R` = rerun run / `workflow_dispatch` (workflow view asks for `ref` via
`Input`), `F` = rerun failed jobs (only when run conclusion is failed),
`c` = cancel (only when run status is `queued|in_progress`). All show an
inline confirmation row before dispatch (`pending_action` in the reducer),
then a status line on completion + refresh. Capability specs encode these
availability rules as requirements.

## Risks / Trade-offs

- [`gh` not installed / not authenticated] → runner maps exit codes/stderr
  to `gh_missing`/`auth` errors with actionable hints (install URL,
  `gh auth login`); `:checkhealth ascii-ui-actions` pre-checks; UI shows an
  error view, never a silent failure.
- [API rate limits (60/h unauthenticated, worse with fine-grained token
  scopes)] → cache last successful payload per view key in the reducer,
  show cached data with "stale" marker on error; manual refresh only.
- [Fast navigation races → stale data] → `seq` stamping in D4.
- [`gh api` 404 on private repos lacking scopes] → surface
  `gh auth status` hint; distinguish 404-vs-permission in `logic`.
- [`workflow_dispatch` requires the workflow to support it] → treat GitHub's
  404/422 "not a workflow_dispatch event" as an explicit error message;
  availability of actions derived from run metadata (`can_re_run`,
  `can_cancel` fields returned by the API).
- [Large run/job lists] → cap rendering to 50 with an explicit
  "load more" entry (single extra `?page=` fetch).

## Migration Plan

- Demo `ui/app.lua` is replaced by the dashboard root; the command name and
  `setup()` signature stay. No persisted state, no rollback complexity
  beyond reverting the commit.

## Open Questions

- v1: `ref` selection for `workflow_dispatch` typed as free-form `Input` —
  could later become `gh api .../git/refs` backed `Select` (out of scope).
