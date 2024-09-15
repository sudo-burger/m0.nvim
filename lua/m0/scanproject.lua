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

--- Create a 'project context' (in practice a concatenation of the project files.)
---@param dir string The directory where the project lives.
---@return string The 'context'
function M:get_context(dir)
  --- Refuse to continue if 'dir' is not a .git repository.
  if require('plenary.path'):new(dir .. '/.git'):is_dir() == false then
    require('m0.utils'):log_info('Not .git in ' .. dir .. '; refusing to scan.')
    return ''
  end
  ---@type string[]
  local files = require('plenary.scandir').scan_dir(dir)
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
