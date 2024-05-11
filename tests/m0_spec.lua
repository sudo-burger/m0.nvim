---@diagnostic disable: undefined-global, undefined-field
M0 = require 'm0'

-- Invalid prompt.
Opts = {
  backends = {
    ['openai:gpt-3.5-turbo'] = {
      type = 'openai',
      api_key = 'xxx',
      model = 'gpt-3.5-turbo',
      stream = true,
    },
  },
  default_backend_name = 'openai:gpt-3.5-turbo',
  prompts = {
    ['Charles Bukowski'] = 'You are now Charles Bukowski.',
  },
  default_prompt_name = 'Marilyn Monroe',
}

describe('m0', function()
  it('setup fails if the default prompt does not exist', function()
    assert.has.errors(function()
      M0.setup(Opts)
    end)
  end)
end)

-- Invalid backend.
Opts = {
  backends = {
    ['openai:gpt-3.5-turbo'] = {
      type = 'openai',
      api_key = 'xxx',
      model = 'gpt-3.5-turbo',
      stream = true,
    },
  },
  default_backend_name = 'xxx',
  prompts = {
    ['Charles Bukowski'] = 'You are now Charles Bukowski.',
  },
  default_prompt_name = 'Charles Bukowski',
}

describe('m0', function()
  it('setup fails if the default backend does not exist', function()
    assert.has.errors(function()
      M0.setup(Opts)
    end)
  end)
end)

-- Valid configuration.
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

describe('m0', function()
  it('can be setup', function()
    M0.setup(Opts)
  end)
end)

describe('m0', function()
  it('can debug', function()
    assert.has_no.errors(function()
      local debug = M0.debug()
      ---@diagnostic disable-next-line: unused-local
      local len = string.len(debug)
    end)
  end)
end)
--
describe('m0', function()
  it('has an initial prompt', function()
    assert(M0.State.prompt == Opts.prompts[Opts.default_prompt_name])
  end)
end)

describe('m0', function()
  it('can change the prompt', function()
    local new_prompt_name = 'Charles Bukowski'
    local expected = Opts.prompts[new_prompt_name]

    M0.M0prompt(new_prompt_name)
    assert(
      expected == M0.State.prompt,
      'Expected: ' .. expected .. '. Actual: ' .. M0.State.prompt
    )
  end)
end)

describe('m0', function()
  local expected = vim.inspect(Opts.backends[Opts.default_backend_name])
  it('has an initial backend', function()
    assert(
      vim.inspect(M0.State.backend.opts) == expected,
      'Expected: '
        .. expected
        .. '. Actual: '
        .. vim.inspect(M0.State.backend.opts)
    )
  end)
end)

describe('m0', function()
  it('can change the backend', function()
    local new_backend_name = 'mistral:mistral-large-latest'
    local initial_backend_opts = vim.inspect(M0.State.backend.opts)
    local expected_backend_opts = vim.inspect(Opts.backends[new_backend_name])
    assert(
      initial_backend_opts ~= vim.inspect {},
      'The initial backend is empty.'
    )
    assert(
      expected_backend_opts ~= vim.inspect {},
      'The expected backend is empty.'
    )
    assert(
      initial_backend_opts ~= expected_backend_opts,
      'initial backend is the same as the test backend (should not happen).'
    )
    M0.M0backend(new_backend_name)
    local actual_backend_opts = vim.inspect(M0.State.backend.opts or {})
    assert(
      expected_backend_opts == actual_backend_opts,
      'Expected: '
        .. expected_backend_opts
        .. ' Actual: '
        .. actual_backend_opts
    )
    M0.M0backend(Opts.default_backend_name)
    actual_backend_opts = vim.inspect(M0.State.backend.opts or {})
    assert(
      initial_backend_opts == actual_backend_opts,
      'Cannot restore the inital backend. Expected: '
        .. initial_backend_opts
        .. ' Actual: '
        .. actual_backend_opts
    )
  end)
end)

describe('m0', function()
  it('can chat', function()
    assert.has_no.errors(M0.M0chat)
  end)
end)
