--- Shared rows for every view (UI structure contract from `define-minimal-ui-structure`):
--- title, breadcrumb, loading/empty/error rows, status line, hint bar and the
--- `?` overlay. Glyphs and highlights come only from `ui/tokens.lua`; keys
--- only from `ui/keymap.lua`.
local BufferLine = require("ascii-ui.buffer.bufferline")
local Segment = require("ascii-ui.buffer.segment")
local SELECT = require("ascii-ui.interaction_type").SELECT
local keymap = require("ascii-ui-actions.ui.keymap")

local M = {}

--- First two rows are always title + breadcrumb; content starts at row 3.
M.HEADER_ROWS = 2

--- Left-justify `s` in a `w`-column field (shared column alignment).
---@param s string
---@param w integer
---@return string
function M.pad(s, w)
	s = s or ""
	return s .. string.rep(" ", math.max(0, w - #s))
end

--- Right-justify `s` in a `w`-column field.
---@param s string
---@param w integer
---@return string
function M.rpad(s, w)
	s = s or ""
	return string.rep(" ", math.max(0, w - #s)) .. s
end

--- A plain (non-focusable) segment.
---@param content string
---@param opts? { highlight?: string, color?: any }
function M.plain(content, opts)
	opts = opts or {}
	return Segment:new({ content = content, highlight = opts.highlight, color = opts.color })
end

--- A focusable segment carrying a SELECT handler (rows call this per render
--- so a fresh Segment/interaction is built — never reused across renders).
---@param content string
---@param on_select fun()
---@param opts? { highlight?: string }
function M.focusable(content, on_select, opts)
	opts = opts or {}
	return Segment:new({
		content = content,
		highlight = opts.highlight,
		is_focusable = true,
		interactions = { [SELECT] = on_select },
	})
end

---@param title string
function M.title_row(title)
	return BufferLine.new(Segment:new({ content = " " .. (title or "ascii-ui-actions") }))
end

---@param crumb string
function M.breadcrumb_row(crumb)
	return BufferLine.new(Segment:new({ content = crumb or "", highlight = "Comment" }))
end

function M.loading_row(text)
	return BufferLine.new(Segment:new({ content = " " .. (text or "loading…"), highlight = "NonText" }))
end

---@param msg string
function M.empty_row(msg)
	return BufferLine.new(Segment:new({ content = " " .. msg, highlight = "NonText" }))
end

--- Error rows: message plus hint (spec: never a blank screen).
---@param err { kind: string, message: string, hint?: string }
---@return table[] BufferLine[]
function M.error_rows(err)
	local rows =
		{ BufferLine.new(Segment:new({ content = "│ " .. (err.message or "error"), highlight = "DiagnosticError" })) }
	if err.hint then
		table.insert(rows, BufferLine.new(Segment:new({ content = "│ " .. err.hint, highlight = "DiagnosticError" })))
	end
	return rows
end

--- Status line: one row below the content region.
---@param line { text: string, kind: "ok"|"error"|"warn"|"neutral" }
function M.status_row(line)
	local hl = ({
		ok = "DiagnosticOk",
		error = "DiagnosticError",
		warn = "DiagnosticWarn",
		neutral = "NonText",
	})[line.kind]
	return BufferLine.new(Segment:new({ content = line.text, highlight = hl }))
end

--- The bottom hint bar: generated from the keymap table, plus the focusable
--- `? keys`/`? close` toggle.
---@param on_toggle_help fun()
---@param help_open boolean
function M.hint_row(on_toggle_help, help_open)
	local bar_text = " " .. (keymap.hint():gsub(" %? keys$", "")) .. " "
	return BufferLine.new(
		Segment:new({ content = bar_text, highlight = "Comment" }),
		Segment:new({
			content = help_open and "? close" or "? keys",
			highlight = "NonText",
			is_focusable = true,
			interactions = { [SELECT] = on_toggle_help },
		})
	)
end

---@param help { keys: string, desc: string, hint?: boolean }
local function help_row(help)
	local pad = string.rep(" ", 10 - #help.keys)
	return BufferLine.new(
		Segment:new({ content = "   " .. help.keys .. pad, highlight = "Comment" }),
		Segment:new({ content = help.desc })
	)
end

--- The `?` overlay: the full keymap listing.
---@return table[] BufferLine[]
function M.help_rows()
	local rows = {}
	for _, entry in ipairs(keymap.entries) do
		table.insert(rows, help_row(entry))
	end
	return rows
end

--- Confirmation row pair shown while `pending_action` awaits y/n.
---@param prompt string e.g. "rerun #123 on o/r?"
---@param on_confirm fun()
---@param on_abort fun()
---@return table[] BufferLine[]
function M.confirm_rows(prompt, on_confirm, on_abort)
	return {
		BufferLine.new(Segment:new({ content = " " .. prompt, highlight = "DiagnosticWarn" })),
		BufferLine.new(
			Segment:new({ content = " " }),
			Segment:new({
				content = "[y] confirm",
				is_focusable = true,
				interactions = { [SELECT] = on_confirm },
			}),
			Segment:new({ content = "  " }),
			Segment:new({
				content = "[n] abort",
				is_focusable = true,
				interactions = { [SELECT] = on_abort },
			})
		),
	}
end

--- "load more" row for capped lists (spec: explicit row, never silent).
---@param on_load_more fun()
function M.load_more_row(on_load_more)
	return BufferLine.new(Segment:new({
		content = "  … load more",
		highlight = "NonText",
		is_focusable = true,
		interactions = { [SELECT] = on_load_more },
	}))
end

return M
