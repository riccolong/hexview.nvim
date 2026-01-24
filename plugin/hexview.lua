if vim.g.loaded_hexview then
	return
end
vim.g.loaded_hexview = true

local hexview = require("hexview")

hexview.setup()

vim.api.nvim_create_user_command("Hex", function()
	hexview.enable()
end, {})

vim.api.nvim_create_user_command("UnHex", function()
	hexview.disable()
end, {})
