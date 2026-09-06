local Client = require("ascii-ui-actions.github.client")
local eq = require("tests.assertions").eq

--- Stub runner: records argv, replies synchronously with per-endpoint fixtures.
---@param json_by_pattern table<string, any> pattern → decoded fixture
---@return table stub, table[] calls
local function stub_runner(json_by_pattern)
	local calls = {}
	local stub = {
		calls = calls,
		run = function(self, args, cb)
			table.insert(calls, args)
			cb(nil, "git@github.com:ricardocasia/ascii-ui-actions.git\n")
		end,
		run_json = function(self, args, cb)
			table.insert(calls, args)
			local key = table.concat(args, " ")
			for pattern, fixture in pairs(json_by_pattern or {}) do
				if key:find(pattern, 1, true) then
					return cb(nil, fixture)
				end
			end
			cb(nil, nil)
		end,
	}
	return stub, calls
end

describe("github.client", function()
	it("list_workflows spawns gh api with the workflows endpoint", function()
		local fixture = { workflows = { { id = 1, name = "CI", path = ".github/workflows/ci.yml" } } }
		local r, calls = stub_runner({ ["/repos/o/r/actions/workflows"] = fixture })
		local client = Client.new({ runner = r })
		local out
		client:list_workflows("o/r", function(err, workflows)
			out = { err = err, workflows = workflows }
		end)
		assert(out and out.err == nil, "no error")
		eq({ "gh", "api", "/repos/o/r/actions/workflows" }, calls[1])
		eq(1, #out.workflows)
		eq("CI", out.workflows[1].name)
	end)

	it("list_runs paginates repo-wide runs", function()
		local fixture = { workflow_runs = { { id = 42 } }, total_count = 120 }
		local r, calls = stub_runner({ ["/repos/o/r/actions/runs?per_page=50&page=2"] = fixture })
		local client = Client.new({ runner = r })
		local out
		client:list_runs("o/r", nil, { page = 2, per_page = 50 }, function(err, runs, total)
			out = { err = err, runs = runs, total = total }
		end)
		assert(out and out.err == nil, "no error")
		eq({ "gh", "api", "/repos/o/r/actions/runs?per_page=50&page=2" }, calls[1])
		eq(42, out.runs[1].id)
		eq(120, out.total)
	end)

	it("list_runs scopes to a workflow", function()
		local fixture = { workflow_runs = {}, total_count = 0 }
		local r, calls = stub_runner({ ["/repos/o/r/actions/workflows/ci.yml/runs?per_page=50&page=1"] = fixture })
		local client = Client.new({ runner = r })
		local called = false
		client:list_runs("o/r", "ci.yml", { page = 1, per_page = 50 }, function()
			called = true
		end)
		assert(called, "callback fired")
		eq({ "gh", "api", "/repos/o/r/actions/workflows/ci.yml/runs?per_page=50&page=1" }, calls[1])
	end)

	it("run_jobs fetches jobs of a run", function()
		local fixture =
			{ jobs = { { id = 7, name = "lint", status = "completed", conclusion = "success" } }, total_count = 1 }
		local r, calls = stub_runner({ ["/repos/o/r/actions/runs/123/jobs?per_page=50"] = fixture })
		local client = Client.new({ runner = r })
		local out
		client:run_jobs("o/r", 123, { per_page = 50 }, function(err, jobs, total)
			out = { err = err, jobs = jobs, total = total }
		end)
		assert(out and out.err == nil, "no error")
		eq({ "gh", "api", "/repos/o/r/actions/runs/123/jobs?per_page=50" }, calls[1])
		eq("lint", out.jobs[1].name)
	end)

	it("get_origin runs git remote in the given cwd", function()
		local r, calls = stub_runner({})
		local client = Client.new({ runner = r })
		local out
		client:get_origin("/tmp/proj", function(err, stdout)
			out = { err = err, stdout = stdout }
		end)
		eq({ "git", "-C", "/tmp/proj", "remote", "get-url", "origin" }, calls[1])
		assert(out.stdout:find("github.com", 1, true), "origin url")
	end)

	it("search_repos uses gh search with json output", function()
		local fixture = { { fullName = "o/one" }, { fullName = "o/two" } }
		local r, calls = stub_runner({ ["gh search repos actions"] = fixture })
		local client = Client.new({ runner = r })
		local out
		client:search_repos("actions", function(err, results)
			out = { err = err, results = results }
		end)
		assert(out and out.err == nil, "no error")
		eq({ "gh", "search", "repos", "actions", "--json", "fullName", "--limit", "20" }, calls[1])
		eq("o/two", out.results[2].fullName)
	end)

	it("dispatch_workflow POSTs with ref body", function()
		local r, calls = stub_runner({ ["/repos/o/r/actions/workflows/build.yml/dispatches"] = nil })
		local client = Client.new({ runner = r })
		local done
		client:dispatch_workflow("o/r", "build.yml", "main", function(err)
			done = err
		end)
		assert(done == nil, "no error")
		eq(
			{ "gh", "api", "--method", "POST", "/repos/o/r/actions/workflows/build.yml/dispatches", "-f", "ref=main" },
			calls[1]
		)
	end)

	it("rerun_run POSTs the rerun endpoint", function()
		local r, calls = stub_runner({})
		local client = Client.new({ runner = r })
		local ok = false
		client:rerun_run("o/r", 99, function(err)
			ok = err == nil
		end)
		assert(ok)
		eq({ "gh", "api", "--method", "POST", "/repos/o/r/actions/runs/99/rerun" }, calls[1])
	end)

	it("rerun_failed_jobs POSTs the hyphenated endpoint", function()
		local r, calls = stub_runner({})
		local client = Client.new({ runner = r })
		local ok = false
		client:rerun_failed_jobs("o/r", 99, function(err)
			ok = err == nil
		end)
		assert(ok)
		eq({ "gh", "api", "--method", "POST", "/repos/o/r/actions/runs/99/rerun-failed-jobs" }, calls[1])
	end)

	it("cancel_run POSTs the cancel endpoint", function()
		local r, calls = stub_runner({})
		local client = Client.new({ runner = r })
		local ok = false
		client:cancel_run("o/r", 99, function(err)
			ok = err == nil
		end)
		assert(ok)
		eq({ "gh", "api", "--method", "POST", "/repos/o/r/actions/runs/99/cancel" }, calls[1])
	end)

	it("propagates typed errors unchanged", function()
		local err = { kind = "gh_missing", message = "gh executable not found", hint = "Install gh" }
		local calls = {}
		local r = {
			run_json = function(self, args, cb)
				table.insert(calls, args)
				cb(err, nil)
			end,
		}
		local client = Client.new({ runner = r })
		local out
		client:list_workflows("o/r", function(got, data)
			out = { got = got, data = data }
		end)
		eq(err, out.got)
		assert(out.data == nil, "no data on error")
	end)
end)
