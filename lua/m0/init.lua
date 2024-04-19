local M = {}
local Config = {
  backends = {},
  default_backend = '',
  prompts = {},
  default_prompt = '',
  section_mark = '-------',
}
local Defaults = {
  openai_url = 'https://api.openai.com/v1/chat/completions',
  antrhopic_url = 'https://api.anthropic.com/v1/messages',
  anthropic_version = '2023-06-01',
  max_tokens = 128,
  temperature = 1,
  stream = false,
}
local Current_backend = ''
local Current_prompt = ''
local API_keys = {}

-- Util functions.
local function get_current_prompt()
  return Config.prompts[Current_prompt]
end
local function get_current_backend_opts()
  return Config.backends[Current_backend]
end
local function get_current_backend_type()
  return Config.backends[Current_backend].type
end

-- Backend support functions
-- -------------------------
--
-- The response is modeled differently, depending on the API.
-- Args:
--   backend: anthropic | openai
--   data: the response data, converted from json.
-- Returns:
--   The response text.
--
local function get_response_text_anthropic(data)
  local j = vim.fn.json_decode(data)
  if j ~= nil and j.content ~= nil then
    return j.content[1].text
  else
    return data
  end
end
local function get_response_text_openai(data)
  local j = vim.fn.json_decode(data)
  if j ~= nil and j.choices ~= nil then
    return j.choices[1].message.content
  else
    return data
  end
end

-- Similarly to responses, the streaminng deltas are modeled differently, depending on the API.
-- Args:
--   backend: anthropic | openai
--   body: the raw body of the response.
-- Returns:
--   event, data
--   where:
--   event: delta | done | cruft | other'
--   data: the delta text (for delta), or nil (for done, cruft), or the http body (for other).
--
local function get_delta_text_openai(body)
  if body == 'data: [DONE]' then
    return 'done', nil
  end

  if body == '\n' or body == '' then
    return 'cruft', nil
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
end

local function get_delta_text_anthropic(body)
  if body == 'event: message_stop' then
    return 'done', nil
  end

  if body == '\n' or body == '' then
    return 'cruft', nil
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
end

-- Transform the chat buffer into a list of 'messages',
-- as required by the APIs:
-- [{ role = <user|assistant>, content = <str> }]
local function get_messages()
  local messages = {}
  local section_mark = Config.section_mark
  -- Read the conversation from the current buffer.
  local conversation =
    vim.api.nvim_buf_get_lines(vim.api.nvim_get_current_buf(), 0, -1, false)

  -- In these messages, the 'user' and 'assistant' take turns.
  -- "Section marks" are used to distinguish between user and
  -- assistant input when building the API calls.
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
  return get_messages()
end
local function get_messages_openai()
  local messages = get_messages()
  -- The OpenAI completions API requires the prompt to be
  -- the first message (with role 'system').
  -- Patch the messages here.
  table.insert(messages, 1, { role = 'system', content = get_current_prompt() })
  return messages
end

-- Backend factory.
-- Args:
--   backend: "anthropic" | "openai"
--   params: backend-specific configuration table.
-- Returns:
--   A table including the backend-specific implementation of the function run().
--
local function make_backend(
  get_delta_text,
  get_response_text,
  get_messages,
  url,
  body,
  headers,
  opts
)
  -- Sanity checks.
  if opts == nil or opts.model == nil then
    error 'Incomplete configuration. Bailing out.'
  end

  return {
    run = function()
      local buf_id = vim.api.nvim_get_current_buf()

      body.messages = get_messages()

      body.stream = get_current_backend_opts().stream or Defaults.stream

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
        -- The streaming callback appends the reply deltas to the current buffer.
        curl_opts.stream = vim.schedule_wrap(function(_, out, _)
          local event, d = get_delta_text(out)
          if event == 'delta' and d then
            -- Add the delta to the current line.
            set_last_line(get_last_line() .. d)
          elseif event == 'other' then
            -- Could be an error.
            ---@diagnostic disable-next-line: param-type-mismatch
            append_lines(vim.fn.split(d, '\n', true))
          elseif event == 'done' then
            print_section_mark()
          else
            return
          end
        end)
      else
        -- Mot streaming.
        -- We append the LLM's reply to the current buffer at one go.
        curl_opts.callback = vim.schedule_wrap(function(out)
          -- Build and print the reply in the current buffer.
          set_last_line(get_response_text(out.body))
          print_section_mark()
        end)
      end

      print_section_mark()
      -- The closing section mark is printed by the curl callbacks.
      require('plenary.curl').post(url, curl_opts)
    end,
  }
end

-- backend constructors.
local function make_openai(opts)
  return make_backend(
    get_delta_text_openai,
    get_response_text_openai,
    get_messages_openai,
    opts.url or Defaults.openai_url,
    -- Body
    {
      model = opts.model,
      temperature = opts.temperature or Defaults.temperature,
      max_tokens = opts.max_tokens or Defaults.max_tokens,
    },
    -- Headers.
    {
      content_type = 'application/json',
      authorization = 'Bearer ' .. opts.api_key,
    },
    opts
  )
end

local function make_anthropic(opts)
  return make_backend(
    get_delta_text_anthropic,
    get_response_text_anthropic,
    get_messages_anthropic,
    opts.url or Defaults.antrhopic_url,
    -- Body.
    {
      model = opts.model,
      temperature = opts.temperature or Defaults.temperature,
      max_tokens = opts.max_tokens or Defaults.max_tokens,
      system = get_current_prompt(),
    },
    -- Headers.
    {
      content_type = 'application/json',
      x_api_key = opts.api_key,
      anthropic_version = Defaults.anthropic_version,
    },
    opts
  )
end

-- Exported functions
-- ------------------

function M.M0backend(backend)
  if backend ~= nil and backend ~= '' then
    Current_backend = backend
  end
  print('Backend: ' .. Current_backend)
  if get_current_backend_type() == nil then
    error('Unable to find current backend type for ' .. Current_backend)
  end
end

function M.M0prompt(prompt)
  if prompt ~= nil and prompt ~= '' then
    Current_prompt = prompt
  end
  print('Prompt: ' .. Current_prompt)
end

function M.M0chat()
  local messages = get_messages()
  local backend_type = get_current_backend_type()
  local opts = get_current_backend_opts()
  local backend = nil

  if backend_type == 'anthropic' then
    backend = make_anthropic(opts)
  elseif backend_type == 'openai' then
    backend = make_openai(opts)
  else
    error('Invalid backend type: ' .. backend_type)
    return nil
  end

  backend.run()
end

function M.setup(user_config)
  Config = vim.tbl_extend('force', Config, user_config or {})
  Current_backend = Config.default_backend
  if Config.backends[Current_backend] == nil then
    error(
      'Current_backend ('
        .. Current_backend
        .. ') set to non-existing configuration.',
      2
    )
  end
  Current_prompt = Config.default_prompt
  if Config.prompts[Current_prompt] == nil then
    error(
      'Current_prompt ('
        .. Current_prompt
        .. ') set to non-existing configuration.',
      2
    )
  end
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

-- vim.api.nvim_create_user_command('M0debug', function()
--   local buf_id = vim.api.nvim_get_current_buf()
--   local c = vim.inspect(Config)
--   vim.api.nvim_buf_set_lines(buf_id, -1, -1, false, vim.fn.split(c, '\n', true))
--   vim.api.nvim_buf_set_lines(
--     buf_id,
--     -1,
--     -1,
--     false,
--     vim.fn.split('Current backend: ' .. Current_backend, '\n', true)
--   )
--   vim.api.nvim_buf_set_lines(
--     buf_id,
--     -1,
--     -1,
--     false,
--     vim.fn.split(
--       'Current backend type: ' .. get_current_backend_type(),
--       '\n',
--       true
--     )
--   )
-- end, { nargs = 0 })

return M
