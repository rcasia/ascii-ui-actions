--- Runs view. `RunRow` repeats → component (rule 10). Status glyphs are
--- precomputed by `logic/view_model`; nothing here inlines a color.
local BufferLine = require("ascii-ui.buffer.bufferline")
local common = require("ascii-ui-actions.ui.render.common")
local ui = require("ascii-ui")

local NAME_W = 24
local BRANCH_W = 18
local EVENT_W = 12
local ACTOR_W = 10
local DUR_W = 9

--- One run: [glyph] name branch event actor duration.
local RunRow = ui.createComponent("RunRow", function(props)
	local row = props.row
	return {
		BufferLine.new(
			common.plain(" " .. row.glyph, { highlight = row.highlight }),
			common.focusable(" " .. common.pad(row.name, NAME_W), function()
				props.on_open(props.index)
			end),
			common.plain("  " .. common.pad(row.branch, BRANCH_W)),
			common.plain(common.pad(row.event, EVENT_W), { highlight = "Comment" }),
			common.plain("  " .. common.pad(row.actor, ACTOR_W), { highlight = "NonText" }),
			common.plain(common.rpad(row.duration, DUR_W), { highlight = "NonText" })
		),
	}
end, { row = "table", index = "number", on_open = "function" })

--- The runs list: rows + optional "load more" (pagination lives here).
local RunList = ui.createComponent("RunList", function(props)
	local out = ui.map(props.rows, function(row, index)
		return RunRow({ row = row, index = index, on_open = props.on_open })
	end)
	if props.show_more then
		out[#out + 1] = common.load_more_row(props.on_load_more)
	end
	return out
end, { rows = "table", on_open = "function" })

return { Row = RunRow, List = RunList }
