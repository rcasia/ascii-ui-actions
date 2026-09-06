pcall(require, "luacov")

local eq = require("tests.assertions").eq
local actions = require("ascii-ui-actions.logic.actions")

--- A client stub that records which endpoint was called.
local function stub_client()
	local self = { called = nil, args = nil }
	function self:dispatch_workflow(repo, id, ref, cb)
		self.called = "dispatch_workflow"
		self.args = { repo = repo, id = id, ref = ref }
		cb(nil)
	end
	function self:rerun_run(repo, id, cb)
		self.called = "rerun_run"
		self.args = { repo = repo, id = id }
		cb(nil)
	end
	function self:rerun_failed_jobs(repo, id, cb)
		self.called = "rerun_failed_jobs"
		self.args = { repo = repo, id = id }
		cb(nil)
	end
	function self:cancel_run(repo, id, cb)
		self.called = "cancel_run"
		self.args = { repo = repo, id = id }
		cb(nil)
	end
	return self
end

describe("logic.actions", function()
	it("maps each pending kind to the right client endpoint", function()
		local cases = {
			{
				pa = { kind = "dispatch", target = { workflow_id = 9, name = "CI" }, ref = "dev" },
				ep = "dispatch_workflow",
			},
			{ pa = { kind = "rerun", target = { run_id = 5 } }, ep = "rerun_run" },
			{ pa = { kind = "rerun_failed", target = { run_id = 5 } }, ep = "rerun_failed_jobs" },
			{ pa = { kind = "cancel", target = { run_id = 5 } }, ep = "cancel_run" },
		}
		for _, c in ipairs(cases) do
			local client = stub_client()
			local err = "unset"
			actions.execute(client, c.pa, "o/r", function(e)
				err = e
			end)
			eq(c.ep, client.called, c.pa.kind)
			eq(nil, err)
		end
	end)

	it("dispatch defaults an empty ref to main", function()
		local client = stub_client()
		actions.execute(
			client,
			{ kind = "dispatch", target = { workflow_id = 1, name = "CI" }, ref = "" },
			"o/r",
			function() end
		)
		eq("main", client.args.ref)
	end)

	it("unknown kinds surface an error instead of silence", function()
		local client = stub_client()
		local got
		actions.execute(client, { kind = "explode", target = {} }, "o/r", function(e)
			got = e
		end)
		eq(nil, client.called)
		eq("api", got.kind)
	end)

	it("confirm prompts name the target", function()
		assert(actions.confirm_prompt({ kind = "rerun", target = { run_id = 5 } }, "o/r"):find("#5", 1, true))
		local d = actions.confirm_prompt({ kind = "dispatch", target = { name = "CI" }, ref = "dev" }, "o/r")
		assert(d:find("CI", 1, true) and d:find("dev", 1, true), d)
	end)
end)
