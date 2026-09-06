--- Async command runner for the `gh` (and `git`) CLIs.
---
--- The only place in the plugin that spawns processes. Results arrive on the
--- main thread via `vim.schedule_wrap` and failures are mapped to typed
--- errors `{ kind, message, hint }` — never silent `nil`s.
local M = {}
M.__index = M

---@alias ascii_ui_actions.github.ErrorKind "gh_missing"|"auth"|"api"|"network"|"parse"

---@class ascii_ui_actions.github.Error
---@field kind ascii_ui_actions.github.ErrorKind
---@field message string
---@field hint string?

---@class ascii_ui_actions.github.RunnerOpts
---@field system? fun(cmd: string[], opts: table, on_exit: fun(err: table?, output: table)): table

---@param opts? ascii_ui_actions.github.RunnerOpts
---@return ascii_ui_actions.github.Runner
function M.new(opts)
	opts = opts or {}
	return setmetatable({
		_system = opts.system or vim.system,
	}, M)
end

---@param text string
---@param pattern string
local function has(text, pattern)
	return text:find(pattern, 1) ~= nil
end

--- Map a completed process outcome to a typed error, or nil on success.
---@param args string[]
---@param spawn_err table?
---@param output { code: integer, stdout: string?, stderr: string? }?
---@return ascii_ui_actions.github.Error?, string
local function classify(args, spawn_err, output)
	local cmd = args[1]

	if spawn_err then
		if cmd == "gh" then
			return {
				kind = "gh_missing",
				message = "gh executable not found (" .. tostring(spawn_err.err) .. ")",
				hint = "Install gh: https://cli.github.com/",
			},
				""
		end
		return {
			kind = "api",
			message = "failed to run '" .. cmd .. "' (" .. tostring(spawn_err.err) .. ")",
		},
			""
	end

	local code = output and output.code or -1
	local stderr = (output and output.stderr) or ""
	local stdout = (output and output.stdout) or ""

	if code == 0 then
		return nil, stdout
	end

	if cmd == "gh" then
		if
			has(stderr, "gh auth login")
			or has(stderr, "not logged in")
			or has(stderr, "bad credentials")
			or has(stderr, "HTTP 401")
		then
			return {
				kind = "auth",
				message = stderr:match("^[^\r\n]+") or stderr,
				hint = "Run: gh auth login",
			},
				stdout
		end
		if
			has(stderr, "no such host")
			or has(stderr, "dial tcp")
			or has(stderr, "connection refused")
			or has(stderr, "could not resolve")
			or has(stderr, "timed out")
		then
			return {
				kind = "network",
				message = "network error reaching GitHub",
				hint = "Check your connection and GH_HOST",
			},
				stdout
		end
		local msg, status = stderr:match("gh: (.-) %((HTTP %d+)%)")
		if msg then
			local hint
			if status == "HTTP 404" then
				hint = "Check the repo/path and your access — gh auth status"
			end
			return { kind = "api", message = msg .. " " .. status, hint = hint }, stdout
		end
	end

	return { kind = "api", message = stderr:match("^[^\r\n]+") or (cmd .. " failed with code " .. code) }, stdout
end

--- Run args async. on_done(err, stdout) is always called once, on the main
--- thread (err is a typed error or nil).
---@param args string[]
---@param on_done fun(err: ascii_ui_actions.github.Error?, stdout: string)
function M:run(args, on_done)
	local done = vim.schedule_wrap(on_done)
	self._system(args, { text = true }, function(spawn_err, output)
		local err, stdout = classify(args, spawn_err, output)
		if err then
			done(err, stdout)
		else
			done(nil, stdout)
		end
	end)
end

--- Run args async and JSON-decode stdout. Empty output decodes to nil
--- (204 responses from action endpoints).
---@param args string[]
---@param on_done fun(err: ascii_ui_actions.github.Error?, data: any)
function M:run_json(args, on_done)
	self:run(args, function(err, stdout)
		if err then
			return on_done(err, nil)
		end
		if stdout == nil or stdout:match("^%s*$") then
			return on_done(nil, nil)
		end
		local ok, decoded = pcall(vim.json.decode, stdout)
		if not ok then
			return on_done({
				kind = "parse",
				message = "invalid JSON from " .. table.concat(args, " ") .. ": " .. stdout:sub(1, 200),
			}, nil)
		end
		on_done(nil, decoded)
	end)
end

return M
