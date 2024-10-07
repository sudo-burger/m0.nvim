local M = {}

---@param txt string The text to show in the popup
---@return boolean success
---@return string? error
function M:popup(txt)
  local win_width = vim.api.nvim_win_get_width(0)
  local win_height = vim.api.nvim_win_get_height(0)

  -- Sanity checks.
  if win_width < 20 or win_height < 20 then
    return false, 'We are in a tight place.'
  end

  local popup_buf_id = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_lines(
    popup_buf_id,
    -2,
    -1,
    false,
    -- If the input contains multiple lines,
    -- split them as required by nvim_buf_get_lines()
    vim.fn.split(txt, '\n', false)
  )
  local win_id = vim.api.nvim_open_win(popup_buf_id, true, {
    relative = 'win',
    row = 5,
    col = 5,
    width = win_width - 10,
    height = win_height - 10,
    style = 'minimal',
    border = 'rounded',
  })
  if win_id == 0 then
    vim.api.nvim_buf_delete(popup_buf_id, {})
    return false, 'Unable to create popup window.'
  end
  --
  -- Bind q to quit popup.
  vim.keymap.set('n', 'q', function()
    vim.api.nvim_win_close(win_id, true)
    vim.api.nvim_buf_delete(popup_buf_id, {})
  end, { buffer = popup_buf_id })
  return true
end

return M
