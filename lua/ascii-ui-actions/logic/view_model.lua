--- Pure view-model: dashboard state + payloads → plain row data for the
--- render layer. No ascii-ui, no vim API except os.date — the current clock
--- arrives as `now` (epoch seconds) from the caller so tests stay stable.
local nav = require("ascii-ui-actions.logic.nav")
local tokens = require("ascii-ui-actions.ui.tokens")

local M = {}

-- ───────────────────────────── time helpers ─────────────────────────────

--- Seconds since epoch for an ISO-8601 UTC timestamp ("2026-09-05T12:00:00Z").
---@param iso string?
---@return integer?
function M.utc_epoch(iso)
	if type(iso) ~= "string" then
		return nil
	end
	local y, mo, d, h, mi, s = iso:match("^(%d+)%-(%d+)%-(%d+)T(%d+):(%d+):(%d+)")
	if not y then
		return nil
	end
	local target = {
		year = tonumber(y),
		month = tonumber(mo),
		day = tonumber(d),
		hour = tonumber(h),
		min = tonumber(mi),
		sec = tonumber(s),
	}
	return os.time(target) + os.difftime(os.time(), os.time(os.date("!*t", os.time())))
end

--- Format a duration in seconds as "1h2m3s" / "2m14s" / "12s".
---@param secs integer
---@return string
function M.fmt_duration(secs)
	if secs < 0 then
		secs = 0
	end
	local h = math.floor(secs / 3600)
	local m = math.floor((secs % 3600) / 60)
	local s = secs % 60
	if h > 0 then
		return h .. "h" .. m .. "m" .. s .. "s"
	end
	if m > 0 then
		return m .. "m" .. s .. "s"
	end
	return s .. "s"
end

--- Run duration: created→updated when completed, started→now while running.
---@param run table
---@param now integer
---@return string
function M.run_duration(run, now)
	local created = M.utc_epoch(run.created_at)
	if not created then
		return ""
	end
	local finish
	if run.status == "completed" then
		finish = M.utc_epoch(run.updated_at)
	else
		finish = M.utc_epoch(run.run_started_at or run.created_at)
	end
	if not finish then
		return ""
	end
	return M.fmt_duration(finish - created)
end

--- Human relative time, e.g. "3h ago" (from an ISO timestamp to `now`).
---@param iso string?
---@param now integer
---@return string
function M.rel_time(iso, now)
	local t = M.utc_epoch(iso)
	if not t then
		return ""
	end
	local d = math.max(0, now - t)
	if d < 60 then
		return d .. "s ago"
	end
	if d < 3600 then
		return math.floor(d / 60) .. "m ago"
	end
	if d < 86400 then
		return math.floor(d / 3600) .. "h ago"
	end
	return math.floor(d / 86400) .. "d ago"
end

-- ───────────────────────────── row builders ─────────────────────────────

local function truncate(s, w)
	s = s or ""
	if #s > w then
		return s:sub(1, w - 1) .. "…"
	end
	return s
end

--- Status label + token key for a run/job.
---@param item table { status, conclusion? }
---@return { state: string, glyph: string, highlight: string? }
function M.status(item)
	local key = tokens.state_for(item)
	local st = tokens.state(key)
	return { state = key, glyph = st.glyph, highlight = st.highlight }
end

--- Workflow rows: last-run status, name, path.
---@param workflows table[]
---@param runs table[] recent repo-wide runs (first per workflow wins)
---@param now integer
---@return table[] { state, glyph, highlight, id, name, path, html_url, last_branch, updated, can_dispatch }
function M.workflow_rows(workflows, runs, now)
	local last = {}
	for _, run in ipairs(runs or {}) do
		if run.workflow_id and not last[run.workflow_id] then
			last[run.workflow_id] = run
		end
	end
	local rows = {}
	for _, w in ipairs(workflows or {}) do
		local lr = last[w.id]
		local key = lr and tokens.state_for(lr) or "neutral"
		local st = tokens.state(key)
		table.insert(rows, {
			state = key,
			glyph = st.glyph,
			highlight = st.highlight,
			id = w.id,
			name = truncate(w.name, 20),
			path = w.path or "",
			html_url = w.html_url,
			last_branch = lr and lr.head_branch,
			updated = lr and M.rel_time(lr.created_at, now) or "",
			can_dispatch = w.state ~= "inactive",
		})
	end
	return rows
end

--- Action availability for a run (D8/spec gating rules).
---@param run table
---@return { rerun: boolean, rerun_failed: boolean, cancel: boolean }
function M.run_actions(run)
	if not run or type(run) ~= "table" then
		return { rerun = false, rerun_failed = false, cancel = false }
	end
	local running = run.status == "queued" or run.status == "in_progress"
	return {
		rerun = run.can_re_run == true,
		rerun_failed = run.can_re_run_failed == true and run.conclusion == "failed",
		cancel = run.can_cancel == true and running,
	}
end

--- Run rows with formatted columns.
---@param runs table[]
---@param now integer
---@return table[]
function M.run_rows(runs, now)
	local rows = {}
	for _, r in ipairs(runs or {}) do
		local st = M.status(r)
		table.insert(rows, {
			id = r.id,
			state = st.state,
			glyph = st.glyph,
			highlight = st.highlight,
			name = truncate(r.display_title or r.name or tostring(r.id), 24),
			branch = truncate(r.head_branch or "", 18),
			event = r.event or "",
			actor = (r.actor and r.actor.login) or "",
			duration = M.run_duration(r, now),
			run = r,
			actions = M.run_actions(r),
		})
	end
	return rows
end

--- Job rows for the run detail view.
---@param jobs table[]
---@param now integer
---@return table[]
function M.job_rows(jobs, now)
	local rows = {}
	for _, j in ipairs(jobs or {}) do
		local st = M.status(j)
		local dur = ""
		local started, finished = M.utc_epoch(j.started_at), M.utc_epoch(j.completed_at)
		if started and finished then
			dur = M.fmt_duration(finished - started)
		end
		table.insert(rows, {
			state = st.state,
			glyph = st.glyph,
			highlight = st.highlight,
			name = truncate(j.name or tostring(j.id), 28),
			duration = dur,
			url = j.html_url or "",
		})
	end
	return rows
end

--- Run metadata rows (label/value pairs) for the detail header.
---@param run table
---@param now integer
---@return { label: string, value: string }[]
function M.run_meta(run, now)
	if not run then
		return {}
	end
	return {
		{ label = "workflow", value = run.name or "" },
		{ label = "branch", value = run.head_branch or "" },
		{ label = "commit", value = (run.head_sha or ""):sub(1, 7) },
		{ label = "trigger", value = run.event or "" },
		{ label = "actor", value = (run.actor and run.actor.login) or "" },
		{ label = "created", value = M.rel_time(run.created_at, now) },
		{ label = "duration", value = M.run_duration(run, now) },
	}
end

--- More rows remain beyond the cap? (drives the "load more" row)
---@param shown_count integer rows currently rendered
---@param total_count? integer from the API
---@param fetched_count integer size of the last fetched payload page
---@return boolean
function M.has_more(shown_count, total_count, fetched_count)
	if (fetched_count or 0) < nav.PER_PAGE then
		return false
	end
	if total_count then
		return shown_count < total_count
	end
	return true
end

--- The 50-row cap: first nav.MAX_ROWS rows + "load more" marker.
---@param rows table[]
---@param has_more boolean
---@return table[] capped rows
---@return boolean show load-more row
function M.cap(rows, more)
	if #rows > nav.MAX_ROWS then
		local capped = {}
		for i = 1, nav.MAX_ROWS do
			capped[i] = rows[i]
		end
		return capped, true
	end
	return rows, more == true
end

-- ───────────────────────────── view framing ─────────────────────────────

--- Breadcrumb text per view kind.
---@param view table
---@return string
function M.breadcrumb(view)
	if view.kind == "detect" then
		return "resolving repository…"
	end
	if view.kind == "picker" then
		return "select repository"
	end
	if view.kind == "workflows" then
		return " " .. view.repo
	end
	if view.kind == "runs" then
		local wf = view.workflow_name or view.workflow_id
		return " " .. view.repo .. " › " .. (wf or "all workflows")
	end
	if view.kind == "run_detail" then
		local wf = view.workflow_name or view.workflow_id or "runs"
		local id = view.run and view.run.id or ""
		return " " .. view.repo .. " › " .. wf .. " › #" .. id
	end
	return ""
end

--- Status-line text and severity token.
---@param state table
---@return { text: string, kind: "ok"|"error"|"warn"|"neutral" }
function M.status_line(state)
	if state.pending_action then
		if state.pending_action.state == "running" then
			return { text = " … " .. state.pending_action.kind .. " in flight", kind = "warn" }
		end
		return { text = " confirm " .. state.pending_action.kind .. " · y/n", kind = "warn" }
	end
	if state.error and state.stale then
		return { text = " " .. state.error.message .. " · stale", kind = "error" }
	end
	if state.action_message then
		return { text = tokens.state("success").glyph .. " " .. state.action_message, kind = "ok" }
	end
	if state.status == "error" and state.error then
		return { text = state.error.message, kind = "error" }
	end
	if state.fetched_at then
		return { text = " fetched " .. state.fetched_at, kind = "neutral" }
	end
	return { text = " …", kind = "neutral" }
end

return M
