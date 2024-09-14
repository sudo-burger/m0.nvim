---@class M0.Utils
---@field log_error fun(self:M0.Utils, message: string):nil
---@field log_info fun(self:M0.Utils, message: string):nil
---@field safe_call fun(self:M0.Utils, func: fun(), ...):any
---@field json_decode fun(self:M0.Utils, data: any):any

---@type M0.Utils
---@diagnostic disable-next-line: missing-fields
local M = {}

function M:log_error(message)
  vim.notify(message, vim.log.levels.ERROR)
  error(message)
end

function M:log_info(message)
  vim.notify(message, vim.log.levels.INFO)
end

function M:safe_call(func, ...)
  local success, result = pcall(func, ...)
  if not success then
    M:log_error('Error occurred: ' .. tostring(result))
  end
  return result
end

--- Safe json_decode.
function M:json_decode(data)
  return M:safe_call(vim.fn.json_decode, data)
end

return M
