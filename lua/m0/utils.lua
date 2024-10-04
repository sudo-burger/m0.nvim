---@class M0.Utils
---@field new fun(self:M0.Utils, opts:table):M0.Utils
---@field opts table
---@field _logger fun(self:M0.Utils, level:integer):fun(message:string):nil
---@field log_error fun(self:M0.Utils, message: string):nil
---@field log_info fun(self:M0.Utils, message: string):nil
---@field log_warn fun(self:M0.Utils, message: string):nil
---@field safe_call fun(self:M0.Utils, func: fun(), ...):any
---@field json_decode fun(self:M0.Utils, data: any):any

---@type M0.Utils
---@diagnostic disable-next-line: missing-fields
local M = {}

function M:safe_call(func, ...)
  local _, result = pcall(func, ...)
  return result
end

--- Safe json_decode.
function M:json_decode(data)
  return self:safe_call(vim.fn.json_decode, data)
end

return M
