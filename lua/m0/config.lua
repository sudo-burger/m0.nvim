---@class M0Config
local M = {}

---@class Config
---@field backends table<Backend>
---@field providers table
---@field default_backend_name string
---@field default_max_tokens integer
---@field default_prompt_name string
---@field default_stream boolean
---@field default_temperature number
---@field prompts table
---@field section_mark string
M = {
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
          'claude-3-haiku-20240307',
          'claude-3-sonnet-20240229',
          'claude-3-opus-20240229',
        },
      },
      ['openai'] = {
        api_type = 'openai',
        url = 'https://api.openai.com/v1/chat/completions',
        models = {
          'gpt-4o',
        },
      },
      ['mistral'] = {
        api_type = 'openai',
        url = 'https://api.mistral.ai/v1/chat/completions',
        models = { 'mistral-large-latest' },
      },
      ['groq'] = {
        api_type = 'openai',
        url = 'https://api.groq.com/openai/v1/chat/completions',
        models = { 'mixtral-8x7b-32768' },
      },
    },
    backend_name = '',
    max_tokens = 128,
    prompt_name = '',
    stream = false,
    temperature = 1.0,
  },
  prompts = {},
  section_mark = '-------',
}

return M
