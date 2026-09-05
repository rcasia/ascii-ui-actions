--- The entire state palette in one place: glyphs + theme-aware highlight
--- groups. Views read states from here — never inline glyphs or hex.
local M = {}

M.states = {
	success = { glyph = "✓", highlight = "DiagnosticOk" },
	failure = { glyph = "✗", highlight = "DiagnosticError" },
	running = { glyph = "●", highlight = "DiagnosticInfo" },
	queued = { glyph = "○", highlight = "DiagnosticWarn" },
	cancelled = { glyph = "⊘", highlight = "Comment" },
	neutral = { glyph = " ", highlight = nil },
}

---@param run { status: string, conclusion?: string }
---@return string
function M.state_for(run)
	if run.status == "completed" then
		if run.conclusion == "success" then
			return "success"
		elseif run.conclusion == "cancelled" then
			return "cancelled"
		elseif run.conclusion == "skipped" then
			return "neutral"
		end
		return "failure"
	end
	if run.status == "in_progress" then
		return "running"
	end
	return "queued"
end

---@param key string
function M.state(key)
	local entry = M.states[key]
	if not entry then
		error(("ui.tokens: unknown state '%s'"):format(tostring(key)))
	end
	return entry
end

return M
