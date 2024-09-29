# m0.nvim

## Introduction
Yet another Neovim plugin interacting with LLMs.

Goals:
* Configure any number of LLM backends and prompts.
* Switch backends and prompts, even mid-conversation.
* Minimal codebase.
* Learn some Lua, have fun.

Supported APIs:
* OpenAI: completions (https://platform.openai.com/docs/api-reference/making-requests)
* Anthropic: messages (https://docs.anthropic.com/claude/reference/messages_post)
  - Supports prompt caching for project scans.

## Installation

Using [lazy.nvim](https://github.com/folke/lazy.nvim)
``` lua

-- Suggested helpers for safely importing API keys.
-- Depends on 'pass' (https://www.passwordstore.org).
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
  dependencies = {
    'nvim-lua/plenary.nvim',
    'nvim-telescope/telescope.nvim',
  },
  opts = {
    providers = {
      ['anthropic'] = {
        api_key = anthropic_key,
      },
      ['openai'] = {
        api_key = openai_key,
      },
      ['mistral'] = {
        api_key = mistral_key,
      },
    },
    backends = {
      ['openai:gpt-4o-mini-stream'] = {
        provider = 'openai',
        model = 'gpt-4o-mini',
        stream = true,
        max_tokens = 4096,
        temperature = 0.8,
      },
      ['anthropic:claude-3-haiku'] = {
        provider = 'anthropic',
        model = 'claude-3-haiku-20240307',
        stream = true,
      },
      ['mistral:mistral-large-latest-stream'] = {
        -- M0 knows to use the OpenAI API for Mistral.
        provider = 'mistral',
        model = 'mistral-large-latest',
      },
    },
    default_backend_name = 'openai:gpt-4o-mini-stream',
    prompts = {
      ['Helpful assistant'] = 'You are a helpful assistant.',
      ['Marilyn Monroe'] = 'Assume the persona of Marilyn Monroe.',
    },
    default_prompt_name = 'Helpful assistant',
    section_mark = '-*-*-*-*-*-*-*-*-',
  },
  keys = {
    { '<leader>ax', '<Plug>(M0 chat)', desc = 'M0 chat', mode = { 'n', 'v' } },
    { '<leader>ap', '<Plug>(M0 prompt)', desc = 'M0 prompt' },
    { '<leader>ab', '<Plug>(M0 backend)', desc = 'M0 backend' },
    { '<leader>as', '<Plug>(M0 scan_project)', desc = 'M0 scan_project' },
  },
}
```

## Usage
":M0 chat" start/continue chat.
":M0 scan_project" include the current project as conversation context.
":M0 backend" to select a backend.
":M0 prompt" to select a prompt.

## Similar Projects
- [karthink/GPTel](https://github.com/karthink/gptel)
- [CamdenClark/flyboy](https://github.com/CamdenClark/flyboy)
- [gsuuon/model.nvim](https://github.com/gsuuon/model.nvim)
