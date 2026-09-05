--- The one keymap table. The hint bar and the `?` overlay both read this,
--- so bindings, bar text and docs cannot drift apart.
local M = {}

---@type { keys: string, desc: string, hint?: boolean }[]
M.entries = {
	{ keys = "j/k", desc = "move", hint = true },
	{ keys = "<CR>", desc = "open", hint = true },
	{ keys = "h", desc = "back", hint = true },
	{ keys = "r", desc = "refresh", hint = true },
	{ keys = "R", desc = "rerun run" },
	{ keys = "F", desc = "rerun failed jobs" },
	{ keys = "c", desc = "cancel in-progress run" },
	{ keys = "o", desc = "open in browser" },
	{ keys = "y/n", desc = "confirm / abort action" },
	{ keys = "<ESC>", desc = "close overlay" },
	{ keys = "q", desc = "quit", hint = true },
	{ keys = "?", desc = "keys", hint = true },
}

--- Compact hint-bar text from the entries flagged `hint`.
---@return string
function M.hint()
	local parts = vim.iter(M.entries)
		:filter(function(e)
			return e.hint == true
		end)
		:map(function(e)
			return e.keys .. " " .. e.desc
		end)
		:totable()
	return table.concat(parts, "  ")
end

return M
