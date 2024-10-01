local M0 = require 'm0'
local assert = require 'luassert'
local stub = require 'luassert.stub'
local spy = require 'luassert.spy'

describe('m0.nvim', function()
  local mock_config = {
    providers = {
      ['openai'] = {
        api_key = function()
          return 'dummy_key'
        end,
      },
      ['anthropic'] = {
        api_key = function()
          return 'dummy_key'
        end,
      },
    },
    backends = {
      ['openai:gpt-3.5-turbo'] = {
        provider = 'openai',
        model = { name = 'gpt-3.5-turbo' },
        stream = false,
      },
      ['anthropic:claude-3-haiku'] = {
        provider = 'anthropic',
        model = { name = 'claude-3-haiku-20240307' },
        stream = false,
      },
    },
    default_backend_name = 'openai:gpt-3.5-turbo',
    prompts = {
      ['Helpful assistant'] = 'You are a helpful assistant.',
      ['Code reviewer'] = 'You are a code reviewer.',
    },
    default_prompt_name = 'Helpful assistant',
    section_mark = '-------',
  }

  local original_state

  before_each(function()
    original_state = vim.deepcopy(M0.State)
    M0.setup(mock_config)
  end)

  after_each(function()
    M0.State = original_state
  end)

  describe('setup', function()
    it('can be set up', function()
      assert.has_no.errors(function()
        M0.setup(mock_config)
      end)
    end)

    it('initializes with the default backend', function()
      assert.equals('openai:gpt-3.5-turbo', M0.State.backend.opts.name)
    end)

    it('initializes with the default prompt', function()
      assert.equals('You are a helpful assistant.', M0.State.prompt)
    end)

    it('should validate configuration', function()
      local invalid_config = vim.deepcopy(mock_config)
      invalid_config.default_backend_name = 'non_existent_backend'
      assert.has_error(function()
        M0.setup(invalid_config)
      end, 'Configuration error. Please check your setup.')
    end)

    it('should create user commands', function()
      local commands = vim.api.nvim_get_commands {}
      assert.is_not_nil(commands.M0)
    end)

    it('should set up keymaps', function()
      local keymap = vim.api.nvim_get_keymap 'n'
      assert.is_not_nil(vim.tbl_filter(function(k)
        return k.lhs == '<Plug>(M0 chat)'
      end, keymap)[1])
    end)
  end)

  describe('backend management', function()
    it('can change the backend', function()
      local initial_backend = M0.State.backend.opts.name
      M0:M0backend 'anthropic:claude-3-haiku'
      assert.are_not.equal(initial_backend, M0.State.backend.opts.name)
      assert.equals('anthropic:claude-3-haiku', M0.State.backend.opts.name)
    end)

    it('should throw an error for non-existent backend', function()
      assert.has_error(function()
        M0:M0backend 'non_existent_backend'
      end)
    end)
  end)

  describe('prompt management', function()
    it('can change the prompt', function()
      local initial_prompt = M0.State.prompt
      M0:M0prompt 'Code reviewer'
      assert.are_not.equal(initial_prompt, M0.State.prompt)
      assert.equals('You are a code reviewer.', M0.State.prompt)
    end)

    it('should throw an error for non-existent prompt', function()
      assert.has_error(function()
        M0:M0prompt 'non_existent_prompt'
      end)
    end)
  end)

  describe('chat functionality', function()
    local mock_api

    before_each(function()
      mock_api = {
        make_body = stub.new(),
        make_headers = stub.new(),
        get_messages = stub.new(),
        get_response_text = stub.new(),
      }
      stub(require 'm0.apifactory', 'create').returns(mock_api)
    end)

    after_each(function()
      require('m0.apifactory').create:revert()
    end)

    it('should initiate a chat', function()
      M0:M0chat()
      assert.stub(mock_api.make_body).was_called()
      assert.stub(mock_api.make_headers).was_called()
    end)
  end)

  describe('project scanning', function()
    local mock_scan_project

    before_each(function()
      mock_scan_project = {
        get_context = stub.new().returns 'Mock project context',
      }
      stub(require 'm0.scanproject', 'get_context').returns 'Mock project context'
    end)

    after_each(function()
      require('m0.scanproject').get_context:revert()
    end)

    it('should scan project when enabled', function()
      M0.State.scan_project = true
      M0:M0chat()
      assert.stub(require('m0.scanproject').get_context).was_called()
    end)

    it('should not scan project when disabled', function()
      M0.State.scan_project = false
      M0:M0chat()
      assert.stub(require('m0.scanproject').get_context).was_not_called()
    end)
  end)

  describe('utility functions', function()
    it('has a functional debug method', function()
      local debug_info = M0:debug()
      assert.is_string(debug_info)
      assert.is_true(#debug_info > 0)
    end)
  end)

  describe('error handling', function()
    it('should handle API errors gracefully', function()
      local utils_mock = {
        log_error = stub.new(),
      }
      stub(require 'm0.utils', 'log_error')

      local error_api = {
        make_body = function()
          error 'API error'
        end,
        make_headers = stub.new(),
        get_messages = stub.new(),
      }
      stub(require 'm0.apifactory', 'create').returns(error_api)

      M0:M0chat()
      assert.stub(require('m0.utils').log_error).was_called()

      require('m0.utils').log_error:revert()
      require('m0.apifactory').create:revert()
    end)
  end)
end)
