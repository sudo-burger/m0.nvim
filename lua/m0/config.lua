---@alias api_type "anthropic" | "openai"

---@class ProviderOptions
---@field api_type api_type
---@field api_key? string
---@field anthropic_version? string
---@field url string
---@field models string[]
---@field max_tokens number
---@field stream boolean
---@field temperature number

---@class Defaults
---@field providers table<string, ProviderOptions>
---@field default_backend_name string
---@field default_prompt_name string

---@class BackendOptions:ProviderOptions
---@field provider string
---@field api_key string
---@field model string
---@field stream boolean?
---@field max_tokens number?
---@field temperature number?

---@class Config
---@field backends table<string,BackendOptions>
---@field providers table<string,ProviderOptions>
---@field defaults Defaults
---@field prompts string[]
---@field section_mark string

---@type Config
local M = {
  backends = {},
  providers = {},
  defaults = {
    providers = {
      ['anthropic'] = {
        api_type = 'anthropic',
        anthropic_version = '2023-06-01',
        url = 'https://api.anthropic.com/v1/messages',
        models = {
          'claude-3-haiku-20240307',
          'claude-3-5-sonnet-20240620',
          'claude-3-opus-20240229',
        },
        max_tokens = 128,
        stream = false,
        temperature = 1.0,
      },
      ['openai'] = {
        api_type = 'openai',
        url = 'https://api.openai.com/v1/chat/completions',
        models = {
          'gpt-4o',
          'gpt-4o-mini',
        },
        max_tokens = 128,
        stream = false,
        temperature = 1.0,
      },
      ['mistral'] = {
        api_type = 'openai',
        url = 'https://api.mistral.ai/v1/chat/completions',
        models = { 'mistral-large-latest' },
        max_tokens = 128,
        stream = false,
        temperature = 1.0,
      },
      ['groq'] = {
        api_type = 'openai',
        url = 'https://api.groq.com/openai/v1/chat/completions',
        models = { 'mixtral-8x7b-32768' },
        max_tokens = 128,
        stream = false,
        temperature = 1.0,
      },
    },
    default_backend_name = '',
    default_prompt_name = '',
  },
  prompts = {},
  section_mark = '-------',
}

return M
