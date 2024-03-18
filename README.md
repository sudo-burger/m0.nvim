# m0.nvim
## Introduction
Yet another Neovim plugin interacting with LLMs.

Aims:
* Easily configure several backends.
* Eeasily switch between backends, even mid-conversation.
* Minimal codebase.
* Learn some Lua, have fun.

Currently supported APIs:
* OpenAI: completions (https://platform.openai.com/docs/api-reference/making-requests)
* Anthropic: messages (https://docs.anthropic.com/claude/reference/messages_post)

## Installation
See the example Lazy configuration in `examples/m0.lua`.

## Usage
Call M0chat to send the contents of the current buffer.

Sections surrounded by '=====' will be interpreted as assistant answers.

Send an argument to M0chat at any time in order to switch between the configured backends.
