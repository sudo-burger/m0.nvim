---@class M0.Utils
---@field safe_call fun(self:M0.Utils, func: fun(), ...):any,string?
---@field json_decode fun(self:M0.Utils, data: any):table?,string?

---@type M0.Utils
---@diagnostic disable-next-line: missing-fields
local M = {}

--- Execute a function safely, catching any errors that may occur.
--- @param fun fun(...) The function to execute.
--- @param ... ... Any additional arguments to pass to the function.
--- @return any result
--- @return string? error Error message
function M:safe_call(fun, ...)
  local success, ret = pcall(fun, ...)
  if not success then
    return nil, ret
  end
  return ret
end

--- Decode a JSON string safely.
--- @param data string A JSON string to decode.
--- @return table? json The decoded object, or nil if decoding fails.
--- @return string? error Error message.
function M:json_decode(data)
  return self:safe_call(vim.fn.json_decode, data)
end

return M
