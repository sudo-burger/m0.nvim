---@class M0Config
local M = {}

---@class Config
---@field backends table<Backend>
---@field provider_defaults table
---@field default_backend_name string
---@field default_max_tokens integer
---@field default_prompt_name string
---@field default_stream boolean
---@field default_temperature number
---@field prompts table
---@field section_mark string

M.defaults = {
  backends = {},
  provider_defaults = {
    ['anthropic'] = {
      api_version = '2023-06-01',
      url = 'https://api.anthropic.com/v1/messages',
    },
    ['openai'] = {
      url = 'https://api.openai.com/v1/chat/completions',
    },
  },
  default_backend_name = '',
  default_max_tokens = 128,
  default_prompt_name = '',
  default_stream = false,
  default_temperature = 1.0,
  prompts = {},
  section_mark = '-------',
}

return M
