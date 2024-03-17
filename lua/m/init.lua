-- Define the function to insert the current date
local function insert_date()
	local current_date = os.date("%Y-%m-%d")
	local current_buffer = vim.api.nvim_get_current_buf()
	local current_cursor = vim.api.nvim_win_get_cursor(0)
	local row = current_cursor[1]
	local col = current_cursor[2]
	vim.api.nvim_buf_set_text(
		current_buffer,
		row - 1,
		col,
		row - 1,
		col,
		---@diagnostic disable-next-line: assign-type-mismatch
		{ current_date }
	)
end

-- Create a key mapping to trigger the date insertion
vim.api.nvim_set_keymap("n", "<C-d>", ':lua require("m").insert_date()<CR>', { noremap = true, silent = true })

-- Return the public interface of the plugin
return {
	insert_date = insert_date,
}
