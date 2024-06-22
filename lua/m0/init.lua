---@class Backend
---@field opts BackendOptions
---@field run fun(): nil

---@class State
---@field backend Backend?
---@field prompt string?
---@field prompt_name string?

---@type Message
Message = require 'm0.message'

---@type APIFactory
local APIFactory = require 'm0.apifactory'

---@type Utils
local Utils = require 'm0.utils'

local M = {
  ---@type State
  State = {},
  ---@type Config
  Config = require 'm0.config',
}
M.__index = M

---@class CurrentBuffer:Message
---@field opts Config
---@field buf_id integer

---@type CurrentBuffer
local CurrentBuffer = {}

---Create a new current buffer.
---@param opts Config The current configuration
---@return Message
function CurrentBuffer:new(opts)
  return setmetatable(
    { buf_id = vim.api.nvim_get_current_buf(), opts = opts },
    { __index = setmetatable(CurrentBuffer, { __index = Message }) }
  )
end

---Get the currently selected text.
---@return table selected An array of lines.
function CurrentBuffer:get_visual_selection()
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
---@return Message[]
function CurrentBuffer:get_messages()
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

function CurrentBuffer:append_lines(lines)
  vim.api.nvim_buf_set_lines(self.buf_id, -1, -1, false, lines)
end

function CurrentBuffer:get_last_line()
  return table.concat(vim.api.nvim_buf_get_lines(self.buf_id, -2, -1, false))
end

function CurrentBuffer:set_last_line(txt)
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

function CurrentBuffer:open_section()
  self:append_lines { self.opts.section_mark, '' }
end

function CurrentBuffer:close_section()
  self:append_lines { self.opts.section_mark, '' }
end

---Returns a table including the backend-specific implementation of the function run().
---
---@param API LLMAPI The API handler.
---@param msg Message The message handler.
---@param opts BackendOptions
---@return Backend
local function make_backend(API, msg, opts)
  return {
    opts = opts,
    -- name = opts.backend_name,
    run = function()
      local body = API:make_body()

      -- Message are specific to each run.
      body.messages = API:get_messages(msg:get_messages())

      local curl_opts = {
        headers = API:make_headers(),
        body = vim.fn.json_encode(body),
      }

      -- Different callbacks needed, depending on whether streaming is enabled or not.
      if opts.stream == true then
        -- The streaming callback appends the reply to the current buffer.
        curl_opts.stream = vim.schedule_wrap(function(err, out, _)
          if err then
            Utils:log_error('Stream error (1): ' .. err)
            return
          end
          local event, d = API:get_delta_text(out)

          if event == 'delta' and d ~= '' then
            -- Add the delta to the current line.
            msg:set_last_line(msg:get_last_line() .. d)
          elseif event == 'other' and d ~= '' then
            -- Could be an error.
            Utils:log_info(d)
          elseif event == 'done' then
            msg:close_section()
          else
            -- Cruft or no data.
            return
          end
        end)
      else
        -- Not streaming.
        -- We append the LLM's reply to the current buffer at one go.
        curl_opts.callback = vim.schedule_wrap(function(out)
          -- Build the reply in the message handler.
          local res = API:get_response_text(out.body)
          msg:set_last_line(res)
          msg:close_section()
        end)
      end

      -- The closing section mark is printed by the curl callbacks.
      msg:open_section()
      local response = require('plenary.curl').post(opts.url, curl_opts)
      if response.status ~= nil and response.status ~= 200 then
        Utils:log_error('API error (1): ' .. vim.inspect(response))
      end
    end,
  }
end

-- Exported functions
-- ------------------

---Select backend interactively.
---@param backend_name string The name of the backend, as found in the user configuration.
---@return nil
function M:M0backend(backend_name)
  local msg = CurrentBuffer:new(self.Config)
  -- Use deepcopy to avoid cluttering the configuration with backend-specific settings.
  local backend_opts = vim.deepcopy(self.Config.backends[backend_name])
  local provider_name = backend_opts.provider
  local provider_opts = vim.deepcopy(self.Config.providers[provider_name])
  local default_opts =
    vim.deepcopy(self.Config.defaults.providers[provider_name])

  if not backend_opts then
    error("Backend '" .. backend_name .. "' not in configuration.")
  end

  if not provider_opts then
    error(
      "Unable to find provider '"
        .. provider_name
        .. "' for backend '"
        .. backend_name
        .. "'."
    )
  end

  -- Merge the defaults, provider opts, and backend opts.
  -- The former are overridden by the latter.
  backend_opts =
    vim.tbl_extend('force', default_opts, provider_opts, backend_opts)

  ---@type LLMAPI
  local API = APIFactory.create(backend_opts.api_type, backend_opts, M.State)

  M.State.backend = make_backend(API, msg, backend_opts)
end

---Select prompt interactively.
---@param prompt_name string
---@return nil
function M:M0prompt(prompt_name)
  if self.Config.prompts[prompt_name] == nil then
    error("Prompt '" .. prompt_name .. "' not in configuration.")
  end
  self.State.prompt_name = prompt_name
  self.State.prompt = self.Config.prompts[prompt_name]
end

--- Run a chat round.
---@return nil
function M:M0chat()
  M.State.backend.run()
end

---Returns printable debug information.
---@return string
function M:debug()
  return 'State:\n'
    .. vim.inspect(self.State)
    .. '\nConfiguration: '
    .. vim.inspect(self.Config)
end

--- Sets up the m0 plugin.
---@param user_config table The user configuration.
---@return nil
function M.setup(user_config)
  M.Config = vim.tbl_extend('force', M.Config, user_config or {})
  if M.Config.backends[M.Config.default_backend_name] == nil then
    error(
      'Default backend ('
        .. M.Config.default_backend_name
        .. ') not in configuration.'
    )
  end
  if M.Config.prompts[M.Config.default_prompt_name] == nil then
    error(
      'Default prompt ('
        .. M.Config.default_prompt_name
        .. ') not in configuration.'
    )
  end
  M:M0prompt(M.Config.default_prompt_name)
  M:M0backend(M.Config.default_backend_name)

  -- User commands
  -- -------------

  vim.api.nvim_create_user_command('M0prompt', function(opts)
    M:M0prompt(opts.args)
  end, {
    nargs = 1,
    complete = function()
      local ret = {}
      for k, _ in pairs(M.Config.prompts) do
        table.insert(ret, k)
      end
      table.sort(ret)
      return ret
    end,
  })

  vim.api.nvim_create_user_command('M0backend', function(opts)
    M:M0backend(opts.args)
  end, {
    nargs = 1,
    complete = function()
      local ret = {}
      for k, _ in pairs(M.Config.backends) do
        table.insert(ret, k)
      end
      table.sort(ret)
      return ret
    end,
  })

  vim.api.nvim_create_user_command('M0chat', M.M0chat, {})
end

return M
