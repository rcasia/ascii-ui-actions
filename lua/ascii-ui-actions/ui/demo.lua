local BufferLine = require("ascii-ui.buffer.bufferline")
local Segment = require("ascii-ui.buffer.segment")
local ui = require("ascii-ui")
local SELECT = require("ascii-ui.interaction_type").SELECT
local keymap = require("ascii-ui-actions.ui.keymap")
local tokens = require("ascii-ui-actions.ui.tokens")
local useState = ui.hooks.useState

local RUNS = {
	{ status = "completed", conclusion = "success", name = "build", branch = "main", duration = "2m14s" },
	{ status = "completed", conclusion = "failure", name = "test", branch = "feature/x", duration = "12s" },
	{ status = "in_progress", name = "docker", branch = "main", duration = "1h2m3s" },
}
local RIGHT = 40
local NAME_W = 8

local function run_row(r)
	local st = tokens.state(tokens.state_for(r))
	local pad_dur = string.rep(" ", RIGHT - #r.duration - (5 + NAME_W + #r.branch))
	return BufferLine.new(
		Segment:new({ content = " " .. st.glyph, highlight = st.highlight }),
		Segment:new({ content = " " .. r.name .. string.rep(" ", NAME_W - #r.name) .. "  " .. r.branch }),
		Segment:new({ content = pad_dur .. r.duration, highlight = "NonText" })
	)
end

local function help_row(h)
	local pad = string.rep(" ", 10 - #h.keys)
	return BufferLine.new(
		Segment:new({ content = "   " .. h.keys .. pad, highlight = "Comment" }),
		Segment:new({ content = h.desc })
	)
end

local Demo = ui.createComponent("Demo", function(props)
	props = props or {}
	local help_open, setHelpOpen = useState(false)

	local body
	if help_open then
		body = ui.map(keymap.entries, help_row)
	else
		body = ui.map(RUNS, run_row)
	end

	local bar_text = " " .. (keymap.hint():gsub(" %? keys$", "")) .. " "

	local status
	if props.show_error then
		status = BufferLine.new(
			Segment:new({ content = "│ gh not found · gh auth login", highlight = "DiagnosticError" })
		)
	else
		status = BufferLine.new(Segment:new({ content = " fetched 12:04:31", highlight = "NonText" }))
	end

	return {
		BufferLine.new(Segment:new({ content = " ascii-ui-actions" })),
		BufferLine.new(Segment:new({ content = " foo/bar › ci.yml", highlight = "Comment" })),
		body,
		status,
		BufferLine.new(
			Segment:new({ content = bar_text, highlight = "Comment" }),
			Segment:new({
				content = help_open and "? close" or "? keys",
				highlight = "NonText",
				is_focusable = true,
				interactions = {
					[SELECT] = function()
						setHelpOpen(function(prev)
							return not prev
						end)
					end,
				},
			})
		),
	}
end, { show_error = "boolean" })

return Demo
