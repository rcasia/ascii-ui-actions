local health = vim.health or require("health")

local function check_nvim_version()
	if vim.fn.has("nvim-0.10") == 1 then
		health.ok("Neovim >= 0.10")
	else
		health.error("Neovim 0.10 or above is required", { "Install a newer version of Neovim." })
	end
end

local function check_ascii_ui()
	local ok = pcall(require, "ascii-ui")
	if ok then
		health.ok("'ascii-ui' is available")
	else
		health.error("'ascii-ui.nvim' is not installed", {
			"Install it: https://github.com/ascii-ui/ascii-ui.nvim",
		})
	end
end

local function check_gh()
	if vim.fn.executable("gh") == 0 then
		health.error("'gh' executable not found", {
			"Install the GitHub CLI: https://cli.github.com/",
		})
		return
	end
	health.ok("'gh' executable found")

	local out = vim.fn.system({ "gh", "auth", "status" })
	local code = vim.v.shell_error
	if code == 0 then
		health.ok("'gh' is authenticated")
	else
		local hint = out:match("[^\n]+") or "run: gh auth login"
		health.error("'gh' is not authenticated", { hint, "Run: gh auth login" })
	end
end

return {
	check = function()
		check_nvim_version()
		check_ascii_ui()
		check_gh()
	end,
}
