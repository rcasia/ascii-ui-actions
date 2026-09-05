if vim.g.loaded_ascii_ui_actions then
	return
end
vim.g.loaded_ascii_ui_actions = true

vim.api.nvim_create_user_command("AsciiUiActions", function()
	require("ascii-ui-actions").open()
end, { desc = "Open the ascii-ui-actions floating window" })
