---@class M0.Logger
---@field new fun(self:M0.Logger, opts:table):M0.Logger
---@field opts table
---@field _logger fun(self:M0.Logger, level:integer):fun(message:string):nil
---@field log_debug fun(self:M0.Logger, message: string):nil
---@field log_error fun(self:M0.Logger, message: string):nil
---@field log_info fun(self:M0.Logger, message: string):nil
---@field log_warn fun(self:M0.Logger, message: string):nil

---@type M0.Logger
---@diagnostic disable-next-line: missing-fields
local M = {}
---
---@param opts table
---@return M0.Logger
function M:new(opts)
  return setmetatable({ opts = opts }, { __index = M })
end

function M:_logger(level)
  return function(message)
    if self.opts.log_level > level then
      return
    end
    vim.notify(message, level)
  end
end

function M:log_debug(message)
  self:_logger(vim.log.levels.DEBUG)(message)
end

function M:log_error(message)
  self:_logger(vim.log.levels.ERROR)(message)
end

function M:log_warn(message)
  self:_logger(vim.log.levels.WARN)(message)
end

function M:log_info(message)
  self:_logger(vim.log.levels.INFO)(message)
end

return M
