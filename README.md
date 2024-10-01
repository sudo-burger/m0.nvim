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
return {
  'sudo-burger/m0.nvim',
  dependencies = {
    'nvim-lua/plenary.nvim',
    'nvim-telescope/telescope.nvim',
  },
  opts = {
    providers = {
      ['anthropic'] = {
        api_key = <anthropic_key>,
      },
      ['openai'] = {
        api_key = <openai_key>,
      },
      ['mistral'] = {
        api_key = <mistral_key>,
      },
    },
    backends = {
      ['openai:gpt-4o-mini-nostream'] = {
        provider = 'openai',
        model = { name = 'gpt-4o-mini', max_completion_tokens = 128 },
        stream = false,
        temperature = 0.8,
      },
      ['anthropic:claude-3-haiku'] = {
        provider = 'anthropic',
        model = { name = 'claude-3-haiku-20240307' },
      },
      ['mistral:mistral-large-latest-stream'] = {
        provider = 'mistral',
        model = { name = 'mistral-large-latest', max_tokens = 3000 },
      },
    },
    default_backend_name = 'openai:gpt-4o-mini-nostream',
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
- ":M0 chat" start/continue chat.
- ":M0 scan_project" include the current project as conversation context.
  - Prompt caching used when supported.
- ":M0 backend" to select a backend.
- ":M0 prompt" to select a prompt.

## Similar Projects
- [karthink/GPTel](https://github.com/karthink/gptel)
- [CamdenClark/flyboy](https://github.com/CamdenClark/flyboy)
- [gsuuon/model.nvim](https://github.com/gsuuon/model.nvim)
