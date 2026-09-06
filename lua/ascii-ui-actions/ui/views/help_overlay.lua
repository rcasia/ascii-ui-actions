--- The `?` keys overlay: one `HelpEntryRow` per keymap entry (repeated →
--- component, rule 10). Rendered from `ui/keymap.lua` so the overlay can never
--- drift from the real bindings.
local BufferLine = require("ascii-ui.buffer.bufferline")
local common = require("ascii-ui-actions.ui.render.common")
local keymap = require("ascii-ui-actions.ui.keymap")
local ui = require("ascii-ui")

local HelpEntryRow = ui.createComponent("HelpEntryRow", function(props)
	local entry = props.entry
	return {
		BufferLine.new(
			common.plain(
				"   " .. entry.keys .. string.rep(" ", math.max(0, 10 - #entry.keys)),
				{ highlight = "Comment" }
			),
			common.plain(entry.desc)
		),
	}
end, { entry = "table" })

local HelpOverlay = ui.createComponent("HelpOverlay", function()
	return ui.map(keymap.entries, function(entry)
		return HelpEntryRow({ entry = entry })
	end)
end)

return { Row = HelpEntryRow, Overlay = HelpOverlay }
