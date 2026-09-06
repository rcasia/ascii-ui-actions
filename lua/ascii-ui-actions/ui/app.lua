--- Dashboard root component. Owns ALL dashboard state in a single store and a
--- functional `dispatch` over the pure `logic/nav` reducer, so consecutive
--- actions in one tick compose instead of clobbering (ascii-ui's built-in
--- useReducer captures render-time state — see skill coding rule 6).
---
--- Data fetching, repo detection, timers and keymaps live in effects; the
--- render body only computes view data (pure) and mounts view components.
local Client = require("ascii-ui-actions.github.client")
local ConfirmBar = require("ascii-ui-actions.ui.components.confirm_bar")
local DispatchForm = require("ascii-ui-actions.ui.components.dispatch_form")
local actions = require("ascii-ui-actions.logic.actions")
local common = require("ascii-ui-actions.ui.render.common")
local nav = require("ascii-ui-actions.logic.nav")
local repo_id = require("ascii-ui-actions.logic.repo_id")
local ui = require("ascii-ui")
local vm = require("ascii-ui-actions.logic.view_model")
local HelpOverlay = require("ascii-ui-actions.ui.views.help_overlay").Overlay
local RepoPicker = require("ascii-ui-actions.ui.views.repo_picker")
local RunDetailView = require("ascii-ui-actions.ui.views.run_detail")
local RunsView = require("ascii-ui-actions.ui.views.runs")
local WorkflowsView = require("ascii-ui-actions.ui.views.workflows")

local useEffect = ui.hooks.useEffect
local useInterval = ui.hooks.useInterval
local useState = ui.hooks.useState

--- Pick and render the data-driven view (workflows / runs / run_detail) once a
--- payload exists. Module-level and pure so the component body reads as a
--- routing table. Returns a single node (a list component call or a common row).
---@param state table
---@param now integer
---@param dispatch fun(action: table)
local function content(state, now, dispatch)
	local view = state.view
	if view.kind == "workflows" then
		local rows = vm.workflow_rows(state.data.workflows, state.data.runs, now)
		if #rows == 0 then
			return common.empty_row("no workflows")
		end
		return WorkflowsView.List({
			rows = rows,
			on_open = function(index)
				local row = rows[index]
				if row then
					dispatch({
						type = "NAV",
						kind = "open_runs",
						repo = view.repo,
						workflow_id = row.id,
						workflow_name = row.name,
					})
				end
			end,
		})
	end
	if view.kind == "runs" then
		local rows = vm.run_rows(state.data.runs, now)
		local capped, more = vm.cap(rows, vm.has_more(#rows, state.data.total, #state.data.runs))
		if #capped == 0 then
			return common.empty_row("no runs yet")
		end
		return RunsView.List({
			rows = capped,
			show_more = more,
			on_open = function(index)
				local row = capped[index]
				if row then
					dispatch({
						type = "NAV",
						kind = "open_run_detail",
						repo = view.repo,
						workflow_id = view.workflow_id,
						workflow_name = view.workflow_name,
						run = row.run,
					})
				end
			end,
			on_load_more = function()
				dispatch({ type = "NAV", kind = "load_more" })
			end,
		})
	end
	if view.kind == "run_detail" then
		local jobs = vm.job_rows(state.data.jobs, now)
		local capped, more = vm.cap(jobs, vm.has_more(#jobs, state.data.total, #state.data.jobs))
		return RunDetailView.View({
			meta = vm.run_meta(view.run, now),
			jobs = capped,
			show_more = more,
			on_load_more = function()
				dispatch({ type = "NAV", kind = "load_more" })
			end,
		})
	end
	return common.empty_row("")
end

local Dashboard = ui.createComponent("Dashboard", function(props)
	local client = props.client or Client.new()
	local state, set_state = useState(nav.initial(props))
	local help_open, set_help_open = useState(false)
	local searching, set_searching = useState(false)

	--- The one and only state mutator: functional set, so queued actions
	--- reduce against the latest state, never a stale capture.
	local function dispatch(action)
		set_state(function(prev)
			return nav.reduce(prev, action)
		end)
	end

	local repo = state.view.repo

	-- ─────────────────────────── handlers (closures) ───────────────────────────

	--- Run a confirmed pending action through the client, then report + refresh.
	---@param pa table a pending_action descriptor
	local function execute(pa)
		dispatch({ type = "ACTION_CONFIRM" })
		actions.execute(client, pa, repo, function(err)
			local message
			if err then
				message = "failed: " .. err.message
			elseif pa.kind == "dispatch" then
				message = "dispatched " .. (pa.target.name or "")
			else
				message = pa.kind .. " #" .. tostring(pa.target.run_id)
			end
			dispatch({ type = "ACTION_RESULT", message = message })
			if not err then
				dispatch({ type = "NAV", kind = "refresh" })
			end
		end)
	end

	local function confirm_pending()
		local pa = state.pending_action
		if not pa or pa.state == "running" then
			return
		end
		execute(pa)
	end

	local function abort_pending()
		dispatch({ type = "ACTION_ABORT" })
	end

	---@param kind string "rerun"|"rerun_failed"|"cancel"
	local function request_run_action(kind)
		local rows = vm.run_rows(state.data.runs, os.time())
		local index = math.max(1, vim.api.nvim_win_get_cursor(0)[1] - common.HEADER_ROWS)
		local row = rows[index]
		if row and row.actions[kind] then
			dispatch({ type = "ACTION_REQUEST", action = kind, target = { run_id = row.id } })
		end
	end

	local function request_dispatch()
		local rows = vm.workflow_rows(state.data.workflows, state.data.runs, os.time())
		local index = math.max(1, vim.api.nvim_win_get_cursor(0)[1] - common.HEADER_ROWS)
		local row = rows[index]
		if row and row.can_dispatch then
			dispatch({
				type = "ACTION_REQUEST",
				action = "dispatch",
				target = { workflow_id = row.id, name = row.name },
				ref = row.last_branch or "main",
			})
		end
	end

	local function toggle_help()
		set_help_open(function(prev)
			return not prev
		end)
	end

	-- ─────────────────────────── effects ───────────────────────────

	-- Resolve the repo once, on mount, when none was configured.
	useEffect(function()
		if state.view.kind ~= "detect" then
			return
		end
		client:get_origin(props.cwd or vim.fn.getcwd(), function(err, stdout)
			local id = (not err) and repo_id.parse(stdout)
			if id then
				dispatch({ type = "NAV", kind = "open_workflows", repo = id })
			else
				dispatch({ type = "NAV", kind = "open_picker" })
			end
		end)
	end, {})

	-- Fetch the current view's data whenever navigation/refresh bumps `seq`.
	useEffect(function()
		local view = state.view
		local seq = state.seq
		if view.kind == "detect" or view.kind == "picker" then
			return
		end
		dispatch({ type = "FETCH_START", seq = seq })
		if view.kind == "workflows" then
			client:list_workflows(view.repo, function(wf_err, workflows)
				if wf_err then
					return dispatch({ type = "FETCH_ERR", seq = seq, error = wf_err })
				end
				client:list_runs(view.repo, nil, { per_page = nav.PER_PAGE }, function(run_err, runs)
					if run_err then
						return dispatch({ type = "FETCH_ERR", seq = seq, error = run_err })
					end
					dispatch({
						type = "FETCH_OK",
						seq = seq,
						data = { workflows = workflows, runs = runs },
						at = os.date("%H:%M:%S"),
					})
				end)
			end)
		elseif view.kind == "runs" then
			client:list_runs(
				view.repo,
				view.workflow_id,
				{ page = view.page or 1, per_page = nav.PER_PAGE },
				function(err, runs, total)
					if err then
						return dispatch({ type = "FETCH_ERR", seq = seq, error = err })
					end
					dispatch({
						type = "FETCH_OK",
						seq = seq,
						data = { runs = runs, total = total },
						at = os.date("%H:%M:%S"),
					})
				end
			)
		elseif view.kind == "run_detail" then
			client:run_jobs(
				view.repo,
				view.run.id,
				{ page = view.jobs_page or 1, per_page = nav.PER_PAGE },
				function(err, jobs, total)
					if err then
						return dispatch({ type = "FETCH_ERR", seq = seq, error = err })
					end
					dispatch({
						type = "FETCH_OK",
						seq = seq,
						data = { jobs = jobs, total = total },
						at = os.date("%H:%M:%S"),
					})
				end
			)
		end
	end, { state.seq, state.view.kind })

	-- Auto-refresh; a 0 interval passes nil to pause the timer (pattern 1).
	useInterval(function()
		dispatch({ type = "NAV", kind = "refresh" })
	end, (props.refresh_interval or 0) > 0 and (props.refresh_interval * 1000) or nil)

	-- Buffer-local keymaps, re-registered each render so handlers read fresh
	-- state, and torn down on unmount (skill coding rule 9).
	useEffect(function()
		local defs = {
			["<BS>"] = function()
				dispatch({ type = "NAV", kind = "back" })
			end,
			h = function()
				dispatch({ type = "NAV", kind = "back" })
			end,
			r = function()
				dispatch({ type = "NAV", kind = "refresh" })
			end,
			R = function()
				if state.view.kind == "workflows" then
					request_dispatch()
				else
					request_run_action("rerun")
				end
			end,
			F = function()
				request_run_action("rerun_failed")
			end,
			c = function()
				request_run_action("cancel")
			end,
			y = confirm_pending,
			n = abort_pending,
			["?"] = toggle_help,
			["<Esc>"] = function()
				if help_open then
					toggle_help()
				end
			end,
		}
		for lhs, fn in pairs(defs) do
			vim.keymap.set("n", lhs, fn, { buffer = 0, nowait = true, silent = true })
		end
		return function()
			for lhs in pairs(defs) do
				if vim.fn.maparg(lhs, "n", false, true) ~= "" then
					vim.keymap.del("n", lhs, { buffer = 0 })
				end
			end
		end
	end, { state, help_open })

	-- ─────────────────────────── render (pure) ───────────────────────────

	local now = os.time()
	local body
	if help_open then
		body = { HelpOverlay({}) }
	elseif state.view.kind == "detect" then
		body = { common.loading_row("resolving repository…") }
	elseif state.view.kind == "picker" then
		body = {
			RepoPicker.View({
				results = state.data and state.data.results,
				searching = searching,
				on_submit = function(text)
					local id = repo_id.parse_manual(text)
					if id then
						return dispatch({ type = "NAV", kind = "open_workflows", repo = id })
					end
					set_searching(true)
					client:search_repos(text, function(err, results)
						set_searching(false)
						if err then
							return dispatch({ type = "FETCH_ERR", seq = state.seq, error = err })
						end
						dispatch({ type = "SEARCH_DONE", results = results or {}, query = text })
					end)
				end,
				on_pick = function(index)
					local result = (state.data and state.data.results or {})[index]
					if result then
						dispatch({ type = "NAV", kind = "open_workflows", repo = result.fullName })
					end
				end,
			}),
		}
	elseif state.status == "loading" and not state.data then
		body = { common.loading_row() }
	elseif state.status == "error" and not state.data then
		body = common.error_rows(state.error)
	else
		body = { content(state, now, dispatch) }
	end

	-- Action bar under the content while one action is pending.
	local action_ui
	if state.pending_action then
		local pa = state.pending_action
		if pa.kind == "dispatch" and pa.state == "form" then
			action_ui = DispatchForm({
				workflow_name = pa.target.name or "workflow",
				initial_ref = pa.ref,
				on_submit = function(ref)
					dispatch({ type = "ACTION_REF", ref = ref })
					execute(vim.tbl_extend("force", pa, { ref = ref }))
				end,
				on_abort = abort_pending,
			})
		elseif pa.state == "confirm" then
			action_ui = ConfirmBar({
				prompt = actions.confirm_prompt(pa, repo),
				on_confirm = confirm_pending,
				on_abort = abort_pending,
			})
		end
	end

	local out = { common.title_row(props.title), common.breadcrumb_row(vm.breadcrumb(state.view)) }
	for _, n in ipairs(body) do
		out[#out + 1] = n
	end
	if action_ui then
		for _, n in ipairs(action_ui) do
			out[#out + 1] = n
		end
	end
	out[#out + 1] = common.status_row(vm.status_line(state))
	out[#out + 1] = common.hint_row(toggle_help, help_open)
	return out
end, {
	title = "string",
	repo = "string",
	cwd = "string",
	refresh_interval = "number",
	client = "table",
})

return Dashboard
