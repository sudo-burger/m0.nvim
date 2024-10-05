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
  local system

  -- The "prompt caching" feature replaces the body.system element with
  -- a list of system elements.
  if self.opts.anthropic_beta then
    system = {
      { type = 'text', text = self.state.prompt },
    }
    -- If we have access to prompt caching and we are scanning the project,
    -- ensure that the project context is cached.
    if self.state.scan_project == true then
      table.insert(system, {
        type = 'text',
        text = self.state.project_context,
        cache_control = { type = 'ephemeral' },
      })
    end
  else
    system = self.state.prompt
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

function M:get_messages(raw_messages)
  ---@type M0.AnthropicMessage[]
  local messages = {}
  local role = 'user'
  local i = 1

  -- If we are scanning the project but don't have access to caching
  -- (given by the Anthropic beta feature), pass the scan as a user message.
  if self.state.scan_project == true and not self.opts.anthropic_beta then
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
    return
  end
  return j.content[1].text
end

function M:get_delta_text(body)
  self.state.logger:log_trace(body)
  if string.find(body, '^data: ') then
    local json_data = Utils:json_decode(string.sub(body, 7))
    if not json_data or not json_data.type then
      return 'error', 'Unable to decode: ' .. body
    end

    if
      json_data.type == 'content_block_delta'
      and json_data.delta
      and json_data.delta ~= vim.empty_dict()
      and json_data.delta.text
      and json_data.delta.text ~= vim.NIL
    then
      return 'delta', json_data.delta.text
    end

    if json_data.type == 'message_stop' then
      return 'done', body
    end

    -- Print usage stats.
    if
      json_data.type == 'message_delta'
      and json_data.usage ~= vim.empty_dict()
    then
      return 'stats', vim.inspect(json_data.usage)
    end
  end
  -- Anything else.
  return 'cruft', body
end

return M
