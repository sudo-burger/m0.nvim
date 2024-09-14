-- Helper functions.
--
local function read_file(path)
  local file = io.open(path, 'r')
  ---@diagnostic disable-next-line: need-check-nil
  local contents = (file:read '*all' or error('Unable to read file: ' .. path))
  ---@diagnostic disable-next-line: need-check-nil
  file:close()
  return vim.fn.shellescape(contents)
end
local function get_key(key_name)
  return string.gsub(vim.fn.system('pass ' .. key_name), '%s+', '')
end
local function anthropic_key()
  return get_key 'api.anthropic.com/key-0'
end
local function mistral_key()
  return get_key 'api.mistral.ai/key-0'
end
local function openai_key()
  return get_key 'api.openai.com/key-0'
end
return {
  'sudo-burger/m0.nvim',
  --branch = 'feat-errors',
  dependencies = {
    'nvim-lua/plenary.nvim',
  },
  cmd = { 'M0' },
  config = function()
    require('m0').setup {
      providers = {
        ['openai'] = {
          api_key = openai_key,
        },
        ['anthropic'] = {
          api_key = anthropic_key,
        },
        ['mistral'] = {
          api_key = mistral_key,
        },
      },
      backends = {
        ['openai:gpt-4o-stream'] = {
          provider = 'openai',
          model = 'gpt-4o',
          stream = true,
          max_tokens = 2048,
        },
        ['openai:gpt-4o-mini-stream'] = {
          provider = 'openai',
          model = 'gpt-4o-mini',
          stream = true,
          max_tokens = 10000,
          temperature = 0.8,
        },
        ['anthropic:claude-3-haiku'] = {
          provider = 'anthropic',
          model = 'claude-3-haiku-20240307',
          stream = true,
        },
        ['anthropic:claude-3-haiku-stream'] = {
          provider = 'anthropic',
          model = 'claude-3-haiku-20240307',
          stream = true,
        },
        ['anthropic:claude-3-5-sonnet-stream'] = {
          provider = 'anthropic',
          model = 'claude-3-5-sonnet-20240620',
          max_tokens = 2048,
          stream = true,
        },
        ['anthropic:claude-3-opus-stream'] = {
          provider = 'anthropic',
          model = 'claude-3-opus-20240229',
          max_tokens = 4096,
          stream = true,
        },
        ['mistral:mistral-large-latest-stream'] = {
          provider = 'mistral',
          model = 'mistral-large-latest',
          stream = true,
          max_tokens = 2048,
        },
      },
      -- default_backend_name = 'openai:gpt-4o-stream',
      -- default_backend_name = 'anthropic:claude-3-5-sonnet-stream',
      default_backend_name = 'openai:gpt-4o-mini-stream',
      prompts = {
        ['Charles Bukowski'] = 'You are now Charles Bukowski.',
        ['Expert assistant'] = read_file '~/.local/share/llm/prompts/expert-assistant.md',
        ['Helpful assistant'] = 'You are a helpful assistant.',
        ['Marilyn Monroe'] = 'Assume the persona of Marilyn Monroe.',
      },
      default_prompt_name = 'Expert assistant',
      section_mark = '-*-*-*-*-*-*-*-*-',
    }
    vim.keymap.set(
      { 'n', 'v' },
      '<leader>ax',
      '<Plug>(M0chat)',
      { desc = 'M0chat' }
    )
  end,
}
