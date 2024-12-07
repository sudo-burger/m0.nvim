local LLMAPI = require 'm0.API.llmapi'
local Utils = require 'm0.utils'

---@class M0.API.OpenAIMessage
---@field role string
---@field content string

---@class M0.API.OpenAI :M0.API.LLMAPI
---@field new fun(self:M0.API.LLMAPI, backend_opts:M0.BackendOptions, state: table):M0.API.LLMAPI
---@field private make_messages fun(self:M0.API.OpenAI, messages:string[], opts:table):M0.API.OpenAIMessage[]
---@field opts table
---@field state table

---@type M0.API.OpenAI
---@diagnostic disable-next-line: missing-fields
local M = {}
function M:new(opts, state)
  return setmetatable(
    { opts = opts, state = state },
    { __index = setmetatable(M, LLMAPI) }
  )
end

local function make_messages(raw_messages)
  ---@type M0.API.OpenAIMessage[]
  local messages = {}
  local role = 'user'
  local i = 1

  while i <= #raw_messages do
    table.insert(messages, { role = role, content = raw_messages[i] })
    role = role == 'user' and 'assistant' or 'user'
    i = i + 1
  end
  return messages
end

---@param opts table
---@return table
function M:make_body(opts)
  -- Handle model-specific defaults.
  local model_defaults = vim.tbl_filter(function(t)
    return t.name == self.opts.model.name
  end, self.opts.models)

  local messages = make_messages(opts.messages)
  if self.state.scan_project == true then
    -- Prepend the project_context as the first user message.
    table.insert(messages, 1, { role = 'user', content = opts.context })
  end
  -- The OpenAI completions API requires the prompt to be
  -- the first message (with role 'system').
  -- Patch the messages here.
  -- NOTE: "o1" beta models do not support the 'system' role, or temperatures
  -- different than 1.
  local role, temperature
  if
    self.opts.model.name == 'o1-preview' or self.opts.model.name == 'o1-mini'
  then
    role = 'user'
    temperature = 1
  else
    role = 'system'
    temperature = self.opts.temperature
  end
  table.insert(messages, 1, {
    role = role,
    content = opts.prompt,
  })

  local body = {
    model = self.opts.model.name,
    temperature = temperature,
    stream = self.opts.stream,
    max_completion_tokens = self.opts.max_completion_tokens
      or model_defaults[1].max_completion_tokens,
    messages = messages,
  }

  if opts.include_usage then
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

function M:stream(data, opts)
  -- The OpenAI API streaming calls end with this non-JSON message.
  if data == 'data: [DONE]' then
    opts.on_done()
    return true
  end

  if string.find(data, '^data: ') then
    local json, msg = Utils:json_decode(string.sub(data, 7))
    if not json then
      return false, 'Unable to decode (' .. msg .. '): ' .. data
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
      opts.on_delta(json.choices[1].delta.content)
      return true
    end

    -- Print usage stats.
    if json.usage and json.usage ~= vim.NIL then
      opts.on_stats(vim.inspect(json.usage))
      return true
    end
  end

  -- Anything else.
  opts.on_cruft(data)
  return true
end

-- function M:get_delta_text(body)
--   -- The OpenAI API streaming calls end with this non-JSON message.
--   if body == 'data: [DONE]' then
--     return 'done', body
--   end
--   if body and string.find(body, '^data: ') then
--     local json, msg = Utils:json_decode(string.sub(body, 7))
--     if not json then
--       return 'error', 'Unable to decode (' .. msg .. '): ' .. body
--     end
--
--     -- Handle the actual delta.
--     if
--       json.object
--       and json.object == 'chat.completion.chunk'
--       and json.choices
--       and json.choices ~= {}
--       and json.choices[1]
--       and json.choices[1].delta
--       and json.choices[1].delta ~= vim.empty_dict()
--       and json.choices[1].delta.content
--       and json.choices[1].delta.content ~= vim.NIL
--     then
--       return 'delta', json.choices[1].delta.content
--     end
--
--     -- Print usage stats.
--     if json.usage and json.usage ~= vim.NIL then
--       return 'stats', vim.inspect(json.usage)
--     end
--   end
--   -- Anything else.
--   return 'cruft', body
-- end

return M
