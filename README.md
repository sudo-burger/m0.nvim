# m0.nvim
## Introduction
Yet another Neovim plugin interacting with LLMs.

Aims:
* Easily configure any number of LLM backends and prompts.
* Easily switch backends and prompts, even mid-conversation.
* Minimal codebase.
* Learn some Lua, have fun.

Currently supported APIs:
* OpenAI: completions (https://platform.openai.com/docs/api-reference/making-requests)
* Anthropic: messages (https://docs.anthropic.com/claude/reference/messages_post)

## Installation
See the example Lazy configuration in `examples/m0.lua`.

## Usage
":M0 chat" sends the contents of the current buffer.
":M0 backend" to select a backend.
":M0 prompt" to select a prompt.

## Similar Projects

- [karthink/GPTel](https://github.com/karthink/gptel)
- [CamdenClark/flyboy](https://github.com/CamdenClark/flyboy)
- [gsuuon/model.nvim](https://github.com/gsuuon/model.nvim)
