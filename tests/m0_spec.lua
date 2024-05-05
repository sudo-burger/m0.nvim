---@diagnostic disable: undefined-global

Opts = {
  backends = {
    ['openai:gpt-3.5-turbo'] = {
      type = 'openai',
      api_key = 'xxx',
      model = 'gpt-3.5-turbo',
      stream = true,
    },
    ['anthropic:claude-3-haiku'] = {
      type = 'anthropic',
      api_key = 'xxx',
      anthropic_version = '2023-06-01',
      model = 'claude-3-haiku-20240307',
    },
    ['mistral:mistral-large-latest'] = {
      type = 'openai',
      url = 'https://api.mistral.ai/v1/chat/completions',
      api_key = 'xxx',
      model = 'mistral-large-latest',
      max_tokens = 1024,
      temperature = 0.7,
    },
  },
  default_backend_name = 'anthropic:claude-3-haiku',
  prompts = {
    ['Charles Bukowski'] = 'You are now Charles Bukowski.',
    ['Marilyn Monroe'] = 'Assume the role of Marilyn Monroe.',
  },
  default_prompt_name = 'Marilyn Monroe',
}

M0 = require 'm0'
M0.setup(Opts)

describe('m0', function()
  it('can be required', function()
    require 'm0'
  end)
end)

describe('m0', function()
  it('has an initial prompt', function()
    assert(M0.get_current_prompt() == Opts.prompts[Opts.default_prompt_name])
  end)
end)

describe('m0', function()
  it('can change the prompt', function()
    local new_prompt_name = 'Charles Bukowski'
    local eprompt = Opts.prompts[new_prompt_name]

    M0.M0prompt(new_prompt_name)
    assert(
      eprompt == M0.get_current_prompt(),
      'Expected: ' .. eprompt .. '. Actual: ' .. M0.get_current_prompt()
    )
  end)
end)

describe('m0', function()
  it('has an initial backend', function()
    assert(
      vim.inspect(M0.get_current_backend_opts()) ~= vim.inspect {},
      'no current bakend opts.'
    )
  end)
end)

describe('m0', function()
  it('can change the backend', function()
    local new_backend_name = 'mistral:mistral-large-latest'
    local ebackend_opts = vim.inspect(Opts.backends[new_backend_name])
    M0.M0backend(new_backend_name)
    local abackend_opts = vim.inspect(M0.get_current_backend_opts() or {})
    assert(
      (ebackend_opts ~= vim.inspect {}) and (ebackend_opts == abackend_opts),
      'Expected: '
        .. ebackend_opts
        .. ' where this is not {}. Actual: '
        .. abackend_opts
    )
  end)
end)

describe('m0', function()
  it('can debug', function()
    M0.debug()
  end)
end)
