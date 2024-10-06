require 'm0.message'

---@class M0.VimBuffer
---@field opts M0.Config | nil
---@field buf_id integer | nil
---@field new? fun(self:M0.VimBuffer, opts:table):M0.VimBuffer
---@field get_visual_selection? fun(self:M0.VimBuffer):string[]
---@field get_messages? fun(self:M0.VimBuffer):RawMessage[]
---@field append_lines? fun(self:M0.VimBuffer, lines:string[])
---@field get_last_line? fun(self:M0.VimBuffer):string
---@field set_last_line? fun(self:M0.VimBuffer, txt:string)
---@field open_response? fun(self:M0.VimBuffer)
---@field close_response? fun(self:M0.VimBuffer)
---@field put_response fun(self:M0.VimBuffer, response:string, opts?:table):boolean

---@type M0.VimBuffer
local M = {
  opts = nil,
  buf_id = nil,
}

---@param opts M0.Config The current configuration
---@return M0.VimBuffer
function M:new(opts)
  return setmetatable(
    { buf_id = vim.api.nvim_get_current_buf(), opts = opts },
    { __index = M }
  )
end

function M:put_response(response, opts)
  if not opts or opts.stream == false then
    self:set_last_line(response)
  else
    -- Assume streaming.
    -- Append the delta to the current line.
    self:set_last_line(self:get_last_line() .. response)
  end
  return true
end

---Get the currently selected text.
---@return string[]
function M:get_visual_selection()
  local sline = vim.fn.line 'v'
  local eline = vim.fn.line '.'
  return vim.api.nvim_buf_get_lines(
    self.buf_id,
    math.min(sline, eline) - 1,
    math.max(sline, eline),
    false
  )
end

--- Get messages from current buffer, generating a list of 'messages'.
---@return RawMessage[]
function M:get_messages()
  self.buf_id = vim.api.nvim_get_current_buf()
  ---@type RawMessage[]
  local messages = {}
  local section_mark = self.opts.section_mark
  local conversation = nil

  local mode = vim.api.nvim_get_mode().mode
  -- If we are in visual mode, read the conversation from the visual selection.
  -- Otherwise use the whole current buffer as input.
  if mode == 'v' or mode == 'V' then
    conversation = self:get_visual_selection()
  else
    -- Read the conversation from the current buffer.
    conversation = vim.api.nvim_buf_get_lines(self.buf_id, 0, -1, false)
  end

  local i = 1
  -- Iterate through the conversation.
  while i <= #conversation do
    local message = ''
    -- In conversations, the 'user' and AI take turns.
    -- "Section marks" are used to signal the switches between the two roles.
    while i <= #conversation and conversation[i] ~= section_mark do
      message = message .. conversation[i] .. '\n'
      i = i + 1
    end

    table.insert(messages, message)
    i = i + 1
  end
  return messages
end

--- Append lines to the end of the buffer.
---@param lines string[]
function M:append_lines(lines)
  vim.api.nvim_buf_set_lines(self.buf_id, -1, -1, false, lines)
end

--- Get the last line of the buffer.
---@return string
function M:get_last_line()
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

--- Open/close a response.
--- FIX: the same marker opens/closes sections at the moment.
--- We may want different markers.
function M:open_response()
  self:append_lines { self.opts.section_mark, '' }
end
function M:close_response()
  self:append_lines { self.opts.section_mark, '' }
end

return M
