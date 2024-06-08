---@class M0Config
local M = {}

M.defaults = {
  backends = {},
  default_anthropic_version = '2023-06-01',
  default_anthropic_url = 'https://api.anthropic.com/v1/messages',
  default_backend_name = '',
  default_max_tokens = 128,
  default_openai_url = 'https://api.openai.com/v1/chat/completions',
  default_prompt_name = '',
  default_stream = false,
  default_temperature = 1.0,
  prompts = {},
  section_mark = '-------',
}

return M
