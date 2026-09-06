local config = require("ascii-ui-actions.config")

local M = {}

function M.setup(opts)
	config.setup(opts)
end

function M.open()
	local ui = require("ascii-ui")
	local Dashboard = require("ascii-ui-actions.ui.app")
	local o = config.options
	ui.mount(function()
		return Dashboard({
			title = o.title,
			repo = o.repo,
			refresh_interval = o.refresh_interval,
			cwd = vim.fn.getcwd(),
		})
	end)
end

return M
