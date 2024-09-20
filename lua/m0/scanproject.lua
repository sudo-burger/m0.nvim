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
    The context is structured using an XML-like syntax.
    The "<project>" tag contains the project.
    The "<file>" tag contains each file in the project.
    The file tag may have "name" attribute.\n

    <project>\n]]

  for _, f in pairs(files) do
    context = context
      .. '<file name="'
      .. f
      .. '">\n'
      .. read_file(f)
      .. '\n</file>\n'
  end
  context = context .. '</project>\n'
  return context
end
return M
