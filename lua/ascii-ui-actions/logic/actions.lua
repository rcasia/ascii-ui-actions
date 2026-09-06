--- Maps a confirmed `pending_action` to the right client call.
---
--- Kept out of the component so the action→endpoint wiring is a plain,
--- injectable function (tests pass a stub client). `on_done(err)` is called
--- exactly once with a typed error or nil.
local M = {}

---@param client ascii_ui_actions.github.Client
---@param action { kind: string, target: table, ref?: string }
---@param repo string
---@param on_done fun(err: ascii_ui_actions.github.Error?)
function M.execute(client, action, repo, on_done)
	local kind = action.kind
	local target = action.target or {}
	if kind == "dispatch" then
		local ref = (action.ref and action.ref ~= "") and action.ref or "main"
		return client:dispatch_workflow(repo, target.workflow_id, ref, on_done)
	end
	if kind == "rerun" then
		return client:rerun_run(repo, target.run_id, on_done)
	end
	if kind == "rerun_failed" then
		return client:rerun_failed_jobs(repo, target.run_id, on_done)
	end
	if kind == "cancel" then
		return client:cancel_run(repo, target.run_id, on_done)
	end
	return on_done({ kind = "api", message = "unknown action: " .. tostring(kind) })
end

--- The inline confirmation prompt for a pending action.
---@param action { kind: string, target: table, ref?: string }
---@param repo string
---@return string
function M.confirm_prompt(action, repo)
	local target = action.target or {}
	if action.kind == "dispatch" then
		local ref = (action.ref and action.ref ~= "") and action.ref or "main"
		return ("dispatch '%s' on %s @ %s?"):format(target.name or target.workflow_id or "workflow", repo, ref)
	end
	if action.kind == "rerun" then
		return ("rerun #%s on %s?"):format(tostring(target.run_id), repo)
	end
	if action.kind == "rerun_failed" then
		return ("rerun failed jobs of #%s on %s?"):format(tostring(target.run_id), repo)
	end
	if action.kind == "cancel" then
		return ("cancel run #%s on %s?"):format(tostring(target.run_id), repo)
	end
	return action.kind .. "?"
end

return M
