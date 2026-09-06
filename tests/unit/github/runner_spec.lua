local Runner = require("ascii-ui-actions.github.runner")

--- Stub vim.system: invokes on_exit with the canned outcome and records argv.
---@param outcome { err?: table, code?: integer, stdout?: string, stderr?: string }
---@return ascii_ui_actions.github.Runner, string[][]
local function stub(outcome)
	local calls = {}
	local system = function(cmd, _opts, on_exit)
		table.insert(calls, cmd)
		on_exit(outcome.err, {
			code = outcome.code or 0,
			stdout = outcome.stdout or "",
			stderr = outcome.stderr or "",
		})
		return {}
	end
	return Runner.new({ system = system }), calls
end

--- run() is schedule_wrap'd: pump the event loop until the callback lands.
---@param runner table
---@param args string[]
---@return table? pending
local function run_and_wait(runner, args)
	local result = {}
	runner:run(args, function(err, stdout)
		result.err = err
		result.stdout = stdout
		result.done = true
	end)
	vim.wait(500, function()
		return result.done
	end)
	return result
end

describe("github.runner", function()
	it("delivers decoded stdout on success", function()
		local runner = stub({ code = 0, stdout = '{"total":1}' })
		local res = run_and_wait(runner, { "gh", "api", "/x" })
		assert(res.err == nil, "no error: " .. tostring(res.err and res.err.kind))
		assert(res.done, "callback fired")
		assert(res.stdout:find("total", 1, true))
	end)

	it("maps missing gh to gh_missing with install hint", function()
		local runner = stub({ err = { err = "ENOENT" } })
		local res = run_and_wait(runner, { "gh", "api", "/x" })
		assert(res.err and res.err.kind == "gh_missing", "kind: " .. tostring(res.err and res.err.kind))
		assert(res.err.hint:find("cli.github.com", 1, true), "hint: " .. res.err.hint)
	end)

	it("maps 'gh auth login' in stderr to auth", function()
		local runner =
			stub({ code = 1, stderr = "gh: To use GitHub with the gh command line tool, run 'gh auth login'" })
		local res = run_and_wait(runner, { "gh", "api", "/x" })
		assert(res.err and res.err.kind == "auth", "kind: " .. tostring(res.err and res.err.kind))
		assert(res.err.hint:find("gh auth login", 1, true), "hint: " .. res.err.hint)
	end)

	it("maps API HTTP errors to api with the GitHub message verbatim", function()
		local runner = stub({ code = 1, stderr = "gh: Not Found (HTTP 404)\n" })
		local res = run_and_wait(runner, { "gh", "api", "/x" })
		assert(res.err and res.err.kind == "api", "kind: " .. tostring(res.err and res.err.kind))
		assert(res.err.message:find("Not Found", 1, true), "message: " .. res.err.message)
	end)

	it("maps DNS/connection failures to network", function()
		local runner =
			stub({ code = 1, stderr = 'Get "https://api.github.com": dial tcp: lookup api.github.com: no such host' })
		local res = run_and_wait(runner, { "gh", "api", "/x" })
		assert(res.err and res.err.kind == "network", "kind: " .. tostring(res.err and res.err.kind))
	end)

	it("passes other spawn failures through as api errors (git)", function()
		local runner = stub({ err = { err = "ENOENT" } })
		local res = run_and_wait(runner, { "git", "remote", "get-url", "origin" })
		assert(res.err and res.err.kind == "api", "kind: " .. tostring(res.err and res.err.kind))
		assert(res.err.message:find("git", 1, true), "message: " .. res.err.message)
	end)

	it("run_json maps invalid JSON to parse with raw head", function()
		local runner_obj = stub({ code = 0, stdout = "<html>nope</html>" })
		local result = {}
		runner_obj:run_json({ "gh", "api", "/x" }, function(err, data)
			result.err = err
			result.data = data
			result.done = true
		end)
		vim.wait(500, function()
			return result.done
		end)
		assert(result.err and result.err.kind == "parse", "kind: " .. tostring(result.err and result.err.kind))
		assert(result.err.message:find("<html>nope", 1, true), "message: " .. result.err.message)
		assert(result.done, "callback fired")
	end)

	it("run_json decodes objects", function()
		local runner_obj = stub({ code = 0, stdout = '{"workflows":[{"id":1}]}' })
		local result = {}
		runner_obj:run_json({ "gh", "api", "/x" }, function(err, data)
			result.err = err
			result.data = data
			result.done = true
		end)
		vim.wait(500, function()
			return result.done
		end)
		assert(result.done)
		assert(result.err == nil)
		assert(result.data.workflows[1].id == 1, "decoded")
	end)

	it("run_json treats empty stdout as nil data (204)", function()
		local runner_obj = stub({ code = 0, stdout = "" })
		local result = {}
		runner_obj:run_json({ "gh", "api", "--method", "POST", "/x" }, function(err, data)
			result.err = err
			result.data = data
			result.done = true
		end)
		vim.wait(500, function()
			return result.done
		end)
		assert(result.done)
		assert(result.err == nil, "no error")
		assert(result.data == nil, "nil payload")
	end)
end)
