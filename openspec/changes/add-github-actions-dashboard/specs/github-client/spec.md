## ADDED Requirements

### Requirement: Async GitHub API access through gh CLI

The system SHALL perform all GitHub Actions API access by invoking `gh api`
asynchronously (never blocking the Neovim event loop) and decoding the JSON
response into typed Lua tables.

#### Scenario: Successful workflow list request

- **WHEN** the client requests the workflows of repo `o/r`
- **THEN** it spawns `gh` with argv containing `api` and
  `/repos/o/r/actions/workflows`
- **AND** delivers the decoded response to the completion callback exactly once

#### Scenario: Request does not block the editor

- **WHEN** an API request is in flight
- **THEN** the Neovim UI remains responsive (callback-based completion, no
  `vim.wait` on the main thread)

#### Scenario: Completion is scheduled onto the main thread

- **WHEN** a request completes from the system callback
- **THEN** the client invokes the consumer callback via `vim.schedule`

### Requirement: Structured error reporting

The client SHALL report every failure as a typed error
`{ kind, message, hint }` with `kind` in
`gh_missing | auth | api | network | parse`, and MUST NOT surface failures
as silent `nil` returns or bare `pcall` swallowing.

#### Scenario: gh binary not installed

- **WHEN** `gh` cannot be executed (not on PATH)
- **THEN** the callback receives an error with `kind = "gh_missing"` and a
  hint pointing to the gh installation instructions

#### Scenario: Authentication failure

- **WHEN** `gh` exits indicating not logged in (exit code with `gh auth
  login` in stderr)
- **THEN** the callback receives an error with `kind = "auth"` and hint
  `gh auth login`

#### Scenario: API error response

- **WHEN** the endpoint returns a non-2xx status with a GitHub error message
- **THEN** the callback receives `kind = "api"` including the GitHub
  `message` field verbatim

#### Scenario: Invalid JSON payload

- **WHEN** stdout is not valid JSON
- **THEN** the callback receives `kind = "parse"` with the raw head of the
  payload in the message

### Requirement: Repository, workflow, run, and job read endpoints

The client SHALL expose methods for: current-repo detection inputs
(`git remote get-url origin`), searching repos, listing workflows, listing
runs (per repo and per workflow, with pagination), and listing jobs of a run.

#### Scenario: Paginated runs fetch

- **WHEN** the caller requests runs for a workflow with `page = 2`
- **THEN** the request argv includes `per_page` and `page=2`
- **AND** the decoded result contains the runs array and pagination metadata

### Requirement: Run and workflow action endpoints

The client SHALL expose `dispatch_workflow(repo, workflow_id, ref)`,
`rerun_run(repo, run_id)`, `rerun_failed_jobs(repo, run_id)`, and
`cancel_run(repo, run_id)`, returning success/failure through the same
typed-error contract.

#### Scenario: Workflow dispatch payload

- **WHEN** `dispatch_workflow("o/r", "build.yml", "main")` is called
- **THEN** argv contains `--method POST`, the dispatches endpoint, and a
  body with `ref = "main"`

### Requirement: Injectable command runner

All `gh`/`git` execution SHALL go through an injectable runner object so
tests can substitute a stub without spawning processes.

#### Scenario: Stubbed runner in tests

- **WHEN** a client is constructed with a stub runner returning a fixture
- **THEN** endpoint methods return the fixture data and the test asserts the
  exact argv passed to the stub
