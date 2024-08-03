require 'm0.message'

local LLMAPI = require 'm0.llmapi'
local Utils = require 'm0.utils'

---@class M0.OpenAIMessage
---@field role string
---@field content string

---@class M0.OpenAI :M0.LLMAPI
---@field new fun(self:M0.LLMAPI, backend_opts:M0.BackendOptions, state: table):M0.LLMAPI
---@field get_messages fun(self:M0.OpenAI, messages:RawMessage[]):M0.OpenAIMessage[]
---@field opts table
---@field state table

---@type M0.OpenAI
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
  }
end

function M:make_headers()
  return {
    content_type = 'application/json',
    authorization = 'Bearer ' .. self.opts.api_key(),
  }
end

function M:get_messages(raw_messages)
  ---@type M0.OpenAIMessage[]
  local messages = {}
  local role = 'user'
  local i = 1
  -- The OpenAI completions API requires the prompt to be
  -- the first message (with role 'system').
  -- Patch the messages here.
  table.insert(messages, 1, { role = 'system', content = self.state.prompt })
  while i <= #raw_messages do
    table.insert(messages, { role = role, content = raw_messages[i] })
    role = role == 'user' and 'assistant' or 'user'
    i = i + 1
  end
  return messages
end

function M:get_response_text(data)
  local j = Utils:json_decode(data)
  if j.choices == nil then
    error('Received: ' .. data)
  end
  return j.choices[1].message.content
end

function M:get_delta_text(body)
  if body == 'data: [DONE]' then
    return 'done', body
  end

  if body == '\n' or body == '' then
    return 'cruft', body
  end

  if string.find(body, '^data: ') ~= nil then
    -- We are in a 'data: ' package now.
    -- Extract and return the text payload.
    --
    -- The last message in an openai delta will have:
    --   choices[1].delta == {}
    --   choices[1].finish_reason == 'stop'
    --
    local json_data = Utils:json_decode(string.sub(body, 7))
    if
      json_data ~= nil
      and json_data.object == 'chat.completion.chunk'
      and json_data.choices[1].delta.content ~= nil
    then
      return 'delta', json_data.choices[1].delta.content
    end
  else
    return 'other', body
  end
  -- Not data, so most likely metadata that we only would want to see for
  -- debugging purposes.
  return 'cruft', body
end

return M
