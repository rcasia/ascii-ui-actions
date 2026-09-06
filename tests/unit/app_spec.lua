pcall(require, "luacov")

local eq = require("tests.assertions").eq
local Dashboard = require("ascii-ui-actions.ui.app")
local harness = require("tests.harness")

--- A fake client whose callbacks are queued and executed by the test.
--- This lets the test drain callbacks *outside* the effect, mirroring how
--- the real runner's `vim.schedule_wrap` keeps dispatch out of `run_pending`.
local function stub_client()
	local self = {
		queue = {},
		calls = {},
		workflows = {},
		runs = {},
		jobs = {},
		search_results = {},
		origin = nil,
		origin_err = nil,
	}

	local function enqueue(cb, ...)
		table.insert(self.queue, { cb = cb, args = { ... } })
	end

	function self:list_workflows(repo, cb)
		table.insert(self.calls, { "list_workflows", repo })
		enqueue(cb, nil, self.workflows)
	end
	function self:list_runs(repo, workflow_id, opts, cb)
		table.insert(self.calls, { "list_runs", repo, workflow_id, opts.page })
		enqueue(cb, nil, self.runs, #self.runs)
	end
	function self:run_jobs(repo, run_id, opts, cb)
		table.insert(self.calls, { "run_jobs", repo, run_id })
		enqueue(cb, nil, self.jobs, #self.jobs)
	end
	function self:search_repos(query, cb)
		table.insert(self.calls, { "search_repos", query })
		enqueue(cb, nil, self.search_results)
	end
	function self:rerun_run(repo, run_id, cb)
		table.insert(self.calls, { "rerun_run", repo, run_id })
		enqueue(cb, nil)
	end
	function self:rerun_failed_jobs(repo, run_id, cb)
		table.insert(self.calls, { "rerun_failed_jobs", repo, run_id })
		enqueue(cb, nil)
	end
	function self:cancel_run(repo, run_id, cb)
		table.insert(self.calls, { "cancel_run", repo, run_id })
		enqueue(cb, nil)
	end
	function self:dispatch_workflow(repo, workflow_id, ref, cb)
		table.insert(self.calls, { "dispatch_workflow", repo, workflow_id, ref })
		enqueue(cb, nil)
	end
	function self:get_origin(cwd, cb)
		table.insert(self.calls, { "get_origin", cwd })
		enqueue(cb, self.origin_err, self.origin)
	end

	--- Execute all queued callbacks, draining nested enqueues.
	function self:drain()
		while #self.queue > 0 do
			local item = table.remove(self.queue, 1)
			item.cb(unpack(item.args))
		end
	end

	return self
end

--- Run a render pass, drain client callbacks, then render again so state
--- changes from async callbacks are visible. Repeat to handle chained calls.
local function flush(screen, client, passes)
	for _ = 1, passes or 3 do
		screen:_rerender()
		client:drain()
	end
	screen:_rerender()
	return screen
end

--- A workflows payload with one active workflow + recent repo run.
local function sample_workflows(client)
	client.workflows = {
		{
			id = 1,
			name = "CI",
			path = ".github/workflows/ci.yml",
			state = "active",
			html_url = "https://github.com/o/r/actions/workflows/ci.yml",
		},
	}
	client.runs = {
		{
			workflow_id = 1,
			id = 5,
			display_title = "fix bug",
			head_branch = "main",
			event = "push",
			actor = { login = "ric" },
			status = "completed",
			conclusion = "success",
			created_at = "2026-09-05T11:58:00Z",
			updated_at = "2026-09-05T12:00:00Z",
			can_re_run = true,
		},
	}
end

local function sample_run_jobs(client)
	client.jobs = {
		{
			id = 100,
			name = "lint",
			status = "completed",
			conclusion = "success",
			started_at = "2026-09-05T11:00:00Z",
			completed_at = "2026-09-05T11:00:12Z",
		},
	}
end

describe("Dashboard", function()
	it("opens directly on the configured repo and lists workflows", function()
		local client = stub_client()
		sample_workflows(client)
		local screen = harness.render(Dashboard, {
			title = "actions",
			repo = "o/r",
			refresh_interval = 0,
			cwd = "/tmp",
			client = client,
		})
		flush(screen, client)
		assert(screen:hasText("o/r"), "breadcrumb shows repo")
		assert(screen:hasText("CI"), "workflow row")
		assert(screen:hasText("✓"), "status glyph")
		assert(screen:hasText("fetched"), "status line")
	end)

	it("selecting a workflow opens its runs", function()
		local client = stub_client()
		sample_workflows(client)
		local screen = harness.render(Dashboard, {
			title = "actions",
			repo = "o/r",
			refresh_interval = 0,
			cwd = "/tmp",
			client = client,
		})
		flush(screen, client)
		screen:select("CI")
		flush(screen, client)
		assert(screen:hasText("fix bug"), "run row visible")
		assert(screen:hasText("o/r › CI"), "runs breadcrumb")
	end)

	it("selecting a run opens its detail + jobs", function()
		local client = stub_client()
		sample_workflows(client)
		sample_run_jobs(client)
		local screen = harness.render(Dashboard, {
			title = "actions",
			repo = "o/r",
			refresh_interval = 0,
			cwd = "/tmp",
			client = client,
		})
		flush(screen, client)
		screen:select("CI")
		flush(screen, client)
		screen:select("fix bug")
		flush(screen, client)
		assert(screen:hasText("workflow"), "run meta")
		assert(screen:hasText("lint"), "job row")
	end)

	it("detects the repo from origin when none is configured", function()
		local client = stub_client()
		sample_workflows(client)
		client.origin = "git@github.com:acme/widget.git\n"
		client.origin_err = nil
		local screen = harness.render(Dashboard, {
			title = "actions",
			repo = nil,
			refresh_interval = 0,
			cwd = "/tmp",
			client = client,
		})
		flush(screen, client, 4)
		assert(screen:hasText("acme/widget"), "detected repo")
		assert(screen:hasText("CI"), "workflows loaded")
	end)

	it("falls back to the repo picker when origin detection fails", function()
		local client = stub_client()
		client.origin_err = { kind = "api", message = "no remote" }
		local screen = harness.render(Dashboard, {
			title = "actions",
			repo = nil,
			refresh_interval = 0,
			cwd = "/tmp",
			client = client,
		})
		flush(screen, client, 4)
		assert(screen:hasText("select repository"), "picker shown")
	end)
end)
