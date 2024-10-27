local M = {}

M.check_version = function()
  local min_version = '0.10.1'
  local verstr = tostring(vim.version())
  if not vim.version.ge or not vim.version.ge(vim.version(), min_version) then
    vim.health.error(
      string.format(
        "Neovim out of date: '%s'. Upgrade to latest stable or nightly",
        verstr
      )
    )
    return
  end
  vim.health.ok(string.format("Neovim version is: '%s'", verstr))
end

M.check = function()
  vim.health.start 'm0.nvim'

  M.check_version()
end

return M
