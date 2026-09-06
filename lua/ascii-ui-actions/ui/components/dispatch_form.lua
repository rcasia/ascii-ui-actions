--- workflow_dispatch prompt: a ref field + confirm/abort. The draft ref is
--- owned by this form (App only decides whether it is shown); `on_submit`
--- fires only on explicit confirm, and `on_abort` dismisses without a call.
local BufferLine = require("ascii-ui.buffer.bufferline")
local Segment = require("ascii-ui.buffer.segment")
local ui = require("ascii-ui")
local SELECT = require("ascii-ui.interaction_type").SELECT
local Input = ui.components.Input
local useState = ui.hooks.useState

return ui.createComponent("DispatchForm", function(props)
	local ref, set_ref = useState(props.initial_ref or "main")

	return {
		-- Input renders its own BufferLine row; it cannot nest inside one.
		BufferLine.new(Segment:new({ content = " " .. props.workflow_name .. " · ref:", highlight = "Comment" })),
		Input({
			initial_value = ref,
			on_change = set_ref,
			on_submit = function(v)
				props.on_submit(v)
			end,
		}),
		BufferLine.new(
			Segment:new({ content = " " }),
			Segment:new({
				content = "[y] dispatch",
				is_focusable = true,
				interactions = {
					[SELECT] = function()
						props.on_submit(ref)
					end,
				},
			}),
			Segment:new({ content = "  " }),
			Segment:new({
				content = "[n] cancel",
				is_focusable = true,
				interactions = {
					[SELECT] = function()
						props.on_abort()
					end,
				},
			})
		),
	}
end, { workflow_name = "string", initial_ref = "string", on_submit = "function", on_abort = "function" })
