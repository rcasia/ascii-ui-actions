## ADDED Requirements

### Requirement: Trigger or re-run a workflow via dispatch

The dashboard SHALL offer "run workflow" on the workflows view, prompt for
a `ref` (defaulting to the repo's default/last-used branch), require
explicit confirmation, and call the workflow dispatch endpoint.

#### Scenario: Dispatch with confirmation

- **WHEN** the user selects "run workflow", types ref `main`, and confirms
- **THEN** the client calls dispatch for that workflow with `ref = "main"`
- **AND** on success a status line confirms and the runs view refreshes

#### Scenario: Dispatch rejected by GitHub

- **WHEN** the workflow does not accept `workflow_dispatch` (API error)
- **THEN** the dashboard shows the API error message and keeps the view

#### Scenario: Cancel confirmation

- **WHEN** the user opens the dispatch prompt but dismisses it without
  confirming
- **THEN** no API call is made

### Requirement: Re-run a previous run

The dashboard SHALL allow re-running a previous run (full rerun, or failed
jobs only when the run conclusion is failed); actions MUST be gated on the
run's `can_re_run`/`can_re_run_failed` flags and require confirmation.

#### Scenario: Rerun successful

- **WHEN** the user presses `R` on a completed run with `can_re_run = true`
  and confirms
- **THEN** rerun is called for that run and the view shows the action result
  before refreshing

#### Scenario: Action unavailable hidden

- **WHEN** a run has `can_re_run = false`
- **THEN** the rerun action is not offered for that run

### Requirement: Cancel an in-progress run

The dashboard SHALL offer cancel only while a run's status is
`queued` or `in_progress` (and `can_cancel` is true), with a confirmation
step, and SHALL reflect the resulting state on refresh.

#### Scenario: Cancel in-progress run

- **WHEN** the user presses `c` on an in-progress run and confirms
- **THEN** cancel is called and the run eventually renders as cancelled

#### Scenario: Completed run cannot be cancelled

- **WHEN** a run's status is `completed`
- **THEN** no cancel action is offered

### Requirement: Action feedback without dead ends

Every action (success or failure) SHALL produce visible feedback in the UI
(status line with message) and never leave the user waiting indefinitely;
pending actions MUST show an in-flight indicator and disable re-triggering
while running.

#### Scenario: Double-trigger prevented

- **WHEN** the user confirms a rerun and the request is still in flight
- **THEN** a second rerun cannot be triggered from the dashboard until the
  first completes
