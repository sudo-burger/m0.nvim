local M = {}

---@param txt string | string[] The text to show in the popup
---@param exit_callback? fun()
---@param opts? table
---@return integer? buffer id
---@return string? error
function M:popup(txt, exit_callback, opts)
  local opts = opts or {}
  local win_width = vim.api.nvim_win_get_width(0)
  local win_height = vim.api.nvim_win_get_height(0)

  -- Sanity checks.
  if win_width < 20 or win_height < 20 then
    return nil, 'We are in a tight place.'
  end

  local buf_id = vim.api.nvim_create_buf(false, true)
  if buf_id == 0 then
    return nil, 'Unable to create popup buffer.'
  end
  vim.api.nvim_buf_set_lines(
    buf_id,
    -2,
    -1,
    false,
    -- If the input contains multiple lines,
    -- split them as required by nvim_buf_get_lines()
    type(txt) == 'string' and vim.fn.split(txt, '\n', false) or txt
  )
  local win_id = vim.api.nvim_open_win(buf_id, true, {
    relative = opts.cursor and 'cursor' or 'win',
    row = opts.cursor and 1 or 5,
    col = opts.cursor and 1 or 5,
    width = opts.cursor and 30 or win_width - 10,
    height = opts.cursor and 10 or win_height - 10,
    -- FIXME: make these configurable.
    style = 'minimal',
    border = 'rounded',
  })
  if win_id == 0 then
    vim.api.nvim_buf_delete(buf_id, {})
    return nil, 'Unable to create popup window.'
  end
  --
  -- Bind q to quit popup.
  vim.keymap.set('n', 'q', function()
    vim.api.nvim_win_close(win_id, true)
    vim.api.nvim_buf_delete(buf_id, {})
    if exit_callback then
      exit_callback()
    end
  end, { buffer = buf_id })
  return buf_id
end

return M
