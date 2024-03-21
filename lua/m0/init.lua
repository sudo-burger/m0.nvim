local M = {}
local Config = {
  backends = {},
  default_backend = '',
  prompts = {},
  default_prompt = '',
}
local Defaults = {
  openai_url = 'https://api.openai.com/v1/chat/completions',
  antrhopic_url = 'https://api.anthropic.com/v1/messages',
  anthropic_version = '2023-06-01',
}
local Current_backend = ''
local Current_prompt = ''
local API_keys = {}

-- Util functions.
function M.get_api_key(name)
  if API_keys[name] ~= nil then
    API_keys[name] = vim.fn.system('echo -n $(pass ' .. name .. ')')
  end
  return API_keys[name]
end

-- Generic backend.
-- Args:
--    backend: "anthropic" | "openai"
--    params: configuration table.
--
local function make_backend(backend, params)
  if backend == nil or params == nil then
    error 'No configuration. Bailing out.'
  end
  return {
    run = function(messages)
      -- Build the payload (or "data" in curl parlance).
      -- Mandatory:
      -- - model (the user configuration is expected to set this; there is no default).
      -- - messages
      -- Optional:
      -- - max_tokens
      -- - temperature
      -- - prompt (openAI only)
      local data = {}
      if params.model then
        data.model = params.model
      end
      if params.max_tokens then
        data.max_tokens = params.max_tokens
      end
      if params.temperature then
        data.temperature = params.temperature
      end
      data.messages = messages

      local prompt = (Config.prompts[Current_prompt] or '')
      local auth_param = ''
      local url = ''

      -- Authorization, prompt, and message structure differ slightly
      -- between the Anthropic and OpenAI APIs.
      if backend == 'anthropic' then
        auth_param = 'x-api-key: ' .. (params.api_key or '')
        data.system = prompt
        url = params.url or Defaults.antrhopic_url
      elseif backend == 'openai' then
        auth_param = 'Authorization: Bearer ' .. (params.api_key or '')
        table.insert(messages, 1, { role = 'system', content = prompt })
        url = params.url or Defaults.openai_url
      else
        error('Unknown backend: ' .. backend, 2)
      end

      local cmd = 'curl -s '
        .. vim.fn.shellescape(url)
        .. ' -d '
        .. vim.fn.shellescape(vim.fn.json_encode(data))
        .. ' -H '
        .. vim.fn.shellescape(auth_param)
        .. ' -H '
        .. vim.fn.shellescape 'Content-Type: application/json'

      -- Extra header required by the Anthropic API.
      if backend == 'anthropic' then
        cmd = cmd
          .. ' -H '
          .. vim.fn.shellescape(
            'anthropic-version: '
              .. (params.anthropic_version or Defaults.anthropic_version)
          )
      end

      local response = vim.fn.system(cmd)
      local json_response = vim.fn.json_decode(response)

      local ret = {
        error = json_response.error,
      }
      if backend == 'anthropic' then
        ret.reply = (json_response.content[1].text or '')
      elseif backend == 'openai' then
        ret.reply = (json_response.choices[1].message.content or '')
      end
      return ret
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

function M.M0chat()
  local conversation = vim.api.nvim_buf_get_lines(0, 0, -1, false)
  local messages = {}
  local section_mark = '====='

  local i = 1
  local role = {
    'user',
    'assistant',
  }
  local role_idx = 1
  while i <= #conversation do
    -- Switch between roles when meeting a section mark in the conversattion.
    if conversation[i]:sub(1, 5) == section_mark then
      i = i + 1
      if role_idx == 1 then
        role_idx = 2
      else
        role_idx = 1
      end
    end

    local message = { role = role[role_idx], content = '' }

    while i <= #conversation and conversation[i]:sub(1, 5) ~= section_mark do
      message.content = message.content .. conversation[i] .. '\n'
      i = i + 1
    end

    table.insert(messages, message)
  end

  local chat = make_backend(
    Config.backends[Current_backend].type,
    Config.backends[Current_backend]
  )
  local result = chat.run(messages)
  if result.error then
    vim.api.nvim_err_writeln('Error: ' .. result.error.message)
  elseif result.reply then
    -- Build and print the reply in the current buffer.
    -- The reply is enclosed in "section_marks".
    -- The section marks are also used to distinguish between
    -- user and assistant input when building the API calls.
    vim.api.nvim_buf_set_lines(0, -1, -1, false, { section_mark })
    vim.api.nvim_buf_set_lines(
      0,
      -1,
      -1,
      false,
      vim.fn.split(result.reply, '\n')
    )
    vim.api.nvim_buf_set_lines(0, -1, -1, false, { section_mark })
  else
    vim.api.nvim_err_writeln 'Error: Unable to get response.'
  end
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
