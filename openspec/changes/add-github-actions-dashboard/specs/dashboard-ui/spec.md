## ADDED Requirements

### Requirement: Dashboard opens from a single command

`:AsciiUiActions` SHALL mount the dashboard in an ascii-ui floating window
with navigation keys (`<CR>` open, `h`/`<BS>` back, `r` refresh, `q` quit).

#### Scenario: Command mounts the dashboard

- **WHEN** the user runs `:AsciiUiActions`
- **THEN** a floating window renders the repository view (or repo picker if
  no repo is resolved)

### Requirement: Repository resolution

The dashboard SHALL resolve a target repository in this priority:
`setup({ repo = "owner/name" })` option, then `git remote get-url origin`
of the current buffer's project, then an interactive picker (search or
manual `owner/repo` entry).

#### Scenario: Configured repo wins

- **WHEN** the user has configured `repo = "foo/bar"`
- **THEN** the dashboard opens directly on `foo/bar`'s workflows without
  prompting

#### Scenario: Origin detection

- **WHEN** no repo option is set and the current project's origin is
  `git@github.com:foo/bar.git`
- **THEN** the dashboard resolves `foo/bar`

#### Scenario: Manual selection fallback

- **WHEN** detection fails
- **THEN** the user sees an input/search list to pick a repository

### Requirement: Workflow list view

The workflows view SHALL list each workflow's name, file path, and last-run
status, color-coded by conclusion, and selecting one opens its runs.

#### Scenario: Navigate to runs

- **WHEN** the user presses `<CR>` on a workflow entry
- **THEN** the runs view opens for that workflow

### Requirement: Run list view

The runs view SHALL list recent runs with status, conclusion, branch,
event, actor, and human-readable duration, color-coded
(passing/failure/running/pending/cancelled), and MUST cap rendering at 50
entries with an explicit "load more" row.

#### Scenario: Load more pagination

- **WHEN** the user selects "load more"
- **THEN** the next page is fetched and appended to the list

### Requirement: Run detail view

The run detail view SHALL show run metadata (workflow, branch, commit,
trigger, timing) and its jobs with per-job status/conclusion.

#### Scenario: Jobs rendered with status colors

- **WHEN** a run detail with two jobs (one success, one failure) is shown
- **THEN** both job lines are visible with their respective status colors

### Requirement: Explicit async UI states

Every view SHALL render distinct loading, empty, and error states; errors
MUST show the typed error message plus its hint, and the previously cached
payload MAY be shown with a "stale" marker when a refresh fails.

#### Scenario: Refresh failure keeps stale data

- **WHEN** a background refresh errors but a previous successful payload
  exists for the view
- **THEN** the data stays visible marked as stale with the error message

#### Scenario: gh missing surfaces guidance

- **WHEN** any fetch errors with `gh_missing`
- **THEN** the error view shows the install hint instead of a blank screen

### Requirement: Central dashboard state with race protection

The dashboard SHALL own its navigation and fetch state in a single reducer;
stale responses (from superseded navigations/refreshes) MUST be discarded
so the UI never shows data for a view the user left.

#### Scenario: Stale fetch ignored

- **WHEN** the user navigates workflows→runs before the workflows fetch
  completes, and the workflows response arrives second
- **THEN** the runs view stays intact and the workflows payload is dropped

### Requirement: Periodic refresh

The dashboard SHALL auto-refresh the current view on a configurable
interval (default 30 seconds; `0` disables it) without re-mounting the
window, and `r` SHALL refresh immediately.

#### Scenario: Disabled auto-refresh

- **WHEN** `refresh_interval = 0` is configured
- **THEN** no periodic fetches are issued
