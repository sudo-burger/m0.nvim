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

-- The response is modeled differently, depending on the API.
-- Args:
--   backend: anthropic | openai
--   data: the response data, converted from json.
-- Returns:
--   The response text.
--
local function get_response_text(backend, data)
  if backend == 'anthropic' then
    return data.content[1].text
  elseif backend == 'openai' then
    return data.choices[1].message.content
  end
end

-- Similarly, the streaminng deltas are modeled differently, depending on the API.
-- Args:
--   backend: anthropic | openai
--   body: the raw body of the response.
-- Returns:
--   event, delta
--   where:
--   event: delta | done | cruft'
--   delta: the delta text.
--
local function get_delta_text(backend, body)
  if
    (backend == 'openai' and body == 'data: [DONE]')
    or (backend == 'anthropic' and body == 'event: message_stop')
  then
    return 'done', nil
  end

  if string.find(body, '^data: ') == nil then
    -- Not a data package. Skip.
    return 'cruft', nil
  end

  -- We are in a 'data: ' package now.
  -- Extract and return the text payload.
  --
  local j = vim.fn.json_decode(string.sub(body, 7))
  ---@diagnostic disable-next-line: need-check-nil, undefined-field
  if backend == 'anthropic' and j.type == 'content_block_delta' then
    ---@diagnostic disable-next-line: need-check-nil, undefined-field
    return 'delta', j.delta.text
  ---@diagnostic disable-next-line: need-check-nil, undefined-field
  elseif backend == 'openai' and j.object == 'chat.completion.chunk' then
    ---@diagnostic disable-next-line: need-check-nil, undefined-field
    return 'delta', j.choices[1].delta.content
  else
    return 'other', body
  end
end

-- Generic backend.
-- Args:
--   backend: "anthropic" | "openai"
--   params: backend-specific configuration table.
-- Returns:
--   A table including the backend-specific function: run().
--
local function make_backend(backend, opts)
  -- Sanity checks.
  if backend ~= 'anthropic' and backend ~= 'openai' then
    error('Invalid backend: ' .. backend)
  end
  if opts == nil or opts.model == nil then
    error 'Incomplete configuration. Bailing out.'
  end

  local url = nil
  if backend == 'anthropic' then
    url = opts.url or Defaults.antrhopic_url
  elseif backend == 'openai' then
    url = opts.url or Defaults.openai_url
  end

  -- Buld request headers.
  --
  local headers = {
    content_type = 'application/json',
  }
  -- Authorization, prompt, and message structure differ slightly
  -- between the Anthropic and OpenAI APIs.
  if backend == 'anthropic' then
    headers.x_api_key = opts.api_key
    headers.anthropic_version = Defaults.anthropic_version
  elseif backend == 'openai' then
    headers.authorization = 'Bearer ' .. opts.api_key
  end

  -- Build request payload.
  --
  local body = {
    model = opts.model,
    temperature = opts.temperature or Defaults.temperature,
    max_tokens = opts.max_tokens or Defaults.max_tokens,
  }
  if backend == 'anthropic' then
    body.system = get_current_prompt()
  end

  return {
    run = function(messages)
      if backend == 'openai' then
        -- The OpenAI completions API requires the prompt to be the first message
        -- (with role 'system'). Patch the messages here.
        table.insert(
          messages,
          1,
          { role = 'system', content = get_current_prompt() }
        )
      end
      body.messages = messages

      body.stream = Config.backends[Current_backend].stream or Defaults.stream

      local curl_opts = {
        headers = headers,
        body = vim.fn.json_encode(body),
      }

      local function print_section_mark()
        vim.api.nvim_buf_set_lines(
          0,
          -1,
          -1,
          false,
          { Config.section_mark, '' }
        )
      end

      -- Different callbacks needed, depending on whether streaming is enabled or not.
      if body.stream == true then
        -- The streaming callback appends the reply deltas to the current buffer.
        curl_opts.stream = vim.schedule_wrap(function(_, out, _)
          local event, d = get_delta_text(backend, out)
          if event == 'delta' and d then
            vim.api.nvim_buf_set_lines(
              0,
              -2,
              -1,
              false,
              -- { out, '' }
              -- Add the delta to the current line.
              vim.fn.split(
                table.concat(vim.api.nvim_buf_get_lines(0, -2, -1, false)) .. d,
                '\n',
                true
              )
            )
          elseif event == 'done' then
            print_section_mark()
          end
        end)
      else
        -- When not streaming, we append the LLM's reply to the current buffer at one go.
        curl_opts.callback = vim.schedule_wrap(function(out)
          -- Build and print the reply in the current buffer.
          -- The assistant reply is enclosed in "section marks".
          vim.api.nvim_buf_set_lines(
            0,
            -2,
            -1,
            false,
            vim.fn.split(
              get_response_text(backend, vim.fn.json_decode(out.body)),
              '\n'
            )
          )
          print_section_mark()
        end)
      end

      print_section_mark()
      -- The closing section mark is printed by the curl callbacks.
      require('plenary.curl').post(url, curl_opts)
    end,
  }
end

-- Exported functions.
--

-- backend constructors.
function M.make_openai(params)
  return make_backend('openai', params)
end

function M.make_anthropic(params)
  return make_backend('anthropic', params)
end

function M.M0backend(backend)
  if backend ~= nil and backend ~= '' then
    Current_backend = backend
  end
  print('Backend: ' .. Current_backend)
end

function M.M0prompt(prompt)
  if prompt ~= nil and prompt ~= '' then
    Current_prompt = prompt
  end
  print('Prompt: ' .. Current_prompt)
end

-- Transform the chat buffer into a list of 'messages',
-- as required by the APIs:
-- [{ role = <user|assistant>, content = <str> }]
local function get_messages()
  local messages = {}
  local section_mark = Config.section_mark
  -- Read the conversation from the current buffer.
  local conversation = vim.api.nvim_buf_get_lines(0, 0, -1, false)

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

function M.M0chat()
  local messages = get_messages()
  local backend = make_backend(
    Config.backends[Current_backend].type,
    Config.backends[Current_backend]
  )
  backend.run(messages)
end

function M.setup(user_config)
  user_config = user_config or {}
  Config = vim.tbl_extend('force', Config, user_config)
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

return M
