local Logger = require 'm0.logger'

---@alias anthropic_api_type 'anthropic'
---@alias openai_api_type 'openai'
---@alias api_type  anthropic_api_type | openai_api_type

---@class M0.AnthropicModelOptions
---@field name string
---@field max_tokens integer

---@class M0.OpenAIModelOptions
---@field name string
---@field max_tokens? integer
---@field max_completion_tokens? integer

---@class M0.AnthropicProviderOptions
---@field api_type anthropic_api_type
---@field api_key? string
---@field anthropic_version string
---@field url string
---@field models table<string, M0.AnthropicModelOptions>
---@field stream boolean?|nil
---@field temperature number?|nil

---@class M0.OpenAIProviderOptions
---@field api_type openai_api_type
---@field api_key? string
---@field url string
---@field models table<string, M0.OpenAIModelOptions>
---@field stream boolean?|nil
---@field temperature number?|nil

---@class M0.BackendOptions
---@field provider string
---@field model table[M0.AnthropicModelOptions|M0.OpenAIModelOptions]

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
---@field log_level? integer See vim.log.loglevel
---@field default_backend_name? string
---@field default_prompt_name? string
---@field validate? fun(self:M0.Config, logger:M0.Logger):any

---@type M0.Config
local M = {
  log_level = vim.log.levels.INFO,
  providers = {},
  backends = {},
  defaults = {
    backends = {
      -- Default/example backend.
      ['openai:gpt-4o-mini'] = {
        provider = 'openai',
        model = { name = 'gpt-4o-mini' },
      },
    },
    providers = {
      ['anthropic'] = {
        api_type = 'anthropic',
        anthropic_version = '2023-06-01',
        anthropic_beta = 'prompt-caching-2024-07-31',
        url = 'https://api.anthropic.com/v1/messages',
        stream = true,
        temperature = 0.7,
        models = {
          { name = 'claude-3-5-sonnet-20240620', max_tokens = 8192 },
          { name = 'claude-3-haiku-20240307', max_tokens = 4096 },
          { name = 'claude-3-opus-20240229', max_tokens = 4096 },
          { name = 'claude-3-sonnet-20240229', max_tokens = 4096 },
        },
      },
      ['openai'] = {
        api_type = 'openai',
        url = 'https://api.openai.com/v1/chat/completions',
        stream = true,
        temperature = 0.7,
        models = {
          { name = 'gpt-4o', max_completion_tokens = 4096 },
          { name = 'chatgpt-4o-latest', max_completion_tokens = 16384 },
          { name = 'gpt-4o-mini', max_completion_tokens = 16384 },
          { name = 'o1-mini', max_completion_tokens = 65536 },
          { name = 'o1-preview', max_completion_tokens = 32768 },
        },
      },
      ['mistral'] = {
        api_type = 'openai',
        url = 'https://api.mistral.ai/v1/chat/completions',
        stream = true,
        temperature = 0.7,
        models = {
          { name = 'codestral-latest', max_tokens = 1024 },
          { name = 'mistral-large-latest', max_tokens = 1024 },
          { name = 'mistral-small-latest', max_tokens = 1024 },
          { name = 'open-mistral-nemo', max_tokens = 1024 },
          { name = 'pixtral-12b-2409', max_tokens = 1024 },
        },
      },
      ['groq'] = {
        api_type = 'openai',
        url = 'https://api.groq.com/openai/v1/chat/completions',
        stream = true,
        temperature = 0.7,
        models = {
          { name = 'mixtral-8x7b-32768', max_tokens = 32768 },
          { name = 'llama-3.2-3b-preview', max_tokens = 8192 },
        },
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

function M:validate(logger)
  local function do_validate()
    -- Must have a default backend name.
    if not self.default_backend_name then
      logger:log_error 'No default backend configured.'
    end
    -- Must have at least one configured backend.
    if not self.backends or vim.tbl_isempty(self.backends) then
      logger:log_error 'No backends configured.'
    end
    -- The default backend must be configured.
    if not self.backends[self.default_backend_name] then
      logger:log_error(
        'Default backend ('
          .. self.default_backend_name
          .. ') is not among configured backends ('
          .. vim.inspect(self.backends)
          .. ')'
      )
    end
    -- Must have a default prompt name.
    if not self.default_prompt_name then
      logger:log_error 'No default backend configured.'
    end
    -- Must have at least one configured prompt.
    if not self.backends or vim.tbl_isempty(self.prompts) then
      logger:log_error 'No prompts configured.'
    end
    -- The default prompt must be configured.
    if not self.prompts[self.default_prompt_name] == nil then
      logger:log_error(
        'Default prompt ('
          .. self.default_prompt_name
          .. ') is not among configured prompts ('
          .. vim.inspect(self.prompts)
          .. ')'
      )
    end
  end
  if not pcall(do_validate) then
    logger:log_error 'Configuration error. Please check your setup.'
    return
  end
end

return M
