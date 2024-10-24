---@class M0.VimBuffer
---@field opts? M0.Config
---@field buf_id? integer
---@field win_id? integer
---@field cursor? table
---@field new? fun(self:M0.VimBuffer, opts:table):M0.VimBuffer
---@field get_visual_selection_lines? fun(self:M0.VimBuffer):string[]
---@field get_messages? fun(self:M0.VimBuffer):string[]
---@field open_buffer? fun(self:M0.VimBuffer, mode:string)
---@field close_buffer? fun(self:M0.VimBuffer, mode:string)
---@field rewrite? fun(self:M0.VimBuffer, response:string, opts?:table):boolean,string?
---@field put_response? fun(self:M0.VimBuffer, response:string, opts?:table):boolean
---@field append_section_mark? fun(self:M0.VimBuffer)
---@field get_last_line? fun(self:M0.VimBuffer):string
---@field set_last_line? fun(self:M0.VimBuffer, txt:string)

---@type M0.VimBuffer
local M = {
  opts = nil,
  win_id = nil,
  buf_id = nil,
  cursor = { nil, nil },
}

---@param opts M0.Config The current configuration
---@return M0.VimBuffer
function M:new(opts)
  return setmetatable({
    buf_id = vim.api.nvim_get_current_buf(),
    win_id = vim.api.nvim_get_current_win(),
    opts = opts,
  }, { __index = M })
end

-- FIXME: we could probably remove some code and merge put_response() and rewrite(). They become similar if using self.cursor.
function M:put_response(response, opts)
  -- This method assumes that 'open_buffer()' has appended an empty line
  -- to the end of the buffer.
  if not opts or opts.stream == false then
    -- Not streaming, so the response consists of full lines.
    self:set_last_line(response)
  else
    -- Streaming, so the response consists of partial lines.
    self:set_last_line(self:get_last_line() .. response)
  end
  return true
end

---@return integer startline
---@return integer endline
local function get_visual_selection_line_span()
  local sline = vim.fn.line 'v'
  local eline = vim.fn.line '.'
  return math.min(sline, eline) - 1, math.max(sline, eline)
end

---Get the currently selected text.
---@return string[]
function M:get_visual_selection_lines()
  local startline, endline = get_visual_selection_line_span()
  return vim.api.nvim_buf_get_lines(self.buf_id, startline, endline, false)
end

--- Returns true if we are in visual mode, otherwise false.
---@return boolean
local function in_visual_mode()
  local mode = vim.api.nvim_get_mode().mode
  if mode == 'v' or mode == 'V' then
    return true
  end
  return false
end

function M:rewrite(txt)
  -- Assumes that self.cursor has been set in open_buffer().
  -- Streaming, so getting partial lines.
  vim.api.nvim_buf_set_text(
    self.buf_id,
    self.cursor[1] - 1,
    self.cursor[2],
    self.cursor[1] - 1,
    self.cursor[2],
    vim.fn.split(txt, '\n', true)
  )

  -- Prepare for the next partial line, if any.
  self.cursor = vim.api.nvim_win_get_cursor(self.win_id)
  return true
end

---Get messages from current buffer, generating a list of 'messages'.
---@return string[]
function M:get_messages()
  self.buf_id = vim.api.nvim_get_current_buf()
  local messages = {}
  local section_mark = self.opts.section_mark
  local conversation = nil

  -- If we are in visual mode, read the conversation from the visual selection.
  -- Otherwise use the whole current buffer as input.
  if in_visual_mode() then
    conversation = self:get_visual_selection_lines()
  else
    conversation = vim.api.nvim_buf_get_lines(self.buf_id, 0, -1, false)
  end

  -- Iterate through the conversation lines, transforming the raw text into
  -- a list of messages.
  local i = 1
  while i <= #conversation do
    local message = ''
    -- "Section marks" are used to signal the switches between the turns.
    -- Add everything up to the next section mark to the current message.
    while i <= #conversation and conversation[i] ~= section_mark do
      message = message .. conversation[i] .. '\n'
      i = i + 1
    end

    table.insert(messages, message)
    i = i + 1
  end
  return messages
end

--- Get the last line of the buffer.
---@return string
function M:get_last_line()
  -- Neovim manual: ... to get the last element use start=-2 and end=-1.
  return table.concat(vim.api.nvim_buf_get_lines(self.buf_id, -2, -1, false))
end

--- Replace the last line of the buffer with the given text.
---@param txt string
function M:set_last_line(txt)
  vim.api.nvim_buf_set_lines(
    self.buf_id,
    -2,
    -1,
    false,
    -- If the input contains multiple lines,
    -- split them as required by nvim_buf_get_lines()
    vim.fn.split(txt, '\n', true)
  )
end

function M:append_section_mark()
  -- Line index -1 refers to the index past the end of the buffer.
  vim.api.nvim_buf_set_lines(
    self.buf_id,
    -1,
    -1,
    false,
    { self.opts.section_mark, '' }
  )
end

--- Open/close a response.
function M:open_buffer(mode)
  -- Ensure that the response is sent to the win/buf the request originated from.
  self.buf_id = vim.api.nvim_get_current_buf()
  self.win_id = vim.api.nvim_get_current_win()

  if mode == 'chat' then
    self:append_section_mark()
  elseif mode == 'rewrite' and in_visual_mode() then
    local startline, endline = get_visual_selection_line_span()
    -- Replace the selected line range with an empty line.
    -- This is the placeholder for the rewrite.
    vim.api.nvim_buf_set_lines(self.buf_id, startline, endline, false, { '' })
    -- Move the cursor to the empty line we just created, preparing for
    -- text to be inserted.
    self.cursor = { startline + 1, 0 }
    vim.api.nvim_win_set_cursor(self.win_id, self.cursor)
  end
end

function M:close_buffer(mode)
  if mode == 'chat' then
    self:append_section_mark()
    -- Move cursor to end of document.
    vim.api.nvim_win_set_cursor(
      self.win_id,
      { vim.api.nvim_buf_line_count(self.buf_id), 0 }
    )
  elseif mode == 'rewrite' and in_visual_mode() then
    -- FIXME: wrap the visual selection, as if using 'gq'.
    -- Get the line range that was originally selected
    local startline, endline = get_visual_selection_line_span()

    -- Format the text in the range using Vim's built-in formatting
    vim.cmd(string.format('silent %d,%dnormal! gw', startline, endline))

    -- -- Exit visual mode to return to normal mode
    -- vim.cmd(
    --   'normal! ' .. vim.api.nvim_replace_termcodes('<Esc>', true, false, true)
    -- )
    --
    -- -- Position cursor at start of formatted text
    -- vim.api.nvim_win_set_cursor(self.win_id, { startline + 1, 0 })
  end
end

return M
