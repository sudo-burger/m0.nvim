# m0.nvim
## Introduction
Yet another Neovim plugin interacting with LLMs.

Aims:
* Easily configure several backends.
* Eeasily switch backends and prompts, even mid-conversation.
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

Call M0backend to change backend.

Call M0prompt to change prompt.
