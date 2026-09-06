--- Test helper: render a component *with props* through `ascii-ui.testing`.
--- `testing.render` calls the component with no args, so we wrap it in a
--- uniquely-named component that closes over the props (mini.test runs every
--- spec in one nvim process, hence the shared counter for unique names).
local testing = require("ascii-ui.testing")
local ui = require("ascii-ui")

local M = {}
local counter = 0

---@param Component function a createComponent result
---@param props? table
---@return ascii-ui.testing.Screen
function M.render(Component, props)
	counter = counter + 1
	local Wrap = ui.createComponent("TestWrap" .. counter, function()
		return Component(props or {})
	end)
	return testing.render(Wrap)
end

return M
