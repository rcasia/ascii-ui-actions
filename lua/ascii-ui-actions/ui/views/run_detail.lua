--- Run detail view. Metadata (`MetaRow`) and jobs (`JobRow`) both repeat, so
--- each is a component the list maps (rule 10). A static spacer line divides
--- the two blocks.
local BufferLine = require("ascii-ui.buffer.bufferline")
local common = require("ascii-ui-actions.ui.render.common")
local ui = require("ascii-ui")

local LABEL_W = 9
local NAME_W = 28
local DUR_W = 9

local MetaRow = ui.createComponent("MetaRow", function(props)
	local entry = props.entry
	return {
		BufferLine.new(
			common.plain("   " .. common.pad(entry.label, LABEL_W), { highlight = "Comment" }),
			common.plain(entry.value)
		),
	}
end, { entry = "table" })

local JobRow = ui.createComponent("JobRow", function(props)
	local job = props.job
	return {
		BufferLine.new(
			common.plain(" " .. job.glyph, { highlight = job.highlight }),
			common.plain(" " .. common.pad(job.name, NAME_W)),
			common.plain(common.rpad(job.duration, DUR_W), { highlight = "NonText" })
		),
	}
end, { job = "table" })

local RunDetailView = ui.createComponent("RunDetail", function(props)
	local out = ui.map(props.meta, function(entry)
		return MetaRow({ entry = entry })
	end)
	out[#out + 1] = BufferLine.new(common.plain(" "))
	out = vim.list_extend(
		out,
		ui.map(props.jobs, function(job)
			return JobRow({ job = job })
		end)
	)
	if props.show_more then
		out[#out + 1] = common.load_more_row(props.on_load_more)
	end
	return out
end, { meta = "table", jobs = "table" })

return { MetaRow = MetaRow, JobRow = JobRow, View = RunDetailView }
