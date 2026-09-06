--- GitHub Actions API through the `gh` CLI (D1/D2).
---
--- Thin endpoint layer over an injectable runner: builds exact argv, decodes
--- JSON, and propagates typed errors to `cb(err, data)` callbacks. No UI or
--- vim state here, so tests stub the runner and assert argv.
local runner_mod = require("ascii-ui-actions.github.runner")

local M = {}
M.__index = M

---@class ascii_ui_actions.github.Client
---@field private _runner table

---@class ascii_ui_actions.github.ClientOpts
---@field runner? table Runner instance (defaults to the real vim.system runner)

---@param opts? ascii_ui_actions.github.ClientOpts
---@return ascii_ui_actions.github.Client
function M.new(opts)
	opts = opts or {}
	return setmetatable({
		_runner = opts.runner or runner_mod.new(),
	}, M)
end

---@param repo string "owner/name"
local function repo_path(repo)
	return "/repos/" .. repo
end

---@param path string
---@param page? integer
---@param per_page? integer
---@return string
local function with_query(path, page, per_page)
	local qs = {}
	if per_page then
		table.insert(qs, "per_page=" .. per_page)
	end
	if page then
		table.insert(qs, "page=" .. page)
	end
	if #qs == 0 then
		return path
	end
	return path .. "?" .. table.concat(qs, "&")
end

-- ───────────────────────────── reads ─────────────────────────────

--- Detect the repo of the current project: `git remote get-url origin`.
---@param cwd string
---@param cb fun(err: ascii_ui_actions.github.Error?, stdout: string)
function M:get_origin(cwd, cb)
	self._runner:run({ "git", "-C", cwd, "remote", "get-url", "origin" }, cb)
end

---@param query string
---@param cb fun(err: ascii_ui_actions.github.Error?, results: { fullName: string }?)
function M:search_repos(query, cb)
	self._runner:run_json({ "gh", "search", "repos", query, "--json", "fullName", "--limit", "20" }, cb)
end

---@param repo string
---@param cb fun(err: ascii_ui_actions.github.Error?, workflows: table?)
function M:list_workflows(repo, cb)
	self._runner:run_json({ "gh", "api", repo_path(repo) .. "/actions/workflows" }, function(err, data)
		cb(err, data and data.workflows or nil)
	end)
end

--- List recent runs for a repo (workflow_id nil) or one workflow.
---@param repo string
---@param workflow_id? string|integer
---@param opts? { page?: integer, per_page?: integer }
---@param cb fun(err: ascii_ui_actions.github.Error?, runs: table?, total: integer?)
function M:list_runs(repo, workflow_id, opts, cb)
	opts = opts or {}
	local base = repo_path(repo) .. "/actions"
	local path = (workflow_id and (base .. "/workflows/" .. workflow_id .. "/runs")) or (base .. "/runs")
	path = with_query(path, opts.page, opts.per_page)
	self._runner:run_json({ "gh", "api", path }, function(err, data)
		cb(err, data and data.workflow_runs or nil, data and data.total_count)
	end)
end

--- Jobs of a run (pagination via opts.page/per_page).
---@param repo string
---@param run_id integer|string
---@param opts? { page?: integer, per_page?: integer }
---@param cb fun(err: ascii_ui_actions.github.Error?, jobs: table?, total: integer?)
function M:run_jobs(repo, run_id, opts, cb)
	opts = opts or {}
	local path = with_query(repo_path(repo) .. "/actions/runs/" .. run_id .. "/jobs", opts.page, opts.per_page)
	self._runner:run_json({ "gh", "api", path }, function(err, data)
		cb(err, data and data.jobs or nil, data and data.total_count)
	end)
end

-- ───────────────────────────── actions ─────────────────────────────

---@param repo string
---@param workflow_id string|integer
---@param ref string
---@param cb fun(err: ascii_ui_actions.github.Error?)
function M:dispatch_workflow(repo, workflow_id, ref, cb)
	self._runner:run_json({
		"gh",
		"api",
		"--method",
		"POST",
		repo_path(repo) .. "/actions/workflows/" .. workflow_id .. "/dispatches",
		"-f",
		"ref=" .. ref,
	}, function(err)
		cb(err)
	end)
end

---@param repo string
---@param run_id integer|string
---@param cb fun(err: ascii_ui_actions.github.Error?)
function M:rerun_run(repo, run_id, cb)
	self._runner:run_json(
		{ "gh", "api", "--method", "POST", repo_path(repo) .. "/actions/runs/" .. run_id .. "/rerun" },
		function(err)
			cb(err)
		end
	)
end

---@param repo string
---@param run_id integer|string
---@param cb fun(err: ascii_ui_actions.github.Error?)
function M:rerun_failed_jobs(repo, run_id, cb)
	self._runner:run_json({
		"gh",
		"api",
		"--method",
		"POST",
		repo_path(repo) .. "/actions/runs/" .. run_id .. "/rerun-failed-jobs",
	}, function(err)
		cb(err)
	end)
end

---@param repo string
---@param run_id integer|string
---@param cb fun(err: ascii_ui_actions.github.Error?)
function M:cancel_run(repo, run_id, cb)
	self._runner:run_json(
		{ "gh", "api", "--method", "POST", repo_path(repo) .. "/actions/runs/" .. run_id .. "/cancel" },
		function(err)
			cb(err)
		end
	)
end

return M
