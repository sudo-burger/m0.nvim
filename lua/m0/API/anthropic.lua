local LLMAPI = require 'm0.API.llmapi'
local Utils = require 'm0.utils'

---@class M0.API.AnthropicMessage
---@field role string
---@field content string|table
---@field cache_control? table

---@class M0.API.Anthropic:M0.API.LLMAPI
---@field new fun(self:M0.API.LLMAPI, backend_opts:M0.BackendOptions, state: table):M0.API.LLMAPI
---@field private make_messages fun(self:M0.API.Anthropic, messages:string[]):M0.API.AnthropicMessage[]
---@field opts table
---@field state table

---@type M0.API.Anthropic
---@diagnostic disable-next-line: missing-fields
local M = {}
function M:new(opts, state)
  return setmetatable(
    { opts = opts, state = state },
    { __index = setmetatable(M, LLMAPI) }
  )
end

local function make_messages(self, raw_messages)
  ---@type M0.API.AnthropicMessage[]
  local messages = {}

  -- If we are scanning the project but don't have access to caching
  -- (given by the Anthropic beta feature), pass the scan as a user message.
  if self.state.scan_project == true and not self.opts.anthropic_beta then
    table.insert(
      messages,
      { role = 'user', content = self.state.project_context }
    )
  end

  -- The initial message is assumed to be by the user.
  local role = 'user'
  local i = 1
  while i <= #raw_messages do
    table.insert(messages, { role = role, content = raw_messages[i] })
    role = role == 'user' and 'assistant' or 'user'
    i = i + 1
  end

  -- FIXME: should explicitly test for the caching feature.
  if self.opts.anthropic_beta then
    -- User turns processed counter used to drive prompt caching.
    -- See: https://github.com/anthropics/anthropic-cookbook/blob/main/misc/prompt_caching.ipynb
    -- Anthropic's suggestion is to "Add the last two user turns with ephemeral cache control."
    local user_messages_processed = 0
    i = #messages
    while i > 0 and user_messages_processed < 2 do
      if messages[i].role == 'user' then
        local text = messages[i].content
        messages[i].content = {
          {
            type = 'text',
            text = text,
            cache_control = { type = 'ephemeral' },
          },
        }
        user_messages_processed = user_messages_processed + 1
      end
      i = i - 1
    end
  end
  return messages
end

function M:make_body(opts)
  local system

  -- The "prompt caching" feature replaces the body.system element with
  -- a list of system elements.
  if self.opts.anthropic_beta then
    system = {
      { type = 'text', text = opts.prompt },
    }
    -- If we have access to prompt caching and we are scanning the project,
    -- ensure that the project context is cached.
    if self.state.scan_project == true then
      table.insert(system, {
        type = 'text',
        text = opts.context,
        cache_control = { type = 'ephemeral' },
      })
    end
  else
    system = opts.prompt
  end

  -- Handle model-specific defaults.
  local model_defaults = vim.tbl_filter(function(t)
    return t.name == self.opts.model.name
  end, self.opts.models)

  return {
    model = self.opts.model.name,
    temperature = self.opts.temperature,
    stream = self.opts.stream,
    max_tokens = self.opts.max_tokens or model_defaults[1].max_tokens,
    system = system,
    messages = make_messages(self, opts.messages),
  }
end

function M:make_headers()
  return {
    content_type = 'application/json',
    x_api_key = self.opts.api_key(),
    anthropic_version = self.opts.anthropic_version,
    anthropic_beta = self.opts.anthropic_beta,
  }
end

function M:get_response_text(data)
  local json, msg = Utils:json_decode(data)
  if not json then
    return false, 'Unable to decode (' .. msg .. '): ' .. data, nil
  end
  if not (json.content and json.content[1] and json.content[1].text) then
    return false, 'Unable to get response: ' .. data, nil
  end
  return true, json.content[1].text, vim.inspect(json.usage or '')
end

function M:stream(data, opts)
  if data and string.find(data, '^data: ') then
    local json, msg = Utils:json_decode(string.sub(data, 7))
    if not (json and json.type) then
      return false, 'Unable to decode (' .. msg .. '): ' .. data
    end

    if
      json.type == 'content_block_delta'
      and json.delta
      and json.delta ~= vim.empty_dict()
      and json.delta.text
      and json.delta.text ~= vim.NIL
    then
      opts.on_delta(json.delta.text)
      return true
    end

    if json.type == 'message_stop' then
      opts.on_done()
      return true
    end

    -- Print usage stats.
    if json.type == 'message_delta' and json.usage ~= vim.empty_dict() then
      opts.on_stats(vim.inspect(json.usage))
      return true
    end
  end
  -- Anything else.
  opts.on_cruft(data)
  return true
end

return M
