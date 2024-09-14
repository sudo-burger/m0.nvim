---@class M0.ScanProject
---@field get_context fun(self:M0.ScanProject, dir: string):string

---@type M0.ScanProject
---@diagnostic disable-next-line: missing-fields
local M = {}

local function read_file(path)
  local file = assert(io.open(path, 'r'))
  ---@diagnostic disable-next-line: need-check-nil
  local contents = assert(file:read '*all')
  ---@diagnostic disable-next-line: need-check-nil
  file:close()
  return contents
end

function M:get_context(dir)
  ---@type table
  local files = require('plenary.scandir').scan_dir(dir)
  ---@type string
  local context = [[The following is the context for this project.
  The context is composed of zero or more files.
  The contexts of each file are given here, bracketed by the string "__BEGIN_FILE "
  followed by the file name at the start,
  and by the string "__END_FILE " followed by the same file name at the end. \n]]

  for _, f in pairs(files) do
    context = context
      .. '__BEGIN_FILE '
      .. f
      .. '\n'
      .. read_file(f)
      .. '\n'
      .. '__END_FILE '
      .. f
      .. '\n'
  end
  return context
end
return M
