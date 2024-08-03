---@class M0.APIFactory
local M = {}

local Anthropic = require 'm0.anthropic'
local OpenAI = require 'm0.openai'
local Utils = require 'm0.utils'

local APIHandlers = {
  anthropic = Anthropic,
  openai = OpenAI,
}

---@param api_type api_type
---@param opts M0.BackendOptions
---@param state table reference to current state.
---@return M0.LLMAPI?
function M.create(api_type, opts, state)
  local APIHandler = APIHandlers[api_type]
  if not APIHandler then
    Utils:log_error('Unsupported API type: ' .. api_type)
  end
  return APIHandler:new(opts, state)
end

return M
