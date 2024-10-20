---@class M0.LLMAPIFactory
local M = {}

local Anthropic = require 'm0.anthropic'
local OpenAI = require 'm0.openai'

local APIHandlers = {
  anthropic = Anthropic,
  openai = OpenAI,
}

---@param api_type api_type
---@param opts M0.BackendOptions
---@param state table reference to current state.
---@return boolean success
---@return M0.LLMAPI|string ret If the function fails, this is an error string.
function M.create(api_type, opts, state)
  local APIHandler = APIHandlers[api_type]
  if not APIHandler then
    return false, 'Unsupported API type: ' .. api_type
  end
  local instance = APIHandler:new(opts, state)
  if not instance then
    return false, 'Failed to create handler for ' .. api_type
  end

  return true, instance
end

return M
