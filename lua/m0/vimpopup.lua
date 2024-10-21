local M = {}

---@param txt? string | string[] The text to show in the popup
---@param exit_callback? fun()
---@param opts? table
--- Opts:
--- cursor boolean Whether to open the popup at the cursor's position (false).
---@return integer? buffer id
---@return string? error
function M:popup(txt, exit_callback, opts)
  local opts = opts or {}
  -- FIXME: use current position for workarounds when close to border.
  -- local _, _, col , _ = vim.fn.getpos('.')
  local columns = vim.api.nvim_win_get_width(0)
  local lines = vim.api.nvim_win_get_height(0)
  local min_width = opts.min_width or 40
  local min_height = opts.min_height or 15
  local width = opts.cursor and min_width or columns - 10
  local height = opts.cursor and min_height or lines - 10
  local row = opts.cursor and 1 or math.floor((lines - height) / 2)
  local col = opts.cursor and 1 or math.floor((columns - width) / 2)

  -- Sanity checks.
  -- if win_width < min_width or win_height < min_height then
  --   return nil, 'We are in a tight place.'
  -- end

  -- Create an unlisted, 'throwaway' buffer.
  local buf_id = vim.api.nvim_create_buf(false, true)
  if buf_id == 0 then
    return nil, 'Unable to create popup buffer.'
  end

  -- Populate buffer.
  if txt then
    vim.api.nvim_buf_set_lines(
      buf_id,
      -2,
      -1,
      false,
      -- If the input contains multiple lines,
      -- split them as required by nvim_buf_get_lines()
      type(txt) == 'string' and vim.fn.split(txt, '\n', false) or txt
    )
  end

  -- Create the popup.
  local win_id = vim.api.nvim_open_win(buf_id, true, {
    relative = opts.cursor and 'cursor' or 'editor',
    row = row,
    col = col,
    width = width,

    -- width = math.floor(columns / 3),
    -- split = 'right',
    -- win = 0,

    height = height,
    -- FIXME: make these configurable.
    style = 'minimal',
    border = 'rounded',
  })

  if win_id == 0 then
    vim.api.nvim_buf_delete(buf_id, {})
    return nil, 'Unable to create popup window.'
  end

  -- Set options.
  -- FIXME: 'tw' doesn't achieve the desired line wrapping.
  -- vim.api.nvim_set_option_value('tw', width, { buf = buf_id })

  -- Bind q to quit popup.
  -- FIXME: document.
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
