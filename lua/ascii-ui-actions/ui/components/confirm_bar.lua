--- Inline confirmation bar (pending_action in `confirm` state). A one-off
--- pair of rows (prompt + [y]/[n]), so it reuses the pure `render/common`
--- builder instead of inlining markup. [y]/[n] are focusable, so confirming
--- works with mouse and keyboard.
local common = require("ascii-ui-actions.ui.render.common")
local ui = require("ascii-ui")

return ui.createComponent("ConfirmBar", function(props)
	return common.confirm_rows(props.prompt, props.on_confirm, props.on_abort)
end, { prompt = "string", on_confirm = "function", on_abort = "function" })
