--- @class M0.Selector
--- A single-item selector.
--- The selector requires the items to be in the format
--- {
---   ( k = "foo", v = "bar" },
---   ( k = "baz", v = "boz" },
--- }
--- @field make_selector fun(self:M0.Selector, opts: table, callback: fun(opts: table)):fun():nil

local pickers = require 'telescope.pickers'
local finders = require 'telescope.finders'
local previewers = require 'telescope.previewers'
local conf = require('telescope.config').values
local actions = require 'telescope.actions'
local action_state = require 'telescope.actions.state'

---@type M0.Selector
---@diagnostic disable-next-line: missing-fields
local M = {}

--- Private implementation of a single-item selector.
--- @param opts table Telescope theme.
--- @param title string? The title of the selector.
--- @param results table A set of 'results' to select from.
--- @param callback fun(opts: table):nil A callback to be called on selection.
--- @return fun():nil
local make_selector = function(opts, title, results, callback)
  return function()
    opts = opts or {}
    pickers
      .new(opts, {
        prompt_title = title,
        -- The finder shows the keys in the key-value pairs.
        finder = finders.new_table {
          results = results,
          entry_maker = function(entry)
            return {
              value = entry.v,
              display = entry.k,
              ordinal = entry.k,
            }
          end,
        },
        -- The previewer shows the values in the key-value pairs.
        previewer = previewers.new_buffer_previewer {
          ---@diagnostic disable-next-line: unused-local
          define_preview = function(self, entry, _status)
            vim.api.nvim_buf_set_lines(
              self.state.bufnr,
              0,
              -1,
              false,
              vim.split(entry.value or '', '\n')
            )
          end,
        },
        sorter = conf.generic_sorter(opts),
        -- Run the callback on the selection and cleanup.
        ---@diagnostic disable-next-line: unused-local
        attach_mappings = function(prompt_bufnr, _map)
          actions.select_default:replace(function()
            actions.close(prompt_bufnr)
            local selection = action_state.get_selected_entry()
            callback(selection)
          end)
          return true
        end,
      })
      :find()
  end
end

--- @param items table Items to select.
--- @param callback fun(opts: table):nil A callback to be called on selection.
--- @return fun():nil
function M:make_selector(items, callback)
  return make_selector({}, nil, items, callback)
end

return M
