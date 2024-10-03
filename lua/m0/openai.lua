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
---@diagnostic disable-next-line: missing-fields
local M = {}
function M:new(opts, state)
  return setmetatable(
    { opts = opts, state = state },
    { __index = setmetatable(M, LLMAPI) }
  )
end

function M:make_body()
  -- Handle model-specific defaults.
  local model_defaults = vim.tbl_filter(function(t)
    return t.name == self.opts.model.name
  end, self.opts.models)

  return {
    model = self.opts.model.name,
    temperature = self.opts.temperature,
    stream = self.opts.stream,
    max_completion_tokens = self.opts.max_completion_tokens
      or model_defaults[1].max_completion_tokens,
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
  if j.choices == nil then
    return
  end
  return j.choices[1].message.content
end

function M:get_delta_text(body)
  if string.find(body, '^data: ') ~= nil then
    -- The redundant packet '[DONE]' used by the OpenAI API.
    if body == 'data: [DONE]' then
      return 'cruft', body
    end
    local json_data = Utils:json_decode(string.sub(body, 7))
    if
      -- Unexpected data? Return for debugging purposes.
      json_data == nil or json_data.object ~= 'chat.completion.chunk'
    then
      return 'cruft', body
    end
    if json_data.choices[1].delta.content ~= nil then
      return 'delta', json_data.choices[1].delta.content
    end
    -- The last message in an OpenAI streaming response.
    if json_data.choices[1].finish_reason == 'stop' then
      return 'done', body
    end
  end
  -- Possibly metadata that we may want to see for debugging purposes.
  return 'cruft', body
end

return M
