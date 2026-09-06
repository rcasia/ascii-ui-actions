local M = {}

M.defaults = {
	title = "ascii-ui-actions",
	--- Default repository as "owner/name". When nil the dashboard detects
	--- the repo from the current project's `origin` remote, then falls back
	--- to an interactive picker.
	repo = nil,
	--- Auto-refresh interval in seconds for the current view. 0 disables it.
	refresh_interval = 30,
}

M.options = M.defaults

function M.setup(overrides)
	M.options = vim.tbl_deep_extend("force", {}, M.defaults, overrides or {})
end

return M
