---@alias M0.VimBufferMode "'chat'" | "'rewrite'"

---@class M0.VimBuffer
---@field is_open boolean
---@field mode? M0.VimBufferMode
---@field opts? M0.Config
---@field buf_id? integer
---@field win_id? integer
---@field cursor table
---@field new fun(self:M0.VimBuffer, opts:table):M0.VimBuffer
---@field get_messages fun(self:M0.VimBuffer):string[]
---@field open_buffer fun(self:M0.VimBuffer, mode:string)
---@field close_buffer fun(self:M0.VimBuffer)
---@field put_response fun(self:M0.VimBuffer, response:string):boolean,string?
---@field private append_section_mark fun(self:M0.VimBuffer)
---@field private get_visual_selection_lines? fun(self:M0.VimBuffer):string[]

---@type M0.VimBuffer
---@diagnostic disable-next-line: missing-fields
local M = {
  is_open = false,
  mode = nil,
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

function M:put_response(txt)
  -- Assumes that self.cursor has been set in open_buffer() before the first
  -- call.

  -- Put the cursor back where it should be, in case it was moved by the user.
  vim.api.nvim_win_set_cursor(self.win_id, self.cursor)

  vim.api.nvim_buf_set_text(
    self.buf_id,
    self.cursor[1] - 1,
    self.cursor[2],
    self.cursor[1] - 1,
    self.cursor[2],
    vim.fn.split(txt, '\n', true)
  )

  -- Prepare for the next write.
  self.cursor = vim.api.nvim_win_get_cursor(self.win_id)
  return true
end

--- Returns 1-indexed values (the first line in the buffer is line 1).
---@return integer startline
---@return integer endline
local function get_visual_selection_line_span()
  local sline = vim.fn.line 'v'
  local eline = vim.fn.line '.'
  return math.min(sline, eline), math.max(sline, eline)
end

---Get the currently selected text.
---@return string[]
local function get_visual_selection_lines(self)
  local startline, endline = get_visual_selection_line_span()
  return vim.api.nvim_buf_get_lines(self.buf_id, startline - 1, endline, false)
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
    conversation = get_visual_selection_lines(self)
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

local function append_section_mark(self)
  -- Line index -1 refers to the index past the end of the buffer.
  vim.api.nvim_buf_set_lines(self.buf_id, -1, -1, false, {
    self.opts.section_mark,
    -- Insert an empty line as placeholder for the new section.
    -- FIXME: the empty string should work here, but it garbles the LLM's response.
    ' ',
  })
end

--- Open/close a response.
function M:open_buffer(mode)
  if self.is_open == true then
    return
  end
  self.is_open = true
  self.mode = mode
  -- Ensure that the response is sent to the win/buf the request originated from.
  self.buf_id = vim.api.nvim_get_current_buf()
  self.win_id = vim.api.nvim_get_current_win()

  if self.mode == 'chat' then
    append_section_mark(self)
    -- Move the cursor to the start of the last line, preparing for text to be
    -- inserted.
    self.cursor = { vim.api.nvim_buf_line_count(self.buf_id), 0 }
  elseif self.mode == 'rewrite' and in_visual_mode() then
    local startline, endline = get_visual_selection_line_span()
    -- Replace the selected line range with an empty line.
    -- This is the placeholder for the rewrite.
    vim.api.nvim_buf_set_lines(
      self.buf_id,
      startline - 1,
      endline,
      false,
      -- FIXME: the empty string works here, but we use a space to be consistent with append_section_mark().
      { ' ' }
    )
    -- Move the cursor to the start of the empty line we just created, preparing
    -- for text to be inserted.
    self.cursor = { startline, 0 }
  else
    return
  end
  vim.api.nvim_win_set_cursor(self.win_id, self.cursor)
end

function M:close_buffer()
  self.is_open = false

  if self.mode == 'chat' then
    append_section_mark(self)
    -- Move cursor to end of document, preparing for the next turn.
    vim.api.nvim_win_set_cursor(
      self.win_id,
      { vim.api.nvim_buf_line_count(self.buf_id), 0 }
    )
  elseif self.mode == 'rewrite' and in_visual_mode() then
    local startline, endline = get_visual_selection_line_span()

    -- Format the text in the range using Vim's built-in formatting
    vim.cmd(string.format('silent %d,%dnormal! gq', startline, endline))

    -- Position cursor at end of formatted text
    vim.api.nvim_win_set_cursor(self.win_id, { endline, 0 })
  end
end

return M
