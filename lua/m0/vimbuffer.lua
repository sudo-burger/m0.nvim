require 'm0.message'

---@class VimBuffer
---@field opts? Config
---@field buf_id? integer
---@field new? fun(self:VimBuffer, opts:table):VimBuffer
---@field get_visual_selection? fun(self:VimBuffer):table<string>
---@field get_messages? fun(self:VimBuffer):table<string>
---@field append_lines? fun(self:VimBuffer, lines:string[])
---@field get_last_line? fun(self:VimBuffer):string
---@field set_last_line? fun(self:VimBuffer, txt:string)
---@field open_section? fun(self:VimBuffer)
---@field close_section? fun(self:VimBuffer)

---@type VimBuffer
local M = {}

---@param opts Config The current configuration
---@return VimBuffer
function M:new(opts)
  return setmetatable(
    { buf_id = vim.api.nvim_get_current_buf(), opts = opts },
    { __index = M }
  )
end

---Get the currently selected text.
---@return table selected An array of lines.
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

--- Get messages from current buffer.
--- Transform the chat text into a list of 'messages',
--- with format: [{ role = <user|assistant>, content = <str> }].
--- This is the format used by the OpenAI and Anthropic APIs.
function M:get_messages()
  self.buf_id = vim.api.nvim_get_current_buf()
  local messages = {}
  local section_mark = self.opts.section_mark
  local conversation = nil

  local mode = vim.api.nvim_get_mode().mode
  if mode == 'v' or mode == 'V' then
    -- Read the conversation from the visual selection.
    conversation = self:get_visual_selection()
  else
    -- Read the conversation from the current buffer.
    conversation = vim.api.nvim_buf_get_lines(self.buf_id, 0, -1, false)
  end

  -- In conversations, the 'user' and 'assistant' take turns.
  -- "Section marks" are used to signal the switches between the two roles.
  -- Assume the first message to be the user's.
  local role = 'user'
  local i = 1
  -- Iterate through the conversation.
  while i <= #conversation do
    -- When meeting a section mark, switch roles.
    if conversation[i] == section_mark then
      -- Switch role.
      role = role == 'user' and 'assistant' or 'user'
      i = i + 1
    end

    -- Build a message for the current role.
    local message = { role = role, content = '' }
    while i <= #conversation and conversation[i] ~= section_mark do
      message.content = message.content .. conversation[i] .. '\n'
      i = i + 1
    end

    table.insert(messages, message)
  end
  return messages
end

function M:append_lines(lines)
  vim.api.nvim_buf_set_lines(self.buf_id, -1, -1, false, lines)
end

function M:get_last_line()
  return table.concat(vim.api.nvim_buf_get_lines(self.buf_id, -2, -1, false))
end

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

function M:open_section()
  self:append_lines { self.opts.section_mark, '' }
end

function M:close_section()
  self:append_lines { self.opts.section_mark, '' }
end

return M
