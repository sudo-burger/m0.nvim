---@class M0.VimBuffer
---@field opts M0.Config | nil
---@field buf_id integer
---@field new? fun(self:M0.VimBuffer, opts:table):M0.VimBuffer
---@field get_visual_selection_lines? fun(self:M0.VimBuffer):string[]
---@field get_messages? fun(self:M0.VimBuffer):string[]
---@field open_buffer? fun(self:M0.VimBuffer, mode:string)
---@field close_buffer? fun(self:M0.VimBuffer, mode:string)
---@field rewrite? fun(self:M0.VimBuffer, response:string, opts?:table):boolean,string?
---@field put_response? fun(self:M0.VimBuffer, response:string, opts?:table):boolean
---@field insert_lines? fun(self:M0.VimBuffer, lines:string[], opts?:table)
---@field get_last_line? fun(self:M0.VimBuffer):string
---@field set_last_line? fun(self:M0.VimBuffer, txt:string)

---@type M0.VimBuffer
local M = {
  opts = nil,
  buf_id = 0,
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
    -- Not streaming, so getting whole lines.
    self:set_last_line(response)
  else
    -- Streaming, so getting partial lines.
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
  -- Streaming, so getting partial lines.
  vim.api.nvim_put(vim.fn.split(txt, '\n', true), 'c', true, true)
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

--- Insert lines, by default at end of the buffer.
---@param lines string[]
function M:insert_lines(lines, opts)
  local start_line = -1
  local end_line = -1

  if opts and opts.start_line and opts.end_line then
    start_line = opts.start_line
    end_line = opts.end_line
  end
  vim.api.nvim_buf_set_lines(self.buf_id, start_line, end_line, false, lines)
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
function M:open_buffer(mode)
  if mode == 'chat' then
    self:insert_lines { self.opts.section_mark, '' }
  elseif mode == 'rewrite' and in_visual_mode() then
    local startline, endline = get_visual_selection_line_span()
    -- Replace the visually selected line range with an empty line.
    -- This is the placeholder for the rewrite.
    vim.api.nvim_buf_set_lines(self.buf_id, startline, endline, false, { '' })
  end
end

function M:close_buffer(mode)
  if mode == 'chat' then
    self:insert_lines { self.opts.section_mark, '' }
  end
end

return M
