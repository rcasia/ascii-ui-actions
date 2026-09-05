-- scripts/minimal_init.lua
-- Headless testing with mini.test, no user config loaded.

local DEPENDENCIES_DIR = "./.dependencies"

-- Speed up startup
for _, p in ipairs({
	"gzip",
	"zip",
	"zipPlugin",
	"tar",
	"tarPlugin",
	"vimball",
	"vimballPlugin",
	"2html_plugin",
	"matchit",
	"matchparen",
	"netrw",
	"netrwPlugin",
	"netrwSettings",
	"netrwFileHandlers",
	"rrhelper",
	"spellfile_plugin",
	"shada_plugin",
}) do
	vim.g["loaded_" .. p] = 1
end

vim.opt.shortmess:append("I")
vim.opt.swapfile = false
vim.opt.backup = false
vim.opt.writebackup = false

-- ─────────────────────────────────────────────────────────────
-- Ensure dependencies exist (auto-clone if missing)
-- ─────────────────────────────────────────────────────────────
local function ensure_repo(path, url)
	if vim.fn.isdirectory(path) == 0 then
		vim.fn.mkdir(path, "p")
		vim.fn.system({ "git", "clone", "--depth", "1", url, path })
	end
end

ensure_repo(DEPENDENCIES_DIR .. "/mini.nvim", "https://github.com/echasnovski/mini.nvim")
ensure_repo(DEPENDENCIES_DIR .. "/ascii-ui.nvim", "https://github.com/ascii-ui/ascii-ui.nvim")

-- ─────────────────────────────────────────────────────────────
-- Runtime path setup (plugin roots, NOT /lua/ subdirectories)
-- ─────────────────────────────────────────────────────────────
package.path = "./?.lua;./?/init.lua;" .. package.path
vim.opt.runtimepath:append(".")
vim.opt.runtimepath:append(DEPENDENCIES_DIR .. "/mini.nvim")
vim.opt.runtimepath:append(DEPENDENCIES_DIR .. "/ascii-ui.nvim")

-- ─────────────────────────────────────────────────────────────
-- Enable mini.test
-- ─────────────────────────────────────────────────────────────
require("mini.test").setup({
	collect = {
		emulate_busted = true,
		find_files = function()
			return vim.fn.globpath("tests/unit", "**/*_spec.lua", true, true)
		end,
	},
	execute = {
		reporter = require("mini.test").gen_reporter.stdout(),
		stop_on_error = false,
	},
})
