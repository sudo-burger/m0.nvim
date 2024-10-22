local LLMAPI = require 'm0.llmapi'
local Utils = require 'm0.utils'

---@class M0.OpenAIMessage
---@field role string
---@field content string

---@class M0.OpenAI :M0.LLMAPI
---@field new fun(self:M0.LLMAPI, backend_opts:M0.BackendOptions, state: table):M0.LLMAPI
---@field get_messages fun(self:M0.OpenAI, messages:string[]):M0.OpenAIMessage[]
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

---@param messages string[]
---@return table
function M:make_body(messages)
  -- Handle model-specific defaults.
  local model_defaults = vim.tbl_filter(function(t)
    return t.name == self.opts.model.name
  end, self.opts.models)

  local body = {
    model = self.opts.model.name,
    temperature = self.opts.temperature,
    stream = self.opts.stream,
    max_completion_tokens = self.opts.max_completion_tokens
      or model_defaults[1].max_completion_tokens,
    messages = self:get_messages(messages),
  }

  if self.opts.stream and self.state.log_level <= vim.log.levels.DEBUG then
    body.stream_options = {
      include_usage = true,
    }
  end
  return body
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
  local json, msg = Utils:json_decode(data)
  if
    not (
      json
      and json.choices
      and json.choices[1]
      and json.choices[1].message
      and json.choices[1].message ~= vim.empty_dict()
      and json.choices[1].message.content
      and json.usage
    )
  then
    return false, 'Unable to decode (' .. msg .. '): ' .. data, nil
  end
  return true, json.choices[1].message.content, vim.inspect(json.usage)
end

function M:get_delta_text(body)
  -- The OpenAI API streaming calls end with this non-JSON message.
  if body == 'data: [DONE]' then
    return 'done', body
  end
  if body and string.find(body, '^data: ') then
    local json, msg = Utils:json_decode(string.sub(body, 7))
    if not json then
      return 'error', 'Unable to decode (' .. msg .. '): ' .. body
    end

    -- Handle the actual delta.
    if
      json.object
      and json.object == 'chat.completion.chunk'
      and json.choices
      and json.choices ~= {}
      and json.choices[1]
      and json.choices[1].delta
      and json.choices[1].delta ~= vim.empty_dict()
      and json.choices[1].delta.content
      and json.choices[1].delta.content ~= vim.NIL
    then
      return 'delta', json.choices[1].delta.content
    end

    -- Print usage stats.
    if json.usage and json.usage ~= vim.NIL then
      return 'stats', vim.inspect(json.usage)
    end
  end
  -- Anything else.
  return 'cruft', body
end

return M
