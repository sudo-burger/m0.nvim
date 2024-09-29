---@alias anthropic_api_type "anthropic"
---@alias openai_api_type "openai"

---@class M0.AnthropicProviderOptions
---@field api_type anthropic_api_type
---@field api_key? string
---@field anthropic_version string
---@field url string
---@field models string[]
---@field max_tokens number?|nil
---@field stream boolean?|nil
---@field temperature number?|nil

---@class M0.OpenAIProviderOptions
---@field api_type openai_api_type
---@field api_key? string
---@field url string
---@field models string[]
---@field max_completion_tokens number?|nil
---@field stream boolean?|nil
---@field temperature number?|nil

---@class M0.BackendOptions
---@field provider string
---@field model string

---@class M0.Defaults
---@field backends table<string, M0.BackendOptions>
---@field providers table<string, M0.AnthropicProviderOptions|M0.OpenAIProviderOptions>
---@field prompts table<string, string>
---@field default_backend_name string
---@field default_prompt_name string

---@class M0.Config
---@field providers table<string,M0.AnthropicProviderOptions|M0.OpenAIProviderOptions>
---@field backends table<string,M0.BackendOptions>
---@field defaults M0.Defaults
---@field prompts table<string, string>
---@field section_mark string
---@field default_backend_name? string
---@field default_prompt_name? string
---@field validate? fun(self:M0.Config):any

local Utils = require 'm0.Utils'

---@type M0.Config
local M = {
  providers = {},
  backends = {},
  defaults = {
    backends = {
      ['openai:gpt-4o-mini-stream'] = {
        provider = 'openai',
        model = 'gpt-4o-mini',
        stream = true,
        max_completion_tokens = 4096,
      },
    },
    providers = {
      ['anthropic'] = {
        api_type = 'anthropic',
        anthropic_version = '2023-06-01',
        anthropic_beta = 'prompt-caching-2024-07-31',
        url = 'https://api.anthropic.com/v1/messages',
        models = {
          'claude-3-haiku-20240307',
          'claude-3-5-sonnet-20240620',
          'claude-3-opus-20240229',
        },
        max_tokens = 4096,
        stream = false,
        temperature = nil,
      },
      ['openai'] = {
        api_type = 'openai',
        url = 'https://api.openai.com/v1/chat/completions',
        models = {
          'gpt-4o',
          'gpt-4o-mini',
          'o1-preview',
          'o1-mini',
        },
        max_completion_tokens = nil,
        stream = false,
        temperature = nil,
      },
      ['mistral'] = {
        api_type = 'openai',
        url = 'https://api.mistral.ai/v1/chat/completions',
        models = { 'mistral-large-latest' },
        max_completion_tokens = nil,
        stream = false,
        temperature = nil,
      },
      ['groq'] = {
        api_type = 'openai',
        url = 'https://api.groq.com/openai/v1/chat/completions',
        models = { 'mixtral-8x7b-32768' },
        max_completion_tokens = nil,
        stream = false,
        temperature = nil,
      },
    },
    prompts = {
      ['useful assistant'] = 'You are a useful assistant.',
    },
    default_backend_name = 'openai:gpt-4o-mini-stream',
    default_prompt_name = 'useful assistant',
  },
  prompts = {},
  section_mark = '-------',
}

function M:validate()
  local function do_validate()
    if not self.default_backend_name then
      Utils:log_error 'No default backend configured.'
    end
    if not self.backends or vim.tbl_isempty(self.backends) then
      Utils:log_error 'No backends configured.'
    end
    if not self.backends[self.default_backend_name] then
      Utils:log_error(
        'Default backend ('
          .. self.default_backend_name
          .. ') is not among configured backends ('
          .. vim.inspect(self.backends)
          .. ')'
      )
    end
    if not self.default_prompt_name then
      Utils:log_error 'No default backend configured.'
    end
    if not self.backends or vim.tbl_isempty(self.prompts) then
      Utils:log_error 'No prompts configured.'
    end
    if not self.prompts[self.default_prompt_name] == nil then
      Utils:log_error(
        'Default prompt ('
          .. self.default_prompt_name
          .. ') is not among configured prompts ('
          .. vim.inspect(self.prompts)
          .. ')'
      )
    end
  end
  if not pcall(do_validate) then
    Utils:log_error 'Configuration error. Please check your setup.'
    return
  end
end

return M
