pcall(require, "luacov")

local eq = require("tests.assertions").eq
local ConfirmBar = require("ascii-ui-actions.ui.components.confirm_bar")
local DispatchForm = require("ascii-ui-actions.ui.components.dispatch_form")
local RunDetailView = require("ascii-ui-actions.ui.views.run_detail")
local RunsView = require("ascii-ui-actions.ui.views.runs")
local WorkflowsView = require("ascii-ui-actions.ui.views.workflows")
local harness = require("tests.harness")
local vm = require("ascii-ui-actions.logic.view_model")
local HelpOverlay = require("ascii-ui-actions.ui.views.help_overlay").Overlay
local RepoPicker = require("ascii-ui-actions.ui.views.repo_picker")

local NOW = vm.utc_epoch("2026-09-05T12:00:00Z")

describe("ui.views", function()
	it("WorkflowList renders aligned rows and selects by index", function()
		local opened
		local rows = vm.workflow_rows({
			{ id = 1, name = "Lint", path = ".github/workflows/lint.yml", state = "active" },
			{ id = 2, name = "Docker Image", path = ".github/workflows/docker.yml", state = "active" },
		}, {
			{ workflow_id = 1, status = "completed", conclusion = "success", created_at = "2026-09-05T11:45:00Z" },
		}, NOW)
		local screen = harness.render(WorkflowsView.List, {
			rows = rows,
			on_open = function(i)
				opened = i
			end,
		})
		local out = screen:toLines()
		assert(out[1]:find("Lint", 1, true), out[1])
		assert(out[1]:find("15m ago", 1, true), out[1])
		assert(out[2]:find("Docker Image", 1, true), out[2])
		screen:select("Lint")
		eq(1, opened)
	end)

	it("RunList appends a focusable load-more row", function()
		local loaded = false
		local rows = vm.run_rows({
			{
				id = 1,
				display_title = "fix bug",
				head_branch = "main",
				event = "push",
				actor = { login = "ric" },
				status = "completed",
				conclusion = "success",
				created_at = "2026-09-05T11:59:48Z",
				updated_at = "2026-09-05T12:00:00Z",
			},
		}, NOW)
		local screen = harness.render(RunsView.List, {
			rows = rows,
			show_more = true,
			on_open = function() end,
			on_load_more = function()
				loaded = true
			end,
		})
		assert(screen:hasText("fix bug"), "run row")
		assert(screen:hasFocusable("load more"), "load more focusable")
		screen:select("load more")
		assert(loaded, "load more fires")
	end)

	it("RunDetail lists metadata, a spacer, then job rows", function()
		local run = {
			id = 7,
			name = "CI",
			head_branch = "main",
			head_sha = "abcdef1234567890",
			event = "push",
			actor = { login = "ric" },
			status = "completed",
			conclusion = "success",
			created_at = "2026-09-05T11:00:00Z",
			updated_at = "2026-09-05T11:02:14Z",
		}
		local screen = harness.render(RunDetailView.View, {
			meta = vm.run_meta(run, NOW),
			jobs = vm.job_rows({
				{
					id = 1,
					name = "lint",
					status = "completed",
					conclusion = "success",
					started_at = "2026-09-05T11:00:00Z",
					completed_at = "2026-09-05T11:00:12Z",
				},
				{
					id = 2,
					name = "test",
					status = "completed",
					conclusion = "failure",
					started_at = "2026-09-05T11:00:00Z",
					completed_at = "2026-09-05T11:02:00Z",
				},
			}, NOW),
		})
		local out = screen:toLines()
		assert(out[1]:find("workflow", 1, true) and out[1]:find("CI", 1, true), out[1])
		assert(#out >= 10, "expected 7 meta rows + spacer + 2 job rows")
		assert(out[8] == " ", "spacer line") -- 8th row is the spacer
		assert(screen:hasText("1h ago"), "created meta")
		assert(screen:hasText("2m14s"), "duration meta")
		assert(screen:hasText("✓ lint"), "lint job")
		assert(screen:hasText("✗ test"), "test job")
	end)

	it("ConfirmBar shows the prompt and confirms/aborts", function()
		local ok, abort = false, false
		local screen = harness.render(ConfirmBar, {
			prompt = "rerun #7 on o/r?",
			on_confirm = function()
				ok = true
			end,
			on_abort = function()
				abort = true
			end,
		})
		assert(screen:hasText("rerun #7"), "prompt")
		screen:select("[y] confirm")
		assert(ok, "confirmed")
		screen:select("[n] abort")
		assert(abort, "aborted")
	end)

	it("DispatchForm defaults ref to main and submits on dispatch", function()
		local submitted
		local screen = harness.render(DispatchForm, {
			workflow_name = "CI",
			initial_ref = "main",
			on_submit = function(ref)
				submitted = ref
			end,
			on_abort = function() end,
		})
		assert(screen:hasText("CI"), "workflow name")
		assert(screen:hasText("main"), "prefilled ref")
		screen:select("[y] dispatch")
		eq("main", submitted)
	end)

	it("RepoPicker lists search results and picks one", function()
		local picked
		local screen = harness.render(RepoPicker.View, {
			results = { { fullName = "acme/widget" }, { fullName = "acme/other" } },
			on_submit = function() end,
			on_pick = function(i)
				picked = i
			end,
		})
		assert(screen:hasText("acme/widget"), "result 1")
		assert(screen:hasText("acme/other"), "result 2")
		screen:select("acme/widget")
		eq(1, picked)
	end)

	it("HelpOverlay lists every keymap entry", function()
		local screen = harness.render(HelpOverlay, {})
		assert(screen:hasText("move"), "j/k")
		assert(screen:hasText("rerun failed jobs"), "F")
		assert(screen:hasText("keys"), "?")
	end)
end)
