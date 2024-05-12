local M = {}

---@class (exact) Config
---@field backends table
---@field default_backend_name string
---@field prompts table
---@field default_prompt_name string
---@field section_mark string
---@field default_max_tokens integer
---@field default_temperature float
---@field default_stream boolean
---@field default_openai_url string
---@field default_antrhopic_url string
---@field default_anthropic_version string
local Config = {
  backends = {},
  default_backend_name = '',
  prompts = {},
  default_prompt_name = '',
  section_mark = '-------',
  default_max_tokens = 128,
  default_temperature = 1,
  default_stream = false,
  default_openai_url = 'https://api.openai.com/v1/chat/completions',
  default_antrhopic_url = 'https://api.anthropic.com/v1/messages',
  default_anthropic_version = '2023-06-01',
}

---@class (exact) State
---@field backend Backend
---@field backend_name string
---@field prompt string
---@field prompt_name string
---@field api_keys table
M.State = {
  ---@class (exact) Backend
  ---@field name string
  ---@field opts table
  ---@field type string
  ---@field run fun(): nil
  backend = {},

  ---@type string
  prompt = '',

  ---@type string
  prompt_name = '',

  ---@type table
  api_keys = {},
}

--- Abstract class for message handlers.
---@class (exact) Message
---@field new fun():Message
---@field get_messages fun():table
---@field append_lines fun(table)
---@field get_last_line fun():string
---@field set_last_line fun(string)
---@field open_section fun()
---@field close_section fun()
local Message = {}
Message.new = function()
  local self = {}
  function self.get_messages()
    error 'abstract method!'
  end
  function self.append_lines()
    error 'abstract method!'
  end
  function self.get_last_line()
    error 'abstract method!'
  end
  function self.set_last_line()
    error 'abstract method!'
  end
  function self.open_section()
    error 'abstract method!'
  end
  function self.close_section()
    error 'abstract method!'
  end
  return self
end

--- Extends Message.
local CurrentBuffer = {}
CurrentBuffer.new = function()
  local self = Message.new()
  local buf_id = vim.api.nvim_get_current_buf()
  -- Private method.
  local get_visual_selection = function()
    local sline = vim.fn.line 'v'
    local eline = vim.fn.line '.'
    return vim.api.nvim_buf_get_lines(
      buf_id,
      math.min(sline, eline) - 1,
      math.max(sline, eline),
      false
    )
  end

  -- Get messages from current buffer.
  -- Transform the chat text into a list of 'messages',
  -- with format: [{ role = <user|assistant>, content = <str> }]
  --
  self.get_messages = function()
    buf_id = vim.api.nvim_get_current_buf()
    local messages = {}
    local section_mark = Config.section_mark
    local conversation = nil

    local mode = vim.api.nvim_get_mode().mode
    if mode == 'v' or mode == 'V' then
      -- Read the conversation from the visual selection.
      conversation = get_visual_selection()
    else
      -- Read the conversation from the current buffer.
      conversation = vim.api.nvim_buf_get_lines(buf_id, 0, -1, false)
    end

    -- In conversations, the 'user' and 'assistant' take turns.
    -- "Section marks" are used to signal the switches between the two roles.
    local i = 1
    local role = {
      'user',
      'assistant',
    }
    -- Assume the first message to be the user's.
    local role_idx = 1
    while i <= #conversation do
      -- Switch between roles when meeting a section mark in the conversation.
      if conversation[i] == section_mark then
        -- Switch role.
        if role_idx == 1 then
          role_idx = 2
        else
          role_idx = 1
        end
        i = i + 1
      end

      -- Build a message.
      local message = { role = role[role_idx], content = '' }
      while i <= #conversation and conversation[i] ~= section_mark do
        message.content = message.content .. conversation[i] .. '\n'
        i = i + 1
      end

      table.insert(messages, message)
    end
    return messages
  end

  self.append_lines = function(lines)
    vim.api.nvim_buf_set_lines(buf_id, -1, -1, false, lines)
  end

  self.get_last_line = function()
    return table.concat(vim.api.nvim_buf_get_lines(buf_id, -2, -1, false))
  end

  self.set_last_line = function(txt)
    vim.api.nvim_buf_set_lines(
      buf_id,
      -2,
      -1,
      false,
      -- If the input contains multiple lines,
      -- split them as required by nvim_buf_get_lines()
      vim.fn.split(txt, '\n', true)
    )
  end

  self.open_section = function()
    self.append_lines { Config.section_mark, '' }
  end

  self.close_section = function()
    self.append_lines { Config.section_mark, '' }
  end
  return self
end

---Abstract class for LLM APIs.
--
---@class (exact) LLMAPI
---@field new fun():LLMAPI
---@field opts table
---@field get_body fun():table|nil
---@field get_headers fun():table|nil
---@field get_messages fun(table):table|nil
---@field get_response_text fun(string):string|nil
---@field get_delta_text fun(string):string,string
local LLMAPI = {}
function LLMAPI.new()
  local self = {}
  self.opts = {}
  function self.get_body()
    error 'abstract method!'
  end
  function self.get_headers()
    error 'abstract method!'
  end
  function self.get_messages()
    error 'abstract method!'
  end
  function self.get_response_text()
    error 'abstract method!'
  end
  function self.get_delta_text()
    error 'abstract method!'
  end
  return self
end
--

-- Extends LLMAPI
---@class (exact) Anthropic
---@field new fun(table):LLMAPI
---@field opts table
local Anthropic = {}
Anthropic.new = function(opts)
  local self = LLMAPI.new()
  self.opts = opts

  ---@return table
  self.get_body = function()
    return {
      model = self.opts.model,
      temperature = self.opts.temperature or Config.default_temperature,
      max_tokens = self.opts.max_tokens or Config.default_max_tokens,
      stream = opts.stream or Config.default_stream,
      system = M.State.prompt,
    }
  end
  --
  ---@return table
  self.get_headers = function()
    return {
      content_type = 'application/json',
      x_api_key = self.opts.api_key,
      anthropic_version = Config.default_anthropic_version,
    }
  end

  self.get_messages = function(messages)
    return messages
  end
  --
  ---Returns the text content of an API response.
  ---Throws an error if the API response cannot be parsed.
  ---@param data string The response data. Normally a JSON.
  ---@return string|nil text The API response text, if available.
  self.get_response_text = function(data)
    local j = vim.fn.json_decode(data)
    if j ~= nil and j.content ~= nil then
      return j.content[1].text
    else
      error('Received: ' .. data)
    end
  end

  ---Returns event,data
  ---where
  ---  event: delta | done | cruft | other
  ---  data: the delta text (for delta), or the http body for other events.
  ---@param body string The raw body of the response.
  ---@return string,string
  self.get_delta_text = function(body)
    if body == 'event: message_stop' then
      return 'done', body
    end

    if body == '\n' or body == '' or string.find(body, '^event: ') ~= nil then
      return 'cruft', body
    end

    if string.find(body, '^data: ') ~= nil then
      -- We are in a 'data: ' package now.
      -- Extract and return the text payload.
      --
      local j = vim.fn.json_decode(string.sub(body, 7))
      if
        j ~= nil
        and j.type == 'content_block_delta'
        and j.delta.text ~= nil
      then
        return 'delta', j.delta.text
      end
    else
      return 'other', body
    end
    -- Not data, so most likely metadata that we only would want to see for
    -- debugging purposes.
    return 'cruft', body
  end
  return self
end

-- Extends LLMAPI
---@class (exact) OpenAI
---@field new fun(table):LLMAPI
---@field opts table
local OpenAI = {}
OpenAI.new = function(opts)
  local self = LLMAPI.new()
  self.opts = opts
  ---@return table
  self.get_body = function()
    return {
      model = self.opts.model,
      temperature = self.opts.temperature or Config.default_temperature,
      max_tokens = self.opts.max_tokens or Config.default_max_tokens,
      stream = opts.stream or Config.default_stream,
    }
  end
  --
  ---@return table
  self.get_headers = function()
    return {
      content_type = 'application/json',
      authorization = 'Bearer ' .. self.opts.api_key,
    }
  end

  self.get_messages = function(messages)
    -- The OpenAI completions API requires the prompt to be
    -- the first message (with role 'system').
    -- Patch the messages here.
    table.insert(messages, 1, { role = 'system', content = M.State.prompt })
    return messages
  end

  ---Returns the text content of an API response.
  ---Throws an error if the API response cannot be parsed.
  ---@param data string The response data. Normally a JSON.
  ---@return string|nil text The API response text, if available.
  self.get_response_text = function(data)
    local j = vim.fn.json_decode(data)
    if j ~= nil and j.choices ~= nil then
      return j.choices[1].message.content
    else
      error('Received: ' .. data)
    end
  end

  ---Returns event,data
  ---where
  ---  event: delta | done | cruft | other
  ---  data: the delta text (for delta), or the http body for other events.
  ---@param body string The raw body of the response.
  ---@return string,string
  self.get_delta_text = function(body)
    if body == 'data: [DONE]' then
      return 'done', body
    end

    if body == '\n' or body == '' then
      return 'cruft', body
    end

    if string.find(body, '^data: ') ~= nil then
      -- We are in a 'data: ' package now.
      -- Extract and return the text payload.
      --
      -- The last message in an openai delta will have:
      --   choices[1].delta == {}
      --   choices[1].finish_reason == 'stop'
      --
      local j = vim.fn.json_decode(string.sub(body, 7))
      if
        j ~= nil
        and j.object == 'chat.completion.chunk'
        and j.choices[1].delta.content ~= nil
      then
        return 'delta', j.choices[1].delta.content
      end
    else
      return 'other', body
    end
    -- Not data, so most likely metadata that we only would want to see for
    -- debugging purposes.
    return 'cruft', body
  end
  return self
end

---comment
---Backend factory.
---Returns a table including the backend-specific implementation of the function run().
---
---@param API LLMAPI The API handler.
---@param msg Message The message handler.
---@return Backend
local function make_backend(API, msg, opts)
  return {
    opts = opts,
    name = opts.backend_name,
    type = opts.type,
    run = function()
      local body = API.get_body()
      -- Message are specific to each run.
      body.messages = API.get_messages(msg.get_messages())

      local curl_opts = {
        headers = API.get_headers(),
        body = vim.fn.json_encode(body),
      }

      -- Different callbacks needed, depending on whether streaming is enabled or not.
      if body.stream == true then
        -- The streaming callback appends the reply to the current buffer.
        curl_opts.stream = vim.schedule_wrap(function(_, out, _)
          local event, d = API.get_delta_text(out)
          if event == 'delta' and d ~= '' then
            -- Add the delta to the current line.
            msg.set_last_line(msg.get_last_line() .. d)
          elseif event == 'other' and d ~= '' then
            -- Could be an error.
            msg.append_lines(vim.fn.split(d, '\n', true))
          elseif event == 'done' then
            msg.close_section()
          else
            -- Cruft or no data.
            return
          end
        end)
      else
        -- Not streaming.
        -- We append the LLM's reply to the current buffer at one go.
        curl_opts.callback = vim.schedule_wrap(function(out)
          -- Build and print the reply in the current buffer.
          msg.set_last_line(API.get_response_text(out.body))
          msg.close_section()
        end)
      end

      -- The closing section mark is printed by the curl callbacks.
      msg.open_section()
      require('plenary.curl').post(opts.url, curl_opts)
    end,
  }
end

-- Exported functions
-- ------------------

---Select backend interactively.
---@param backend_name string
---@return nil
function M.M0backend(backend_name)
  local API = nil
  local msg = CurrentBuffer.new()
  local opts = Config.backends[backend_name]

  -- Sanity checks.
  if opts == nil then
    error("Backend '" .. backend_name .. "' not in configuration.")
  end
  if opts.type == nil then
    error('Unable to find type for backend: ' .. backend_name)
  end

  -- Backend type handlers.
  if opts.type == 'anthropic' then
    if opts.url == nil then
      opts.url = Config.default_antrhopic_url
    end
    API = Anthropic.new(opts)
  elseif opts.type == 'openai' then
    if opts.url == nil then
      opts.url = Config.default_openai_url
    end
    API = OpenAI.new(opts)
  else
    error('Invalid backend type: ' .. (opts.type or 'nil'))
  end

  M.State.backend = make_backend(API, msg, opts)
end

---Select prompt interactively.
---@param prompt_name string
---@return nil
function M.M0prompt(prompt_name)
  if Config.prompts[prompt_name] == nil then
    error("Prompt '" .. prompt_name .. "' not in configuration.")
  end
  M.State.prompt_name = prompt_name
  M.State.prompt = Config.prompts[prompt_name]
end

---Run a chat round.
function M.M0chat()
  M.State.backend.run()
end

function M.setup(user_config)
  Config = vim.tbl_extend('force', Config, user_config or {})
  if Config.backends[Config.default_backend_name] == nil then
    error(
      'Default backend ('
        .. Config.default_backend_name
        .. ') not in configuration.'
    )
  end
  if Config.prompts[Config.default_prompt_name] == nil then
    error(
      'Default prompt ('
        .. Config.default_prompt_name
        .. ') not in configuration.'
    )
  end
  M.M0prompt(Config.default_prompt_name)
  M.M0backend(Config.default_backend_name)
end

-- User commands
-- -------------

vim.api.nvim_create_user_command('M0prompt', function(opts)
  M.M0prompt(opts.args)
end, {
  nargs = 1,
  complete = function()
    local ret = {}
    for k, _ in pairs(Config.prompts) do
      table.insert(ret, k)
    end
    table.sort(ret)
    return ret
  end,
})

vim.api.nvim_create_user_command('M0backend', function(opts)
  M.M0backend(opts.args)
end, {
  nargs = 1,
  complete = function()
    local ret = {}
    for k, _ in pairs(Config.backends) do
      table.insert(ret, k)
    end
    table.sort(ret)
    return ret
  end,
})

vim.api.nvim_create_user_command('M0chat', function()
  M.M0chat()
end, { nargs = 0 })

---Get a key fron pass.
---@param name string the name of the key.
---@return string key the key value.
function M.get_api_key(name)
  if M.State.api_keys[name] == nil then
    M.State.api_keys[name] = vim.fn.system('echo -n $(pass ' .. name .. ')')
  end
  return M.State.api_keys[name]
end

---Returns various debug information as a string.
---@return string
function M.debug()
  return 'State:\n'
    .. vim.inspect(M.State)
    .. '\nConfiguration: '
    .. vim.inspect(Config)
end

return M
