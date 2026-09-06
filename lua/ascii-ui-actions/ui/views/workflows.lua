--- Workflows view. `WorkflowRow` is a component because it repeats (rule 10):
--- the list maps it, so rows with unchanged data skip re-rendering.
local BufferLine = require("ascii-ui.buffer.bufferline")
local common = require("ascii-ui-actions.ui.render.common")
local ui = require("ascii-ui")

local NAME_W = 20
local UPDATED_W = 8

--- One workflow: [glyph] name path updated. Name is the selectable target.
local WorkflowRow = ui.createComponent("WorkflowRow", function(props)
	local row = props.row
	return {
		BufferLine.new(
			common.plain(" " .. row.glyph, { highlight = row.highlight }),
			common.focusable(" " .. common.pad(row.name, NAME_W), function()
				props.on_open(props.index)
			end),
			common.plain("  " .. row.path, { highlight = "NonText" }),
			common.plain("  " .. common.rpad(row.updated, UPDATED_W), { highlight = "NonText" })
		),
	}
end, { row = "table", index = "number", on_open = "function" })

--- The workflow list: rows + optional "load more".
local WorkflowsList = ui.createComponent("WorkflowsList", function(props)
	local out = ui.map(props.rows, function(row, index)
		return WorkflowRow({ row = row, index = index, on_open = props.on_open })
	end)
	if props.show_more then
		out[#out + 1] = common.load_more_row(props.on_load_more)
	end
	return out
end, { rows = "table", on_open = "function" })

return { Row = WorkflowRow, List = WorkflowsList }
