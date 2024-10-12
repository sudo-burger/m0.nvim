---@class M0.Utils
---@field safe_call fun(self:M0.Utils, func: fun(), ...):any
---@field json_decode fun(self:M0.Utils, data: any):any

---@type M0.Utils
---@diagnostic disable-next-line: missing-fields
local M = {}

--- Execute a function safely, catching any errors that may occur.
--- @param fun fun(...) The function to execute.
--- @param ... ... Any additional arguments to pass to the function.
--- @return boolean success
--- @return any result
--- @return ...
function M:safe_call(fun, ...)
  return pcall(fun, ...)
end

--- Decode a JSON string safely.
--- @param data string The JSON string to decode.
--- @return table The decoded object, or nil and an error message if decoding fails.
function M:json_decode(data)
  return self:safe_call(vim.fn.json_decode, data)
end

return M
