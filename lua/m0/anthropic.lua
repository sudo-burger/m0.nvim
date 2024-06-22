local M = {}
local LLMAPI = require 'm0.llmapi'
local Utils = require 'm0.utils'
---
---@class Anthropic:LLMAPI
---@field new fun(LLMAPI, table):LLMAPI
---@field opts table
---@field state table

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
    x_api_key = self.opts.api_key,
    anthropic_version = self.opts.anthropic_version,
  }
end

function M:get_messages(messages)
  return messages
end

function M:get_response_text(data)
  local j = Utils:json_decode(data)
  if j.content == nil then
    error('Received: ' .. data)
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
