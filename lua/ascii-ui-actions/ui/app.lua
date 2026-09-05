local ui = require("ascii-ui")

local Paragraph = ui.components.Paragraph
local Button = ui.components.Button
local Row = ui.layout.Row
local useState = ui.hooks.useState

local App = ui.createComponent("AsciiUiActionsApp", function(props)
	props = props or {}
	local count, setCount = useState(0)

	return {
		Paragraph({ content = props.title or "ascii-ui-actions" }),
		Paragraph({ content = "count: " .. count }),
		Row(
			Button({
				label = "+1",
				on_press = function()
					setCount(function(prev)
						return prev + 1
					end)
				end,
			}),
			Button({
				label = "reset",
				on_press = function()
					setCount(0)
				end,
			})
		),
		Paragraph({ content = "q to close" }),
	}
end, { title = "string" })

return App
