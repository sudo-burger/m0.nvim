local M = {}

function M:log_error(message)
  vim.notify(message, vim.log.levels.ERROR)
end

function M:log_info(message)
  vim.notify(message, vim.log.levels.INFO)
end

return M
