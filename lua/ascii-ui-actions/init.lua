local config = require("ascii-ui-actions.config")

local M = {}

function M.setup(opts)
	config.setup(opts)
end

function M.open()
	local ui = require("ascii-ui")
	local App = require("ascii-ui-actions.ui.app")
	local title = config.options.title
	ui.mount(function()
		return App({ title = title })
	end)
end

return M
