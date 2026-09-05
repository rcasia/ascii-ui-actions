local M = {}

M.defaults = {
	title = "ascii-ui-actions",
}

M.options = M.defaults

function M.setup(overrides)
	M.options = vim.tbl_deep_extend("force", {}, M.defaults, overrides or {})
end

return M
