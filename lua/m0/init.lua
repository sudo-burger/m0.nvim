local M = {}

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

---@class (exact) Backend
---@field run fun(): nil
local Current_backend = {}
---@type string
local Current_backend_name = ''
---@type string
local Current_prompt_name = ''
---@type table
local API_keys = {}

-- Util functions
-- --------------

---comment
---@return string
function M.get_current_prompt()
  return Config.prompts[Current_prompt_name]
end
---comment
---@return table
function M.get_current_backend_opts()
  return Config.backends[Current_backend_name]
end
---comment
---@return string
function M.get_current_backend_type()
  return Config.backends[Current_backend_name].type
end

-- Backend support functions
-- -------------------------
-- The response is modeled differently, depending on the API.

---Returns the text content of an API response.
---Throws an error if the API response cannot be parsed.
---@param data string The response data (normally a JSON)
---@return string|nil text if available in the API response.
local function get_response_text_anthropic(data)
  local j = vim.fn.json_decode(data)
  if j ~= nil and j.content ~= nil then
    return j.content[1].text
  else
    error('Received: ' .. data)
  end
end

---Returns the text content of an API response.
---Throws an error if the API response cannot be parsed.
---@param data string The response data (normally a JSON)
---@return string|nil text if available in the API response.
local function get_response_text_openai(data)
  local j = vim.fn.json_decode(data)
  if j ~= nil and j.choices ~= nil then
    return j.choices[1].message.content
  else
    error('Received: ' .. data)
  end
end

-- Similarly to responses, the streaminng deltas are modeled differently
-- depending on the API.

---Returns event,data
---where
---  event: delta | done | cruft | other
---  data: the delta text (for delta), or the http body for other events.
---@param body string The raw body of the response.
---@return string,string
local function get_delta_text_openai(body)
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

---Returns event,data
---where
---  event: delta | done | cruft | other
---  data: the delta text (for delta), or the http body for other events.
---@param body string The raw body of the response.
---@return string,string
local function get_delta_text_anthropic(body)
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
    if j ~= nil and j.type == 'content_block_delta' and j.delta.text ~= nil then
      return 'delta', j.delta.text
    end
  else
    return 'other', body
  end
  -- Not data, so most likely metadata that we only would want to see for
  -- debugging purposes.
  return 'cruft', body
end

local function get_visual_selection()
  local sline = vim.fn.line 'v'
  local eline = vim.fn.line '.'
  return vim.api.nvim_buf_get_lines(
    vim.api.nvim_get_current_buf(),
    math.min(sline, eline) - 1,
    math.max(sline, eline),
    false
  )
end

-- Transform the chat text into a list of 'messages',
-- with format: [{ role = <user|assistant>, content = <str> }]
--
local function get_messages_from_current_buffer()
  local messages = {}
  local section_mark = Config.section_mark
  local conversation = nil

  local mode = vim.api.nvim_get_mode().mode
  if mode == 'v' or mode == 'V' then
    -- Read the conversation from the visual selection.
    conversation = get_visual_selection()
  else
    -- Read the conversation from the current buffer.
    conversation =
      vim.api.nvim_buf_get_lines(vim.api.nvim_get_current_buf(), 0, -1, false)
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

local function get_messages_anthropic()
  return get_messages_from_current_buffer()
end
local function get_messages_openai()
  local messages = get_messages_from_current_buffer()
  -- The OpenAI completions API requires the prompt to be
  -- the first message (with role 'system').
  -- Patch the messages here.
  table.insert(
    messages,
    1,
    { role = 'system', content = M.get_current_prompt() }
  )
  return messages
end

---comment
---Backend factory.
---Returns a table including the backend-specific implementation of the function run().
---
---@param get_delta_text fun(string):table<string,string> A function to return an API response delta if streaminng.
---@param get_response_text fun(table):string A function to return an API response if not streaming.
---@param get_messages fun():table A function to extract messages from the current conversation.
---@param url string API url.
---@param body table API-specific request body.
---@param headers table API-specific headers.
---@return Backend
local function make_backend(
  get_delta_text,
  get_response_text,
  get_messages,
  url,
  body,
  headers
)
  return {
    run = function()
      local buf_id = vim.api.nvim_get_current_buf()

      body.messages = get_messages()

      body.stream = M.get_current_backend_opts().stream or Config.default_stream

      local curl_opts = {
        headers = headers,
        body = vim.fn.json_encode(body),
      }

      local function append_lines(lines)
        vim.api.nvim_buf_set_lines(buf_id, -1, -1, false, lines)
      end

      local function get_last_line()
        return table.concat(vim.api.nvim_buf_get_lines(buf_id, -2, -1, false))
      end

      local function set_last_line(txt)
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

      local function print_section_mark()
        append_lines { Config.section_mark, '' }
      end

      -- Different callbacks needed, depending on whether streaming is enabled or not.
      if body.stream == true then
        -- The streaming callback appends the reply to the current buffer.
        curl_opts.stream = vim.schedule_wrap(function(_, out, _)
          local event, d = get_delta_text(out)
          if event == 'delta' and d ~= '' then
            -- Add the delta to the current line.
            set_last_line(get_last_line() .. d)
          elseif event == 'other' and d ~= '' then
            -- Could be an error.
            append_lines(vim.fn.split(d, '\n', true))
          elseif event == 'done' then
            print_section_mark()
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
          set_last_line(get_response_text(out.body))
          print_section_mark()
        end)
      end

      -- Mark the start of a reply section.
      -- The closing section mark is printed by the curl callbacks.
      print_section_mark()
      require('plenary.curl').post(url, curl_opts)
    end,
  }
end

-- Backend constuctors
-- -------------------

---Make an OpenAI backend.
---Returns a table that includes the run() function.
---@param opts table Backend opts. Normally from the user configuration.
---@return table
local function make_openai(opts)
  return make_backend(
    get_delta_text_openai,
    get_response_text_openai,
    get_messages_openai,
    opts.url or Config.default_openai_url,
    -- Body
    {
      model = opts.model,
      temperature = opts.temperature or Config.default_temperature,
      max_tokens = opts.max_tokens or Config.default_max_tokens,
    },
    -- Headers.
    {
      content_type = 'application/json',
      authorization = 'Bearer ' .. opts.api_key,
    }
  )
end

---Make an Anthropic backend.
---Returns a table that includes the run() function.
---@param opts table Backend opts. Normally from the user configuration.
---@return table
local function make_anthropic(opts)
  return make_backend(
    get_delta_text_anthropic,
    get_response_text_anthropic,
    get_messages_anthropic,
    opts.url or Config.default_antrhopic_url,
    -- Body.
    {
      model = opts.model,
      temperature = opts.temperature or Config.default_temperature,
      max_tokens = opts.max_tokens or Config.default_max_tokens,
      system = M.get_current_prompt(),
    },
    -- Headers.
    {
      content_type = 'application/json',
      x_api_key = opts.api_key,
      anthropic_version = Config.default_anthropic_version,
    }
  )
end

-- Exported functions
-- ------------------

---Select backend interactively.
---@param backend_name string
---@return nil
function M.M0backend(backend_name)
  if backend_name ~= nil and backend_name ~= '' then
    Current_backend_name = backend_name
  end
  local backend_type = M.get_current_backend_type()
  if backend_type == nil then
    error('Unable to find type for backend: ' .. Current_backend_name)
  end
  local opts = M.get_current_backend_opts()
  if opts == nil then
    error('Unable to find opts for backend: ' .. Current_backend_name)
  end
  if backend_type == 'anthropic' then
    Current_backend = make_anthropic(opts)
  elseif backend_type == 'openai' then
    Current_backend = make_openai(opts)
  else
    error('Invalid backend type: ' .. backend_type)
  end
end

---Select prompt interactively.
---@param prompt_name string
---@return nil
function M.M0prompt(prompt_name)
  if prompt_name ~= nil and prompt_name ~= '' then
    Current_prompt_name = prompt_name
  end
end

---Run a chat round.
function M.M0chat()
  Current_backend.run()
end

function M.setup(user_config)
  Config = vim.tbl_extend('force', Config, user_config or {})
  Current_backend_name = Config.default_backend_name
  if Config.backends[Current_backend_name] == nil then
    error(
      'Current_backend_name ('
        .. Current_backend_name
        .. ') set to non-existing configuration.',
      2
    )
  end
  Current_prompt_name = Config.default_prompt_name
  if Config.prompts[Current_prompt_name] == nil then
    error(
      'Current_prompt_name ('
        .. Current_prompt_name
        .. ') set to non-existing configuration.',
      2
    )
  end
  M.M0backend(Current_backend_name)
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

-- Gets a key fron pass.
function M.get_api_key(name)
  if API_keys[name] ~= nil then
    API_keys[name] = vim.fn.system('echo -n $(pass ' .. name .. ')')
  end
  return API_keys[name]
end

function M.debug()
  return 'Current backend name: '
    .. (Current_backend_name or '')
    .. '\nCurrent backend type: '
    .. (M.get_current_backend_type() or '')
    .. '\nCurrent prompt name: '
    .. (Current_prompt_name or '')
    .. '\nConfiguration: '
    .. vim.inspect(Config)
end

return M
