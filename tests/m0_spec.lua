---@diagnostic disable: undefined-global, undefined-field
M0 = require 'm0'

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
      .. vim.inspect(M0.State.backend.opts.api_type),
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
  M0:M0backend 'openai:gpt-3.5-turbo'
  it(
    'can change the prompt when the backend is '
      .. vim.inspect(M0.State.backend.opts.api_type),
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

-- local mock = require 'luassert.mock'
local stub = require 'luassert.stub'

describe('m0', function()
  local m0, config, api_factory, anthropic, openai, utils, vim_buffer

  before_each(function()
    m0 = require 'm0'
    config = require 'm0.config'
    api_factory = require 'm0.apifactory'
    anthropic = require 'm0.anthropic'
    openai = require 'm0.openai'
    utils = require 'm0.utils'
    vim_buffer = require 'm0.vimbuffer'
  end)

  describe('APIFactory', function()
    it('should create an Anthropic API handler', function()
      local api = api_factory.create('anthropic', {}, {})
      assert.truthy(api)
      assert.are.equal(getmetatable(api).__index, anthropic)
    end)

    it('should create an OpenAI API handler', function()
      local api = api_factory.create('openai', {}, {})
      assert.truthy(api)
      assert.are.equal(getmetatable(api).__index, openai)
    end)

    it('should throw an error for unsupported API type', function()
      assert.has.error(function()
        api_factory.create('unsupported', {}, {})
      end, 'Unsupported API type: unsupported')
    end)
  end)

  describe('Anthropic', function()
    local api

    before_each(function()
      api = anthropic:new({
        model = 'claude-3-opus-20240229',
        temperature = 0.7,
        max_tokens = 100,
        stream = false,
        api_key = 'test_key',
        anthropic_version = '2023-06-01',
      }, { prompt = 'Test prompt' })
    end)

    it('should create a valid body', function()
      local body = api:make_body()
      assert.are.same({
        model = 'claude-3-opus-20240229',
        temperature = 0.7,
        max_tokens = 100,
        stream = false,
        system = 'Test prompt',
      }, body)
    end)

    it('should create valid headers', function()
      local headers = api:make_headers()
      assert.are.same({
        content_type = 'application/json',
        x_api_key = 'test_key',
        anthropic_version = '2023-06-01',
      }, headers)
    end)

    it('should format messages correctly', function()
      local raw_messages = { 'Hello', 'Hi there', 'How are you?' }
      local formatted = api:get_messages(raw_messages)
      assert.are.same({
        { role = 'user', content = 'Hello' },
        { role = 'assistant', content = 'Hi there' },
        { role = 'user', content = 'How are you?' },
      }, formatted)
    end)
  end)

  describe('OpenAI', function()
    local api

    before_each(function()
      api = openai:new({
        model = 'gpt-4',
        temperature = 0.7,
        max_tokens = 100,
        stream = false,
        api_key = 'test_key',
      }, { prompt = 'Test prompt' })
    end)

    it('should create a valid body', function()
      local body = api:make_body()
      assert.are.same({
        model = 'gpt-4',
        temperature = 0.7,
        max_tokens = 100,
        stream = false,
      }, body)
    end)

    it('should create valid headers', function()
      local headers = api:make_headers()
      assert.are.same({
        content_type = 'application/json',
        authorization = 'Bearer test_key',
      }, headers)
    end)

    it('should format messages correctly', function()
      local raw_messages = { 'Hello', 'Hi there', 'How are you?' }
      local formatted = api:get_messages(raw_messages)
      assert.are.same({
        { role = 'system', content = 'Test prompt' },
        { role = 'user', content = 'Hello' },
        { role = 'assistant', content = 'Hi there' },
        { role = 'user', content = 'How are you?' },
      }, formatted)
    end)
  end)

  describe('VimBuffer', function()
    local buffer

    before_each(function()
      buffer = vim_buffer:new { section_mark = '-------' }
      stub(vim.api, 'nvim_get_current_buf')
      stub(vim.api, 'nvim_buf_get_lines')
      stub(vim.api, 'nvim_buf_set_lines')
    end)

    after_each(function()
      vim.api.nvim_get_current_buf:revert()
      vim.api.nvim_buf_get_lines:revert()
      vim.api.nvim_buf_set_lines:revert()
    end)

    it('should get messages from buffer', function()
      vim.api.nvim_get_current_buf.returns(1)
      vim.api.nvim_buf_get_lines.returns {
        'User: Hello',
        '-------',
        'AI: Hi there',
        '-------',
        'User: How are you?',
        '-------',
      }

      local messages = buffer:get_messages()
      assert.are.same({
        'User: Hello\n',
        'AI: Hi there\n',
        'User: How are you?\n',
      }, messages)
    end)
  end)

  describe('setup', function()
    it('should throw an error for invalid default backend', function()
      assert.has_error(function()
        m0.setup {
          backends = { ['a'] = {} },
          default_backend_name = 'invalid_backend',
        }
      end, 'Default backend (invalid_backend) not in configuration.')
    end)
    it('should throw an error for invalid default prompt', function()
      assert.has_error(function()
        m0.setup {
          backends = { ['a'] = {} },
          default_backend_name = 'a',
          prompts = { ['a'] = {} },
          default_prompt_name = 'invalid_prompt',
        }
      end, 'Default prompt (invalid_prompt) not in configuration.')
    end)
  end)
end)
