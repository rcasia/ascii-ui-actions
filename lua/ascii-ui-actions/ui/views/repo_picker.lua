--- Repo picker: an `Input` (search or manual owner/repo) plus result rows.
--- `SearchResultRow` repeats → component (rule 10). The field is uncontrolled:
--- the query only matters at submit, so App holds no per-keystroke state.
local BufferLine = require("ascii-ui.buffer.bufferline")
local common = require("ascii-ui-actions.ui.render.common")
local ui = require("ascii-ui")
local Input = ui.components.Input

local SearchResultRow = ui.createComponent("SearchResultRow", function(props)
	local result = props.result
	return {
		BufferLine.new(common.focusable(" " .. result.fullName, function()
			props.on_pick(props.index)
		end)),
	}
end, { result = "table", index = "number", on_pick = "function" })

local RepoPicker = ui.createComponent("RepoPicker", function(props)
	local out = {
		BufferLine.new(
			common.plain(" no repository detected — type owner/repo or a search term", { highlight = "Comment" })
		),
		Input({
			placeholder = "owner/repo",
			on_submit = props.on_submit,
		}),
		BufferLine.new(common.plain(" ")),
	}
	local results = props.results or {}
	if props.searching then
		out[#out + 1] = common.loading_row("searching…")
	elseif #results > 0 then
		out = vim.list_extend(
			out,
			ui.map(results, function(result, index)
				return SearchResultRow({ result = result, index = index, on_pick = props.on_pick })
			end)
		)
	end
	return out
end, { results = "table", on_pick = "function", on_submit = "function" })

return { Row = SearchResultRow, View = RepoPicker }
