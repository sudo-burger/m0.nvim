---@class M0.Logger
---@field new fun(self:M0.Logger, opts:table):M0.Logger
---@field private opts table
---@field log_trace fun(self:M0.Logger, message: string?):nil
---@field log_debug fun(self:M0.Logger, message: string?):nil
---@field log_info fun(self:M0.Logger, message: string?):nil
---@field log_warn fun(self:M0.Logger, message: string?):nil
---@field log_error fun(self:M0.Logger, message: string?):nil
---@field private _logger fun(self:M0.Logger, level:integer):fun(message:string?):nil

---@type M0.Logger
---@diagnostic disable-next-line: missing-fields
local M = {}
---
---@param opts table
---@return M0.Logger
function M:new(opts)
  return setmetatable({ opts = opts }, { __index = M })
end

local function _logger(self, level)
    if self.opts.log_level > level then
      return
    end
    vim.notify(message or '', level)
  end
end

function M:log_trace(message)
  _logger(self, vim.log.levels.TRACE)('[TRACE] ' .. message)
end

function M:log_debug(message)
  _logger(self, vim.log.levels.DEBUG)('[DEBUG] ' .. message)
end

function M:log_info(message)
  _logger(self, vim.log.levels.INFO)('[INFO] ' .. message)
end

function M:log_warn(message)
  _logger(self, vim.log.levels.WARN)('[WARN] ' .. message)
end

function M:log_error(message)
  _logger(self, vim.log.levels.ERROR)('[ERROR] ' .. message)
end

return M
