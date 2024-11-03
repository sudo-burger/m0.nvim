-- Sidebar module.
--

---@class M0.Sidebar
local M = {}

M.state = {
  open = false,
  width = 60,
  buf_id = nil,
  win_id = nil,
}

function M:toggle_sidebar()
  if self.state.open then
    self:close_sidebar()
  else
    self:open_sidebar()
  end
end

function M:open_sidebar()
  if self.state.open then
    return
  end

  -- Save current window
  local current_win = vim.api.nvim_get_current_win()

  -- Create new window on the right
  vim.cmd('botright vertical ' .. self.state.width .. 'split')
  self.state.win_id = vim.api.nvim_get_current_win()

  -- Create or set buffer
  if
    not self.state.buf_id or not vim.api.nvim_buf_is_valid(self.state.buf_id)
  then
    self.state.buf_id = vim.api.nvim_create_buf(false, true)
    vim.api.nvim_buf_set_name(self.state.buf_id, 'M0 Chat')
  end
  vim.api.nvim_win_set_buf(self.state.win_id, self.state.buf_id)

  -- Set buffer options
  vim.api.nvim_set_option_value(
    'buftype',
    'nofile',
    { buf = self.state.buf_id }
  )
  vim.api.nvim_set_option_value('swapfile', false, { buf = self.state.buf_id })
  vim.api.nvim_set_option_value(
    'bufhidden',
    'hide',
    { buf = self.state.buf_id }
  )

  -- Set window options
  vim.api.nvim_set_option_value('wrap', true, { win = self.state.win_id })
  vim.api.nvim_set_option_value('cursorline', true, { win = self.state.win_id })

  -- Return to original window
  vim.api.nvim_set_current_win(current_win)

  self.state.open = true
end

function M:close_sidebar()
  if not self.state.open then
    return
  end

  if self.state.win_id and vim.api.nvim_win_is_valid(self.state.win_id) then
    vim.api.nvim_win_close(self.state.win_id, true)
  end

  self.state.open = false
  self.state.win_id = nil
end

function M:update_sidebar()
  if not self.state.open or not self.state.buf_id then
    return
  end

  local lines = self:get_chat_lines()
  vim.api.nvim_buf_set_lines(self.state.buf_id, 0, -1, false, lines)
end

function M:get_chat_lines()
  -- Implement this to return the current chat as an array of lines
  -- This is a placeholder implementation
  return { 'Chat line 1', 'Chat line 2', 'Chat line 3' }
end

return M
