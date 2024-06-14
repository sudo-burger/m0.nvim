---@diagnostic disable: undefined-global, undefined-field
M0 = require 'm0'

-- Invalid prompt.
Opts = {
  providers = {
    ['openai'] = {
      api_key = 'xxx',
    },
  },
  backends = {
    ['openai:gpt-3.5-turbo'] = {
      provider = 'openai',
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
  providers = {
    ['openai'] = {
      api_key = 'xxx',
    },
  },
  backends = {
    ['openai:gpt-3.5-turbo'] = {
      provider = 'openai',
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
  providers = {
    ['openai'] = {
      api_key = 'xxx',
    },
    ['anthropic'] = {
      api_key = 'xxx',
    },
  },
  backends = {
    ['openai:gpt-3.5-turbo'] = {
      provider = 'openai',
      model = 'gpt-3.5-turbo',
      stream = true,
    },
    ['anthropic:claude-3-haiku'] = {
      provider = 'anthropic',
      anthropic_version = '2023-06-01',
      model = 'claude-3-haiku-20240307',
    },
    ['mistral:mistral-large-latest'] = {
      provider = 'openai',
      url = 'https://api.mistral.ai/v1/chat/completions',
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
      local debug = M0:debug()
      ---@diagnostic disable-next-line: unused-local
      local len = string.len(debug)
    end)
  end)
end)
--
describe('m0', function()
  local expected = Opts.backends[Opts.default_backend_name]
  local actual = M0.State.backend.opts
  it('has an initial backend', function()
    for k, _ in pairs(expected) do
      assert(
        expected[k] == actual[k],
        'Expected: ' .. expected[k] .. '. Actual: ' .. actual[k]
      )
    end
  end)
end)

describe('m0', function()
  it('can change the backend', function()
    local new_backend_name = 'mistral:mistral-large-latest'
    local initial_backend_opts = M0.State.backend.opts
    local expected_backend_opts = Opts.backends[new_backend_name]
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
    M0:M0backend(new_backend_name)
    local actual_backend_opts = M0.State.backend.opts or {}
    for k, _ in pairs(expected_backend_opts) do
      assert(
        expected_backend_opts[k] == actual_backend_opts[k],
        'Expected: '
          .. vim.inspect(expected_backend_opts[k])
          .. ' Actual: '
          .. vim.inspect(actual_backend_opts[k])
      )
    end
    M0:M0backend(Opts.default_backend_name)
    actual_backend_opts = M0.State.backend.opts or {}

    for k, _ in pairs(initial_backend_opts) do
      assert(
        vim.inspect(initial_backend_opts[k])
          == vim.inspect(actual_backend_opts[k]),
        'Cannot restore the inital backend. Expected: '
          .. vim.inspect(initial_backend_opts[k])
          .. ' Actual: '
          .. vim.inspect(actual_backend_opts[k])
      )
    end
  end)
end)

describe('m0', function()
  it('can chat', function()
    assert.has_no.errors(M0.M0chat)
  end)
end)

describe('m0', function()
  it('has an initial prompt', function()
    assert(M0.State.prompt == Opts.prompts[Opts.default_prompt_name])
  end)
end)

describe('m0', function()
  it(
    'can change the prompt when the backend is '
      .. vim.inspect(M0.State.backend.opts.type),
    function()
      local new_prompt_name = 'Charles Bukowski'
      local expected = Opts.prompts[new_prompt_name]

      M0:M0prompt(new_prompt_name)
      assert(
        expected == M0.State.prompt,
        'Expected: ' .. expected .. '. Actual: ' .. M0.State.prompt
      )
    end
  )
  M0:M0backend 'anthropic:claude-3-haiku'
  it(
    'can change the prompt when the backend is '
      .. vim.inspect(M0.State.backend.opts.type),
    function()
      local new_prompt_name = 'Marilyn Monroe'
      local expected = Opts.prompts[new_prompt_name]

      M0:M0prompt(new_prompt_name)
      assert(
        expected == M0.State.prompt,
        'Expected: ' .. expected .. '. Actual: ' .. M0.State.prompt
      )
    end
  )
end)
