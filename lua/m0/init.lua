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
  max_tokens = 512,
}
local Current_backend = ''
local Current_prompt = ''
local API_keys = {}

-- Util functions.
-- Gets a key fron pass.
function M.get_api_key(name)
  if API_keys[name] ~= nil then
    API_keys[name] = vim.fn.system('echo -n $(pass ' .. name .. ')')
  end
  return API_keys[name]
end

-- Generic backend.
-- Args:
--    backend: "anthropic" | "openai"
--    params: backend-specific configuration table.
--
-- Returns:
-- A table including the backend-specific params and the function: run().
--
local function make_backend(backend, params)
  if backend == nil or params == nil then
    error 'Missing configuration. Bailing out.'
  end
  if params.model == nil then
    error 'Missing model. Bailing out.'
  end
  -- Build the API payload (or "data" in curl parlance).
  -- Mandatory:
  -- - max_tokens
  -- - messages
  -- - model (the user configuration is expected to set this; there is no default).
  -- Optional:
  -- - temperature
  -- - prompt (note that Anthropic and OpenAI place this differently in the API calls).
  -- local headers = {
  --   Authorization = 'Bearer ' .. (params.api_key or ''),
  --   Content_Type = "application/json",
  -- }
  -- local api_payload = {
  --   model = nil,
  --   temperature = nil,
  --   max_tokens = nil
  -- }
  --
  -- api_payload.model = (params.model or '')
  -- api_payload.max_tokens = (tonumber(params.max_tokens) or Defaults.max_tokens)
  -- if api_payload.max_tokens == nil then
  --   error('Invalid max_tokens: ' .. params.max_tokens)
  -- end
  -- api_payload.temperature = (tonumber(params.max_tokens) or Defaults.max_tokens)
  -- if api_payload.temperature == nil then
  --   error('Invalid temperature: ' .. params.temperature)
  -- end
  --
  -- The OpenAI completions API requires the prompt to be the first message
  -- (with role 'system').
  -- The Anthropic messages API requires the prompt to be a separate payload
  -- variable, named 'system'.
  -- prompt = (Config.prompts[Current_prompt] or '')
  local url = params.url or Defaults.openai_url

  -- Authorization, prompt, and message structure differ slightly
  -- between the Anthropic and OpenAI APIs.
  -- if backend == 'anthropic' then
  --   auth_param = 'x-api-key: ' .. (params.api_key or '')
  --   api_payload.system = prompt
  --   url = params.url or Defaults.antrhopic_url
  -- elseif backend == 'openai' then
  --   auth_param = 'Authorization: Bearer ' .. (params.api_key or '')
  --   url = params.url or Defaults.openai_url
  -- else
  --   error('Unknown backend: ' .. backend, 2)
  -- end
  return {
    run = function(messages, callback)
      local curl = require 'plenary.curl'
      local response = curl.post(url, {
        headers = {
          Authorization = 'Bearer ' .. (params.api_key or ''),
          Content_Type = 'application/json',
        },
        body = vim.fn.json_encode {
          model = params.model,
          temperature = params.temperature or 1,
          max_tokens = params.max_tokens or 128,
          messages = messages,
          stream = false,
        },
      })
      callback(response.body)
    end,
  }
  -- table.insert(messages, 1, { role = 'system', content = prompt })
  -- api_payload.messages = messages
  --   table.insert(curl_args, '-d')
  --   table.insert(
  --     curl_args,
  --     vim.fn.shellescape(vim.fn.json_encode(api_payload))
  --   )
  --   local response = ''
  --
  --   local curl = require 'plenary.curl'
  --   curl.post(url, {
  --     headers = headers,
  --   })
  --
  --     command = 'curl',
  --     args = curl_args,
  --     cwd = vim.fn.getcwd(),
  --     on_stderr = function(_, return_val)
  --       error('curl fails: ' .. return_val)
  --     end,
  --     on_exit = function(j, _)
  --       local reply = ''
  --       local json_response = vim.fn.json_decode(j:result())
  --       if json_response.error then
  --         error(json_response.error.message)
  --       elseif backend == 'anthropic' then
  --         reply = (json_response.content[1].text or '')
  --       elseif backend == 'openai' then
  --         reply = (json_response.choices[1].message.content or '')
  --       end
  --       callback(reply)
  --     end,
  --   }
  --
  --   job:start()
  -- end,
  -- }
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

local function show_reply(reply)
  local section_mark = Config.section_mark

  -- Build and print the reply in the current buffer.
  -- The assistant reply is enclosed in "section marks".
  vim.api.nvim_buf_set_lines(0, -1, -1, false, { section_mark })
  vim.api.nvim_buf_set_lines(0, -1, -1, false, vim.fn.split(reply, '\n'))
  vim.api.nvim_buf_set_lines(0, -1, -1, false, { section_mark })
end

function get_messages_from_buffer()
  local messages = {}
  local section_mark = Config.section_mark
  local section_mark_len = string.len(section_mark)
  -- Read the conversation from the current buffer.
  local conversation = vim.api.nvim_buf_get_lines(0, 0, -1, false)

  -- Transform the conversation into a series of 'messages',
  -- as required by the APIs.
  -- In these messages, the 'user' and 'assistant' take turns.
  -- "Section marks" also used to distinguish between user and
  -- assistant input when building the API calls.
  local i = 1
  local role = {
    'user',
    'assistant',
  }
  local role_idx = 1
  while i <= #conversation do
    -- Switch between roles when meeting a section mark in the conversation.
    if conversation[i]:sub(1, section_mark_len) == section_mark then
      -- Next row.
      i = i + 1
      -- Switch role.
      if role_idx == 1 then
        role_idx = 2
      else
        role_idx = 1
      end
    end

    -- Build a message.
    local message = { role = role[role_idx], content = '' }
    while
      i <= #conversation
      and conversation[i]:sub(1, section_mark_len) ~= section_mark
    do
      message.content = message.content .. conversation[i] .. '\n'
      i = i + 1
    end

    table.insert(messages, message)
  end
  return messages
end

function M.M0chat()
  local messages = get_messages_from_buffer()
  local backend = make_backend(
    Config.backends[Current_backend].type,
    Config.backends[Current_backend]
  )

  backend.run(messages, show_reply)
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
    return ret
  end,
})

vim.api.nvim_create_user_command('M0chat', function()
  M.M0chat()
end, { nargs = 0 })

return M
