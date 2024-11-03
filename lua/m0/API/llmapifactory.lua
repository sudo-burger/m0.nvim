---@class M0.API.LLMAPIFactory
local M = {}

local Anthropic = require 'm0.API.anthropic'
local OpenAI = require 'm0.API.openai'

local APIHandlers = {
  anthropic = Anthropic,
  openai = OpenAI,
}

---@param api_type api_type
---@param opts M0.BackendOptions
---@param state table reference to current state.
---@return boolean success
---@return M0.API.LLMAPI ret
function M.create(api_type, opts, state)
  local APIHandler = APIHandlers[api_type]
  if not APIHandler then
    return false, { error = 'Unsupported API type: ' .. api_type }
  end
  local instance = APIHandler:new(opts, state)
  if not instance then
    return false, { error = 'Failed to create handler for ' .. api_type }
  end

  return true, instance
end

return M
