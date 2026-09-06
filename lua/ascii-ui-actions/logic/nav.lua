--- Pure dashboard state machine (D4/D5).
---
--- One reducer owns the whole UI state:
---   { view, status, data, error, stale, pending_action, action_message,
---     seq, append_requested }
---
--- `view` is { kind = "detect"|"picker"|"workflows"|"runs"|"run_detail", ... }.
--- Every navigation or refresh stamps a new `seq`; `FETCH_*` actions carrying
--- a stale seq are dropped, so fast navigation can never show wrong data.
--- Side-effect free: os/clock values arrive on the action (`at`).
local M = {}

M.PER_PAGE = 50
M.MAX_ROWS = 50

--- Copy-on-write extend that can also *clear* fields (vim.tbl_extend drops
--- nil values silently — a stale-`error` bug magnet).
---@param state table
---@param overrides table
---@return table
local function with(state, overrides)
	local t = {}
	for k, v in pairs(state) do
		t[k] = v
	end
	for k, v in pairs(overrides) do
		if v == vim.NIL then
			t[k] = nil
		else
			t[k] = v
		end
	end
	return t
end

---@param props { repo?: string, title?: string }
---@return table initial dashboard state
function M.initial(props)
	props = props or {}
	local view
	if props.repo and props.repo ~= "" then
		view = { kind = "workflows", repo = props.repo }
	else
		view = { kind = "detect" }
	end
	return {
		view = view,
		status = "loading",
		data = nil,
		error = nil,
		stale = false,
		pending_action = nil,
		action_message = nil,
		seq = 1,
		append_requested = false,
	}
end

local function set_view(state, view)
	return {
		view = view,
		status = "loading",
		data = nil,
		error = nil,
		stale = false,
		pending_action = nil,
		action_message = state.action_message,
		seq = state.seq + 1,
		append_requested = false,
	}
end

--- Parent view for `back`; nil when there is nowhere to go.
---@param view table
---@return table?
local function parent_of(view)
	if view.kind == "run_detail" then
		return { kind = "runs", repo = view.repo, workflow_id = view.workflow_id, workflow_name = view.workflow_name }
	end
	if view.kind == "runs" then
		return { kind = "workflows", repo = view.repo }
	end
	if view.kind == "workflows" then
		return { kind = "picker" }
	end
	return nil
end

local function open_runs(state, action)
	return set_view(state, {
		kind = "runs",
		repo = action.repo or state.view.repo,
		workflow_id = action.workflow_id,
		workflow_name = action.workflow_name,
	})
end

local function handle_nav(state, action)
	local nav = action.kind
	if nav == "open_workflows" then
		return set_view(state, { kind = "workflows", repo = action.repo })
	end
	if nav == "open_runs" then
		return open_runs(state, action)
	end
	if nav == "open_run_detail" then
		return set_view(state, {
			kind = "run_detail",
			repo = action.repo or state.view.repo,
			workflow_id = state.view.workflow_id,
			workflow_name = state.view.workflow_name,
			run = action.run,
			jobs_page = 1,
		})
	end
	if nav == "open_picker" then
		return set_view(state, { kind = "picker" })
	end
	if nav == "back" then
		local parent = parent_of(state.view)
		if not parent then
			return state
		end
		return set_view(state, parent)
	end
	if nav == "refresh" then
		return with(state, { status = "loading", seq = state.seq + 1, append_requested = false })
	end
	if nav == "load_more" then
		if state.view.kind == "runs" then
			local view = vim.tbl_extend("force", state.view, { page = (state.view.page or 1) + 1 })
			return with(state, { view = view, status = "loading", seq = state.seq + 1, append_requested = true })
		end
		if state.view.kind == "run_detail" then
			local view = vim.tbl_extend("force", state.view, { jobs_page = (state.view.jobs_page or 1) + 1 })
			return with(state, { view = view, status = "loading", seq = state.seq + 1, append_requested = true })
		end
		return state
	end
	return state
end

local function merge_page(state, data)
	if not state.append_requested or not state.data then
		return data
	end
	if state.view.kind == "runs" then
		return { runs = vim.list_extend(vim.deepcopy(state.data.runs or {}), data.runs or {}), total = data.total }
	end
	if state.view.kind == "run_detail" then
		return { jobs = vim.list_extend(vim.deepcopy(state.data.jobs or {}), data.jobs or {}), total = data.total }
	end
	return data
end

local function handle_result(state, action)
	local t = action.type
	if t == "FETCH_START" then
		if action.seq ~= state.seq then
			return state
		end
		return with(state, { status = "loading" })
	end
	if t == "FETCH_OK" then
		if action.seq ~= state.seq then
			return state -- stale response from a superseded view: drop it
		end
		return with(state, {
			status = "ready",
			data = merge_page(state, action.data),
			error = vim.NIL,
			stale = false,
			fetched_at = action.at,
			append_requested = false,
		})
	end
	if t == "FETCH_ERR" then
		if action.seq ~= state.seq then
			return state
		end
		if state.data then
			-- keep the last good payload, marked stale (D: cache-last-payload)
			return with(state, { status = "ready", error = action.error, stale = true, append_requested = false })
		end
		return with(state, { status = "error", error = action.error, stale = false, append_requested = false })
	end
	if t == "SEARCH_DONE" then
		if state.view.kind ~= "picker" then
			return state
		end
		return with(state, { data = { results = action.results, query = action.query } })
	end
	return state
end

local function handle_action(state, action)
	local t = action.type
	if t == "ACTION_REQUEST" then
		if state.pending_action then
			return state -- block double-trigger while one is in flight
		end
		local kind = action.action
		local initial = "confirm"
		if kind == "dispatch" then
			initial = "form"
		end
		return with(state, {
			pending_action = { kind = kind, target = action.target, ref = action.ref, state = initial },
		})
	end
	if t == "ACTION_REF" then
		if not state.pending_action then
			return state
		end
		return with(state, {
			pending_action = vim.tbl_extend("force", state.pending_action, { ref = action.ref }),
		})
	end
	if t == "ACTION_CONFIRM" then
		if not state.pending_action or state.pending_action.state == "running" then
			return state
		end
		return with(state, {
			pending_action = vim.tbl_extend("force", state.pending_action, { state = "running" }),
		})
	end
	if t == "ACTION_ABORT" then
		return with(state, { pending_action = vim.NIL })
	end
	if t == "ACTION_RESULT" then
		return with(state, {
			pending_action = vim.NIL,
			action_message = action.message,
		})
	end
	if t == "ACTION_MESSAGE_CLEAR" then
		return with(state, { action_message = vim.NIL })
	end
	return state
end

--- The single reducer: (state, action) -> state.
---@param state table
---@param action table
---@return table
function M.reduce(state, action)
	if action.type == "NAV" then
		return handle_nav(state, action)
	end
	local result = handle_result(state, action)
	if result ~= state then
		return result
	end
	return handle_action(state, action)
end

return M
