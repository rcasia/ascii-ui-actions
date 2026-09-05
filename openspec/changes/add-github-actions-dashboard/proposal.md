## Why

Developers currently have to leave Neovim (browser or `gh` CLI) to inspect GitHub Actions activity for their repos. This plugin's purpose is an ascii-ui.nvim dashboard that brings CI visibility — and basic control — into the editor, turning `ascii-ui-actions` from a scaffold into a real tool.

## What Changes

- Add a GitHub Actions dashboard opened with `:AsciiUiActions` (replaces the demo counter app).
- New data layer that talks to the GitHub API through the `gh` CLI (auth handled by `gh`), executed asynchronously via `vim.system`.
- Browse and select a repository (current-buffer repo via `gh repo view`, plus manual search/entry).
- List workflows for the selected repo (name, last run status, path).
- List recent runs for the selected workflow (or all workflows), with status, branch, event, actor, duration, and color-coded state.
- Inspect a run: jobs with per-job status and log links.
- Re-run a workflow (`workflow_dispatch`) or re-run a previous run (`rerun`, including `rerun_failed_jobs` when available).
- Cancel an in-progress run (`q`/button with confirmation), only when the run is cancellable.
- Loading, error, and empty states for every view; errors from the API surfaced explicitly.

## Capabilities

### New Capabilities

- `github-client`: authenticated, async access to the GitHub Actions REST endpoints (repos, workflows, runs, jobs, rerun/cancel/dispatch) via the `gh` CLI, with parsed typed results and explicit error propagation.
- `dashboard-ui`: the ascii-ui floating-window experience — view routing (repo → workflows → runs → run detail), async data-driven re-renders, loading/error/empty states, keyboard navigation.
- `workflow-control`: user-initiated actions on CI — trigger/re-run a workflow, re-run a failed run, cancel an in-progress run — with confirmation and status feedback.

### Modified Capabilities

<!-- none — no existing specs -->

## Impact

- `lua/ascii-ui-actions/`: new `github/` (client + endpoints) and `ui/` (views/components) modules; `init.lua`/`config.lua` grow options (default repo, refresh interval).
- Runtime dependency on `gh` being installed and authenticated (detected via `:checkhealth` and a first-run check; graceful message otherwise).
- Dev/testing: pure logic layers testable with `mini.test`; `ascii-ui.testing` for components; `gh` behind an injectable runner seam.
- Existing demo App component is replaced (no public API yet, so non-breaking).
