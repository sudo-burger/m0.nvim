require 'm0.message'

local LLMAPI = require 'm0.llmapi'
local Utils = require 'm0.utils'

---@class M0.AnthropicMessage
---@field role string
---@field content string

---@class M0.Anthropic:M0.LLMAPI
---@field new fun(self:M0.LLMAPI, backend_opts:M0.BackendOptions, state: table):M0.LLMAPI
---@field get_messages fun(self:M0.Anthropic, messages:RawMessage[]):M0.AnthropicMessage[]
---@field opts table
---@field state table

---@type M0.Anthropic
---@diagnostic disable-next-line: missing-fields
local M = {}

function M:new(opts, state)
  return setmetatable(
    { opts = opts, state = state },
    { __index = setmetatable(M, LLMAPI) }
  )
end

function M:make_body()
  return {
    model = self.opts.model,
    temperature = self.opts.temperature,
    max_tokens = self.opts.max_tokens,
    stream = self.opts.stream,
    system = self.state.prompt,
  }
end

function M:make_headers()
  return {
    content_type = 'application/json',
    x_api_key = self.opts.api_key(),
    anthropic_version = self.opts.anthropic_version,
  }
end

function M:get_messages(raw_messages)
  ---@type M0.AnthropicMessage[]
  local messages = {}
  local role = 'user'
  local i = 1

  if self.state.scan_project == true then
    -- Prepend the project_context as the first user message.
    table.insert(
      messages,
      { role = 'user', content = self.state.project_context }
    )
  end

  while i <= #raw_messages do
    table.insert(messages, { role = role, content = raw_messages[i] })
    role = role == 'user' and 'assistant' or 'user'
    i = i + 1
  end
  return messages
end

function M:get_response_text(data)
  local j = Utils:json_decode(data)
  if j.content == nil then
    Utils:log_error('Received: ' .. data)
    return
  end
  return j.content[1].text
end

function M:get_delta_text(body)
  if body == 'event: message_stop' then
    return 'done', body
  end

  if body == '\n' or body == '' or string.find(body, '^event: ') ~= nil then
    return 'cruft', body
  end

  if string.find(body, '^data: ') ~= nil then
    -- We are in a 'data: ' package now.
    -- Extract and return the text payload.
    --
    local json_data = Utils:json_decode(string.sub(body, 7))
    if
      json_data ~= nil
      and json_data.type == 'content_block_delta'
      and json_data.delta.text ~= nil
    then
      return 'delta', json_data.delta.text
    end
  else
    return 'other', body
  end
  -- Not data, so most likely metadata that we only would want to see for
  -- debugging purposes.
  return 'cruft', body
end

return M
